import 'package:flutter/material.dart';
import 'package:abc_app/core/theme/app_theme.dart';
import 'package:abc_app/features/auth/screens/login_screen.dart';
import 'package:abc_app/features/auth/services/auth_service.dart';
import 'package:abc_app/features/products/screens/products_screen.dart';
import 'package:abc_app/features/alerts/screens/alerts_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  String _businessName = 'Cửa hàng';
  final _authService = AuthService();

  final List<Widget> _screens = [
    const ProductsScreen(), // MOB-02
    const AlertsScreen(),   // MOB-05
  ];

  @override
  void initState() {
    super.initState();
    _loadBusinessInfo();
  }

  Future<void> _loadBusinessInfo() async {
    final name = await AuthService.getActiveBusinessName();
    if (name != null && mounted) {
      setState(() {
        _businessName = name;
      });
    }
  }

  Future<void> _handleSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Đăng xuất', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        content: const Text('Bạn có chắc chắn muốn đăng xuất khỏi tài khoản này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy', style: TextStyle(color: AppTheme.muted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _authService.signOut();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ABC COPILOT',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: AppTheme.muted,
              ),
            ),
            Text(
              _businessName,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.primary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, size: 20, color: AppTheme.muted),
            tooltip: 'Đăng xuất',
            onPressed: _handleSignOut,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppTheme.border, width: 1)),
        ),
        child: BottomNavigationBar(
          backgroundColor: AppTheme.surface,
          selectedItemColor: AppTheme.primary,
          unselectedItemColor: AppTheme.muted,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
          elevation: 0,
          currentIndex: _currentIndex,
          onTap: (idx) {
            setState(() {
              _currentIndex = idx;
            });
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.inventory_2_outlined, size: 20),
              activeIcon: Icon(Icons.inventory_2, size: 20),
              label: 'Kho & Hàng',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.notifications_active_outlined, size: 20),
              activeIcon: Icon(Icons.notifications_active, size: 20),
              label: 'Cảnh báo',
            ),
          ],
        ),
      ),
    );
  }
}
