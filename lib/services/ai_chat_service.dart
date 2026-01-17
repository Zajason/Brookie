import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'token_storage.dart';

class AiChatServiceException implements Exception {
  final String message;
  AiChatServiceException(this.message);
  @override
  String toString() => message;
}

class AiChatService {
  static Future<Map<String, String>> _authHeaders() async {
    final token = await TokenStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      throw AiChatServiceException("Missing access token. Please log in again.");
    }
    return <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// POST /api/chat/threads/  -> {id, title}
  static Future<int> createThread({String title = ""}) async {
    final headers = await _authHeaders();
    final url = Uri.parse('${ApiConfig.baseUrl}/api/chat/threads/');

    final res = await http.post(
      url,
      headers: headers,
      body: jsonEncode({"title": title}),
    );

    if (res.statusCode == 201) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return (data["id"] as num).toInt();
    }

    if (res.statusCode == 401) {
      throw AiChatServiceException("Unauthorized (401). Please log in again.");
    }

    throw AiChatServiceException("Failed to create thread (${res.statusCode}): ${res.body}");
  }

  /// GET /api/chat/threads/<id>/ -> {id,title,messages:[{role,content,created_at}]}
  static Future<List<Map<String, dynamic>>> fetchThreadMessages(int threadId) async {
    final headers = await _authHeaders();
    final url = Uri.parse('${ApiConfig.baseUrl}/api/chat/threads/$threadId/');

    final res = await http.get(url, headers: headers);

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final msgs = (data["messages"] as List<dynamic>? ?? []);
      return msgs.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }

    if (res.statusCode == 401) {
      throw AiChatServiceException("Unauthorized (401). Please log in again.");
    }

    throw AiChatServiceException("Failed to fetch thread (${res.statusCode}): ${res.body}");
  }

  /// POST /api/chat/threads/<id>/message/ -> {reply: "..."}
  static Future<String> sendMessage({
    required int threadId,
    required String message,
  }) async {
    final headers = await _authHeaders();
    final url = Uri.parse('${ApiConfig.baseUrl}/api/chat/threads/$threadId/message/');

    final res = await http.post(
      url,
      headers: headers,
      body: jsonEncode({"message": message}),
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return (data["reply"] ?? "").toString();
    }

    if (res.statusCode == 401) {
      throw AiChatServiceException("Unauthorized (401). Please log in again.");
    }

    throw AiChatServiceException("Failed to send message (${res.statusCode}): ${res.body}");
  }
}
