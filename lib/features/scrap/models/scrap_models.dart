// Models for F08 — Scrap Management.
// The shapes mirror `abc-frontend/src/types/scrap.ts` and
// `abc-backend/src/modules/inventory/services/scrap.service.ts`.

enum ScrapStatus {
  pending,
  completed,
  rejected,
  cancelled;

  static ScrapStatus fromCode(String? code) {
    switch ((code ?? '').toUpperCase()) {
      case 'COMPLETED':
        return ScrapStatus.completed;
      case 'REJECTED':
        return ScrapStatus.rejected;
      case 'CANCELLED':
        return ScrapStatus.cancelled;
      default:
        return ScrapStatus.pending;
    }
  }

  String get code {
    switch (this) {
      case ScrapStatus.pending:
        return 'PENDING';
      case ScrapStatus.completed:
        return 'COMPLETED';
      case ScrapStatus.rejected:
        return 'REJECTED';
      case ScrapStatus.cancelled:
        return 'CANCELLED';
    }
  }

  String get label {
    switch (this) {
      case ScrapStatus.pending:
        return 'Chờ duyệt';
      case ScrapStatus.completed:
        return 'Đã duyệt';
      case ScrapStatus.rejected:
        return 'Bị từ chối';
      case ScrapStatus.cancelled:
        return 'Đã hủy bỏ';
    }
  }
}

/// Which pool of stock the scrap comes from.
enum ScrapSource {
  damagedStock,
  sellableStock;

  static ScrapSource fromCode(String? code) {
    return (code ?? '').toUpperCase() == 'DAMAGED_STOCK'
        ? ScrapSource.damagedStock
        : ScrapSource.sellableStock;
  }

  String get code {
    switch (this) {
      case ScrapSource.damagedStock:
        return 'DAMAGED_STOCK';
      case ScrapSource.sellableStock:
        return 'SELLABLE_STOCK';
    }
  }

  String get label {
    switch (this) {
      case ScrapSource.damagedStock:
        return 'Hàng hư hỏng';
      case ScrapSource.sellableStock:
        return 'Hàng có thể bán';
    }
  }
}

/// The reason codes the Owner can pick when rejecting a scrap order.
enum RejectionReasonCode {
  wrongQuantity,
  photoUnclear,
  notRemovedFromShelf,
  other;

  static RejectionReasonCode? fromCode(String? code) {
    switch ((code ?? '').toUpperCase()) {
      case 'WRONG_QUANTITY':
        return RejectionReasonCode.wrongQuantity;
      case 'PHOTO_UNCLEAR':
        return RejectionReasonCode.photoUnclear;
      case 'NOT_REMOVED_FROM_SHELF':
        return RejectionReasonCode.notRemovedFromShelf;
      case 'OTHER':
        return RejectionReasonCode.other;
      default:
        return null;
    }
  }

  String get code {
    switch (this) {
      case RejectionReasonCode.wrongQuantity:
        return 'WRONG_QUANTITY';
      case RejectionReasonCode.photoUnclear:
        return 'PHOTO_UNCLEAR';
      case RejectionReasonCode.notRemovedFromShelf:
        return 'NOT_REMOVED_FROM_SHELF';
      case RejectionReasonCode.other:
        return 'OTHER';
    }
  }

  String get label {
    switch (this) {
      case RejectionReasonCode.wrongQuantity:
        return 'Số lượng không đúng';
      case RejectionReasonCode.photoUnclear:
        return 'Ảnh không rõ';
      case RejectionReasonCode.notRemovedFromShelf:
        return 'Chưa bỏ khỏi kệ';
      case RejectionReasonCode.other:
        return 'Lý do khác';
    }
  }
}

/// Limits enforced by the backend (`scrap-image.service.ts`).
const int maxScrapImages = 10;
const int maxScrapImageBytes = 5 * 1024 * 1024;
const List<String> allowedScrapImageTypes = ['image/jpeg', 'image/png', 'image/webp'];

/// A person attached to a scrap order.
class ScrapUser {
  final String id;
  final String fullName;
  final String email;

  const ScrapUser({
    required this.id,
    required this.fullName,
    required this.email,
  });

  factory ScrapUser.fromJson(Map<String, dynamic> json) {
    return ScrapUser(
      id: json['id']?.toString() ?? '',
      fullName: json['fullName']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
    );
  }
}

/// The SKU of a scrap order.
class ScrapVariant {
  final String id;
  final String sku;
  final String productName;
  final double costPrice;

  const ScrapVariant({
    required this.id,
    required this.sku,
    required this.productName,
    required this.costPrice,
  });

  factory ScrapVariant.fromJson(Map<String, dynamic> json) {
    final template = (json['template'] as Map<String, dynamic>?) ?? const {};
    return ScrapVariant(
      id: json['id']?.toString() ?? '',
      sku: json['sku']?.toString() ?? '',
      productName: (json['name'] ?? template['name'])?.toString() ?? '',
      costPrice: _toDouble(json['costPrice']),
    );
  }
}

/// The lot item the scrap is taken from.
class ScrapLotItem {
  final String id;
  final DateTime? expirationDate;
  final String status;
  final int? quarantineQty;
  final String lotNumber;

  const ScrapLotItem({
    required this.id,
    this.expirationDate,
    required this.status,
    this.quarantineQty,
    required this.lotNumber,
  });

  factory ScrapLotItem.fromJson(Map<String, dynamic> json) {
    final lot = (json['lot'] as Map<String, dynamic>?) ?? const {};
    return ScrapLotItem(
      id: json['id']?.toString() ?? '',
      expirationDate: _toDate(json['expirationDate']),
      status: json['status']?.toString() ?? '',
      quarantineQty: json['quarantineQty'] == null ? null : _toInt(json['quarantineQty']),
      lotNumber: lot['lotNumber']?.toString() ?? '',
    );
  }
}

/// A scrap order.
class ScrapOrder {
  final String id;
  final String scrapCode;
  final String variantId;
  final String? lotItemId;
  final int scrapQty;
  final double unitCost;
  final ScrapSource scrapSource;
  final String scrapReason;
  final ScrapStatus status;
  final double? totalLossValue;
  final String createdBy;
  final DateTime? createdAt;
  final DateTime? approvedAt;
  final DateTime? rejectedAt;
  final String? rejectionReasonCode;
  final String? rejectionNote;
  final DateTime? cancelledAt;
  final String? cancelledNote;
  final ScrapVariant variant;
  final ScrapLotItem? lotItem;
  final ScrapUser? createdByUser;
  final ScrapUser? approvedByUser;
  final ScrapUser? rejectedByUser;
  final ScrapUser? cancelledByUser;
  final int imageCount;

  const ScrapOrder({
    required this.id,
    required this.scrapCode,
    required this.variantId,
    this.lotItemId,
    required this.scrapQty,
    required this.unitCost,
    required this.scrapSource,
    required this.scrapReason,
    required this.status,
    this.totalLossValue,
    required this.createdBy,
    this.createdAt,
    this.approvedAt,
    this.rejectedAt,
    this.rejectionReasonCode,
    this.rejectionNote,
    this.cancelledAt,
    this.cancelledNote,
    required this.variant,
    this.lotItem,
    this.createdByUser,
    this.approvedByUser,
    this.rejectedByUser,
    this.cancelledByUser,
    this.imageCount = 0,
  });

  factory ScrapOrder.fromJson(Map<String, dynamic> json) {
    final variant = (json['variant'] as Map<String, dynamic>?) ?? const {};
    final lotItem = json['lotItem'];
    final count = json['_count'];
    ScrapUser? user(String key) {
      final value = json[key];
      return value is Map<String, dynamic> ? ScrapUser.fromJson(value) : null;
    }

    return ScrapOrder(
      id: json['id']?.toString() ?? '',
      scrapCode: json['scrapCode']?.toString() ?? '',
      variantId: json['variantId']?.toString() ?? '',
      lotItemId: json['lotItemId']?.toString(),
      scrapQty: _toInt(json['scrapQty']),
      unitCost: _toDouble(json['unitCost']),
      scrapSource: ScrapSource.fromCode(json['scrapSource']?.toString()),
      scrapReason: json['scrapReason']?.toString() ?? '',
      status: ScrapStatus.fromCode(json['status']?.toString()),
      totalLossValue:
          json['totalLossValue'] == null ? null : _toDouble(json['totalLossValue']),
      createdBy: json['createdBy']?.toString() ?? '',
      createdAt: _toDate(json['createdAt']),
      approvedAt: _toDate(json['approvedAt']),
      rejectedAt: _toDate(json['rejectedAt']),
      rejectionReasonCode: json['rejectionReasonCode']?.toString(),
      rejectionNote: json['rejectionNote']?.toString(),
      cancelledAt: _toDate(json['cancelledAt']),
      cancelledNote: json['cancelledNote']?.toString(),
      variant: ScrapVariant.fromJson(variant),
      lotItem: lotItem is Map<String, dynamic> ? ScrapLotItem.fromJson(lotItem) : null,
      createdByUser: user('createdByUser'),
      approvedByUser: user('approvedByUser'),
      rejectedByUser: user('rejectedByUser'),
      cancelledByUser: user('cancelledByUser'),
      // Prisma answers a filtered relation count as `{ count: n }`; an unfiltered one as a number.
      imageCount: count is Map<String, dynamic>
          ? _imageCount(count['images'])
          : 0,
    );
  }

  static int _imageCount(dynamic value) {
    if (value is num) return value.toInt();
    if (value is Map<String, dynamic>) return _toInt(value['count']);
    return 0;
  }

  double get estimatedLoss => unitCost * scrapQty;
}

/// An evidence photo of a scrap order.
class ScrapImage {
  final String id;
  final String scrapOrderId;
  final String mimeType;
  final int sizeBytes;
  final String uploadedBy;
  final String uploadedByName;
  final DateTime? createdAt;
  final String? url;

  const ScrapImage({
    required this.id,
    required this.scrapOrderId,
    required this.mimeType,
    required this.sizeBytes,
    required this.uploadedBy,
    required this.uploadedByName,
    this.createdAt,
    this.url,
  });

  factory ScrapImage.fromJson(Map<String, dynamic> json) {
    return ScrapImage(
      id: json['id']?.toString() ?? '',
      scrapOrderId: json['scrapOrderId']?.toString() ?? '',
      mimeType: json['mimeType']?.toString() ?? '',
      sizeBytes: _toInt(json['sizeBytes']),
      uploadedBy: json['uploadedBy']?.toString() ?? '',
      uploadedByName: json['uploadedByName']?.toString() ?? '',
      createdAt: _toDate(json['createdAt']),
      url: json['url']?.toString(),
    );
  }
}

/// A scrap order with its evidence photos.
class ScrapOrderDetail extends ScrapOrder {
  final List<ScrapImage> images;

  const ScrapOrderDetail({
    required super.id,
    required super.scrapCode,
    required super.variantId,
    super.lotItemId,
    required super.scrapQty,
    required super.unitCost,
    required super.scrapSource,
    required super.scrapReason,
    required super.status,
    super.totalLossValue,
    required super.createdBy,
    super.createdAt,
    super.approvedAt,
    super.rejectedAt,
    super.rejectionReasonCode,
    super.rejectionNote,
    super.cancelledAt,
    super.cancelledNote,
    required super.variant,
    super.lotItem,
    super.createdByUser,
    super.approvedByUser,
    super.rejectedByUser,
    super.cancelledByUser,
    super.imageCount,
    required this.images,
  });

  factory ScrapOrderDetail.fromJson(Map<String, dynamic> json) {
    final base = ScrapOrder.fromJson(json);
    final raw = json['images'];
    return ScrapOrderDetail(
      id: base.id,
      scrapCode: base.scrapCode,
      variantId: base.variantId,
      lotItemId: base.lotItemId,
      scrapQty: base.scrapQty,
      unitCost: base.unitCost,
      scrapSource: base.scrapSource,
      scrapReason: base.scrapReason,
      status: base.status,
      totalLossValue: base.totalLossValue,
      createdBy: base.createdBy,
      createdAt: base.createdAt,
      approvedAt: base.approvedAt,
      rejectedAt: base.rejectedAt,
      rejectionReasonCode: base.rejectionReasonCode,
      rejectionNote: base.rejectionNote,
      cancelledAt: base.cancelledAt,
      cancelledNote: base.cancelledNote,
      variant: base.variant,
      lotItem: base.lotItem,
      createdByUser: base.createdByUser,
      approvedByUser: base.approvedByUser,
      rejectedByUser: base.rejectedByUser,
      cancelledByUser: base.cancelledByUser,
      imageCount: base.imageCount,
      images: raw is List
          ? raw.whereType<Map<String, dynamic>>().map(ScrapImage.fromJson).toList()
          : const [],
    );
  }
}

/// The counts shown on the scrap list screen.
class ScrapStatistics {
  final int pendingCount;
  final int completedCount;
  final int rejectedCount;
  final int cancelledCount;
  final double totalLossValue;
  final int damagedStockCount;
  final int sellableStockCount;

  const ScrapStatistics({
    this.pendingCount = 0,
    this.completedCount = 0,
    this.rejectedCount = 0,
    this.cancelledCount = 0,
    this.totalLossValue = 0,
    this.damagedStockCount = 0,
    this.sellableStockCount = 0,
  });

  factory ScrapStatistics.fromJson(Map<String, dynamic> json) {
    final bySource = (json['bySource'] as Map<String, dynamic>?) ?? const {};
    return ScrapStatistics(
      pendingCount: _toInt(json['pendingCount']),
      completedCount: _toInt(json['completedCount']),
      rejectedCount: _toInt(json['rejectedCount']),
      cancelledCount: _toInt(json['cancelledCount']),
      totalLossValue: _toDouble(json['totalLossValue']),
      damagedStockCount: _toInt(bySource['DAMAGED_STOCK']),
      sellableStockCount: _toInt(bySource['SELLABLE_STOCK']),
    );
  }
}

/// The result of approving a scrap order.
class ApproveScrapResult {
  final ScrapOrder? scrapOrder;
  final int inventoryReduced;
  final double lossAmount;
  final bool lotScrapped;
  final bool ledgerCreated;

  const ApproveScrapResult({
    this.scrapOrder,
    this.inventoryReduced = 0,
    this.lossAmount = 0,
    this.lotScrapped = false,
    this.ledgerCreated = false,
  });

  factory ApproveScrapResult.fromJson(Map<String, dynamic> json) {
    final order = json['scrapOrder'];
    return ApproveScrapResult(
      scrapOrder: order is Map<String, dynamic> ? ScrapOrder.fromJson(order) : null,
      inventoryReduced: _toInt(json['inventoryReduced']),
      lossAmount: _toDouble(json['lossAmount']),
      lotScrapped: json['lotScrapped'] == true,
      ledgerCreated: json['ledgerCreated'] == true,
    );
  }
}

int _toInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

double _toDouble(dynamic value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

DateTime? _toDate(dynamic value) {
  if (value is DateTime) return value;
  if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
  return null;
}
