import 'package:flutter/material.dart';

/// Placeholder achievement screen.
class AchievementScreen extends StatelessWidget {
  const AchievementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        title: const Text('Achievements'),
        backgroundColor: const Color(0xFF161B22),
      ),
      body: const Center(
        child: Text(
          'Achievements',
          style: TextStyle(color: Colors.white, fontSize: 20),
        ),
      ),
    );
  }
}
