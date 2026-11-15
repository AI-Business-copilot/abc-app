import 'package:abc_app/core/network/api_client.dart';
import 'package:abc_app/features/alerts/models/alert_models.dart';
import 'package:abc_app/features/products/services/products_service.dart';

class AlertsService {
  final _dio = ApiClient().dio;
  final _productsService = ProductsService();

  Future<List<LotAlertItem>> getExpiringLots() async {
    try {
      final response = await _dio.get('/inventory/lots/expiring');
      final data = response.data;
      if (data is List) {
        return data.map((item) => LotAlertItem.fromJson(item as Map<String, dynamic>)).toList();
      } else if (data is Map<String, dynamic> && data['data'] is List) {
        return (data['data'] as List)
            .map((item) => LotAlertItem.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<List<LowStockAlertItem>> getLowStockItems({int threshold = 10}) async {
    try {
      final products = await _productsService.getProducts();
      final List<LowStockAlertItem> lowStockList = [];

      for (final p in products) {
        for (final v in p.variants) {
          if (v.totalOnHand <= threshold) {
            lowStockList.add(
              LowStockAlertItem(
                productId: p.id,
                productName: p.name,
                sku: v.sku,
                variantTitle: v.title.isNotEmpty ? v.title : 'Mặc định',
                currentStock: v.totalOnHand,
                minStockThreshold: threshold,
              ),
            );
          }
        }
      }
      return lowStockList;
    } catch (_) {
      return [];
    }
  }
}
