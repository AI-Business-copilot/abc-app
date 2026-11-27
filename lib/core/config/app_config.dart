import 'package:flutter/foundation.dart' show kIsWeb;

class AppConfig {
  /// Set for a physical device or a hosted backend, including the /api suffix.
  static const String apiBaseUrlOverride = String.fromEnvironment(
    'API_BASE_URL',
  );
  static const String supabaseUrl = 'https://vhivkicmqwjiypvbssbv.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZoaXZraWNtcXdqaXlwdmJzc2J2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTIzODM2MTUsImV4cCI6MjEwNzk1OTYxNX0.HubY19CKmXVkWdac0Ngs989MAZZ0azfrA1P_OmBEmhc';

  // 1. IP mạng LAN của máy tính đang chạy backend
  // Cập nhật theo mạng Wi-Fi hiện tại của máy tính
  static const String apiBaseUrlLan = 'http://192.168.1.40:5000/api';

  // 2. IP dành cho máy ảo Android Emulator
  static const String apiBaseUrlEmulator = 'http://10.0.2.2:5000/api';

  // 3. IP dành cho Windows Desktop / iOS Simulator
  static const String apiBaseUrlLocal = 'http://localhost:5000/api';

  /// Custom URL scheme dùng cho OAuth callback trên Android / iOS.
  /// Phải khớp với `intent-filter` trong AndroidManifest.xml và
  /// `CFBundleURLTypes` trong ios/Runner/Info.plist.
  static const String appUrlScheme = 'io.supabase.abcapps';

  /// Redirect URL của OAuth (native): scheme://host/path.
  static const String appOAuthRedirectUrl = '$appUrlScheme://login-callback';

  /// Redirect URL dùng cho OAuth.
  /// - Web: trả về địa chỉ hiện tại (bỏ query/hash) để Supabase redirect về đúng trang.
  /// - Android/iOS: dùng custom scheme để mở lại app.
  static String get oauthRedirectUrl {
    if (kIsWeb) {
      final base = Uri.base;
      return Uri(
        scheme: base.scheme,
        host: base.host,
        port: base.hasPort ? base.port : null,
        path: base.path,
      ).toString();
    }
    return appOAuthRedirectUrl;
  }
}
