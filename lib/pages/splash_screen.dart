import 'dart:async';
import 'package:flutter/material.dart';
import '../main.dart'; // or import main.dart and use AuthGate directly

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Wait 2 seconds, then navigate to AuthGate
    Timer(const Duration(seconds: 2), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AuthGate()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Image.asset(
          Theme.of(context).brightness == Brightness.dark
              ? 'assets/images/logo_no_background_dark.png'
              : 'assets/images/logo_no_background_light.png',
          width: 150,
          height: 150,
        ),
      ),
    );
  }
}
