import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  void _issueTicket() async {
    // 1. Show a loading circle so the officer knows the app is working
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    String ticketId = "TKT-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}";
    
    try {
      await FirebaseFirestore.instance.collection('tickets').doc(ticketId).set({
        'ticketId': ticketId,
        'plate': _plateController.text,
        'violation': _selectedViolation,
        'amount': double.parse(_amountController.text),
        'status': 'UNPAID',
        'officerId': widget.officerId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.pop(context); // Remove loading circle

      // 2. Show the Success Popup
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Icon(Icons.check_circle, color: Colors.green, size: 50),
          content: Text("Ticket Generated!\n\nID: $ticketId\nPlate: ${_plateController.text}"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                _plateController.clear(); // Clear form for next ticket
                _amountController.clear();
              }, 
              child: const Text("OK")
            )
          ],
        ),
      );
    } catch (e) {
      Navigator.pop(context); // Remove loading circle
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Cloud Error: Check your internet or Firebase Rules")),
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
            ElevatedButton(
              onPressed: _issueTicket,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 60),
                backgroundColor: Colors.orange[800],
                foregroundColor: Colors.white,
              ),
              child: const Text("GENERATE DIGITAL TICKET"),
            ),
          ],
        ),
      ),
    );
  }
}
