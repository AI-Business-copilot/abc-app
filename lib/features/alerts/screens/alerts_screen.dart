import 'package:flutter/material.dart';
import 'package:abc_app/core/theme/app_theme.dart';
import 'package:abc_app/features/alerts/models/alert_models.dart';
import 'package:abc_app/features/alerts/services/alerts_service.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _alertsService = AlertsService();

  List<LotAlertItem> _expiringLots = [];
  List<LowStockAlertItem> _lowStockItems = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    setState(() {
      _isLoading = true;
    });

    final lots = await _alertsService.getExpiringLots();
    final lowStock = await _alertsService.getLowStockItems();

    if (mounted) {
      setState(() {
        _expiringLots = lots;
        _lowStockItems = lowStock;
        _isLoading = false;
      });
    }
  }

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
            // Header Tabs
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
                tabs: [
                  Tab(text: 'Hạn dùng (${_expiringLots.length})'),
                  Tab(text: 'Tồn thấp (${_lowStockItems.length})'),
                ],
              ),
            ),
            const Divider(height: 1, color: AppTheme.border),

            // Tab Views
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                      ),
                    )
                  : RefreshIndicator(
                      color: AppTheme.primary,
                      onRefresh: _loadAlerts,
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildExpiringLotsTab(),
                          _buildLowStockTab(),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpiringLotsTab() {
    if (_expiringLots.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.task_alt_rounded, size: 36, color: AppTheme.success),
            SizedBox(height: 8),
            Text(
              'Không có lô hàng cần xử lý',
              style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.primary, fontSize: 13.5),
            ),
            SizedBox(height: 4),
            Text(
              'Mọi lô hàng đều ở ngưỡng ngày an toàn',
              style: TextStyle(fontSize: 12, color: AppTheme.muted),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _expiringLots.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final lot = _expiringLots[index];
        final isExpired = lot.daysLeft <= 0;

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isExpired ? AppTheme.danger.withValues(alpha: 0.3) : AppTheme.warning.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 2),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isExpired ? AppTheme.danger : AppTheme.warning,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lot.productName,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppTheme.primary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Lô: ${lot.lotCode} • Biến thể: ${lot.variantTitle}',
                      style: const TextStyle(fontSize: 11.5, color: AppTheme.muted),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'HSD: ${lot.expirationDate} • ${isExpired ? "Quá hạn ${-lot.daysLeft} ngày" : "Còn ${lot.daysLeft} ngày"}',
                      style: TextStyle(
                        color: isExpired ? AppTheme.danger : AppTheme.warning,
                        fontWeight: FontWeight.w600,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'SL: ${lot.currentQuantity}',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.primary),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLowStockTab() {
    if (_lowStockItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.task_alt_rounded, size: 36, color: AppTheme.success),
            SizedBox(height: 8),
            Text(
              'Tồn kho an toàn',
              style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.primary, fontSize: 13.5),
            ),
            SizedBox(height: 4),
            Text(
              'Không có sản phẩm nào chạm ngưỡng tối thiểu',
              style: TextStyle(fontSize: 12, color: AppTheme.muted),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _lowStockItems.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = _lowStockItems[index];
        final isOut = item.currentStock == 0;

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isOut ? AppTheme.danger.withValues(alpha: 0.3) : AppTheme.border,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productName,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppTheme.primary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Biến thể: ${item.variantTitle} • SKU: ${item.sku}',
                      style: const TextStyle(fontSize: 11.5, color: AppTheme.muted),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${item.currentStock}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: isOut ? AppTheme.danger : AppTheme.warning,
                    ),
                  ),
                  Text(
                    isOut ? 'Hết hàng' : 'Tồn thấp',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: isOut ? AppTheme.danger : AppTheme.warning,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
