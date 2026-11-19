import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:abc_app/core/theme/app_theme.dart';
import 'package:abc_app/features/auth/services/auth_service.dart';
import 'package:abc_app/features/auth/widgets/google_logo.dart';
import 'package:abc_app/features/home/home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with WidgetsBindingObserver {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  StreamSubscription<AuthState>? _authSubscription;
  Timer? _resumeTimer;

  /// Đảm bảo chỉ một luồng đăng nhập được đi tiếp (email hoặc Google).
  bool _loginHandled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (state) {
        if (state.event == AuthChangeEvent.signedIn) {
          _finishSignIn();
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        // Lỗi OAuth (người dùng từ chối, sai redirect, ...) được phát ra ở đây.
        if (!mounted) return;
        setState(() {
          _isGoogleLoading = false;
          _errorMessage = AuthService.authErrorMessage(
            error,
            fallback: 'Không thể đăng nhập với Google.',
          );
        });
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (!_isGoogleLoading) return;

    // Người dùng có thể đóng trình duyệt OAuth mà không đăng nhập.
    // Chờ nhịp để deep link được xử lý xong rồi mới bỏ trạng thái đang tải.
    _resumeTimer?.cancel();
    _resumeTimer = Timer(const Duration(milliseconds: 800), () {
      if (!mounted || !_isGoogleLoading) return;
      if (Supabase.instance.client.auth.currentSession != null) return;
      setState(() {
        _isGoogleLoading = false;
      });
    });
  }

  @override
  void dispose() {
    _resumeTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _authSubscription?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Đồng bộ user / cửa hàng / role / permissions rồi chuyển sang HomeScreen.
  ///
  /// Được gọi từ sự kiện `signedIn` của Supabase (Google OAuth hoặc deep link)
  /// và từ luồng đăng nhập email. `_loginHandled` đảm bảo chỉ một lần.
  Future<void> _finishSignIn() async {
    if (_loginHandled) return;
    _loginHandled = true;

    final error = await _authService.completeSignIn();
    if (!mounted) return;

    if (error != null) {
      setState(() {
        _isLoading = false;
        _isGoogleLoading = false;
        _errorMessage = error;
      });
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Vui lòng nhập đầy đủ Email và Mật khẩu.';
      });
      return;
    }

    setState(() {
      _loginHandled = false;
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.signInWithEmailPassword(
        email: email,
        password: password,
      );
      await _finishSignIn();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = AuthService.authErrorMessage(
          e,
          fallback: 'Đăng nhập không thành công. Vui lòng kiểm tra lại thông tin kết nối.',
        );
      });
    }
  }

  Future<void> _handleGoogleLogin() async {
    setState(() {
      _loginHandled = false;
      _isGoogleLoading = true;
      _errorMessage = null;
    });

    try {
      final launched = await _authService.signInWithGoogle();
      if (!launched && mounted) {
        setState(() {
          _isGoogleLoading = false;
          _errorMessage = 'Không thể mở trình duyệt để đăng nhập với Google.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isGoogleLoading = false;
        _errorMessage = AuthService.authErrorMessage(
          e,
          fallback: 'Không thể đăng nhập với Google.',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _isLoading || _isGoogleLoading;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Minimal Brand Signet
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppTheme.accent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Text(
                          'ABC',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Đăng nhập tài khoản',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primary,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Hệ thống quản lý vận hành bán lẻ & kho hàng',
                    style: TextStyle(
                      fontSize: 13.5,
                      color: AppTheme.muted,
                    ),
                  ),
                  const SizedBox(height: 28),

                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.dangerBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.danger.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: AppTheme.danger, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: AppTheme.danger, fontSize: 12.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Email
                  const Text(
                    'Email công việc',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primary),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'ten@cuahang.com',
                      prefixIcon: Icon(Icons.mail_outline_rounded, size: 18, color: AppTheme.muted),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Password
                  const Text(
                    'Mật khẩu',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primary),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Nhập mật khẩu',
                      prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18, color: AppTheme.muted),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          size: 18,
                          color: AppTheme.muted,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  ElevatedButton(
                    onPressed: busy ? null : _handleLogin,
                    child: _isLoading
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Truy cập hệ thống'),
                  ),
                  const SizedBox(height: 12),

                  // Đăng nhập bằng Google
                  OutlinedButton(
                    onPressed: busy ? null : _handleGoogleLogin,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                      side: const BorderSide(color: AppTheme.border),
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    child: _isGoogleLoading
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              GoogleLogo(size: 18),
                              SizedBox(width: 10),
                              Text('Tiếp tục với Google'),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
