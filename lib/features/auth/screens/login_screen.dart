import 'package:flutter/material.dart';
import 'package:abc_app/core/theme/app_theme.dart';
import 'package:abc_app/features/auth/services/auth_service.dart';
import 'package:abc_app/features/home/home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

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
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.signInWithEmailPassword(
        email: email,
        password: password,
      );

      final meData = await _authService.fetchCurrentUserAndBusinesses();
      final business = meData['business'];

      if (!mounted) return;

      if (business != null && business['id'] != null) {
        await AuthService.saveActiveBusiness(
          business['id'],
          business['name'] ?? 'Cửa hàng',
        );

        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } else {
        setState(() {
          _errorMessage = 'Tài khoản này chưa thuộc cửa hàng nào hoặc đang bị tạm khóa.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Đăng nhập không thành công. Vui lòng kiểm tra lại thông tin kết nối.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text(
                          'ABC',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            letterSpacing: -0.5,
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
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primary,
                      letterSpacing: -0.5,
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
                    onPressed: _isLoading ? null : _handleLogin,
                    child: _isLoading
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Truy cập hệ thống'),
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
