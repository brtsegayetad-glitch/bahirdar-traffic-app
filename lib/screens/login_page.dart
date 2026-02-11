import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'ticket_form_page.dart';
import 'payment_page.dart';
import 'supervisor_dashboard.dart';
import 'change_password_page.dart'; // አዲሱን ገጽ እዚህ ጋር Import አድርግ

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _idController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isOfficerMode = true;
  bool _isLoading = false;

  void _handleAccess() async {
    String inputId = _idController.text.trim();
    String password = _passwordController.text.trim();

    if (inputId.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please fill all fields")));
      return;
    }

    setState(() => _isLoading = true);

    // 1. Hardcoded Boss Access (Always Works)
    if (inputId == "ADMIN99" && password == "BahirDar2026") {
      setState(() => _isLoading = false);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const SupervisorDashboard()),
      );
      return;
    }

    try {
      // 2. Fetch User from Firebase
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(inputId)
          .get();

      if (!userDoc.exists) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("ID '$inputId' not found! Please register it first."),
          ),
        );
        return;
      }

      var data = userDoc.data() as Map<String, dynamic>;
      String dbPassword = data['password'].toString().trim();
      String dbRole = data['role'].toString().toLowerCase().trim();

      // NEW LOGIC: Forced Password Change Check
      bool mustChange = data['mustChangePassword'] ?? false;

      if (dbPassword == password) {
        setState(() => _isLoading = false);

        // --- ROLE VALIDATION ---
        bool isCorrectRole =
            (_isOfficerMode && (dbRole == "officer" || dbRole == "office")) ||
            (!_isOfficerMode && dbRole == "clerk");

        if (!isCorrectRole) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "Role Mismatch: This ID is registered as a $dbRole",
              ),
            ),
          );
          return;
        }

        // --- SECURITY CHECK: Force Change Password ---
        if (mustChange) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  ChangePasswordPage(userId: inputId, role: dbRole),
            ),
          );
        } else {
          // --- REGULAR ACCESS ---
          if (dbRole == "officer" || dbRole == "office") {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => TicketFormPage(officerId: inputId),
              ),
            );
          } else if (dbRole == "clerk") {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => ClerkPaymentPage(clerkId: inputId),
              ),
            );
          }
        }
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Wrong Password! Try again.")),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("System Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    Color themeColor = _isOfficerMode ? Colors.blue : Colors.green.shade700;

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(30),
                child: Column(
                  children: [
                    const Icon(
                      Icons.location_city,
                      size: 50,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "BAHIR DAR TRAFFIC SYSTEM",
                      style: TextStyle(
                        fontSize: 14,
                        letterSpacing: 1.5,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 40),
                    Icon(
                      _isOfficerMode
                          ? Icons.local_police
                          : Icons.account_balance,
                      size: 70,
                      color: themeColor,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _isOfficerMode ? "OFFICER LOGIN" : "CLERK LOGIN",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: themeColor,
                      ),
                    ),
                    const SizedBox(height: 30),
                    TextField(
                      controller: _idController,
                      decoration: const InputDecoration(
                        labelText: "Enter ID Number",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: "Enter Password",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 25),
                    ElevatedButton(
                      onPressed: _handleAccess,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        backgroundColor: themeColor,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text("LOGIN"),
                    ),
                    const SizedBox(height: 15),
                    TextButton.icon(
                      onPressed: () =>
                          setState(() => _isOfficerMode = !_isOfficerMode),
                      icon: const Icon(Icons.swap_horiz),
                      label: Text(
                        _isOfficerMode
                            ? "Need to login as Clerk?"
                            : "Need to login as Officer?",
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
