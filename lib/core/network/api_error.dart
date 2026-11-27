import 'package:dio/dio.dart';

/// Turns an API error into the message the backend sent.
String apiErrorMessage(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    if (data is Map && data['error'] is String) {
      return data['error'] as String;
    }
    if (error.response != null) {
      return 'Lỗi ${error.response!.statusCode} từ máy chủ.';
    }
    return 'Không kết nối được máy chủ.';
  }
  return error.toString();
}

/// The HTTP status of an API error, or null when it is not an API error.
int? apiErrorStatus(Object error) {
  if (error is DioException) return error.response?.statusCode;
  return null;
}
