import 'package:flutter/material.dart';
import '../../auth/services/auth_service.dart';
import '../../commerce/models/commerce_models.dart';
import '../../commerce/services/commerce_service.dart';
import '../../commerce/widgets/commerce_widgets.dart';
import 'purchase_order_screens.dart';

class PurchaseReceiptDetail extends StatelessWidget {
  const PurchaseReceiptDetail({super.key, required this.api, required this.id});
  final PurchasesService api;
  final String id;
  @override
  Widget build(BuildContext context) => RemoteDetail(
    title: 'Chi tiết phiếu nhận',
    load: () => api.receipt(id),
    builder: (r, reload) => ListView(
      padding: const EdgeInsets.all(12),
      children: [
        CommerceCard(
          title: textOf(r['receiptCode']),
          children: [
            InfoRow('Nhà cung cấp', object(r['supplier'])['name']),
            InfoRow('Ngày nhận', r['receivedAt']),
            InfoRow('Trạng thái', statusLabel(r['status'])),
            InfoRow('Tổng tiền hàng', moneyLabel(r['totalAmount'])),
            InfoRow('Đã trả NCC', moneyLabel(r['paidAmount'])),
            InfoRow('Còn nợ', moneyLabel(r['debtAmount'])),
            if (r['poId'] != null)
              TextButton(
                onPressed: () => openCommerce(
                  context,
                  PurchaseOrderDetail(api: api, id: textOf(r['poId'])),
                ),
                child: Text('Đơn mua ${object(r['po'])['poCode'] ?? ''}'),
              ),
            if (canPurchaseWrite && r['status'] == 'RECEIVED') ...[
              if (Money.parse(
                    r['debtAmount'],
                    wholeDigits: 12,
                  ).compareTo(Money.zero) >
                  0)
                FilledButton(
                  onPressed: () async {
                    await openCommerce(
                      context,
                      SupplierPaymentScreen(api: api, receipt: r),
                    );
                    if (context.mounted) reload();
                  },
                  child: const Text('Thanh toán thêm NCC'),
                ),
              if (AuthService.hasPermission('inventory.adjust'))
                TextButton(
                  onPressed: () async {
                    await openCommerce(
                      context,
                      CorrectReceiptScreen(api: api, receipt: r),
                    );
                    if (context.mounted) reload();
                  },
                  child: const Text('Sửa số lượng / giá phiếu nhận'),
                ),
            ],
            TextButton(
              onPressed: () => openCommerce(
                context,
                RemoteDetail(
                  title: 'Lịch sử thanh toán NCC',
                  load: () => api.payments(id),
                  builder: (history, _) => ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      InfoRow('Tổng đã trả', moneyLabel(history['paidAmount'])),
                      InfoRow(
                        'Đã ghi nhận',
                        moneyLabel(history['recordedPaymentAmount']),
                      ),
                      if (history['historyComplete'] != true)
                        Text(
                          'Lịch sử chưa đầy đủ. Phần đã trả chưa có giao dịch: ${moneyLabel(history['untrackedPaidAmount'])}',
                        ),
                      for (final item in records(history['items']))
                        ListTile(
                          title: Text(moneyLabel(item['amount'])),
                          subtitle: Text(
                            '${item['createdAt']} · ${object(item['createdByUser'])['fullName'] ?? ''}',
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              child: const Text('Lịch sử các khoản chi'),
            ),
          ],
        ),
        CommerceCard(
          title: 'Hàng thực nhận',
          children: records(r['purchaseReceiptItems'])
              .map(
                (l) => ListTile(
                  title: Text(variantLabel(l)),
                  subtitle: Text(
                    '${l['receivedQty']} × ${moneyLabel(l['actualCost'])} = ${moneyLabel(l['subtotal'])}\n${object(l['lot'])['lotNumber'] ?? ''} ${dayOf(object(l['lot'])['expirationDate'])}',
                  ),
                ),
              )
              .toList(),
        ),
        ledgerView(r),
      ],
    ),
  );
}

class SupplierPaymentScreen extends StatefulWidget {
  const SupplierPaymentScreen({
    super.key,
    required this.api,
    required this.receipt,
  });
  final PurchasesService api;
  final Json receipt;
  @override
  State<SupplierPaymentScreen> createState() => _SupplierPaymentScreenState();
}

class _SupplierPaymentScreenState extends State<SupplierPaymentScreen>
    with CommerceActions {
  final _amount = TextEditingController();
  final _form = GlobalKey<FormState>();
  late Json receipt;
  bool _uncertain = false;
  @override
  void initState() {
    super.initState();
    receipt = widget.receipt;
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext viewContext) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(title: Text('Trả tiền · ${receipt['receiptCode']}')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ShiftPanel(service: widget.api, domain: 'purchases'),
            InfoRow('Tiền hàng', moneyLabel(receipt['totalAmount'])),
            InfoRow('Đã trả', moneyLabel(receipt['paidAmount'])),
            InfoRow('Còn nợ', moneyLabel(receipt['debtAmount'])),
            CommerceField(
              _amount,
              'Số tiền trả lần này',
              money: true,
              required: true,
              readOnly: busy || _uncertain,
            ),
            TextButton(
              onPressed: busy || _uncertain
                  ? null
                  : () => _amount.text = textOf(receipt['debtAmount']),
              child: const Text('Trả hết công nợ phiếu'),
            ),
            ErrorNotice(actionError),
            if (_uncertain)
              TextButton(
                onPressed: busy
                    ? null
                    : () => act(() async {
                        final current = await widget.api.receipt(
                          textOf(receipt['id']),
                        );
                        if (mounted) {
                          setState(() {
                            receipt = current;
                            _uncertain = false;
                            _amount.clear();
                          });
                        }
                      }),
                child: const Text('Tải lại phiếu để kiểm tra kết quả'),
              ),
            FilledButton(
              onPressed: busy || _uncertain
                  ? null
                  : () async {
                      if (!_form.currentState!.validate()) return;
                      final ok = await act(() async {
                        final next = paymentTotal(
                          textOf(receipt['paidAmount']),
                          _amount.text,
                          textOf(receipt['totalAmount']),
                        );
                        if (!await confirmCommerce(
                          context,
                          'Ghi nhận trả NCC?',
                          'Trả thêm ${moneyLabel(_amount.text)}. Tổng đã trả sẽ là ${moneyLabel(next)}.',
                        )) {
                          return;
                        }
                        try {
                          await widget.api.pay(textOf(receipt['id']), next);
                        } catch (_) {
                          if (mounted) setState(() => _uncertain = true);
                          rethrow;
                        }
                        if (mounted) Navigator.pop(context, true);
                      });
                      if (!ok && mounted) {
                        setState(
                          () => actionError =
                              '${actionError ?? ''}\nKiểm tra lại phiếu trước khi thử tiếp để tránh ghi nhận nhầm số tiền.',
                        );
                      }
                    },
              child: Text(busy ? 'Đang ghi nhận…' : 'Xác nhận đã trả tiền NCC'),
            ),
          ],
        ),
      ),
    ),
  );
}

class CorrectReceiptScreen extends StatefulWidget {
  const CorrectReceiptScreen({
    super.key,
    required this.api,
    required this.receipt,
  });
  final PurchasesService api;
  final Json receipt;
  @override
  State<CorrectReceiptScreen> createState() => _CorrectReceiptScreenState();
}

class _CorrectionLine {
  _CorrectionLine(this.item)
    : qty = TextEditingController(text: textOf(item['receivedQty'])),
      price = TextEditingController(text: textOf(item['actualCost']));
  final Json item;
  final TextEditingController qty, price;
  void dispose() {
    qty.dispose();
    price.dispose();
  }
}

class _CorrectReceiptScreenState extends State<CorrectReceiptScreen>
    with CommerceActions {
  final _form = GlobalKey<FormState>();
  late final List<_CorrectionLine> _lines;
  bool _uncertain = false;
  @override
  void initState() {
    super.initState();
    _lines = records(
      widget.receipt['purchaseReceiptItems'],
    ).map(_CorrectionLine.new).toList();
  }

  @override
  void dispose() {
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext viewContext) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(title: const Text('Sửa phiếu nhận')),
      body: Form(
        key: _form,
        child: AbsorbPointer(
          absorbing: busy,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Chỉ sửa lượng/giá của dòng hiện tại, giữ SKU và lô. Backend sẽ kiểm tra giao dịch kho tiếp theo và dữ liệu cũ trước khi ghi.',
              ),
              for (final l in _lines)
                CommerceCard(
                  title: variantLabel(l.item),
                  children: [
                    CommerceField(
                      l.qty,
                      'Số thực nhận',
                      required: true,
                      integer: true,
                    ),
                    CommerceField(
                      l.price,
                      'Giá thực nhận',
                      required: true,
                      money: true,
                    ),
                  ],
                ),
              ErrorNotice(actionError),
              if (_uncertain)
                const Text(
                  'Kết quả chưa xác định. Quay lại và tải lại phiếu nhận trước khi sửa tiếp.',
                ),
              FilledButton(
                onPressed: _uncertain
                    ? null
                    : () => act(() async {
                        if (!_form.currentState!.validate()) return;
                        final changes = <Json>[];
                        for (final l in _lines) {
                          final quantity = quantityOf(l.qty.text),
                              cost = Money.parse(l.price.text).toString();
                          if (quantity != l.item['receivedQty'] ||
                              Money.parse(cost).compareTo(
                                    Money.parse(l.item['actualCost']),
                                  ) !=
                                  0) {
                            changes.add({
                              'id': l.item['id'],
                              'receivedQty': quantity,
                              'actualCost': cost,
                              'expectedReceivedQty': l.item['receivedQty'],
                              'expectedActualCost': l.item['actualCost'],
                            });
                          }
                        }
                        if (changes.isEmpty) {
                          throw const FormatException('Chưa có dòng thay đổi.');
                        }
                        if (!await confirmCommerce(
                          context,
                          'Lưu điều chỉnh phiếu nhận?',
                          'Điều chỉnh ${changes.length} dòng, tồn kho, giá vốn và công nợ liên quan?',
                        )) {
                          return;
                        }
                        try {
                          await widget.api.correct(widget.receipt, changes);
                        } catch (_) {
                          if (mounted) setState(() => _uncertain = true);
                          rethrow;
                        }
                        if (mounted) Navigator.pop(context, true);
                      }),
                child: const Text('Xác nhận sửa phiếu nhận'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
