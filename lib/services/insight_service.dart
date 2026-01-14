import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'token_storage.dart';

class InsightsService {
  /// Fetch all category insights (rule-based, fast)
  static Future<List<Map<String, dynamic>>> fetchCategoryInsights() async {
    final token = await TokenStorage.getAccessToken();
    if (token == null) {
      throw Exception("Not logged in (no access token).");
    }

    final url = Uri.parse('${ApiConfig.baseUrl}/api/insights/categories/');
    final res = await http.get(url, headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    });

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return (data['insights'] as List).cast<Map<String, dynamic>>();
    }

    throw Exception('Failed to fetch insights (${res.statusCode}): ${res.body}');
  }

  /// Fetch AI-powered insight for a specific category (slower, more detailed)
  static Future<String> fetchCategoryAIInsight(String categoryKey) async {
    final token = await TokenStorage.getAccessToken();
    if (token == null) {
      throw Exception("Not logged in (no access token).");
    }

    final url = Uri.parse('${ApiConfig.baseUrl}/api/insights/category-ai/?category=$categoryKey');
    final res = await http.get(url, headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    });

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return data['insight'] as String;
    }

    throw Exception('Failed to fetch AI insight (${res.statusCode}): ${res.body}');
  }

  /// Fetch peer spending averages
  static Future<Map<String, double>> fetchPeerAverages() async {
    final token = await TokenStorage.getAccessToken();
    if (token == null) {
      throw Exception("Not logged in (no access token).");
    }

    final url = Uri.parse('${ApiConfig.baseUrl}/api/analytics/peer-averages/');
    final res = await http.get(url, headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    });

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return data.map((key, value) => MapEntry(key, (value as num).toDouble()));
    }

    throw Exception('Failed to fetch peer averages (${res.statusCode}): ${res.body}');
  }
}
