import 'package:flutter/material.dart';

class BudgetCategory {
  final String id;
  final String name;
  final double amount; // for wheel proportions
  final Color color;

  final double budget;
  final double spent;
  final String aiComment;

  const BudgetCategory({
    required this.id,
    required this.name,
    required this.amount,
    required this.color,
    required this.budget,
    required this.spent,
    required this.aiComment,
  });

  double get percentageUsed => budget == 0 ? 0 : (spent / budget) * 100.0;
  double get remaining => budget - spent;
}
