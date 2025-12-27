import 'package:flutter/material.dart';
import 'ui/home_screen.dart';

void main() {
  runApp(const KooxApp());
}

class KooxApp extends StatelessWidget {
  const KooxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "MOVIKOOX",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF922E42),
        ),
        scaffoldBackgroundColor: const Color(0xFFF9FAFB),
      ),
      home: const HomeScreen(),
    );
  }
}
