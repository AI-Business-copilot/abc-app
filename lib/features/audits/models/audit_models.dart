// Models for F07 — Stock Audit.
// The shapes mirror `abc-frontend/src/types/audit.ts` and the `formatAuditItem`
// payload of `abc-backend/src/modules/inventory/services/audit.service.ts`.

enum AuditType {
  newLots,
  reAudit;

  static AuditType fromCode(String? code) {
    return (code ?? '').toUpperCase() == 'RE_AUDIT' ? AuditType.reAudit : AuditType.newLots;
  }

  String get code => this == AuditType.reAudit ? 'RE_AUDIT' : 'NEW_LOTS';

  String get label => this == AuditType.reAudit ? 'Kiểm kê lại (lô có sẵn)' : 'Kiểm kê lô mới';
}

enum AuditStatus {
  inProgress,
  done,
  cancelled;

  static AuditStatus fromCode(String? code) {
    switch ((code ?? '').toUpperCase()) {
      case 'DONE':
        return AuditStatus.done;
      case 'CANCELLED':
        return AuditStatus.cancelled;
      default:
        return AuditStatus.inProgress;
    }
  }

  String get code {
    switch (this) {
      case AuditStatus.inProgress:
        return 'IN_PROGRESS';
      case AuditStatus.done:
        return 'DONE';
      case AuditStatus.cancelled:
        return 'CANCELLED';
    }
  }

  String get label {
    switch (this) {
      case AuditStatus.inProgress:
        return 'Đang thực hiện';
      case AuditStatus.done:
        return 'Hoàn thành';
      case AuditStatus.cancelled:
        return 'Đã hủy';
    }
  }
}

enum AuditItemStatus {
  inProgress,
  pendingApproval,
  approved;

  static AuditItemStatus fromCode(String? code) {
    switch ((code ?? '').toUpperCase()) {
      case 'PENDING_APPROVAL':
        return AuditItemStatus.pendingApproval;
      case 'APPROVED':
        return AuditItemStatus.approved;
      default:
        return AuditItemStatus.inProgress;
    }
  }

  String get code {
    switch (this) {
      case AuditItemStatus.inProgress:
        return 'IN_PROGRESS';
      case AuditItemStatus.pendingApproval:
        return 'PENDING_APPROVAL';
      case AuditItemStatus.approved:
        return 'APPROVED';
    }
  }

  String get label {
    switch (this) {
      case AuditItemStatus.inProgress:
        return 'Đang thực hiện';
      case AuditItemStatus.pendingApproval:
        return 'Chờ duyệt';
      case AuditItemStatus.approved:
        return 'Đã duyệt';
    }
  }
}

/// What the employee counts: an existing lot item or a lot that does not exist yet.
enum LotMode {
  existing,
  newLot;

  static LotMode fromCode(String? code) {
    return (code ?? '').toUpperCase() == 'EXISTING' ? LotMode.existing : LotMode.newLot;
  }

  String get code => this == LotMode.existing ? 'EXISTING' : 'NEW';
}

class UserRef {
  final String id;
  final String name;

  const UserRef({required this.id, required this.name});

  factory UserRef.fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) return const UserRef(id: '', name: '');
    return UserRef(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
    );
  }

  bool get isEmpty => id.isEmpty;
}

/// A business member, used as the assignee of an audit row.
class StaffMember {
  final String userId;
  final String fullName;
  final String email;
  final String role;
  final String status;

  const StaffMember({
    required this.userId,
    required this.fullName,
    required this.email,
    required this.role,
    required this.status,
  });

  factory StaffMember.fromJson(Map<String, dynamic> json) {
    final user = (json['user'] as Map<String, dynamic>?) ?? const {};
    return StaffMember(
      userId: user['id']?.toString() ?? '',
      fullName: user['fullName']?.toString() ?? '',
      email: user['email']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
    );
  }

  bool get isAssignable => status == 'ACTIVE' && role != 'OWNER';
}

/// A product (template) the owner picks first in the row editor (`GET /products/list`).
class AuditProductOption {
  final String id;
  final String name;
  final String? imageUrl;

  /// How many active SKUs the product has.
  final int skuCount;
  final bool hasLotTracking;

  const AuditProductOption({
    required this.id,
    required this.name,
    this.imageUrl,
    required this.skuCount,
    required this.hasLotTracking,
  });

  factory AuditProductOption.fromJson(Map<String, dynamic> json) {
    final skus = json['skus'];
    return AuditProductOption(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString(),
      skuCount: skus is List ? skus.length : _toInt(json['variantCount']),
      hasLotTracking: json['hasLotTracking'] == true,
    );
  }
}

/// A SKU option for the owner's row picker (`GET /inventory/variants`).
class VariantOption {
  final String id;
  final String sku;
  final String barcode;
  final String productName;
  final String? imageUrl;
  final bool hasLotTracking;
  final int onHand;
  final String attributeText;

  const VariantOption({
    required this.id,
    required this.sku,
    required this.barcode,
    required this.productName,
    this.imageUrl,
    required this.hasLotTracking,
    required this.onHand,
    required this.attributeText,
  });

  factory VariantOption.fromJson(Map<String, dynamic> json) {
    return VariantOption(
      id: json['id']?.toString() ?? '',
      sku: json['sku']?.toString() ?? '',
      barcode: json['barcode']?.toString() ?? '',
      productName: json['productName']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString(),
      hasLotTracking: json['hasLotTracking'] == true,
      onHand: _toInt(json['onHand']),
      attributeText: json['attributeText']?.toString() ?? '',
    );
  }

  /// From `GET /products/templates/:id` — the attribute text is a flat join of the values.
  factory VariantOption.fromTemplateJson(
    Map<String, dynamic> json,
    String productName,
  ) {
    final values = (json['variantAttributeValues'] as List?) ?? const [];
    final balances = (json['inventoryBalances'] as List?) ?? const [];
    var onHand = 0;
    for (final balance in balances.whereType<Map<String, dynamic>>()) {
      onHand += _toInt(balance['quantityOnHand']);
    }
    return VariantOption(
      id: json['id']?.toString() ?? '',
      sku: json['sku']?.toString() ?? '',
      barcode: json['barcode']?.toString() ?? '',
      productName: productName,
      hasLotTracking: false,
      onHand: onHand,
      attributeText: values
          .whereType<Map<String, dynamic>>()
          .map((value) => (value['attributeValue'] as Map<String, dynamic>?)?['value']?.toString() ?? '')
          .where((value) => value.isNotEmpty)
          .join(' · '),
    );
  }
}

/// One lot of a variant (`GET /inventory/lots?variantId=`).
class VariantLot {
  final String id;
  final String lotId;
  final String lotNumber;
  final DateTime? manufacturingDate;
  final DateTime? expirationDate;
  final int onHand;
  final bool hasOpenScrapOrder;
  final bool isScrapped;
  final ScrapOrderRef? scrapOrder;

  const VariantLot({
    required this.id,
    required this.lotId,
    required this.lotNumber,
    this.manufacturingDate,
    this.expirationDate,
    required this.onHand,
    required this.hasOpenScrapOrder,
    required this.isScrapped,
    this.scrapOrder,
  });

  factory VariantLot.fromJson(Map<String, dynamic> json) {
    final order = json['scrapOrder'];
    return VariantLot(
      id: json['id']?.toString() ?? '',
      lotId: json['lotId']?.toString() ?? '',
      lotNumber: json['lotNumber']?.toString() ?? '',
      manufacturingDate: _toDate(json['manufacturingDate']),
      expirationDate: _toDate(json['expirationDate']),
      onHand: _toInt(json['onHand'] ?? json['quantityOnHand']),
      hasOpenScrapOrder: json['hasOpenScrapOrder'] == true,
      isScrapped: json['isScrapped'] == true,
      scrapOrder: order is Map<String, dynamic> ? ScrapOrderRef.fromJson(order) : null,
    );
  }

  /// A lot that cannot be put into an audit.
  bool get isBlocked => hasOpenScrapOrder || isScrapped;
}

/// A link to the scrap order already raised for a lot.
class ScrapOrderRef {
  final String id;
  final String scrapCode;
  final String status;

  const ScrapOrderRef({
    required this.id,
    required this.scrapCode,
    required this.status,
  });

  factory ScrapOrderRef.fromJson(Map<String, dynamic> json) {
    return ScrapOrderRef(
      id: json['id']?.toString() ?? '',
      scrapCode: json['scrapCode']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
    );
  }
}

/// The header of a stock audit.
class StockAudit {
  final String id;
  final String auditCode;
  final AuditType auditType;
  final AuditStatus status;
  final bool isLockedForAudit;
  final DateTime? countStartAt;
  final DateTime? completedAt;
  final String? approvedBy;
  final UserRef? createdBy;
  final int itemCount;
  final List<StockAuditItem> items;

  const StockAudit({
    required this.id,
    required this.auditCode,
    required this.auditType,
    required this.status,
    required this.isLockedForAudit,
    this.countStartAt,
    this.completedAt,
    this.approvedBy,
    this.createdBy,
    required this.itemCount,
    this.items = const [],
  });

  factory StockAudit.fromJson(Map<String, dynamic> json) {
    final createdBy = json['createdBy'];
    final rawItems = json['items'];
    return StockAudit(
      id: json['id']?.toString() ?? '',
      auditCode: json['auditCode']?.toString() ?? '',
      auditType: AuditType.fromCode(json['auditType']?.toString()),
      status: AuditStatus.fromCode(json['status']?.toString()),
      isLockedForAudit: json['isLockedForAudit'] == true,
      countStartAt: _toDate(json['countStartAt']),
      completedAt: _toDate(json['completedAt']),
      approvedBy: json['approvedBy']?.toString(),
      createdBy: createdBy is Map<String, dynamic> ? UserRef.fromJson(createdBy) : null,
      itemCount: _toInt(json['itemCount']),
      items: rawItems is List
          ? rawItems
              .whereType<Map<String, dynamic>>()
              .map(StockAuditItem.fromJson)
              .toList()
          : const [],
    );
  }
}

/// One row of a stock audit.
class StockAuditItem {
  final String id;
  final String variantId;
  final String sku;
  final String productName;
  final String? imageUrl;
  final String attributeText;
  final String? lotId;
  final String? lotItemId;
  final String? lotNumber;
  final DateTime? expirationDate;
  final DateTime? manufacturingDate;
  final DateTime? lotExpirationDate;
  final DateTime? lotManufacturingDate;
  final DateTime? newLotManufacturingDate;
  final bool datesCorrected;
  final LotMode lotMode;
  final bool isNewLot;
  final int snapshotQty;
  final int countedQty;
  final int diffQty;
  final String? discrepancyReason;
  final AuditItemStatus itemStatus;
  final UserRef? assignedTo;
  final UserRef? createdBy;
  final UserRef? submittedBy;
  final DateTime? submittedAt;
  final UserRef? approvedBy;
  final DateTime? approvedAt;
  final String? rejectionReason;
  final UserRef? rejectedBy;
  final DateTime? rejectedAt;

  const StockAuditItem({
    required this.id,
    required this.variantId,
    required this.sku,
    required this.productName,
    this.imageUrl,
    required this.attributeText,
    this.lotId,
    this.lotItemId,
    this.lotNumber,
    this.expirationDate,
    this.manufacturingDate,
    this.lotExpirationDate,
    this.lotManufacturingDate,
    this.newLotManufacturingDate,
    required this.datesCorrected,
    required this.lotMode,
    required this.isNewLot,
    required this.snapshotQty,
    required this.countedQty,
    required this.diffQty,
    this.discrepancyReason,
    required this.itemStatus,
    this.assignedTo,
    this.createdBy,
    this.submittedBy,
    this.submittedAt,
    this.approvedBy,
    this.approvedAt,
    this.rejectionReason,
    this.rejectedBy,
    this.rejectedAt,
  });

  factory StockAuditItem.fromJson(Map<String, dynamic> json) {
    UserRef? person(String key) {
      final value = json[key];
      return value is Map<String, dynamic> ? UserRef.fromJson(value) : null;
    }

    return StockAuditItem(
      id: json['id']?.toString() ?? '',
      variantId: json['variantId']?.toString() ?? '',
      sku: json['sku']?.toString() ?? '',
      productName: json['productName']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString(),
      attributeText: json['attributeText']?.toString() ?? '',
      lotId: json['lotId']?.toString(),
      lotItemId: json['lotItemId']?.toString(),
      lotNumber: json['lotNumber']?.toString(),
      expirationDate: _toDate(json['expirationDate']),
      manufacturingDate: _toDate(json['manufacturingDate']),
      lotExpirationDate: _toDate(json['lotExpirationDate']),
      lotManufacturingDate: _toDate(json['lotManufacturingDate']),
      newLotManufacturingDate: _toDate(json['newLotManufacturingDate']),
      datesCorrected: json['datesCorrected'] == true,
      lotMode: LotMode.fromCode(json['lotMode']?.toString()),
      isNewLot: json['isNewLot'] == true,
      snapshotQty: _toInt(json['snapshotQty']),
      countedQty: _toInt(json['countedQty']),
      diffQty: _toInt(json['diffQty']),
      discrepancyReason: json['discrepancyReason']?.toString(),
      itemStatus: AuditItemStatus.fromCode(json['itemStatus']?.toString()),
      assignedTo: person('assignedTo'),
      createdBy: person('createdBy'),
      submittedBy: person('submittedBy'),
      submittedAt: _toDate(json['submittedAt']),
      approvedBy: person('approvedBy'),
      approvedAt: _toDate(json['approvedAt']),
      rejectionReason: json['rejectionReason']?.toString(),
      rejectedBy: person('rejectedBy'),
      rejectedAt: _toDate(json['rejectedAt']),
    );
  }

  int get computedDiff => countedQty - snapshotQty;
}

/// The result of approving a single audit item.
class ApproveItemResult {
  final String id;
  final AuditItemStatus itemStatus;
  final DateTime? approvedAt;
  final bool auditAutoApplied;

  const ApproveItemResult({
    required this.id,
    required this.itemStatus,
    this.approvedAt,
    required this.auditAutoApplied,
  });

  factory ApproveItemResult.fromJson(Map<String, dynamic> json) {
    return ApproveItemResult(
      id: json['id']?.toString() ?? '',
      itemStatus: AuditItemStatus.fromCode(json['itemStatus']?.toString()),
      approvedAt: _toDate(json['approvedAt']),
      auditAutoApplied: json['auditAutoApplied'] == true,
    );
  }
}

/// Pagination envelope used by the audit endpoints.
class PaginationInfo {
  final int page;
  final int pageSize;
  final int total;
  final int totalPages;

  const PaginationInfo({
    required this.page,
    required this.pageSize,
    required this.total,
    required this.totalPages,
  });

  factory PaginationInfo.fromJson(Map<String, dynamic> json) {
    return PaginationInfo(
      page: _toInt(json['page'], fallback: 1),
      pageSize: _toInt(json['pageSize'], fallback: 20),
      total: _toInt(json['total']),
      totalPages: _toInt(json['totalPages'], fallback: 1),
    );
  }

  static const empty = PaginationInfo(page: 1, pageSize: 20, total: 0, totalPages: 1);
}

/// A row the owner creates: an employee, a SKU and an optional lot item.
class AuditItemAssignment {
  final String assignedToUserId;
  final String variantId;
  final String? lotItemId;

  const AuditItemAssignment({
    required this.assignedToUserId,
    required this.variantId,
    this.lotItemId,
  });

  Map<String, dynamic> toJson() => {
        'assignedToUserId': assignedToUserId,
        'variantId': variantId,
        if (lotItemId != null && lotItemId!.isNotEmpty) 'lotItemId': lotItemId,
      };
}

int _toInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

DateTime? _toDate(dynamic value) {
  if (value is DateTime) return value;
  if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
  return null;
}
