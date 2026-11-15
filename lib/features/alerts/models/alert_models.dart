class LotAlertItem {
  final String lotCode;
  final String productName;
  final String variantTitle;
  final String expirationDate;
  final int daysLeft;
  final String status;
  final int currentQuantity;

  LotAlertItem({
    required this.lotCode,
    required this.productName,
    required this.variantTitle,
    required this.expirationDate,
    required this.daysLeft,
    required this.status,
    required this.currentQuantity,
  });

  factory LotAlertItem.fromJson(Map<String, dynamic> json) {
    return LotAlertItem(
      lotCode: json['lotCode'] ?? json['lot_code'] ?? 'Lô không tên',
      productName: json['productName'] ?? json['product_name'] ?? '',
      variantTitle: json['variantTitle'] ?? json['variant_title'] ?? '',
      expirationDate: json['expirationDate'] ?? json['expiration_date'] ?? '',
      daysLeft: (json['daysLeft'] ?? json['days_left'] ?? 0).toInt(),
      status: json['status'] ?? 'NORMAL',
      currentQuantity: (json['currentQuantity'] ?? json['current_quantity'] ?? 0).toInt(),
    );
  }
}

class LowStockAlertItem {
  final String productId;
  final String productName;
  final String sku;
  final String variantTitle;
  final int currentStock;
  final int minStockThreshold;

  LowStockAlertItem({
    required this.productId,
    required this.productName,
    required this.sku,
    required this.variantTitle,
    required this.currentStock,
    this.minStockThreshold = 10, // Ngưỡng an toàn mặc định
  });
}
