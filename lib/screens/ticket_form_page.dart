import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class TicketFormPage extends StatefulWidget {
  final String officerId;
  const TicketFormPage({super.key, required this.officerId});

  @override
  State<TicketFormPage> createState() => _TicketFormPageState();
}

class _TicketFormPageState extends State<TicketFormPage> {
  final _plateController = TextEditingController();
  final _amountController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _ownerPhoneController = TextEditingController();
  String _selectedViolation = 'Speeding';

  // --- Date Filter States ---
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();

  final List<String> _violations = [
    'Speeding',
    'Illegal Parking',
    'No License',
    'Wrong Way',
    'Overloading',
  ];

  // --- 1. PDF REPORT GENERATOR ---
  Future<void> _generateOfficerReport(List<QueryDocumentSnapshot> docs) async {
    final pdf = pw.Document();
    double totalFine = 0;
    for (var doc in docs) {
      totalFine += (doc['amount'] ?? 0);
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(level: 0, child: pw.Text("Officer Performance Report")),
          pw.Text("Officer ID: ${widget.officerId}"),
          pw.Text(
              "Report Period: ${DateFormat('MMM d, y').format(_startDate)} - ${DateFormat('MMM d, y').format(_endDate)}"),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            headers: ['Date', 'Plate', 'Violation', 'Amount', 'Status'],
            data: docs.map((doc) {
              var d = doc.data() as Map<String, dynamic>;
              return [
                d['timestamp'] != null
                    ? DateFormat('MM/dd').format(
                        (d['timestamp'] as Timestamp).toDate())
                    : '',
                d['plate'],
                d['violation'],
                "${d['amount']} ETB",
                d['status'],
              ];
            }).toList(),
          ),
          pw.SizedBox(height: 20),
          pw.Container(
            alignment: pw.Alignment.centerRight,
            child: pw.Text("TOTAL ISSUED: ${totalFine.toStringAsFixed(2)} ETB",
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }

  // --- 2. HISTORY MODAL WITH FILTERS & PDF ---
  void _showOfficerHistory() {
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

                  // Header & Filters
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    child: Column(
                      children: [
                        // Title Row with PDF Button
                        // Note: The PDF button is inside the StreamBuilder below
                        // so it has access to the data, but we put the header here.
                      ],
                    ),
                  ),

                  // Data List & Stream
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('tickets')
                          .where('officerId', isEqualTo: widget.officerId)
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
                        if (snapshot.hasError) {
                          return Center(
                              child: Text("Error: ${snapshot.error}"));
                        }
                        if (!snapshot.hasData) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }

                        var docs = snapshot.data!.docs;

                        // --- INSIDE BUILDER TO ACCESS DOCS FOR PDF ---
                        return Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 15),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        "PERFORMANCE LOGS",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      // RED PDF BUTTON
                                      IconButton(
                                        icon: const Icon(Icons.picture_as_pdf,
                                            color: Colors.red, size: 28),
                                        onPressed: docs.isEmpty
                                            ? null
                                            : () => _generateOfficerReport(docs),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  // FILTERS ROW
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      _filterBtn(setModalState, "Today", 0),
                                      _filterBtn(setModalState, "7 Days", 7),
                                      _filterBtn(setModalState, "30 Days", 30),
                                      _filterBtn(setModalState, "1 Year", 365),
                                      IconButton(
                                        icon: const Icon(Icons.date_range,
                                            color: Colors.blue),
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
                            
                            // THE LIST
                            Expanded(
                              child: docs.isEmpty
                                  ? const Center(
                                      child: Text(
                                          "No records found for this period."))
                                  : ListView.builder(
                                      controller: scrollController,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 15),
                                      itemCount: docs.length,
                                      itemBuilder: (context, index) {
                                        var data = docs[index].data()
                                            as Map<String, dynamic>;
                                        bool isPaid = data['status'] == 'PAID';
                                        return Card(
                                          elevation: 0,
                                          margin:
                                              const EdgeInsets.only(bottom: 8),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            side: BorderSide(
                                                color: Colors.grey[200]!),
                                          ),
                                          child: ListTile(
                                            leading: CircleAvatar(
                                              backgroundColor: isPaid
                                                  ? Colors.green[50]
                                                  : Colors.red[50],
                                              child: Icon(
                                                isPaid
                                                    ? Icons.check
                                                    : Icons.timer,
                                                color: isPaid
                                                    ? Colors.green
                                                    : Colors.red,
                                                size: 20,
                                              ),
                                            ),
                                            title: Text(
                                              data['plate'],
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            subtitle: Text(
                                              "${data['violation']} • ${data['amount']} ETB",
                                            ),
                                            trailing: Text(
                                              data['timestamp'] != null
                                                  ? DateFormat('MMM d').format(
                                                      (data['timestamp']
                                                              as Timestamp)
                                                          .toDate(),
                                                    )
                                                  : "",
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey,
                                              ),
                                            ),
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

  // --- 3. PLATE VERIFICATION ---
  void _verifyVehicle() async {
    String plate = _plateController.text.trim().toUpperCase();
    if (plate.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Enter plate first")));
      return;
    }
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Records for: $plate"),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('tickets')
                .where('plate', isEqualTo: plate)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              var tickets = snapshot.data!.docs;
              if (tickets.isEmpty) {
                return const Center(child: Text("Clean Record."));
              }
              return ListView.builder(
                itemCount: tickets.length,
                itemBuilder: (context, index) {
                  var data = tickets[index].data() as Map<String, dynamic>;
                  bool isPaid = data['status'] == 'PAID';
                  return Card(
                    color: isPaid ? Colors.green.shade50 : Colors.red.shade50,
                    child: ListTile(
                      title: Text(
                        "${data['violation']} - ${data['amount']} ETB",
                      ),
                      subtitle: Text(
                        "Status: ${data['status']}\nOwner: ${data['ownerName']}",
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
      ),
    );
  }

  // --- 4. ISSUE TICKET & SHOW CENTER POPUP ---
  void _issueTicket() async {
    if (_plateController.text.isEmpty || _amountController.text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Fill all fields")));
      return;
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    String tID =
        "TKT-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}";
    String plate = _plateController.text.toUpperCase();
    String violation = _selectedViolation;
    String amount = _amountController.text;

    try {
      await FirebaseFirestore.instance.collection('tickets').doc(tID).set({
        'ticketId': tID,
        'plate': plate,
        'ownerName': _ownerNameController.text.trim(),
        'ownerPhone': _ownerPhoneController.text.trim(),
        'violation': violation,
        'amount': double.parse(amount),
        'status': 'UNPAID',
        'officerId': widget.officerId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      Navigator.pop(context); // Close loading

      // Clear inputs
      _plateController.clear();
      _amountController.clear();
      _ownerNameController.clear();
      _ownerPhoneController.clear();

      // SHOW CENTER TICKET
      _showCenterTicket(tID, plate, violation, amount);
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Upload Error")));
    }
  }

  // --- 5. CENTER POPUP UI ---
  void _showCenterTicket(
      String id, String plate, String violation, String amount) {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevents closing by clicking outside
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "ባህርዳር ከተማ አስተዳደር ትራፊክ ጽ/ቤት",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              "Bahirdar City Administration Traffic Office",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 10),
            const Icon(Icons.qr_code_2, size: 80, color: Colors.black),
            const Text("OFFICIAL TICKET",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            const Divider(),
            const SizedBox(height: 10),
            _ticketRow("Ticket ID", id),
            _ticketRow("Plate", plate),
            _ticketRow("Violation", violation),
            _ticketRow("Fine", "$amount ETB"),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade900,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 45)),
              onPressed: () => Navigator.pop(context),
              child: const Text("CLOSE TICKET"),
            )
          ],
        ),
      ),
    );
  }

  Widget _ticketRow(String label, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(val, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Officer: ${widget.officerId}"),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _showOfficerHistory,
            icon: const Icon(Icons.history_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
            color: Colors.white,
            child: const Column(
              children: [
                Text(
                  "ባህርዳር ከተማ አስተዳደር ትራፊክ ጽ/ቤት",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  "Bahirdar City Administration Traffic Office",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text(
                    "ISSUE NEW VIOLATION",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _plateController,
                    decoration: const InputDecoration(
                      labelText: "Plate Number",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: _ownerNameController,
                    decoration: const InputDecoration(
                      labelText: "Driver Name",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: _ownerPhoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: "Phone",
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
                      labelText: "Fine Amount (ETB)",
                      prefixText: "ETB ",
                      border: OutlineInputBorder(),
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
                    ),
                    icon: const Icon(Icons.verified),
                    label: const Text("VERIFY PLATE STATUS"),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
