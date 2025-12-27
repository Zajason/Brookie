import 'package:flutter/material.dart';
import 'screens/budget_wheel_screen.dart';

void main() {
  runApp(const BudgetWheelApp());
}

class BudgetWheelApp extends StatelessWidget {
  const BudgetWheelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: const BudgetWheelScreen(),
    );
  }
}
