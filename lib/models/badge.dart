import 'package:flutter/material.dart';

class BadgeModel {
  final int id;
  final String title;
  final String description;
  final IconData icon;
  final double progress; // 0–100
  final bool earned;
  final List<Color> gradient;
  final String requirement;

  const BadgeModel({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.progress,
    required this.earned,
    required this.gradient,
    required this.requirement,
  });
}
