import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'user_management_page.dart';

class SupervisorDashboard extends StatefulWidget {
  const SupervisorDashboard({super.key});

  @override
  State<SupervisorDashboard> createState() => _SupervisorDashboardState();
}

class _SupervisorDashboardState extends State<SupervisorDashboard> {
  String _timeFilter = 'Today';
  DateTime _selectedDate = DateTime.now();

  // የሰራተኛውን ዝርዝር ስራ የሚያሳይ Popup (Detailed Report)
  void _showStaffDetails(String staffId, String role, String name) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              "Activity Report: $name",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              "ID: $staffId | Role: ${role.toUpperCase()}",
              style: const TextStyle(color: Colors.grey),
            ),
            const Divider(),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('tickets')
                    .where(
                      role == 'officer' ? 'officerId' : 'clerkId',
                      isEqualTo: staffId,
                    )
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData)
                    return const Center(child: CircularProgressIndicator());
                  var docs = snapshot.data!.docs;
                  if (docs.isEmpty)
                    return const Center(
                      child: Text("No transactions recorded yet."),
                    );

                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      var data = docs[index].data() as Map<String, dynamic>;
                      return Card(
                        child: ListTile(
                          leading: const Icon(
                            Icons.receipt_long,
                            color: Colors.blueGrey,
                          ),
                          title: Text("Plate: ${data['plate']}"),
                          subtitle: Text(
                            "Amount: ${data['amount']} ETB | Status: ${data['status']}",
                          ),
                          trailing: Text(
                            data['timestamp'] != null
                                ? DateFormat('MMM d').format(
                                    (data['timestamp'] as Timestamp).toDate(),
                                  )
                                : "",
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("BUREAU OVERSIGHT & COMMAND"),
        backgroundColor: Colors.blue.shade900,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.group_add),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const UserManagementPage(),
              ),
            ),
            tooltip: "Staff Management",
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () async {
              DateTime? picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2024),
                lastDate: DateTime.now(),
              );
              if (picked != null)
                setState(() {
                  _selectedDate = picked;
                  _timeFilter = "Custom";
                });
            },
          ),
          DropdownButton<String>(
            value: _timeFilter == "Custom" ? null : _timeFilter,
            hint: const Text(
              "Filter",
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
            dropdownColor: Colors.blue.shade800,
            style: const TextStyle(color: Colors.white),
            underline: Container(),
            items: <String>['Today', 'Month', 'Year'].map((String value) {
              return DropdownMenuItem<String>(value: value, child: Text(value));
            }).toList(),
            onChanged: (newValue) => setState(() {
              _timeFilter = newValue!;
            }),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('tickets').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());

          var docs = snapshot.data!.docs;
          double totalFines = 0, totalRevenue = 0;
          int paidCount = 0, unpaidCount = 0;
          Map<String, int> officerStats = {};
          Map<String, double> methodStats = {};

          var filteredDocs = docs.where((doc) {
            var data = doc.data() as Map<String, dynamic>;
            if (data['timestamp'] == null) return true;
            DateTime docDate = (data['timestamp'] as Timestamp).toDate();
            DateTime now = DateTime.now();
            if (_timeFilter == 'Today')
              return docDate.day == now.day &&
                  docDate.month == now.month &&
                  docDate.year == now.year;
            if (_timeFilter == 'Month')
              return docDate.month == now.month && docDate.year == now.year;
            if (_timeFilter == 'Year') return docDate.year == now.year;
            if (_timeFilter == 'Custom')
              return docDate.day == _selectedDate.day &&
                  docDate.month == _selectedDate.month &&
                  docDate.year == _selectedDate.year;
            return true;
          }).toList();

          for (var doc in filteredDocs) {
            var data = doc.data() as Map<String, dynamic>;
            double amount = (data['amount'] ?? 0.0).toDouble();
            String status = data['status'] ?? 'UNPAID';
            String officer = data['officerId'] ?? 'Unknown';
            String method = data['paymentMethod'] ?? 'None';

            totalFines += amount;
            if (status == 'PAID') {
              totalRevenue += amount;
              paidCount++;
              methodStats[method] = (methodStats[method] ?? 0) + amount;
            } else {
              unpaidCount++;
            }
            officerStats[officer] = (officerStats[officer] ?? 0) + 1;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "View: ${_timeFilter == 'Custom' ? DateFormat('yMMMd').format(_selectedDate) : _timeFilter}",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey,
                  ),
                ),
                const SizedBox(height: 15),

                _buildStatCard(
                  "Total Fines Issued",
                  "${totalFines.toStringAsFixed(2)} ETB",
                  Colors.red,
                ),
                _buildStatCard(
                  "Revenue Collected",
                  "${totalRevenue.toStringAsFixed(2)} ETB",
                  Colors.green,
                ),

                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        "Paid Tickets",
                        "$paidCount",
                        Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildStatCard(
                        "Pending",
                        "$unpaidCount",
                        Colors.orange,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 30),
                const Text(
                  "OFFICER PERFORMANCE (Click to view details)",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const Divider(),
                ...officerStats.entries.map(
                  (e) => Card(
                    child: ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person)),
                      title: FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('users')
                            .doc(e.key)
                            .get(),
                        builder: (context, userSnap) {
                          String name =
                              (userSnap.hasData && userSnap.data!.exists)
                              ? userSnap.data!['name']
                              : e.key;
                          return Text(
                            name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          );
                        },
                      ),
                      subtitle: Text("Total Tickets: ${e.value}"),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                      onTap: () async {
                        var userDoc = await FirebaseFirestore.instance
                            .collection('users')
                            .doc(e.key)
                            .get();
                        String name = userDoc.exists ? userDoc['name'] : e.key;
                        _showStaffDetails(e.key, 'officer', name);
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 25),
                const Text(
                  "CLERK COLLECTION BY METHOD",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const Divider(),
                ...methodStats.entries.map(
                  (e) => ListTile(
                    leading: const Icon(
                      Icons.account_balance_wallet,
                      color: Colors.green,
                    ),
                    title: Text(e.key),
                    trailing: Text(
                      "${e.value.toStringAsFixed(2)} ETB",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 25),
                const Text(
                  "LIVE AUDIT TRAIL",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const Divider(),
                _buildAuditTrail(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAuditTrail() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('audit_logs')
            .orderBy('timestamp', descending: true)
            .limit(10)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var log =
                  snapshot.data!.docs[index].data() as Map<String, dynamic>;
              return ListTile(
                dense: true,
                title: Text("${log['action']} - ${log['amount']} ETB"),
                subtitle: Text("Ticket: ${log['ticketId']}"),
                trailing: const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 16,
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Card(
      elevation: 3,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: color, width: 5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
