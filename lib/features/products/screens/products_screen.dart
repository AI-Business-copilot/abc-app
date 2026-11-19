import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:abc_app/core/theme/app_theme.dart';
import 'package:abc_app/features/products/models/product_model.dart';
import 'package:abc_app/features/products/services/products_service.dart';
import 'package:abc_app/features/products/screens/barcode_scanner_screen.dart';
import 'package:abc_app/features/products/screens/barcode_label_screen.dart';
import 'package:abc_app/features/products/screens/edit_product_screen.dart';
import 'package:abc_app/features/products/screens/manage_catalog_screen.dart';

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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Search & Scan Controls
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              color: AppTheme.surface,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(fontSize: 13.5),
                      decoration: InputDecoration(
                        hintText: 'Tìm theo tên, SKU, Barcode...',
                        prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppTheme.muted),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded, size: 16, color: AppTheme.subtle),
                                onPressed: () {
                                  _searchController.clear();
                                  _loadProducts();
                                },
                              )
                            : null,
                      ),
                      onSubmitted: (val) => _loadProducts(keyword: val),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: _openScanner,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      height: 48,
                      width: 48,
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.qr_code_scanner_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppTheme.border),

            // Item count & Catalog quick actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppTheme.surface,
              child: Row(
                children: [
                  Text(
                    '${_products.length} mặt hàng',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.muted,
                    ),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ManageCatalogScreen()),
                      );
                      _loadProducts(keyword: _searchController.text);
                    },
                    child: const Row(
                      children: [
                        Icon(Icons.category_outlined, size: 14, color: AppTheme.accent),
                        SizedBox(width: 4),
                        Text('Danh mục & Thuộc tính', style: TextStyle(fontSize: 12, color: AppTheme.accent, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: () => _loadProducts(keyword: _searchController.text),
                    child: const Row(
                      children: [
                        Icon(Icons.refresh_rounded, size: 14, color: AppTheme.muted),
                        SizedBox(width: 4),
                        Text('Cập nhật', style: TextStyle(fontSize: 12, color: AppTheme.muted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppTheme.border),

            // List Content
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                      ),
                    )
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.wifi_off_rounded, size: 36, color: AppTheme.subtle),
                                const SizedBox(height: 10),
                                Text(
                                  _error!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: AppTheme.muted, fontSize: 13),
                                ),
                                const SizedBox(height: 14),
                                OutlinedButton(
                                  onPressed: () => _loadProducts(keyword: _searchController.text),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.primary,
                                    side: const BorderSide(color: AppTheme.border),
                                  ),
                                  child: const Text('Thử lại'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _products.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.inventory_2_outlined, size: 40, color: AppTheme.subtle),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Không có sản phẩm nào',
                                    style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.primary, fontSize: 14),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _searchController.text.isNotEmpty
                                        ? 'Thử tìm với từ khóa hoặc mã barcode khác'
                                        : 'Chưa có mặt hàng trong kho',
                                    style: const TextStyle(fontSize: 12.5, color: AppTheme.muted),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              itemCount: _products.length,
                              separatorBuilder: (ctx, idx) => const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final product = _products[index];
                                return _buildProductRow(product);
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductRow(ProductItem product) {
    final inStock = product.totalStock > 0;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.border),
              image: product.imageUrl != null && product.imageUrl!.isNotEmpty
                  ? DecorationImage(image: NetworkImage(product.imageUrl!), fit: BoxFit.cover)
                  : null,
            ),
            child: product.imageUrl == null || product.imageUrl!.isEmpty
                ? const Icon(Icons.image_outlined, size: 20, color: AppTheme.subtle)
                : null,
          ),
          title: Text(
            product.name,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: AppTheme.primary,
              letterSpacing: -0.2,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Row(
              children: [
                if (product.categoryName != null) ...[
                  Text(
                    product.categoryName!,
                    style: const TextStyle(fontSize: 11.5, color: AppTheme.muted),
                  ),
                  const Text(' • ', style: TextStyle(color: AppTheme.subtle)),
                ],
                Text(
                  'Tồn: ',
                  style: const TextStyle(fontSize: 11.5, color: AppTheme.muted),
                ),
                Text(
                  '${product.totalStock}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: inStock ? AppTheme.success : AppTheme.danger,
                  ),
                ),
                const Spacer(),
                Text(
                  _currencyFormat.format(product.avgPrice),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
          ),
          children: [
            const Divider(height: 1, color: AppTheme.border),
            // Edit Header Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              color: AppTheme.surface,
              child: Row(
                children: [
                  Text('Mã: ${product.code}', style: const TextStyle(fontSize: 11.5, color: AppTheme.muted)),
                  const Spacer(),
                  InkWell(
                    onTap: () async {
                      final updated = await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => EditProductScreen(product: product)),
                      );
                      if (updated == true) {
                        _loadProducts(keyword: _searchController.text);
                      }
                    },
                    child: const Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 14, color: AppTheme.accent),
                        SizedBox(width: 4),
                        Text('Sửa thông tin / Đổi ảnh', style: TextStyle(fontSize: 12, color: AppTheme.accent, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppTheme.border),

            if (product.variants.isEmpty)
              const Padding(
                padding: EdgeInsets.all(12.0),
                child: Text('Không có dữ liệu biến thể.', style: TextStyle(color: AppTheme.muted, fontSize: 12)),
              )
            else
              Container(
                color: AppTheme.background,
                child: Column(
                  children: product.variants.map((v) {
                    final vStock = v.totalOnHand > 0;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: AppTheme.border, width: 0.5)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  v.title,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'SKU: ${v.sku}${v.barcode != null && v.barcode!.isNotEmpty ? " • ${v.barcode}" : ""}',
                                  style: const TextStyle(fontSize: 11, color: AppTheme.muted),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                _currencyFormat.format(v.basePrice),
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Tồn: ${v.totalOnHand}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: vStock ? AppTheme.success : AppTheme.danger,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 10),
                          IconButton(
                            icon: const Icon(Icons.print_outlined, size: 18, color: AppTheme.primary),
                            tooltip: 'In tem mã vạch',
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => BarcodeLabelScreen(product: product, variant: v),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
