import 'package:intl/intl.dart';
import 'package:abc_app/core/utils/money_format.dart';

/// Dòng hàng trong hóa đơn (OrderItem từ GET /sales/orders).
/// Tiền trong API là chuỗi decimal, giữ nguyên dạng chuỗi để hiển thị.
class InvoiceItem {
  final String id;
  final String sku;
  final String productName;
  final String lotNumber;
  final double quantity;
  final String unitPrice;
  final String discountAmount;
  final String subtotal;

  InvoiceItem({
    required this.id,
    required this.sku,
    required this.productName,
    required this.lotNumber,
    required this.quantity,
    required this.unitPrice,
    required this.discountAmount,
    required this.subtotal,
  });

  factory InvoiceItem.fromJson(Map<String, dynamic> json) {
    final variant = json['variant'] is Map ? json['variant'] as Map<String, dynamic> : const {};
    final template = variant['template'] is Map ? variant['template'] as Map<String, dynamic> : const {};
    final lotItem = json['lotItem'] is Map ? json['lotItem'] as Map<String, dynamic> : const {};
    final lot = lotItem['lot'] is Map ? lotItem['lot'] as Map<String, dynamic> : const {};

    return InvoiceItem(
      id: json['id']?.toString() ?? '',
      sku: variant['sku']?.toString() ?? '',
      productName: template['name']?.toString() ?? 'Hàng hóa',
      lotNumber: lot['lotNumber']?.toString() ?? '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
      unitPrice: json['unitPrice']?.toString() ?? '0',
      discountAmount: json['discountAmount']?.toString() ?? '0',
      subtotal: json['subtotal']?.toString() ?? '0',
    );
  }
}

/// Phiếu thu trong hóa đơn (OrderPayment từ GET /sales/orders).
class InvoicePayment {
  final String id;
  final String method;
  final String amount;
  final String reference;
  final String createdAt;

  InvoicePayment({
    required this.id,
    required this.method,
    required this.amount,
    required this.reference,
    required this.createdAt,
  });

  factory InvoicePayment.fromJson(Map<String, dynamic> json) {
    return InvoicePayment(
      id: json['id']?.toString() ?? '',
      method: json['paymentMethod']?.toString() ?? 'CASH',
      amount: json['amount']?.toString() ?? '0',
      reference: json['paymentReference']?.toString() ?? '',
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }
}

/// Một hóa đơn = một đơn hàng bán lẻ.
class InvoiceOrder {
  final String id;
  final String code;
  final String status;
  final String createdAt;
  final String customerName;
  final String customerPhone;
  final String totalGrossAmount;
  final String discountAmount;
  final String totalNetAmount;
  final String grossProfit;
  final List<InvoiceItem> items;
  final List<InvoicePayment> payments;

  InvoiceOrder({
    required this.id,
    required this.code,
    required this.status,
    required this.createdAt,
    required this.customerName,
    required this.customerPhone,
    required this.totalGrossAmount,
    required this.discountAmount,
    required this.totalNetAmount,
    required this.grossProfit,
    required this.items,
    required this.payments,
  });

  int get itemCount => items.length;

  factory InvoiceOrder.fromJson(Map<String, dynamic> json) {
    final customer = json['customer'] is Map ? json['customer'] as Map<String, dynamic> : null;
    final rawItems = json['orderItems'] is List ? json['orderItems'] as List : const [];
    final rawPayments = json['orderPayments'] is List ? json['orderPayments'] as List : const [];

    return InvoiceOrder(
      id: json['id']?.toString() ?? '',
      code: json['orderCode']?.toString() ?? '',
      status: json['status']?.toString() ?? 'DRAFT',
      createdAt: json['createdAt']?.toString() ?? '',
      customerName: customer?['name']?.toString() ?? '',
      customerPhone: customer?['phone']?.toString() ?? '',
      totalGrossAmount: json['totalGrossAmount']?.toString() ?? '0',
      discountAmount: json['discountAmount']?.toString() ?? '0',
      totalNetAmount: json['totalNetAmount']?.toString() ?? '0',
      grossProfit: json['grossProfit']?.toString() ?? '0',
      items: rawItems
          .whereType<Map<String, dynamic>>()
          .map((e) => InvoiceItem.fromJson(e))
          .toList(),
      payments: rawPayments
          .whereType<Map<String, dynamic>>()
          .map((e) => InvoicePayment.fromJson(e))
          .toList(),
    );
  }
}

/// Trang kết quả danh sách hóa đơn.
class InvoicePage {
  final List<InvoiceOrder> items;
  final int page;
  final int pageSize;
  final int total;
  final int totalPages;

  InvoicePage({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
    required this.totalPages,
  });

  bool get hasMore => page < totalPages;

  factory InvoicePage.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] is List ? json['items'] as List : const [];
    final pagination = json['pagination'] is Map
        ? json['pagination'] as Map<String, dynamic>
        : const <String, dynamic>{};

    return InvoicePage(
      items: rawItems
          .whereType<Map<String, dynamic>>()
          .map((e) => InvoiceOrder.fromJson(e))
          .toList(),
      page: (pagination['page'] as num?)?.toInt() ?? 1,
      pageSize: (pagination['pageSize'] as num?)?.toInt() ?? 20,
      total: (pagination['total'] as num?)?.toInt() ?? 0,
      totalPages: (pagination['totalPages'] as num?)?.toInt() ?? 1,
    );
  }
}

/// Giữ tên cũ để các màn hình hóa đơn không phải đổi imports.
String formatInvoiceMoney(Object? value) => formatDecimalMoney(value);

/// Ngày ISO từ API (UTC) hiển thị theo giờ địa phương.
String formatInvoiceDate(Object? value, {bool withTime = true}) {
  final raw = value?.toString() ?? '';
  if (raw.isEmpty) return '—';
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;
  final local = parsed.toLocal();
  return withTime
      ? DateFormat('dd/MM/yyyy HH:mm').format(local)
      : DateFormat('dd/MM/yyyy').format(local);
}

String invoiceStatusLabel(String status) {
  switch (status.toUpperCase()) {
    case 'COMPLETED':
      return 'Hoàn tất';
    case 'CANCELLED':
      return 'Đã hủy';
    case 'DRAFT':
      return 'Nháp';
    default:
      return status;
  }
}

String invoicePaymentLabel(String method) {
  switch (method.toUpperCase()) {
    case 'CASH':
      return 'Tiền mặt';
    case 'BANK_TRANSFER':
      return 'Chuyển khoản';
    case 'PROMOTION':
      return 'Khuyến mãi';
    default:
      return method;
  }
}
