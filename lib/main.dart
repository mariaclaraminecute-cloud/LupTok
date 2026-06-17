import 'package:flutter/material.dart';
import 'splash_screen.dart';

void main() {
  runApp(const LupTokApp());
}

class LupTokApp extends StatelessWidget {
  const LupTokApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LupTok',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFF0F0F0F),
        fontFamily: 'Roboto',
      ),
      home: const SplashScreen(),
    );
  }
}