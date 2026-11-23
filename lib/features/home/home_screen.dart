import 'package:flutter/material.dart';
import 'package:abc_app/core/theme/app_theme.dart';
import 'package:abc_app/features/auth/screens/login_screen.dart';
import 'package:abc_app/features/auth/services/auth_service.dart';
import 'package:abc_app/features/auth/widgets/abc_logo.dart';
import 'package:abc_app/features/products/screens/products_screen.dart';
import 'package:abc_app/features/alerts/screens/alerts_screen.dart';
import 'package:abc_app/features/audits/screens/audits_list_screen.dart';
import 'package:abc_app/features/lots/screens/lots_and_scrap_screen.dart';
import 'package:abc_app/features/pos/screens/pos_screen.dart';
import 'package:abc_app/features/kpi/screens/kpi_dashboard_screen.dart';
import 'package:abc_app/features/ai_advisor/screens/ai_advisor_screen.dart';

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
    const ProductsScreen(),       // MOB-02: Sản phẩm & Kho
    const PosScreen(),            // MOB-03: POS Bán hàng
    const AuditsListScreen(),     // MOB-04 / F07: Kiểm kho
    const LotsAndScrapScreen(),   // F08: Lô & Hủy hàng
    const AlertsScreen(),         // MOB-05: Cảnh báo
    const KpiDashboardScreen(),   // MOB-06: KPI & Báo cáo
    const AiAdvisorScreen(),      // MOB-07: AI Business Advisor
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
        titleSpacing: 14,
        title: Row(
          children: [
            const AbcLogo(showBadge: false, size: 20),
            const SizedBox(width: 12),
            Container(
              width: 1,
              height: 24,
              color: AppTheme.border,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _businessName,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primary,
                      letterSpacing: -0.2,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Text(
                    'Không gian vận hành ABC Mobile',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w400,
                      color: AppTheme.muted,
                    ),
                  ),
                ],
              ),
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
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppTheme.accent,
          unselectedItemColor: AppTheme.muted,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 10),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w400, fontSize: 10),
          elevation: 0,
          currentIndex: _currentIndex,
          onTap: (idx) {
            setState(() {
              _currentIndex = idx;
            });
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.inventory_2_outlined, size: 19),
              activeIcon: Icon(Icons.inventory_2, size: 19),
              label: 'Kho',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.point_of_sale_outlined, size: 19),
              activeIcon: Icon(Icons.point_of_sale, size: 19),
              label: 'POS',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.fact_check_outlined, size: 19),
              activeIcon: Icon(Icons.fact_check, size: 19),
              label: 'Kiểm kê',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.qr_code_2_outlined, size: 19),
              activeIcon: Icon(Icons.qr_code_2, size: 19),
              label: 'Lô & Hủy',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.notifications_active_outlined, size: 19),
              activeIcon: Icon(Icons.notifications_active, size: 19),
              label: 'Cảnh báo',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.insights_rounded, size: 19),
              activeIcon: Icon(Icons.insights, size: 19),
              label: 'KPI',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.smart_toy_outlined, size: 19),
              activeIcon: Icon(Icons.smart_toy, size: 19),
              label: 'AI',
            ),
          ],
        ),
      ),
    );
  }
}
