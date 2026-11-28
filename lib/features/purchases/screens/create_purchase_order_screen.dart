import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:abc_app/core/auth/permission_gate.dart';
import 'package:abc_app/core/theme/app_theme.dart';
import 'package:abc_app/core/utils/money_format.dart';
import 'package:abc_app/features/auth/services/auth_service.dart';
import '../models/purchase_models.dart';
import '../services/purchases_service.dart';

class _PoLine {
  final SupplierProduct product;
  final TextEditingController qtyController;
  final TextEditingController priceController;

  _PoLine(this.product)
      : qtyController = TextEditingController(
          text: product.minOrderQty.toString(),
        ),
        priceController = TextEditingController(text: product.supplyPrice);

  void dispose() {
    qtyController.dispose();
    priceController.dispose();
  }
}

/// Form lập đơn đặt hàng nhà cung cấp (PO).
/// Có thể mở từ nút "Đặt NCC" trên thẻ sản phẩm: khi đó SKU tương ứng
/// sẽ được tự động thêm nếu NCC nào đó đang cung cấp SKU đó.
class CreatePurchaseOrderScreen extends StatefulWidget {
  final String? initialVariantId;
  final String? initialSku;
  final String? initialProductName;

  const CreatePurchaseOrderScreen({
    super.key,
    this.initialVariantId,
    this.initialSku,
    this.initialProductName,
  });

  @override
  State<CreatePurchaseOrderScreen> createState() =>
      _CreatePurchaseOrderScreenState();
}

class _CreatePurchaseOrderScreenState extends State<CreatePurchaseOrderScreen> {
  final _service = PurchasesService();
  final _codeController = TextEditingController();
  final _productSearchController = TextEditingController();

  List<Supplier> _suppliers = [];
  Supplier? _selectedSupplier;
  List<SupplierProduct> _products = [];
  final List<_PoLine> _lines = [];

  bool _supplierLoading = true;
  bool _productLoading = false;
  bool _submitting = false;
  String? _supplierError;
  String? _productError;
  String? _notice;
  DateTime _expectedDate =
      DateTime.now().add(const Duration(days: 3)).copyWith(
    hour: 0,
    minute: 0,
    second: 0,
    millisecond: 0,
    microsecond: 0,
  );

  bool get _canWrite => AuthService.hasPermission('inventory.receive');

  @override
  void initState() {
    super.initState();
    _codeController.text = generatePurchaseCode();
    _loadSuppliers();
  }

  @override
  void dispose() {
    for (final line in _lines) {
      line.dispose();
    }
    _codeController.dispose();
    _productSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadSuppliers() async {
    setState(() {
      _supplierLoading = true;
      _supplierError = null;
    });
    try {
      final suppliers = await _service.getSuppliers();
      if (!mounted) return;
      setState(() {
        _suppliers = suppliers;
        _supplierLoading = false;
      });

      final sku = widget.initialSku?.trim() ?? '';
      if (sku.isNotEmpty) {
        final matched = await _findSupplierForSku(
          sku,
          widget.initialVariantId,
        );
        if (!mounted) return;
        await _selectSupplier(
          matched ?? (_suppliers.isEmpty ? null : _suppliers.first),
        );
        if (!mounted) return;
        if (matched == null) {
          setState(() {
            _notice =
                'SKU $sku chưa thuộc danh mục đang cung cấp của NCC nào. '
                'Hãy chọn NCC và SKU phù hợp.';
          });
        } else {
          _addLine(_findProduct(sku), closePicker: false);
        }
      } else if (suppliers.isNotEmpty) {
        await _selectSupplier(suppliers.first);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _supplierLoading = false;
          _supplierError = _service.messageOf(e);
        });
      }
    }
  }

  /// Dò danh mục của từng NCC để tìm NCC đang cung cấp SKU cần đặt.
  Future<Supplier?> _findSupplierForSku(String sku, String? variantId) async {
    for (final supplier in _suppliers.take(20)) {
      try {
        final products = await _service.getSupplierProducts(
          supplier.id,
          search: sku,
        );
        for (final product in products) {
          final same = variantId != null
              ? product.variantId == variantId
              : product.sku.toLowerCase() == sku.toLowerCase();
          if (same) return supplier;
        }
      } catch (_) {
        // NCC lỗi danh mục thì bỏ qua, thử NCC kế tiếp.
      }
    }
    return null;
  }

  SupplierProduct? _findProduct(String sku) {
    for (final product in _products) {
      final same = widget.initialVariantId != null
          ? product.variantId == widget.initialVariantId
          : product.sku.toLowerCase() == sku.toLowerCase();
      if (same) return product;
    }
    return null;
  }

  Future<void> _selectSupplier(Supplier? supplier) async {
    setState(() {
      _selectedSupplier = supplier;
      _notice = null;
      _productError = null;
      for (final line in _lines) {
        line.dispose();
      }
      _lines.clear();
      _products = [];
    });
    if (supplier == null) return;

    setState(() => _productLoading = true);
    try {
      final products = await _service.getSupplierProducts(supplier.id);
      if (!mounted) return;
      setState(() => _products = products);
    } catch (e) {
      if (mounted) setState(() => _productError = _service.messageOf(e));
    } finally {
      if (mounted) setState(() => _productLoading = false);
    }
  }

  void _addLine(SupplierProduct? product, {bool closePicker = true}) {
    if (product == null) return;
    if (_lines.any((line) => line.product.variantId == product.variantId)) {
      _showMessage('SKU ${product.sku} đã có trong đơn.');
      return;
    }
    setState(() {
      _lines.add(_PoLine(product));
      _notice = null;
    });
    if (closePicker && mounted) Navigator.of(context).pop();
  }

  void _showProductPicker() {
    if (_selectedSupplier == null) {
      _showMessage('Hãy chọn nhà cung cấp trước.');
      return;
    }
    String query = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final plain = query.trim().toLowerCase();
            final filtered = plain.isEmpty
                ? _products
                : _products
                    .where(
                      (p) =>
                          p.sku.toLowerCase().contains(plain) ||
                          p.displayName.toLowerCase().contains(plain) ||
                          p.supplierSku.toLowerCase().contains(plain),
                    )
                    .toList();

            return SafeArea(
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.72,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: TextField(
                        autofocus: true,
                        onChanged: (value) => setSheetState(() => query = value),
                        decoration: InputDecoration(
                          hintText: 'Tìm SKU hoặc tên hàng',
                          prefixIcon: const Icon(Icons.search_rounded, size: 18),
                          isDense: true,
                        ),
                      ),
                    ),
                    const Divider(height: 1, color: AppTheme.border),
                    Expanded(
                      child: _productLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.accent,
                              ),
                            )
                          : filtered.isEmpty
                              ? const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(24),
                                    child: Text(
                                      'NCC này chưa có SKU nào để đặt.',
                                      style: TextStyle(
                                        color: AppTheme.muted,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: filtered.length,
                                  separatorBuilder: (_, _) =>
                                      const Divider(height: 1, color: AppTheme.border),
                                  itemBuilder: (context, index) {
                                    final product = filtered[index];
                                    final added = _lines.any(
                                      (line) =>
                                          line.product.variantId ==
                                          product.variantId,
                                    );
                                    return ListTile(
                                      title: Text(
                                        product.displayName,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      subtitle: Text(
                                        '${product.sku} • Tồn ${product.onHand} '
                                        '• Tối thiểu ${product.minOrderQty} '
                                        '${product.unitOfMeasure}',
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                      trailing: added
                                          ? const Icon(
                                              Icons.check_circle_rounded,
                                              color: AppTheme.success,
                                              size: 20,
                                            )
                                          : Text(
                                              formatDecimalMoney(product.supplyPrice),
                                              style: const TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w800,
                                                color: AppTheme.accent,
                                              ),
                                            ),
                                      onTap: added
                                          ? null
                                          : () => _addLine(product),
                                    );
                                  },
                                ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _pickExpectedDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expectedDate,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (picked != null && mounted) setState(() => _expectedDate = picked);
  }

  void _changeQty(_PoLine line, int delta) {
    final current = int.tryParse(line.qtyController.text) ?? 0;
    final next = current + delta;
    if (next < 1) return;
    setState(() => line.qtyController.text = next.toString());
  }

  String? _validate() {
    if (!_canWrite) return 'Bạn không có quyền inventory.receive để đặt hàng.';
    if (_codeController.text.trim().isEmpty) return 'Mã PO không được để trống.';
    if (_selectedSupplier == null) return 'Hãy chọn nhà cung cấp.';
    if (_lines.isEmpty) return 'Hãy thêm ít nhất một SKU vào đơn.';
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    if (_expectedDate.isBefore(today)) return 'Ngày giao dự kiến không được trước hôm nay.';

    for (final line in _lines) {
      final qty = int.tryParse(line.qtyController.text.trim());
      if (qty == null || !isValidOrderQty(qty, line.product.minOrderQty, line.product.orderMultiple)) {
        return '${line.product.sku}: số lượng phải ≥ ${line.product.minOrderQty} '
            'và là bội số của ${line.product.orderMultiple}.';
      }
      final price = line.priceController.text.trim();
      if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(price)) {
        return '${line.product.sku}: đơn giá phải không âm, tối đa 2 chữ số thập phân.';
      }
    }
    return null;
  }

  Future<void> _submit() async {
    final error = _validate();
    if (error != null) {
      _showMessage(error);
      return;
    }

    setState(() => _submitting = true);
    try {
      await _service.createOrder(
        code: _codeController.text.trim(),
        supplierId: _selectedSupplier!.id,
        expectedDeliveryDate: _expectedDate,
        items: _lines
            .map(
              (line) => <String, dynamic>{
                'variantId': line.product.variantId,
                'orderedQty': int.parse(line.qtyController.text.trim()),
                'unitPrice': line.priceController.text.trim(),
              },
            )
            .toList(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      final message = _service.messageOf(e);
      final duplicated = e is DioException && e.response?.statusCode == 409;
      if (duplicated || message.contains('đã tồn tại')) {
        setState(() {
          _codeController.text = generatePurchaseCode();
          _submitting = false;
        });
        _showMessage('Mã PO bị trùng, đã đổi mã mới. Bấm gửi lại.');
        return;
      }
      setState(() => _submitting = false);
      _showMessage(message);
    }
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Tạo đơn đặt hàng'),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: ElevatedButton.icon(
            onPressed: _submitting ? null : _submit,
            icon: _submitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.send_rounded, size: 18),
            label: Text(_submitting ? 'Đang gửi đơn...' : 'Gửi đơn đặt hàng'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13),
            ),
          ),
        ),
      ),
      body: _supplierLoading
          ? const Center(
              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent),
            )
          : _supplierError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _supplierError!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppTheme.muted),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: _loadSuppliers,
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  ),
                )
              : _suppliers.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Chưa có nhà cung cấp nào trong hệ thống.\n'
                          'Hãy tạo NCC trên web trước khi đặt hàng.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: AppTheme.muted),
                        ),
                      ),
                    )
                  : _buildForm(),
    );
  }

  Widget _buildForm() {
    if (!_canWrite) {
      return const PermissionDeniedView(
        message: 'Bạn cần quyền inventory.receive để lập đơn đặt hàng.',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        _buildInfoCard(),
        const SizedBox(height: 12),
        _buildItemsCard(),
      ],
    );
  }

  Widget _buildInfoCard() {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Thông tin đơn hàng',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _codeController,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'Mã PO',
                hintText: 'PO-YYYYMMDD-XXXX',
                prefixIcon: const Icon(Icons.confirmation_number_outlined, size: 18),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.autorenew_rounded, size: 18),
                  tooltip: 'Đổi mã gợi ý',
                  onPressed: () {
                    setState(() => _codeController.text = generatePurchaseCode());
                  },
                ),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<Supplier>(
              initialValue: _selectedSupplier,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Nhà cung cấp',
                prefixIcon: Icon(Icons.business_outlined, size: 18),
                isDense: true,
              ),
              items: _suppliers
                  .map(
                    (supplier) => DropdownMenuItem<Supplier>(
                      value: supplier,
                      child: Text(
                        supplier.displayName,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) => _selectSupplier(value),
            ),
            if (_selectedSupplier != null) ...[
              const SizedBox(height: 6),
              Text(
                [
                  if (_selectedSupplier!.contactPerson.isNotEmpty)
                    'Liên hệ: ${_selectedSupplier!.contactPerson}',
                  if (_selectedSupplier!.phone.isNotEmpty)
                    'ĐT: ${_selectedSupplier!.phone}',
                ].join('  •  '),
                style: const TextStyle(fontSize: 11, color: AppTheme.muted),
              ),
            ],
            if (_notice != null) ...[
              const SizedBox(height: 8),
              Text(
                _notice!,
                style: const TextStyle(fontSize: 11.5, color: AppTheme.warning),
              ),
            ],
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickExpectedDate,
              borderRadius: BorderRadius.circular(8),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Ngày giao dự kiến',
                  prefixIcon: Icon(Icons.event_outlined, size: 18),
                  isDense: true,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat('dd/MM/yyyy').format(_expectedDate),
                      style: const TextStyle(fontSize: 13),
                    ),
                    const Icon(Icons.calendar_month_outlined, size: 17, color: AppTheme.muted),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsCard() {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Hàng hóa đặt mua',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
                TextButton.icon(
                  onPressed: _productLoading ? null : _showProductPicker,
                  icon: const Icon(Icons.add_rounded, size: 17),
                  label: const Text('Chọn SKU'),
                ),
              ],
            ),
            if (_productError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _productError!,
                  style: const TextStyle(fontSize: 11.5, color: AppTheme.danger),
                ),
              ),
            if (_productLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent),
                ),
              ),
            if (!_productLoading && _lines.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Text(
                  'Chưa có SKU. Bấm "Chọn SKU" để thêm hàng vào đơn.',
                  style: TextStyle(fontSize: 12, color: AppTheme.muted),
                ),
              ),
            ..._lines.map(_buildLine),
            if (_lines.isNotEmpty) ...[
              const Divider(height: 20, color: AppTheme.border),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Tạm tính',
                    style: TextStyle(fontSize: 12.5, color: AppTheme.muted),
                  ),
                  Text(
                    _totalText(),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.accent,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLine(_PoLine line) {
    final qty = int.tryParse(line.qtyController.text) ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${line.product.displayName} (${line.product.sku})',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 17, color: AppTheme.danger),
                  tooltip: 'Bỏ SKU này',
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    setState(() {
                      line.dispose();
                      _lines.remove(line);
                    });
                  },
                ),
              ],
            ),
            Text(
              'Tối thiểu ${line.product.minOrderQty} ${line.product.unitOfMeasure}'
              '  •  Bội số ${line.product.orderMultiple}',
              style: const TextStyle(fontSize: 10.5, color: AppTheme.muted),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: line.priceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Đơn giá',
                      isDense: true,
                      prefixText: '₫ ',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 30,
                        height: 34,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.remove_circle_outline, size: 19),
                          onPressed: () => _changeQty(line, -line.product.orderMultiple),
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: line.qtyController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          decoration: const InputDecoration(
                            labelText: 'SL',
                            isDense: true,
                            counterText: '',
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      SizedBox(
                        width: 30,
                        height: 34,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.add_circle_outline, size: 19),
                          onPressed: () => _changeQty(line, line.product.orderMultiple),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Thành tiền: ${previewPurchaseAmount(line.priceController.text, qty)}',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _totalText() {
    var total = 0.0;
    for (final line in _lines) {
      final price = num.tryParse(line.priceController.text.trim()) ?? 0;
      final qty = int.tryParse(line.qtyController.text.trim()) ?? 0;
      total += price * qty;
    }
    return formatDecimalMoney(total.toStringAsFixed(2));
  }
}
