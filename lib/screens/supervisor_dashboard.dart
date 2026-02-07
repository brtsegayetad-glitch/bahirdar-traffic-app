import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SupervisorDashboard extends StatefulWidget {
  const SupervisorDashboard({super.key});

  @override
  State<SupervisorDashboard> createState() => _SupervisorDashboardState();
}

class _SupervisorDashboardState extends State<SupervisorDashboard> {
  String _timeFilter = 'Today';
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Bureau Executive Dashboard"),
        backgroundColor: Colors.blue.shade900,
        foregroundColor: Colors.white,
        actions: [
          // THE CALENDAR BUTTON
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () async {
              DateTime? picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2024),
                lastDate: DateTime.now(),
              );
              if (picked != null) {
                setState(() {
                  _selectedDate = picked;
                  _timeFilter = "Custom"; // Switches filter when date is picked
                });
              }
            },
          ),
          DropdownButton<String>(
            value: _timeFilter == "Custom" ? null : _timeFilter,
            hint: const Text("Filter", style: TextStyle(color: Colors.white)),
            dropdownColor: Colors.blue.shade800,
            style: const TextStyle(color: Colors.white),
            underline: Container(), // Removes the default line
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

          double totalFinesIssued = 0; // Total debt created
          double totalRevenueCollected = 0; // Real money in bank
          int countPaid = 0;
          int countUnpaid = 0;
          Map<String, int> officerStats = {};

          for (var doc in docs) {
            var data = doc.data() as Map<String, dynamic>;
            double amount = (data['amount'] ?? 0.0).toDouble();
            String status = data['status'] ?? 'UNPAID';
            String officer = data['officerId'] ?? 'Unknown';

            // Add to total fines issued regardless of payment status
            totalFinesIssued += amount;

            if (status == 'PAID') {
              totalRevenueCollected += amount;
              countPaid++;
            } else {
              countUnpaid++;
            }
            officerStats[officer] = (officerStats[officer] ?? 0) + 1;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Highlight Total Fines in RED (The "Debt")
                _buildStatCard(
                  "Total Fines Issued (Debt)",
                  "${totalFinesIssued.toStringAsFixed(2)} ETB",
                  Colors.red,
                ),
                const SizedBox(height: 10),

                // Highlight Revenue in GREEN (The "Cash")
                _buildStatCard(
                  "Total Revenue Collected",
                  "${totalRevenueCollected.toStringAsFixed(2)} ETB",
                  Colors.green,
                ),
                const SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        "Paid Tickets",
                        "$countPaid",
                        Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildStatCard(
                        "Pending",
                        "$countUnpaid",
                        Colors.orange,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 25),
                Text(
                  "Viewing Data for: ${_timeFilter == 'Custom' ? _selectedDate.toString().split(' ')[0] : _timeFilter}",
                  style: const TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Colors.blueGrey,
                  ),
                ),

                const SizedBox(height: 20),
                const Text(
                  "Officer Activity",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const Divider(),
                ...officerStats.entries.map(
                  (e) => ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.blue,
                      child: Icon(Icons.person, color: Colors.white),
                    ),
                    title: Text("Officer: ${e.key}"),
                    trailing: Text(
                      "${e.value} Tickets",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

                const SizedBox(height: 30),
                const Text(
                  "City Heatmap (Simulation)",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 10),
                Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                    image: const DecorationImage(
                      image: NetworkImage(
                        'https://maps.googleapis.com/maps/api/staticmap?center=11.59,37.39&zoom=13&size=600x300&sensor=false',
                      ),
                      fit: BoxFit.cover,
                      opacity: 0.5,
                    ),
                  ),
                  child: const Center(
                    child: Text(
                      "High Activity: Bahir Dar Central Area",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: color, width: 6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black54,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
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
