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
  // Start with 'Today' range
  DateTime _startDate = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );
  DateTime _endDate = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
    23,
    59,
    59,
  );

  // Helper to update range from predefined buttons
  void _updateRange(int days) {
    setState(() {
      _endDate = DateTime.now();
      _startDate = DateTime.now().subtract(Duration(days: days));
      // Reset time to start of day for accuracy
      _startDate = DateTime(_startDate.year, _startDate.month, _startDate.day);
    });
  }

  void _showStaffDetails(String staffId, String role, String name) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Text(
                "Activity: $name",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                "Filter: ${DateFormat('yMMMd').format(_startDate)} - ${DateFormat('yMMMd').format(_endDate)}",
                style: const TextStyle(color: Colors.grey),
              ),
              const Divider(),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('tickets')
                      .where(
                        role == 'officer' ? 'officerId' : 'processedByClerk',
                        isEqualTo: staffId,
                      )
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData)
                      return const Center(child: CircularProgressIndicator());

                    // Filter by date locally to match the dashboard range
                    var docs = snapshot.data!.docs.where((doc) {
                      var ts = doc['timestamp'] as Timestamp?;
                      if (ts == null) return false;
                      return ts.toDate().isAfter(_startDate) &&
                          ts.toDate().isBefore(_endDate);
                    }).toList();

                    if (docs.isEmpty)
                      return const Center(
                        child: Text("No records for this period."),
                      );

                    return ListView.builder(
                      controller: scrollController,
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        var data = docs[index].data() as Map<String, dynamic>;
                        return Card(
                          child: ListTile(
                            title: Text("Plate: ${data['plate']}"),
                            subtitle: Text(
                              "Amt: ${data['amount']} ETB | Status: ${data['status']}",
                            ),
                            trailing: Text(
                              DateFormat('MMM d').format(
                                (data['timestamp'] as Timestamp).toDate(),
                              ),
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("COMMAND CENTER"),
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
          ),
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: () async {
              DateTimeRange? picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2024),
                lastDate: DateTime.now(),
                initialDateRange: DateTimeRange(
                  start: _startDate,
                  end: _endDate,
                ),
              );
              if (picked != null) {
                setState(() {
                  _startDate = picked.start;
                  _endDate = picked.end.add(
                    const Duration(hours: 23, minutes: 59),
                  );
                });
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('tickets').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());

          var allDocs = snapshot.data!.docs;

          // Apply Date Range Filter
          var filteredDocs = allDocs.where((doc) {
            var data = doc.data() as Map<String, dynamic>;
            if (data['timestamp'] == null) return false;
            DateTime docDate = (data['timestamp'] as Timestamp).toDate();
            return docDate.isAfter(_startDate) && docDate.isBefore(_endDate);
          }).toList();

          double totalFines = 0, totalRevenue = 0;
          int paidCount = 0, unpaidCount = 0;
          Map<String, int> officerStats = {};
          Map<String, double> clerkStats = {}; // Tracks money per clerk

          for (var doc in filteredDocs) {
            var data = doc.data() as Map<String, dynamic>;
            double amount = (data['amount'] ?? 0.0).toDouble();
            String status = data['status'] ?? 'UNPAID';
            String officer = data['officerId'] ?? 'Unknown';
            String clerk = data['processedByClerk'] ?? 'System/Unpaid';

            totalFines += amount;
            if (status == 'PAID') {
              totalRevenue += amount;
              paidCount++;
              clerkStats[clerk] = (clerkStats[clerk] ?? 0) + amount;
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
                // Quick Filter Chips
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ActionChip(
                      label: const Text("Today"),
                      onPressed: () => _updateRange(0),
                    ),
                    ActionChip(
                      label: const Text("7 Days"),
                      onPressed: () => _updateRange(7),
                    ),
                    ActionChip(
                      label: const Text("30 Days"),
                      onPressed: () => _updateRange(30),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    "Interval: ${DateFormat('yMMMd').format(_startDate)} - ${DateFormat('yMMMd').format(_endDate)}",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Main Stats
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        "Fines Issued",
                        "${totalFines.toStringAsFixed(0)} ETB",
                        Colors.red,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildStatCard(
                        "Revenue",
                        "${totalRevenue.toStringAsFixed(0)} ETB",
                        Colors.green,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard("Paid", "$paidCount", Colors.blue),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildStatCard(
                        "Unpaid",
                        "$unpaidCount",
                        Colors.orange,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 30),
                _sectionHeader("OFFICER ACTIVITY (Tickets Issued)"),
                ...officerStats.entries.map(
                  (e) =>
                      _buildUserTile(e.key, "Tickets: ${e.value}", 'officer'),
                ),

                const SizedBox(height: 30),
                _sectionHeader("CLERK PERFORMANCE (Collections)"),
                ...clerkStats.entries.map(
                  (e) => _buildUserTile(
                    e.key,
                    "Collected: ${e.value.toStringAsFixed(0)} ETB",
                    'clerk',
                  ),
                ),

                const SizedBox(height: 30),
                _sectionHeader("LIVE AUDIT TRAIL"),
                _buildAuditTrail(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.blueGrey,
        ),
      ),
    );
  }

  Widget _buildUserTile(String userId, String subtitle, String role) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
      builder: (context, snap) {
        String name = (snap.hasData && snap.data!.exists)
            ? snap.data!['name']
            : userId;
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: role == 'officer'
                  ? Colors.blue[100]
                  : Colors.green[100],
              child: Icon(
                role == 'officer' ? Icons.local_police : Icons.payments,
                size: 20,
              ),
            ),
            title: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(subtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showStaffDetails(userId, role, name),
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Card(
      elevation: 2,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: color, width: 4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
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

  Widget _buildAuditTrail() {
    return Container(
      height: 250,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('audit_logs')
            .orderBy('timestamp', descending: true)
            .limit(15)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          return ListView.separated(
            itemCount: snapshot.data!.docs.length,
            separatorBuilder: (c, i) => const Divider(height: 1),
            itemBuilder: (context, index) {
              var log =
                  snapshot.data!.docs[index].data() as Map<String, dynamic>;
              return ListTile(
                dense: true,
                leading: const Icon(
                  Icons.history_toggle_off,
                  size: 18,
                  color: Colors.blue,
                ),
                title: Text(
                  "${log['action']}",
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  "By: ${log['userEmail'] ?? 'Unknown'}",
                  style: const TextStyle(fontSize: 11),
                ),
                trailing: Text(
                  log['timestamp'] != null
                      ? DateFormat(
                          'HH:mm',
                        ).format((log['timestamp'] as Timestamp).toDate())
                      : "",
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
