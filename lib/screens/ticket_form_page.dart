import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class TicketFormPage extends StatefulWidget {
  final String officerId;
  const TicketFormPage({super.key, required this.officerId});

  @override
  State<TicketFormPage> createState() => _TicketFormPageState();
}

class _TicketFormPageState extends State<TicketFormPage> {
  final _plateController = TextEditingController();
  final _amountController = TextEditingController();
  final _ownerNameController = TextEditingController(); // NEW
  final _ownerPhoneController = TextEditingController(); // NEW
  String _selectedViolation = 'Speeding';

  final List<String> _violations = [
    'Speeding',
    'Illegal Parking',
    'No License',
    'Wrong Way',
    'Overloading',
  ];

  // --- 1. የፖሊሱ የሥራ አፈጻጸም ታሪክ (Daily, Weekly, Monthly) ---
  void _showOfficerHistory() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              "MY PERFORMANCE SUMMARY",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('tickets')
                    .where('officerId', isEqualTo: widget.officerId)
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData)
                    return const Center(child: CircularProgressIndicator());
                  var docs = snapshot.data!.docs;

                  int today = 0, week = 0, month = 0;
                  DateTime now = DateTime.now();

                  for (var doc in docs) {
                    if (doc['timestamp'] == null) continue;
                    DateTime d = (doc['timestamp'] as Timestamp).toDate();
                    if (d.day == now.day &&
                        d.month == now.month &&
                        d.year == now.year)
                      today++;
                    if (now.difference(d).inDays <= 7) week++;
                    if (d.month == now.month && d.year == now.year) month++;
                  }

                  return Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _statTile("Today", today),
                          _statTile("Week", week),
                          _statTile("Month", month),
                        ],
                      ),
                      const Divider(height: 30),
                      const Text(
                        "Recent Violations",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: ListView.builder(
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            var data =
                                docs[index].data() as Map<String, dynamic>;
                            return ListTile(
                              leading: const Icon(Icons.description_outlined),
                              title: Text("Plate: ${data['plate']}"),
                              subtitle: Text(
                                "${data['violation']} - ${data['amount']} ETB",
                              ),
                              trailing: Text(
                                data['timestamp'] != null
                                    ? DateFormat('MMM d').format(
                                        (data['timestamp'] as Timestamp)
                                            .toDate(),
                                      )
                                    : "",
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statTile(String label, int count) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        Text(
          "$count",
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
      ],
    );
  }

  // --- 2. የሰሌዳ ማረጋገጫ (Verification Logic) ---
  void _verifyVehicle() async {
    String plate = _plateController.text.trim().toUpperCase();
    if (plate.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a plate number first")),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Status for Plate: $plate"),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('tickets')
                .where('plate', isEqualTo: plate)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData)
                return const Center(child: CircularProgressIndicator());
              var tickets = snapshot.data!.docs;
              if (tickets.isEmpty)
                return const Center(child: Text("No violation record found."));

              return ListView.builder(
                itemCount: tickets.length,
                itemBuilder: (context, index) {
                  var data = tickets[index].data() as Map<String, dynamic>;
                  bool isPaid = data['status'] == 'PAID';
                  String dateStr = data['timestamp'] != null
                      ? DateFormat(
                          'yMMMd',
                        ).format((data['timestamp'] as Timestamp).toDate())
                      : "N/A";

                  return Card(
                    color: isPaid ? Colors.green.shade50 : Colors.red.shade50,
                    child: ListTile(
                      title: Text(
                        "${data['violation']} - ${data['amount']} ETB",
                      ),
                      subtitle: Text(
                        "Status: ${data['status']}\nDate: $dateStr\nOwner: ${data['ownerName'] ?? 'Unknown'}",
                      ),
                      trailing: Icon(
                        isPaid ? Icons.check_circle : Icons.warning,
                        color: isPaid ? Colors.green : Colors.red,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CLOSE"),
          ),
        ],
      ),
    );
  }

  // --- 3. ቲኬት የመቁረጥ ሎጂክ (Issue Ticket) ---
  void _issueTicket() async {
    if (_plateController.text.isEmpty || _amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill required fields")),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    String ticketId =
        "TKT-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}";

    try {
      await FirebaseFirestore.instance.collection('tickets').doc(ticketId).set({
        'ticketId': ticketId,
        'plate': _plateController.text.toUpperCase(),
        'ownerName': _ownerNameController.text.trim(),
        'ownerPhone': _ownerPhoneController.text.trim(),
        'violation': _selectedViolation,
        'amount': double.parse(_amountController.text),
        'status': 'UNPAID',
        'officerId': widget.officerId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.pop(context);

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Icon(Icons.check_circle, color: Colors.green, size: 50),
          content: Text(
            "Ticket Generated!\n\nID: $ticketId\nPlate: ${_plateController.text}\nOwner: ${_ownerNameController.text}",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _plateController.clear();
                _amountController.clear();
                _ownerNameController.clear();
                _ownerPhoneController.clear();
              },
              child: const Text("OK"),
            ),
          ],
        ),
      );
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error: Check internet or inputs")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Officer: ${widget.officerId}"),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _showOfficerHistory,
            icon: const Icon(Icons.person_pin),
          ), // PROFILE BUTTON
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "ISSUE NEW VIOLATION",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _plateController,
              decoration: const InputDecoration(
                labelText: "Vehicle Plate Number *",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _ownerNameController,
              decoration: const InputDecoration(
                labelText: "Driver/Owner Name",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _ownerPhoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: "Owner Phone Number",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            DropdownButtonFormField(
              initialValue: _selectedViolation,
              decoration: const InputDecoration(
                labelText: "Violation Type",
                border: OutlineInputBorder(),
              ),
              items: _violations
                  .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                  .toList(),
              onChanged: (val) => setState(() => _selectedViolation = val!),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Fine Amount (ETB) *",
                border: OutlineInputBorder(),
                prefixText: "ETB ",
              ),
            ),
            const SizedBox(height: 25),
            ElevatedButton(
              onPressed: _issueTicket,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 60),
                backgroundColor: Colors.orange[800],
                foregroundColor: Colors.white,
              ),
              child: const Text("GENERATE DIGITAL TICKET"),
            ),
            const SizedBox(height: 15),
            OutlinedButton.icon(
              onPressed: _verifyVehicle,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                side: const BorderSide(color: Colors.blue, width: 2),
              ),
              icon: const Icon(Icons.verified),
              label: const Text("VERIFY PLATE STATUS"),
            ),
          ],
        ),
      ),
    );
  }
}
