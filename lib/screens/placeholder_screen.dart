import 'package:flutter/material.dart';
import '../shell/app_shell.dart';

class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return AppShell(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF9FAFB), Color(0xFFF3F4F6)],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 58),
            child: Text(
              title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }
}
