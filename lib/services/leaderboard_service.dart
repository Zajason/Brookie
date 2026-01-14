import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'token_storage.dart';

class LeaderboardUser {
  final int rank;
  final int userId;
  final String username;
  final String fullName;
  final double amount;

  LeaderboardUser({
    required this.rank,
    required this.userId,
    required this.username,
    required this.fullName,
    required this.amount,
  });

  factory LeaderboardUser.fromJson(Map<String, dynamic> json) {
    return LeaderboardUser(
      rank: json['rank'] as int,
      userId: json['user_id'] as int,
      username: json['username'] as String,
      fullName: json['full_name'] as String,
      amount: (json['amount'] as num).toDouble(),
    );
  }
}

class LeaderboardData {
  final List<LeaderboardUser> top10;
  final LeaderboardUser currentUser;
  final int totalUsers;

  LeaderboardData({
    required this.top10,
    required this.currentUser,
    required this.totalUsers,
  });

  factory LeaderboardData.fromJson(Map<String, dynamic> json) {
    return LeaderboardData(
      top10: (json['top_10'] as List)
          .map((e) => LeaderboardUser.fromJson(e))
          .toList(),
      currentUser: LeaderboardUser.fromJson(json['current_user']),
      totalUsers: json['total_users'] as int,
    );
  }
}

class LeaderboardService {
  static Future<LeaderboardData> fetchLeaderboard({String? category, String? period}) async {
    final token = await TokenStorage.getAccessToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    String url = '${ApiConfig.baseUrl}/api/leaderboard/';
    List<String> params = [];
    if (category != null && category != 'total') {
      params.add('category=$category');
    }
    if (period != null) {
      params.add('period=$period');
    }
    if (params.isNotEmpty) {
      url += '?${params.join('&')}';
    }

    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return LeaderboardData.fromJson(data);
    } else {
      throw Exception('Failed to load leaderboard: ${response.statusCode}');
    }
  }
}
