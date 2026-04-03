import 'package:flutter/material.dart';

void main() {
  runApp(const MaterialApp(
    title: 'EarthNova',
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      backgroundColor: Color(0xFF0D1B2A),
      body: Center(
        child: Text(
          'EarthNova',
          style: TextStyle(
            color: Color(0xFFE0E1DD),
            fontSize: 28,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
      ),
    ),
  ));
}
