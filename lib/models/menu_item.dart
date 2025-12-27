import 'package:flutter/material.dart';

class AppMenuItem {
  final IconData icon;
  final String label;
  final Color color;
  final String route; // where to navigate (optional per item)

  const AppMenuItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.route,
  });
}
