import 'package:abc_app/core/network/api_client.dart';
import '../models/pos_model.dart';

class PosService {
  final _dio = ApiClient().dio;

  Future<List<PosOrderSummary>> getOrders() async {
    try {
      final res = await _dio.get('/orders');
      final data = res.data;
      final list = (data is List ? data : (data is Map && data['data'] is List ? data['data'] : [])) as List;
      return list.map((e) => PosOrderSummary.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<PosOrderSummary> createOrder({
    required List<CartItem> items,
    String paymentMethod = 'CASH',
  }) async {
    final payload = {
      'items': items.map((i) => {
        'variantId': i.variantId,
        'quantity': i.quantity,
        'unitPrice': i.price,
      }).toList(),
      'paymentMethod': paymentMethod,
    };

    final createRes = await _dio.post('/orders', data: payload);
    final orderData = createRes.data is Map<String, dynamic> && createRes.data['order'] != null
        ? createRes.data['order']
        : createRes.data;

    final orderId = orderData['id']?.toString() ?? '';
    final finalAmount = (orderData['finalAmount'] as num? ?? 0).toDouble();

    // Thanh toán đơn hàng
    if (orderId.isNotEmpty) {
      try {
        await _dio.post('/orders/$orderId/payments', data: {
          'method': paymentMethod,
          'amount': finalAmount,
        });
      } catch (_) {}
    }

    return PosOrderSummary.fromJson(orderData as Map<String, dynamic>);
  }
}
