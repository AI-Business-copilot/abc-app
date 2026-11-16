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
    // Trên máy thật kết nối cùng Wi-Fi với máy tính, trỏ tới IP LAN của máy tính: 192.168.88.168:5000
    // Trên máy ảo Android Emulator trỏ tới 10.0.2.2:5000
    // Trên Desktop/Web trỏ tới localhost:5000
    final String baseUrl;
    if (!kIsWeb && Platform.isAndroid) {
      // Mặc định ưu tiên IP LAN để thiết bị thật cắm cáp/bắt Wi-Fi đều kết nối được
      baseUrl = AppConfig.apiBaseUrlLan;
    } else {
      baseUrl = AppConfig.apiBaseUrlLocal;
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
        onError: (DioException error, handler) {
          return handler.next(error);
        },
      ),
    );
  }
}
