import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';

class PaymentPage extends StatefulWidget {
  const PaymentPage({super.key});

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  final _ticketSearchController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _ticketFound = false;

  // Mock data for the pilot
  String? _foundPlate;
  String? _foundAmount;

  void _searchTicket() async {
    if (_ticketSearchController.text.isEmpty) return;

    // Look for the ticket in the Cloud
    var doc = await FirebaseFirestore.instance
        .collection('tickets')
        .doc(_ticketSearchController.text)
        .get();

    if (doc.exists) {
      setState(() {
        _ticketFound = true;
        _foundPlate = doc.data()!['plate'];
        _foundAmount = doc.data()!['amount'].toString();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Ticket Not Found in System")),
      );
    }
  }

  void _updateStatusInCloud(String method) async {
    // Update the ticket to 'PAID' so the supervisor knows
    await FirebaseFirestore.instance
        .collection('tickets')
        .doc(_ticketSearchController.text)
        .update({'status': 'PAID', 'paymentMethod': method});

    _processPayment(method); // Show the receipt popup
  }

  void _showTelebirrPrompt() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Telebirr Payment Push"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("The driver will enter their PIN on their own phone."),
            const SizedBox(height: 15),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: "Driver Phone Number",
                hintText: "09...",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCEL"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _simulatingWaitingForDriver();
            },
            child: const Text("SEND REQUEST"),
          ),
        ],
      ),
    );
  }

  void _simulatingWaitingForDriver() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text(
              "Waiting for Driver PIN...",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              "Driver is confirming on their phone",
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );

    Future.delayed(const Duration(seconds: 3), () {
      Navigator.pop(context);
      _updateStatusInCloud(
        'Telebirr',
      ); // Changed from _processPayment to _updateStatusInCloud
    });
  }

  void _processPayment(String method) async {
    // 1. Get the current date and time
    DateTime now = DateTime.now();

    // Format: "Feb 7, 2026 - 10:30 AM"
    String formattedDate =
        "${now.day}/${now.month}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

    // Create a unique Receipt Number
    String receiptNo =
        "BD-REV-${now.millisecondsSinceEpoch.toString().substring(5)}";

    // 2. Data "Baked" into the QR Code for verification
    String qrData =
        """
  OFFICIAL RECEIPT
  Receipt: $receiptNo
  Ticket: ${_ticketSearchController.text}
  Plate: $_foundPlate
  Date: $formattedDate
  Status: PAID via $method
  """;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Center(
          child: Text(
            "OFFICIAL DIGITAL RECEIPT",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Bahir Dar City Revenue Authority",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 5),
              Text(formattedDate, style: const TextStyle(fontSize: 12)),
              const Divider(),

              // THE QR CODE
              Container(
                alignment: Alignment.center,
                width: 180,
                height: 180,
                child: QrImageView(
                  data: qrData,
                  version: QrVersions.auto,
                  size: 180.0,
                  gapless: false,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Colors.black,
                  ),
                ),
              ),

              const SizedBox(height: 10),
              Text(
                "Receipt No: $receiptNo",
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
              Text("Plate: $_foundPlate", style: const TextStyle(fontSize: 14)),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Total Paid:"),
                  Text(
                    "$_foundAmount ETB",
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              const Text(
                "SCAN TO VERIFY RECORD",
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.share), onPressed: () {}),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _ticketFound = false;
                _ticketSearchController.clear();
              });
            },
            child: const Text("CLOSE & FINISH"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Bureau Payment"),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _ticketSearchController,
              decoration: InputDecoration(
                labelText: "Enter Ticket ID",
                suffixIcon: IconButton(
                  onPressed: _searchTicket,
                  icon: const Icon(Icons.search),
                ),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 30),
            if (_ticketFound) ...[
              Card(
                color: Colors.green[50],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      ListTile(
                        title: const Text("Vehicle Plate"),
                        subtitle: Text(_foundPlate!),
                      ),
                      ListTile(
                        title: const Text("Total Fine"),
                        subtitle: Text("ETB $_foundAmount"),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        onPressed: _showTelebirrPrompt,
                        icon: const Icon(Icons.phonelink_ring),
                        label: const Text("PAY VIA TELEBIRR PUSH"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[900],
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () =>
                            _updateStatusInCloud('Cash'), // Changed this too
                        child: const Text("Or Pay with Cash"),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
