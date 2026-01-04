import 'dart:io';

class ApiConfig {
  /// If you're running Django on your Mac:
  /// - iOS Simulator can use 127.0.0.1
  /// - Android Emulator must use 10.0.2.2
  /// - Physical phone must use your Mac’s LAN IP (e.g., 192.168.1.50)
  static String get baseUrl {
    if (Platform.isAndroid) return 'http://10.0.2.2:8000';
    return 'http://127.0.0.1:8000';
  }
}
