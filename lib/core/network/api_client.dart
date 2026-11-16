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
    //    - Emulator (10.0.2.2)
    //    - Thiết bị thật qua LAN (192.168.1.40)
    final String baseUrl;
    if (kIsWeb || !Platform.isAndroid) {
      baseUrl = AppConfig.apiBaseUrlLocal;
    } else {
      // Ưu tiên IP LAN hiện tại của máy tính
      baseUrl = AppConfig.apiBaseUrlLan;
    }

    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
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
          // Fallback tự động: nếu đang chạy trên Android Emulator mà LAN timeout/refused,
          // thử lại với 10.0.2.2
          if (!kIsWeb &&
              Platform.isAndroid &&
              error.requestOptions.baseUrl == AppConfig.apiBaseUrlLan &&
              (error.type == DioExceptionType.connectionTimeout ||
                  error.type == DioExceptionType.connectionError)) {
            try {
              final newOptions = error.requestOptions;
              newOptions.baseUrl = AppConfig.apiBaseUrlEmulator;
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
