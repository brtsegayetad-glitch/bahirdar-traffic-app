import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

class PaymentPage extends StatefulWidget {
  final String clerkId;
  const PaymentPage({super.key, required this.clerkId});

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  final _searchController = TextEditingController();
  bool _isLoading = false;
  List<DocumentSnapshot> _foundTickets = [];
  bool _hasSearched = false;

  void _searchTickets() async {
    if (_searchController.text.isEmpty) return;
    setState(() {
      _isLoading = true;
      _hasSearched = true;
      _foundTickets = [];
    });

    String searchText = _searchController.text.trim().toUpperCase();

    var byId = await FirebaseFirestore.instance
        .collection('tickets')
        .doc(searchText)
        .get();

    if (byId.exists) {
      setState(() {
        _foundTickets = [byId];
        _isLoading = false;
      });
    } else {
      var byPlate = await FirebaseFirestore.instance
          .collection('tickets')
          .where('plate', isEqualTo: searchText)
          .where('status', isEqualTo: 'UNPAID')
          .get();

      setState(() {
        _foundTickets = byPlate.docs;
        _isLoading = false;
      });
    }
  }

  void _processPayment(DocumentSnapshot ticket, String method) async {
    String ticketId = ticket.id;
    double amount = (ticket['amount'] ?? 0).toDouble();
    String plate = ticket['plate'];
    String ownerName = ticket['ownerName'] ?? "N/A"; // ከቲኬቱ ስሙን እናነባለን
    String receiptNo =
        "BD-REV-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}";

    DateTime now = DateTime.now();

    await FirebaseFirestore.instance
        .collection('tickets')
        .doc(ticketId)
        .update({
          'status': 'PAID',
          'paymentMethod': method,
          'paymentDate': FieldValue.serverTimestamp(),
          'clerkId': widget.clerkId,
          'receiptNo': receiptNo,
        });

    await FirebaseFirestore.instance.collection('audit_logs').add({
      'action': 'PAYMENT_COLLECTED',
      'ticketId': ticketId,
      'amount': amount,
      'clerkId': widget.clerkId,
      'method': method,
      'timestamp': FieldValue.serverTimestamp(),
      'receiptNo': receiptNo,
      'ownerName': ownerName,
    });

    _showReceipt(receiptNo, plate, amount, method, now, ownerName);
  }

  void _showReceipt(
    String receiptNo,
    String plate,
    double amount,
    String method,
    DateTime date,
    String ownerName,
  ) {
    String formattedDate = DateFormat('MMM d, yyyy - h:mm a').format(date);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Center(child: Text("OFFICIAL RECEIPT")),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            QrImageView(data: receiptNo, size: 150),
            Text(
              "Receipt: $receiptNo",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const Divider(),
            Text(
              "Date: $formattedDate",
              style: const TextStyle(color: Colors.blueGrey, fontSize: 13),
            ),
            const SizedBox(height: 5),
            Text(
              "Owner: $ownerName",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ), // ስም ተጨምሯል
            Text("Plate: $plate"),
            Text("Amount: $amount ETB"),
            Text("Method: $method"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _searchTickets();
            },
            child: const Text("DONE"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Clerk: ${widget.clerkId}"),
        backgroundColor: Colors.green.shade800,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: "Search Ticket ID or Plate Number...",
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _searchTickets(),
            ),
          ),
          if (_isLoading) const CircularProgressIndicator(),
          Expanded(
            child: _foundTickets.isEmpty && _hasSearched
                ? const Center(child: Text("No Unpaid Tickets Found"))
                : ListView.builder(
                    itemCount: _foundTickets.length,
                    itemBuilder: (context, index) {
                      var tkt = _foundTickets[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: ListTile(
                          title: Text("Plate: ${tkt['plate']}"),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Owner: ${tkt['ownerName'] ?? 'N/A'}",
                                style: const TextStyle(color: Colors.blueGrey),
                              ), // ክፍያ ከመቀበል በፊት ለማየት
                              Text("Fine: ${tkt['amount']} ETB"),
                            ],
                          ),
                          trailing: ElevatedButton(
                            onPressed: () => _showPaymentOptions(tkt),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                            ),
                            child: const Text(
                              "PAY",
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton.icon(
              onPressed: _showClerkHistory,
              icon: const Icon(Icons.history),
              label: const Text("MY PAYMENT HISTORY"),
            ),
          ),
        ],
      ),
    );
  }

  void _showPaymentOptions(DocumentSnapshot tkt) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ListTile(
            title: Text(
              "Select Payment Method",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.phone_android, color: Colors.blue),
            title: const Text("Telebirr"),
            onTap: () {
              Navigator.pop(context);
              _processPayment(tkt, "Telebirr");
            },
          ),
          ListTile(
            leading: const Icon(Icons.account_balance, color: Colors.purple),
            title: const Text("Bank Transfer"),
            onTap: () {
              Navigator.pop(context);
              _processPayment(tkt, "Bank Transfer");
            },
          ),
          ListTile(
            leading: const Icon(Icons.money, color: Colors.green),
            title: const Text("Cash"),
            onTap: () {
              Navigator.pop(context);
              _processPayment(tkt, "Cash");
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _showClerkHistory() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('tickets')
              .where('clerkId', isEqualTo: widget.clerkId)
              .where('status', isEqualTo: 'PAID')
              .orderBy('paymentDate', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError)
              return Center(child: Text("Error: ${snapshot.error}"));
            if (!snapshot.hasData)
              return const Center(child: CircularProgressIndicator());

            var myDocs = snapshot.data!.docs;
            return Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    "MY PAYMENT HISTORY",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: myDocs.isEmpty
                      ? const Center(child: Text("No payments collected yet."))
                      : ListView.builder(
                          itemCount: myDocs.length,
                          itemBuilder: (context, index) {
                            var data =
                                myDocs[index].data() as Map<String, dynamic>;
                            String dateStr = "";
                            if (data['paymentDate'] != null) {
                              dateStr = DateFormat('MMM d, h:mm a').format(
                                (data['paymentDate'] as Timestamp).toDate(),
                              );
                            }

                            return ListTile(
                              leading: const Icon(
                                Icons.receipt_long,
                                color: Colors.green,
                              ),
                              title: Text("Plate: ${data['plate']}"),
                              subtitle: Text(
                                "Owner: ${data['ownerName'] ?? 'N/A'}\nDate: $dateStr",
                              ),
                              trailing: Text(
                                "${data['amount']} ETB",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              isThreeLine: true,
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
