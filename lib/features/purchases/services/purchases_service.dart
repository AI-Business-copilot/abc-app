import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:abc_app/core/network/api_client.dart';
import '../models/purchase_models.dart';

/// API mua hàng: /purchases/... qua ApiClient (baseUrl đã có /api).
/// Backend áp dụng requireSupabaseIdentity → requireBusinessScope →
/// inventory.read + finance.read; ghi cần thêm inventory.receive.
class PurchasesService {
  final _dio = ApiClient().dio;

  Future<List<Supplier>> getSuppliers({String? search}) async {
    final response = await _dio.get(
      '/purchases/suppliers',
      queryParameters: {
        'isActive': 'true',
        'pageSize': 100,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      },
    );
    final data = response.data;
    if (data is Map<String, dynamic>) {
      final items = data['items'] is List ? data['items'] as List : const [];
      return items
          .whereType<Map<String, dynamic>>()
          .map((e) => Supplier.fromJson(e))
          .toList();
    }
    return const [];
  }

  /// Danh mục SKU đang cung cấp — backend chỉ nhận các SKU này khi tạo PO.
  Future<List<SupplierProduct>> getSupplierProducts(
    String supplierId, {
    String? search,
  }) async {
    final response = await _dio.get(
      '/purchases/suppliers/$supplierId/products',
      queryParameters: {
        'kind': 'catalog',
        'isActive': 'true',
        'pageSize': 100,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      },
    );
    final data = response.data;
    if (data is Map<String, dynamic>) {
      final items = data['items'] is List ? data['items'] as List : const [];
      return items
          .whereType<Map<String, dynamic>>()
          .map((e) => SupplierProduct.fromJson(e))
          .toList();
    }
    return const [];
  }

  Future<PurchaseOrderPage> getOrders({
    String? search,
    String? status,
    DateTime? from,
    DateTime? to,
    int page = 1,
    int pageSize = 20,
  }) async {
    final day = DateFormat('yyyy-MM-dd');
    final response = await _dio.get(
      '/purchases/orders',
      queryParameters: {
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        if (status != null && status.isNotEmpty) 'status': status,
        if (from != null) 'from': day.format(from),
        if (to != null) 'to': day.format(to),
        'page': page,
        'pageSize': pageSize,
      },
    );
    final data = response.data;
    if (data is Map<String, dynamic>) return PurchaseOrderPage.fromJson(data);
    return PurchaseOrderPage(
      items: const [],
      page: page,
      pageSize: pageSize,
      total: 0,
      totalPages: 1,
    );
  }

  Future<PurchaseOrder> getOrder(String id) async {
    final response = await _dio.get('/purchases/orders/$id');
    final data = response.data;
    if (data is Map<String, dynamic>) return PurchaseOrder.fromJson(data);
    throw const FormatException('Phản hồi đơn đặt hàng không hợp lệ.');
  }

  /// Tạo PO. Không gửi orderDate để backend tự lấy ngày Việt Nam,
  /// tránh lệch múi giờ khi thiết bị ở múi khác.
  Future<PurchaseOrder> createOrder({
    required String code,
    required String supplierId,
    required DateTime expectedDeliveryDate,
    required List<Map<String, dynamic>> items,
  }) async {
    final response = await _dio.post(
      '/purchases/orders',
      data: {
        'poCode': code.trim(),
        'supplierId': supplierId,
        'expectedDeliveryDate': DateFormat('yyyy-MM-dd').format(expectedDeliveryDate),
        'items': items,
      },
    );
    final data = response.data;
    if (data is Map<String, dynamic>) return PurchaseOrder.fromJson(data);
    throw const FormatException('Không đọc được đơn đặt hàng vừa tạo.');
  }

  /// Thông báo lỗi ưu tiên lấy field "error" từ response backend.
  String messageOf(Object error) {
    if (error is DioException && error.response?.data is Map<String, dynamic>) {
      final body = error.response!.data as Map<String, dynamic>;
      final message = body['error']?.toString();
      if (message != null && message.isNotEmpty) return message;
    }
    return purchaseErrorMessage(error);
  }
}
