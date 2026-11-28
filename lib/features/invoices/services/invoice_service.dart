import 'package:intl/intl.dart';
import 'package:abc_app/core/network/api_client.dart';
import '../models/invoice_models.dart';

/// Tra cứu hóa đơn bán lẻ qua API /sales/orders.
/// Backend đã áp dụng requireSupabaseIdentity -> requireBusinessScope
/// -> requirePermission("orders.read"), nên mobile chỉ cần gửi token/businessId
/// qua ApiClient.
class InvoiceService {
  final _dio = ApiClient().dio;

  Future<InvoicePage> getInvoices({
    String? search,
    String? status,
    DateTime? from,
    DateTime? to,
    int page = 1,
    int pageSize = 20,
  }) async {
    final day = DateFormat('yyyy-MM-dd');
    final response = await _dio.get(
      '/sales/orders',
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
    if (data is Map<String, dynamic>) return InvoicePage.fromJson(data);
    return InvoicePage(items: const [], page: page, pageSize: pageSize, total: 0, totalPages: 1);
  }

  /// Chi tiết 1 hóa đơn: items + payments + khách hàng.
  Future<InvoiceOrder> getInvoice(String id) async {
    final response = await _dio.get('/sales/orders/$id');
    final data = response.data;
    if (data is Map<String, dynamic>) return InvoiceOrder.fromJson(data);
    throw const FormatException('Phản hồi hóa đơn không hợp lệ.');
  }
}
