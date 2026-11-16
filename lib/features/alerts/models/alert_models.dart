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
