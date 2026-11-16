import 'package:abc_app/core/network/api_client.dart';
import 'package:abc_app/features/alerts/models/alert_models.dart';
import 'package:abc_app/features/lots/models/lot_models.dart';
import 'package:abc_app/features/products/services/products_service.dart';

class AlertsService {
  final _dio = ApiClient().dio;
  final _productsService = ProductsService();

  /// The lots that need attention. The endpoint answers `{ lots, total, summary }`.
  /// Without a `status` filter it returns the WARNING, UNUSABLE and QUARANTINED lots.
  Future<ExpiringLotsResult> getExpiringLots() async {
    try {
      final response = await _dio.get(
        '/inventory/lots/expiring',
        queryParameters: {'take': 100},
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return ExpiringLotsResult.fromJson(data);
      }
    } catch (_) {
      // The alerts tab must not break when the lot list cannot be loaded.
    }
    return const ExpiringLotsResult();
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
