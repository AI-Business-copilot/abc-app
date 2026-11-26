import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/app_config.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/services/auth_service.dart';
import 'features/home/home_screen.dart';

/// Cho phép kéo cuộn ngang bằng cả chuột, trackpad và cảm ứng trên mọi nền tảng
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    // ignore: deprecated_member_use
    anonKey: AppConfig.supabaseAnonKey,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final currentSession = Supabase.instance.client.auth.currentSession;

    return MaterialApp(
      title: 'ABC Business Copilot',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const AppScrollBehavior(),
      theme: AppTheme.lightTheme,
      home: currentSession != null
          ? const _AuthGuardScreen()
          : const LoginScreen(),
    );
  }
}

class _AuthGuardScreen extends StatefulWidget {
  const _AuthGuardScreen();

  @override
  State<_AuthGuardScreen> createState() => _AuthGuardScreenState();
}

class _AuthGuardScreenState extends State<_AuthGuardScreen> {
  @override
  void initState() {
    super.initState();
    _checkActiveBusiness();
  }

  Future<void> _checkActiveBusiness() async {
    await AuthService.loadSession();

    // Luôn refresh khi đã có phiên Supabase (kể cả khi cache cửa hàng còn
    // thiếu), để đăng nhập Google quay lại app từ deep link vẫn vào HomeScreen.
    if (Supabase.instance.client.auth.currentSession != null) {
      await AuthService().refreshSession();
      if (!mounted) return;
    }

    final activeId = await AuthService.getActiveBusinessId();
    if (!mounted) return;

    if (activeId != null && activeId.isNotEmpty) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
        ),
      ),
    );
  }
}
