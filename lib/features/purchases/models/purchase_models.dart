import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:abc_app/core/utils/money_format.dart';

/// Ngày ISO từ API (UTC) hiển thị theo giờ máy.
String formatPurchaseDate(Object? value, {bool withTime = false}) {
  final raw = value?.toString() ?? '';
  if (raw.isEmpty) return '—';
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;
  // orderDate / expectedDeliveryDate là ngày thuần do backend lưu ở 00:00Z;
  // giữ theo UTC để không bị lùi ngày trên thiết bị múi giờ âm.
  final isDateOnly = raw.endsWith('T00:00:00.000Z');
  final shown = isDateOnly ? parsed.toUtc() : parsed.toLocal();
  return withTime
      ? DateFormat('dd/MM/yyyy HH:mm').format(shown)
      : DateFormat('dd/MM/yyyy').format(shown);
}

/// Nhà cung cấp (GET /purchases/suppliers).
class Supplier {
  final String id;
  final String code;
  final String name;
  final String contactPerson;
  final String phone;
  final String email;
  final String address;
  final String debtAmount;
  final bool isActive;

  Supplier({
    required this.id,
    required this.code,
    required this.name,
    required this.contactPerson,
    required this.phone,
    required this.email,
    required this.address,
    required this.debtAmount,
    required this.isActive,
  });

  String get displayName => code.isEmpty ? name : '$code • $name';

  factory Supplier.fromJson(Map<String, dynamic> json) {
    return Supplier(
      id: json['id']?.toString() ?? '',
      code: json['supplierCode']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Nhà cung cấp',
      contactPerson: json['contactPerson']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      debtAmount: json['debtAmount']?.toString() ?? '0.00',
      isActive: json['isActive'] as bool? ?? true,
    );
  }
}

/// Một SKU trong danh mục đang cung cấp của NCC.
/// Backend chỉ nhận đặt mua các SKU có trong catalog này.
class SupplierProduct {
  final String variantId;
  final String sku;
  final String productName;
  final String unitOfMeasure;
  final String supplyPrice;
  final String supplierSku;
  final String supplierProductName;
  final int minOrderQty;
  final int orderMultiple;
  final int leadTimeDays;
  final int onHand;
  final bool hasLotTracking;

  SupplierProduct({
    required this.variantId,
    required this.sku,
    required this.productName,
    required this.unitOfMeasure,
    required this.supplyPrice,
    required this.supplierSku,
    required this.supplierProductName,
    required this.minOrderQty,
    required this.orderMultiple,
    required this.leadTimeDays,
    required this.onHand,
    required this.hasLotTracking,
  });

  String get displayName =>
      supplierProductName.isNotEmpty ? supplierProductName : productName;

  factory SupplierProduct.fromJson(Map<String, dynamic> json) {
    final catalog = json['catalog'] is Map<String, dynamic>
        ? json['catalog'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final rawPrice = json['supplyPrice'] ?? catalog['supplyPrice'];
    final min = (catalog['minOrderQty'] as num?)?.toInt() ?? 1;
    final multiple = (catalog['orderMultiple'] as num?)?.toInt() ?? 1;

    return SupplierProduct(
      variantId: json['id']?.toString() ?? '',
      sku: json['sku']?.toString() ?? '',
      productName: json['productName']?.toString() ?? 'Hàng hóa',
      unitOfMeasure: json['unitOfMeasure']?.toString() ?? 'cái',
      supplyPrice: rawPrice?.toString() ?? '0.00',
      supplierSku: catalog['supplierSku']?.toString() ?? '',
      supplierProductName: catalog['supplierProductName']?.toString() ?? '',
      minOrderQty: min < 1 ? 1 : min,
      orderMultiple: multiple < 1 ? 1 : multiple,
      leadTimeDays: (catalog['leadTimeDays'] as num?)?.toInt() ?? 0,
      onHand: (json['onHand'] as num?)?.toInt() ?? 0,
      hasLotTracking: json['hasLotTracking'] as bool? ?? false,
    );
  }
}

/// Dòng hàng trong PO. `remainingQty` là số còn phải nhận.
class PurchaseOrderItem {
  final String id;
  final String variantId;
  final String sku;
  final String productName;
  final String unitOfMeasure;
  final int orderedQty;
  final int receivedQty;
  final int remainingQty;
  final String unitPrice;
  final String subtotal;

  PurchaseOrderItem({
    required this.id,
    required this.variantId,
    required this.sku,
    required this.productName,
    required this.unitOfMeasure,
    required this.orderedQty,
    required this.receivedQty,
    required this.remainingQty,
    required this.unitPrice,
    required this.subtotal,
  });

  factory PurchaseOrderItem.fromJson(Map<String, dynamic> json) {
    final variant = json['variant'] is Map<String, dynamic>
        ? json['variant'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final template = variant['template'] is Map<String, dynamic>
        ? variant['template'] as Map<String, dynamic>
        : const <String, dynamic>{};

    return PurchaseOrderItem(
      id: json['id']?.toString() ?? '',
      variantId: json['variantId']?.toString() ?? '',
      sku: json['sku']?.toString() ?? variant['sku']?.toString() ?? '',
      productName: json['productName']?.toString() ??
          template['name']?.toString() ??
          'Hàng hóa',
      unitOfMeasure: template['unitOfMeasure']?.toString() ?? 'cái',
      orderedQty: (json['orderedQty'] as num?)?.toInt() ?? 0,
      receivedQty: (json['receivedQty'] as num?)?.toInt() ?? 0,
      remainingQty: (json['remainingQty'] as num?)?.toInt() ?? 0,
      unitPrice: json['unitPrice']?.toString() ?? '0.00',
      subtotal: json['subtotal']?.toString() ?? '0.00',
    );
  }
}

class PurchaseOrderTotals {
  final int orderedQty;
  final int receivedQty;
  final String orderedAmount;
  final String receivedAmount;
  final String paidAmount;
  final String debtAmount;

  const PurchaseOrderTotals({
    required this.orderedQty,
    required this.receivedQty,
    required this.orderedAmount,
    required this.receivedAmount,
    required this.paidAmount,
    required this.debtAmount,
  });

  factory PurchaseOrderTotals.fromJson(Map<String, dynamic>? json) {
    final data = json ?? const <String, dynamic>{};
    return PurchaseOrderTotals(
      orderedQty: (data['orderedQty'] as num?)?.toInt() ?? 0,
      receivedQty: (data['receivedQty'] as num?)?.toInt() ?? 0,
      orderedAmount: data['orderedAmount']?.toString() ?? '0.00',
      receivedAmount: data['receivedAmount']?.toString() ?? '0.00',
      paidAmount: data['paidAmount']?.toString() ?? '0.00',
      debtAmount: data['debtAmount']?.toString() ?? '0.00',
    );
  }
}

/// Đơn đặt hàng NCC (PurchaseOrder).
class PurchaseOrder {
  final String id;
  final String code;
  final String status;
  final String supplierId;
  final String supplierName;
  final String supplierPhone;
  final String orderDate;
  final String expectedDeliveryDate;
  final String note;
  final List<PurchaseOrderItem> items;
  final PurchaseOrderTotals totals;

  PurchaseOrder({
    required this.id,
    required this.code,
    required this.status,
    required this.supplierId,
    required this.supplierName,
    required this.supplierPhone,
    required this.orderDate,
    required this.expectedDeliveryDate,
    required this.note,
    required this.items,
    required this.totals,
  });

  int get itemCount => items.length;

  factory PurchaseOrder.fromJson(Map<String, dynamic> json) {
    final supplier = json['supplier'] is Map<String, dynamic>
        ? json['supplier'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final rawItems = json['purchaseOrderItems'] is List
        ? json['purchaseOrderItems'] as List
        : const [];

    return PurchaseOrder(
      id: json['id']?.toString() ?? '',
      code: json['poCode']?.toString() ?? '',
      status: json['status']?.toString() ?? 'ORDERED',
      supplierId: json['supplierId']?.toString() ?? '',
      supplierName: supplier['name']?.toString() ?? '',
      supplierPhone: supplier['phone']?.toString() ?? '',
      orderDate: json['orderDate']?.toString() ?? '',
      expectedDeliveryDate: json['expectedDeliveryDate']?.toString() ?? '',
      note: json['note']?.toString() ?? '',
      items: rawItems
          .whereType<Map<String, dynamic>>()
          .map((e) => PurchaseOrderItem.fromJson(e))
          .toList(),
      totals: PurchaseOrderTotals.fromJson(
        json['totals'] is Map<String, dynamic>
            ? json['totals'] as Map<String, dynamic>
            : null,
      ),
    );
  }
}

class PurchaseOrderPage {
  final List<PurchaseOrder> items;
  final int page;
  final int pageSize;
  final int total;
  final int totalPages;

  PurchaseOrderPage({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
    required this.totalPages,
  });

  bool get hasMore => page < totalPages;

  factory PurchaseOrderPage.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] is List ? json['items'] as List : const [];
    final pagination = json['pagination'] is Map<String, dynamic>
        ? json['pagination'] as Map<String, dynamic>
        : const <String, dynamic>{};

    return PurchaseOrderPage(
      items: rawItems
          .whereType<Map<String, dynamic>>()
          .map((e) => PurchaseOrder.fromJson(e))
          .toList(),
      page: (pagination['page'] as num?)?.toInt() ?? 1,
      pageSize: (pagination['pageSize'] as num?)?.toInt() ?? 20,
      total: (pagination['total'] as num?)?.toInt() ?? 0,
      totalPages: (pagination['totalPages'] as num?)?.toInt() ?? 1,
    );
  }
}

/// Sinh mã PO gợi ý: PO-yyyyMMdd-XXXX. Backend trả 409 nếu trùng mã.
String generatePurchaseCode([DateTime? now]) {
  final d = now ?? DateTime.now();
  final stamp = '${d.year.toString().padLeft(4, '0')}'
      '${d.month.toString().padLeft(2, '0')}'
      '${d.day.toString().padLeft(2, '0')}';
  final suffix = DateTime.now().microsecondsSinceEpoch
      .remainder(0xFFFF)
      .toRadixString(16)
      .toUpperCase()
      .padLeft(4, '0');
  return 'PO-$stamp-$suffix';
}

/// Kiểm tra số lượng đặt có hợp lệ với cấu hình catalog của NCC không.
bool isValidOrderQty(int qty, int minOrderQty, int orderMultiple) {
  if (minOrderQty < 1 || orderMultiple < 1) return false;
  return qty >= minOrderQty && qty % orderMultiple == 0;
}

String purchaseStatusLabel(String status) {
  switch (status.toUpperCase()) {
    case 'DRAFT':
      return 'Nháp';
    case 'ORDERED':
      return 'Đã đặt';
    case 'PARTIALLY_RECEIVED':
      return 'Nhận một phần';
    case 'COMPLETED':
      return 'Đã nhận đủ';
    case 'CLOSED_SHORT':
      return 'Kết thúc thiếu';
    case 'CANCELLED':
      return 'Đã hủy';
    default:
      return status;
  }
}

Color purchaseStatusColor(String status) {
  switch (status.toUpperCase()) {
    case 'COMPLETED':
      return const Color(0xFF047857);
    case 'ORDERED':
      return const Color(0xFF1D4ED8);
    case 'PARTIALLY_RECEIVED':
      return const Color(0xFFB45309);
    case 'CANCELLED':
      return const Color(0xFFC1121F);
    default:
      return const Color(0xFF64748B);
  }
}

/// Thông báo lỗi thân thiện cho người dùng.
String purchaseErrorMessage(Object error) {
  final text = error.toString();
  final match = RegExp(r'"error"\s*:\s*"([^"]+)"').firstMatch(text);
  if (match != null) return match.group(1)!;
  if (text.contains('409')) return 'Mã đơn đặt hàng đã tồn tại. Hãy đổi mã và gửi lại.';
  if (text.contains('403')) return 'Bạn không có quyền thực hiện thao tác này.';
  if (text.contains('404')) return 'Không tìm thấy nhà cung cấp hoặc SKU.';
  return 'Không kết nối được máy chủ. Kiểm tra mạng và thử lại.';
}

/// Dùng cho bản preview tổng tiền trên form (chỉ để hiển thị).
String previewPurchaseAmount(Object? unitPrice, int qty) {
  final price = num.tryParse(unitPrice?.toString() ?? '0') ?? 0;
  return formatDecimalMoney((price * qty).toStringAsFixed(2));
}
