import 'package:flutter/material.dart';
import 'package:abc_app/core/theme/app_theme.dart';
import 'package:abc_app/features/lots/screens/lots_screen.dart';
import 'package:abc_app/features/scrap/screens/scrap_list_screen.dart';

/// F08 — the lots and the scrap orders, in two tabs.
class LotsAndScrapScreen extends StatefulWidget {
  const LotsAndScrapScreen({super.key});

  @override
  State<LotsAndScrapScreen> createState() => _LotsAndScrapScreenState();
}

class _LotsAndScrapScreenState extends State<LotsAndScrapScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: AppTheme.surface,
              child: TabBar(
                controller: _tabController,
                labelColor: AppTheme.primary,
                unselectedLabelColor: AppTheme.muted,
                indicatorColor: AppTheme.primary,
                indicatorWeight: 2,
                labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                tabs: const [
                  Tab(text: 'Lô hàng'),
                  Tab(text: 'Phiếu hủy'),
                ],
              ),
            ),
            const Divider(height: 1, color: AppTheme.border),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [
                  LotsScreen(),
                  ScrapListScreen(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
