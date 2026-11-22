class PosOrderSummary {
  final String id;
  final String code;
  final String status;
  final double totalAmount;
  final double finalAmount;
  final double paidAmount;
  final String createdAt;
  final int itemCount;

  PosOrderSummary({
    required this.id,
    required this.code,
    required this.status,
    required this.totalAmount,
    required this.finalAmount,
    required this.paidAmount,
    required this.createdAt,
    required this.itemCount,
  });

  factory PosOrderSummary.fromJson(Map<String, dynamic> json) {
    final items = json['items'] as List? ?? [];
    return PosOrderSummary(
      id: json['id'] ?? '',
      code: json['code'] ?? '',
      status: json['status'] ?? 'DRAFT',
      totalAmount: (json['totalAmount'] as num? ?? 0).toDouble(),
      finalAmount: (json['finalAmount'] as num? ?? 0).toDouble(),
      paidAmount: (json['paidAmount'] as num? ?? 0).toDouble(),
      createdAt: json['createdAt']?.toString() ?? '',
      itemCount: items.length,
    );
  }
}

class CartItem {
  final String variantId;
  final String sku;
  final String title;
  final String productName;
  final double price;
  int quantity;

  CartItem({
    required this.variantId,
    required this.sku,
    required this.title,
    required this.productName,
    required this.price,
    this.quantity = 1,
  });

  double get subtotal => price * quantity;
}
