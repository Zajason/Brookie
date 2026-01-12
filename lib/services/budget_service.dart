import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'token_storage.dart';

class BudgetService {
  static Future<List<Map<String, dynamic>>> fetchBudgets() async {
    final token = await TokenStorage.getAccessToken();
    if (token == null) {
      throw Exception("Not logged in (no access token).");
    }

    final url = Uri.parse('${ApiConfig.baseUrl}/api/budgets/');
    final res = await http.get(url, headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    });

    if (res.statusCode == 200) {
      return (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
    }

    throw Exception('Failed to fetch budgets (${res.statusCode}): ${res.body}');
  }

  static Future<List<Map<String, dynamic>>> fetchSpending() async {
    final token = await TokenStorage.getAccessToken();
    if (token == null) {
      throw Exception("Not logged in (no access token).");
    }

    final url = Uri.parse('${ApiConfig.baseUrl}/api/spending/');
    final res = await http.get(url, headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    });

    if (res.statusCode == 200) {
      return (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
    }

    throw Exception('Failed to fetch spending (${res.statusCode}): ${res.body}');
  }

  static Future<void> updateBudget({
    required String categoryKey, // e.g. "rent"
    required double amount,
  }) async {
    final token = await TokenStorage.getAccessToken();
    if (token == null) {
      throw Exception("Not logged in (no access token).");
    }

    final url = Uri.parse('${ApiConfig.baseUrl}/api/budgets/update/');
    final res = await http.patch(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'category': categoryKey,
        'amount': amount,
      }),
    );

    if (res.statusCode == 200) return;

    throw Exception('Failed to update budget (${res.statusCode}): ${res.body}');
  }
}
