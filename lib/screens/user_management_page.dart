import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart'; // ስልክ ለመደወል እንዲረዳን

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  final _idController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController(); // NEW: Phone Number
  final _passwordController = TextEditingController();
  String _selectedRole = 'officer';

  void _addUser() async {
    String id = _idController.text.trim().toUpperCase();
    String name = _nameController.text.trim();
    String phone = _phoneController.text.trim();
    String pass = _passwordController.text.trim();

    if (id.isEmpty || name.isEmpty || pass.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Please fill all fields (ID, Name, Phone, and Password)",
          ),
        ),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('users').doc(id).set({
        'name': name,
        'phone': phone, // ስልክ ቁጥር እዚህ ጋር ይገባል
        'role': _selectedRole,
        'password': pass,
        'mustChangePassword': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("$name Registered Successfully!")));

      _idController.clear();
      _nameController.clear();
      _phoneController.clear();
      _passwordController.clear();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("STAFF DIRECTORY")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // --- REGISTRATION FORM (Wrapped in Padding to fix the error) ---
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(
                  16.0,
                ), // Fixed the Card padding error here
                child: Column(
                  children: [
                    const Text(
                      "ADD NEW STAFF",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: "Full Name"),
                    ),
                    TextField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: "Phone Number",
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    TextField(
                      controller: _idController,
                      decoration: const InputDecoration(
                        labelText: "Badge/Staff ID",
                      ),
                    ),
                    TextField(
                      controller: _passwordController,
                      decoration: const InputDecoration(
                        labelText: "Initial Password",
                      ),
                      obscureText: true,
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedRole,
                      items: ['officer', 'clerk']
                          .map(
                            (r) => DropdownMenuItem(
                              value: r,
                              child: Text(r.toUpperCase()),
                            ),
                          )
                          .toList(),
                      onChanged: (val) => setState(() => _selectedRole = val!),
                    ),
                    const SizedBox(height: 15),
                    ElevatedButton(
                      onPressed: _addUser,
                      child: const Text("REGISTER"),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "ACTIVE STAFF LIST",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const Divider(),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  var users = snapshot.data!.docs;
                  return ListView.builder(
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      var user = users[index].data() as Map<String, dynamic>;
                      String userId = users[index].id;
                      String phone = user['phone'] ?? "";

                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text(
                              (user['name'] != null &&
                                      user['name'].toString().isNotEmpty)
                                  ? user['name'].toString()[0].toUpperCase()
                                  : "?",
                            ),
                          ),
                          title: Text(user['name'] ?? "No Name"),
                          subtitle: Text("ID: $userId | $phone"),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // መደወያ ቁልፍ (Call Button)
                              IconButton(
                                icon: const Icon(
                                  Icons.call,
                                  color: Colors.green,
                                ),
                                onPressed: () async {
                                  final Uri url = Uri.parse('tel:$phone');
                                  if (await canLaunchUrl(url)) {
                                    await launchUrl(url);
                                  }
                                },
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                onPressed: () => FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(userId)
                                    .delete(),
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
      ),
    );
  }
}
