import 'package:flutter/material.dart';
import 'package:abc_app/core/auth/permission_gate.dart';
import 'package:abc_app/core/theme/app_theme.dart';
import 'package:abc_app/core/utils/money_format.dart';
import 'package:abc_app/features/auth/services/auth_service.dart';
import '../models/purchase_models.dart';
import '../services/purchases_service.dart';

/// Chi tiết đơn đặt hàng NCC: SKU, số lượng đã nhận/còn lại, tổng tiền.
class PurchaseOrderDetailScreen extends StatefulWidget {
  final String id;
  final String code;

  const PurchaseOrderDetailScreen({
    super.key,
    required this.id,
    required this.code,
  });

  @override
  State<PurchaseOrderDetailScreen> createState() =>
      _PurchaseOrderDetailScreenState();
}

class _PurchaseOrderDetailScreenState extends State<PurchaseOrderDetailScreen> {
  final _service = PurchasesService();
  PurchaseOrder? _order;
  String? _error;
  bool _loading = true;

  bool get _canRead =>
      AuthService.hasPermission('inventory.read') &&
      AuthService.hasPermission('finance.read');

  @override
  void initState() {
    super.initState();
    if (_canRead) {
      _load();
    } else {
      _loading = false;
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final order = await _service.getOrder(widget.id);
      if (mounted) setState(() => _order = order);
    } catch (e) {
      if (mounted) setState(() => _error = _service.messageOf(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_canRead) {
      return const Scaffold(
        backgroundColor: AppTheme.background,
        body: PermissionDeniedView(
          message: 'Bạn cần quyền inventory.read + finance.read để xem PO.',
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('PO ${widget.code}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Làm mới',
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          size: 38,
                          color: AppTheme.danger,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13, color: AppTheme.muted),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: _load,
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  color: AppTheme.accent,
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                    children: [
                      _buildHeader(_order!),
                      const SizedBox(height: 12),
                      _buildItems(_order!.items),
                      const SizedBox(height: 12),
                      _buildTotals(_order!.totals),
                    ],
                  ),
                ),
    );
  }

  Widget _buildHeader(PurchaseOrder order) {
    final color = purchaseStatusColor(order.status);
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    order.code.isNotEmpty ? order.code : order.id,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    purchaseStatusLabel(order.status),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _row('Nhà cung cấp', order.supplierName.isEmpty ? '—' : order.supplierName),
            if (order.supplierPhone.isNotEmpty)
              _row('Điện thoại', order.supplierPhone),
            _row('Ngày đặt', formatPurchaseDate(order.orderDate)),
            _row('Dự kiến giao', formatPurchaseDate(order.expectedDeliveryDate)),
            if (order.note.isNotEmpty) _row('Ghi chú', order.note),
          ],
        ),
      ),
    );
  }

  Widget _buildItems(List<PurchaseOrderItem> items) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Hàng hóa',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
            const SizedBox(height: 10),
            if (items.isEmpty)
              const Text(
                'Đơn chưa có dòng hàng.',
                style: TextStyle(fontSize: 12, color: AppTheme.muted),
              ),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.productName,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${item.sku} • Đơn giá ${formatDecimalMoney(item.unitPrice)}',
                            style: const TextStyle(fontSize: 11, color: AppTheme.muted),
                          ),
                          Text(
                            'Đặt ${item.orderedQty} • Đã nhận ${item.receivedQty} '
                            '• Còn ${item.remainingQty} ${item.unitOfMeasure}',
                            style: TextStyle(
                              fontSize: 11,
                              color: item.remainingQty > 0
                                  ? AppTheme.warning
                                  : AppTheme.success,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      formatDecimalMoney(item.subtotal),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotals(PurchaseOrderTotals totals) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tổng hợp',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
            const SizedBox(height: 8),
            _row('Số lượng đặt', '${totals.orderedQty}'),
            _row('Đã nhận', '${totals.receivedQty}'),
            _row('Giá trị đơn', formatDecimalMoney(totals.orderedAmount)),
            _row('Giá trị đã nhận', formatDecimalMoney(totals.receivedAmount)),
            _row('Đã thanh toán', formatDecimalMoney(totals.paidAmount)),
            _row(
              'Công nợ',
              formatDecimalMoney(totals.debtAmount),
              bold: true,
              color: AppTheme.danger,
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(
    String label,
    String value, {
    bool bold = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.muted)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                color: color ?? AppTheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
