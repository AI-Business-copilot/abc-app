import 'package:abc_app/core/network/api_client.dart';
import 'package:abc_app/features/audits/models/audit_models.dart';

/// Thin Dio wrapper around the F07 stock audit endpoints.
class AuditsService {
  final _dio = ApiClient().dio;

  /// `GET /inventory/audits` — list items do not carry `auditType`.
  Future<({List<StockAudit> audits, PaginationInfo pagination})> listAudits({
    String? status,
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _dio.get(
      '/inventory/audits',
      queryParameters: {
        if (status != null && status.isNotEmpty) 'status': status,
        'page': page,
        'pageSize': pageSize,
      },
    );
    final data = (response.data as Map<String, dynamic>?) ?? const {};
    final items = (data['items'] as List?) ?? const [];
    return (
      audits: items
          .whereType<Map<String, dynamic>>()
          .map(StockAudit.fromJson)
          .toList(),
      pagination: PaginationInfo.fromJson(
        (data['pagination'] as Map<String, dynamic>?) ?? const {},
      ),
    );
  }

  /// `GET /inventory/audits/:id` — the header plus every item.
  Future<StockAudit> getAudit(String auditId) async {
    final response = await _dio.get('/inventory/audits/$auditId');
    return StockAudit.fromJson((response.data as Map<String, dynamic>?) ?? const {});
  }

  /// `GET /inventory/audits/:id/items` — pass `mine` to only get the caller's rows.
  Future<({List<StockAuditItem> items, PaginationInfo pagination})> getAuditItems(
    String auditId, {
    int page = 1,
    int pageSize = 50,
    bool mine = false,
  }) async {
    final response = await _dio.get(
      '/inventory/audits/$auditId/items',
      queryParameters: {
        'page': page,
        'pageSize': pageSize,
        if (mine) 'mine': 'true',
      },
    );
    final data = (response.data as Map<String, dynamic>?) ?? const {};
    final items = (data['items'] as List?) ?? const [];
    return (
      items: items
          .whereType<Map<String, dynamic>>()
          .map(StockAuditItem.fromJson)
          .toList(),
      pagination: PaginationInfo.fromJson(
        (data['pagination'] as Map<String, dynamic>?) ?? const {},
      ),
    );
  }

  /// `GET /inventory/audits/:id/items/:itemId`
  Future<StockAuditItem> getAuditItem(String auditId, String itemId) async {
    final response = await _dio.get('/inventory/audits/$auditId/items/$itemId');
    return StockAuditItem.fromJson((response.data as Map<String, dynamic>?) ?? const {});
  }

  /// `POST /inventory/audits` — the server generates the audit code.
  Future<StockAudit> createAudit({
    required AuditType auditType,
    String? note,
    List<AuditItemAssignment> items = const [],
  }) async {
    final response = await _dio.post(
      '/inventory/audits',
      data: {
        'auditType': auditType.code,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
        if (items.isNotEmpty)
          'items': items.map((item) => item.toJson()).toList(),
      },
    );
    return StockAudit.fromJson((response.data as Map<String, dynamic>?) ?? const {});
  }

  /// `POST /inventory/audits/:id/items/assign` — owner adds rows.
  Future<int> addItems(String auditId, List<AuditItemAssignment> items) async {
    final response = await _dio.post(
      '/inventory/audits/$auditId/items/assign',
      data: {'items': items.map((item) => item.toJson()).toList()},
    );
    final data = (response.data as Map<String, dynamic>?) ?? const {};
    return (data['added'] as num?)?.toInt() ?? items.length;
  }

  /// `PATCH /inventory/audits/:id/items/:itemId/assign` — owner hands a row to another employee.
  Future<StockAuditItem> reassignItem(
    String auditId,
    String itemId,
    String assignedToUserId,
  ) async {
    final response = await _dio.patch(
      '/inventory/audits/$auditId/items/$itemId/assign',
      data: {'assignedToUserId': assignedToUserId},
    );
    return StockAuditItem.fromJson((response.data as Map<String, dynamic>?) ?? const {});
  }

  /// `PATCH /inventory/audits/:id/items/:itemId` — saves the count.
  /// `discrepancyReason` is always required by the server.
  Future<StockAuditItem> updateCount(
    String auditId,
    String itemId, {
    required int countedQty,
    required String discrepancyReason,
    String? lotItemId,
    String? newLotNumber,
    String? newLotExpirationDate,
    String? newLotManufacturingDate,
  }) async {
    final response = await _dio.patch(
      '/inventory/audits/$auditId/items/$itemId',
      data: {
        'countedQty': countedQty,
        'discrepancyReason': discrepancyReason,
        'lotItemId': ?lotItemId,
        'newLotNumber': ?newLotNumber,
        'newLotExpirationDate': ?newLotExpirationDate,
        'newLotManufacturingDate': ?newLotManufacturingDate,
      },
    );
    return StockAuditItem.fromJson((response.data as Map<String, dynamic>?) ?? const {});
  }

  /// `POST /inventory/audits/:id/items/:itemId/submit`
  Future<StockAuditItem> submitItem(String auditId, String itemId) async {
    final response = await _dio.post('/inventory/audits/$auditId/items/$itemId/submit');
    return StockAuditItem.fromJson((response.data as Map<String, dynamic>?) ?? const {});
  }

  /// `PATCH /inventory/audits/:id/items/:itemId/approve`
  Future<ApproveItemResult> approveItem(String auditId, String itemId) async {
    final response = await _dio.patch('/inventory/audits/$auditId/items/$itemId/approve');
    return ApproveItemResult.fromJson((response.data as Map<String, dynamic>?) ?? const {});
  }

  /// `PATCH /inventory/audits/:id/items/:itemId/reject` — sends the row back for a recount.
  Future<StockAuditItem> rejectItem(String auditId, String itemId, String reason) async {
    final response = await _dio.patch(
      '/inventory/audits/$auditId/items/$itemId/reject',
      data: {'reason': reason},
    );
    return StockAuditItem.fromJson((response.data as Map<String, dynamic>?) ?? const {});
  }

  /// `GET /businesses/members` — the owner assigns rows to these people.
  Future<List<StaffMember>> getMembers() async {
    final response = await _dio.get('/businesses/members');
    final data = (response.data as Map<String, dynamic>?) ?? const {};
    final members = (data['members'] as List?) ?? const [];
    return members
        .whereType<Map<String, dynamic>>()
        .map(StaffMember.fromJson)
        .toList();
  }

  /// `GET /products/list` — the product step of the row picker.
  Future<List<AuditProductOption>> getAuditProducts({
    String? search,
    int limit = 60,
  }) async {
    final response = await _dio.get(
      '/products/list',
      queryParameters: {
        if (search != null && search.trim().isNotEmpty) 'q': search.trim(),
        'status': 'active',
        'pageSize': limit,
      },
    );
    final data = (response.data as Map<String, dynamic>?) ?? const {};
    final items = (data['items'] as List?) ?? const [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(AuditProductOption.fromJson)
        .toList();
  }

  /// `GET /products/templates/:id` — the SKUs of one product.
  Future<List<VariantOption>> getProductVariants(String templateId) async {
    final response = await _dio.get('/products/templates/$templateId');
    final data = (response.data as Map<String, dynamic>?) ?? const {};
    final variants = (data['productVariants'] as List?) ?? const [];
    final productName = data['name']?.toString() ?? '';
    return variants
        .whereType<Map<String, dynamic>>()
        .where((variant) => variant['isActive'] != false)
        .map((variant) => VariantOption.fromTemplateJson(variant, productName))
        .toList();
  }

  /// `GET /inventory/variants` — the SKU picker for the row editor.
  Future<List<VariantOption>> getVariants({String? search, int limit = 60}) async {
    final response = await _dio.get(
      '/inventory/variants',
      queryParameters: {
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        'limit': limit,
      },
    );
    final data = (response.data as Map<String, dynamic>?) ?? const {};
    final items = (data['items'] as List?) ?? const [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(VariantOption.fromJson)
        .toList();
  }

  /// `GET /inventory/lots?variantId=` — the existing lots of a SKU.
  Future<List<VariantLot>> getLots(String variantId) async {
    final response = await _dio.get(
      '/inventory/lots',
      queryParameters: {'variantId': variantId},
    );
    final data = (response.data as Map<String, dynamic>?) ?? const {};
    final items = (data['items'] as List?) ?? const [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(VariantLot.fromJson)
        .toList();
  }
}
