import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; // 1. Add this import
import 'screens/login_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // This allows the app to run on BOTH Web and Android
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyBaZ87VulQIIWQR2YPiAQPNECvNsIQTI1g",
      appId: "1:627883387892:web:0c88f2c170f2bcef3027a1",
      messagingSenderId: "627883387892",
      projectId: "bahirdartraffic",
      storageBucket: "bahirdartraffic.firebasestorage.app",
      authDomain: "bahirdartraffic.firebaseapp.com",
    ),
  );

  runApp(const TrafficApp());
}

class TrafficApp extends StatelessWidget {
  const TrafficApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Bahir Dar Traffic',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const LoginPage(),
    );
  }
}
