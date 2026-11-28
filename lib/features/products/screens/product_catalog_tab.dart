import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:abc_app/features/auth/services/auth_service.dart';
import 'package:abc_app/core/theme/product_ui.dart';
import 'package:abc_app/core/utils/image_url.dart';
import 'package:abc_app/core/utils/vi_text.dart';
import 'package:abc_app/features/products/models/product_model.dart';
import 'package:abc_app/features/products/services/products_service.dart';
import 'package:abc_app/features/products/screens/add_product_screen.dart';
import 'package:abc_app/features/products/screens/manage_catalog_screen.dart';
import 'package:abc_app/features/purchases/screens/create_purchase_order_screen.dart';

// ============================================================================
// Màu lấy từ ProductUi (đo trực tiếp trên abc-app/sku.png) — một nguồn duy nhất.
// ============================================================================
const _cBg = ProductUi.bg;
const _cCard = ProductUi.card;
const _cCardBorder = ProductUi.cardBorder;
const _cLine = ProductUi.line;
const _cInk = ProductUi.ink;
const _cSub = ProductUi.sub;
const _cPrimary = ProductUi.primary;
const _cWarn = ProductUi.warn;
const _cDanger = ProductUi.danger;
const _cButton = ProductUi.button;
const _cGreen = ProductUi.green;
const _cOutPillBg = ProductUi.outPillBg;
const _cOutTile = Color(0xFF4F5569); // nền ảnh khi hết hàng
const _cTile = ProductUi.tile;

/// Kích thước trong mockup là pixel của ảnh rộng 487px; máy thật ~406dp
/// nên chia 1,2 để giữ đúng tỉ lệ.
const _kSide = 16.0;

TextStyle _ts(
  double size,
  FontWeight weight,
  Color color, {
  double? spacing,
  double? height,
}) =>
    ProductUi.t(size, weight, color, spacing: spacing, height: height);

enum _StockFilter { all, inStock, warning, outOfStock }

enum _SortMode { none, name, stock, price }

/// Một dòng = một biến thể (SKU), đúng như mockup.
class _SkuRow {
  final ProductItem product;
  final ProductVariant variant;

  const _SkuRow(this.product, this.variant);

  int get stock => variant.totalOnHand;
  double get price => variant.basePrice;
  String get sku => variant.sku.isNotEmpty ? variant.sku : product.code;
  bool get isOut => stock <= 0;

  bool matches(String plainQuery) {
    if (plainQuery.isEmpty) return true;
    if (normalizeForSearch(product.name).contains(plainQuery)) return true;
    if (normalizeForSearch(sku).contains(plainQuery)) return true;
    if (normalizeForSearch(product.code).contains(plainQuery)) return true;
    final barcode = variant.barcode;
    return barcode != null && barcode.contains(plainQuery);
  }
}

/// Tab "Sản phẩm" — clone 1:1 màn "Danh Sách Hàng Hóa" trong abc-app/sku.png.
class ProductCatalogTab extends StatefulWidget {
  /// Chỉ dùng cho test/preview: nạp sẵn dữ liệu, bỏ qua gọi mạng.
  final List<ProductItem>? initialProducts;

  const ProductCatalogTab({super.key, this.initialProducts});

  @override
  State<ProductCatalogTab> createState() => _ProductCatalogTabState();
}

class _ProductCatalogTabState extends State<ProductCatalogTab> {
  late final ProductsService _productsService = ProductsService();
  final _searchController = TextEditingController();
  final _currency = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

  Timer? _debounce;
  List<ProductItem> _products = [];
  List<_SkuRow> _rows = [];
  bool _isLoading = true;
  String? _error;

  String _plainQuery = '';
  _StockFilter _filter = _StockFilter.all;
  _SortMode _sort = _SortMode.none;
  String? _categoryFilter;

  @override
  void initState() {
    super.initState();
    final seed = widget.initialProducts;
    if (seed != null) {
      _products = seed;
      _rows = _flatten(seed);
      _isLoading = false;
    } else {
      _load();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final products = await _productsService.getProducts(keyword: null);
      if (!mounted) return;
      setState(() {
        _products = products;
        _rows = _flatten(products);
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Không tải được danh sách hàng hóa. Kiểm tra kết nối máy chủ.';
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

  List<_SkuRow> _flatten(List<ProductItem> products) {
    final rows = <_SkuRow>[];
    for (final p in products) {
      if (p.variants.isEmpty) {
        rows.add(
          _SkuRow(
            p,
            ProductVariant(
              id: '',
              sku: p.code,
              title: 'Mặc định',
              basePrice: p.avgPrice,
              costPrice: 0,
              totalOnHand: p.totalStock,
            ),
          ),
        );
        continue;
      }
      for (final v in p.variants) {
        rows.add(_SkuRow(p, v));
      }
    }
    return rows;
  }

  List<_SkuRow> get _searchedRows {
    return _rows.where((row) {
      if (!row.matches(_plainQuery)) return false;
      if (_categoryFilter != null && row.product.categoryName != _categoryFilter) return false;
      return true;
    }).toList();
  }

  List<_SkuRow> get _visibleRows {
    final searched = _searchedRows;
    final filtered = switch (_filter) {
      _StockFilter.all => searched,
      _StockFilter.inStock => searched.where((r) => r.stock > 0).toList(),
      _StockFilter.warning => searched.where((r) => r.stock > 0 && r.stock <= 5).toList(),
      _StockFilter.outOfStock => searched.where((r) => r.stock <= 0).toList(),
    };
    if (_sort == _SortMode.stock) {
      filtered.sort((a, b) => b.stock.compareTo(a.stock));
    } else if (_sort == _SortMode.price) {
      filtered.sort((a, b) => b.price.compareTo(a.price));
    } else if (_sort == _SortMode.name) {
      filtered.sort((a, b) => a.product.name.toLowerCase().compareTo(b.product.name.toLowerCase()));
    }
    return filtered;
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      setState(() {
        _plainQuery = normalizeForSearch(value);
      });
    });
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchController.clear();
    setState(() {
      _plainQuery = '';
    });
  }

  Future<void> _openCreate() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AddProductScreen()),
    );
    if (created == true && mounted) _load();
  }

  Future<void> _openFilter() async {
    final categories = <String>{};
    for (final p in _products) {
      final name = p.categoryName;
      if (name != null && name.trim().isNotEmpty) categories.add(name);
    }
    final sorted = categories.toList()..sort();

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: _cCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Lọc theo danh mục', style: _ts(16, FontWeight.w700, _cInk)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _filterPill(
                    label: 'Tất cả danh mục',
                    active: _categoryFilter == null,
                    onTap: () {
                      setState(() => _categoryFilter = null);
                      Navigator.pop(ctx);
                    },
                  ),
                  for (final name in sorted)
                    _filterPill(
                      label: name,
                      active: _categoryFilter == name,
                      onTap: () {
                        setState(() => _categoryFilter = name);
                        Navigator.pop(ctx);
                      },
                    ),
                ],
              ),
              const Divider(height: 22, color: _cLine),
              InkWell(
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ManageCatalogScreen()),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.category_outlined, size: 16, color: _cPrimary),
                      const SizedBox(width: 8),
                      Text(
                        'Quản lý danh mục & thuộc tính',
                        style: _ts(12, FontWeight.w700, _cInk),
                      ),
                      const Spacer(),
                      const Icon(Icons.chevron_right_rounded, size: 18, color: _cSub),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _openSort() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _cCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            for (final option in _SortMode.values)
              ListTile(
                leading: Icon(
                  _sort == option ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: _cPrimary,
                  size: 20,
                ),
                title: Text(_sortLabel(option), style: _ts(14, FontWeight.w600, _cInk)),
                onTap: () {
                  setState(() => _sort = option);
                  Navigator.pop(ctx);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String _sortLabel(_SortMode mode) {
    switch (mode) {
      case _SortMode.none:
        return 'Mặc định';
      case _SortMode.name:
        return 'Tên A → Z';
      case _SortMode.stock:
        return 'Tồn kho giảm dần';
      case _SortMode.price:
        return 'Giá giảm dần';
    }
  }

  @override
  Widget build(BuildContext context) {
    final searched = _searchedRows;
    final visible = _visibleRows;
    final counts = {
      _StockFilter.all: searched.length,
      _StockFilter.inStock: searched.where((r) => r.stock > 0).length,
      _StockFilter.warning: searched.where((r) => r.stock > 0 && r.stock <= 5).length,
      _StockFilter.outOfStock: searched.where((r) => r.stock <= 0).length,
    };

    return Scaffold(
      backgroundColor: _cBg,
      floatingActionButton: FloatingActionButton(
        backgroundColor: _cButton,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: const CircleBorder(),
        onPressed: _openCreate,
        child: const Icon(Icons.add_rounded, size: 28),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchRow(),
            _buildFilterChips(counts),
            Padding(
              padding: const EdgeInsets.fromLTRB(_kSide + 1, 19, _kSide + 1, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Hiển thị ${visible.length} / ${_rows.length} biến thể',
                  style: _ts(12, FontWeight.w700, _cSub),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Expanded(child: _buildList(visible, searched)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(17, 12, 12, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Danh Sách Hàng Hóa',
                  style: _ts(22.5, FontWeight.w700, _cInk, height: 1.12),
                ),
                const SizedBox(height: 4),
                Text(
                  'Quản lý và tra cứu tất cả sản phẩm trong cửa hàng',
                  style: _ts(12, FontWeight.w600, _cSub, height: 1.3),
                ),
              ],
            ),
          ),
          Column(
            children: [
              InkWell(
                onTap: _openFilter,
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Icon(Icons.tune_rounded, size: 19, color: _cSub),
                ),
              ),
              Text('Bộ lọc', style: _ts(9, FontWeight.w600, _cSub)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(_kSide + 1, 54, _kSide + 1, 0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 43,
              padding: const EdgeInsets.symmetric(horizontal: 13),
              decoration: BoxDecoration(
                color: _cCard,
                borderRadius: BorderRadius.circular(21.5),
                border: Border.all(color: _cLine),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, size: 18, color: _cSub),
                  const SizedBox(width: 9),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: _ts(13, FontWeight.w500, _cInk),
                      cursorColor: _cPrimary,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        hintText: 'Tìm kiếm sản phẩm, mã SKU, barcode...',
                        hintStyle: _ts(13.1, FontWeight.w500, _cInk),
                      ),
                      onChanged: (value) {
                        setState(() {});
                        _onSearchChanged(value);
                      },
                    ),
                  ),
                  if (_searchController.text.isNotEmpty)
                    GestureDetector(
                      onTap: _clearSearch,
                      child: const Icon(Icons.close_rounded, size: 15, color: _cSub),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 11),
          InkWell(
            onTap: _openSort,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 43,
              width: 43,
              decoration: BoxDecoration(
                color: _cCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _cLine),
              ),
              child: const Icon(Icons.swap_vert_rounded, size: 19, color: _cSub),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(Map<_StockFilter, int> counts) {
    const chips = <_StockFilter>[
      _StockFilter.all,
      _StockFilter.inStock,
      _StockFilter.warning,
      _StockFilter.outOfStock,
    ];

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: SizedBox(
        height: 30,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: _kSide + 1),
          itemCount: chips.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final filter = chips[i];
            final active = _filter == filter;
            final label = switch (filter) {
              _StockFilter.all => 'Tất cả',
              _StockFilter.inStock => 'Còn hàng',
              _StockFilter.warning => 'Cảnh báo tồn',
              _StockFilter.outOfStock => 'Hết hàng',
            };
            final idleColor = switch (filter) {
              _StockFilter.warning => _cWarn,
              _StockFilter.outOfStock => _cDanger,
              _ => _cSub,
            };
            return GestureDetector(
              onTap: () => setState(() => _filter = filter),
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 13),
                decoration: BoxDecoration(
                  color: active ? _cPrimary : _cCard,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: active ? _cPrimary : _cLine),
                ),
                child: Text(
                  '$label (${counts[filter] ?? 0})',
                  style: _ts(12, FontWeight.w700, active ? Colors.white : idleColor),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildList(List<_SkuRow> visible, List<_SkuRow> searched) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: _cPrimary));
    }
    if (_error != null) {
      return _buildMessage(
        icon: Icons.cloud_off_rounded,
        title: 'Không tải được hàng hóa',
        detail: _error!,
        actionLabel: 'Thử lại',
        onAction: _load,
      );
    }
    if (visible.isEmpty) {
      return _buildMessage(
        icon: Icons.inventory_2_outlined,
        title: searched.isEmpty ? 'Không tìm thấy hàng hóa' : 'Không có dòng nào khớp bộ lọc',
        detail: 'Thử từ khoá khác hoặc chọn "Tất cả".',
        actionLabel: 'Xoá bộ lọc',
        onAction: () {
          _clearSearch();
          setState(() {
            _filter = _StockFilter.all;
            _categoryFilter = null;
          });
        },
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(_kSide + 1, 0, _kSide + 1, 100),
      itemCount: visible.length,
      itemBuilder: (context, i) => _buildCard(visible[i]),
    );
  }

  Widget _buildCard(_SkuRow row) {
    final product = row.product;
    final isOut = row.isOut;
    final unit = product.unitOfMeasure;

    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Material(
        color: _cCard,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          // Không mở màn hình khi chạm vào thẻ sản phẩm (theo yêu cầu).
          onTap: null,
          child: Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _cCardBorder),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildThumb(primaryImageUrl(product.imageUrl), isOut),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              product.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: _ts(13.8, FontWeight.w700, _cInk, height: 1.18),
                            ),
                          ),
                          if (isOut) ...[
                            const SizedBox(width: 5),
                            _buildOutPill('Tồn: 0 $unit'),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'SKU: ${row.sku}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _ts(12.8, FontWeight.w500, isOut ? _cPrimary : _cSub),
                      ),
                      const SizedBox(height: 9),
                      Container(height: 1, color: _cLine),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (isOut)
                            Text(
                              _currency.format(row.price),
                              style: _ts(13.7, FontWeight.w700, _cPrimary),
                            )
                          else ...[
                            Text('Tồn: ', style: _ts(11.5, FontWeight.w500, _cSub)),
                            Text(
                              '${row.stock} $unit',
                              style: _ts(12.5, FontWeight.w800, _cGreen),
                            ),
                          ],
                          const Spacer(),
                          if (isOut)
                            _buildOrderButton(row)
                          else
                            Text(
                              _currency.format(row.price),
                              style: _ts(13.7, FontWeight.w700, _cPrimary),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThumb(String? imageUrl, bool isOut) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 84,
        height: 84,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (isOut && (imageUrl == null || imageUrl.isEmpty))
              Container(
                color: _cOutTile,
                child: const Icon(Icons.inventory_2_outlined, size: 26, color: Colors.white70),
              )
            else
              Container(
                color: _cTile,
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.image_outlined,
                          size: 24,
                          color: Color(0xFFB9AEA4),
                        ),
                      )
                    : const Icon(Icons.image_outlined, size: 24, color: Color(0xFFB9AEA4)),
              ),
            if (isOut)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 7),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: _cDanger,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'HẾT\nHÀNG',
                      textAlign: TextAlign.center,
                      style: _ts(9, FontWeight.w800, Colors.white, spacing: 0.4, height: 1.15),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOutPill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: BoxDecoration(
        color: _cOutPillBg,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, size: 9, color: _cDanger),
          const SizedBox(width: 3),
          Text(text, style: _ts(9.5, FontWeight.w700, _cDanger)),
        ],
      ),
    );
  }

  Future<void> _openPurchaseOrder(_SkuRow row) async {
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
          initialVariantId: row.variant.id,
          initialSku: row.sku,
          initialProductName: row.product.name,
        ),
      ),
    );
  }

  Widget _buildOrderButton(_SkuRow row) {
    return GestureDetector(
      onTap: () => _openPurchaseOrder(row),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: _cButton,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shopping_cart_outlined, size: 11, color: Colors.white),
            const SizedBox(width: 4),
            Text('Đặt NCC', style: _ts(10.5, FontWeight.w800, Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _filterPill({required String label, required bool active, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? _cPrimary : _cCard,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: active ? _cPrimary : _cLine),
        ),
        child: Text(
          label,
          style: _ts(11.5, FontWeight.w600, active ? Colors.white : _cSub),
        ),
      ),
    );
  }

  Widget _buildMessage({
    required IconData icon,
    required String title,
    required String detail,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 38, color: const Color(0xFFB9AEA4)),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: _ts(15, FontWeight.w700, _cInk),
            ),
            const SizedBox(height: 6),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: _ts(12, FontWeight.w500, _cSub, height: 1.35),
            ),
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: onAction,
              style: OutlinedButton.styleFrom(
                foregroundColor: _cPrimary,
                side: const BorderSide(color: _cPrimary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(actionLabel, style: _ts(12.5, FontWeight.w700, _cPrimary)),
            ),
          ],
        ),
      ),
    );
  }
}
