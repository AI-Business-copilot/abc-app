import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:abc_app/core/theme/app_theme.dart';
import '../models/pos_model.dart';
import '../services/pos_service.dart';
import '../../products/models/product_model.dart';
import '../../products/services/products_service.dart';
import '../../products/screens/barcode_scanner_screen.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _posService = PosService();
  final _productsService = ProductsService();
  final _currency = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

  final List<CartItem> _cart = [];
  List<ProductItem> _products = [];
  List<PosOrderSummary> _orders = [];
  bool _isLoading = false;
  bool _isCheckingOut = false;
  String _searchKeyword = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final prods = await _productsService.getProducts();
    final ords = await _posService.getOrders();
    if (mounted) {
      setState(() {
        _products = prods;
        _orders = ords;
        _isLoading = false;
      });
    }
  }

  void _addToCart(ProductItem product, ProductVariant variant) {
    final existingIndex = _cart.indexWhere((item) => item.variantId == variant.id);
    setState(() {
      if (existingIndex >= 0) {
        _cart[existingIndex].quantity += 1;
      } else {
        _cart.add(
          CartItem(
            variantId: variant.id,
            sku: variant.sku,
            title: variant.title,
            productName: product.name,
            price: variant.basePrice,
          ),
        );
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã thêm ${product.name} (${variant.title}) vào đơn'),
        duration: const Duration(milliseconds: 700),
      ),
    );
  }

  double get _cartTotal => _cart.fold(0, (sum, item) => sum + item.subtotal);

  Future<void> _handleScanBarcode() async {
    final scanned = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (scanned == null || scanned.isEmpty) return;

    for (final p in _products) {
      for (final v in p.variants) {
        if (v.barcode == scanned || v.sku == scanned) {
          _addToCart(p, v);
          return;
        }
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không tìm thấy sản phẩm có mã: $scanned')),
      );
    }
  }

  Future<void> _handleCheckout() async {
    if (_cart.isEmpty) return;

    setState(() => _isCheckingOut = true);
    try {
      final order = await _posService.createOrder(items: _cart);
      if (mounted) {
        setState(() {
          _cart.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Thanh toán thành công đơn hàng #${order.code}!')),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tạo đơn: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCheckingOut = false);
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
      appBar: AppBar(
        title: const Text('Bán hàng POS (MOB-03)'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primary,
          indicatorColor: AppTheme.primary,
          tabs: [
            Tab(text: 'Tạo đơn (${_cart.length})'),
            Tab(text: 'Lịch sử (${_orders.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildCreateOrderTab(),
                _buildOrderHistoryTab(),
              ],
            ),
    );
  }

  Widget _buildCreateOrderTab() {
    final filtered = _products.where((p) {
      final kw = _searchKeyword.toLowerCase();
      return p.name.toLowerCase().contains(kw) ||
          p.variants.any((v) => v.sku.toLowerCase().contains(kw) || (v.barcode?.contains(kw) ?? false));
    }).toList();

    return Column(
      children: [
        // Search & Scanner
        Container(
          padding: const EdgeInsets.all(12),
          color: AppTheme.surface,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Tìm món hoặc SKU để thêm...',
                    prefixIcon: Icon(Icons.search_rounded, size: 18),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onChanged: (val) => setState(() => _searchKeyword = val),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _handleScanBarcode,
                icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                style: IconButton.styleFrom(backgroundColor: AppTheme.primary),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppTheme.border),

        // Products List to pick
        Expanded(
          flex: 4,
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: filtered.length,
            separatorBuilder: (ctx, idx) => const SizedBox(height: 6),
            itemBuilder: (context, idx) {
              final prod = filtered[idx];
              return Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(prod.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: prod.variants.map((v) {
                        return ActionChip(
                          avatar: const Icon(Icons.add, size: 14),
                          label: Text('${v.title} • ${_currency.format(v.basePrice)}', style: const TextStyle(fontSize: 11)),
                          onPressed: () => _addToCart(prod, v),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              );
            },
          ),
        ),

        // Cart Drawer
        if (_cart.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              color: AppTheme.surface,
              border: Border(top: BorderSide(color: AppTheme.border)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Text('Giỏ hàng tạm tính: ', style: TextStyle(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Text(_currency.format(_cartTotal), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.primary)),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isCheckingOut ? null : _handleCheckout,
                    child: _isCheckingOut
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text('Thanh toán ${_cart.length} món (${_currency.format(_cartTotal)})'),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildOrderHistoryTab() {
    if (_orders.isEmpty) {
      return const Center(child: Text('Chưa có đơn hàng nào được ghi nhận.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _orders.length,
      separatorBuilder: (ctx, idx) => const SizedBox(height: 8),
      itemBuilder: (context, idx) {
        final ord = _orders[idx];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Mã đơn: #${ord.code}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                    const SizedBox(height: 2),
                    Text('${ord.itemCount} món • ${ord.status}', style: const TextStyle(fontSize: 11.5, color: AppTheme.muted)),
                  ],
                ),
              ),
              Text(
                _currency.format(ord.finalAmount),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppTheme.primary),
              ),
            ],
          ),
        );
      },
    );
  }
}
