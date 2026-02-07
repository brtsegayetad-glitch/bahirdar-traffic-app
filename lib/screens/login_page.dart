import 'package:flutter/material.dart';
import 'ticket_form_page.dart';
import 'payment_page.dart';
import 'supervisor_dashboard.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _idController = TextEditingController();
  final _passwordController = TextEditingController(); // NEW
  bool _isOfficerMode = true;
  bool _obscurePassword = true; // NEW: To hide/show password

  void _handleAccess() {
    String inputId = _idController.text.trim().toUpperCase();
    String password = _passwordController.text.trim();

    if (inputId.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter both ID and Password")),
      );
      return;
    }

    // 1. SECURE SUPERVISOR ACCESS
    // Login: ADMIN99 | Pass: BahirDar2026
    if (inputId == "ADMIN99" && password == "BahirDar2026") {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const SupervisorDashboard()),
      );
      return;
    }

    // 2. NORMAL OFFICER/CLERK ACCESS (Requires at least 4 digit password)
    if (password.length >= 4) {
      if (_isOfficerMode) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TicketFormPage(officerId: inputId),
          ),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const PaymentPage()),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password must be at least 4 characters")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    Color themeColor = _isOfficerMode ? Colors.blue : Colors.green.shade700;

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          // Added to prevent keyboard overlap
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 80),
              Icon(
                _isOfficerMode ? Icons.local_police : Icons.account_balance,
                size: 80,
                color: themeColor,
              ),
              const SizedBox(height: 10),
              Text(
                _isOfficerMode ? "OFFICER PORTAL" : "BUREAU PAYMENT",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: themeColor,
                ),
              ),
              const Text(
                "Bahir Dar Traffic Management System",
                style: TextStyle(color: Colors.grey, letterSpacing: 1.1),
              ),
              const SizedBox(height: 40),

              // ID FIELD
              TextField(
                controller: _idController,
                decoration: InputDecoration(
                  labelText: _isOfficerMode
                      ? "Officer Badge Number"
                      : "Clerk ID Number",
                  border: const OutlineInputBorder(),
                  prefixIcon: Icon(_isOfficerMode ? Icons.badge : Icons.person),
                ),
              ),
              const SizedBox(height: 20),

              // NEW: PASSWORD FIELD
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: "Secure Password",
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),

              const SizedBox(height: 30),

              ElevatedButton(
                onPressed: _handleAccess,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 55),
                  backgroundColor: themeColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  "LOGIN TO SYSTEM",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),

              const SizedBox(height: 20),

              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _isOfficerMode = !_isOfficerMode;
                  });
                },
                icon: const Icon(Icons.swap_horiz),
                label: Text(
                  _isOfficerMode
                      ? "Switch to Bureau Mode"
                      : "Switch to Officer Mode",
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
