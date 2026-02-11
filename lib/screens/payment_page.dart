import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ClerkPaymentPage extends StatefulWidget {
  final String clerkId;
  const ClerkPaymentPage({super.key, required this.clerkId});

  @override
  State<ClerkPaymentPage> createState() => _ClerkPaymentPageState();
}

class _ClerkPaymentPageState extends State<ClerkPaymentPage> {
  final _searchController = TextEditingController();

  // --- Date Filter States ---
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();

  // --- 1. GENERATE SUMMARY REPORT (PDF for History) ---
  Future<void> _generateClerkReport(List<QueryDocumentSnapshot> docs) async {
    final pdf = pw.Document();
    double totalCollected = 0;

    // Calculate Total
    for (var doc in docs) {
      totalCollected += (doc['amount'] ?? 0);
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(level: 0, child: pw.Text("Payment Collection Report")),
          pw.Text("Clerk ID: ${widget.clerkId}"),
          pw.Text(
            "Period: ${DateFormat('MMM d, y').format(_startDate)} - ${DateFormat('MMM d, y').format(_endDate)}",
          ),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            headers: ['Date', 'Plate', 'Ticket ID', 'Amount'],
            data: docs.map((doc) {
              var d = doc.data() as Map<String, dynamic>;
              return [
                d['paidAt'] != null
                    ? DateFormat(
                        'MM/dd HH:mm',
                      ).format((d['paidAt'] as Timestamp).toDate())
                    : 'N/A',
                d['plate'],
                d['ticketId'],
                "${d['amount']} ETB",
              ];
            }).toList(),
          ),
          pw.SizedBox(height: 20),
          pw.Divider(),
          pw.Container(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              "TOTAL COLLECTED: ${totalCollected.toStringAsFixed(2)} ETB",
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
            ),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }

  // --- 2. GENERATE SINGLE RECEIPT (For one payment) ---
  Future<void> _generateDigitalReceipt(Map<String, dynamic> data) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                "TRAFFIC PAYMENT RECEIPT",
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              pw.Divider(),
              pw.SizedBox(height: 10),
              pw.BarcodeWidget(
                barcode: pw.Barcode.qrCode(),
                data: data['ticketId'],
                width: 80,
                height: 80,
              ),
              pw.SizedBox(height: 10),
              pw.Text("Ticket ID: ${data['ticketId']}"),
              pw.SizedBox(height: 5),
              pw.TableHelper.fromTextArray(
                context: context,
                data: <List<String>>[
                  ['Plate', '${data['plate']}'],
                  ['Driver', '${data['ownerName']}'],
                  ['Violation', '${data['violation']}'],
                  ['Amount', '${data['amount']} ETB'],
                  [
                    'Date',
                    (DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())),
                  ],
                  ['Clerk', widget.clerkId],
                ],
                cellStyle: const pw.TextStyle(fontSize: 9),
                headerStyle: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                "Thank you for complying!",
                style: pw.TextStyle(
                  fontStyle: pw.FontStyle.italic,
                  fontSize: 10,
                ),
              ),
            ],
          );
        },
      ),
    );
    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }

  // --- 3. PROCESS PAYMENT LOGIC ---
  void _processPayment(String docId, Map<String, dynamic> ticketData) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await FirebaseFirestore.instance.collection('tickets').doc(docId).update({
        'status': 'PAID',
        'paidAt': FieldValue.serverTimestamp(),
        'processedByClerk': widget.clerkId,
      });

      Navigator.pop(context); // Close loading

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Payment Confirmed!")));

      // Auto-print receipt
      _generateDigitalReceipt(ticketData);
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  // --- 4. HISTORY MODAL (Updated with Calendar & Filters) ---
  void _showPaymentHistory() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey[50],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return DraggableScrollableSheet(
            initialChildSize: 0.9,
            maxChildSize: 0.95,
            expand: false,
            builder: (context, scrollController) {
              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('tickets')
                    .where('status', isEqualTo: 'PAID')
                    .where(
                      'timestamp',
                      isGreaterThanOrEqualTo: Timestamp.fromDate(
                        DateTime(
                          _startDate.year,
                          _startDate.month,
                          _startDate.day,
                        ),
                      ),
                    )
                    .where(
                      'timestamp',
                      isLessThanOrEqualTo: Timestamp.fromDate(
                        DateTime(
                          _endDate.year,
                          _endDate.month,
                          _endDate.day,
                          23,
                          59,
                          59,
                        ),
                      ),
                    )
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData)
                    return const Center(child: CircularProgressIndicator());

                  var docs = snapshot.data!.docs;

                  // Calculate live total for the UI
                  double currentTotal = 0;
                  for (var doc in docs) {
                    currentTotal += (doc['amount'] ?? 0);
                  }

                  return Column(
                    children: [
                      // Drag Handle
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 12),
                        height: 5,
                        width: 40,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),

                      // HEADER & FILTERS
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "PAYMENT LOGS",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      "Total: ${currentTotal.toStringAsFixed(0)} ETB",
                                      style: TextStyle(
                                        color: Colors.green[700],
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                // RED PDF BUTTON
                                IconButton(
                                  icon: const Icon(
                                    Icons.picture_as_pdf,
                                    color: Colors.red,
                                    size: 28,
                                  ),
                                  onPressed: docs.isEmpty
                                      ? null
                                      : () => _generateClerkReport(docs),
                                ),
                              ],
                            ),
                            const SizedBox(height: 15),

                            // DATE FILTERS
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _filterBtn(setModalState, "Today", 0),
                                _filterBtn(setModalState, "7 Days", 7),
                                _filterBtn(setModalState, "30 Days", 30),
                                _filterBtn(setModalState, "1 Year", 365),
                                IconButton(
                                  icon: const Icon(
                                    Icons.date_range,
                                    color: Colors.blue,
                                  ),
                                  onPressed: () async {
                                    final DateTimeRange? picked =
                                        await showDateRangePicker(
                                          context: context,
                                          firstDate: DateTime(2023),
                                          lastDate: DateTime.now(),
                                          initialDateRange: DateTimeRange(
                                            start: _startDate,
                                            end: _endDate,
                                          ),
                                        );
                                    if (picked != null) {
                                      setModalState(() {
                                        _startDate = picked.start;
                                        _endDate = picked.end;
                                      });
                                    }
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              "Period: ${DateFormat('MMM d, y').format(_startDate)} - ${DateFormat('MMM d, y').format(_endDate)}",
                              style: TextStyle(
                                color: Colors.blue[800],
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const Divider(height: 30),
                          ],
                        ),
                      ),

                      // THE LIST OF PAYMENTS
                      Expanded(
                        child: docs.isEmpty
                            ? const Center(
                                child: Text(
                                  "No payments collected in this range",
                                ),
                              )
                            : ListView.builder(
                                controller: scrollController,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 15,
                                ),
                                itemCount: docs.length,
                                itemBuilder: (context, index) {
                                  var data =
                                      docs[index].data()
                                          as Map<String, dynamic>;
                                  return Card(
                                    elevation: 0,
                                    margin: const EdgeInsets.only(bottom: 8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(
                                        color: Colors.grey[200]!,
                                      ),
                                    ),
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: Colors.green[50],
                                        child: const Icon(
                                          Icons.attach_money,
                                          color: Colors.green,
                                        ),
                                      ),
                                      title: Text(
                                        data['plate'],
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      subtitle: Text(
                                        "ID: ${data['ticketId']} • ${data['violation']}",
                                      ),
                                      trailing: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            "${data['amount']} ETB",
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black,
                                            ),
                                          ),
                                          Text(
                                            data['paidAt'] != null
                                                ? DateFormat(
                                                    'MM/dd HH:mm',
                                                  ).format(
                                                    (data['paidAt']
                                                            as Timestamp)
                                                        .toDate(),
                                                  )
                                                : "",
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  // Filter Button Helper
  Widget _filterBtn(Function setModalState, String label, int days) {
    bool isSelected = DateTime.now().difference(_startDate).inDays == days;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (bool selected) {
        setModalState(() {
          _endDate = DateTime.now();
          _startDate = DateTime.now().subtract(Duration(days: days));
        });
      },
      selectedColor: Colors.blue[100],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Clerk Payment Portal"),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _showPaymentHistory,
            icon: const Icon(Icons.history, size: 28),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Section
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Enter Plate Number (e.g. AA 12345)",
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => setState(() {
                    _searchController.clear();
                  }),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              onChanged: (val) => setState(() {}),
            ),
          ),

          // Results Section
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('tickets')
                  .where(
                    'plate',
                    isEqualTo: _searchController.text.trim().toUpperCase(),
                  )
                  .where('status', isEqualTo: 'UNPAID')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());

                var results = snapshot.data!.docs;

                if (_searchController.text.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search, size: 60, color: Colors.grey),
                        SizedBox(height: 10),
                        Text(
                          "Search for a vehicle to process payment",
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                if (results.isEmpty) {
                  return const Center(
                    child: Text("No unpaid tickets found for this plate."),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(15),
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    var data = results[index].data() as Map<String, dynamic>;
                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.only(bottom: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(15),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      data['plate'],
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 20,
                                      ),
                                    ),
                                    Text(
                                      "Violation: ${data['violation']}",
                                      style: TextStyle(color: Colors.grey[700]),
                                    ),
                                  ],
                                ),
                                Text(
                                  "${data['amount']} ETB",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 25),
                            ElevatedButton.icon(
                              onPressed: () =>
                                  _processPayment(results[index].id, data),
                              icon: const Icon(Icons.payment),
                              label: const Text(
                                "PROCESS PAYMENT & PRINT RECEIPT",
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade700,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(double.infinity, 50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
