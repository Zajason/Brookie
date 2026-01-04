import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'token_storage.dart';

class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}

class AuthService {
  /// Your existing login endpoint (returns {access, refresh})
  static Future<void> login({
    required String username,
    required String password,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/auth/login/');

    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'password': password,
      }),
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final access = data['access'] as String?;
      final refresh = data['refresh'] as String?;

      if (access == null || refresh == null) {
        throw AuthException('Login succeeded but tokens are missing.');
      }

      await TokenStorage.saveTokens(access: access, refresh: refresh);
      return;
    }

    // Try to show backend error
    throw AuthException(_extractError(res, fallback: 'Login failed (${res.statusCode}).'));
  }

  /// ✅ Register endpoint (create user)
  /// IMPORTANT: This assumes your backend has:
  /// POST /api/auth/register/   (or change the URL below)
  ///
  /// Fields: full_name, email, password
  /// If your backend expects username instead of email, adjust the body.
static Future<void> register({
  required String username,
  required String fullName,
  required String email,
  required String password,
}) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/auth/register/');

    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
  'username': username,   // ✅ REQUIRED by backend
  'full_name': fullName,
  'email': email,
  'password': password,
}),
    );

    if (res.statusCode == 200 || res.statusCode == 201) {
      return;
    }

    throw AuthException(_extractError(res, fallback: 'Registration failed (${res.statusCode}).'));
  }

  /// Optional helper for your logout button
  static Future<void> logout() async {
    await TokenStorage.clear();
  }

  static String _extractError(http.Response res, {required String fallback}) {
    try {
      final data = jsonDecode(res.body);

      // Common DRF/SimpleJWT: {"detail": "..."}
      if (data is Map && data['detail'] != null) {
        return data['detail'].toString();
      }

      // Serializer validation errors: {"email": ["..."], "password": ["..."]}
      if (data is Map) {
        final parts = <String>[];
        data.forEach((k, v) {
          if (v is List) {
            parts.add('$k: ${v.join(", ")}');
          } else {
            parts.add('$k: $v');
          }
        });
        if (parts.isNotEmpty) return parts.join('\n');
      }

      // Sometimes: {"error": "..."}
      if (data is Map && data['error'] != null) {
        return data['error'].toString();
      }
    } catch (_) {
      // ignore json parse failures
    }
    return fallback;
  }
}
