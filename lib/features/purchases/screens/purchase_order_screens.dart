import 'package:flutter/material.dart';
import '../../commerce/models/commerce_models.dart';
import '../../commerce/services/commerce_service.dart';
import '../../commerce/widgets/commerce_widgets.dart';
import 'purchase_receipt_screens.dart';

class PurchaseOrderEditor extends StatefulWidget {
  const PurchaseOrderEditor({
    super.key,
    required this.api,
    this.order,
    this.supplier,
    this.initialProducts = const [],
  });
  final PurchasesService api;
  final Json? order, supplier;
  final List<Json> initialProducts;
  @override
  State<PurchaseOrderEditor> createState() => _PurchaseOrderEditorState();
}

class _OrderLine {
  _OrderLine(this.product, String qty, String price)
    : quantity = TextEditingController(text: qty),
      price = TextEditingController(text: price);
  final Json product;
  final TextEditingController quantity, price;
  void dispose() {
    quantity.dispose();
    price.dispose();
  }
}

class _PurchaseOrderEditorState extends State<PurchaseOrderEditor>
    with CommerceActions {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _code, _orderDate, _delivery;
  Json? _supplier;
  final List<_OrderLine> _lines = [];
  @override
  void initState() {
    super.initState();
    final order = widget.order;
    _code = TextEditingController(
      text: textOf(order?['poCode'] ?? documentCode('PO')),
    );
    _orderDate = TextEditingController(
      text: order == null ? shopToday() : dayOf(order['orderDate']),
    );
    _delivery = TextEditingController(
      text: dayOf(order?['expectedDeliveryDate']),
    );
    _supplier =
        widget.supplier ??
        (order == null
            ? null
            : {...object(order['supplier']), 'id': order['supplierId']});
    for (final item in records(order?['purchaseOrderItems'])) {
      _lines.add(
        _OrderLine(
          {
            'id': item['variantId'],
            'sku': object(item['variant'])['sku'],
            'productName': object(object(item['variant'])['template'])['name'],
          },
          textOf(item['orderedQty']),
          textOf(item['unitPrice']),
        ),
      );
    }
    for (final p in widget.initialProducts) {
      add(p);
    }
  }

  void add(Json product) {
    if (_lines.any((l) => l.product['id'] == product['id'])) return;
    final c = object(product['catalog']);
    final min = (c['minOrderQty'] as num?)?.toInt() ?? 1,
        multiple = (c['orderMultiple'] as num?)?.toInt() ?? 1;
    _lines.add(
      _OrderLine(
        product,
        '${((min + multiple - 1) ~/ multiple) * multiple}',
        textOf(product['supplyPrice'] ?? '0'),
      ),
    );
  }

  @override
  void dispose() {
    _code.dispose();
    _orderDate.dispose();
    _delivery.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  Money get sum {
    var total = Money.zero;
    for (final line in _lines) {
      try {
        total =
            total +
            Money.parse(line.price.text).times(quantityOf(line.quantity.text));
      } on FormatException {
        /* Incomplete input has no subtotal. */
      }
    }
    return total;
  }

  @override
  Widget build(BuildContext viewContext) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          widget.order == null ? 'Tạo đơn đặt mua' : 'Sửa đơn đặt mua',
        ),
      ),
      body: Form(
        key: _form,
        child: AbsorbPointer(
          absorbing: busy,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              CommerceField(_code, 'Mã đơn', readOnly: true),
              DateField(_orderDate, 'Ngày đặt', required: true),
              DateField(_delivery, 'Ngày giao dự kiến', required: true),
              ListTile(
                title: Text(
                  _supplier == null
                      ? 'Chọn nhà cung cấp *'
                      : textOf(_supplier!['name']),
                ),
                trailing: const Icon(Icons.search),
                onTap: () async {
                  final selected = await openCommerce<Json>(
                    context,
                    RecordPicker(
                      title: 'Chọn NCC đang hợp tác',
                      load: widget.api.suppliers,
                      extra: const {'isActive': 'true'},
                      label: (s) => '${s['name']} · ${s['phone'] ?? ''}',
                    ),
                  );
                  if (selected == null ||
                      !mounted ||
                      selected['id'] == _supplier?['id']) {
                    return;
                  }
                  if (_lines.isNotEmpty &&
                      !await confirmCommerce(
                        context,
                        'Đổi nhà cung cấp?',
                        'Các SKU đã chọn sẽ được bỏ để chọn lại theo NCC mới.',
                      )) {
                    return;
                  }
                  if (mounted) {
                    setState(() {
                      _supplier = selected;
                      for (final l in _lines) {
                        l.dispose();
                      }
                      _lines.clear();
                    });
                  }
                },
              ),
              OutlinedButton.icon(
                onPressed: _supplier == null
                    ? null
                    : () async {
                        final p = await openCommerce<Json>(
                          context,
                          RecordPicker(
                            title: 'Chọn SKU nhà cung cấp',
                            enabled: (p) =>
                                p['isActive'] == true &&
                                object(p['catalog'])['isActive'] == true,
                            load: (q) => widget.api.products(
                              textOf(_supplier!['id']),
                              q,
                            ),
                            extra: const {
                              'isActive': 'true',
                              'kind': 'catalog',
                            },
                            label: (p) =>
                                '${p['sku']} · ${p['productName']} · ${moneyLabel(p['supplyPrice'])}',
                          ),
                        );
                        if (p != null && mounted) setState(() => add(p));
                      },
                icon: const Icon(Icons.add),
                label: const Text('Thêm SKU từ danh mục NCC'),
              ),
              for (final line in _lines)
                CommerceCard(
                  title:
                      '${line.product['sku']} · ${line.product['productName']}',
                  children: [
                    CommerceField(
                      line.quantity,
                      'Số lượng đặt',
                      integer: true,
                      required: true,
                      onChanged: (_) => setState(() {}),
                    ),
                    CommerceField(
                      line.price,
                      'Đơn giá',
                      money: true,
                      required: true,
                      onChanged: (_) => setState(() {}),
                    ),
                    if (line.product['catalog'] != null)
                      Text(
                        'Tối thiểu ${object(line.product['catalog'])['minOrderQty']} · Bội số ${object(line.product['catalog'])['orderMultiple']}',
                      ),
                    TextButton(
                      onPressed: () => setState(() {
                        _lines.remove(line);
                        line.dispose();
                      }),
                      child: const Text('Bỏ dòng'),
                    ),
                  ],
                ),
              InfoRow('Tổng đặt mua', moneyLabel(sum.toString())),
              const Text('Đặt mua chưa làm tăng tồn kho hoặc công nợ.'),
              ErrorNotice(actionError),
              if (actionError != null)
                Text(
                  'Nếu mất kết nối khi lưu, tra mã ${_code.text} trong danh sách đơn trước khi thử lại.',
                ),
              FilledButton(
                onPressed: () => act(() async {
                  if (!_form.currentState!.validate()) return;
                  if (_supplier == null ||
                      _lines.isEmpty ||
                      _lines.length > 500) {
                    throw const FormatException(
                      'Chọn NCC và từ 1 đến 500 SKU.',
                    );
                  }
                  validateDay(_orderDate.text);
                  validateDay(_delivery.text);
                  if (widget.order == null &&
                      _orderDate.text.compareTo(shopToday()) < 0) {
                    throw const FormatException(
                      'Ngày đặt không được trước hôm nay.',
                    );
                  }
                  if (_delivery.text.compareTo(_orderDate.text) < 0) {
                    throw const FormatException(
                      'Ngày giao không được trước ngày đặt.',
                    );
                  }
                  final items = <Json>[];
                  for (final l in _lines) {
                    final qty = quantityOf(l.quantity.text),
                        c = object(l.product['catalog']);
                    if (qty < ((c['minOrderQty'] as num?)?.toInt() ?? 1) ||
                        qty % ((c['orderMultiple'] as num?)?.toInt() ?? 1) !=
                            0) {
                      throw const FormatException(
                        'Số lượng phải đạt tối thiểu và đúng bội số đặt của NCC.',
                      );
                    }
                    items.add({
                      'variantId': l.product['id'],
                      'orderedQty': qty,
                      'unitPrice': Money.parse(l.price.text).toString(),
                    });
                  }
                  final saved = await widget.api.saveOrder({
                    'poCode': _code.text,
                    'supplierId': _supplier!['id'],
                    'orderDate': _orderDate.text,
                    'expectedDeliveryDate': _delivery.text,
                    'items': items,
                  }, id: widget.order?['id']);
                  if (mounted) Navigator.pop(context, textOf(saved['id']));
                }),
                child: Text(busy ? 'Đang lưu…' : 'Lưu đơn đặt mua'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class PurchaseOrderDetail extends StatelessWidget {
  const PurchaseOrderDetail({super.key, required this.api, required this.id});
  final PurchasesService api;
  final String id;
  @override
  Widget build(BuildContext context) => RemoteDetail(
    title: 'Chi tiết đơn đặt mua',
    load: () => api.order(id),
    builder: (order, reload) =>
        _OrderView(api: api, order: order, reload: reload),
  );
}

class _OrderView extends StatefulWidget {
  const _OrderView({
    required this.api,
    required this.order,
    required this.reload,
  });
  final PurchasesService api;
  final Json order;
  final VoidCallback reload;
  @override
  State<_OrderView> createState() => _OrderViewState();
}

class _OrderViewState extends State<_OrderView> with CommerceActions {
  Future<void> operation(String action, String title, String message) async {
    if (!await confirmCommerce(context, title, message)) return;
    await act(() async {
      await widget.api.orderAction(textOf(widget.order['id']), action);
      if (mounted) widget.reload();
    });
  }

  @override
  Widget build(BuildContext viewContext) {
    final o = widget.order, totals = object(o['totals']);
    final receipts = records(o['purchaseReceipts']);
    final status = o['status'];
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        CommerceCard(
          title: textOf(o['poCode']),
          children: [
            InfoRow('Nhà cung cấp', object(o['supplier'])['name']),
            InfoRow('Trạng thái', statusLabel(status)),
            InfoRow(
              'Ngày đặt / giao dự kiến',
              '${dayOf(o['orderDate'])} / ${dayOf(o['expectedDeliveryDate'])}',
            ),
            InfoRow(
              'Số lượng nhận / đặt',
              '${totals['receivedQty']} / ${totals['orderedQty']}',
            ),
            for (final e in {
              'orderedAmount': 'Giá trị đặt',
              'receivedAmount': 'Đã nhận',
              'paidAmount': 'Đã trả',
              'debtAmount': 'Còn nợ',
            }.entries)
              InfoRow(e.value, moneyLabel(totals[e.key])),
          ],
        ),
        if (canPurchaseWrite) ...[
          if (['DRAFT', 'ORDERED'].contains(status) && receipts.isEmpty)
            TextButton(
              onPressed: busy
                  ? null
                  : () async {
                      await openCommerce(
                        context,
                        PurchaseOrderEditor(api: widget.api, order: o),
                      );
                      if (mounted) widget.reload();
                    },
              child: const Text('Sửa đơn chưa nhận hàng'),
            ),
          if (status == 'DRAFT')
            FilledButton(
              onPressed: busy
                  ? null
                  : () => operation(
                      'confirm',
                      'Xác nhận đặt mua?',
                      'Chuyển đơn nháp thành đơn đặt mua chính thức sau khi đã kiểm tra SKU, số lượng và giá.',
                    ),
              child: const Text('Xác nhận đặt hàng'),
            ),
          if (['ORDERED', 'PARTIALLY_RECEIVED'].contains(status))
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      await openCommerce(
                        context,
                        ReceiveOrderScreen(api: widget.api, order: o),
                      );
                      if (mounted) widget.reload();
                    },
              child: const Text('Kiểm đếm & nhận hàng'),
            ),
          if (['DRAFT', 'ORDERED'].contains(status) && receipts.isEmpty)
            TextButton(
              onPressed: busy
                  ? null
                  : () => operation(
                      'cancel',
                      'Hủy đơn đặt mua?',
                      'Đơn sẽ không thể nhận hàng sau khi hủy.',
                    ),
              child: const Text('Hủy đơn'),
            ),
          if (status == 'PARTIALLY_RECEIVED')
            TextButton(
              onPressed: busy
                  ? null
                  : () => operation(
                      'close',
                      'Đóng phần giao thiếu?',
                      'Dừng nhận thêm; giữ hàng đã nhận và công nợ.',
                    ),
              child: const Text('Đóng phần giao thiếu'),
            ),
        ],
        ErrorNotice(actionError),
        CommerceCard(
          title: 'SKU đặt mua',
          children: records(o['purchaseOrderItems'])
              .map(
                (l) => ListTile(
                  title: Text(variantLabel(l)),
                  subtitle: Text(
                    'Đặt ${l['orderedQty']} · Nhận ${l['receivedQty']} · Còn ${l['remainingQty']}\n${moneyLabel(l['unitPrice'])} / đơn vị',
                  ),
                ),
              )
              .toList(),
        ),
        CommerceCard(
          title: 'Các đợt nhận & thanh toán',
          children: [
            if (receipts.isEmpty) const Text('Chưa có phiếu nhận.'),
            ...receipts.map(
              (r) => ListTile(
                title: Text(
                  '${r['receiptCode']} · ${statusLabel(r['status'])}',
                ),
                subtitle: Text(
                  'Tiền hàng ${moneyLabel(r['totalAmount'])}\nĐã trả ${moneyLabel(r['paidAmount'])} · Nợ ${moneyLabel(r['debtAmount'])}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await openCommerce(
                    context,
                    PurchaseReceiptDetail(api: widget.api, id: textOf(r['id'])),
                  );
                  if (mounted) widget.reload();
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class ReceiveOrderScreen extends StatefulWidget {
  const ReceiveOrderScreen({super.key, required this.api, required this.order});
  final PurchasesService api;
  final Json order;
  @override
  State<ReceiveOrderScreen> createState() => _ReceiveOrderScreenState();
}

class _ReceiveRow {
  _ReceiveRow(this.item)
    : qty = TextEditingController(text: '0'),
      price = TextEditingController(text: textOf(item['unitPrice']));
  final Json item;
  final TextEditingController qty,
      price,
      lot = TextEditingController(),
      expiry = TextEditingController(),
      manufacturing = TextEditingController();
  void dispose() {
    for (final c in [qty, price, lot, expiry, manufacturing]) {
      c.dispose();
    }
  }

  ReceiveLine get input => ReceiveLine(
    poItemId: textOf(item['id']),
    qty: qty.text,
    price: price.text,
    lot: lot.text,
    expiration: expiry.text,
    manufacturing: manufacturing.text,
  );
}

class _ReceiveOrderScreenState extends State<ReceiveOrderScreen>
    with CommerceActions {
  final _code = TextEditingController(text: documentCode('PR')),
      _paid = TextEditingController(text: '0');
  final List<_ReceiveRow> _lines = [];
  Json? _draft;
  bool _uncertain = false;
  @override
  void initState() {
    super.initState();
    for (final item in records(
      widget.order['purchaseOrderItems'],
    ).where((i) => (i['remainingQty'] as num) > 0)) {
      _lines.add(_ReceiveRow(item));
    }
  }

  @override
  void dispose() {
    _code.dispose();
    _paid.dispose();
    for (final row in _lines) {
      row.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext viewContext) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(title: Text('Nhận hàng · ${widget.order['poCode']}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ShiftPanel(service: widget.api, domain: 'purchases'),
          const Text(
            'Để số lượng 0 cho hàng chưa giao. Có thể chia một SKU thành nhiều dòng theo lô. Phiếu nháp chưa ghi kho và không giữ chỗ.',
          ),
          ErrorNotice(actionError),
          if (_uncertain) ...[
            Text(
              'Chưa xác định được kết quả nhận hàng. Tra mã ${_code.text} trong danh sách phiếu trước khi thử lại.',
            ),
            TextButton(
              onPressed: () async {
                await act(() async {
                  final page = await widget.api.receipts({
                    'search': _code.text,
                    'poId': widget.order['id'],
                    'pageSize': 100,
                  });
                  final matches = page.items.where(
                    (r) => r['receiptCode'] == _code.text,
                  );
                  if (matches.isEmpty) {
                    if (mounted) {
                      setState(() {
                        _uncertain = false;
                        _draft = null;
                        actionError =
                            'Chưa tìm thấy phiếu. Kiểm tra lại đơn và kho trước khi lập lại.';
                      });
                    }
                  } else if (mounted) {
                    await openCommerce(
                      context,
                      PurchaseReceiptDetail(
                        api: widget.api,
                        id: textOf(matches.first['id']),
                      ),
                    );
                    if (mounted) Navigator.pop(context, true);
                  }
                });
              },
              child: const Text('Tra cứu kết quả theo mã phiếu'),
            ),
          ],
          if (_draft == null)
            AbsorbPointer(
              absorbing: busy || _uncertain,
              child: Column(
                children: [
                  CommerceField(
                    _code,
                    'Mã phiếu nhận',
                    required: true,
                    maxLength: 50,
                  ),
                  CommerceField(
                    _paid,
                    'Trả ngay NCC',
                    money: true,
                    required: true,
                  ),
                  for (final row in _lines)
                    CommerceCard(
                      title: variantLabel(row.item),
                      children: [
                        Text('Còn thiếu ${row.item['remainingQty']}'),
                        CommerceField(
                          row.qty,
                          'Số thực nhận (0 nếu chưa giao)',
                        ),
                        CommerceField(
                          row.price,
                          'Giá nhận thực tế',
                          money: true,
                        ),
                        if (object(
                              object(row.item['variant'])['template'],
                            )['hasLotTracking'] ==
                            true) ...[
                          CommerceField(row.lot, 'Số lô', maxLength: 100),
                          DateField(row.expiry, 'Hạn sử dụng'),
                          DateField(row.manufacturing, 'Ngày sản xuất'),
                        ],
                        TextButton(
                          onPressed: () => setState(() {
                            _lines.remove(row);
                            row.dispose();
                          }),
                          child: const Text('Bỏ dòng'),
                        ),
                      ],
                    ),
                  Wrap(
                    children: records(widget.order['purchaseOrderItems'])
                        .where((i) => (i['remainingQty'] as num) > 0)
                        .map(
                          (item) => TextButton(
                            onPressed: () =>
                                setState(() => _lines.add(_ReceiveRow(item))),
                            child: Text(
                              '+ Dòng ${object(item['variant'])['sku']}',
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  FilledButton(
                    onPressed: () => act(() async {
                      final body = buildReceiptPayload(
                        widget.order,
                        _code.text,
                        _paid.text,
                        _lines.map((l) => l.input).toList(),
                      );
                      final draft = await widget.api.previewReceipt(
                        textOf(widget.order['id']),
                        body,
                      );
                      if (mounted) setState(() => _draft = draft);
                    }),
                    child: const Text('Xem trước phiếu nhận'),
                  ),
                ],
              ),
            ),
          if (_draft != null)
            CommerceCard(
              title: 'Kiểm tra phiếu nhận trước khi nhập kho',
              children: [
                InfoRow('Mã phiếu', _code.text),
                InfoRow('Tiền hàng', moneyLabel(_draft!['totalAmount'])),
                InfoRow(
                  'Trả ngay',
                  moneyLabel(object(_draft!['receipt'])['paidAmount']),
                ),
                InfoRow('Còn nợ', moneyLabel(_draft!['debtAmount'])),
                InfoRow('Hết hạn nháp', _draft!['expiresAt']),
                for (final item in records(object(_draft!['receipt'])['items']))
                  InfoRow(
                    'Nhận ${item['receivedQty']} · ${item['lotNumber'] ?? ''}',
                    moneyLabel(item['actualCost']),
                  ),
                TextButton(
                  onPressed: busy || _uncertain
                      ? null
                      : () => setState(() => _draft = null),
                  child: const Text('Quay lại kiểm đếm'),
                ),
                FilledButton(
                  onPressed: busy || _uncertain
                      ? null
                      : () => act(() async {
                          final expiry = DateTime.tryParse(
                            textOf(_draft!['expiresAt']),
                          );
                          if (expiry == null ||
                              !DateTime.now().isBefore(expiry)) {
                            setState(() => _draft = null);
                            throw const FormatException(
                              'Bản nháp hết hạn. Hãy xem trước lại.',
                            );
                          }
                          // No automatic retry: a disconnected confirmation may already have committed.
                          try {
                            await widget.api.confirmReceipt(
                              textOf(widget.order['id']),
                              textOf(_draft!['draftToken']),
                            );
                          } catch (_) {
                            if (mounted) setState(() => _uncertain = true);
                            rethrow;
                          }
                          if (mounted) Navigator.pop(context, true);
                        }),
                  child: const Text('Xác nhận nhập kho & thanh toán'),
                ),
              ],
            ),
          if (busy) const LinearProgressIndicator(),
        ],
      ),
    ),
  );
}
