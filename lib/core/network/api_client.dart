import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late final Dio dio;

  ApiClient._internal() {
    // 1. Web hoặc Desktop -> localhost:5000
    // 2. Android:
    //    - Emulator Android luôn truy cập host qua 10.0.2.2:5000 (đây là loopback alias của Android SDK)
    //    - Thiết bị thật mới cần IP LAN (192.168.1.40:5000)
    final String baseUrl;
    if (kIsWeb || !Platform.isAndroid) {
      baseUrl = AppConfig.apiBaseUrlLocal;
    } else {
      // Mặc định cho Android dùng 10.0.2.2 (hoạt động chuẩn xác trên mọi máy ảo)
      baseUrl = AppConfig.apiBaseUrlEmulator;
    }

    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        // Server giữ request tới ~6s khi Supabase Auth chậm (3s x 2 lần thử).
        // Client phải chờ lâu hơn server, nếu không nó tự cắt trước và nuốt mất
        // thông báo lỗi thật (trước đây cả hai đều đặt 10s).
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 25),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Gắn Supabase Access Token nếu user đã login
          final session = Supabase.instance.client.auth.currentSession;
          if (session?.accessToken != null) {
            options.headers['Authorization'] = 'Bearer ${session!.accessToken}';
          }

          // Gắn businessId đang active nếu có
          final prefs = await SharedPreferences.getInstance();
          final businessId = prefs.getString('active_business_id');
          if (businessId != null && businessId.isNotEmpty) {
            options.headers['x-business-id'] = businessId;
          }

          return handler.next(options);
        },
        onError: (DioException error, handler) async {
          // Fallback tự động: nếu 10.0.2.2 thất bại (ví dụ đang chạy trên thiết bị thật),
          // tự động thử lại với IP LAN (192.168.1.40)
          if (!kIsWeb &&
              Platform.isAndroid &&
              error.requestOptions.baseUrl == AppConfig.apiBaseUrlEmulator &&
              (error.type == DioExceptionType.connectionTimeout ||
                  error.type == DioExceptionType.connectionError)) {
            try {
              final newOptions = error.requestOptions;
              newOptions.baseUrl = AppConfig.apiBaseUrlLan;
              final response = await dio.fetch(newOptions);
              return handler.resolve(response);
            } catch (_) {
              // Bỏ qua nếu fallback cũng fail
            }
          }
          return handler.next(error);
        },
      ),
    );
  }
}
