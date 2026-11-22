class DashboardKpi {
  final double todayRevenue;
  final int todayOrderCount;
  final int totalProducts;
  final int totalLowStockCount;
  final int totalExpiringLotsCount;

  DashboardKpi({
    required this.todayRevenue,
    required this.todayOrderCount,
    required this.totalProducts,
    required this.totalLowStockCount,
    required this.totalExpiringLotsCount,
  });
}
