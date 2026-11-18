import 'package:flutter/material.dart';
import 'package:abc_app/core/network/api_error.dart';
import 'package:abc_app/core/theme/app_theme.dart';
import 'package:abc_app/core/widgets/app_widgets.dart';
import 'package:abc_app/features/auth/services/auth_service.dart';
import 'package:abc_app/features/lots/models/lot_models.dart';
import 'package:abc_app/features/lots/screens/lot_detail_screen.dart';
import 'package:abc_app/features/lots/services/lots_service.dart';
import 'package:abc_app/features/scrap/screens/create_scrap_order_screen.dart';

/// F08 — the lots that need attention, grouped by their effective status.
class LotsScreen extends StatefulWidget {
  const LotsScreen({super.key});

  @override
  State<LotsScreen> createState() => _LotsScreenState();
}

class _LotsScreenState extends State<LotsScreen> {
  final _service = LotsService();

  ExpiringLotsResult _result = const ExpiringLotsResult();
  LotStatus? _status;
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
      final result = await _service.getExpiringLots(status: _status, take: 100);
      if (!mounted) return;
      setState(() => _result = result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = _result.summary;
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
                    label: 'Bình thường',
                    value: summary.healthy,
                    color: AppTheme.success,
                  ),
                  const SizedBox(width: 8),
                  _CountCard(
                    label: 'Sắp hết hạn',
                    value: summary.warning,
                    color: AppTheme.warning,
                  ),
                  const SizedBox(width: 8),
                  _CountCard(
                    label: 'Hết hạn',
                    value: summary.unusable,
                    color: AppTheme.danger,
                  ),
                  const SizedBox(width: 8),
                  _CountCard(
                    label: 'Cách ly',
                    value: summary.quarantined,
                    color: AppTheme.accent,
                  ),
                  const SizedBox(width: 8),
                  _CountCard(
                    label: 'Đã hủy',
                    value: summary.scrapped,
                    color: AppTheme.muted,
                  ),
                ],
              ),
            ),
            FilterChipBar<LotStatus?>(
              options: const [
                null,
                LotStatus.warning,
                LotStatus.unusable,
                LotStatus.quarantined,
                LotStatus.healthy,
                LotStatus.scrapped,
              ],
              selected: _status,
              labelOf: (value) {
                switch (value) {
                  case LotStatus.warning:
                    return 'Sắp hết hạn';
                  case LotStatus.unusable:
                    return 'Hết hạn';
                  case LotStatus.quarantined:
                    return 'Cách ly';
                  case LotStatus.healthy:
                    return 'Bình thường';
                  case LotStatus.scrapped:
                    return 'Đã hủy';
                  default:
                    return 'Cần xử lý';
                }
              },
              onSelected: (value) {
                setState(() => _status = value);
                _load();
              },
            ),
            Expanded(
              child: RefreshIndicator(
                color: AppTheme.primary,
                onRefresh: _load,
                child: _isLoading && _result.lots.isEmpty
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
                        : _result.lots.isEmpty
                            ? ListView(
                                children: const [
                                  SizedBox(height: 40),
                                  EmptyStateView(
                                    title: 'Không có lô hàng cần xử lý',
                                    subtitle: 'Mọi lô hàng đều ở ngưỡng ngày an toàn.',
                                    icon: Icons.task_alt_rounded,
                                    iconColor: AppTheme.success,
                                  ),
                                ],
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                                itemCount: _result.lots.length,
                                separatorBuilder: (_, _) => const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final lot = _result.lots[index];
                                  return _LotCard(
                                    lot: lot,
                                    onTap: () async {
                                      await Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => LotDetailScreen(lotItem: lot),
                                        ),
                                      );
                                      _load();
                                    },
                                    onCreateScrap: (target) async {
                                      await Navigator.of(context).push<bool>(
                                        MaterialPageRoute(
                                          builder: (_) => CreateScrapOrderScreen(lotItem: target),
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

class _LotCard extends StatelessWidget {
  const _LotCard({required this.lot, required this.onTap, required this.onCreateScrap});

  final LotItem lot;
  final VoidCallback onTap;
  final void Function(LotItem lot) onCreateScrap;

  /// A pending order still blocks a new one; a rejected or cancelled one does not.
  bool get canCreateScrap =>
      lot.effectiveStatus == LotStatus.quarantined &&
      !lot.scrapOrderBlocksNew &&
      AuthService.hasPermission(AppPermissions.scrapCreate);

  @override
  Widget build(BuildContext context) {
    final color = switch (lot.effectiveStatus) {
      LotStatus.healthy => AppTheme.success,
      LotStatus.warning => AppTheme.warning,
      LotStatus.unusable => AppTheme.danger,
      LotStatus.quarantined => AppTheme.accent,
      LotStatus.scrapped => AppTheme.muted,
    };

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
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
                        lot.variant.productName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Lô ${lot.lotNumber} • SKU ${lot.variant.sku}',
                        style: const TextStyle(fontSize: 11.5, color: AppTheme.muted),
                      ),
                    ],
                  ),
                ),
                StatusBadge(label: lot.effectiveStatus.label, color: color),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'HSD ${formatDay(lot.expirationDate)} • ',
                  style: const TextStyle(fontSize: 11.5, color: AppTheme.muted),
                ),
                Text(
                  lot.daysUntilExpiry <= 0
                      ? 'Quá hạn ${-lot.daysUntilExpiry} ngày'
                      : 'Còn ${lot.daysUntilExpiry} ngày',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: lot.daysUntilExpiry <= 0 ? AppTheme.danger : AppTheme.warning,
                  ),
                ),
                const Spacer(),
                Text(
                  'Tồn ${lot.totalStock}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
            if (lot.scrapOrder != null) ...[
              const SizedBox(height: 6),
              Text(
                'Đã có phiếu hủy ${lot.scrapOrder!.scrapCode} • ${lot.scrapOrder!.statusLabel}',
                style: const TextStyle(fontSize: 11, color: AppTheme.accent),
              ),
            ],
            // A settled order does not block a new one, so the staff can file a fresh order
            // straight from the list, before opening the details.
            if (canCreateScrap)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => onCreateScrap(lot),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.danger,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: const Icon(Icons.delete_outline_rounded, size: 17),
                    label: const Text('Tạo phiếu hủy hàng', style: TextStyle(fontSize: 13)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
