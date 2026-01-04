import 'package:flutter_secure_storage/flutter_secure_storage.dart';


class TokenStorage {
  static const _storage = FlutterSecureStorage();

  static const _kAccess = 'access_token';
  static const _kRefresh = 'refresh_token';

  static Future<void> saveTokens({
    required String access,
    required String refresh,
  }) async {
    await _storage.write(key: _kAccess, value: access);
    await _storage.write(key: _kRefresh, value: refresh);
  }

  static Future<String?> getAccessToken() => _storage.read(key: _kAccess);
  static Future<String?> getRefreshToken() => _storage.read(key: _kRefresh);

  static Future<void> clear() async {
    await _storage.delete(key: _kAccess);
    await _storage.delete(key: _kRefresh);
  }
}
