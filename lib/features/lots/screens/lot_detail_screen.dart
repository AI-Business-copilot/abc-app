import 'package:flutter/material.dart';
import 'package:abc_app/core/network/api_error.dart';
import 'package:abc_app/core/theme/app_theme.dart';
import 'package:abc_app/core/widgets/app_widgets.dart';
import 'package:abc_app/features/auth/services/auth_service.dart';
import 'package:abc_app/features/lots/models/lot_models.dart';
import 'package:abc_app/features/lots/services/lots_service.dart';
import 'package:abc_app/features/scrap/screens/create_scrap_order_screen.dart';
import 'package:abc_app/features/scrap/screens/scrap_detail_screen.dart';

/// F08 — one lot item. Staff can quarantine it and then raise a scrap order for it.
class LotDetailScreen extends StatefulWidget {
  const LotDetailScreen({super.key, required this.lotItem});

  final LotItem lotItem;

  @override
  State<LotDetailScreen> createState() => _LotDetailScreenState();
}

class _LotDetailScreenState extends State<LotDetailScreen> {
  final _service = LotsService();

  late LotItem _lot = widget.lotItem;
  bool _isActing = false;
  String? _error;

  Future<void> _refresh() async {
    try {
      final batch = await _service.getLot(_lot.lotId);
      final updated = batch.items.where((item) => item.id == _lot.id).toList();
      if (!mounted) return;
      if (updated.isNotEmpty) {
        setState(() => _lot = updated.first);
      }
    } catch (_) {
      // Keep the copy we already have: the screen still shows the last known state.
    }
  }

  Future<void> _quarantine() async {
    final quantity = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _QuarantineSheet(lot: _lot),
    );
    if (quantity == null || !mounted) return;

    setState(() {
      _isActing = true;
      _error = null;
    });
    try {
      await _service.quarantineLot(_lot.lotId, _lot.id, quantity: quantity);
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã cách ly lô hàng')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  Future<void> _createScrapOrder() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CreateScrapOrderScreen(lotItem: _lot),
      ),
    );
    if (created == true) {
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final lot = _lot;
    final color = switch (lot.effectiveStatus) {
      LotStatus.healthy => AppTheme.success,
      LotStatus.warning => AppTheme.warning,
      LotStatus.unusable => AppTheme.danger,
      LotStatus.quarantined => AppTheme.accent,
      LotStatus.scrapped => AppTheme.muted,
    };
    final canQuarantine = AuthService.hasPermission(AppPermissions.scrapCreate) &&
        lot.effectiveStatus != LotStatus.scrapped &&
        lot.effectiveStatus != LotStatus.quarantined &&
        lot.totalStock > 0;
    final canCreateScrap = AuthService.hasPermission(AppPermissions.scrapCreate) &&
        lot.effectiveStatus == LotStatus.quarantined &&
        lot.scrapOrder == null;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('Lô ${lot.lotNumber}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_error != null) MessageBanner(message: _error!, isError: true),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lot.variant.productName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'SKU: ${lot.variant.sku} • Lô ${lot.lotNumber}',
                    style: const TextStyle(fontSize: 12, color: AppTheme.muted),
                  ),
                  const SizedBox(height: 10),
                  StatusBadge(label: lot.effectiveStatus.label, color: color),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                children: [
                  _DetailRow(
                    label: 'Hạn sử dụng',
                    value: formatDay(lot.expirationDate),
                  ),
                  _DetailRow(
                    label: 'Ngày sản xuất',
                    value: formatDay(lot.manufacturingDate),
                  ),
                  _DetailRow(label: 'Tồn có thể bán', value: '${lot.onHand}'),
                  _DetailRow(label: 'Hàng hư hỏng', value: '${lot.damaged}'),
                  _DetailRow(
                    label: 'Còn lại ngày',
                    value: lot.daysUntilExpiry <= 0
                        ? 'Quá hạn ${-lot.daysUntilExpiry} ngày'
                        : '${lot.daysUntilExpiry} ngày',
                  ),
                  if (lot.quarantineQty != null)
                    _DetailRow(label: 'Đang cách ly', value: '${lot.quarantineQty}'),
                  if (lot.quarantinedAt != null)
                    _DetailRow(
                      label: 'Cách ly lúc',
                      value: formatDateTime(lot.quarantinedAt),
                    ),
                ],
              ),
            ),
            if (lot.scrapOrder != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lô này đã có phiếu hủy ${lot.scrapOrder!.scrapCode}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.accent,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Mỗi lô chỉ được có một phiếu hủy.',
                      style: TextStyle(fontSize: 11.5, color: AppTheme.muted),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ScrapDetailScreen(scrapOrderId: lot.scrapOrder!.id),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: const Text('Xem phiếu hủy', style: TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            if (canQuarantine)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isActing ? null : _quarantine,
                  icon: const Icon(Icons.block_rounded, size: 18),
                  label: const Text('Cách ly lô hàng'),
                ),
              ),
            if (canCreateScrap) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isActing ? null : _createScrapOrder,
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('Tạo phiếu hủy hàng'),
                ),
              ),
            ],
            if (!canQuarantine && !canCreateScrap && lot.scrapOrder == null)
              const MessageBanner(
                message: 'Lô này hiện không có thao tác nào khả dụng cho tài khoản của bạn.',
              ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.muted)),
          Text(
            value,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.primary),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet that asks for the quantity to pull off the shelf.
class _QuarantineSheet extends StatefulWidget {
  const _QuarantineSheet({required this.lot});

  final LotItem lot;

  @override
  State<_QuarantineSheet> createState() => _QuarantineSheetState();
}

class _QuarantineSheetState extends State<_QuarantineSheet> {
  late final TextEditingController _controller =
      TextEditingController(text: '${widget.lot.totalStock}');
  final _noteController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _submit() {
    final quantity = int.tryParse(_controller.text.trim());
    if (quantity == null || quantity <= 0) {
      setState(() => _error = 'Số lượng phải là số nguyên lớn hơn 0.');
      return;
    }
    if (quantity > widget.lot.totalStock) {
      setState(() => _error = 'Lô này chỉ còn ${widget.lot.totalStock} sản phẩm.');
      return;
    }
    Navigator.of(context).pop(quantity);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cách ly lô hàng',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.primary),
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.lot.variant.productName} • SKU ${widget.lot.variant.sku} • lô ${widget.lot.lotNumber}',
              style: const TextStyle(fontSize: 12, color: AppTheme.muted),
            ),
            const SizedBox(height: 14),
            if (_error != null) MessageBanner(message: _error!, isError: true),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                labelText: 'Số lượng cách ly (tối đa ${widget.lot.totalStock})',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              maxLines: 2,
              maxLength: 500,
              style: const TextStyle(fontSize: 14),
              decoration: const InputDecoration(labelText: 'Ghi chú (không bắt buộc)'),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Hủy'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(onPressed: _submit, child: const Text('Cách ly')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
