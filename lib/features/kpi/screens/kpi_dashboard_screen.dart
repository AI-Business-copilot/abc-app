import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:abc_app/core/theme/app_theme.dart';
import 'package:abc_app/features/auth/widgets/abc_logo.dart';
import '../models/kpi_model.dart';
import '../services/kpi_service.dart';

class KpiDashboardScreen extends StatefulWidget {
  const KpiDashboardScreen({super.key});

  @override
  State<KpiDashboardScreen> createState() => _KpiDashboardScreenState();
}

class _KpiDashboardScreenState extends State<KpiDashboardScreen> {
  final _kpiService = KpiService();
  final _currency = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
  DashboardKpi? _kpi;
  bool _isLoading = false;

  // 1. Bộ lọc kỳ thời gian (dạng thanh trượt ngang pill, không dùng dropdown)
  String _selectedPeriod = 'this_quarter';
  final List<Map<String, String>> _periodOptions = const [
    {'id': 'today', 'label': 'Hôm nay'},
    {'id': 'this_week', 'label': 'Tuần này'},
    {'id': 'this_month', 'label': 'Tháng này'},
    {'id': 'this_quarter', 'label': 'Quý này (Q4)'},
    {'id': 'this_year', 'label': 'Năm nay'},
    {'id': 'season', 'label': 'Mùa vụ'},
    {'id': 'custom', 'label': 'Tùy chọn'},
  ];

  // 2. Bộ lọc Tồn kho nhiều nhất: 'variant' | 'category' | 'template' | 'cogs'
  String _inventoryFilter = 'variant';

  // 3. Bộ lọc Top sản phẩm bán chạy: 'revenue' | 'quantity' | 'orders'
  String _topProductsFilter = 'revenue';

  @override
  void initState() {
    super.initState();
    _loadMetrics();
  }

  Future<void> _loadMetrics() async {
    setState(() => _isLoading = true);
    final data = await _kpiService.getDashboardMetrics();
    if (mounted) {
      setState(() {
        _kpi = data;
        _isLoading = false;
      });
    }
  }

  String get _currentPeriodLabel {
    return _periodOptions.firstWhere(
      (opt) => opt['id'] == _selectedPeriod,
      orElse: () => {'label': 'Quý này (Q4)'},
    )['label']!;
  }

  bool get _isDaily => _selectedPeriod == 'today';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: _isLoading && _kpi == null
            ? const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.accent,
                ),
              )
            : RefreshIndicator(
                onRefresh: _loadMetrics,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. Header: DUY NHẤT 1 LOGO ABC TRÊN MÀN HÌNH + Bell thông báo
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const AbcLogo(size: 26),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                const Icon(Icons.notifications_none_rounded, size: 26, color: Color(0xFF0F172A)),
                                Positioned(
                                  right: 1,
                                  top: 1,
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFC1121F),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 1.5),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            onPressed: () {},
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // 2. Tiêu đề Dashboard chữ lớn, đậm nét
                      const Text(
                        'Dashboard',
                        style: TextStyle(
                          fontFamily: 'serif',
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.6,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 3. Bộ lọc thời gian: THANH TRƯỢT NGANG CÁC PILL (Không dùng dropdown)
                      SizedBox(
                        height: 38,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _periodOptions.length,
                          separatorBuilder: (context, index) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final opt = _periodOptions[index];
                            final active = opt['id'] == _selectedPeriod;
                            return GestureDetector(
                              onTap: () => setState(() => _selectedPeriod = opt['id']!),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: active ? const Color(0xFF0F4C3A) : Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: active ? const Color(0xFF0F4C3A) : const Color(0xFFE2E8F0),
                                    width: 1.2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: active ? const Color(0x260F4C3A) : const Color(0x06000000),
                                      blurRadius: active ? 6 : 3,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    opt['label']!,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                                      color: active ? Colors.white : const Color(0xFF475569),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Dải thời gian thực tế
                      Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 7),
                          Text(
                            _isDaily
                                ? '00:00 - 23:59 • Hôm nay (13/11/2026)'
                                : 'Toàn thời gian kỳ: $_currentPeriodLabel',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // 4. Lưới 4 Thẻ chỉ số tổng quan (2x2 Grid đều đặn, Tổng doanh thu full width cột)
                      _buildSummaryKpiGrid(),
                      const SizedBox(height: 16),

                      // 5. Biểu đồ: Doanh thu theo giờ (hoặc theo ngày)
                      _buildRevenueBarChartCard(),
                      const SizedBox(height: 16),

                      // 6. Section: Đơn mua hàng NCC (PO)
                      _buildPurchaseOrdersCard(),
                      const SizedBox(height: 16),

                      // 7. Section: Tỷ trọng doanh thu theo biến thể (Donut Chart)
                      _buildDonutVariantCard(),
                      const SizedBox(height: 16),

                      // 8. Section: Tồn kho nhiều nhất (Tabs: biến thể, danh mục, mẫu cha, giá vốn)
                      _buildTopInventoryCard(),
                      const SizedBox(height: 16),

                      // 9. Section: Top sản phẩm bán chạy (Tabs: Doanh thu, Số lượng, Lượt đặt)
                      _buildTopSellingCard(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  // 4 Thẻ chỉ số tổng quan: Cân bằng kích thước chiều ngang 100% bằng CrossAxisAlignment.stretch
  Widget _buildSummaryKpiGrid() {
    final revenue = _kpi?.todayRevenue != null && _kpi!.todayRevenue > 0
        ? _kpi!.todayRevenue
        : 28450000.0;
    final orders = _kpi?.todayOrderCount != null && _kpi!.todayOrderCount > 0
        ? _kpi!.todayOrderCount
        : 86;
    final aov = orders > 0 ? (revenue / orders).round() : 330000;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cột trái: Thẻ 1 & Thẻ 3
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Thẻ 1: Tổng doanh thu (Chiều ngang đồng nhất hoàn toàn với các ô khác)
              _buildCardContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tổng doanh thu',
                      style: TextStyle(fontSize: 13.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _currency.format(revenue),
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        '114% chỉ tiêu',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF047857)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Thẻ 3: Đổi trả (Tiền hoàn dùng pill xám mềm, không bọc đỏ chói)
              _buildCardContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Đổi trả',
                      style: TextStyle(fontSize: 13.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: const [
                        Text('03', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFFC1121F))),
                        SizedBox(width: 4),
                        Text('đơn trả', style: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('Tiền hoàn: ', style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9), // Pill xám nhạt nhẹ nhàng, không bọc đỏ
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            '-1.07M',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF334155)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),

        // Cột phải: Thẻ 2 & Thẻ 4
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Thẻ 2: Hóa đơn hoàn tất
              _buildCardContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Hóa đơn hoàn tất',
                      style: TextStyle(fontSize: 13.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text('$orders', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                        const SizedBox(width: 4),
                        const Text('đơn', style: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('AOV: ', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
                        Text(
                          _currency.format(aov),
                          style: const TextStyle(fontSize: 12.5, color: Color(0xFF1E293B), fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Thẻ 4: Sản phẩm đã bán
              _buildCardContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Sản phẩm đã bán',
                      style: TextStyle(fontSize: 13.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text('142', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                        SizedBox(width: 4),
                        Text('sp', style: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text('Xuất quầy & online', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Section Biểu đồ: Doanh thu theo giờ (theo ngày) hoặc theo ngày (theo tháng/quý/năm)
  Widget _buildRevenueBarChartCard() {
    final bars = _isDaily
        ? [
            {'label': '08h', 'val': 0.22, 'isPeak': false},
            {'label': '10h', 'val': 0.35, 'isPeak': false},
            {'label': '12h', 'val': 0.60, 'isPeak': false},
            {'label': '14h', 'val': 0.28, 'isPeak': false},
            {'label': '16h', 'val': 0.40, 'isPeak': false},
            {'label': '18h', 'val': 0.72, 'isPeak': false},
            {'label': '20h', 'val': 0.90, 'isPeak': true},
            {'label': '22h', 'val': 0.50, 'isPeak': false},
          ]
        : [
            {'label': '01', 'val': 0.30, 'isPeak': false},
            {'label': '05', 'val': 0.45, 'isPeak': false},
            {'label': '10', 'val': 0.65, 'isPeak': false},
            {'label': '15', 'val': 0.92, 'isPeak': true},
            {'label': '20', 'val': 0.55, 'isPeak': false},
            {'label': '25', 'val': 0.42, 'isPeak': false},
            {'label': '28', 'val': 0.78, 'isPeak': false},
            {'label': '30', 'val': 0.62, 'isPeak': false},
          ];

    return _buildCardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.bar_chart_rounded, size: 20, color: Color(0xFF0F4C3A)),
                  const SizedBox(width: 7),
                  Text(
                    _isDaily ? 'Doanh thu theo giờ' : 'Doanh thu theo ngày',
                    style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _isDaily ? 'Hôm nay' : _currentPeriodLabel,
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            _isDaily ? 'Đỉnh điểm lúc 20:00 (Buổi tối)' : 'Đỉnh điểm ngày 15 (Giữa kỳ)',
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 14),

          // Tooltip nổi trên đỉnh cột cao nhất
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [BoxShadow(color: Color(0x24000000), blurRadius: 8, offset: Offset(0, 2))],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF34D399), shape: BoxShape.circle)),
                  const SizedBox(width: 7),
                  Text(
                    _isDaily ? 'Đỉnh 20:00: 6.850.000 đ (22 đơn)' : 'Đỉnh ngày 15: 8.450.000 đ (31 đơn)',
                    style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Khung biểu đồ cột
          SizedBox(
            height: 125,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: bars.map((b) {
                final isPeak = b['isPeak'] as bool;
                final height = 95.0 * (b['val'] as double);
                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      width: 24,
                      height: height,
                      decoration: BoxDecoration(
                        color: isPeak ? const Color(0xFF0F4C3A) : const Color(0xFF86EFAC),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      b['label'] as String,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isPeak ? FontWeight.w900 : FontWeight.w600,
                        color: isPeak ? const Color(0xFF0F4C3A) : const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // Section: Đơn mua hàng NCC (PO)
  Widget _buildPurchaseOrdersCard() {
    return _buildCardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.local_shipping_outlined, size: 20, color: Color(0xFF0D9488)),
                  SizedBox(width: 7),
                  Text('Đơn mua hàng NCC (PO)', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFCCFBF1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('4 phiếu', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: Color(0xFF0F766E))),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 3 Dòng trạng thái
          _buildPoRow(
            dotColor: const Color(0xFFB45309),
            title: '2 Đơn chờ giao từ NCC',
            rightWidget: const Text('124.000.000 đ', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
          ),
          const SizedBox(height: 8),
          _buildPoRow(
            dotColor: const Color(0xFFDC2626),
            title: '1 Đang kiểm đếm',
          ),
          const SizedBox(height: 8),
          _buildPoRow(
            dotColor: const Color(0xFF16A34A),
            title: '1 Đã hoàn tất nhập kho sáng nay',
            rightWidget: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
              decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(6)),
              child: const Text('Đạt 100% SKU', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF15803D))),
            ),
          ),
          const SizedBox(height: 14),

          // Nút liên kết theo dõi chi tiết
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text(
                'Theo dõi chi tiết 4 đơn PO  ➔',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF334155)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPoRow({required Color dotColor, required String title, Widget? rightWidget}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(width: 7, height: 7, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
              const SizedBox(width: 9),
              Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
            ],
          ),
          ?rightWidget,
        ],
      ),
    );
  }

  // Section: Tỷ trọng doanh thu theo biến thể (Donut Chart)
  Widget _buildDonutVariantCard() {
    return _buildCardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.pie_chart_outline_rounded, size: 20, color: Color(0xFF0F4C3A)),
              SizedBox(width: 7),
              Text('Tỷ trọng doanh thu theo biến thể', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
            ],
          ),
          const SizedBox(height: 18),

          // Donut Chart: Không ghi doanh thu thuần, chỉ ghi TỔNG và 28.45M
          Center(
            child: SizedBox(
              width: 150,
              height: 150,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(150, 150),
                    painter: _DonutChartPainter(),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text('TỔNG', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8), letterSpacing: 1.0)),
                      SizedBox(height: 2),
                      Text('28.45M', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),

          // 2x2 Grid Chú thích bên dưới
          Row(
            children: [
              Expanded(
                child: _buildLegendItem(
                  color: const Color(0xFF0F4C3A),
                  title: 'Polo Pima Navy-L',
                  subtitle: '42% • 11.95M',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildLegendItem(
                  color: const Color(0xFF10B981),
                  title: 'Serum B5 30ml Std',
                  subtitle: '28% • 7.96M',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildLegendItem(
                  color: const Color(0xFFC1121F),
                  title: 'Quần Tây Đen-31',
                  subtitle: '18% • 5.12M',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildLegendItem(
                  color: const Color(0xFFB45309),
                  title: 'Biến thể khác',
                  subtitle: '12% • 3.42M',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem({required Color color, required String title, required String subtitle}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)), overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Section: Tồn kho nhiều nhất (Tabs: biến thể, danh mục, mẫu cha, giá vốn)
  Widget _buildTopInventoryCard() {
    final items = {
      'variant': [
        {'name': 'Áo Polo Pima Cotton (Navy / L)', 'parent': 'Áo Polo Nam', 'category': 'Thời trang', 'qty': '340 cái', 'cogs': '61.2tr', 'pct': 0.85},
        {'name': 'Serum B5 Phục Hồi (30ml Std)', 'parent': 'Serum B5', 'category': 'Mỹ phẩm', 'qty': '280 chai', 'cogs': '21.0tr', 'pct': 0.70},
        {'name': 'Quần Tây Slimfit Form Ý (Đen / 31)', 'parent': 'Quần Tây Công Sở', 'category': 'Thời trang', 'qty': '195 cái', 'cogs': '46.8tr', 'pct': 0.50},
      ],
      'category': [
        {'name': 'Thời trang & Phụ kiện', 'parent': 'Nhóm chính', 'category': 'Quần áo nam nữ', 'qty': '1.450 cái', 'cogs': '182.4tr', 'pct': 0.90},
        {'name': 'Mỹ phẩm & Chăm sóc da', 'parent': 'Nhóm chính', 'category': 'Skincare chính hãng', 'qty': '890 chai', 'cogs': '76.5tr', 'pct': 0.65},
        {'name': 'Hóa mỹ phẩm & Tiêu dùng', 'parent': 'Nhóm chính', 'category': 'Hàng gia dụng', 'qty': '420 cái', 'cogs': '35.1tr', 'pct': 0.40},
      ],
      'template': [
        {'name': 'Áo Polo Nam Cổ Bẻ Cao Cấp', 'parent': '4 Biến thể', 'category': 'Thời trang', 'qty': '580 cái', 'cogs': '98.5tr', 'pct': 0.82},
        {'name': 'Serum Dưỡng Ẩm B5 Phục Hồi', 'parent': '2 Biến thể', 'category': 'Mỹ phẩm', 'qty': '390 chai', 'cogs': '31.2tr', 'pct': 0.60},
        {'name': 'Quần Tây Nam Slimfit Co Giãn', 'parent': '6 Biến thể', 'category': 'Thời trang', 'qty': '310 cái', 'cogs': '68.4tr', 'pct': 0.48},
      ],
      'cogs': [
        {'name': 'Áo Polo Pima Cotton (Navy / L)', 'parent': 'Áo Polo Nam', 'category': 'Thời trang', 'qty': '340 cái', 'cogs': '61.200.000 đ', 'pct': 0.88},
        {'name': 'Quần Tây Slimfit Form Ý (Đen / 31)', 'parent': 'Quần Tây Công Sở', 'category': 'Thời trang', 'qty': '195 cái', 'cogs': '46.800.000 đ', 'pct': 0.72},
        {'name': 'Serum B5 Phục Hồi (30ml Std)', 'parent': 'Serum B5', 'category': 'Mỹ phẩm', 'qty': '280 chai', 'cogs': '21.000.000 đ', 'pct': 0.45},
      ],
    }[_inventoryFilter]!;

    return _buildCardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.inventory_2_outlined, size: 20, color: Color(0xFF0F4C3A)),
              SizedBox(width: 7),
              Text('Tồn kho nhiều nhất', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
            ],
          ),
          const SizedBox(height: 12),

          // 4 Filter Pills: SKU Biến thể, Danh mục, Mẫu cha (Template), Giá vốn
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterPill('variant', 'SKU Biến thể'),
                const SizedBox(width: 8),
                _buildFilterPill('category', 'Danh mục'),
                const SizedBox(width: 8),
                _buildFilterPill('template', 'Mẫu cha (Template)'),
                const SizedBox(width: 8),
                _buildFilterPill('cogs', 'Giá vốn'),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Danh sách các mục có progress bar
          ...items.map((it) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          it['name'] as String,
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(it['qty'] as String, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: Color(0xFF0F4C3A))),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Kế bên tên mẫu cha là tên danh mục
                      Text(
                        'Mẫu cha: ${it['parent']} • ${it['category']}',
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                      ),
                      Text('Vốn: ${it['cogs']}', style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: LinearProgressIndicator(
                      value: it['pct'] as double,
                      minHeight: 5.5,
                      backgroundColor: const Color(0xFFF1F5F9),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0F4C3A)),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFilterPill(String id, String label) {
    final active = _inventoryFilter == id;
    return GestureDetector(
      onTap: () => setState(() => _inventoryFilter = id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF0F4C3A) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: active ? FontWeight.w800 : FontWeight.w600,
            color: active ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  // Section: Top sản phẩm bán chạy (Tabs: Doanh thu, Số lượng, Lượt đặt)
  Widget _buildTopSellingCard() {
    return _buildCardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Row(
                children: [
                  Icon(Icons.emoji_events_outlined, size: 20, color: Color(0xFFD97706)),
                  SizedBox(width: 7),
                  Text('Top sản phẩm bán chạy', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                ],
              ),
              Text('Tất cả (28)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F4C3A))),
            ],
          ),
          const SizedBox(height: 12),

          // 3 Tabs: Doanh thu | Số lượng | Lượt đặt
          Container(
            padding: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                _buildSubTab('revenue', 'Doanh thu'),
                _buildSubTab('quantity', 'Số lượng'),
                _buildSubTab('orders', 'Lượt đặt'),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Danh sách #1, #2, #3
          _buildRankItem(
            rank: '#1',
            rankColor: const Color(0xFFFEF3C7),
            rankTextColor: const Color(0xFF92400E),
            name: 'Áo Polo Pima Cotton Cao Cấp',
            sub: '48 lượt bán • 34 sản phẩm',
            revenue: '11.950.000 đ',
            hasBadge: true,
          ),
          const SizedBox(height: 9),
          _buildRankItem(
            rank: '#2',
            rankColor: const Color(0xFFF1F5F9),
            rankTextColor: const Color(0xFF475569),
            name: 'Serum Dưỡng Ẩm Phục Hồi B5',
            sub: '32 lượt bán • 28 chai',
            revenue: '7.900.000 đ',
          ),
          const SizedBox(height: 9),
          _buildRankItem(
            rank: '#3',
            rankColor: const Color(0xFFFFEDD5),
            rankTextColor: const Color(0xFF9A3412),
            name: 'Quần Tây Nam Slimfit Co Giãn',
            sub: '24 lượt bán • 19 sản phẩm',
            revenue: '5.120.000 đ',
          ),
        ],
      ),
    );
  }

  Widget _buildSubTab(String id, String label) {
    final active = _topProductsFilter == id;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _topProductsFilter = id),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: active ? const [BoxShadow(color: Color(0x0A000000), blurRadius: 4)] : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                color: active ? const Color(0xFF0F172A) : const Color(0xFF64748B),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRankItem({
    required String rank,
    required Color rankColor,
    required Color rankTextColor,
    required String name,
    required String sub,
    required String revenue,
    bool hasBadge = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(color: rankColor, shape: BoxShape.circle),
            child: Center(
              child: Text(
                rank,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: rankTextColor),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text('img', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(sub, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                const SizedBox(height: 2),
                Text(
                  revenue,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: Color(0xFF0F4C3A)),
                ),
              ],
            ),
          ),
          if (hasBadge)
            const Icon(Icons.verified_rounded, size: 18, color: Color(0xFF0F766E)),
        ],
      ),
    );
  }

  Widget _buildCardContainer({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: child,
    );
  }
}

/// Painter vẽ Donut Chart 4 lát màu
class _DonutChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    const strokeWidth = 20.0;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    // 42% Forest Green
    paint.color = const Color(0xFF0F4C3A);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * 0.42,
      false,
      paint,
    );

    // 28% Mint Green
    paint.color = const Color(0xFF10B981);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2 + 2 * math.pi * 0.42,
      2 * math.pi * 0.28,
      false,
      paint,
    );

    // 18% Crimson Red
    paint.color = const Color(0xFFC1121F);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2 + 2 * math.pi * 0.70,
      2 * math.pi * 0.18,
      false,
      paint,
    );

    // 12% Amber Brown
    paint.color = const Color(0xFFB45309);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2 + 2 * math.pi * 0.88,
      2 * math.pi * 0.12,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
