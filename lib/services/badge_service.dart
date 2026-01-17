import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'token_storage.dart';

class BadgeData {
  final int id;
  final String badgeType;
  final String title;
  final String description;
  final String icon;
  final String gradientStart;
  final String gradientEnd;
  final double progress;
  final bool earned;
  final String requirement;
  final String? earnedAt;

  BadgeData({
    required this.id,
    required this.badgeType,
    required this.title,
    required this.description,
    required this.icon,
    required this.gradientStart,
    required this.gradientEnd,
    required this.progress,
    required this.earned,
    required this.requirement,
    this.earnedAt,
  });

  factory BadgeData.fromJson(Map<String, dynamic> json) {
    return BadgeData(
      id: json['id'] as int,
      badgeType: json['badge_type'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      icon: json['icon'] as String,
      gradientStart: json['gradient_start'] as String,
      gradientEnd: json['gradient_end'] as String,
      progress: (json['progress'] as num).toDouble(),
      earned: json['earned'] as bool,
      requirement: json['requirement'] as String,
      earnedAt: json['earned_at'] as String?,
    );
  }
}

class BadgeResponse {
  final List<BadgeData> badges;
  final int earnedCount;
  final int totalCount;

  BadgeResponse({
    required this.badges,
    required this.earnedCount,
    required this.totalCount,
  });

  factory BadgeResponse.fromJson(Map<String, dynamic> json) {
    return BadgeResponse(
      badges: (json['badges'] as List)
          .map((e) => BadgeData.fromJson(e))
          .toList(),
      earnedCount: json['earned_count'] as int,
      totalCount: json['total_count'] as int,
    );
  }
}

class BadgeService {
  static Future<BadgeResponse> fetchBadges() async {
    final token = await TokenStorage.getAccessToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    final uri = Uri.parse('${ApiConfig.baseUrl}/api/badges/');

    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return BadgeResponse.fromJson(data);
    } else {
      throw Exception('Failed to fetch badges: ${response.statusCode}');
    }
  }
}
