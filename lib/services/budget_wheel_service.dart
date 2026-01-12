import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/budget_category.dart';
import 'token_storage.dart';

class BudgetWheelServiceException implements Exception {
  final String message;
  BudgetWheelServiceException(this.message);
  @override
  String toString() => message;
}

class BudgetWheelService {
  static Future<List<BudgetCategory>> fetchCategories() async {
    final token = await TokenStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      throw BudgetWheelServiceException('Missing access token. Please log in again.');
    }

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    final budgetsUrl = Uri.parse('${ApiConfig.baseUrl}/api/budgets/');
    final spendingUrl = Uri.parse('${ApiConfig.baseUrl}/api/spending/');

    final budgetsRes = await http.get(budgetsUrl, headers: headers);
    final spendingRes = await http.get(spendingUrl, headers: headers);

    if (budgetsRes.statusCode == 401 || spendingRes.statusCode == 401) {
      throw BudgetWheelServiceException('Unauthorized (401). Please log in again.');
    }
    if (budgetsRes.statusCode != 200) {
      throw BudgetWheelServiceException('Failed to load budgets (${budgetsRes.statusCode}).');
    }
    if (spendingRes.statusCode != 200) {
      throw BudgetWheelServiceException('Failed to load spending (${spendingRes.statusCode}).');
    }

    final budgetsJson = jsonDecode(budgetsRes.body) as List<dynamic>;
    final spendingJson = jsonDecode(spendingRes.body) as List<dynamic>;

    // category -> values
    final Map<String, double> budgetByCat = {};
    final Map<String, double> spentByCat = {};
    final Map<String, String> labelByCat = {};

    for (final item in budgetsJson) {
      final m = Map<String, dynamic>.from(item as Map);
      final cat = (m['category'] ?? '').toString();
      if (cat.isEmpty) continue;

      labelByCat[cat] = (m['category_label'] ?? cat).toString();
      budgetByCat[cat] = _toDouble(m['amount']);
    }

    for (final item in spendingJson) {
      final m = Map<String, dynamic>.from(item as Map);
      final cat = (m['category'] ?? '').toString();
      if (cat.isEmpty) continue;

      labelByCat.putIfAbsent(cat, () => (m['category_label'] ?? cat).toString());
      spentByCat[cat] = _toDouble(m['amount']);
    }

    // union of categories (should match due to ensure_user_rows)
    final cats = <String>{...budgetByCat.keys, ...spentByCat.keys}.toList()
      ..sort();

    return cats.map((cat) {
      final label = labelByCat[cat] ?? cat;
      final budget = budgetByCat[cat] ?? 0.0;
      final spent = spentByCat[cat] ?? 0.0;

      return BudgetCategory(
        id: cat,                 // IMPORTANT: id is the backend category key (rent, utilities, etc)
        name: label,             // "Rent"
        amount: spent,           // Wheel uses SPENT
        color: _colorForCategory(cat),
        budget: budget,
        spent: spent,
        aiComment: _aiStub(label, budget, spent),
      );
    }).toList();
  }

  static Future<void> updateBudget({
    required String category, // e.g. "rent"
    required double amount,
  }) async {
    final token = await TokenStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      throw BudgetWheelServiceException('Missing access token. Please log in again.');
    }

    final url = Uri.parse('${ApiConfig.baseUrl}/api/budgets/update/');
    final res = await http.patch(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'category': category,
        'amount': amount,
      }),
    );

    if (res.statusCode == 401) {
      throw BudgetWheelServiceException('Unauthorized (401). Please log in again.');
    }
    if (res.statusCode != 200) {
      throw BudgetWheelServiceException('Failed to update budget (${res.statusCode}): ${res.body}');
    }
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  static String _aiStub(String label, double budget, double spent) {
    if (budget <= 0) return "Set a budget for $label to start tracking.";
    final pct = (spent / budget) * 100.0;
    if (pct < 80) return "You're comfortably under budget for $label. Keep it up.";
    if (pct <= 100) return "You're close to your $label budget. Watch spending for the rest of the month.";
    return "You're over budget for $label. Consider adjusting your budget or reducing spend.";
  }

  static Color _colorForCategory(String cat) {
    switch (cat) {
      case 'rent':
        return const Color(0xFF3B82F6);
      case 'utilities':
        return const Color(0xFFEF4444);
      case 'entertainment':
        return const Color(0xFF8B5CF6);
      case 'groceries':
        return const Color(0xFF10B981);
      case 'transportation':
        return const Color(0xFFF59E0B);
      case 'savings':
        return const Color(0xFF06B6D4);
      case 'healthcare':
        return const Color(0xFFEC4899);
      case 'other':
      default:
        return const Color(0xFF6366F1);
    }
  }
}
