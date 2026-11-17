import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

import 'app_config.dart';

/// Lưu địa chỉ backend do người dùng nhập, để có thể đổi mà không cần build lại.
///
/// Thứ tự ưu tiên:
///   1. Giá trị đã lưu (người dùng nhập trong màn hình Cài đặt)
///   2. `--dart-define=API_BASE_URL=...`
///   3. Mặc định theo nền tảng (Android -> IP LAN, còn lại -> localhost)
class ServerAddressStore {
  static const String _kKey = 'api_base_url';

  /// Đọc địa chỉ đã lưu, `null` nếu chưa có.
  static Future<String?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_kKey);
    if (value == null) return null;
    final normalized = normalize(value);
    return normalized.isEmpty ? null : normalized;
  }

  /// Lưu địa chỉ mới. Trả về `null` nếu hợp lệ, hoặc thông báo lỗi.
  static Future<String?> write(String raw) async {
    final normalized = normalize(raw);
    final error = validate(normalized);
    if (error != null) return error;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kKey, normalized);
    return null;
  }

  /// Xóa địa chỉ đã lưu, quay về giá trị mặc định.
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kKey);
  }

  /// Địa chỉ đang dùng: giá trị đã lưu, nếu không thì mặc định theo nền tảng.
  static Future<String> effective() async {
    final saved = await read();
    if (saved != null) return saved;
    return defaultBaseUrl;
  }

  /// Mặc định theo nền tảng:
  /// - có `--dart-define=API_BASE_URL` thì dùng giá trị đó
  /// - Android -> IP LAN của máy tính chạy backend
  /// - còn lại -> localhost
  static String get defaultBaseUrl {
    if (AppConfig.apiBaseUrlOverride.isNotEmpty) {
      return AppConfig.apiBaseUrlOverride;
    }
    if (!kIsWeb && Platform.isAndroid) {
      return AppConfig.apiBaseUrlLan;
    }
    return AppConfig.apiBaseUrlLocal;
  }

  /// Các địa chỉ gợi ý nhanh trong màn hình Cài đặt.
  static List<({String label, String url})> get suggestions {
    return [
      (label: 'Máy ảo Android', url: AppConfig.apiBaseUrlEmulator),
      (label: 'USB / adb reverse', url: 'http://localhost:5000/api'),
      (label: 'Máy tính (LAN)', url: AppConfig.apiBaseUrlLan),
    ];
  }

  /// Chuẩn hoá: bỏ khoảng trắng, bỏ dấu `/` cuối cùng.
  static String normalize(String raw) {
    var value = raw.trim();
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    return value;
  }

  /// Kiểm tra địa chỉ hợp lệ. Trả về thông báo lỗi, `null` nếu hợp lệ.
  static String? validate(String value) {
    if (value.isEmpty) {
      return 'Địa chỉ không được để trống.';
    }
    if (!value.startsWith('http://') && !value.startsWith('https://')) {
      return 'Địa chỉ phải bắt đầu bằng http:// hoặc https://';
    }
    final uri = Uri.tryParse(value);
    if (uri == null || uri.host.isEmpty) {
      return 'Địa chỉ không hợp lệ.';
    }
    return null;
  }
}
