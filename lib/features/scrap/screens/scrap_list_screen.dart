import 'package:flutter/material.dart';
import 'package:abc_app/core/network/api_error.dart';
import 'package:abc_app/core/theme/app_theme.dart';
import 'package:abc_app/core/widgets/app_widgets.dart';
import 'package:abc_app/features/scrap/models/scrap_models.dart';
import 'package:abc_app/features/scrap/screens/scrap_detail_screen.dart';
import 'package:abc_app/features/scrap/services/scrap_service.dart';

/// F08 — the scrap orders, split by status.
class ScrapListScreen extends StatefulWidget {
  const ScrapListScreen({super.key});

  @override
  State<ScrapListScreen> createState() => _ScrapListScreenState();
}

class _ScrapListScreenState extends State<ScrapListScreen> {
  final _service = ScrapService();

  List<ScrapOrder> _orders = [];
  ScrapStatistics _statistics = const ScrapStatistics();
  ScrapStatus _status = ScrapStatus.pending;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final orders = await _service.listScrapOrders(status: _status, take: 100);
      ScrapStatistics statistics = const ScrapStatistics();
      try {
        statistics = await _service.getStatistics();
      } catch (_) {
        // The statistics are only a summary: a failure must not hide the list.
      }
      if (!mounted) return;
      setState(() {
        _orders = orders.orders;
        _statistics = statistics;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: Row(
                children: [
                  _CountCard(
                    label: 'Chờ duyệt',
                    value: _statistics.pendingCount,
                    color: AppTheme.warning,
                  ),
                  const SizedBox(width: 8),
                  _CountCard(
                    label: 'Đã duyệt',
                    value: _statistics.completedCount,
                    color: AppTheme.success,
                  ),
                  const SizedBox(width: 8),
                  _CountCard(
                    label: 'Bị từ chối',
                    value: _statistics.rejectedCount,
                    color: AppTheme.danger,
                  ),
                ],
              ),
            ),
            Container(
              color: AppTheme.surface,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Row(
                children: [
                  const Icon(Icons.trending_down_rounded, size: 16, color: AppTheme.muted),
                  const SizedBox(width: 6),
                  const Text(
                    'Tổng giá trị tổn thất:',
                    style: TextStyle(fontSize: 12, color: AppTheme.muted),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    formatMoney(_statistics.totalLossValue),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.primary),
                  ),
                ],
              ),
            ),
            FilterChipBar<ScrapStatus>(
              options: ScrapStatus.values,
              selected: _status,
              labelOf: (value) => value.label,
              onSelected: (value) {
                setState(() => _status = value);
                _load();
              },
            ),
            Expanded(
              child: RefreshIndicator(
                color: AppTheme.primary,
                onRefresh: _load,
                child: _isLoading && _orders.isEmpty
                    ? const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                        ),
                      )
                    : _error != null
                        ? ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              const SizedBox(height: 40),
                              MessageBanner(message: _error!, isError: true),
                            ],
                          )
                        : _orders.isEmpty
                            ? ListView(
                                children: const [
                                  SizedBox(height: 40),
                                  EmptyStateView(
                                    title: 'Chưa có phiếu hủy nào',
                                    subtitle: 'Phiếu hủy do nhân viên tạo sẽ xuất hiện ở đây.',
                                    icon: Icons.receipt_long_outlined,
                                  ),
                                ],
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                                itemCount: _orders.length,
                                separatorBuilder: (_, _) => const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final order = _orders[index];
                                  return _ScrapOrderCard(
                                    order: order,
                                    onTap: () async {
                                      await Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => ScrapDetailScreen(scrapOrderId: order.id),
                                        ),
                                      );
                                      _load();
                                    },
                                  );
                                },
                              ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountCard extends StatelessWidget {
  const _CountCard({required this.label, required this.value, required this.color});

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$value',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 10.5, color: AppTheme.muted, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScrapOrderCard extends StatelessWidget {
  const _ScrapOrderCard({required this.order, required this.onTap});

  final ScrapOrder order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = switch (order.status) {
      ScrapStatus.pending => AppTheme.warning,
      ScrapStatus.completed => AppTheme.success,
      ScrapStatus.rejected => AppTheme.danger,
      ScrapStatus.cancelled => AppTheme.muted,
    };

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.scrapCode,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${order.variant.productName} • SKU ${order.variant.sku}',
                        style: const TextStyle(fontSize: 11.5, color: AppTheme.muted),
                      ),
                    ],
                  ),
                ),
                StatusBadge(label: order.status.label, color: color),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _MiniStat(label: 'Lô', value: order.lotItem?.lotNumber ?? '—'),
                _MiniStat(label: 'Số lượng', value: '${order.scrapQty}'),
                _MiniStat(label: 'Ảnh', value: '${order.imageCount}'),
                _MiniStat(label: 'Người tạo', value: order.createdByUser?.fullName ?? '—'),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Ngày tạo: ${formatDateTime(order.createdAt)}',
              style: const TextStyle(fontSize: 11, color: AppTheme.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppTheme.subtle, fontWeight: FontWeight.w600),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.primary),
        ),
      ],
    );
  }
}
