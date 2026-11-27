import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/auth/permission_gate.dart';
import '../../auth/services/auth_service.dart';
import '../../commerce/models/commerce_models.dart';
import '../../commerce/services/commerce_service.dart';
import '../../commerce/widgets/commerce_widgets.dart';
import '../../products/screens/barcode_scanner_screen.dart';
import 'sales_screen.dart';
import 'sale_detail_screen.dart';

class SaleEditorScreen extends StatefulWidget {
  const SaleEditorScreen({super.key, required this.api});
  final SalesService api;
  @override
  State<SaleEditorScreen> createState() => _SaleEditorScreenState();
}

class _CartLine {
  _CartLine(this.variant) : quantity = TextEditingController(text: '1');
  final Json variant;
  final TextEditingController quantity;
}

class _SaleEditorScreenState extends State<SaleEditorScreen>
    with CommerceActions {
  final _code = documentCode('POS');
  final List<_CartLine> _lines = [];
  Json? _customer, _preview;
  String? _previewKey;
  int _previewRevision = 0;
  bool _uncertain = false;
  @override
  void dispose() {
    for (final l in _lines) {
      l.quantity.dispose();
    }
    super.dispose();
  }

  List<Json> items() {
    if (_lines.isEmpty || _lines.length > 500) {
      throw const FormatException('Giỏ hàng cần từ 1 đến 500 SKU.');
    }
    return _lines
        .map(
          (l) => <String, dynamic>{
            'variantId': l.variant['id'],
            'quantity': quantityOf(l.quantity.text),
          },
        )
        .toList();
  }

  String get cartKey =>
      _lines.map((l) => '${l.variant['id']}:${l.quantity.text}').join('|');
  void changed() {
    _previewRevision++;
    setState(() {
      _preview = null;
      _previewKey = null;
    });
  }

  void add(Json variant) {
    final existing = _lines.where((l) => l.variant['id'] == variant['id']);
    if (existing.isNotEmpty) {
      final line = existing.first;
      line.quantity.text = '${(int.tryParse(line.quantity.text) ?? 0) + 1}';
    } else {
      _lines.add(_CartLine(variant));
    }
    changed();
  }

  Future<void> preview() async {
    final lines = items(), key = cartKey, revision = _previewRevision;
    final data = await widget.api.preview(lines);
    if (mounted && revision == _previewRevision && key == cartKey) {
      setState(() {
        _preview = data;
        _previewKey = key;
      });
    }
  }

  @override
  Widget build(BuildContext viewContext) {
    if (!canSaleWrite || !AuthService.hasPermission('inventory.read')) {
      return const Scaffold(
        body: PermissionDeniedView(
          message: 'Tạo đơn tại quầy cần quyền tạo đơn và xem kho.',
        ),
      );
    }
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(title: const Text('Bán hàng tại quầy')),
        body: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            ShiftPanel(service: widget.api, domain: 'sales'),
            Text('Mã đơn: $_code'),
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: busy || _uncertain
                        ? null
                        : () async {
                            final variant = await openCommerce<Json>(
                              context,
                              VariantPicker(service: widget.api),
                            );
                            if (variant != null && mounted) add(variant);
                          },
                    icon: const Icon(Icons.add_shopping_cart),
                    label: const Text('Chọn sản phẩm'),
                  ),
                ),
                if (kIsWeb ||
                    defaultTargetPlatform == TargetPlatform.android ||
                    defaultTargetPlatform == TargetPlatform.iOS ||
                    defaultTargetPlatform == TargetPlatform.macOS)
                  IconButton(
                    tooltip: 'Quét mã vạch',
                    onPressed: busy || _uncertain
                        ? null
                        : () async {
                            final barcode = await openCommerce<String>(
                              context,
                              const BarcodeScannerScreen(),
                            );
                            if (barcode == null || !mounted) return;
                            await act(() async {
                              final result = await widget.api.variants(barcode);
                              final exact = records(result['items']).where(
                                (v) =>
                                    v['barcode'] == barcode ||
                                    v['sku'] == barcode,
                              );
                              if (exact.length != 1) {
                                throw const FormatException(
                                  'Không tìm thấy một SKU khớp mã vạch. Dùng tìm sản phẩm để chọn.',
                                );
                              }
                              if (mounted) add(exact.first);
                            });
                          },
                    icon: const Icon(Icons.qr_code_scanner),
                  ),
              ],
            ),
            if (_lines.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Giỏ hàng trống. Chọn SKU hoặc quét mã để bắt đầu.',
                ),
              ),
            for (final line in _lines)
              CommerceCard(
                title:
                    '${line.variant['sku']} · ${line.variant['productName']}',
                children: [
                  InfoRow(
                    'Giá niêm yết',
                    moneyLabel(line.variant['basePrice']),
                  ),
                  Text(
                    'Tồn tham khảo: ${line.variant['onHand']}. Hệ thống kiểm tra lại tồn tốt khi thanh toán.',
                  ),
                  CommerceField(
                    line.quantity,
                    'Số lượng',
                    integer: true,
                    required: true,
                    readOnly: busy || _uncertain,
                    onChanged: (_) => changed(),
                  ),
                  TextButton(
                    onPressed: busy || _uncertain
                        ? null
                        : () {
                            _lines.remove(line);
                            line.quantity.dispose();
                            changed();
                          },
                    child: const Text('Bỏ sản phẩm'),
                  ),
                ],
              ),
            CommerceCard(
              title: 'Khách hàng',
              children: [
                ListTile(
                  title: Text(
                    _customer == null
                        ? 'Khách vãng lai'
                        : '${_customer!['name']} · ${_customer!['phone']}',
                  ),
                  trailing: const Icon(Icons.person_search),
                  onTap: busy || _uncertain
                      ? null
                      : () async {
                          final customer = await openCommerce<Json>(
                            context,
                            CustomersScreen(api: widget.api, picking: true),
                          );
                          if (customer != null && mounted) {
                            setState(() => _customer = customer);
                          }
                        },
                ),
                if (_customer != null)
                  TextButton(
                    onPressed: busy || _uncertain
                        ? null
                        : () => setState(() => _customer = null),
                    child: const Text('Bán khách vãng lai'),
                  ),
              ],
            ),
            ErrorNotice(actionError),
            if (_uncertain) ...[
              Text(
                'Chưa xác định được kết quả tạo đơn. Tra mã $_code trước khi tạo lại.',
              ),
              TextButton(
                onPressed: busy
                    ? null
                    : () => act(() async {
                        final page = await widget.api.orders({
                          'search': _code,
                          'pageSize': 100,
                        });
                        final matches = page.items.where(
                          (o) => o['orderCode'] == _code,
                        );
                        if (matches.isEmpty) {
                          if (mounted) {
                            setState(() {
                              _uncertain = false;
                              _preview = null;
                              _previewKey = null;
                            });
                          }
                        } else if (mounted) {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SaleDetailScreen(
                                api: widget.api,
                                id: textOf(matches.first['id']),
                              ),
                            ),
                          );
                        }
                      }),
                child: const Text('Tra cứu kết quả tạo đơn'),
              ),
            ],
            if (_preview != null)
              CommerceCard(
                title: 'Giá & khuyến mãi từ máy chủ',
                children: [
                  InfoRow(
                    'Tiền hàng',
                    moneyLabel(_preview!['totalGrossAmount']),
                  ),
                  InfoRow(
                    object(_preview!['promotion'])['name']?.toString() ??
                        'Khuyến mãi',
                    moneyLabel(_preview!['discountAmount']),
                  ),
                  InfoRow(
                    'Tổng cần thu',
                    moneyLabel(_preview!['totalNetAmount']),
                  ),
                ],
              ),
            TextButton(
              onPressed: busy || _uncertain || _lines.isEmpty
                  ? null
                  : () => act(preview),
              child: const Text('Kiểm tra giá & khuyến mãi'),
            ),
            const Text(
              'Đơn nháp chưa giữ chỗ hoặc trừ kho. Giá và khuyến mãi được máy chủ xác định. Sau khi tạo, kiểm tra tổng tiền rồi xác nhận đã thu tiền trên màn hình đơn.',
            ),
            FilledButton(
              onPressed:
                  busy ||
                      _uncertain ||
                      _preview == null ||
                      _previewKey != cartKey
                  ? null
                  : () => act(() async {
                      final lines = items();
                      final shift = await widget.api.shift('sales');
                      if (shift == null) {
                        throw const FormatException(
                          'Cần mở ca của bạn trước khi tạo đơn.',
                        );
                      }
                      final previewAmount = textOf(_preview!['totalNetAmount']);
                      Json order;
                      try {
                        order = await widget.api.create({
                          'orderCode': _code,
                          'shiftId': shift['id'],
                          if (_customer != null) 'customerId': _customer!['id'],
                          'items': lines,
                        });
                      } catch (_) {
                        if (mounted) setState(() => _uncertain = true);
                        rethrow;
                      }
                      if (!mounted) return;
                      final changedAmount =
                          Money.parse(
                            order['totalNetAmount'],
                          ).compareTo(Money.parse(previewAmount)) !=
                          0;
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SaleDetailScreen(
                            api: widget.api,
                            id: textOf(order['id']),
                            notice: changedAmount
                                ? 'Giá hoặc khuyến mãi đã thay đổi. Kiểm tra tổng mới trước khi thu tiền.'
                                : null,
                          ),
                        ),
                      );
                    }),
              child: Text(
                busy ? 'Đang xử lý…' : 'Tạo đơn & tiếp tục thanh toán',
              ),
            ),
            if (busy) const LinearProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
