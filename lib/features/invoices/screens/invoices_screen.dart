import 'dart:async';

import 'package:flutter/material.dart';
import 'package:abc_app/core/auth/permission_gate.dart';
import 'package:abc_app/core/theme/app_theme.dart';
import 'package:abc_app/features/auth/services/auth_service.dart';
import '../models/invoice_models.dart';
import '../services/invoice_service.dart';

enum _TimeRange { all, today, week, month }

/// Tab "Hóa đơn" — tra cứu đơn bán hàng trên mobile.
class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  final _service = InvoiceService();
  final _searchController = TextEditingController();

  InvoicePage _page = InvoicePage(
    items: const [],
    page: 1,
    pageSize: 20,
    total: 0,
    totalPages: 1,
  );
  Timer? _debounce;
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;
  String? _keyword;
  String? _status;
  _TimeRange _range = _TimeRange.all;

  @override
  void initState() {
    super.initState();
    if (_canRead()) _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  bool _canRead() => AuthService.hasPermission('orders.read');

  DateTime? get _from {
    final now = DateTime.now();
    switch (_range) {
      case _TimeRange.today:
        return DateTime(now.year, now.month, now.day);
      case _TimeRange.week:
        return DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
      case _TimeRange.month:
        return DateTime(now.year, now.month, now.day).subtract(const Duration(days: 29));
      case _TimeRange.all:
        return null;
    }
  }

  DateTime? get _to {
    if (_range == _TimeRange.all) return null;
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  Future<void> _load({bool append = false}) async {
    if (!_canRead()) return;
    setState(() {
      if (append) {
        _loadingMore = true;
      } else {
        _loading = true;
        _error = null;
      }
    });

    final nextPage = append ? _page.page + 1 : 1;
    try {
      final result = await _service.getInvoices(
        search: _keyword,
        status: _status,
        from: _from,
        to: _to,
        page: nextPage,
        pageSize: 20,
      );
      if (!mounted) return;
      setState(() {
        _page = append
            ? InvoicePage(
                items: [..._page.items, ...result.items],
                page: result.page,
                pageSize: result.pageSize,
                total: result.total,
                totalPages: result.totalPages,
              )
            : result;
      });
    } catch (e) {
      if (mounted) setState(() => _error = _message(e));
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() => _keyword = value.trim());
      _load();
    });
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchController.clear();
    setState(() => _keyword = null);
    _load();
  }

  String _message(Object error) {
    final text = error.toString();
    if (text.contains('403')) return 'Bạn không có quyền truy xuất hóa đơn.';
    if (text.contains('404')) return 'Không tìm thấy hóa đơn.';
    return 'Không tải được hóa đơn. Kiểm tra kết nối máy chủ.';
  }

  void _openDetail(InvoiceOrder invoice) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InvoiceDetailScreen(id: invoice.id, code: invoice.code),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_canRead()) {
      return const Scaffold(
        backgroundColor: AppTheme.background,
        body: PermissionDeniedView(
          message: 'Bạn không có quyền orders.read để truy xuất hóa đơn.',
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Hóa đơn'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Làm mới',
            onPressed: _loading ? null : () => _load(),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearch(),
          _buildFilters(),
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  Widget _buildSearch() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      color: AppTheme.surface,
      child: TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search,
        onChanged: _onSearchChanged,
        onSubmitted: (value) {
          _debounce?.cancel();
          setState(() => _keyword = value.trim());
          _load();
        },
        decoration: InputDecoration(
          hintText: 'Tìm theo mã hóa đơn (ví dụ: DH-2026-001)',
          prefixIcon: const Icon(Icons.search_rounded, size: 19),
          suffixIcon: _searchController.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded, size: 17),
                  tooltip: 'Xóa tìm kiếm',
                  onPressed: _clearSearch,
                ),
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 30,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _TimeRange.values.length,
              separatorBuilder: (_, _) => const SizedBox(width: 7),
              itemBuilder: (context, index) {
                final range = _TimeRange.values[index];
                final label = switch (range) {
                  _TimeRange.all => 'Tất cả',
                  _TimeRange.today => 'Hôm nay',
                  _TimeRange.week => '7 ngày',
                  _TimeRange.month => '30 ngày',
                };
                return _filterChip(
                  label: label,
                  active: _range == range,
                  onTap: () {
                    if (_range == range) return;
                    setState(() => _range = range);
                    _load();
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 30,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 4,
              separatorBuilder: (_, _) => const SizedBox(width: 7),
              itemBuilder: (context, index) {
                final status = switch (index) {
                  0 => null,
                  1 => 'COMPLETED',
                  2 => 'DRAFT',
                  _ => 'CANCELLED',
                };
                final label = switch (status) {
                  null => 'Mọi trạng thái',
                  'COMPLETED' => 'Hoàn tất',
                  'DRAFT' => 'Nháp',
                  _ => 'Đã hủy',
                };
                return _filterChip(
                  label: label,
                  active: _status == status,
                  onTap: () {
                    if (_status == status) return;
                    setState(() => _status = status);
                    _load();
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          color: active ? AppTheme.accent : AppTheme.background,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: active ? AppTheme.accent : AppTheme.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: active ? FontWeight.w800 : FontWeight.w600,
            color: active ? Colors.white : AppTheme.muted,
          ),
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 38, color: AppTheme.subtle),
              const SizedBox(height: 10),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.muted, fontSize: 13),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => _load(),
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }
    if (_page.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.receipt_long_outlined, size: 42, color: AppTheme.subtle),
              SizedBox(height: 10),
              Text(
                'Không có hóa đơn nào',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppTheme.primary),
              ),
              SizedBox(height: 4),
              Text(
                'Thử đổi bộ lọc ngày, trạng thái hoặc mã hóa đơn.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: AppTheme.muted),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: AppTheme.accent,
      onRefresh: () => _load(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: _page.items.length + (_page.hasMore ? 1 : 0),
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          if (index == _page.items.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: OutlinedButton(
                onPressed: _loadingMore ? null : () => _load(append: true),
                child: _loadingMore
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Xem thêm hóa đơn'),
              ),
            );
          }
          return _buildCard(_page.items[index]);
        },
      ),
    );
  }

  Widget _buildCard(InvoiceOrder invoice) {
    final statusColor = switch (invoice.status.toUpperCase()) {
      'COMPLETED' => AppTheme.success,
      'CANCELLED' => AppTheme.danger,
      'DRAFT' => AppTheme.warning,
      _ => AppTheme.muted,
    };

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        onTap: () => _openDetail(invoice),
        leading: const CircleAvatar(
          backgroundColor: AppTheme.accentBg,
          foregroundColor: AppTheme.accent,
          child: Icon(Icons.receipt_outlined, size: 18),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                'HĐ ${invoice.code.isNotEmpty ? invoice.code : invoice.id.substring(0, invoice.id.length.clamp(0, 8))}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                invoiceStatusLabel(invoice.status),
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: statusColor),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${formatInvoiceDate(invoice.createdAt)}  •  ${invoice.itemCount} món',
                style: const TextStyle(fontSize: 11, color: AppTheme.muted),
              ),
              if (invoice.customerName.isNotEmpty)
                Text(
                  'Khách: ${invoice.customerName}',
                  style: const TextStyle(fontSize: 11, color: AppTheme.muted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        trailing: SizedBox(
          width: 108,
          child: Text(
            formatInvoiceMoney(invoice.totalNetAmount),
            textAlign: TextAlign.right,
            maxLines: 2,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppTheme.accent,
            ),
          ),
        ),
        isThreeLine: true,
      ),
    );
  }
}

/// Màn hình chi tiết một hóa đơn: hàng hóa, giảm giá, thanh toán.
class InvoiceDetailScreen extends StatefulWidget {
  final String id;
  final String code;

  const InvoiceDetailScreen({super.key, required this.id, required this.code});

  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends State<InvoiceDetailScreen> {
  final _service = InvoiceService();
  InvoiceOrder? _invoice;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final invoice = await _service.getInvoice(widget.id);
      if (mounted) setState(() => _invoice = invoice);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('Hóa đơn ${widget.code.isNotEmpty ? widget.code : ""}'),
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
                        const Icon(Icons.error_outline_rounded, size: 38, color: AppTheme.danger),
                        const SizedBox(height: 10),
                        Text(
                          'Không tải được chi tiết hóa đơn.\n$_error',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13, color: AppTheme.muted),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(onPressed: _load, child: const Text('Thử lại')),
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
                      _buildSummary(_invoice!),
                      const SizedBox(height: 12),
                      _buildItems(_invoice!.items),
                      const SizedBox(height: 12),
                      _buildPayments(_invoice!.payments),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSummary(InvoiceOrder invoice) {
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
            Text(
              invoice.code,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 6),
            _row('Trạng thái', invoiceStatusLabel(invoice.status)),
            _row('Ngày lập', formatInvoiceDate(invoice.createdAt)),
            if (invoice.customerName.isNotEmpty)
              _row('Khách hàng', invoice.customerName),
            if (invoice.customerPhone.isNotEmpty)
              _row('Điện thoại', invoice.customerPhone),
            const Divider(height: 18, color: AppTheme.border),
            _row('Tiền hàng', formatInvoiceMoney(invoice.totalGrossAmount)),
            _row('Giảm giá', formatInvoiceMoney(invoice.discountAmount)),
            _row(
              'Thanh toán',
              formatInvoiceMoney(invoice.totalNetAmount),
              bold: true,
              color: AppTheme.accent,
            ),
            _row('Lợi nhuận', formatInvoiceMoney(invoice.grossProfit)),
          ],
        ),
      ),
    );
  }

  Widget _buildItems(List<InvoiceItem> items) {
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
              const Text('Không có dòng hàng.', style: TextStyle(color: AppTheme.muted)),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.productName,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${item.sku}  •  SL: ${item.quantity}'
                            '${item.lotNumber.isNotEmpty ? "  •  Lô: ${item.lotNumber}" : ""}',
                            style: const TextStyle(fontSize: 11, color: AppTheme.muted),
                          ),
                          Text(
                            'Đơn giá: ${formatInvoiceMoney(item.unitPrice)}',
                            style: const TextStyle(fontSize: 11, color: AppTheme.muted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      formatInvoiceMoney(item.subtotal),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
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

  Widget _buildPayments(List<InvoicePayment> payments) {
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
              'Thanh toán',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
            const SizedBox(height: 10),
            if (payments.isEmpty)
              const Text('Chưa có phiếu thu.', style: TextStyle(color: AppTheme.muted)),
            ...payments.map(
              (payment) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            invoicePaymentLabel(payment.method),
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                          ),
                          if (payment.reference.isNotEmpty)
                            Text(
                              payment.reference,
                              style: const TextStyle(fontSize: 11, color: AppTheme.muted),
                            ),
                        ],
                      ),
                    ),
                    Text(
                      formatInvoiceMoney(payment.amount),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
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

  Widget _row(String label, String value, {bool bold = false, Color? color}) {
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
