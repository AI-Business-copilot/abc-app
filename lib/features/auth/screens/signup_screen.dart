import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:abc_app/features/auth/screens/login_screen.dart';
import 'package:abc_app/features/auth/services/auth_service.dart';
import 'package:abc_app/features/auth/widgets/abc_logo.dart';
import 'package:abc_app/features/auth/widgets/google_logo.dart';
import 'package:abc_app/features/home/home_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> with WidgetsBindingObserver {
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  String? _successMessage;

  StreamSubscription<AuthState>? _authSubscription;
  Timer? _resumeTimer;
  bool _authHandled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (state) {
        if (state.event == AuthChangeEvent.signedIn) {
          _finishAuth();
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!mounted) return;
        setState(() {
          _isGoogleLoading = false;
          _errorMessage = AuthService.authErrorMessage(
            error,
            fallback: 'Không thể đăng ký với Google.',
          );
        });
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (!_isGoogleLoading) return;

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
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _finishAuth() async {
    if (_authHandled) return;
    _authHandled = true;

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

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  Future<void> _handleSignup() async {
    final fullName = _fullNameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Vui lòng nhập đầy đủ Email và Mật khẩu.';
        _successMessage = null;
      });
      return;
    }

    if (password.length < 6) {
      setState(() {
        _errorMessage = 'Mật khẩu phải chứa ít nhất 6 ký tự.';
        _successMessage = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final res = await _authService.signUpWithEmail(
        email: email,
        password: password,
        fullName: fullName.isNotEmpty ? fullName : null,
      );

      if (!mounted) return;

      if (res.session != null) {
        await _finishAuth();
      } else {
        setState(() {
          _isLoading = false;
          _successMessage = 'Đăng ký thành công! Hãy kiểm tra hộp thư email $email để kích hoạt tài khoản của bạn.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = AuthService.authErrorMessage(
          e,
          fallback: 'Đăng ký không thành công. Vui lòng kiểm tra lại thông tin.',
        );
      });
    }
  }

  Future<void> _handleGoogleSignup() async {
    setState(() {
      _authHandled = false;
      _isGoogleLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final launched = await _authService.signInWithGoogle();
      if (!launched && mounted) {
        setState(() {
          _isGoogleLoading = false;
          _errorMessage = 'Không thể mở trình duyệt để đăng ký với Google.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isGoogleLoading = false;
        _errorMessage = AuthService.authErrorMessage(
          e,
          fallback: 'Không thể đăng ký với Google.',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 390),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo ABC theo chuan Web Dashboard
                  const Center(
                    child: AbcLogo(showBadge: true, size: 28),
                  ),
                  const SizedBox(height: 24),

                  // Heading Serif
                  const Text(
                    'Tạo tài khoản mới',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'serif',
                      fontSize: 25,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Subtitle
                  const Text(
                    'Bắt đầu quản lý kho và bán hàng cùng ABC Copilot',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 26),

                  // Success Alert
                  if (_successMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.mark_email_read_rounded, color: Color(0xFF059669), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _successMessage!,
                              style: const TextStyle(color: Color(0xFF065F46), fontSize: 12.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Error Alert
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFC1121F).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Color(0xFFC1121F), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: Color(0xFF991B1B), fontSize: 12.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Field 1: Họ và tên
                  const Text(
                    'Họ và tên',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _fullNameController,
                    textInputAction: TextInputAction.next,
                    style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      hintText: 'Hương Phạm',
                      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      prefixIcon: const Icon(
                        Icons.person_outline_rounded,
                        color: Color(0xFF64748B),
                        size: 20,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFF0F4C3A), width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Field 2: Email
                  const Text(
                    'Email',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      hintText: 'kim.pham@vinaclothes.com',
                      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      prefixIcon: const Icon(
                        Icons.mail_outline_rounded,
                        color: Color(0xFF64748B),
                        size: 20,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFF0F4C3A), width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Field 3: Mật khẩu
                  const Text(
                    'Mật khẩu',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _handleSignup(),
                    style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      hintText: '••••••••••••••',
                      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      prefixIcon: const Icon(
                        Icons.lock_outline_rounded,
                        color: Color(0xFF64748B),
                        size: 20,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          color: const Color(0xFF64748B),
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFF0F4C3A), width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Điều khoản dịch vụ & Chính sách bảo mật
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: RichText(
                      textAlign: TextAlign.center,
                      text: const TextSpan(
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF64748B),
                          height: 1.45,
                        ),
                        children: [
                          TextSpan(text: 'Bằng việc bấm Đăng ký, bạn đồng ý với '),
                          TextSpan(
                            text: 'Điều khoản dịch vụ',
                            style: TextStyle(
                              color: Color(0xFF0F4C3A),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextSpan(text: ' & '),
                          TextSpan(
                            text: 'Chính sách bảo mật',
                            style: TextStyle(
                              color: Color(0xFF0F4C3A),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextSpan(text: ' của ABC.'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Nút Đăng ký tài khoản
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleSignup,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F4C3A),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.person_add_alt_1_rounded, size: 18, color: Colors.white),
                                SizedBox(width: 8),
                                Text(
                                  'Đăng ký tài khoản',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Divider "hoặc tiếp tục với"
                  Row(
                    children: [
                      const Expanded(child: Divider(color: Color(0xFFE2E8F0), thickness: 1)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'hoặc tiếp tục với',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ),
                      const Expanded(child: Divider(color: Color(0xFFE2E8F0), thickness: 1)),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Nút Đăng ký với Google
                  SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed: _isGoogleLoading ? null : _handleGoogleSignup,
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF0F172A),
                        side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isGoogleLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0F4C3A)),
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                GoogleLogo(size: 20),
                                SizedBox(width: 10),
                                Text(
                                  'Đăng ký với Google',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Đã có tài khoản? Đăng nhập ngay
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Đã có tài khoản? ',
                        style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                      ),
                      GestureDetector(
                        onTap: () {
                          if (Navigator.of(context).canPop()) {
                            Navigator.of(context).pop();
                          } else {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(builder: (_) => const LoginScreen()),
                            );
                          }
                        },
                        child: const Text(
                          'Đăng nhập ngay  ➔',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F4C3A),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Footer
                  const Center(
                    child: Text(
                      'ABC – Retail & Inventory Management',
                      style: TextStyle(
                        fontFamily: 'serif',
                        fontSize: 11.5,
                        color: Color(0xFF94A3B8),
                        letterSpacing: 0.2,
                      ),
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
