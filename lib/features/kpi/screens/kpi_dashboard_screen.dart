import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:abc_app/core/theme/app_theme.dart';
import 'package:abc_app/features/auth/widgets/abc_logo.dart';
import '../models/kpi_model.dart';
import '../services/kpi_service.dart';

class KpiDashboardScreen extends StatefulWidget {
  const KpiDashboardScreen({super.key});

  @override
  State<KpiDashboardScreen> createState() => _KpiDashboardScreenState();
}

class _KpiDashboardScreenState extends State<KpiDashboardScreen> {
  final _kpiService = KpiService();
  final _currency = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
  DashboardKpi? _kpi;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadMetrics();
  }

  Future<void> _loadMetrics() async {
    setState(() => _isLoading = true);
    final data = await _kpiService.getDashboardMetrics();
    if (mounted) {
      setState(() {
        _kpi = data;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Báo cáo & KPI (MOB-06)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadMetrics,
          ),
        ],
      ),
      body: _isLoading || _kpi == null
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary))
          : RefreshIndicator(
              onRefresh: _loadMetrics,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Main Revenue Hero Card
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'DOANH THU HÔM NAY',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: Colors.white70),
                              ),
                              const AbcLogo(size: 16),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _currency.format(_kpi!.todayRevenue),
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white24,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${_kpi!.todayOrderCount} đơn đã tạo',
                                  style: const TextStyle(fontSize: 11.5, color: Colors.white, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'Chỉ số Vận hành & Kho hàng',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppTheme.primary),
                    ),
                    const SizedBox(height: 10),

                    // Metrics Grid
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricTile(
                            title: 'Tổng sản phẩm',
                            value: '${_kpi!.totalProducts}',
                            icon: Icons.inventory_2_outlined,
                            color: AppTheme.accent,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildMetricTile(
                            title: 'Tồn chạm ngưỡng',
                            value: '${_kpi!.totalLowStockCount}',
                            icon: Icons.warning_amber_rounded,
                            color: _kpi!.totalLowStockCount > 0 ? AppTheme.warning : AppTheme.success,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    _buildMetricTile(
                      title: 'Lô hàng cần theo dõi date',
                      value: '${_kpi!.totalExpiringLotsCount} lô',
                      icon: Icons.hourglass_bottom_rounded,
                      color: _kpi!.totalExpiringLotsCount > 0 ? AppTheme.danger : AppTheme.success,
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const Spacer(),
              Text(
                value,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontSize: 12, color: AppTheme.muted)),
        ],
      ),
    );
  }
}
