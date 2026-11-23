// Models for F07 — Stock Audit.
// The shapes mirror `abc-frontend/src/types/audit.ts` and the `formatAuditItem`
// payload of `abc-backend/src/modules/inventory/services/audit.service.ts`.

enum AuditStatus {
  /// The owner is still preparing it: nothing is locked and it can be deleted.
  draft,
  inProgress,
  done,
  cancelled;

  static AuditStatus fromCode(String? code) {
    switch ((code ?? '').toUpperCase()) {
      case 'DRAFT':
        return AuditStatus.draft;
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
      case AuditStatus.draft:
        return 'DRAFT';
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
      case AuditStatus.draft:
        return 'Nháp';
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

  /// The label of the row, given the status of the audit it belongs to.
  ///
  /// A row of a draft has not been counted yet: the audit-level status is the gate that blocks
  /// counting, so the row's own status alone would wrongly claim it is being counted.
  String labelForAudit(AuditStatus auditStatus) {
    if (auditStatus == AuditStatus.draft && this == AuditItemStatus.inProgress) {
      return 'Chưa đếm';
    }
    return label;
  }
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

/// How the two counters of a row relate to each other.
enum CountAgreement {
  /// Only one counter is assigned to the row.
  single,
  /// Two counters are assigned but nobody has sent a count yet.
  notStarted,
  /// Two counters, but only one has sent their count so far.
  pending,
  /// Two counters, both submitted, and the numbers match.
  agreed,
  /// Two counters, both submitted, and the numbers differ. The owner decides.
  conflict;

  static CountAgreement fromCode(String? code) {
    switch ((code ?? '').toUpperCase()) {
      case 'NOT_STARTED':
        return CountAgreement.notStarted;
      case 'PENDING':
        return CountAgreement.pending;
      case 'AGREED':
        return CountAgreement.agreed;
      case 'CONFLICT':
        return CountAgreement.conflict;
      default:
        return CountAgreement.single;
    }
  }

  String get label {
    switch (this) {
      case CountAgreement.single:
        return 'Một người kiểm kê';
      case CountAgreement.notStarted:
        return 'Chưa đếm';
      case CountAgreement.pending:
        return 'Chờ người còn lại';
      case CountAgreement.agreed:
        return 'Hai người khớp';
      case CountAgreement.conflict:
        return 'Hai người khác nhau';
    }
  }
}

/// Limits enforced by the backend (`audit-image.service.ts`).
const int maxAuditImages = 10;
const int maxAuditImageBytes = 5 * 1024 * 1024;

/// An evidence photo of the broken goods one counter found during their count.
class AuditItemCountImage {
  final String id;
  final String countId;
  final String mimeType;
  final int sizeBytes;
  final String uploadedBy;
  final String uploadedByName;
  final DateTime? createdAt;
  /// Short-lived signed link (5 minutes). Null when storage could not sign it.
  final String? url;

  const AuditItemCountImage({
    required this.id,
    required this.countId,
    required this.mimeType,
    required this.sizeBytes,
    required this.uploadedBy,
    required this.uploadedByName,
    this.createdAt,
    this.url,
  });

  factory AuditItemCountImage.fromJson(Map<String, dynamic> json) {
    return AuditItemCountImage(
      id: json['id']?.toString() ?? '',
      countId: json['countId']?.toString() ?? '',
      mimeType: json['mimeType']?.toString() ?? '',
      sizeBytes: _toInt(json['sizeBytes']),
      uploadedBy: json['uploadedBy']?.toString() ?? '',
      uploadedByName: json['uploadedByName']?.toString() ?? '',
      createdAt: _toDate(json['createdAt']),
      url: json['url']?.toString(),
    );
  }
}

/// One counter's independent count on an audit row.
class AuditItemCount {
  final String id;
  final String counterUserId;
  final UserRef? counter;
  final int countedQty;
  final int countedDamagedQty;
  final String? discrepancyReason;
  final DateTime? submittedAt;
  /// The photos this counter took of the broken goods.
  final List<AuditItemCountImage> images;

  const AuditItemCount({
    required this.id,
    required this.counterUserId,
    this.counter,
    required this.countedQty,
    required this.countedDamagedQty,
    this.discrepancyReason,
    this.submittedAt,
    this.images = const [],
  });

  factory AuditItemCount.fromJson(Map<String, dynamic> json) {
    final counter = json['counter'];
    final rawImages = json['images'];
    return AuditItemCount(
      id: json['id']?.toString() ?? '',
      counterUserId: json['counterUserId']?.toString() ?? '',
      counter: counter is Map<String, dynamic> ? UserRef.fromJson(counter) : null,
      countedQty: _toInt(json['countedQty']),
      countedDamagedQty: _toInt(json['countedDamagedQty']),
      discrepancyReason: json['discrepancyReason']?.toString(),
      submittedAt: _toDate(json['submittedAt']),
      images: rawImages is List
          ? rawImages
              .whereType<Map<String, dynamic>>()
              .map(AuditItemCountImage.fromJson)
              .toList()
          : const [],
    );
  }

  bool get isSubmitted => submittedAt != null;

  /// The total handed in by this counter: usable quantity plus broken goods.
  int get totalCountedQty => countedQty + countedDamagedQty;
}

/// One counter's own reason and broken goods, so the owner sees both without the row's fields.
class AuditCounterDetail {
  final String counterUserId;
  final UserRef? counter;
  final String? discrepancyReason;
  final int countedDamagedQty;

  const AuditCounterDetail({
    required this.counterUserId,
    this.counter,
    this.discrepancyReason,
    this.countedDamagedQty = 0,
  });

  factory AuditCounterDetail.fromJson(Map<String, dynamic> json) {
    final counter = json['counter'];
    return AuditCounterDetail(
      counterUserId: json['counterUserId']?.toString() ?? '',
      counter: counter is Map<String, dynamic> ? UserRef.fromJson(counter) : null,
      discrepancyReason: json['discrepancyReason']?.toString(),
      countedDamagedQty: _toInt(json['countedDamagedQty']),
    );
  }
}

/// What the owner decided about a row.
enum AuditHistoryAction {
  approved,
  rejected,
  recount;

  static AuditHistoryAction fromCode(String? code) {
    switch (code) {
      case 'APPROVED':
        return AuditHistoryAction.approved;
      case 'REJECTED':
        return AuditHistoryAction.rejected;
      case 'RECOUNT':
        return AuditHistoryAction.recount;
      default:
        return AuditHistoryAction.approved;
    }
  }

  String get code {
    switch (this) {
      case AuditHistoryAction.approved:
        return 'APPROVED';
      case AuditHistoryAction.rejected:
        return 'REJECTED';
      case AuditHistoryAction.recount:
        return 'RECOUNT';
    }
  }

  String get label {
    switch (this) {
      case AuditHistoryAction.approved:
        return 'Đã duyệt';
      case AuditHistoryAction.rejected:
        return 'Đã từ chối';
      case AuditHistoryAction.recount:
        return 'Yêu cầu đếm lại';
    }
  }
}

/// One counter's number at the moment of a history record.
class AuditItemHistoryCount {
  final String id;
  final String counterUserId;
  final UserRef? counter;
  final int countedQty;
  final int countedDamagedQty;
  final String? discrepancyReason;
  final DateTime? submittedAt;

  const AuditItemHistoryCount({
    required this.id,
    required this.counterUserId,
    this.counter,
    required this.countedQty,
    required this.countedDamagedQty,
    this.discrepancyReason,
    this.submittedAt,
  });

  factory AuditItemHistoryCount.fromJson(Map<String, dynamic> json) {
    final counter = json['counter'];
    return AuditItemHistoryCount(
      id: json['id']?.toString() ?? '',
      counterUserId: json['counterUserId']?.toString() ?? '',
      counter: counter is Map<String, dynamic> ? UserRef.fromJson(counter) : null,
      countedQty: _toInt(json['countedQty']),
      countedDamagedQty: _toInt(json['countedDamagedQty']),
      discrepancyReason: json['discrepancyReason']?.toString(),
      submittedAt: _toDate(json['submittedAt']),
    );
  }
}

/// One record of a row: what was counted when the owner decided something.
///
/// The numbers are a copy of that moment, so the record does not change when the live row does.
class AuditItemHistory {
  final String id;
  final int revision;
  final AuditHistoryAction action;
  final String? reason;
  final DateTime? createdAt;
  final int snapshotQty;
  final int countedQty;
  final int countedDamagedQty;
  final String? discrepancyReason;
  final UserRef? actor;
  final List<AuditItemHistoryCount> counts;
  /// The evidence photos filed under this record.
  final List<AuditItemCountImage> images;

  const AuditItemHistory({
    required this.id,
    required this.revision,
    required this.action,
    this.reason,
    this.createdAt,
    this.snapshotQty = 0,
    this.countedQty = 0,
    this.countedDamagedQty = 0,
    this.discrepancyReason,
    this.actor,
    this.counts = const [],
    this.images = const [],
  });

  factory AuditItemHistory.fromJson(Map<String, dynamic> json) {
    final actor = json['actor'];
    final rawCounts = json['counts'];
    final rawImages = json['images'];
    return AuditItemHistory(
      id: json['id']?.toString() ?? '',
      revision: _toInt(json['revision']),
      action: AuditHistoryAction.fromCode(json['action']?.toString()),
      reason: json['reason']?.toString(),
      createdAt: _toDate(json['createdAt']),
      snapshotQty: _toInt(json['snapshotQty']),
      countedQty: _toInt(json['countedQty']),
      countedDamagedQty: _toInt(json['countedDamagedQty']),
      discrepancyReason: json['discrepancyReason']?.toString(),
      actor: actor is Map<String, dynamic> ? UserRef.fromJson(actor) : null,
      counts: rawCounts is List
          ? rawCounts
              .whereType<Map<String, dynamic>>()
              .map(AuditItemHistoryCount.fromJson)
              .toList()
          : const [],
      images: rawImages is List
          ? rawImages
              .whereType<Map<String, dynamic>>()
              .map(AuditItemCountImage.fromJson)
              .toList()
          : const [],
    );
  }
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
  final int snapshotQty;
  final int countedQty;
  /// The broken goods the employee counted. The total is derived: countedQty + countedDamagedQty.
  final int countedDamagedQty;
  final int diffQty;
  final String? discrepancyReason;
  final AuditItemStatus itemStatus;
  final UserRef? assignedTo;
  /// The optional second counter. When set, the row counts twice.
  final UserRef? secondCounter;
  final String? secondCounterUserId;
  /// How the counters relate: SINGLE / NOT_STARTED / PENDING / AGREED / CONFLICT.
  final CountAgreement countAgreement;
  /// The visible counts. A staff member only ever receives their own count.
  final List<AuditItemCount> counts;
  /// The reason and broken goods of every counter. The row's own fields belong to the first one.
  final List<AuditCounterDetail> counterDetails;
  /// The row's history. Only the owner may read it, so a staff member receives an empty list.
  final List<AuditItemHistory> histories;
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
    required this.snapshotQty,
    required this.countedQty,
    required this.countedDamagedQty,
    required this.diffQty,
    this.discrepancyReason,
    required this.itemStatus,
    this.assignedTo,
    this.secondCounter,
    this.secondCounterUserId,
    required this.countAgreement,
    this.counts = const [],
    this.counterDetails = const [],
    this.histories = const [],
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

    final rawCounts = (json['counts'] as List?) ?? const [];
    final rawCounterDetails = (json['counterDetails'] as List?) ?? const [];
    final rawHistories = (json['histories'] as List?) ?? const [];

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
      snapshotQty: _toInt(json['snapshotQty']),
      countedQty: _toInt(json['countedQty']),
      countedDamagedQty: _toInt(json['countedDamagedQty']),
      diffQty: _toInt(json['diffQty']),
      discrepancyReason: json['discrepancyReason']?.toString(),
      itemStatus: AuditItemStatus.fromCode(json['itemStatus']?.toString()),
      assignedTo: person('assignedTo'),
      secondCounter: person('secondCounter'),
      secondCounterUserId: json['secondCounterUserId']?.toString(),
      countAgreement: CountAgreement.fromCode(json['countAgreement']?.toString()),
      counts: rawCounts
          .whereType<Map<String, dynamic>>()
          .map(AuditItemCount.fromJson)
          .toList(),
      counterDetails: rawCounterDetails
          .whereType<Map<String, dynamic>>()
          .map(AuditCounterDetail.fromJson)
          .toList(),
      histories: rawHistories
          .whereType<Map<String, dynamic>>()
          .map(AuditItemHistory.fromJson)
          .toList(),
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

  /// The total handed in: the usable quantity plus the broken goods. Derived, never stored.
  int get totalCountedQty => countedQty + countedDamagedQty;

  /// The row's counters: the employee it was assigned to and the second counter.
  ///
  /// Both people are always listed, even when one of them has not counted yet. A staff member
  /// receives only their own count from the server, so the other person shows without numbers,
  /// which keeps the second count blind.
  List<_CounterRow> get counterRows {
    final people = <UserRef?>[
      assignedTo,
      secondCounter,
    ].whereType<UserRef>().toList();

    return people.map((person) {
      AuditItemCount? count;
      for (final c in counts) {
        if (c.counterUserId == person.id) {
          count = c;
          break;
        }
      }
      return _CounterRow(
        id: person.id,
        name: person.name,
        count: count,
        countId: count?.id,
      );
    }).toList();
  }
}

/// One of the row's counters, with their count when they have already counted.
class _CounterRow {
  final String id;
  final String name;
  final AuditItemCount? count;

  /// The id of the count, needed to fetch the signed links of its photos.
  final String? countId;

  const _CounterRow({
    required this.id,
    required this.name,
    this.count,
    this.countId,
  });

  bool get hasCount => count != null;
  int? get countedQty => count?.countedQty;
  int? get countedDamagedQty => count?.countedDamagedQty;
  bool get isSubmitted => count?.isSubmitted ?? false;
  List<AuditItemCountImage> get images => count?.images ?? const [];
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

/// A row the owner creates: an employee, a SKU and the lot item it counts.
class AuditItemAssignment {
  final String assignedToUserId;
  final String variantId;
  final String lotItemId;
  /// The second counter. Required: every row is counted by two people.
  final String secondCounterUserId;

  const AuditItemAssignment({
    required this.assignedToUserId,
    required this.variantId,
    required this.lotItemId,
    required this.secondCounterUserId,
  });

  Map<String, dynamic> toJson() => {
        'assignedToUserId': assignedToUserId,
        'variantId': variantId,
        'lotItemId': lotItemId,
        'secondCounterUserId': secondCounterUserId,
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
