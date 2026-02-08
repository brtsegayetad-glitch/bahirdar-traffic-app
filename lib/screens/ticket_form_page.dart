import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // ቀን ለመጻፍ ያስፈልገናል

class TicketFormPage extends StatefulWidget {
  final String officerId;
  const TicketFormPage({super.key, required this.officerId});

  @override
  State<TicketFormPage> createState() => _TicketFormPageState();
}

class _TicketFormPageState extends State<TicketFormPage> {
  final _plateController = TextEditingController();
  final _amountController = TextEditingController();
  String _selectedViolation = 'Speeding';

  final List<String> _violations = [
    'Speeding',
    'Illegal Parking',
    'No License',
    'Wrong Way',
    'Overloading',
  ];

  // --- 1. እዚህ ጋር ነው Verification Logic የምንጨምረው ---
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

              if (tickets.isEmpty) {
                return const Center(child: Text("No violation record found."));
              }

              return ListView.builder(
                itemCount: tickets.length,
                itemBuilder: (context, index) {
                  var data = tickets[index].data() as Map<String, dynamic>;
                  bool isPaid = data['status'] == 'PAID';

                  // --- ቀኑን የማንበቢያ ኮድ ---
                  String formattedDate = "No Date";
                  if (data['timestamp'] != null) {
                    DateTime date = (data['timestamp'] as Timestamp).toDate();
                    formattedDate = DateFormat(
                      'yMMMd',
                    ).format(date); // ለምሳሌ፡ Feb 8, 2026
                  }

                  return Card(
                    color: isPaid ? Colors.green.shade50 : Colors.red.shade50,
                    child: ListTile(
                      title: Text(
                        "${data['violation']} - ${data['amount']} ETB",
                      ),
                      subtitle: Text(
                        "Status: ${data['status']}\nDate: $formattedDate",
                      ), // ቀኑ እዚህ ይታያል
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

  void _issueTicket() async {
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
        'violation': _selectedViolation,
        'amount': double.parse(_amountController.text),
        'status': 'UNPAID',
        'officerId': widget.officerId,
        'timestamp': FieldValue.serverTimestamp(), // ለዳሽቦርድ ማጣሪያ ይጠቅመናል
      });

      if (!mounted) return;
      Navigator.pop(context);

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Icon(Icons.check_circle, color: Colors.green, size: 50),
          content: Text(
            "Ticket Generated!\n\nID: $ticketId\nPlate: ${_plateController.text}",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _plateController.clear();
                _amountController.clear();
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
                labelText: "Vehicle Plate Number",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
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
            const SizedBox(height: 20),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Fine Amount (ETB)",
                border: OutlineInputBorder(),
                prefixText: "ETB ",
              ),
            ),
            const SizedBox(height: 30),

            // --- 2. እዚህ ጋር ነው በተኑን የምንጨምረው ---
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
