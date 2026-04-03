import 'package:flutter/material.dart';

/// Simple full-screen loading indicator shown during startup and session restore.
class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0D1117),
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
