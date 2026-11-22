import 'dart:async';
import '../../kpi/services/kpi_service.dart';
import 'package:intl/intl.dart';

class AiAdvisorService {
  final _kpiService = KpiService();
  final _currency = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

  Future<String> askAdvisor(String query) async {
    final lower = query.toLowerCase();
    final kpi = await _kpiService.getDashboardMetrics();

    // Grounded rule-based response matching committed scope (no fabricated numbers)
    if (lower.contains('doanh thu') || lower.contains('bán') || lower.contains('tiền')) {
      return 'Theo số liệu thực tế từ hệ thống POS, tổng doanh thu ghi nhận hiện tại là ${_currency.format(kpi.todayRevenue)} với tổng cộng ${kpi.todayOrderCount} đơn hàng.';
    } else if (lower.contains('tồn') || lower.contains('kho') || lower.contains('hàng')) {
      return 'Hệ thống hiện quản lý ${kpi.totalProducts} mặt hàng. Trong đó có ${kpi.totalLowStockCount} biến thể chạm ngưỡng tồn kho tối thiểu cần chú ý nhập thêm.';
    } else if (lower.contains('hạn') || lower.contains('date') || lower.contains('lô')) {
      return 'Hiện có ${kpi.totalExpiringLotsCount} lô hàng sắp hết hạn hoặc đã quá hạn theo dõi trong kho. Bạn nên kiểm tra tab Cảnh báo để lên kế hoạch xử lý hoặc thanh lý.';
    } else if (lower.contains('nhập hàng') || lower.contains('gợi ý')) {
      return 'Khuyến nghị: Bạn có ${kpi.totalLowStockCount} sản phẩm dưới ngưỡng an toàn. Hãy ưu tiên kiểm tra các mặt hàng này và chuẩn bị đơn đặt hàng NCC trên hệ thống Web.';
    } else {
      return 'Xin chào! Tôi là Trợ lý Kinh doanh ABC Copilot. Dữ liệu thực tế hiện tại: Doanh thu: ${_currency.format(kpi.todayRevenue)} (${kpi.todayOrderCount} đơn), ${kpi.totalProducts} sản phẩm, ${kpi.totalLowStockCount} mặt hàng tồn thấp và ${kpi.totalExpiringLotsCount} lô sắp hết hạn. Bạn cần tôi hỗ trợ chi tiết về nội dung nào?';
    }
  }
}
