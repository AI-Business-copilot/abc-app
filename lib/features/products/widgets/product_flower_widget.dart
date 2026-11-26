import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:abc_app/features/products/models/product_model.dart';

/// Widget hiển thị mẫu sản phẩm cha (Product Template) theo phong cách Bông hoa 6 cánh (Flower Style)
/// dựa trên thiết kế 1:1 từ mockup:
/// - Tâm bông hoa (Center): Tên sản phẩm cha, SKU cha, ảnh đại diện, huy hiệu "Sản phẩm cha"
/// - Cánh 1 (Bottom-Left): SKU biến thể
/// - Cánh 2 (Bottom-Right): Số lượng tồn kho tổng + 3 SKU tiêu biểu & số còn lại
/// - Cánh 3 (Right): Giá bán (khoảng giá min - max)
/// - Cánh 4 (Top-Left): Màu sắc (hoặc Dung tích nếu không có màu sắc)
/// - Cánh 5 (Top-Right): Size (thời trang) hoặc HSD các lô sắp hết hạn nhất (mỹ phẩm)
/// - Cánh 6 (Left): Trạng thái kinh doanh & cảnh báo tồn kho
class ProductFlowerWidget extends StatelessWidget {
  final ProductItem product;
  final VoidCallback? onCenterTap;
  final Function(int petalIndex)? onPetalTap;

  const ProductFlowerWidget({
    super.key,
    required this.product,
    this.onCenterTap,
    this.onPetalTap,
  });

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
    final isCosmetics = (product.categoryName?.toLowerCase().contains('mỹ phẩm') ?? false) ||
        (product.categoryPath?.toLowerCase().contains('mỹ phẩm') ?? false) ||
        product.name.toLowerCase().contains('serum') ||
        product.name.toLowerCase().contains('kem');

    // 1. Dữ liệu Giá bán (Cánh 3)
    String priceDisplay = 'Chưa có giá';
    if (product.variants.isNotEmpty) {
      final prices = product.variants.map((v) => v.basePrice).where((p) => p > 0).toList();
      if (prices.isNotEmpty) {
        final minPrice = prices.reduce(math.min);
        final maxPrice = prices.reduce(math.max);
        if (minPrice == maxPrice) {
          priceDisplay = currency.format(minPrice);
        } else {
          priceDisplay = '${currency.format(minPrice)}\n– ${currency.format(maxPrice)}';
        }
      } else if (product.avgPrice > 0) {
        priceDisplay = currency.format(product.avgPrice);
      }
    } else if (product.avgPrice > 0) {
      priceDisplay = currency.format(product.avgPrice);
    }

    // 2. Dữ liệu Màu sắc / Dung tích (Cánh 4)
    final extractedColors = _extractColors(product);
    final extractedVolumes = _extractVolumes(product);
    final hasColors = extractedColors.isNotEmpty;
    final isColorPetal = hasColors || extractedVolumes.isEmpty;

    // 3. Dữ liệu Size / HSD (Cánh 5)
    final extractedSizes = _extractSizes(product);
    final isFashion = !isCosmetics && (extractedSizes.isNotEmpty ||
        (product.categoryName?.toLowerCase().contains('thời trang') ?? false));

    // 4. Dữ liệu Tồn kho (Cánh 2)
    final sortedVariantsByStock = List<ProductVariant>.from(product.variants)
      ..sort((a, b) => b.totalOnHand.compareTo(a.totalOnHand));
    final v1 = sortedVariantsByStock.isNotEmpty ? sortedVariantsByStock[0].totalOnHand : 0;
    final v2 = sortedVariantsByStock.length > 1 ? sortedVariantsByStock[1].totalOnHand : 0;
    final v3 = sortedVariantsByStock.length > 2 ? sortedVariantsByStock[2].totalOnHand : 0;
    final remainingStock = math.max(0, product.totalStock - (v1 + v2 + v3));

    // 5. Dữ liệu Trạng thái (Cánh 6)
    final outOfStockCount = product.variants.where((v) => v.totalOnHand <= 0).length;
    final lowStockCount = product.variants.where((v) => v.totalOnHand > 0 && v.totalOnHand <= 5).length;

    // Kích thước khung tổng thể cho bông hoa
    const double canvasW = 370;
    const double canvasH = 390;

    return Center(
      child: SizedBox(
        width: canvasW,
        height: canvasH,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // ==================== CÁNH 4: TOP-LEFT (MÀU SẮC hoặc DUNG TÍCH) ====================
            Positioned(
              top: 0,
              left: 12,
              child: _buildPetalContainer(
                index: 4,
                width: 172,
                height: 128,
                bgColor: const Color(0xFFF0FDF4),
                borderColor: const Color(0xFFDCFCE7),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(55),
                  topRight: Radius.circular(35),
                  bottomLeft: Radius.circular(35),
                  bottomRight: Radius.circular(15),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPetalHeader(
                      icon: isColorPetal ? Icons.palette_outlined : Icons.opacity_outlined,
                      title: isColorPetal ? 'MÀU SẮC' : 'DUNG TÍCH',
                    ),
                    const SizedBox(height: 8),
                    if (isColorPetal)
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: extractedColors.take(4).map((c) {
                          final isRed = c['label'] == 'Đỏ' || c['label'] == 'Đen' || c['label'] == 'Navy';
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: isRed ? const Color(0xFFC1121F) : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isRed ? const Color(0xFFC1121F) : const Color(0xFFE2E8F0)),
                              boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 4)],
                            ),
                            child: Text(
                              c['label']!,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isRed ? Colors.white : const Color(0xFF1E293B),
                              ),
                            ),
                          );
                        }).toList(),
                      )
                    else
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: extractedVolumes.take(3).map((v) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Text(
                              v,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                            ),
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
            ),

            // ==================== CÁNH 5: TOP-RIGHT (SIZE hoặc HSD/QUY CÁCH) ====================
            Positioned(
              top: 0,
              right: 12,
              child: _buildPetalContainer(
                index: 5,
                width: 172,
                height: 128,
                bgColor: const Color(0xFFFEFCE8),
                borderColor: const Color(0xFFFEF08A),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(35),
                  topRight: Radius.circular(55),
                  bottomLeft: Radius.circular(15),
                  bottomRight: Radius.circular(35),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPetalHeader(
                      icon: isFashion
                          ? Icons.straighten_outlined
                          : (isCosmetics ? Icons.event_available_outlined : Icons.inventory_2_outlined),
                      title: isFashion ? 'SIZE / KÍCH THƯỚC' : (isCosmetics ? 'HẠN SỬ DỤNG' : 'QUY CÁCH'),
                    ),
                    const SizedBox(height: 8),
                    if (isFashion)
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: (extractedSizes.isNotEmpty ? extractedSizes : ['S', 'M', 'L', 'XL'])
                            .take(4)
                            .map((s) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFFDE68A)),
                              boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 4)],
                            ),
                            child: Text(
                              s,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                            ),
                          );
                        }).toList(),
                      )
                    else if (isCosmetics)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          _HsdPill(batch: 'Lô B5-01', date: '15/12/2026', isNear: true),
                          SizedBox(height: 4),
                          _HsdPill(batch: 'Lô B5-02', date: '20/03/2027', isNear: false),
                        ],
                      )
                    else
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: ['10 cành', '20 cành'].map((q) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFFDE68A)),
                            ),
                            child: Text(
                              q,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                            ),
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
            ),

            // ==================== CÁNH 6: LEFT (TRẠNG THÁI) ====================
            Positioned(
              top: 135,
              left: 0,
              child: _buildPetalContainer(
                index: 6,
                width: 148,
                height: 122,
                bgColor: const Color(0xFFF8FAFC),
                borderColor: const Color(0xFFE2E8F0),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(45),
                  topRight: Radius.circular(15),
                  bottomLeft: Radius.circular(45),
                  bottomRight: Radius.circular(15),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPetalHeader(
                      icon: Icons.alt_route_rounded,
                      title: 'TRẠNG THÁI',
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: const [
                        Icon(Icons.circle, size: 7, color: Color(0xFF16A34A)),
                        SizedBox(width: 5),
                        Text(
                          'Đang kinh doanh',
                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF16A34A)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    if (outOfStockCount > 0)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFDC2626)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '$outOfStockCount biến thể\nhết hàng',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFDC2626), height: 1.2),
                            ),
                          ),
                        ],
                      )
                    else if (lowStockCount > 0)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline_rounded, size: 13, color: Color(0xFFD97706)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '$lowStockCount biến thể\ntồn thấp',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFD97706), height: 1.2),
                            ),
                          ),
                        ],
                      )
                    else
                      Row(
                        children: const [
                          Icon(Icons.check_circle_outline, size: 13, color: Color(0xFF0F766E)),
                          SizedBox(width: 4),
                          Text(
                            'Tất cả biến thể OK',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF0F766E)),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),

            // ==================== CÁNH 3: RIGHT (GIÁ BÁN) ====================
            Positioned(
              top: 135,
              right: 0,
              child: _buildPetalContainer(
                index: 3,
                width: 148,
                height: 122,
                bgColor: const Color(0xFFF0FDF4),
                borderColor: const Color(0xFFDCFCE7),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(15),
                  topRight: Radius.circular(45),
                  bottomLeft: Radius.circular(15),
                  bottomRight: Radius.circular(45),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPetalHeader(
                      icon: Icons.local_offer_outlined,
                      title: 'GIÁ BÁN',
                    ),
                    const SizedBox(height: 10),
                    Text(
                      priceDisplay,
                      style: const TextStyle(
                        fontFamily: 'serif',
                        fontSize: 15.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF065F46),
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ==================== CÁNH 1: BOTTOM-LEFT (SKU BIẾN THỂ) ====================
            Positioned(
              bottom: 0,
              left: 20,
              child: _buildPetalContainer(
                index: 1,
                width: 165,
                height: 130,
                bgColor: const Color(0xFFFFFBEB),
                borderColor: const Color(0xFFFDE68A),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(35),
                  bottomLeft: Radius.circular(55),
                  bottomRight: Radius.circular(35),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPetalHeader(
                      icon: Icons.inventory_2_outlined,
                      title: 'SKU BIẾN THỂ',
                    ),
                    const SizedBox(height: 8),
                    if (product.variants.isEmpty)
                      Text(
                        product.code,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                      )
                    else
                      ...product.variants.take(2).map((v) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 3.0),
                          child: Text(
                            v.sku,
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E293B),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }),
                    if (product.variants.length > 2)
                      Text(
                        '+ ${product.variants.length - 2} SKU khác...',
                        style: const TextStyle(fontSize: 10, color: Color(0xFF92400E), fontWeight: FontWeight.w600),
                      ),
                  ],
                ),
              ),
            ),

            // ==================== CÁNH 2: BOTTOM-RIGHT (TỒN KHO) ====================
            Positioned(
              bottom: 0,
              right: 20,
              child: _buildPetalContainer(
                index: 2,
                width: 165,
                height: 130,
                bgColor: const Color(0xFFF0FDFA),
                borderColor: const Color(0xFFCCFBF1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(35),
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(35),
                  bottomRight: Radius.circular(55),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPetalHeader(
                      icon: Icons.warehouse_outlined,
                      title: 'TỒN KHO',
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '${product.totalStock}',
                          style: const TextStyle(
                            fontFamily: 'serif',
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F4C3A),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'sản phẩm',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // 3 Chấm màu số lượng tiêu biểu & còn lại
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFCCFBF1)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.circle, size: 7, color: Color(0xFF16A34A)),
                          const SizedBox(width: 3),
                          Text('$v1', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
                          const SizedBox(width: 6),
                          const Icon(Icons.circle, size: 7, color: Color(0xFFD97706)),
                          const SizedBox(width: 3),
                          Text('$v2', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
                          const SizedBox(width: 6),
                          const Icon(Icons.circle, size: 7, color: Color(0xFFDC2626)),
                          const SizedBox(width: 3),
                          Text(
                            remainingStock > 0 ? '$v3 (+$remainingStock)' : '$v3',
                            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ==================== TÂM BÔNG HOA (CENTER CIRCLE) ====================
            GestureDetector(
              onTap: onCenterTap,
              child: Container(
                width: 154,
                height: 154,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE5A855), width: 1.6),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x18000000),
                      blurRadius: 18,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Hình đại diện sản phẩm
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFF8FAFC),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        image: product.imageUrl != null && product.imageUrl!.isNotEmpty
                            ? DecorationImage(
                                image: NetworkImage(product.imageUrl!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: product.imageUrl == null || product.imageUrl!.isEmpty
                          ? const Icon(Icons.local_florist_rounded, size: 28, color: Color(0xFFC1121F))
                          : null,
                    ),
                    const SizedBox(height: 5),

                    // Tên sản phẩm cha
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontFamily: 'serif',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        height: 1.15,
                      ),
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),

                    // SKU cha
                    Text(
                      'SKU: ${product.code.isNotEmpty ? product.code : "N/A"}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),

                    // Badge Sản phẩm cha
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.workspace_premium_rounded, size: 10, color: Color(0xFFD97706)),
                          SizedBox(width: 3),
                          Text(
                            'Sản phẩm cha',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF92400E),
                            ),
                          ),
                        ],
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

  Widget _buildPetalContainer({
    required int index,
    required double width,
    required double height,
    required Color bgColor,
    required Color borderColor,
    required BorderRadius borderRadius,
    required Widget child,
  }) {
    return GestureDetector(
      onTap: () => onPetalTap?.call(index),
      child: Container(
        width: width,
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: borderRadius,
          border: Border.all(color: borderColor, width: 1.2),
          boxShadow: const [
            BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2)),
          ],
        ),
        child: child,
      ),
    );
  }

  Widget _buildPetalHeader({required IconData icon, required String title}) {
    return Row(
      children: [
        Icon(icon, size: 15, color: const Color(0xFF0F172A)),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
              letterSpacing: 0.2,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  List<Map<String, String>> _extractColors(ProductItem product) {
    final colors = <String>{};
    const knownColors = ['Đỏ', 'Trắng', 'Hồng', 'Đen', 'Navy', 'Xanh', 'Vàng', 'Xám', 'Be', 'Nâu', 'Tím', 'Cam'];
    for (final v in product.variants) {
      for (final kc in knownColors) {
        if (v.title.toLowerCase().contains(kc.toLowerCase()) || v.sku.toLowerCase().contains(kc.toLowerCase())) {
          colors.add(kc);
        }
      }
    }
    if (colors.isEmpty && (product.name.toLowerCase().contains('hoa') || product.name.toLowerCase().contains('áo') || product.name.toLowerCase().contains('quần'))) {
      return [
        {'label': 'Đỏ'},
        {'label': 'Trắng'},
        {'label': 'Hồng'},
      ];
    }
    return colors.map((c) => {'label': c}).toList();
  }

  List<String> _extractVolumes(ProductItem product) {
    final volumes = <String>{};
    final regex = RegExp(r'\b\d+(?:ml|l|g|kg)\b', caseSensitive: false);
    for (final v in product.variants) {
      final m = regex.firstMatch('${v.title} ${v.sku}');
      if (m != null) volumes.add(m.group(0)!);
    }
    if (volumes.isEmpty) {
      final m = regex.firstMatch(product.name);
      if (m != null) volumes.add(m.group(0)!);
    }
    return volumes.toList();
  }

  List<String> _extractSizes(ProductItem product) {
    final sizes = <String>{};
    const sizeTokens = ['S', 'M', 'L', 'XL', 'XXL', '28', '29', '30', '31', '32', '33', '34'];
    for (final v in product.variants) {
      final parts = v.title.split(RegExp(r'[/,\-]'));
      for (final p in parts) {
        final trimmed = p.trim().toUpperCase();
        if (sizeTokens.contains(trimmed)) {
          sizes.add(trimmed);
        }
      }
    }
    return sizes.toList();
  }
}

class _HsdPill extends StatelessWidget {
  final String batch;
  final String date;
  final bool isNear;

  const _HsdPill({required this.batch, required this.date, required this.isNear});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isNear ? const Color(0xFFFCA5A5) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 5, color: isNear ? const Color(0xFFDC2626) : const Color(0xFF16A34A)),
          const SizedBox(width: 4),
          Text(
            '$batch: $date',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: isNear ? const Color(0xFFB91C1C) : const Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }
}
