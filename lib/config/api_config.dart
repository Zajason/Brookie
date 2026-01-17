import 'dart:io';

class ApiConfig {
  // ========================================
  // CONFIGURATION: Change this to switch between local and remote
  // ========================================
  
  /// Set to true to use your REMOTE server
  /// Set to false to use LOCALHOST for development
  static const bool useRemoteServer = false;
  
  /// Your remote server URL (set this when you deploy)
  /// Example: 'https://your-app.up.railway.app'
  /// Example: 'https://your-app.onrender.com'
  static const String remoteServerUrl = 'https://your-backend-url-here.com';
  
  // ========================================
  // AUTO-CONFIGURATION (don't modify below)
  // ========================================
  
  /// Get the appropriate base URL based on configuration and platform
  static String get baseUrl {
    if (useRemoteServer) {
      // Use remote server
      return remoteServerUrl;
    } else {
      // Use localhost - different IPs for different platforms
      if (Platform.isAndroid) {
        // Android emulator uses 10.0.2.2 to access host machine's localhost
        return 'http://10.0.2.2:8000';
      } else if (Platform.isIOS) {
        // iOS simulator can use 127.0.0.1
        return 'http://127.0.0.1:8000';
      } else {
        // Web, desktop, or physical device
        // For physical device: change this to your computer's local IP
        // Example: 'http://192.168.1.100:8000'
        return 'http://127.0.0.1:8000';
      }
    }
  }
  
  /// Print current configuration (useful for debugging)
  static void printConfig() {
    print('🔧 API Configuration:');
    print('   Mode: ${useRemoteServer ? "REMOTE" : "LOCAL"}');
    print('   Base URL: $baseUrl');
    print('   Platform: ${Platform.operatingSystem}');
  }
}
