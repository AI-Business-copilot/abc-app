import 'package:flutter/material.dart';
import '../../auth/services/auth_service.dart';
import '../../commerce/models/commerce_models.dart';
import '../../commerce/services/commerce_service.dart';
import '../../commerce/widgets/commerce_widgets.dart';
import 'sale_receipt.dart';

class SaleDetailScreen extends StatefulWidget {
  const SaleDetailScreen({
    super.key,
    required this.api,
    required this.id,
    this.notice,
  });
  final SalesService api;
  final String id;
  final String? notice;
  @override
  State<SaleDetailScreen> createState() => _SaleDetailScreenState();
}

class _SaleDetailScreenState extends State<SaleDetailScreen> {
  bool autoPrintRequested = false;
  @override
  Widget build(BuildContext viewContext) => RemoteDetail(
    title: 'Chi tiết đơn bán',
    load: () => widget.api.order(widget.id),
    builder: (order, reload) => _SaleView(
      key: ValueKey('${order['id']}:${order['status']}'),
      api: widget.api,
      order: order,
      reload: reload,
      notice: widget.notice,
      automaticPrint: autoPrintRequested,
      onPaid: () {
        setState(() => autoPrintRequested = true);
        reload();
      },
    ),
  );
}

class _SaleView extends StatefulWidget {
  const _SaleView({
    super.key,
    required this.api,
    required this.order,
    required this.reload,
    required this.onPaid,
    required this.automaticPrint,
    this.notice,
  });
  final SalesService api;
  final Json order;
  final VoidCallback reload, onPaid;
  final bool automaticPrint;
  final String? notice;
  @override
  State<_SaleView> createState() => _SaleViewState();
}

class _SaleViewState extends State<_SaleView> with CommerceActions {
  String _method = 'CASH';
  final _received = TextEditingController(),
      _reference = TextEditingController();
  bool _confirmed = false, _uncertain = false;
  String? _printInfo;
  late Future<Json?> _shift;
  @override
  void initState() {
    super.initState();
    _shift = widget.api.shift('sales');
    if (widget.automaticPrint && widget.order['status'] == 'COMPLETED') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          act(() async {
            if (await SaleReceipt.claimAutomatic(textOf(widget.order['id']))) {
              await printReceipt();
            }
          });
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant _SaleView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.order != widget.order) {
      _confirmed = false;
      _uncertain = false;
      _shift = widget.api.shift('sales');
    }
  }

  @override
  void dispose() {
    _received.dispose();
    _reference.dispose();
    super.dispose();
  }

  String? get change {
    try {
      final received = Money.parse(_received.text),
          due = Money.parse(widget.order['totalNetAmount']);
      return received.compareTo(due) < 0 ? null : (received - due).toString();
    } on FormatException {
      return null;
    }
  }

  Future<void> printReceipt() async {
    final result = await SaleReceipt.print(widget.order);
    if (mounted) {
      setState(
        () => _printInfo = result
            ? 'Đã gửi lệnh in. Kiểm tra giấy tại máy in.'
            : 'Đã đóng hộp thoại in. Có thể in lại từ đơn này.',
      );
    }
  }

  @override
  Widget build(BuildContext viewContext) {
    final o = widget.order;
    final completed = o['status'] == 'COMPLETED';
    final free = Money.parse(o['totalNetAmount']).isZero;
    final writable =
        canSaleWrite &&
        o['cashierId'] == AuthService.userId &&
        o['status'] == 'DRAFT';
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        CommerceCard(
          title: textOf(o['orderCode']),
          children: [
            InfoRow('Trạng thái', statusLabel(o['status'])),
            InfoRow('Ngày tạo', o['createdAt']),
            InfoRow(
              'Khách hàng',
              object(o['customer'])['name'] ?? 'Khách vãng lai',
            ),
            if (o['customer'] != null)
              InfoRow('Số điện thoại', object(o['customer'])['phone']),
            InfoRow('Tiền hàng', moneyLabel(o['totalGrossAmount'])),
            InfoRow(
              object(o['promotionSnapshot'])['name']?.toString() ?? 'Giảm giá',
              moneyLabel(o['discountAmount']),
            ),
            InfoRow(
              completed ? 'Đã thu / hoàn tất' : 'Tổng cần thu',
              moneyLabel(o['totalNetAmount']),
            ),
          ],
        ),
        if (!completed && widget.notice != null) ErrorNotice(widget.notice),
        if (completed) ...[
          Text(
            free
                ? 'Đơn đã hoàn tất bằng khuyến mãi 100%; đã xuất kho.'
                : 'Đã ghi nhận thanh toán và xuất kho.',
          ),
          FilledButton.tonalIcon(
            onPressed: busy ? null : () => act(printReceipt),
            icon: const Icon(Icons.print_outlined),
            label: const Text('In hóa đơn / In lại'),
          ),
          if (_printInfo != null) Text(_printInfo!),
        ],
        ErrorNotice(actionError),
        if (_uncertain) ...[
          const Text(
            'Chưa xác định được kết quả thao tác. Tải lại đơn và kiểm tra tiền đã nhận trước khi thử tiếp.',
          ),
          TextButton(
            onPressed: busy ? null : widget.reload,
            child: const Text('Tải lại trạng thái đơn'),
          ),
        ],
        CommerceCard(
          title: 'Sản phẩm & phân bổ lô',
          children: [
            ...records(o['orderItems']).map(
              (l) => ListTile(
                title: Text(variantLabel(l)),
                subtitle: Text(
                  '${l['quantity']} × ${moneyLabel(l['unitPrice'])} = ${moneyLabel(l['subtotal'])}\nGiảm ${moneyLabel(l['discountAmount'])}${l['lotItem'] == null ? '' : '\nLô ${object(object(l['lotItem'])['lot'])['lotNumber']} · HSD ${dayOf(object(l['lotItem'])['expirationDate'])}'}',
                ),
              ),
            ),
            const Text(
              'Lô còn hạn gần nhất được chọn khi thanh toán; hàng hỏng và lô hết hạn không được bán.',
            ),
          ],
        ),
        if (writable)
          CommerceCard(
            title: free ? 'Hoàn tất đơn miễn phí' : 'Thanh toán',
            children: [
              FutureBuilder<Json?>(
                future: _shift,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const LinearProgressIndicator();
                  }
                  if (snapshot.hasError) {
                    return ErrorNotice(errorLabel(snapshot.error!));
                  }
                  final matchingShift =
                      snapshot.data?['id'] == o['shiftId'] &&
                      snapshot.data?['status'] == 'OPEN';
                  if (!matchingShift) {
                    return const Text(
                      'Chỉ thanh toán/hủy trong ca gốc đang mở của người tạo. Kiểm tra lại ca.',
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!free) ...[
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(
                              value: 'CASH',
                              label: Text('Tiền mặt'),
                            ),
                            ButtonSegment(
                              value: 'BANK_TRANSFER',
                              label: Text('Chuyển khoản'),
                            ),
                          ],
                          selected: {_method},
                          onSelectionChanged: busy || _uncertain
                              ? null
                              : (v) => setState(() {
                                  _method = v.first;
                                  _confirmed = false;
                                }),
                        ),
                        if (_method == 'CASH') ...[
                          CommerceField(
                            _received,
                            'Tiền khách đưa',
                            money: true,
                            required: true,
                            readOnly: busy || _uncertain,
                            onChanged: (_) =>
                                setState(() => _confirmed = false),
                          ),
                          Wrap(
                            children: [
                              TextButton(
                                onPressed: busy || _uncertain
                                    ? null
                                    : () => setState(() {
                                        _received.text = textOf(
                                          o['totalNetAmount'],
                                        );
                                        _confirmed = false;
                                      }),
                                child: const Text('Đủ tiền'),
                              ),
                              for (final v in [50000, 100000, 200000, 500000])
                                if (Money.parse(v).compareTo(
                                      Money.parse(o['totalNetAmount']),
                                    ) >
                                    0)
                                  TextButton(
                                    onPressed: busy || _uncertain
                                        ? null
                                        : () => setState(() {
                                            _received.text = '$v';
                                            _confirmed = false;
                                          }),
                                    child: Text(moneyLabel(v)),
                                  ),
                            ],
                          ),
                          InfoRow(
                            'Trả lại khách',
                            change == null
                                ? 'Chưa đủ / chưa hợp lệ'
                                : moneyLabel(change),
                          ),
                          const Text(
                            'Hệ thống chỉ ghi nhận đúng tổng đơn; tiền khách đưa và tiền thừa dùng để tính tại quầy.',
                          ),
                        ] else ...[
                          CommerceField(
                            _reference,
                            'Mã giao dịch (tùy chọn)',
                            maxLength: 100,
                            readOnly: busy || _uncertain,
                            onChanged: (_) =>
                                setState(() => _confirmed = false),
                          ),
                          const Text(
                            'Kiểm tra tiền thực tế đã vào tài khoản trước khi xác nhận.',
                          ),
                        ],
                      ],
                      CheckboxListTile(
                        value: _confirmed,
                        onChanged: busy || _uncertain
                            ? null
                            : (v) => setState(() => _confirmed = v == true),
                        title: Text(
                          free
                              ? 'Tôi xác nhận hoàn tất đơn giảm 100%.'
                              : 'Tôi đã kiểm tra và nhận đủ ${moneyLabel(o['totalNetAmount'])}.',
                        ),
                      ),
                      FilledButton(
                        onPressed:
                            busy ||
                                _uncertain ||
                                !_confirmed ||
                                (!free && _method == 'CASH' && change == null)
                            ? null
                            : () => act(() async {
                                try {
                                  await widget.api.pay(
                                    o,
                                    method: _method,
                                    reference: _method == 'BANK_TRANSFER'
                                        ? _reference.text
                                        : '',
                                  );
                                } catch (_) {
                                  if (mounted) {
                                    setState(() {
                                      _uncertain = true;
                                      _confirmed = false;
                                    });
                                  }
                                  rethrow;
                                }
                                if (mounted) widget.onPaid();
                              }),
                        child: Text(
                          busy
                              ? 'Đang xử lý…'
                              : free
                              ? 'Hoàn tất & xuất kho'
                              : 'Xác nhận thanh toán & xuất kho',
                        ),
                      ),
                      TextButton(
                        onPressed: busy || _uncertain
                            ? null
                            : () async {
                                if (!await confirmCommerce(
                                  context,
                                  'Hủy đơn nháp?',
                                  'Đơn chưa thanh toán sẽ được hủy; không trừ kho.',
                                )) {
                                  return;
                                }
                                await act(() async {
                                  try {
                                    await widget.api.cancel(textOf(o['id']));
                                  } catch (_) {
                                    if (mounted) {
                                      setState(() => _uncertain = true);
                                    }
                                    rethrow;
                                  }
                                  if (mounted) widget.reload();
                                });
                              },
                        child: const Text('Hủy đơn nháp'),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        if (o['status'] == 'DRAFT' && !writable)
          const Text(
            'Chỉ người tạo đơn có quyền tạo đơn bán mới được thanh toán hoặc hủy.',
          ),
        CommerceCard(
          title: 'Lịch sử thanh toán',
          children: [
            if (records(o['orderPayments']).isEmpty)
              const Text('Chưa có khoản thanh toán.'),
            ...records(o['orderPayments']).map(
              (p) => ListTile(
                title: Text(
                  '${p['paymentMethod'] == 'CASH'
                      ? 'Tiền mặt'
                      : p['paymentMethod'] == 'PROMOTION'
                      ? 'Khuyến mãi 100%'
                      : 'Chuyển khoản'} · ${moneyLabel(p['amount'])}',
                ),
                subtitle: Text(
                  '${p['createdAt']} · ${p['paymentReference'] ?? ''}',
                ),
              ),
            ),
          ],
        ),
        ledgerView(o),
      ],
    );
  }
}
