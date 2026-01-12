import 'package:flutter/material.dart';

class BudgetSettingsItem {
  final String key;        // backend category: rent, utilities, ...
  final String label;      // UI label: Rent, Utilities, ...
  final String icon;       // emoji
  final List<Color> gradient; // 2-color gradient
  double limit;            // budget amount
  double spent;            // spending amount

  BudgetSettingsItem({
    required this.key,
    required this.label,
    required this.icon,
    required this.gradient,
    required this.limit,
    required this.spent,
  });

  double get remaining => limit - spent;

  double get pctUsed {
    if (limit <= 0) return 0;
    final p = (spent / limit) * 100.0;
    return p > 100 ? 100 : p;
  }

  bool get overBudget => limit > 0 && spent > limit;
}
