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
      backgroundColor: const Color(0xFFF8F9FE),
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
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: const [
                                BoxShadow(color: Color(0x0A000000), blurRadius: 6, offset: Offset(0, 2)),
                              ],
                              border: Border.all(color: const Color(0xFFEDF2F7), width: 1),
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              clipBehavior: Clip.none,
                              children: [
                                const Icon(Icons.notifications_none_rounded, size: 21, color: Color(0xFF0F172A)),
                                Positioned(
                                  right: 9,
                                  top: 8,
                                  child: Container(
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDC2626),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 1.2),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // 2. Tiêu đề Dashboard chữ lớn, đậm nét chuẩn Serif
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

                      // 3. Bộ lọc thời gian: THANH TRƯỢT NGANG CÁC PILL (Kéo trượt qua được)
                      SizedBox(
                        height: 38,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                          itemCount: _periodOptions.length,
                          separatorBuilder: (context, index) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final opt = _periodOptions[index];
                            final active = opt['id'] == _selectedPeriod;
                            return GestureDetector(
                              onTap: () => setState(() => _selectedPeriod = opt['id']!),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: active ? const Color(0xFF065F46) : Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: active ? const Color(0xFF065F46) : const Color(0xFFE2E8F0),
                                    width: 1.2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: active ? const Color(0x26065F46) : const Color(0x06000000),
                                      blurRadius: active ? 6 : 3,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        opt['label']!,
                                        style: TextStyle(
                                          fontFamily: 'serif',
                                          fontSize: 13,
                                          fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                                          color: active ? Colors.white : const Color(0xFF334155),
                                        ),
                                      ),
                                      if (active) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          width: 6,
                                          height: 6,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF34D399),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ],
                                    ],
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
                              color: Color(0xFF34D399),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 7),
                          Text(
                            _isDaily
                                ? '00:00 - 21:30 • Hôm nay (15/11/2026)'
                                : 'Toàn thời gian kỳ: $_currentPeriodLabel',
                            style: const TextStyle(
                              fontFamily: 'serif',
                              fontSize: 12,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
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
    final aov = orders > 0 ? (revenue / orders).round() : 350000;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cột trái: Thẻ 1 & Thẻ 3
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Thẻ 1: Tổng doanh thu
              _buildCardContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tổng doanh thu',
                      style: TextStyle(fontFamily: 'serif', fontSize: 13.5, color: Color(0xFF475569), fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _currency.format(revenue),
                      style: const TextStyle(
                        fontFamily: 'serif',
                        fontSize: 20.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.4,
                      ),
                    ),
                    Container(
                      height: 1,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      color: const Color(0xFFF1F5F9),
                    ),
                    const Text(
                      '114% chỉ tiêu',
                      style: TextStyle(fontFamily: 'serif', fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF059669)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Thẻ 3: Đổi trả (Tiền hoàn dùng pill hồng/đào nhạt theo mockup)
              _buildCardContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Đổi trả',
                      style: TextStyle(fontFamily: 'serif', fontSize: 13.5, color: Color(0xFF475569), fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: const [
                        Text('03', style: TextStyle(fontFamily: 'serif', fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFFDC2626))),
                        SizedBox(width: 4),
                        Text('đơn trả', style: TextStyle(fontFamily: 'serif', fontSize: 12, color: Color(0xFFDC2626), fontWeight: FontWeight.w600)),
                      ],
                    ),
                    Container(
                      height: 1,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      color: const Color(0xFFF1F5F9),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Tiền hoàn:', style: TextStyle(fontFamily: 'serif', fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFE4E6),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            '-1.67M',
                            style: TextStyle(fontFamily: 'serif', fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFFDC2626)),
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
                      style: TextStyle(fontFamily: 'serif', fontSize: 13.5, color: Color(0xFF475569), fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text('$orders', style: const TextStyle(fontFamily: 'serif', fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                        const SizedBox(width: 4),
                        const Text('đơn', style: TextStyle(fontFamily: 'serif', fontSize: 13, color: Color(0xFF475569), fontWeight: FontWeight.w600)),
                      ],
                    ),
                    Container(
                      height: 1,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      color: const Color(0xFFF1F5F9),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('AOV:', style: TextStyle(fontFamily: 'serif', fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                        Text(
                          _currency.format(aov),
                          style: const TextStyle(fontFamily: 'serif', fontSize: 12.5, color: Color(0xFF0F172A), fontWeight: FontWeight.w800),
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
                  children: [
                    const Text(
                      'Sản phẩm đã bán',
                      style: TextStyle(fontFamily: 'serif', fontSize: 13.5, color: Color(0xFF475569), fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: const [
                        Text('142', style: TextStyle(fontFamily: 'serif', fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                        SizedBox(width: 4),
                        Text('sp', style: TextStyle(fontFamily: 'serif', fontSize: 13, color: Color(0xFF475569), fontWeight: FontWeight.w600)),
                      ],
                    ),
                    Container(
                      height: 1,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      color: Colors.transparent,
                    ),
                    const SizedBox(height: 18),
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
                children: const [
                  Icon(Icons.bar_chart_rounded, size: 20, color: Color(0xFF065F46)),
                  SizedBox(width: 7),
                  Text(
                    'Doanh thu theo giờ',
                    style: TextStyle(fontFamily: 'serif', fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
              
            ],
          ),
          const SizedBox(height: 3),
          const Text(
            'Đỉnh điểm lúc 20:00 (Buổi tối)',
            style: TextStyle(fontFamily: 'serif', fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 14),

          // Tooltip nổi trên đỉnh cột cao nhất kèm mũi tên trỏ xuống
          Center(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [BoxShadow(color: Color(0x24000000), blurRadius: 8, offset: Offset(0, 2))],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF34D399), shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Text(
                        _isDaily ? 'Đỉnh 20:00: ' : 'Đỉnh ngày 15: ',
                        style: const TextStyle(fontFamily: 'serif', fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        _isDaily ? '6.850.000 đ' : '8.450.000 đ',
                        style: const TextStyle(fontFamily: 'serif', fontSize: 12, color: Color(0xFF34D399), fontWeight: FontWeight.w900),
                      ),
                      Text(
                        _isDaily ? ' (22 đơn)' : ' (31 đơn)',
                        style: const TextStyle(fontFamily: 'serif', fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                CustomPaint(
                  size: const Size(10, 5),
                  painter: _TrianglePainter(),
                ),
              ],
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
                final isDarkBar = isPeak || b['label'] == '12h' || b['label'] == '18h';
                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      width: 24,
                      height: height,
                      decoration: BoxDecoration(
                        color: isDarkBar ? const Color(0xFF065F46) : const Color(0xFF6EE7B7),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                      ),
                      child: isPeak
                          ? Align(
                              alignment: Alignment.topCenter,
                              child: Container(
                                height: 5,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF86EFAC),
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
                                ),
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      b['label'] as String,
                      style: TextStyle(
                        fontFamily: 'serif',
                        fontSize: 11,
                        fontWeight: isPeak ? FontWeight.w900 : FontWeight.w600,
                        color: isPeak ? const Color(0xFF065F46) : const Color(0xFF64748B),
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

  Widget _buildChartHeaderPill(String periodId, String label) {
    final active = _selectedPeriod == periodId;
    return GestureDetector(
      onTap: () => setState(() => _selectedPeriod = periodId),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF0F4C3A) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: active ? FontWeight.w800 : FontWeight.w600,
            color: active ? Colors.white : const Color(0xFF475569),
          ),
        ),
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
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.local_shipping_outlined, size: 18, color: Color(0xFF065F46)),
                  ),
                  const SizedBox(width: 9),
                  const Text(
                    'Đơn mua hàng NCC (PO)',
                    style: TextStyle(fontFamily: 'serif', fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('4 phiếu', style: TextStyle(fontFamily: 'serif', fontSize: 11.5, fontWeight: FontWeight.w900, color: Color(0xFF15803D))),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 3 Dòng trạng thái (bo góc mềm mại nền xám/xanh nhạt)
          _buildPoRow(
            dotColor: const Color(0xFFB45309),
            title: '2 Đơn chờ giao từ NCC',
            rightWidget: const Text('124.000.000 đ', style: TextStyle(fontFamily: 'serif', fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF92400E))),
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
            rightWidget: const Text('Đủ 100% SKU', style: TextStyle(fontFamily: 'serif', fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF15803D))),
          ),
          const SizedBox(height: 14),

          // Nút liên kết theo dõi chi tiết
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text(
                'Theo dõi chi tiết 4 đơn PO  ➔',
                style: TextStyle(fontFamily: 'serif', fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF065F46)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPoRow({required Color dotColor, required String title, Widget? rightWidget}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6FC),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(width: 7, height: 7, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
              const SizedBox(width: 9),
              Text(title, style: const TextStyle(fontFamily: 'serif', fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
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
              Icon(Icons.pie_chart_outline_rounded, size: 20, color: Color(0xFF065F46)),
              SizedBox(width: 7),
              Text(
                'Tỷ trọng doanh thu theo biến thể',
                style: TextStyle(fontFamily: 'serif', fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Donut Chart: Có TỔNG, 28.45M và 100% Thuần ở tâm
          Center(
            child: SizedBox(
              width: 155,
              height: 155,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(155, 155),
                    painter: _DonutChartPainter(),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text('TỔNG', style: TextStyle(fontFamily: 'serif', fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.8)),
                      SizedBox(height: 2),
                      Text('28.45M', style: TextStyle(fontFamily: 'serif', fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                      SizedBox(height: 2),
                      Text('100% Thuần', style: TextStyle(fontFamily: 'serif', fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF065F46))),
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
                  color: const Color(0xFF065F46),
                  title: 'Polo Pima Navy-L',
                  subtitle: '42% • 11.950k',
                  isAccent: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildLegendItem(
                  color: const Color(0xFF6EE7B7),
                  title: 'Serum B5 30ml Std',
                  subtitle: '28% • 7.960k',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildLegendItem(
                  color: const Color(0xFFDC2626),
                  title: 'Quần Tây Đen-31',
                  subtitle: '18% • 5.120k',
                  isRed: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildLegendItem(
                  color: const Color(0xFFB45309),
                  title: 'Biến thể khác',
                  subtitle: '12% • 3.420k',
                  isAmber: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem({
    required Color color,
    required String title,
    required String subtitle,
    bool isAccent = false,
    bool isRed = false,
    bool isAmber = false,
  }) {
    Color subColor = const Color(0xFF64748B);
    if (isAccent) subColor = const Color(0xFF065F46);
    if (isRed) subColor = const Color(0xFFDC2626);
    if (isAmber) subColor = const Color(0xFFB45309);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: const Color(0xFFF4F6FC), borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontFamily: 'serif', fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)), overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontFamily: 'serif', fontSize: 11, color: subColor, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Section: Tồn kho nhiều nhất (Tabs: biến thể, danh mục, mẫu cha, giá vốn, kéo trượt qua được)
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
      'low_stock': [
        {'name': 'Áo Sơ Mi Trắng Oxford (M)', 'parent': 'Sơ Mi Nam', 'category': 'Thời trang', 'qty': '12 cái', 'cogs': '2.400.000 đ', 'pct': 0.15},
        {'name': 'Kem Dưỡng Ẩm Ceramide (50ml)', 'parent': 'Kem Dưỡng', 'category': 'Mỹ phẩm', 'qty': '8 hũ', 'cogs': '1.800.000 đ', 'pct': 0.10},
        {'name': 'Cà vạt Lụa Cao Cấp (Navy)', 'parent': 'Phụ kiện', 'category': 'Thời trang', 'qty': '5 cái', 'cogs': '950.000 đ', 'pct': 0.08},
      ],
      'restocking': [
        {'name': 'Áo Thun Basic Cotton 220gsm', 'parent': 'Áo Thun Nam', 'category': 'Thời trang', 'qty': '500 cái', 'cogs': '45.000.000 đ', 'pct': 0.95},
        {'name': 'Tẩy Trang Rau Má (150ml)', 'parent': 'Tẩy Trang', 'category': 'Mỹ phẩm', 'qty': '350 chai', 'cogs': '38.500.000 đ', 'pct': 0.75},
        {'name': 'Quần Kaki Ống Đứng', 'parent': 'Quần Nam', 'category': 'Thời trang', 'qty': '220 cái', 'cogs': '33.000.000 đ', 'pct': 0.55},
      ],
    }[_inventoryFilter] ?? [
      {'name': 'Áo Polo Pima Cotton (Navy / L)', 'parent': 'Áo Polo Nam', 'category': 'Thời trang', 'qty': '340 cái', 'cogs': '61.2tr', 'pct': 0.85},
    ];

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

          // Filter Pills: Kéo trượt ngang mượt mà (Horizontal Scrollable)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            child: Row(
              children: [
                _buildFilterPill('variant', 'SKU Biến thể'),
                const SizedBox(width: 8),
                _buildFilterPill('category', 'Danh mục'),
                const SizedBox(width: 8),
                _buildFilterPill('template', 'Mẫu cha (Template)'),
                const SizedBox(width: 8),
                _buildFilterPill('cogs', 'Giá vốn'),
                const SizedBox(width: 8),
                _buildFilterPill('low_stock', 'Sắp hết hàng'),
                const SizedBox(width: 8),
                _buildFilterPill('restocking', 'Đang nhập hàng'),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Danh sách các mục có progress bar (Mỗi mục là một Container bo góc nền xám nhạt theo mockup)
          ...items.map((it) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10.0),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F6FC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          it['name'] as String,
                          style: const TextStyle(fontFamily: 'serif', fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(it['qty'] as String, style: const TextStyle(fontFamily: 'serif', fontSize: 13.5, fontWeight: FontWeight.w900, color: Color(0xFF065F46))),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Mẫu cha: ${it['parent']} • ${it['category']}',
                        style: const TextStyle(fontFamily: 'serif', fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                      ),
                      Text('Vốn: ${it['cogs']}', style: const TextStyle(fontFamily: 'serif', fontSize: 11.5, color: Color(0xFF475569), fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: it['pct'] as double,
                      minHeight: 6,
                      backgroundColor: const Color(0xFFE2E8F0),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF065F46)),
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF065F46) : const Color(0xFFEEF2FF),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'serif',
            fontSize: 12,
            fontWeight: active ? FontWeight.w800 : FontWeight.w600,
            color: active ? Colors.white : const Color(0xFF334155),
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
                  Text('Top sản phẩm bán chạy', style: TextStyle(fontFamily: 'serif', fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                ],
              ),
              Text('Tất cả (28)', style: TextStyle(fontFamily: 'serif', fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF065F46))),
            ],
          ),
          const SizedBox(height: 12),

          // Tabs lọc: Doanh thu | Số lượng | Lượt đặt | Lợi nhuận | Tỷ lệ hoàn (Kéo trượt ngang qua được)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  _buildSubTab('revenue', 'Doanh thu'),
                  const SizedBox(width: 4),
                  _buildSubTab('quantity', 'Số lượng'),
                  const SizedBox(width: 4),
                  _buildSubTab('orders', 'Lượt đặt'),
                  const SizedBox(width: 4),
                  _buildSubTab('profit', 'Lợi nhuận'),
                  const SizedBox(width: 4),
                  _buildSubTab('return_rate', 'Tỷ lệ hoàn'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Danh sách #1, #2, #3 linh hoạt theo bộ lọc đã chọn
          ..._getTopProductsList().asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;
            final rankStr = '#${idx + 1}';
            final rankColors = [
              [const Color(0xFFFDE68A), const Color(0xFF92400E)],
              [const Color(0xFFDBEAFE), const Color(0xFF1E3A8A)],
              [const Color(0xFFFFEDD5), const Color(0xFF9A3412)],
            ];
            final colorPair = idx < 3 ? rankColors[idx] : rankColors[1];
            return Padding(
              padding: EdgeInsets.only(bottom: idx == 2 ? 0 : 9),
              child: _buildRankItem(
                rank: rankStr,
                rankColor: colorPair[0],
                rankTextColor: colorPair[1],
                name: item['name'] as String,
                sub: item['sub'] as String,
                revenue: item['rev'] as String,
                hasBadge: item['badge'] as bool? ?? false,
              ),
            );
          }),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getTopProductsList() {
    final data = {
      'revenue': [
        {'name': 'Áo Polo Pima Cotton Cao Cấp', 'sub': '48 lượt bán • 34 sản phẩm', 'rev': '11.950.000 đ', 'badge': true},
        {'name': 'Serum Dưỡng Ẩm Phục Hồi B5', 'sub': '52 lượt bán • 28 chai', 'rev': '7.960.000 đ', 'badge': false},
        {'name': 'Quần Tây Nam Slimfit Co Giãn', 'sub': '24 lượt bán • 19 sản phẩm', 'rev': '5.120.000 đ', 'badge': false},
      ],
      'quantity': [
        {'name': 'Serum Dưỡng Ẩm Phục Hồi B5', 'sub': '52 lượt bán • 84 chai xuất kho', 'rev': '7.960.000 đ', 'badge': true},
        {'name': 'Áo Thun Basic 100% Cotton', 'sub': '68 lượt bán • 72 sản phẩm', 'rev': '4.320.000 đ', 'badge': false},
        {'name': 'Áo Polo Pima Cotton Cao Cấp', 'sub': '48 lượt bán • 34 sản phẩm', 'rev': '11.950.000 đ', 'badge': false},
      ],
      'orders': [
        {'name': 'Áo Thun Basic 100% Cotton', 'sub': '68 lượt đặt • 72 sản phẩm', 'rev': '4.320.000 đ', 'badge': true},
        {'name': 'Áo Polo Pima Cotton Cao Cấp', 'sub': '48 lượt đặt • 34 sản phẩm', 'rev': '11.950.000 đ', 'badge': false},
        {'name': 'Serum Dưỡng Ẩm Phục Hồi B5', 'sub': '32 lượt đặt • 28 chai', 'rev': '7.960.000 đ', 'badge': false},
      ],
      'profit': [
        {'name': 'Áo Polo Pima Cotton Cao Cấp', 'sub': 'Biên lãi 42% • Vốn 6.931.000 đ', 'rev': '+5.019.000 đ', 'badge': true},
        {'name': 'Serum Dưỡng Ẩm Phục Hồi B5', 'sub': 'Biên lãi 38% • Vốn 4.898.000 đ', 'rev': '+3.024.000 đ', 'badge': false},
        {'name': 'Quần Tây Nam Slimfit Co Giãn', 'sub': 'Biên lãi 35% • Vốn 3.328.000 đ', 'rev': '+1.792.000 đ', 'badge': false},
      ],
      'return_rate': [
        {'name': 'Quần Tây Nam Slimfit Co Giãn', 'sub': 'Tỷ lệ hoàn cực thấp: 1.2% (1 đơn)', 'rev': '5.120.000 đ', 'badge': true},
        {'name': 'Serum Dưỡng Ẩm Phục Hồi B5', 'sub': 'Tỷ lệ hoàn cực thấp: 1.5% (1 chai)', 'rev': '7.960.000 đ', 'badge': false},
        {'name': 'Áo Polo Pima Cotton Cao Cấp', 'sub': 'Tỷ lệ hoàn kiểm soát: 2.1% (2 cái)', 'rev': '11.950.000 đ', 'badge': false},
      ],
    };
    return data[_topProductsFilter] ?? data['revenue']!;
  }

  Widget _buildSubTab(String id, String label) {
    final active = _topProductsFilter == id;
    return GestureDetector(
      onTap: () => setState(() => _topProductsFilter = id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6.5),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: active ? const [BoxShadow(color: Color(0x10000000), blurRadius: 4, offset: Offset(0, 1))] : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'serif',
              fontSize: 12,
              fontWeight: active ? FontWeight.w800 : FontWeight.w600,
              color: active ? const Color(0xFF065F46) : const Color(0xFF64748B),
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
        color: const Color(0xFFF4F6FC),
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
                style: TextStyle(fontFamily: 'serif', fontSize: 11, fontWeight: FontWeight.w900, color: rankTextColor),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text('img', style: TextStyle(fontFamily: 'serif', fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontFamily: 'serif', fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(sub, style: const TextStyle(fontFamily: 'serif', fontSize: 11, color: Color(0xFF64748B))),
                const SizedBox(height: 2),
                Text(
                  revenue,
                  style: const TextStyle(fontFamily: 'serif', fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF065F46)),
                ),
              ],
            ),
          ),
          if (hasBadge)
            const Icon(Icons.verified_rounded, size: 18, color: Color(0xFF065F46)),
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
        border: Border.all(color: const Color(0xFFE8EEF5), width: 1.0),
        boxShadow: const [
          BoxShadow(color: Color(0x0A0F172A), blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: child,
    );
  }
}

/// Mũi tên tam giác trỏ xuống cho tooltip
class _TrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1E293B)
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
    paint.color = const Color(0xFF065F46);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * 0.42,
      false,
      paint,
    );

    // 28% Mint Green
    paint.color = const Color(0xFF6EE7B7);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2 + 2 * math.pi * 0.42,
      2 * math.pi * 0.28,
      false,
      paint,
    );

    // 18% Crimson Red
    paint.color = const Color(0xFFDC2626);
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
