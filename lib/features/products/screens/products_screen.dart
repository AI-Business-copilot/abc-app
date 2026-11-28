import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:abc_app/features/products/models/product_model.dart';
import 'package:abc_app/features/products/services/products_service.dart';
import 'package:abc_app/features/products/screens/barcode_scanner_screen.dart';
import 'package:abc_app/features/products/screens/barcode_label_screen.dart';
import 'package:abc_app/features/products/screens/edit_product_screen.dart';
import 'package:abc_app/features/products/screens/manage_catalog_screen.dart';
import 'package:abc_app/features/auth/services/auth_service.dart';
import 'package:abc_app/features/purchases/screens/create_purchase_order_screen.dart';

class _SkuDisplayItem {
  final ProductItem parent;
  final ProductVariant variant;

  _SkuDisplayItem({required this.parent, required this.variant});

  String get displayName {
    if (variant.title.isEmpty || variant.title == 'Mặc định' || variant.title == variant.sku) {
      return parent.name;
    }
    return '${parent.name} (${variant.title})';
  }

  String get unitLabel {
    final lower = '${parent.name} ${parent.categoryName ?? ''}'.toLowerCase();
    if (lower.contains('serum') || lower.contains('nước') || lower.contains('tẩy trang') || lower.contains('toner')) {
      return 'chai';
    }
    if (lower.contains('son')) return 'thỏi';
    if (lower.contains('giày') || lower.contains('dép') || lower.contains('sneaker')) return 'đôi';
    if (lower.contains('kem')) return 'hũ';
    return 'cái';
  }
}

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _productsService = ProductsService();
  final _searchController = TextEditingController();
  final _currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

  List<ProductItem> _products = [];
  bool _isLoading = false;
  String? _error;

  // 'all' | 'in_stock' | 'low_stock' | 'out_of_stock'
  String _stockFilter = 'all';
  // 'default' | 'stock_asc' | 'stock_desc' | 'price_desc'
  String _sortMode = 'default';

  static const Color _bgCream = Color(0xFFFDFBF7);
  static const Color _brandRed = Color(0xFFB91C1C);
  static const Color _cardBorder = Color(0xFFEFECE6);

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts({String? keyword}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final items = await _productsService.getProducts(keyword: keyword);
      if (mounted) {
        setState(() {
          _products = items;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Không thể kết nối đến máy chủ. Hãy kiểm tra kết nối mạng của bạn.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openScanner() async {
    final scannedBarcode = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );

    if (scannedBarcode != null && scannedBarcode.isNotEmpty) {
      _searchController.text = scannedBarcode;
      _loadProducts(keyword: scannedBarcode);
    }
  }

  List<_SkuDisplayItem> get _allVariants {
    final list = <_SkuDisplayItem>[];
    for (final p in _products) {
      if (p.variants.isEmpty) {
        list.add(_SkuDisplayItem(
          parent: p,
          variant: ProductVariant(
            id: p.id,
            sku: p.code.isNotEmpty ? p.code : 'SKU-${p.id.substring(0, 4)}',
            title: 'Mặc định',
            basePrice: p.avgPrice,
            costPrice: 0,
            totalOnHand: p.totalStock,
          ),
        ));
      } else {
        for (final v in p.variants) {
          list.add(_SkuDisplayItem(parent: p, variant: v));
        }
      }
    }
    return list;
  }

  List<_SkuDisplayItem> get _filteredVariants {
    final all = _allVariants;
    final filtered = all.where((item) {
      final qty = item.variant.totalOnHand;
      if (_stockFilter == 'in_stock') return qty > 0;
      if (_stockFilter == 'low_stock') return qty > 0 && qty <= 5;
      if (_stockFilter == 'out_of_stock') return qty <= 0;
      return true;
    }).toList();

    if (_sortMode == 'stock_asc') {
      filtered.sort((a, b) => a.variant.totalOnHand.compareTo(b.variant.totalOnHand));
    } else if (_sortMode == 'stock_desc') {
      filtered.sort((a, b) => b.variant.totalOnHand.compareTo(a.variant.totalOnHand));
    } else if (_sortMode == 'price_desc') {
      filtered.sort((a, b) => b.variant.basePrice.compareTo(a.variant.basePrice));
    }

    return filtered;
  }

  void _cycleSortMode() {
    setState(() {
      if (_sortMode == 'default') {
        _sortMode = 'stock_asc';
      } else if (_sortMode == 'stock_asc') {
        _sortMode = 'stock_desc';
      } else if (_sortMode == 'stock_desc') {
        _sortMode = 'price_desc';
      } else {
        _sortMode = 'default';
      }
    });
    final labels = {
      'default': 'Sắp xếp: Mặc định',
      'stock_asc': 'Sắp xếp: Tồn kho tăng dần',
      'stock_desc': 'Sắp xếp: Tồn kho giảm dần',
      'price_desc': 'Sắp xếp: Giá bán cao đến thấp',
    };
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(labels[_sortMode]!), duration: const Duration(seconds: 1)),
    );
  }

  void _openFilterMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tùy chọn & Bộ lọc nâng cao',
                style: TextStyle(fontFamily: 'PlayfairDisplay', fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 14),
              ListTile(
                leading: const Icon(Icons.category_outlined, color: _brandRed),
                title: const Text('Quản lý Danh mục & Thuộc tính', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Cấu hình danh mục, màu sắc, kích cỡ'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageCatalogScreen()));
                  _loadProducts(keyword: _searchController.text);
                },
              ),
              ListTile(
                leading: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF1E293B)),
                title: const Text('Quét mã vạch (Barcode)', style: TextStyle(fontWeight: FontWeight.w700)),
                onTap: () {
                  Navigator.pop(ctx);
                  _openScanner();
                },
              ),
              ListTile(
                leading: const Icon(Icons.refresh_rounded, color: Color(0xFF475569)),
                title: const Text('Làm mới dữ liệu kho', style: TextStyle(fontWeight: FontWeight.w700)),
                onTap: () {
                  Navigator.pop(ctx);
                  _loadProducts(keyword: _searchController.text);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openPurchaseOrder(_SkuDisplayItem item) async {
    if (!AuthService.hasPermission('inventory.receive')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bạn cần quyền inventory.receive để đặt hàng NCC.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CreatePurchaseOrderScreen(
          initialVariantId: item.variant.id,
          initialSku: item.variant.sku,
          initialProductName: item.parent.name,
        ),
      ),
    );
  }

  void _openItemActions(_SkuDisplayItem item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.displayName,
                style: const TextStyle(fontFamily: 'PlayfairDisplay', fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
              ),
              Text('SKU: ${item.variant.sku}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              const Divider(height: 20),
              ListTile(
                leading: const Icon(Icons.qr_code_2_rounded, color: Color(0xFF1E293B)),
                title: const Text('In tem mã vạch SKU này', style: TextStyle(fontWeight: FontWeight.w700)),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BarcodeLabelScreen(product: item.parent, variant: item.variant),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit_outlined, color: _brandRed),
                title: const Text('Sửa thông tin sản phẩm cha', style: TextStyle(fontWeight: FontWeight.w700)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final updated = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => EditProductScreen(product: item.parent)),
                  );
                  if (updated == true) _loadProducts(keyword: _searchController.text);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final all = _allVariants;
    final inStockCount = all.where((i) => i.variant.totalOnHand > 0).length;
    final lowStockCount = all.where((i) => i.variant.totalOnHand > 0 && i.variant.totalOnHand <= 5).length;
    final outStockCount = all.where((i) => i.variant.totalOnHand <= 0).length;
    final displayList = _filteredVariants;

    return Scaffold(
      backgroundColor: _bgCream,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageCatalogScreen()));
        },
        backgroundColor: _brandRed,
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        elevation: 4,
        child: const Icon(Icons.add, size: 28),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Header: Danh Sách Hàng Hóa + Nút Bộ lọc
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Danh Sách Hàng Hóa',
                          style: TextStyle(
                            fontFamily: 'PlayfairDisplay',
                            fontSize: 25,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.4,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Quản lý và tra cứu tất cả sản phẩm trong cửa hàng',
                          style: TextStyle(
                            fontFamily: 'PlayfairDisplay',
                            fontSize: 12.5,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: _openFilterMenu,
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      child: Column(
                        children: const [
                          Icon(Icons.tune_rounded, size: 22, color: Color(0xFF0F172A)),
                          SizedBox(height: 2),
                          Text(
                            'Bộ lọc',
                            style: TextStyle(
                              fontFamily: 'PlayfairDisplay',
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 2. Search Bar & Sort Button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _cardBorder),
                        boxShadow: const [
                          BoxShadow(color: Color(0x06000000), blurRadius: 6, offset: Offset(0, 2)),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(fontFamily: 'PlayfairDisplay', fontSize: 13.5, color: Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          hintText: 'Tìm kiếm sản phẩm, mã SKU, barcode...',
                          hintStyle: const TextStyle(fontFamily: 'PlayfairDisplay', fontSize: 13, color: Color(0xFF94A3B8)),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 13),
                          prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF64748B)),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_searchController.text.isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF94A3B8)),
                                  onPressed: () {
                                    _searchController.clear();
                                    _loadProducts();
                                  },
                                ),
                              IconButton(
                                icon: const Icon(Icons.qr_code_scanner_rounded, size: 18, color: _brandRed),
                                tooltip: 'Quét mã vạch',
                                onPressed: _openScanner,
                              ),
                            ],
                          ),
                        ),
                        onSubmitted: (val) => _loadProducts(keyword: val),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  InkWell(
                    onTap: _cycleSortMode,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      height: 46,
                      width: 46,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _cardBorder),
                        boxShadow: const [
                          BoxShadow(color: Color(0x06000000), blurRadius: 6, offset: Offset(0, 2)),
                        ],
                      ),
                      child: const Icon(Icons.swap_vert_rounded, color: Color(0xFF475569), size: 22),
                    ),
                  ),
                ],
              ),
            ),

            // 3. Thanh Filter Pills cuộn ngang (Tất cả, Còn hàng, Cảnh báo tồn, Hết hàng)
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _buildFilterPill('all', 'Tất cả (${all.length})'),
                  const SizedBox(width: 8),
                  _buildFilterPill('in_stock', 'Còn hàng ($inStockCount)'),
                  const SizedBox(width: 8),
                  _buildFilterPill('low_stock', 'Cảnh báo tồn ($lowStockCount)', textColor: const Color(0xFFB45309)),
                  const SizedBox(width: 8),
                  _buildFilterPill('out_of_stock', 'Hết hàng ($outStockCount)', textColor: _brandRed),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // 4. Dòng thống kê số lượng biến thể hiển thị
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Hiển thị ${displayList.length} / ${all.length} biến thể',
                style: const TextStyle(
                  fontFamily: 'PlayfairDisplay',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF475569),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // 5. Danh sách thẻ SKU Biến thể
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: _brandRed),
                      ),
                    )
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.wifi_off_rounded, size: 38, color: Color(0xFF94A3B8)),
                                const SizedBox(height: 10),
                                Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                                const SizedBox(height: 14),
                                OutlinedButton(
                                  onPressed: () => _loadProducts(keyword: _searchController.text),
                                  style: OutlinedButton.styleFrom(foregroundColor: _brandRed, side: const BorderSide(color: _cardBorder)),
                                  child: const Text('Thử lại'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : displayList.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.inventory_2_outlined, size: 42, color: Color(0xFF94A3B8)),
                                  const SizedBox(height: 8),
                                  const Text('Không có biến thể nào', style: TextStyle(fontFamily: 'PlayfairDisplay', fontWeight: FontWeight.w700, fontSize: 15)),
                                  const SizedBox(height: 4),
                                  Text(
                                    _searchController.text.isNotEmpty ? 'Thử tìm với từ khóa hoặc mã barcode khác' : 'Thử chuyển sang bộ lọc trạng thái khác',
                                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              color: _brandRed,
                              onRefresh: () => _loadProducts(keyword: _searchController.text),
                              child: ListView.separated(
                                padding: const EdgeInsets.fromLTRB(16, 4, 16, 84),
                                itemCount: displayList.length,
                                separatorBuilder: (context, index) => const SizedBox(height: 12),
                                itemBuilder: (context, index) => _buildSkuCard(displayList[index]),
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPill(String id, String label, {Color? textColor}) {
    final active = _stockFilter == id;
    return GestureDetector(
      onTap: () => setState(() => _stockFilter = id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: active ? _brandRed : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? _brandRed : _cardBorder),
          boxShadow: active ? const [BoxShadow(color: Color(0x24B91C1C), blurRadius: 6, offset: Offset(0, 2))] : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'PlayfairDisplay',
              fontSize: 12,
              fontWeight: active ? FontWeight.w800 : FontWeight.w600,
              color: active ? Colors.white : (textColor ?? const Color(0xFF334155)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSkuCard(_SkuDisplayItem item) {
    final qty = item.variant.totalOnHand;
    final isOutOfStock = qty <= 0;
    final isLowStock = qty > 0 && qty <= 5;
    final imgUrl = item.parent.imageUrl;

    return Container(
      padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _cardBorder, width: 1.0),
          boxShadow: const [
            BoxShadow(color: Color(0x07000000), blurRadius: 10, offset: Offset(0, 3)),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Thumbnail bên trái (84x84), nếu hết hàng có overlay tối + tag HẾT HÀNG đỏ
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 84,
                height: 84,
                child: isOutOfStock
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          Container(
                            color: const Color(0xFF475569),
                            child: const Center(
                              child: Icon(Icons.inventory_2_outlined, size: 28, color: Color(0xFFCBD5E1)),
                            ),
                          ),
                          Positioned(
                            left: 0,
                            bottom: 18,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: const BoxDecoration(
                                color: _brandRed,
                                borderRadius: BorderRadius.horizontal(right: Radius.circular(6)),
                              ),
                              child: const Text(
                                'HẾT',
                                style: TextStyle(fontFamily: 'PlayfairDisplay', fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white),
                              ),
                            ),
                          ),
                          const Positioned(
                            left: 6,
                            bottom: 3,
                            child: Text(
                              'HÀNG',
                              style: TextStyle(fontFamily: 'PlayfairDisplay', fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white),
                            ),
                          ),
                        ],
                      )
                    : Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          image: imgUrl != null && imgUrl.isNotEmpty
                              ? DecorationImage(image: NetworkImage(imgUrl), fit: BoxFit.cover)
                              : null,
                        ),
                        child: imgUrl == null || imgUrl.isEmpty
                            ? const Icon(Icons.image_outlined, size: 28, color: Color(0xFF94A3B8))
                            : null,
                      ),
              ),
            ),
            const SizedBox(width: 14),

            // Nội dung bên phải
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Dòng 1: Tên sản phẩm + Badge Tồn: 0 (nếu hết hàng)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          item.displayName,
                          style: const TextStyle(
                            fontFamily: 'PlayfairDisplay',
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isOutOfStock) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFE4E6),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFFCA5A5), width: 0.8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.cancel_outlined, size: 12, color: _brandRed),
                              const SizedBox(width: 4),
                              Text(
                                'Tồn: 0 ${item.unitLabel}',
                                style: const TextStyle(
                                  fontFamily: 'PlayfairDisplay',
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: _brandRed,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Dòng 2: SKU code
                  Text(
                    'SKU: ${item.variant.sku}',
                    style: TextStyle(
                      fontFamily: 'PlayfairDisplay',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: isOutOfStock ? _brandRed : const Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),

                  // Dòng 3: Tồn & Giá bán (hoặc Giá bán & Nút + Đặt NCC nếu hết hàng)
                  if (isOutOfStock)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _currencyFormat.format(item.variant.basePrice),
                          style: const TextStyle(
                            fontFamily: 'PlayfairDisplay',
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: _brandRed,
                          ),
                        ),
                        InkWell(
                          onTap: () => _openPurchaseOrder(item),
                          borderRadius: BorderRadius.circular(18),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _brandRed,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.shopping_cart_outlined, size: 14, color: Colors.white),
                                SizedBox(width: 5),
                                Text(
                                  '+ Đặt NCC',
                                  style: TextStyle(
                                    fontFamily: 'PlayfairDisplay',
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(fontFamily: 'PlayfairDisplay', fontSize: 12.5, color: Color(0xFF475569)),
                            children: [
                              const TextSpan(text: 'Tồn:  '),
                              TextSpan(
                                text: '$qty',
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w900,
                                  color: isLowStock ? const Color(0xFFD97706) : const Color(0xFF15803D),
                                ),
                              ),
                              TextSpan(text: '  ${item.unitLabel}'),
                            ],
                          ),
                        ),
                        Text(
                          _currencyFormat.format(item.variant.basePrice),
                          style: const TextStyle(
                            fontFamily: 'PlayfairDisplay',
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: _brandRed,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(width: 2),
            IconButton(
              icon: const Icon(Icons.more_horiz, size: 18, color: Color(0xFF64748B)),
              tooltip: 'Tác vụ sản phẩm',
              visualDensity: VisualDensity.compact,
              onPressed: () => _openItemActions(item),
            ),
          ],
        ),
    );
  }
}
