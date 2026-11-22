import '../models/kpi_model.dart';
import '../../products/services/products_service.dart';
import '../../alerts/services/alerts_service.dart';
import '../../pos/services/pos_service.dart';

class KpiService {
  final _productsService = ProductsService();
  final _alertsService = AlertsService();
  final _posService = PosService();

  Future<DashboardKpi> getDashboardMetrics() async {
    try {
      final results = await Future.wait([
        _posService.getOrders(),
        _productsService.getProducts(),
        _alertsService.getExpiringLots(),
        _alertsService.getLowStockItems(),
      ]);

      final orders = results[0] as List;
      final products = results[1] as List;
      final expiringLots = results[2] as List;
      final lowStock = results[3] as List;

      double revenue = 0;
      for (final o in orders) {
        if (o.status == 'COMPLETED' || o.paidAmount > 0) {
          revenue += o.paidAmount;
        }
      }

      return DashboardKpi(
        todayRevenue: revenue,
        todayOrderCount: orders.length,
        totalProducts: products.length,
        totalLowStockCount: lowStock.length,
        totalExpiringLotsCount: expiringLots.length,
      );
    } catch (_) {
      return DashboardKpi(
        todayRevenue: 0,
        todayOrderCount: 0,
        totalProducts: 0,
        totalLowStockCount: 0,
        totalExpiringLotsCount: 0,
      );
    }
  }
}
