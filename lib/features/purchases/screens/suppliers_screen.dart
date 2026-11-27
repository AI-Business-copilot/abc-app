import 'dart:typed_data';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import '../../auth/services/auth_service.dart';
import '../../commerce/models/commerce_models.dart';
import '../../commerce/services/commerce_service.dart';
import '../../commerce/widgets/commerce_widgets.dart';
import 'purchase_order_screens.dart';
import 'purchase_receipt_screens.dart';

class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key});
  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  final api = PurchasesService();
  int revision = 0;
  @override
  Widget build(BuildContext viewContext) {
    return CommerceList(
      key: ValueKey(revision),
      load: api.suppliers,
      activeFilter: true,
      dates: false,
      header: canPurchaseWrite
          ? TextButton.icon(
              onPressed: () async {
                await openCommerce(context, SupplierEditor(api: api));
                if (mounted) setState(() => revision++);
              },
              icon: const Icon(Icons.add),
              label: const Text('Thêm nhà cung cấp'),
            )
          : null,
      tile: (s, reload) => Card(
        child: ListTile(
          title: Text('${s['name']} · ${s['supplierCode'] ?? ''}'),
          subtitle: Text(
            '${s['phone'] ?? ''} · ${s['isActive'] == true ? 'Đang hợp tác' : 'Ngừng hợp tác'}\nCông nợ: ${moneyLabel(s['debtAmount'])}',
          ),
          isThreeLine: true,
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            await openCommerce(context, SupplierDetail(api: api, supplier: s));
            reload();
          },
        ),
      ),
    );
  }
}

class SupplierEditor extends StatefulWidget {
  const SupplierEditor({super.key, required this.api, this.supplier});
  final PurchasesService api;
  final Json? supplier;
  @override
  State<SupplierEditor> createState() => _SupplierEditorState();
}

class _SupplierEditorState extends State<SupplierEditor> with CommerceActions {
  final _form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> fields;
  late bool _active;
  late final String _code;
  String? _lookupInfo;
  static const labels = {
    'name': 'Tên nhà cung cấp',
    'taxCode': 'Mã số thuế',
    'address': 'Địa chỉ',
    'contactPerson': 'Người liên hệ',
    'phone': 'Số điện thoại',
    'email': 'Email',
    'note': 'Ghi chú',
  };
  static const lengths = {
    'name': 255,
    'taxCode': 30,
    'address': 5000,
    'contactPerson': 100,
    'phone': 20,
    'email': 255,
    'note': 5000,
  };
  @override
  void initState() {
    super.initState();
    fields = {
      for (final key in labels.keys)
        key: TextEditingController(text: textOf(widget.supplier?[key])),
    };
    _active = widget.supplier?['isActive'] != false;
    _code = textOf(widget.supplier?['supplierCode'] ?? documentCode('NCC'));
  }

  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext viewContext) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          widget.supplier == null ? 'Thêm nhà cung cấp' : 'Sửa nhà cung cấp',
        ),
      ),
      body: Form(
        key: _form,
        child: AbsorbPointer(
          absorbing: busy,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Mã NCC: $_code'),
              for (final entry in labels.entries) ...[
                CommerceField(
                  fields[entry.key]!,
                  entry.value,
                  required: entry.key == 'name',
                  maxLength: lengths[entry.key],
                  validator: entry.key == 'email'
                      ? (v) =>
                            v != null &&
                                v.isNotEmpty &&
                                !RegExp(
                                  r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                                ).hasMatch(v.trim())
                            ? 'Email không hợp lệ.'
                            : null
                      : null,
                ),
                if (entry.key == 'taxCode')
                  TextButton(
                    onPressed: () => act(() async {
                      final result = await widget.api.lookupTax(
                        fields['taxCode']!.text.trim(),
                      );
                      if (!mounted) return;
                      fields['name']!.text = textOf(result['name']);
                      fields['address']!.text = textOf(result['address']);
                      setState(
                        () => _lookupInfo =
                            'Đã lấy tên và địa chỉ từ ${result['source']}. Kiểm tra lại trước khi lưu.',
                      );
                    }),
                    child: const Text('Tra cứu tên / địa chỉ từ mã số thuế'),
                  ),
              ],
              if (_lookupInfo != null) Text(_lookupInfo!),
              SwitchListTile(
                title: const Text('Đang hợp tác'),
                subtitle: const Text(
                  'Ngừng hợp tác chặn đặt mua mới; vẫn nhận hàng và trả tiền cho đơn cũ.',
                ),
                value: _active,
                onChanged: (v) => setState(() => _active = v),
              ),
              ErrorNotice(actionError),
              FilledButton(
                onPressed: () => act(() async {
                  if (!_form.currentState!.validate()) return;
                  final payload = <String, dynamic>{
                    for (final e in fields.entries)
                      e.key: e.value.text.trim().isEmpty
                          ? null
                          : e.value.text.trim(),
                    'isActive': _active,
                    if (widget.supplier == null) 'supplierCode': _code,
                  };
                  final saved = await widget.api.saveSupplier(
                    payload,
                    id: widget.supplier?['id'],
                  );
                  if (mounted) Navigator.pop(context, saved);
                }),
                child: Text(busy ? 'Đang lưu…' : 'Lưu nhà cung cấp'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class SupplierDetail extends StatefulWidget {
  const SupplierDetail({super.key, required this.api, required this.supplier});
  final PurchasesService api;
  final Json supplier;
  @override
  State<SupplierDetail> createState() => _SupplierDetailState();
}

class _SupplierDetailState extends State<SupplierDetail> with CommerceActions {
  late Json supplier;
  @override
  void initState() {
    super.initState();
    supplier = {...widget.supplier};
  }

  @override
  Widget build(BuildContext viewContext) => Scaffold(
    appBar: AppBar(title: Text(textOf(supplier['name']))),
    body: ListView(
      padding: const EdgeInsets.all(12),
      children: [
        CommerceCard(
          title: 'Hồ sơ nhà cung cấp',
          children: [
            for (final entry in {
              'supplierCode': 'Mã NCC',
              ..._SupplierEditorState.labels,
            }.entries)
              InfoRow(entry.value, supplier[entry.key]),
            InfoRow(
              'Hợp tác',
              supplier['isActive'] == true ? 'Đang hoạt động' : 'Đã ngừng',
            ),
            InfoRow('Công nợ', moneyLabel(supplier['debtAmount'])),
            if (canPurchaseWrite)
              TextButton(
                onPressed: () async {
                  final updated = await openCommerce<Json>(
                    context,
                    SupplierEditor(api: widget.api, supplier: supplier),
                  );
                  if (updated != null && mounted) {
                    setState(() => supplier = updated);
                  }
                },
                child: const Text('Sửa hồ sơ'),
              ),
          ],
        ),
        FilledButton.tonal(
          onPressed: () => openCommerce(
            context,
            SupplierProductsScreen(api: widget.api, supplier: supplier),
          ),
          child: const Text('Danh mục cung cấp & lịch sử nhập'),
        ),
        TextButton(
          onPressed: () => openCommerce(
            context,
            RemoteDetail(
              title: 'Đối chiếu công nợ',
              load: () => widget.api.reconciliation(textOf(supplier['id'])),
              builder: (data, reload) => DebtPreview(
                api: widget.api,
                preview: data,
                onApplied: () {
                  setState(
                    () => supplier['debtAmount'] = data['calculatedDebtAmount'],
                  );
                  reload();
                },
              ),
            ),
          ),
          child: const Text('Đối chiếu công nợ từ chứng từ'),
        ),
        ErrorNotice(actionError),
      ],
    ),
  );
}

class DebtPreview extends StatefulWidget {
  const DebtPreview({
    super.key,
    required this.api,
    required this.preview,
    required this.onApplied,
  });
  final PurchasesService api;
  final Json preview;
  final VoidCallback onApplied;
  @override
  State<DebtPreview> createState() => _DebtPreviewState();
}

class _DebtPreviewState extends State<DebtPreview> with CommerceActions {
  @override
  Widget build(BuildContext viewContext) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      const Text(
        'Công nợ tính từ phiếu nhận trừ giá trị trả NCC đã hoàn tất. Không gồm điều chỉnh ngoài chứng từ.',
      ),
      for (final entry in {
        'storedDebtAmount': 'Đang lưu',
        'receiptDebtAmount': 'Nợ phiếu nhận',
        'vendorReturnCreditAmount': 'Giá trị trả NCC',
        'calculatedDebtAmount': 'Công nợ tính lại',
        'difference': 'Chênh lệch',
      }.entries)
        InfoRow(entry.value, moneyLabel(widget.preview[entry.key])),
      ErrorNotice(actionError),
      if (canPurchaseWrite)
        FilledButton(
          onPressed: busy
              ? null
              : () async {
                  if (!await confirmCommerce(
                    context,
                    'Áp dụng công nợ?',
                    'Cập nhật công nợ NCC theo số tính lại từ chứng từ?',
                  )) {
                    return;
                  }
                  await act(() async {
                    await widget.api.applyReconciliation(widget.preview);
                    if (mounted) widget.onApplied();
                  });
                },
          child: const Text('Áp dụng công nợ tính lại'),
        ),
    ],
  );
}

class SupplierProductsScreen extends StatefulWidget {
  const SupplierProductsScreen({
    super.key,
    required this.api,
    required this.supplier,
  });
  final PurchasesService api;
  final Json supplier;
  @override
  State<SupplierProductsScreen> createState() => _SupplierProductsScreenState();
}

class _SupplierProductsScreenState extends State<SupplierProductsScreen> {
  String _kind = 'catalog';
  int _revision = 0;
  final _selected = <String, Json>{};
  bool get writable => canPurchaseWrite && widget.supplier['isActive'] == true;
  @override
  Widget build(BuildContext viewContext) => Scaffold(
    appBar: AppBar(title: Text('Sản phẩm · ${widget.supplier['name']}')),
    body: Column(
      children: [
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'catalog', label: Text('Cung cấp')),
            ButtonSegment(value: 'history', label: Text('Đã mua')),
          ],
          selected: {_kind},
          onSelectionChanged: (v) => setState(() {
            _kind = v.first;
            _selected.clear();
          }),
        ),
        if (writable)
          Wrap(
            alignment: WrapAlignment.center,
            children: [
              TextButton.icon(
                onPressed: () async {
                  final v = await openCommerce<Json>(
                    context,
                    VariantPicker(service: widget.api),
                  );
                  if (v == null || !mounted) return;
                  await openCommerce(
                    context,
                    SupplierProductEditor(
                      api: widget.api,
                      supplierId: textOf(widget.supplier['id']),
                      product: v,
                    ),
                  );
                  if (mounted) setState(() => _revision++);
                },
                icon: const Icon(Icons.add),
                label: const Text('Thêm SKU'),
              ),
              if (AuthService.hasPermission('products.manage'))
                TextButton(
                  onPressed: () async {
                    await openCommerce(
                      context,
                      SupplierImportScreen(
                        api: widget.api,
                        supplierId: textOf(widget.supplier['id']),
                      ),
                    );
                    if (mounted) {
                      setState(() {
                        _revision++;
                        _selected.clear();
                      });
                    }
                  },
                  child: const Text('Nhập Excel / CSV'),
                ),
              if (_selected.isNotEmpty)
                FilledButton(
                  onPressed: () async {
                    await openCommerce(
                      context,
                      PurchaseOrderEditor(
                        api: widget.api,
                        supplier: widget.supplier,
                        initialProducts: _selected.values.toList(),
                      ),
                    );
                    if (mounted) setState(() => _selected.clear());
                  },
                  child: Text('Đặt mua ${_selected.length} SKU'),
                ),
            ],
          ),
        Expanded(
          child: CommerceList(
            key: ValueKey('$_kind:$_revision'),
            dates: false,
            activeFilter: _kind == 'catalog',
            load: (q) => widget.api.products(textOf(widget.supplier['id']), {
              ...q,
              'kind': _kind,
            }),
            tile: (p, reload) {
              final c = object(p['catalog']);
              return Card(
                child: Column(
                  children: [
                    ListTile(
                      title: Text('${p['sku']} · ${p['productName']}'),
                      subtitle: Text(
                        'Giá chào ${moneyLabel(p['supplyPrice'])} · Tồn ${p['onHand']}\nTối thiểu ${c['minOrderQty'] ?? 1} · Bội số ${c['orderMultiple'] ?? 1}${c['isPreferred'] == true ? ' · Ưu tiên' : ''}\n${c['isActive'] == false ? 'Ngừng cung cấp' : ''}',
                      ),
                      isThreeLine: true,
                      leading:
                          writable &&
                              p['isActive'] == true &&
                              c['isActive'] == true
                          ? Checkbox(
                              value: _selected.containsKey(p['id']),
                              onChanged: (v) => setState(() {
                                if (v == true) {
                                  _selected[textOf(p['id'])] = p;
                                } else {
                                  _selected.remove(p['id']);
                                }
                              }),
                            )
                          : null,
                      onTap: writable
                          ? () async {
                              await openCommerce(
                                context,
                                SupplierProductEditor(
                                  api: widget.api,
                                  supplierId: textOf(widget.supplier['id']),
                                  product: p,
                                ),
                              );
                              _selected.clear();
                              reload();
                              if (mounted) setState(() {});
                            }
                          : null,
                    ),
                    if (c.isNotEmpty)
                      ExpansionTile(
                        title: const Text('Điều kiện cung cấp'),
                        children: [
                          InfoRow('Mã hàng NCC', c['supplierSku']),
                          InfoRow('Tên hàng NCC', c['supplierProductName']),
                          InfoRow(
                            'Thời gian giao',
                            c['leadTimeDays'] == null
                                ? 'Theo cấu hình SKU'
                                : '${c['leadTimeDays']} ngày',
                          ),
                          InfoRow('Ghi chú', c['note']),
                          InfoRow('Cập nhật giá', c['priceUpdatedAt']),
                        ],
                      ),
                    if (p['lastPurchase'] != null)
                      ListTile(
                        title: Text(
                          'Lần nhập gần nhất · ${object(p['lastPurchase'])['receiptCode']}',
                        ),
                        subtitle: Text(
                          '${moneyLabel(object(p['lastPurchase'])['actualCost'])} · SL ${object(p['lastPurchase'])['receivedQty']} · ${dayOf(object(p['lastPurchase'])['receivedAt'])}',
                        ),
                        onTap: () => openCommerce(
                          context,
                          PurchaseReceiptDetail(
                            api: widget.api,
                            id: textOf(object(p['lastPurchase'])['id']),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}

class SupplierProductEditor extends StatefulWidget {
  const SupplierProductEditor({
    super.key,
    required this.api,
    required this.supplierId,
    required this.product,
  });
  final PurchasesService api;
  final String supplierId;
  final Json product;
  @override
  State<SupplierProductEditor> createState() => _SupplierProductEditorState();
}

class _SupplierProductEditorState extends State<SupplierProductEditor>
    with CommerceActions {
  final _form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> fields;
  late bool _preferred;
  @override
  void initState() {
    super.initState();
    final c = object(widget.product['catalog']);
    fields = {
      for (final key in [
        'supplyPrice',
        'supplierSku',
        'supplierProductName',
        'minOrderQty',
        'orderMultiple',
        'leadTimeDays',
        'note',
      ])
        key: TextEditingController(
          text: textOf(
            key == 'supplyPrice'
                ? widget.product[key] ?? '0'
                : c[key] ??
                      (key == 'supplierSku'
                          ? 'NCC-${textOf(widget.product['id']).replaceAll('-', '').toUpperCase()}'
                          : key == 'supplierProductName'
                          ? widget.product['productName']
                          : ['minOrderQty', 'orderMultiple'].contains(key)
                          ? 1
                          : ''),
          ),
        ),
    };
    _preferred = c['isPreferred'] == true;
  }

  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext viewContext) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(title: Text('Điều kiện · ${widget.product['sku']}')),
      body: Form(
        key: _form,
        child: AbsorbPointer(
          absorbing: busy,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              CommerceField(
                fields['supplierSku']!,
                'Mã hàng NCC',
                maxLength: 100,
              ),
              CommerceField(
                fields['supplierProductName']!,
                'Tên hàng NCC',
                maxLength: 255,
              ),
              CommerceField(
                fields['supplyPrice']!,
                'Giá chào / đơn vị',
                money: true,
                required: true,
              ),
              CommerceField(
                fields['minOrderQty']!,
                'Đặt tối thiểu',
                integer: true,
                required: true,
              ),
              CommerceField(
                fields['orderMultiple']!,
                'Bội số đặt',
                integer: true,
                required: true,
              ),
              CommerceField(
                fields['leadTimeDays']!,
                'Số ngày giao',
                validator: (v) {
                  try {
                    if (v!.isNotEmpty) quantityOf(v, allowZero: true);
                  } on FormatException catch (e) {
                    return e.message;
                  }
                  return null;
                },
              ),
              CommerceField(fields['note']!, 'Ghi chú', maxLength: 5000),
              SwitchListTile(
                title: const Text('Nhà cung cấp ưu tiên cho SKU'),
                value: _preferred,
                onChanged: (v) => setState(() => _preferred = v),
              ),
              const Text(
                'Lưu sẽ kích hoạt lại liên kết cung cấp. Giá chào không thay giá vốn hoặc chứng từ cũ.',
              ),
              ErrorNotice(actionError),
              FilledButton(
                onPressed: () => act(() async {
                  if (!_form.currentState!.validate()) return;
                  await widget.api.saveProduct(widget.supplierId, {
                    'variantId': widget.product['id'],
                    'supplyPrice': Money.parse(
                      fields['supplyPrice']!.text,
                    ).toString(),
                    'supplierSku': fields['supplierSku']!.text.trim(),
                    'supplierProductName': fields['supplierProductName']!.text
                        .trim(),
                    'minOrderQty': quantityOf(fields['minOrderQty']!.text),
                    'orderMultiple': quantityOf(fields['orderMultiple']!.text),
                    'leadTimeDays': fields['leadTimeDays']!.text.isEmpty
                        ? null
                        : quantityOf(
                            fields['leadTimeDays']!.text,
                            allowZero: true,
                          ),
                    'isPreferred': _preferred,
                    'isActive': true,
                    'note': fields['note']!.text.trim(),
                  });
                  if (mounted) Navigator.pop(context, true);
                }),
                child: const Text('Lưu điều kiện cung cấp'),
              ),
              if (widget.product['catalog'] != null)
                TextButton(
                  onPressed: () async {
                    if (!await confirmCommerce(
                      context,
                      'Ngừng cung cấp SKU?',
                      'Giữ lại lịch sử nhập, bỏ ưu tiên và ngừng cung cấp SKU này.',
                    )) {
                      return;
                    }
                    await act(() async {
                      await widget.api.retireProduct(
                        widget.supplierId,
                        textOf(widget.product['id']),
                      );
                      if (mounted) Navigator.pop(context, true);
                    });
                  },
                  child: const Text('Ngừng cung cấp SKU'),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class SupplierImportScreen extends StatefulWidget {
  const SupplierImportScreen({
    super.key,
    required this.api,
    required this.supplierId,
  });
  final PurchasesService api;
  final String supplierId;
  @override
  State<SupplierImportScreen> createState() => _SupplierImportScreenState();
}

class _SupplierImportScreenState extends State<SupplierImportScreen>
    with CommerceActions {
  Uint8List? _bytes;
  String _filename = '';
  Json? _preview;
  Json _mapping = {};
  Future<void> preview() async {
    final result = await widget.api.importProducts(
      widget.supplierId,
      _filename,
      _bytes!,
      mapping: _mapping.isEmpty ? null : _mapping,
    );
    if (mounted) {
      setState(() {
        _preview = result;
        _mapping = object(result['mapping']);
      });
    }
  }

  @override
  Widget build(BuildContext viewContext) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(title: const Text('Nhập sản phẩm NCC')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Chọn file .xlsx hoặc CSV UTF-8, tối đa 5 MB. Xem trước và kiểm tra ánh xạ cột trước khi xác nhận.',
          ),
          TextButton.icon(
            onPressed: busy
                ? null
                : () => act(() async {
                    final file = await openFile(
                      acceptedTypeGroups: [
                        const XTypeGroup(
                          label: 'Excel / CSV',
                          extensions: ['xlsx', 'csv'],
                          uniformTypeIdentifiers: [
                            'public.comma-separated-values',
                            'org.openxmlformats.spreadsheetml.sheet',
                          ],
                          mimeTypes: [
                            'text/csv',
                            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                          ],
                        ),
                      ],
                    );
                    if (file == null) return;
                    if (await file.length() > 5 * 1024 * 1024) {
                      throw const FormatException(
                        'File không được vượt quá 5 MB.',
                      );
                    }
                    final bytes = await file.readAsBytes();
                    if (!mounted) return;
                    setState(() {
                      _filename = file.name;
                      _bytes = bytes;
                      _preview = null;
                      _mapping = {};
                    });
                    await preview();
                  }),
            icon: const Icon(Icons.upload_file),
            label: Text(_filename.isEmpty ? 'Chọn file' : _filename),
          ),
          ErrorNotice(actionError),
          if (busy) const LinearProgressIndicator(),
          if (_preview != null) ...[
            for (final entry in {
              'sku': 'SKU',
              'name': 'Tên hàng',
              'price': 'Giá chào',
              'supplierSku': 'Mã hàng NCC',
              'unit': 'Đơn vị',
            }.entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: DropdownButtonFormField<int>(
                  isExpanded: true,
                  key: ValueKey('${entry.key}:${_mapping[entry.key]}'),
                  initialValue: (_mapping[entry.key] as num?)?.toInt() ?? -1,
                  decoration: InputDecoration(labelText: entry.value),
                  items: [
                    const DropdownMenuItem(
                      value: -1,
                      child: Text('Không ánh xạ'),
                    ),
                    for (
                      var i = 0;
                      i < (_preview!['headers'] as List).length;
                      i++
                    )
                      DropdownMenuItem(
                        value: i,
                        child: Text('${i + 1}. ${_preview!['headers'][i]}'),
                      ),
                  ],
                  onChanged: busy
                      ? null
                      : (value) => setState(() {
                          if (value == -1) {
                            _mapping.remove(entry.key);
                          } else {
                            _mapping[entry.key] = value;
                          }
                          _preview!['valid'] = false;
                        }),
                ),
              ),
            TextButton(
              onPressed: busy ? null : () => act(preview),
              child: const Text('Kiểm tra lại ánh xạ'),
            ),
            for (final issue in (_preview!['issues'] as List? ?? []))
              ErrorNotice(textOf(issue)),
            for (final item in records(_preview!['items']))
              ListTile(
                title: Text(
                  'Dòng ${item['row']} · ${item['sku']} · ${item['name']}',
                ),
                subtitle: Text(
                  '${item['action']} · ${moneyLabel(item['price'])}${item['error'] == null ? '' : '\n${item['error']}'}',
                ),
              ),
            FilledButton(
              onPressed: busy || _preview!['valid'] != true
                  ? null
                  : () async {
                      if (!await confirmCommerce(
                        context,
                        'Nhập danh mục NCC?',
                        'Tạo/liên kết/cập nhật các sản phẩm theo bản xem trước này?',
                      )) {
                        return;
                      }
                      await act(() async {
                        final result = await widget.api.importProducts(
                          widget.supplierId,
                          _filename,
                          _bytes!,
                          mapping: _mapping,
                          digest: textOf(_preview!['digest']),
                        );
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Đã xử lý ${result['total']} dòng: tạo ${result['created']}, liên kết ${result['linked']}, cập nhật ${result['updated']}.',
                            ),
                          ),
                        );
                        Navigator.pop(context, true);
                      });
                    },
              child: const Text('Xác nhận nhập danh mục'),
            ),
          ],
        ],
      ),
    ),
  );
}
