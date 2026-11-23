class ProductVariant {
  final String id;
  final String sku;
  final String? barcode;
  final String title;
  final double basePrice;
  final double costPrice;
  final int totalOnHand;

  ProductVariant({
    required this.id,
    required this.sku,
    this.barcode,
    required this.title,
    required this.basePrice,
    required this.costPrice,
    required this.totalOnHand,
  });

  factory ProductVariant.fromJson(Map<String, dynamic> json) {
    int onHand = 0;
    if (json['stockQty'] != null) {
      onHand = (json['stockQty'] as num).toInt();
    } else if (json['inventoryBalances'] != null && json['inventoryBalances'] is List) {
      for (var b in json['inventoryBalances']) {
        onHand += (b['quantityOnHand'] as num? ?? 0).toInt();
      }
    }

    return ProductVariant(
      id: json['id'] ?? '',
      sku: json['sku'] ?? '',
      barcode: json['barcode'],
      title: json['title'] ?? json['sku'] ?? 'Mặc định',
      basePrice: (json['basePrice'] as num? ?? 0).toDouble(),
      costPrice: (json['costPrice'] as num? ?? 0).toDouble(),
      totalOnHand: onHand,
    );
  }
}

class ProductItem {
  final String id;
  final String code;
  final String name;
  final String? categoryPath;
  final String? categoryName;
  final int totalStock;
  final double retailValue;
  final double avgPrice;
  final List<ProductVariant> variants;
  /// True when the product tracks lots (cosmetics). Clothes have no lot and no expiry.
  final bool hasLotTracking;

  ProductItem({
    required this.id,
    required this.code,
    required this.name,
    this.categoryPath,
    this.categoryName,
    required this.totalStock,
    required this.retailValue,
    required this.avgPrice,
    required this.variants,
    this.hasLotTracking = false,
  });

  factory ProductItem.fromJson(Map<String, dynamic> json) {
    final rawSkus = (json['skus'] ?? json['variants']) as List? ?? [];
    final variantsList = rawSkus
        .map((v) => ProductVariant.fromJson(v as Map<String, dynamic>))
        .toList();

    return ProductItem(
      id: json['id'] ?? '',
      code: json['code'] ?? '',
      name: json['name'] ?? '',
      categoryPath: json['categoryPath'],
      categoryName: json['categoryName'],
      totalStock: (json['stockQty'] as num? ?? 0).toInt(),
      retailValue: (json['retailValue'] as num? ?? 0).toDouble(),
      avgPrice: (json['avgPrice'] as num? ?? 0).toDouble(),
      variants: variantsList,
      hasLotTracking: json['hasLotTracking'] == true,
    );
  }
}
