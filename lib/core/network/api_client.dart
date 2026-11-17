import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/server_address_store.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late final Dio dio;

  ApiClient._internal() {
    // Địa chỉ backend mặc định lúc khởi động.
    // Mặc định theo nền tảng, nhưng có thể bị ghi đè lúc chạy bởi giá trị
    // người dùng lưu trong màn hình Cài đặt (xem ServerAddressStore).
    final String baseUrl = ServerAddressStore.defaultBaseUrl;

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
          // Địa chỉ backend được xác định lại ở mỗi request để người dùng
          // đổi được trong màn hình Cài đặt mà không cần build lại app.
          options.baseUrl = await ServerAddressStore.effective();

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
