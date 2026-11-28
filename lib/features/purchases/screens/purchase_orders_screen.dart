import 'dart:async';

import 'package:flutter/material.dart';
import 'package:abc_app/core/auth/permission_gate.dart';
import 'package:abc_app/core/theme/app_theme.dart';
import 'package:abc_app/core/utils/money_format.dart';
import 'package:abc_app/features/auth/services/auth_service.dart';
import '../models/purchase_models.dart';
import '../services/purchases_service.dart';
import 'create_purchase_order_screen.dart';
import 'purchase_order_detail_screen.dart';

/// Tab "Đặt hàng" — danh sách đơn đặt hàng NCC (PO).
class PurchaseOrdersScreen extends StatefulWidget {
  const PurchaseOrdersScreen({super.key});

  @override
  State<PurchaseOrdersScreen> createState() => _PurchaseOrdersScreenState();
}

class _PurchaseOrdersScreenState extends State<PurchaseOrdersScreen> {
  final _service = PurchasesService();
  final _searchController = TextEditingController();

  static const _statuses = <String?>[
    null,
    'DRAFT',
    'ORDERED',
    'PARTIALLY_RECEIVED',
    'COMPLETED',
    'CLOSED_SHORT',
    'CANCELLED',
  ];

  PurchaseOrderPage _page = PurchaseOrderPage(
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

  bool get _canRead =>
      AuthService.hasPermission('inventory.read') &&
      AuthService.hasPermission('finance.read');

  bool get _canWrite => AuthService.hasPermission('inventory.receive');

  @override
  void initState() {
    super.initState();
    if (_canRead) _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({bool append = false}) async {
    if (!_canRead) return;
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
      final result = await _service.getOrders(
        search: _keyword,
        status: _status,
        page: nextPage,
        pageSize: 20,
      );
      if (!mounted) return;
      setState(() {
        _page = append
            ? PurchaseOrderPage(
                items: [..._page.items, ...result.items],
                page: result.page,
                pageSize: result.pageSize,
                total: result.total,
                totalPages: result.totalPages,
              )
            : result;
      });
    } catch (e) {
      if (mounted) setState(() => _error = _service.messageOf(e));
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

  Future<void> _openCreate() async {
    if (!_canWrite) {
      _showMessage('Bạn cần quyền inventory.receive để đặt hàng NCC.');
      return;
    }
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CreatePurchaseOrderScreen()),
    );
    if (created == true && mounted) {
      _showMessage('Đã gửi đơn đặt hàng nhà cung cấp.');
      _load();
    }
  }

  void _openDetail(PurchaseOrder order) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PurchaseOrderDetailScreen(id: order.id, code: order.code),
      ),
    );
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_canRead) {
      return const Scaffold(
        backgroundColor: AppTheme.background,
        body: PermissionDeniedView(
          message: 'Bạn cần quyền inventory.read + finance.read để xem đơn đặt hàng.',
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Đặt hàng NCC'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Làm mới',
            onPressed: _loading ? null : () => _load(),
          ),
        ],
      ),
      floatingActionButton: _canWrite
          ? FloatingActionButton.extended(
              onPressed: _openCreate,
              backgroundColor: AppTheme.accent,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_shopping_cart_rounded),
              label: const Text('Tạo PO'),
            )
          : null,
      body: Column(
        children: [
          _buildSearch(),
          _buildStatusFilter(),
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  Widget _buildSearch() {
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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
          hintText: 'Tìm theo mã PO (ví dụ: PO-20261128-A1B2)',
          prefixIcon: const Icon(Icons.search_rounded, size: 19),
          suffixIcon: _searchController.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded, size: 17),
                  tooltip: 'Xóa tìm kiếm',
                  onPressed: () {
                    _debounce?.cancel();
                    _searchController.clear();
                    setState(() => _keyword = null);
                    _load();
                  },
                ),
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildStatusFilter() {
    return Container(
      color: AppTheme.surface,
      height: 50,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _statuses.length,
        separatorBuilder: (_, _) => const SizedBox(width: 7),
        itemBuilder: (context, index) {
          final status = _statuses[index];
          final label = status == null ? 'Tất cả' : purchaseStatusLabel(status);
          final active = _status == status;
          return InkWell(
            onTap: () {
              if (active) return;
              setState(() => _status = status);
              _load();
            },
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
        },
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
              OutlinedButton(onPressed: () => _load(), child: const Text('Thử lại')),
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
            children: [
              const Icon(Icons.shopping_cart_outlined, size: 42, color: AppTheme.subtle),
              const SizedBox(height: 10),
              const Text(
                'Chưa có đơn đặt hàng nào',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Bấm "Tạo PO" để lập đơn cho nhà cung cấp.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: AppTheme.muted),
              ),
              if (_canWrite) ...[
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  onPressed: _openCreate,
                  icon: const Icon(Icons.add_rounded, size: 17),
                  label: const Text('Tạo PO đầu tiên'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: AppTheme.accent,
      onRefresh: () => _load(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
        itemCount: _page.items.length + (_page.hasMore ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 8),
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
                    : const Text('Xem thêm đơn hàng'),
              ),
            );
          }
          return _buildCard(_page.items[index]);
        },
      ),
    );
  }

  Widget _buildCard(PurchaseOrder order) {
    final color = purchaseStatusColor(order.status);
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        onTap: () => _openDetail(order),
        leading: CircleAvatar(
          backgroundColor: AppTheme.accentBg,
          foregroundColor: AppTheme.accent,
          child: const Icon(Icons.local_shipping_outlined, size: 18),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                order.code.isNotEmpty ? order.code : order.id,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13.5,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                purchaseStatusLabel(order.status),
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color),
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
                '${order.supplierName.isEmpty ? 'NCC' : order.supplierName}  •  ${order.itemCount} SKU',
                style: const TextStyle(fontSize: 11, color: AppTheme.muted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                'Đặt ${formatPurchaseDate(order.orderDate)}  •  Dự kiến giao ${formatPurchaseDate(order.expectedDeliveryDate)}',
                style: const TextStyle(fontSize: 11, color: AppTheme.muted),
              ),
              Text(
                'Đã nhận ${order.totals.receivedQty}/${order.totals.orderedQty}',
                style: const TextStyle(fontSize: 11, color: AppTheme.accent),
              ),
            ],
          ),
        ),
        trailing: SizedBox(
          width: 108,
          child: Text(
            formatDecimalMoney(order.totals.orderedAmount),
            textAlign: TextAlign.right,
            maxLines: 2,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppTheme.primary,
            ),
          ),
        ),
        isThreeLine: true,
      ),
    );
  }
}
