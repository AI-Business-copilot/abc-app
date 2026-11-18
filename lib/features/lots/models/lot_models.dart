// Models for F08 — Lot Tracking.
// The shapes mirror `abc-frontend/src/types/scrap.ts` and
// `abc-backend/src/modules/inventory/services/lot.service.ts`.

enum LotStatus {
  healthy,
  warning,
  unusable,
  quarantined,
  scrapped;

  static LotStatus fromCode(String? code) {
    switch ((code ?? '').toUpperCase()) {
      case 'WARNING':
        return LotStatus.warning;
      case 'UNUSABLE':
        return LotStatus.unusable;
      case 'QUARANTINED':
        return LotStatus.quarantined;
      case 'SCRAPPED':
        return LotStatus.scrapped;
      default:
        return LotStatus.healthy;
    }
  }

  String get code {
    switch (this) {
      case LotStatus.healthy:
        return 'HEALTHY';
      case LotStatus.warning:
        return 'WARNING';
      case LotStatus.unusable:
        return 'UNUSABLE';
      case LotStatus.quarantined:
        return 'QUARANTINED';
      case LotStatus.scrapped:
        return 'SCRAPPED';
    }
  }

  String get label {
    switch (this) {
      case LotStatus.healthy:
        return 'Còn hạn';
      case LotStatus.warning:
        return 'Sắp hết hạn';
      case LotStatus.unusable:
        return 'Hết hạn / không dùng được';
      case LotStatus.quarantined:
        return 'Đang cách ly';
      case LotStatus.scrapped:
        return 'Đã hủy hàng';
    }
  }
}

/// The SKU inside a lot.
class LotVariant {
  final String id;
  final String sku;
  final String productName;

  const LotVariant({
    required this.id,
    required this.sku,
    required this.productName,
  });

  factory LotVariant.fromJson(Map<String, dynamic> json) {
    final template = (json['template'] as Map<String, dynamic>?) ?? const {};
    return LotVariant(
      id: json['id']?.toString() ?? '',
      sku: json['sku']?.toString() ?? '',
      productName: template['name']?.toString() ?? '',
    );
  }
}

/// One variant item inside a lot batch. Quarantine and scrap orders act on this row.
class LotItem {
  final String id;
  final String lotId;
  final String variantId;
  final String lotNumber;
  final DateTime? manufacturingDate;
  final DateTime? expirationDate;
  final String dbStatus;
  final String calculatedStatus;
  final LotStatus effectiveStatus;
  final int daysUntilExpiry;
  final int? quarantineQty;
  final DateTime? quarantinedAt;
  final LotVariant variant;
  final int onHand;
  final int damaged;
  final ScrapOrderLink? scrapOrder;

  const LotItem({
    required this.id,
    required this.lotId,
    required this.variantId,
    required this.lotNumber,
    this.manufacturingDate,
    this.expirationDate,
    required this.dbStatus,
    required this.calculatedStatus,
    required this.effectiveStatus,
    required this.daysUntilExpiry,
    this.quarantineQty,
    this.quarantinedAt,
    required this.variant,
    required this.onHand,
    required this.damaged,
    this.scrapOrder,
  });

  factory LotItem.fromJson(Map<String, dynamic> json) {
    final variant = (json['variant'] as Map<String, dynamic>?) ?? const {};
    final order = json['scrapOrder'];
    return LotItem(
      id: json['id']?.toString() ?? '',
      lotId: json['lotId']?.toString() ?? '',
      variantId: json['variantId']?.toString() ?? '',
      lotNumber: json['lotNumber']?.toString() ?? '',
      manufacturingDate: _toDate(json['manufacturingDate']),
      expirationDate: _toDate(json['expirationDate']),
      dbStatus: json['dbStatus']?.toString() ?? '',
      calculatedStatus: json['calculatedStatus']?.toString() ?? '',
      effectiveStatus: LotStatus.fromCode(json['effectiveStatus']?.toString()),
      daysUntilExpiry: _toInt(json['daysUntilExpiry']),
      quarantineQty: json['quarantineQty'] == null ? null : _toInt(json['quarantineQty']),
      quarantinedAt: _toDate(json['quarantinedAt']),
      variant: LotVariant.fromJson(variant),
      onHand: _toInt(json['onHand']),
      damaged: _toInt(json['damaged']),
      scrapOrder: order is Map<String, dynamic> ? ScrapOrderLink.fromJson(order) : null,
    );
  }

  /// Units still sellable plus units already marked damaged.
  int get totalStock => onHand + damaged;

  /// True when the newest scrap order still blocks a new one. Only a PENDING order does: a
  /// rejected or cancelled order is settled, so any staff member can file a fresh order.
  bool get scrapOrderBlocksNew => scrapOrder?.status == 'PENDING';
}

/// A link to the scrap order already raised for a lot item.
class ScrapOrderLink {
  final String id;
  final String scrapCode;
  final String status;

  const ScrapOrderLink({
    required this.id,
    required this.scrapCode,
    required this.status,
  });

  factory ScrapOrderLink.fromJson(Map<String, dynamic> json) {
    return ScrapOrderLink(
      id: json['id']?.toString() ?? '',
      scrapCode: json['scrapCode']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
    );
  }

  /// Vietnamese label for the order status, so the raw code never reaches the user.
  String get statusLabel {
    switch (status.toUpperCase()) {
      case 'COMPLETED':
        return 'Đã duyệt';
      case 'REJECTED':
        return 'Bị từ chối';
      case 'CANCELLED':
        return 'Đã hủy bỏ';
      default:
        return 'Chờ duyệt';
    }
  }
}

/// A batch (product_lots row) with the variant items inside it.
class LotBatch {
  final String id;
  final String lotNumber;
  final List<LotItem> items;

  const LotBatch({
    required this.id,
    required this.lotNumber,
    required this.items,
  });

  factory LotBatch.fromJson(Map<String, dynamic> json) {
    final raw = json['items'];
    return LotBatch(
      id: json['id']?.toString() ?? '',
      lotNumber: json['lotNumber']?.toString() ?? '',
      items: raw is List
          ? raw.whereType<Map<String, dynamic>>().map(LotItem.fromJson).toList()
          : const [],
    );
  }
}

/// Per-status counts of the expiry list. The counts cover every lot, whatever tab is open.
class LotSummary {
  final int healthy;
  final int warning;
  final int unusable;
  final int quarantined;
  final int scrapped;
  final int total;

  const LotSummary({
    this.healthy = 0,
    this.warning = 0,
    this.unusable = 0,
    this.quarantined = 0,
    this.scrapped = 0,
    this.total = 0,
  });

  factory LotSummary.fromJson(Map<String, dynamic> json) {
    return LotSummary(
      healthy: _toInt(json['healthy']),
      warning: _toInt(json['warning']),
      unusable: _toInt(json['unusable']),
      quarantined: _toInt(json['quarantined']),
      scrapped: _toInt(json['scrapped']),
      total: _toInt(json['total']),
    );
  }

  int countOf(LotStatus status) {
    switch (status) {
      case LotStatus.healthy:
        return healthy;
      case LotStatus.warning:
        return warning;
      case LotStatus.unusable:
        return unusable;
      case LotStatus.quarantined:
        return quarantined;
      case LotStatus.scrapped:
        return scrapped;
    }
  }
}

/// The result of `GET /inventory/lots/expiring`.
class ExpiringLotsResult {
  final List<LotItem> lots;
  final List<LotBatch> batches;
  final int total;
  final LotSummary summary;

  const ExpiringLotsResult({
    this.lots = const [],
    this.batches = const [],
    this.total = 0,
    this.summary = const LotSummary(),
  });

  factory ExpiringLotsResult.fromJson(Map<String, dynamic> json) {
    final raw = json['lots'];
    final list = raw is List
        ? raw.whereType<Map<String, dynamic>>().toList()
        : const <Map<String, dynamic>>[];
    // The endpoint returns either a flat list of lot items or, with groupBy=lot, a list of batches.
    final isBatched = list.isNotEmpty && list.first['items'] is List;
    return ExpiringLotsResult(
      lots: isBatched
          ? const <LotItem>[]
          : list.map(LotItem.fromJson).toList(),
      batches: isBatched
          ? list.map(LotBatch.fromJson).toList()
          : const <LotBatch>[],
      total: _toInt(json['total']),
      summary: LotSummary.fromJson(
        (json['summary'] as Map<String, dynamic>?) ?? const {},
      ),
    );
  }
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
