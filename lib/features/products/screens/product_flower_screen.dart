import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:abc_app/features/products/models/product_model.dart';
import 'package:abc_app/features/products/widgets/product_flower_widget.dart';
import 'package:abc_app/features/products/screens/edit_product_screen.dart';
import 'package:abc_app/features/products/screens/barcode_label_screen.dart';

class ProductFlowerScreen extends StatefulWidget {
  final ProductItem product;
  final List<ProductItem> allProducts;

  const ProductFlowerScreen({
    super.key,
    required this.product,
    this.allProducts = const [],
  });

  @override
  State<ProductFlowerScreen> createState() => _ProductFlowerScreenState();
}

class _ProductFlowerScreenState extends State<ProductFlowerScreen> {
  late ProductItem _currentProduct;
  final _currency = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

  @override
  void initState() {
    super.initState();
    _currentProduct = widget.product;
  }

  void _onPetalTapped(int petalIndex) {
    String title = '';
    Widget content = const SizedBox();

    switch (petalIndex) {
      case 1:
        title = 'Cánh 1: SKU Biến thể';
        content = _buildVariantsSheet();
        break;
      case 2:
        title = 'Cánh 2: Chi tiết Tồn kho';
        content = _buildInventorySheet();
        break;
      case 3:
        title = 'Cánh 3: Khung Giá bán & Giá vốn';
        content = _buildPriceSheet();
        break;
      case 4:
        title = 'Cánh 4: Thuộc tính Màu sắc / Dung tích';
        content = _buildAttributeSheet(isColor: true);
        break;
      case 5:
        title = 'Cánh 5: Kích thước (Size) / Hạn sử dụng';
        content = _buildAttributeSheet(isColor: false);
        break;
      case 6:
        title = 'Cánh 6: Trạng thái & Sức khỏe tồn kho';
        content = _buildStatusSheet();
        break;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.local_florist_rounded, size: 20, color: Color(0xFF065F46)),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'serif',
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            content,
          ],
        ),
      ),
    );
  }

  Widget _buildVariantsSheet() {
    if (_currentProduct.variants.isEmpty) {
      return const Text('Sản phẩm này chưa cấu hình biến thể riêng biệt.');
    }
    return Column(
      children: _currentProduct.variants.map((v) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(v.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  Text('SKU: ${v.sku}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${v.totalOnHand} tồn kho', style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF065F46))),
                  Text(_currency.format(v.basePrice), style: const TextStyle(fontSize: 11.5, color: Color(0xFF334155))),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildInventorySheet() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDFA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFCCFBF1)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Tổng số lượng tồn kho cha:'),
              Text(
                '${_currentProduct.totalStock} sản phẩm',
                style: const TextStyle(fontFamily: 'serif', fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F4C3A)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Text('Phân bổ theo các biến thể:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
        const SizedBox(height: 6),
        ..._currentProduct.variants.take(5).map((v) {
          final isZero = v.totalOnHand <= 0;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(Icons.circle, size: 7, color: isZero ? const Color(0xFFDC2626) : const Color(0xFF16A34A)),
                const SizedBox(width: 8),
                Expanded(child: Text('${v.sku} (${v.title})', style: const TextStyle(fontSize: 12))),
                Text(
                  '${v.totalOnHand} cái',
                  style: TextStyle(fontWeight: FontWeight.w800, color: isZero ? const Color(0xFFDC2626) : const Color(0xFF0F172A)),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildPriceSheet() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Giá bán trung bình (Avg):'),
              Text(
                _currency.format(_currentProduct.avgPrice),
                style: const TextStyle(fontFamily: 'serif', fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF065F46)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        ..._currentProduct.variants.take(4).map((v) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(v.title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                Text(_currency.format(v.basePrice), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF065F46))),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildAttributeSheet({required bool isColor}) {
    return Text(
      isColor
          ? 'Thuộc tính màu sắc hoặc dung tích được tự động gom nhóm từ tên và SKU biến thể của mẫu cha này.'
          : 'Kích cỡ (Size) hoặc hạn sử dụng (Lot Expiry) phục vụ theo dõi chính xác thời hạn xuất nhập kho.',
      style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569)),
    );
  }

  Widget _buildStatusSheet() {
    final outCount = _currentProduct.variants.where((v) => v.totalOnHand <= 0).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Icon(Icons.check_circle, size: 16, color: Color(0xFF16A34A)),
            SizedBox(width: 6),
            Text('Mẫu cha đang ở trạng thái KINH DOANH', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF16A34A))),
          ],
        ),
        const SizedBox(height: 8),
        if (outCount > 0)
          Text(
            'Cảnh báo: Hiện có $outCount biến thể đã chạm mốc 0 tồn kho. Cần tạo PO nhập thêm hàng.',
            style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626)),
          )
        else
          Text(
            'Tất cả các biến thể đều có hàng trong kho và sẵn sàng bán tại quầy POS & Online.',
            style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            const Icon(Icons.local_florist_rounded, size: 20, color: Color(0xFF065F46)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Mẫu cha: ${_currentProduct.name}',
                style: const TextStyle(
                  fontFamily: 'serif',
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20, color: Color(0xFF0F172A)),
            tooltip: 'Sửa mẫu cha',
            onPressed: () async {
              final nav = Navigator.of(context);
              final updated = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => EditProductScreen(product: _currentProduct)),
              );
              if (updated == true && mounted) {
                nav.pop(true);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_2_rounded, size: 21, color: Color(0xFF0F172A)),
            tooltip: 'In tem mã vạch',
            onPressed: () {
              final defaultVariant = _currentProduct.variants.isNotEmpty
                  ? _currentProduct.variants.first
                  : ProductVariant(
                      id: '',
                      sku: _currentProduct.code,
                      title: 'Mặc định',
                      basePrice: _currentProduct.avgPrice,
                      costPrice: 0,
                      totalOnHand: _currentProduct.totalStock,
                    );
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BarcodeLabelScreen(
                    product: _currentProduct,
                    variant: defaultVariant,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Thanh chọn nhanh các sản phẩm khác nếu có
              if (widget.allProducts.length > 1) ...[
                SizedBox(
                  height: 34,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: widget.allProducts.length,
                    separatorBuilder: (context, index) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final p = widget.allProducts[index];
                      final isSelected = p.id == _currentProduct.id;
                      return GestureDetector(
                        onTap: () => setState(() => _currentProduct = p),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF065F46) : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isSelected ? const Color(0xFF065F46) : const Color(0xFFE2E8F0)),
                            boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 4)],
                          ),
                          child: Text(
                            p.name,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                              color: isSelected ? Colors.white : const Color(0xFF475569),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Card hiển thị UI Bông hoa 6 cánh 1:1
              Container(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE8EEF5), width: 1.2),
                  boxShadow: const [
                    BoxShadow(color: Color(0x0A0F172A), blurRadius: 16, offset: Offset(0, 4)),
                  ],
                ),
                child: Column(
                  children: [
                    ProductFlowerWidget(
                      product: _currentProduct,
                      onCenterTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => EditProductScreen(product: _currentProduct)),
                        );
                      },
                      onPetalTap: _onPetalTapped,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.touch_app_outlined, size: 14, color: Color(0xFF94A3B8)),
                        SizedBox(width: 5),
                        Text(
                          'Chạm vào nhụy hoặc từng cánh hoa để xem chi tiết',
                          style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Bảng tóm tắt nhanh thông tin mẫu cha
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE8EEF5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Thông tin chi tiết mẫu cha (Template)',
                      style: TextStyle(
                        fontFamily: 'serif',
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildInfoRow('Mã sản phẩm cha (SKU)', _currentProduct.code),
                    _buildInfoRow('Danh mục', _currentProduct.categoryName ?? 'Chưa phân nhóm'),
                    _buildInfoRow('Số lượng biến thể SKU', '${_currentProduct.variants.length} biến thể'),
                    _buildInfoRow('Tổng tồn kho sẵn có', '${_currentProduct.totalStock} cái'),
                    _buildInfoRow('Giá trị bán lẻ ước tính', _currency.format(_currentProduct.retailValue)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          Text(value, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
        ],
      ),
    );
  }
}
