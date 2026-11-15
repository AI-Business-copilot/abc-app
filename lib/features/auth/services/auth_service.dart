import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:abc_app/core/network/api_client.dart';

class BusinessInfo {
  final String id;
  final String name;
  final String? phone;
  final String? address;
  final String? role;
  final String? roleName;

  BusinessInfo({
    required this.id,
    required this.name,
    this.phone,
    this.address,
    this.role,
    this.roleName,
  });

  factory BusinessInfo.fromJson(Map<String, dynamic> json) {
    return BusinessInfo(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Không tên',
      phone: json['phone'],
      address: json['address'],
      role: json['role'],
      roleName: json['roleName'],
    );
  }
}

class AuthService {
  final _supabase = Supabase.instance.client;
  final _dio = ApiClient().dio;

  Future<AuthResponse> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    return await _supabase.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_business_id');
    await prefs.remove('active_business_name');
    await _supabase.auth.signOut();
  }

  Future<Map<String, dynamic>> fetchCurrentUserAndBusinesses() async {
    final response = await _dio.get('/auth/me');
    return response.data as Map<String, dynamic>;
  }

  static Future<void> saveActiveBusiness(String id, String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('active_business_id', id);
    await prefs.setString('active_business_name', name);
  }

  static Future<String?> getActiveBusinessId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('active_business_id');
  }

  static Future<String?> getActiveBusinessName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('active_business_name');
  }
}
