import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/network/api_error.dart';
import '../../../core/auth/permission_gate.dart';
import '../../auth/services/auth_service.dart';
import '../models/commerce_models.dart';
import '../services/commerce_service.dart';

bool get canPurchaseRead =>
    AuthService.hasPermission('inventory.read') &&
    AuthService.hasPermission('finance.read');
bool get canPurchaseWrite =>
    canPurchaseRead && AuthService.hasPermission('inventory.receive');
bool get canSaleWrite =>
    AuthService.hasPermission('orders.read') &&
    AuthService.hasPermission('orders.create');
String moneyLabel(Object? value) {
  final parsed = num.tryParse(textOf(value));
  return parsed == null
      ? '—'
      : '${NumberFormat('#,##0.##', 'vi_VN').format(parsed)} đ';
}

String statusLabel(Object? value) =>
    const {
      'DRAFT': 'Nháp',
      'ORDERED': 'Đã đặt',
      'PARTIALLY_RECEIVED': 'Nhận một phần',
      'COMPLETED': 'Hoàn tất',
      'CLOSED_SHORT': 'Đóng thiếu',
      'CANCELLED': 'Đã hủy',
      'RECEIVED': 'Đã nhận',
      'OPEN': 'Đang mở',
    }[value] ??
    textOf(value);
String errorLabel(Object error) =>
    error is FormatException ? error.message : apiErrorMessage(error);

Future<T?> openCommerce<T>(BuildContext context, Widget screen) =>
    Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => screen));
Future<bool> confirmCommerce(
  BuildContext context,
  String title,
  String message,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Quay lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    ) ??
    false;

/// Serializes user actions and keeps errors visible without discarding form input.
mixin CommerceActions<T extends StatefulWidget> on State<T> {
  bool busy = false;
  String? actionError;
  Future<bool> act(Future<void> Function() action) async {
    if (busy) return false;
    setState(() {
      busy = true;
      actionError = null;
    });
    try {
      await action();
      return true;
    } catch (error) {
      if (mounted) setState(() => actionError = errorLabel(error));
      return false;
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}

class ErrorNotice extends StatelessWidget {
  const ErrorNotice(this.message, {super.key});
  final String? message;
  @override
  Widget build(BuildContext context) => message == null || message!.isEmpty
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            message!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        );
}

class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.value, {super.key});
  final String label;
  final Object? value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label)),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            textOf(value),
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

class CommerceCard extends StatelessWidget {
  const CommerceCard({super.key, required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    ),
  );
}

class CommerceField extends StatelessWidget {
  const CommerceField(
    this.controller,
    this.label, {
    super.key,
    this.required = false,
    this.money = false,
    this.integer = false,
    this.maxLength,
    this.readOnly = false,
    this.onChanged,
    this.validator,
  });
  final TextEditingController controller;
  final String label;
  final bool required, money, integer, readOnly;
  final int? maxLength;
  final ValueChanged<String>? onChanged;
  final String? Function(String?)? validator;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: TextFormField(
      controller: controller,
      readOnly: readOnly,
      maxLength: maxLength,
      onChanged: onChanged,
      keyboardType: money
          ? const TextInputType.numberWithOptions(decimal: true)
          : integer
          ? TextInputType.number
          : TextInputType.text,
      decoration: InputDecoration(
        labelText: '$label${required ? ' *' : ''}',
        helperText: money ? 'Ví dụ: 12500 hoặc 12500.50' : null,
        border: const OutlineInputBorder(),
      ),
      validator:
          validator ??
          (value) {
            if (required && (value == null || value.trim().isEmpty)) {
              return 'Vui lòng nhập $label.';
            }
            try {
              if (money && value!.isNotEmpty) Money.parse(value);
              if (integer && value!.isNotEmpty) quantityOf(value);
            } on FormatException catch (e) {
              return e.message;
            }
            return null;
          },
    ),
  );
}

class DateField extends StatelessWidget {
  const DateField(
    this.controller,
    this.label, {
    super.key,
    this.required = false,
  });
  final TextEditingController controller;
  final String label;
  final bool required;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: TextFormField(
      controller: controller,
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          tooltip: 'Bỏ ngày',
          onPressed: required ? null : controller.clear,
          icon: const Icon(Icons.clear),
        ),
      ),
      validator: (value) =>
          required && (value?.isEmpty ?? true) ? 'Vui lòng chọn $label.' : null,
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: DateTime.tryParse(controller.text) ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (date != null) {
          controller.text = DateFormat('yyyy-MM-dd').format(date);
        }
      },
    ),
  );
}

class RemoteDetail extends StatefulWidget {
  const RemoteDetail({
    super.key,
    required this.title,
    required this.load,
    required this.builder,
  });
  final String title;
  final Future<Json> Function() load;
  final Widget Function(Json data, VoidCallback reload) builder;
  @override
  State<RemoteDetail> createState() => _RemoteDetailState();
}

class _RemoteDetailState extends State<RemoteDetail> {
  late Future<Json> _future;
  @override
  void initState() {
    super.initState();
    _future = widget.load();
  }

  void reload() => setState(() {
    _future = widget.load();
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.title),
      actions: [
        IconButton(
          onPressed: reload,
          tooltip: 'Tải lại',
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: FutureBuilder<Json>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ErrorNotice(errorLabel(snapshot.error!)),
                TextButton(onPressed: reload, child: const Text('Thử lại')),
              ],
            ),
          );
        }
        return widget.builder(snapshot.data!, reload);
      },
    ),
  );
}

class CommerceList extends StatefulWidget {
  const CommerceList({
    super.key,
    required this.load,
    required this.tile,
    this.statuses = const [],
    this.activeFilter = false,
    this.dates = true,
    this.extra = const {},
    this.header,
    this.supplierFilter = false,
  });
  final Future<CommercePage> Function(Json query) load;
  final Widget Function(Json item, VoidCallback reload) tile;
  final List<String> statuses;
  final bool activeFilter, dates, supplierFilter;
  final Json extra;
  final Widget? header;
  @override
  State<CommerceList> createState() => _CommerceListState();
}

class _CommerceListState extends State<CommerceList> {
  final _search = TextEditingController(),
      _from = TextEditingController(),
      _to = TextEditingController();
  String _term = '', _status = '', _active = 'all';
  Json? _supplier;
  int _page = 1;
  late Future<CommercePage> _future;
  @override
  void initState() {
    super.initState();
    _future = fetch();
  }

  Future<CommercePage> fetch() => widget.load({
    'page': _page,
    'pageSize': 20,
    'search': _term,
    if (_status.isNotEmpty) 'status': _status,
    if (widget.activeFilter) 'isActive': _active,
    if (_from.text.isNotEmpty) 'from': _from.text,
    if (_to.text.isNotEmpty) 'to': _to.text,
    if (_supplier != null) 'supplierId': _supplier!['id'],
    ...widget.extra,
  });
  void reload() => setState(() {
    _future = fetch();
  });
  void filter() {
    if (_from.text.isNotEmpty &&
        _to.text.isNotEmpty &&
        _from.text.compareTo(_to.text) > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ngày bắt đầu phải trước hoặc bằng ngày kết thúc.'),
        ),
      );
      return;
    }
    _term = _search.text.trim();
    _page = 1;
    reload();
  }

  @override
  void dispose() {
    _search.dispose();
    _from.dispose();
    _to.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      if (widget.header != null) widget.header!,
      Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              controller: _search,
              maxLength: 255,
              decoration: InputDecoration(
                labelText: 'Tìm kiếm',
                counterText: '',
                suffixIcon: IconButton(
                  tooltip: 'Tìm',
                  onPressed: filter,
                  icon: const Icon(Icons.search),
                ),
              ),
              onSubmitted: (_) => filter(),
            ),
            Row(
              children: [
                if (widget.statuses.isNotEmpty)
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _status,
                      decoration: const InputDecoration(
                        labelText: 'Trạng thái',
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('Tất cả'),
                        ),
                        ...widget.statuses.map(
                          (s) => DropdownMenuItem(
                            value: s,
                            child: Text(statusLabel(s)),
                          ),
                        ),
                      ],
                      onChanged: (v) {
                        _status = v!;
                        filter();
                      },
                    ),
                  ),
                if (widget.activeFilter)
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _active,
                      decoration: const InputDecoration(labelText: 'Hoạt động'),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('Tất cả')),
                        DropdownMenuItem(
                          value: 'true',
                          child: Text('Đang hoạt động'),
                        ),
                        DropdownMenuItem(
                          value: 'false',
                          child: Text('Ngừng hoạt động'),
                        ),
                      ],
                      onChanged: (v) {
                        _active = v!;
                        filter();
                      },
                    ),
                  ),
                IconButton(
                  tooltip: 'Tải lại',
                  onPressed: reload,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            if (widget.supplierFilter)
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () async {
                        final supplier = await openCommerce<Json>(
                          context,
                          RecordPicker(
                            title: 'Lọc nhà cung cấp',
                            load: PurchasesService().suppliers,
                            label: (s) => textOf(s['name']),
                          ),
                        );
                        if (supplier != null && mounted) {
                          _supplier = supplier;
                          filter();
                        }
                      },
                      child: Text(
                        _supplier == null
                            ? 'Tất cả nhà cung cấp'
                            : textOf(_supplier!['name']),
                      ),
                    ),
                  ),
                  if (_supplier != null)
                    IconButton(
                      onPressed: () {
                        _supplier = null;
                        filter();
                      },
                      icon: const Icon(Icons.clear),
                    ),
                ],
              ),
            if (widget.dates)
              ExpansionTile(
                title: const Text('Lọc theo ngày'),
                children: [
                  Row(
                    children: [
                      Expanded(child: DateField(_from, 'Từ ngày')),
                      const SizedBox(width: 8),
                      Expanded(child: DateField(_to, 'Đến ngày')),
                    ],
                  ),
                  TextButton(
                    onPressed: filter,
                    child: const Text('Áp dụng ngày'),
                  ),
                ],
              ),
          ],
        ),
      ),
      Expanded(
        child: FutureBuilder<CommercePage>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ErrorNotice(errorLabel(snapshot.error!)),
                    TextButton(onPressed: reload, child: const Text('Thử lại')),
                  ],
                ),
              );
            }
            final result = snapshot.data!;
            return Column(
              children: [
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      reload();
                      await _future;
                    },
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(8),
                      children: [
                        if (result.items.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(24),
                            child: Text('Chưa có dữ liệu phù hợp.'),
                          ),
                        ...result.items.map(
                          (item) => widget.tile(item, reload),
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      tooltip: 'Trang trước',
                      onPressed: _page > 1
                          ? () {
                              _page--;
                              reload();
                            }
                          : null,
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Text(
                      '$_page / ${result.totalPages == 0 ? 1 : result.totalPages} · ${result.total} mục',
                    ),
                    IconButton(
                      tooltip: 'Trang sau',
                      onPressed: _page < result.totalPages
                          ? () {
                              _page++;
                              reload();
                            }
                          : null,
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    ],
  );
}

class RecordPicker extends StatelessWidget {
  const RecordPicker({
    super.key,
    required this.title,
    required this.load,
    required this.label,
    this.extra = const {},
    this.enabled,
  });
  final String title;
  final Future<CommercePage> Function(Json query) load;
  final String Function(Json row) label;
  final Json extra;
  final bool Function(Json row)? enabled;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: CommerceList(
      load: load,
      extra: extra,
      dates: false,
      tile: (item, _) => ListTile(
        title: Text(label(item)),
        enabled: enabled?.call(item) ?? true,
        onTap: (enabled?.call(item) ?? true)
            ? () => Navigator.pop(context, item)
            : null,
      ),
    ),
  );
}

class VariantPicker extends StatefulWidget {
  const VariantPicker({super.key, required this.service, this.onSelect});
  final CommerceService service;
  final ValueChanged<Json>? onSelect;
  @override
  State<VariantPicker> createState() => _VariantPickerState();
}

class _VariantPickerState extends State<VariantPicker> {
  String _category = '', _search = '';
  bool _inStock = false;
  final _controller = TextEditingController();
  late Future<Json> _future;
  @override
  void initState() {
    super.initState();
    _future = widget.service.variants('');
  }

  void reload() => setState(() {
    _future = widget.service.variants(_search, categoryId: _category);
  });
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!AuthService.hasPermission('inventory.read')) {
      return const Scaffold(body: PermissionDeniedView());
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Chọn SKU')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: 'Tên, SKU hoặc mã vạch',
                suffixIcon: IconButton(
                  onPressed: () {
                    _search = _controller.text.trim();
                    reload();
                  },
                  icon: const Icon(Icons.search),
                ),
              ),
              onSubmitted: (v) {
                _search = v.trim();
                reload();
              },
            ),
          ),
          Expanded(
            child: FutureBuilder<Json>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Column(
                    children: [
                      ErrorNotice(errorLabel(snapshot.error!)),
                      TextButton(
                        onPressed: reload,
                        child: const Text('Thử lại'),
                      ),
                    ],
                  );
                }
                final data = snapshot.data!;
                final items = records(data['items'])
                    .where((v) => !_inStock || (v['onHand'] as num? ?? 0) > 0)
                    .toList();
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        key: ValueKey(_category),
                        initialValue: _category,
                        decoration: const InputDecoration(
                          labelText: 'Danh mục',
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: '',
                            child: Text('Tất cả'),
                          ),
                          ...records(data['categories']).map(
                            (c) => DropdownMenuItem(
                              value: textOf(c['id']),
                              child: Text(textOf(c['name'])),
                            ),
                          ),
                        ],
                        onChanged: (v) {
                          _category = v!;
                          reload();
                        },
                      ),
                    ),
                    SwitchListTile(
                      title: const Text('Chỉ hiện hàng còn tồn'),
                      value: _inStock,
                      onChanged: (v) => setState(() => _inStock = v),
                    ),
                    Expanded(
                      child: ListView(
                        children: [
                          if ((data['total'] as num? ?? 0) > 100)
                            const Padding(
                              padding: EdgeInsets.all(12),
                              child: Text(
                                'Hiện 100 SKU đầu tiên. Dùng từ khóa cụ thể để tìm thêm.',
                              ),
                            ),
                          if (items.isEmpty)
                            const ListTile(
                              title: Text('Không có SKU phù hợp.'),
                            ),
                          ...items.map(
                            (v) => ListTile(
                              title: Text('${v['sku']} · ${v['productName']}'),
                              subtitle: Text(
                                'Tồn: ${v['onHand']} · Giá: ${moneyLabel(v['basePrice'])}',
                              ),
                              trailing: v['hasLotTracking'] == true
                                  ? IconButton(
                                      tooltip: 'Xem lô',
                                      icon: const Icon(Icons.layers_outlined),
                                      onPressed: () => openCommerce(
                                        context,
                                        RemoteDetail(
                                          title: 'Lô · ${v['sku']}',
                                          load: () => widget.service.lots(
                                            textOf(v['id']),
                                          ),
                                          builder: (lots, _) => ListView(
                                            children: [
                                              const ListTile(
                                                title: Text(
                                                  'Lô còn hạn gần nhất sẽ được chọn khi thanh toán. Tồn lô chưa loại hàng hỏng.',
                                                ),
                                              ),
                                              ...records(lots['lots']).map(
                                                (lot) => ListTile(
                                                  title: Text(
                                                    textOf(lot['lotNumber']),
                                                  ),
                                                  subtitle: Text(
                                                    '${dayOf(lot['expirationDate'])} · Tồn ${lot['quantityOnHand']}',
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    )
                                  : null,
                              onTap: () {
                                if (widget.onSelect != null) {
                                  widget.onSelect!(v);
                                } else {
                                  Navigator.pop(context, v);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class ShiftPanel extends StatefulWidget {
  const ShiftPanel({super.key, required this.service, required this.domain});
  final CommerceService service;
  final String domain;
  @override
  State<ShiftPanel> createState() => _ShiftPanelState();
}

class _ShiftPanelState extends State<ShiftPanel> with CommerceActions {
  final _opening = TextEditingController(text: '0');
  late Future<Json?> _future;
  @override
  void initState() {
    super.initState();
    reload();
  }

  void reload() => setState(() {
    _future = widget.service.shift(widget.domain);
  });
  @override
  void dispose() {
    _opening.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CommerceCard(
    title: 'Ca của bạn',
    children: [
      FutureBuilder<Json?>(
        future: _future,
        builder: (context, s) {
          if (s.connectionState != ConnectionState.done) {
            return const LinearProgressIndicator();
          }
          if (s.hasError) return ErrorNotice(errorLabel(s.error!));
          final shift = s.data;
          if (shift != null) {
            return Column(
              children: [
                InfoRow('Đang mở từ', textOf(shift['openedAt'])),
                InfoRow('Tiền đầu ca', moneyLabel(shift['openingCash'])),
                if (dayOf(shift['openedAt']).compareTo(shopToday()) < 0)
                  const Text(
                    'Ca được mở từ ngày trước. Kiểm tra ca trước khi tiếp tục.',
                  ),
              ],
            );
          }
          return Column(
            children: [
              const Text('Chưa có ca mở. Cần mở ca trước khi thu/chi tiền.'),
              if (widget.domain == 'sales'
                  ? canSaleWrite
                  : canPurchaseWrite) ...[
                CommerceField(_opening, 'Tiền đầu ca', money: true),
                FilledButton(
                  onPressed: busy
                      ? null
                      : () => act(() async {
                          await widget.service.openShift(
                            widget.domain,
                            _opening.text,
                          );
                          reload();
                        }),
                  child: const Text('Mở / lấy ca hiện có'),
                ),
              ],
            ],
          );
        },
      ),
      ErrorNotice(actionError),
      TextButton(
        onPressed: busy ? null : reload,
        child: const Text('Kiểm tra lại ca'),
      ),
    ],
  );
}

Widget ledgerView(Json record) => ExpansionTile(
  title: Text(
    'Lịch sử kho · ${records(record['inventoryLedger']).length} bút toán',
  ),
  children: records(record['inventoryLedger'])
      .map(
        (entry) => ListTile(
          title: Text(
            '${entry['transactionType']} · ${entry['quantityChanged']}',
          ),
          subtitle: Text(
            '${entry['createdAt']}\nTồn sau: ${entry['balanceAfter']}',
          ),
        ),
      )
      .toList(),
);
