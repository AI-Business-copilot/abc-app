import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:abc_app/core/config/app_config.dart';
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

/// Permission codes used by the F07 / F08 flows.
class AppPermissions {
  static const auditCreate = 'inventory.audit.create';
  static const auditCount = 'inventory.audit.count';
  static const auditSubmitItem = 'inventory.audit.submit_item';
  static const auditApproveItem = 'inventory.audit.approve_item';
  static const lotRead = 'inventory.lot.read';
  static const scrapCreate = 'inventory.scrap.create';
  static const scrapApprove = 'inventory.scrap.approve';
}

class AuthService {
  final _supabase = Supabase.instance.client;
  final _dio = ApiClient().dio;

  /// Session cache. Loaded once at start-up so permission checks can be synchronous.
  static String? _role;
  static String? _userId;
  static List<String> _permissions = const [];

  static const _kRole = 'active_business_role';
  static const _kUserId = 'active_user_id';
  static const _kPermissions = 'active_business_permissions';

  static String? get role => _role;
  static String? get userId => _userId;
  static List<String> get permissions => _permissions;
  static bool get isOwner => _role == 'OWNER';
  static bool get isStaff => _role == 'STAFF';

  static bool hasPermission(String code) => _permissions.contains(code);

  Future<AuthResponse> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    return await _supabase.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Đăng ký tài khoản mới bằng Email và Mật khẩu.
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    String? fullName,
  }) async {
    return await _supabase.auth.signUp(
      email: email.trim(),
      password: password,
      data: fullName != null && fullName.trim().isNotEmpty
          ? {'full_name': fullName.trim()}
          : null,
    );
  }

  /// Gửi liên kết đặt lại mật khẩu về email.
  Future<void> sendPasswordResetEmail({
    required String email,
  }) async {
    await _supabase.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: AppConfig.oauthRedirectUrl,
    );
  }

  /// Đăng nhập bằng Google thông qua OAuth của Supabase.
  ///
  /// Mở trình duyệt hệ thống, sau đó Supabase trả kết quả về app qua deep link
  /// (native) hoặc qua chính trang hiện tại (web). Phiên đăng nhập được đọc
  /// qua `onAuthStateChange`.
  Future<bool> signInWithGoogle() async {
    return await _supabase.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: AppConfig.oauthRedirectUrl,
      queryParams: const {'access_type': 'offline', 'prompt': 'consent'},
    );
  }

  /// Hoàn tất đăng nhập: đồng bộ user, cửa hàng, role và permissions.
  ///
  /// Trả về `null` khi thành côông, hoặc thông báo lỗi để hiển thị.
  Future<String?> completeSignIn() async {
    final Map<String, dynamic> meData;
    try {
      meData = await fetchCurrentUserAndBusinesses();
    } catch (e) {
      return 'Lỗi gọi API backend: $e';
    }

    final business = meData['business'];
    final permissions = (meData['permissions'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        const <String>[];
    final user = meData['user'];

    if (business is Map<String, dynamic> && business['id'] != null) {
      await AuthService.saveActiveBusiness(
        business['id'].toString(),
        business['name']?.toString() ?? 'Cửa hàng',
        role: business['role']?.toString(),
        permissions: permissions,
        userId: user is Map<String, dynamic> ? user['id']?.toString() : null,
      );
      return null;
    }

    return 'Tài khoản này chưa thuộc cửa hàng nào hoặc đang bị tạm khóa.';
  }

  /// Dịch lỗi OAuth/Supabase sang thông báo tiếng Việt.
  static String authErrorMessage(Object error, {String fallback = 'Không thể đăng nhập.'}) {
    if (error is AuthException) {
      switch (error.code) {
        case 'email_not_confirmed':
          return 'Email chưa được xác nhận. Hãy mở email xác nhận tài khoản rồi thử đăng nhập lại.';
        case 'user_already_exists':
          return 'Email này đã được đăng ký. Vui lòng đăng nhập hoặc dùng email khác.';
        case 'weak_password':
          return 'Mật khẩu phải có ít nhất 6 ký tự.';
        case 'over_email_send_rate_limit':
          return 'Hệ thống đang bận hoặc gửi quá nhiều yêu cầu. Vui lòng thử lại sau ít phút.';
        case 'invalid_credentials':
          return 'Email hoặc mật khẩu không đúng.';
        case 'user_not_found':
          return 'Không tìm thấy tài khoản với email này.';
        case 'user_banned':
          return 'Tài khoản đã bị khóa. Vui lòng liên hệ quản trị viên.';
        case 'access_denied':
          return 'Bạn đã từ chối quyền truy cập. Vui lòng thử lại.';
        case 'server_error':
          return 'Máy chủ đăng nhập đang bận. Vui lòng thử lại sau.';
      }
      if (error.message.isNotEmpty) return error.message;
    }
    return fallback;
  }

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_business_id');
    await prefs.remove('active_business_name');
    await prefs.remove(_kRole);
    await prefs.remove(_kUserId);
    await prefs.remove(_kPermissions);
    _role = null;
    _userId = null;
    _permissions = const [];
    await _supabase.auth.signOut();
  }

  Future<Map<String, dynamic>> fetchCurrentUserAndBusinesses() async {
    final response = await _dio.get('/auth/me');
    return response.data as Map<String, dynamic>;
  }

  /// Persists the active business together with the role and permissions of the session.
  static Future<void> saveActiveBusiness(
    String id,
    String name, {
    String? role,
    List<String> permissions = const [],
    String? userId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('active_business_id', id);
    await prefs.setString('active_business_name', name);
    if (role != null) await prefs.setString(_kRole, role);
    await prefs.setStringList(_kPermissions, permissions);
    if (userId != null) await prefs.setString(_kUserId, userId);
    _role = role ?? _role;
    _permissions = permissions;
    _userId = userId ?? _userId;
  }

  static Future<String?> getActiveBusinessId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('active_business_id');
  }

  static Future<String?> getActiveBusinessName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('active_business_name');
  }

  /// Reads the cached session from disk into memory.
  static Future<void> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    _role = prefs.getString(_kRole);
    _userId = prefs.getString(_kUserId);
    _permissions = prefs.getStringList(_kPermissions) ?? const [];
  }

  /// Refreshes role and permissions from `/auth/me`.
  /// Returns the raw payload so the caller can read the business block.
  Future<Map<String, dynamic>?> refreshSession() async {
    try {
      final data = await fetchCurrentUserAndBusinesses();
      final business = data['business'];
      final permissions = (data['permissions'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[];
      final user = data['user'];

      if (business is Map<String, dynamic> && business['id'] != null) {
        await saveActiveBusiness(
          business['id'].toString(),
          business['name']?.toString() ?? 'Cửa hàng',
          role: business['role']?.toString(),
          permissions: permissions,
          userId: user is Map<String, dynamic> ? user['id']?.toString() : null,
        );
      } else {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('active_business_id');
        await prefs.remove('active_business_name');
        _role = null;
        _permissions = const [];
      }
      return data;
    } catch (_) {
      // A failed refresh must not log the user out: the cached session stays valid.
      await loadSession();
      return null;
    }
  }
}
