import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:abc_app/core/network/api_error.dart';
import 'package:abc_app/core/services/upload_service.dart';
import 'package:abc_app/core/theme/product_ui.dart';
import 'package:abc_app/core/utils/vi_text.dart';

import '../models/category_attribute_model.dart';
import '../services/products_service.dart';
import 'barcode_scanner_screen.dart';
import 'manage_catalog_screen.dart';

/// Màn "Thêm Mới Hàng Hóa" — bám bố cục `abc-app/thêm hàng hóa.png`:
/// ảnh biến thể → định danh → giá & tồn → thuộc tính → cài đặt → mô tả.
///
/// Luồng lưu thật (đúng nghiệp vụ backend, không phải mock):
///   1. POST /products/templates                → tạo mẫu hàng hóa
///   2. POST /products/templates/:id/variants/generate → sinh biến thể theo thuộc tính
///   3. PATCH /products/templates/:id/variants/bulk     → ghi SKU, barcode, giá, tồn tối thiểu
///   4. POST /inventory/opening-sheets (apply)          → nạp tồn kho ban đầu
class AddProductScreen extends StatefulWidget {
  /// Chỉ dùng cho test/preview: nạp sẵn danh mục & thuộc tính, bỏ qua gọi mạng.
  final List<CategoryItem>? previewCategories;
  final List<AttributeItem>? previewAttributes;

  const AddProductScreen({
    super.key,
    this.previewCategories,
    this.previewAttributes,
  });

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

/// Một dòng thuộc tính đang chọn: thuộc tính + các giá trị được tick.
class _AttrRow {
  String? attributeId;
  final Set<String> valueIds = <String>{};

  _AttrRow();

  bool get isValid => attributeId != null && valueIds.isNotEmpty;
}

class _AddProductScreenState extends State<AddProductScreen> {
  static const _units = <String>['Chai', 'Hộp', 'Lọ', 'Tuýp', 'Gói', 'Đôi', 'Cái'];

  final _service = ProductsService();
  final _upload = UploadService();

  final _nameController = TextEditingController();
  final _skuController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _priceController = TextEditingController();
  final _costController = TextEditingController();
  final _descController = TextEditingController();

  final List<String> _images = <String>[];

  /// Mở sẵn một dòng trống để người dùng thấy ngay chỗ chọn thuộc tính.
  final List<_AttrRow> _attrRows = <_AttrRow>[_AttrRow()];

  List<CategoryItem> _categories = const [];
  List<AttributeItem> _attributes = const [];

  String? _categoryId;
  String _unit = 'Chai';
  int _stock = 0;
  int _minStock = 5;
  bool _hasLotTracking = false;
  bool _isActive = true;

  bool _isSaving = false;
  bool _isUploading = false;
  bool _isLoadingMeta = true;

  @override
  void initState() {
    super.initState();
    _priceController.addListener(_onMoneyChanged);
    _costController.addListener(_onMoneyChanged);
    _loadMeta();
  }

  @override
  void dispose() {
    _priceController.removeListener(_onMoneyChanged);
    _costController.removeListener(_onMoneyChanged);
    _nameController.dispose();
    _skuController.dispose();
    _barcodeController.dispose();
    _priceController.dispose();
    _costController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _onMoneyChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadMeta() async {
    final previewCats = widget.previewCategories;
    final previewAttrs = widget.previewAttributes;
    if (previewCats != null && previewAttrs != null) {
      setState(() {
        _categories = previewCats;
        _attributes = previewAttrs;
        _isLoadingMeta = false;
      });
      return;
    }

    setState(() => _isLoadingMeta = true);
    try {
      final results = await Future.wait([
        _service.getCategories(),
        _service.getAttributes(),
      ]);
      if (!mounted) return;
      setState(() {
        _categories = results[0] as List<CategoryItem>;
        _attributes = results[1] as List<AttributeItem>;
      });
    } catch (_) {
      // Không chặn việc nhập tay nếu API danh mục/thuộc tính lỗi.
    } finally {
      if (mounted) setState(() => _isLoadingMeta = false);
    }
  }

  // ---------------------------------------------------------------- tiện ích

  /// "280.000" → 280000.0
  double _money(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return 0;
    return double.tryParse(digits) ?? 0;
  }

  double get _price => _money(_priceController.text);
  double get _cost => _money(_costController.text);

  /// Lãi gộp = (giá bán - giá vốn) / giá bán.
  double? get _margin {
    if (_price <= 0) return null;
    return (_price - _cost) / _price;
  }

  int get _variantCount {
    var total = 1;
    for (final row in _attrRows.where((r) => r.isValid)) {
      total *= row.valueIds.length;
    }
    return total;
  }

  AttributeItem? _attributeById(String? id) {
    if (id == null) return null;
    for (final a in _attributes) {
      if (a.id == id) return a;
    }
    return null;
  }

  String _autoSku() {
    final plain = normalizeForSearch(_nameController.text);
    final words = plain.split(RegExp(r'[^a-z0-9]+')).where((w) => w.isNotEmpty).toList();
    final parts = words.take(3).map((w) => w.substring(0, w.length > 3 ? 3 : w.length)).join('-');
    final suffix = DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase();
    final tail = suffix.substring(suffix.length - 3);
    return parts.isEmpty ? 'SP-$tail' : '${parts.toUpperCase()}-$tail';
  }

  /// Sinh EAN-13 có số kiểm tra hợp lệ.
  String _autoBarcode() {
    final base = DateTime.now().millisecondsSinceEpoch.toString().padLeft(12, '0');
    final twelve = base.substring(base.length - 12);
    var sum = 0;
    for (var i = 0; i < 12; i++) {
      final digit = int.parse(twelve[i]);
      sum += i.isEven ? digit : digit * 3;
    }
    final check = (10 - (sum % 10)) % 10;
    return '$twelve$check';
  }

  // ---------------------------------------------------------------- hành động

  Future<void> _pickImage(bool fromCamera) async {
    try {
      final file = fromCamera ? await _upload.pickImageFromCamera() : await _upload.pickImageFromGallery();
      if (file == null) return;
      setState(() => _isUploading = true);
      final url = await _upload.uploadImage(file);
      if (!mounted) return;
      if (url != null && url.isNotEmpty) {
        setState(() => _images.add(url));
      } else {
        _toast('Tải ảnh thất bại, thử lại giúp mình.');
      }
    } catch (e) {
      if (mounted) _toast('Lỗi tải ảnh: ${apiErrorMessage(e)}');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _scanBarcode() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (code != null && code.isNotEmpty) {
      setState(() => _barcodeController.text = code);
    }
  }

  Future<void> _addAttributeValue(_AttrRow row) async {
    final attribute = _attributeById(row.attributeId);
    if (attribute == null) return;
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Thêm giá trị cho "${attribute.name}"', style: ProductUi.t(15, FontWeight.w700, ProductUi.ink)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: ProductUi.t(13, FontWeight.w500, ProductUi.ink),
          decoration: const InputDecoration(hintText: 'Ví dụ: 30ml'),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text('Thêm', style: ProductUi.t(13, FontWeight.w700, ProductUi.primary)),
          ),
        ],
      ),
    );
    controller.dispose();
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return;

    try {
      await _service.addAttributeValue(attributeId: attribute.id, value: trimmed);
      final refreshed = await _service.getAttributes();
      if (!mounted) return;
      setState(() {
        _attributes = refreshed;
        final fresh = _attributeById(attribute.id);
        if (fresh != null) {
          for (final v in fresh.values) {
            if (normalizeForSearch(v.value) == normalizeForSearch(trimmed)) {
              row.valueIds.add(v.id);
            }
          }
        }
      });
    } catch (e) {
      if (mounted) _toast('Không thêm được giá trị: ${apiErrorMessage(e)}');
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _toast('Nhập tên hàng hóa trước đã.');
      return;
    }
    if (_price <= 0) {
      _toast('Giá bán lẻ phải lớn hơn 0.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final template = await _service.createTemplate(
        name: name,
        categoryId: _categoryId,
        unitOfMeasure: _unit,
        hasLotTracking: _hasLotTracking,
        description: _descController.text,
        imageUrl: _images.isEmpty ? null : jsonEncode(_images),
        isActive: _isActive,
      );

      final templateId = template['id']?.toString() ?? '';
      if (templateId.isEmpty) {
        throw Exception('Máy chủ không trả về mã mẫu hàng hóa.');
      }

      final attrs = _attrRows
          .where((r) => r.isValid)
          .map((r) => <String, dynamic>{
                'attributeId': r.attributeId,
                'attributeValueIds': r.valueIds.toList(),
              })
          .toList();

      final variants = await _service.generateVariants(
        templateId,
        attributes: attrs,
        basePrice: _price.toStringAsFixed(2),
        costPrice: _cost.toStringAsFixed(2),
      );

      if (variants.isNotEmpty) {
        final sku = _skuController.text.trim();
        final barcode = _barcodeController.text.trim();
        final rows = <Map<String, dynamic>>[];
        for (var i = 0; i < variants.length; i++) {
          rows.add(<String, dynamic>{
            'id': variants[i]['id']?.toString(),
            'basePrice': _price.toStringAsFixed(2),
            'costPrice': _cost.toStringAsFixed(2),
            'safetyStockQty': _minStock,
            if (i == 0 && sku.isNotEmpty) 'sku': sku,
            if (i == 0 && barcode.isNotEmpty) 'barcode': barcode,
          });
        }
        await _service.bulkUpdateVariants(templateId, rows);

        // Tồn đầu kỳ chỉ áp cho trường hợp một biến thể (đúng như form này).
        if (variants.length == 1 && _stock > 0) {
          await _service.createOpeningStock(
            variantId: variants.first['id'].toString(),
            quantity: _stock,
            unitCost: _cost.toStringAsFixed(2),
            note: 'Tồn đầu kỳ khi tạo hàng hóa: $name',
          );
        }
      }

      if (!mounted) return;
      _toast('Đã tạo hàng hóa "$name".');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) _toast('Lưu thất bại: ${apiErrorMessage(e)}');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ------------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ProductUi.formBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                children: [
                  _buildTitle(),
                  const SizedBox(height: 14),
                  _buildImagesSection(),
                  _buildIdentitySection(),
                  _buildPriceStockSection(),
                  _buildAttributesSection(),
                  _buildAdvancedSection(),
                  _buildDescriptionSection(),
                ],
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.of(context).maybePop(),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Row(
                children: [
                  const Icon(Icons.chevron_left_rounded, size: 20, color: ProductUi.primary),
                  Text('Quay lại', style: ProductUi.t(12.5, FontWeight.w700, ProductUi.primary)),
                ],
              ),
            ),
          ),
          const Spacer(),
          InkWell(
            onTap: _isSaving ? null : _save,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              decoration: BoxDecoration(
                color: ProductUi.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text('Lưu', style: ProductUi.t(12, FontWeight.w700, Colors.white)),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: ProductUi.roseTile,
              shape: BoxShape.circle,
              border: Border.all(color: ProductUi.softLine),
            ),
            alignment: Alignment.center,
            child: Text('A', style: ProductUi.t(12, FontWeight.w700, ProductUi.primary)),
          ),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Thêm Mới Hàng Hóa', style: ProductUi.t(22.5, FontWeight.w700, ProductUi.primary, height: 1.15)),
        const SizedBox(height: 4),
        Text(
          'Tạo mới biến thể SKU, cấu hình giá, tồn kho và thuộc tính đóng gói',
          style: ProductUi.t(11.5, FontWeight.w600, ProductUi.sub, height: 1.3),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------ ảnh

  Widget _buildImagesSection() {
    return _section(
      icon: Icons.photo_camera_back_outlined,
      title: 'Ảnh sản phẩm biến thể',
      accent: ProductUi.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 74,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (var i = 0; i < _images.length; i++) ...[
                  _imageThumb(i),
                  const SizedBox(width: 8),
                ],
                _uploadTile(
                  icon: Icons.photo_camera_outlined,
                  label: 'Chụp ảnh',
                  onTap: _isUploading ? null : () => _pickImage(true),
                ),
                const SizedBox(width: 8),
                _uploadTile(
                  icon: Icons.upload_file_outlined,
                  label: 'Chọn tệp',
                  onTap: _isUploading ? null : () => _pickImage(false),
                ),
              ],
            ),
          ),
          if (_isUploading) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(minHeight: 2, color: ProductUi.primary),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.info_outline_rounded, size: 12, color: ProductUi.sub),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  'Ảnh đầu tiên là ảnh đại diện chính hiển thị tại quầy POS.',
                  style: ProductUi.t(9.5, FontWeight.w500, ProductUi.sub, height: 1.3),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _imageThumb(int index) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 74,
            height: 74,
            child: Image.network(
              _images[index],
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                color: ProductUi.fieldBg,
                child: const Icon(Icons.image_outlined, size: 22, color: ProductUi.sub),
              ),
            ),
          ),
        ),
        if (index == 0)
          Positioned(
            left: 5,
            top: 5,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: ProductUi.green,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('Chính', style: ProductUi.t(8, FontWeight.w700, Colors.white)),
            ),
          ),
        Positioned(
          right: -6,
          top: -6,
          child: GestureDetector(
            onTap: () => setState(() => _images.removeAt(index)),
            child: Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(color: Color(0xFF3A4256), shape: BoxShape.circle),
              child: const Icon(Icons.close_rounded, size: 12, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _uploadTile({required IconData icon, required String label, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 74,
        height: 74,
        decoration: BoxDecoration(
          color: ProductUi.fieldBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ProductUi.fieldBorder),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: ProductUi.primary),
            const SizedBox(height: 6),
            Text(label, style: ProductUi.t(10, FontWeight.w600, ProductUi.sub)),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------- định danh

  Widget _buildIdentitySection() {
    return _section(
      icon: Icons.badge_outlined,
      title: 'Định danh sản phẩm',
      accent: ProductUi.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('Tên hàng / Biến thể', required: true, trailing: '${_nameController.text.length}/120'),
          const SizedBox(height: 5),
          _field(
            child: TextField(
              controller: _nameController,
              maxLength: 120,
              style: ProductUi.t(12.5, FontWeight.w500, ProductUi.ink),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                counterText: '',
                hintText: 'Ví dụ: Serum Dưỡng Ẩm B5 30ml',
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: 12),

          _label('Mã SKU quản lý', trailingWidget: _linkAction('Sinh mã tự động', Icons.auto_fix_high_rounded, () {
            setState(() => _skuController.text = _autoSku());
          })),
          const SizedBox(height: 5),
          _field(
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _skuController,
                    style: ProductUi.t(12.5, FontWeight.w600, ProductUi.ink),
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      hintText: 'ABC-SER-B5-30ML',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                if (_skuController.text.trim().isNotEmpty)
                  const Icon(Icons.check_circle_rounded, size: 15, color: ProductUi.green),
              ],
            ),
          ),
          const SizedBox(height: 12),

          _label('Mã vạch'),
          const SizedBox(height: 5),
          _field(
            child: Row(
              children: [
                const Icon(Icons.qr_code_2_rounded, size: 16, color: ProductUi.sub),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _barcodeController,
                    keyboardType: TextInputType.number,
                    style: ProductUi.t(12.5, FontWeight.w500, ProductUi.ink),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      hintText: '8936012849102',
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: _scanBarcode,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: ProductUi.green,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.qr_code_scanner_rounded, size: 16, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: () => setState(() => _barcodeController.text = _autoBarcode()),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: ProductUi.fieldBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: ProductUi.fieldBorder),
                    ),
                    child: const Icon(Icons.autorenew_rounded, size: 15, color: ProductUi.sub),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Danh mục'),
                    const SizedBox(height: 5),
                    _dropdown<String>(
                      value: _categoryId,
                      hint: _isLoadingMeta ? 'Đang tải...' : 'Chọn danh mục',
                      items: [
                        for (final c in _categories)
                          DropdownMenuItem(value: c.id, child: Text(c.name)),
                      ],
                      onChanged: (v) => setState(() => _categoryId = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Đơn vị tính'),
                    const SizedBox(height: 5),
                    _dropdown<String>(
                      value: _unit,
                      hint: 'Chọn đơn vị',
                      items: [
                        for (final u in _units) DropdownMenuItem(value: u, child: Text(u)),
                      ],
                      onChanged: (v) => setState(() => _unit = v ?? _unit),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------- giá & tồn kho

  Widget _buildPriceStockSection() {
    final margin = _margin;
    return _section(
      icon: Icons.payments_outlined,
      title: 'Giá bán & Tồn kho',
      accent: ProductUi.green,
      trailing: margin == null
          ? null
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: ProductUi.greenTile,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                'Lãi gộp: ${(margin * 100).toStringAsFixed(1)}%',
                style: ProductUi.t(9.5, FontWeight.w700, ProductUi.green),
              ),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Giá bán lẻ (VND)', required: true),
                    const SizedBox(height: 5),
                    _moneyField(_priceController, hint: '280.000', bold: true),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Giá vốn ban đầu'),
                    const SizedBox(height: 5),
                    _moneyField(_costController, hint: '185.000'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Tồn kho ban đầu'),
                    const SizedBox(height: 5),
                    _stepper(_stock, (v) => setState(() => _stock = v), 0),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Tồn ít nhất (báo động)'),
                    const SizedBox(height: 5),
                    _stepper(_minStock, (v) => setState(() => _minStock = v), 0),
                  ],
                ),
              ),
            ],
          ),
          if (_variantCount > 1 && _stock > 0) ...[
            const SizedBox(height: 10),
            Text(
              'Đang chọn $_variantCount biến thể: tồn kho ban đầu chỉ áp cho biến thể đầu tiên, '
              'các biến thể còn lại vào kho bằng phiếu nhập.',
              style: ProductUi.t(9.5, FontWeight.w500, ProductUi.warn, height: 1.3),
            ),
          ],
        ],
      ),
    );
  }

  Widget _moneyField(TextEditingController controller, {required String hint, bool bold = false}) {
    return _field(
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: [_ThousandsFormatter()],
              style: ProductUi.t(
                13.5,
                bold ? FontWeight.w800 : FontWeight.w500,
                bold ? ProductUi.primary : ProductUi.ink,
              ),
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                hintText: hint,
                hintStyle: ProductUi.t(12.5, FontWeight.w500, ProductUi.sub),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text('đ', style: ProductUi.t(12, FontWeight.w600, ProductUi.sub)),
        ],
      ),
    );
  }

  Widget _stepper(int value, ValueChanged<int> onChanged, int min) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: ProductUi.fieldBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ProductUi.fieldBorder),
      ),
      child: Row(
        children: [
          _stepButton(Icons.remove_rounded, () {
            if (value > min) onChanged(value - 1);
          }),
          Expanded(
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: ProductUi.t(13, FontWeight.w700, ProductUi.ink),
            ),
          ),
          _stepButton(Icons.add_rounded, () => onChanged(value + 1)),
        ],
      ),
    );
  }

  Widget _stepButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 34,
        height: 36,
        child: Icon(icon, size: 16, color: ProductUi.primary),
      ),
    );
  }

  // ------------------------------------------------------------- thuộc tính

  Widget _buildAttributesSection() {
    final validCount = _attrRows.where((r) => r.isValid).length;
    return _section(
      icon: Icons.tune_rounded,
      title: 'Thuộc tính & Quy cách đóng gói',
      accent: ProductUi.warn,
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: ProductUi.peachTile,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          '$validCount thuộc tính',
          style: ProductUi.t(9.5, FontWeight.w700, ProductUi.peachInk),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isLoadingMeta)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(minHeight: 2, color: ProductUi.warn),
            )
          else if (_attributes.isEmpty)
            _emptyAttributesHint()
          else ...[
            for (var i = 0; i < _attrRows.length; i++) ...[
              _attributeRow(i, _attrRows[i]),
              const SizedBox(height: 10),
            ],
          ],
          _outlineAction(
            icon: Icons.add_circle_outline_rounded,
            label: 'Thêm thuộc tính biến thể',
            onTap: _attributes.isEmpty ? null : () => setState(() => _attrRows.add(_AttrRow())),
          ),
          if (_variantCount > 1) ...[
            const SizedBox(height: 8),
            Text(
              'Tổ hợp đã chọn sẽ tạo $_variantCount biến thể, dùng chung mức giá bên trên.',
              style: ProductUi.t(9.5, FontWeight.w500, ProductUi.sub, height: 1.3),
            ),
          ],
        ],
      ),
    );
  }

  Widget _emptyAttributesHint() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: ProductUi.fieldBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ProductUi.fieldBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cửa hàng chưa có thuộc tính nào (Dung tích, Màu, Size...).',
            style: ProductUi.t(10.5, FontWeight.w600, ProductUi.sub, height: 1.35),
          ),
          const SizedBox(height: 6),
          InkWell(
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ManageCatalogScreen()),
              );
              _loadMeta();
            },
            child: Text(
              'Mở danh mục & thuộc tính →',
              style: ProductUi.t(10.5, FontWeight.w700, ProductUi.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _attributeRow(int index, _AttrRow row) {
    final attribute = _attributeById(row.attributeId);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
      decoration: BoxDecoration(
        color: ProductUi.fieldBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ProductUi.fieldBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: row.attributeId,
                    isExpanded: true,
                    isDense: true,
                    hint: Text('Chọn thuộc tính', style: ProductUi.t(11.5, FontWeight.w500, ProductUi.sub)),
                    style: ProductUi.t(11.5, FontWeight.w600, ProductUi.ink),
                    items: [
                      for (final a in _attributes)
                        DropdownMenuItem(value: a.id, child: Text(a.name)),
                    ],
                    onChanged: (value) => setState(() {
                      row.attributeId = value;
                      row.valueIds.clear();
                    }),
                  ),
                ),
              ),
              InkWell(
                onTap: () => setState(() => _attrRows.removeAt(index)),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.delete_outline_rounded, size: 16, color: ProductUi.sub),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (attribute == null)
            Text('Chọn thuộc tính để thêm giá trị.', style: ProductUi.t(9.5, FontWeight.w500, ProductUi.sub))
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final value in attribute.values)
                  _valueChip(
                    label: value.value,
                    selected: row.valueIds.contains(value.id),
                    onTap: () => setState(() {
                      if (!row.valueIds.remove(value.id)) row.valueIds.add(value.id);
                    }),
                  ),
                _valueChip(label: '+ Giá trị', selected: false, dashed: true, onTap: () => _addAttributeValue(row)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _valueChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    bool dashed = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? ProductUi.roseTile : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? ProductUi.primary : ProductUi.fieldBorder),
        ),
        child: Text(
          label,
          style: ProductUi.t(
            10.5,
            FontWeight.w600,
            selected ? ProductUi.primary : (dashed ? ProductUi.warn : ProductUi.sub),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------ cài đặt

  Widget _buildAdvancedSection() {
    return _section(
      icon: Icons.verified_user_outlined,
      title: 'Cài đặt nâng cao & Nghiệp vụ',
      accent: ProductUi.primary,
      child: Column(
        children: [
          _toggleRow(
            title: 'Quản lý theo Lô & Hạn sử dụng (FEFO)',
            subtitle: 'Tự động xuất hàng theo nguyên tắc cận hạn trước.',
            value: _hasLotTracking,
            onChanged: (v) => setState(() => _hasLotTracking = v),
          ),
          const SizedBox(height: 6),
          _toggleRow(
            title: 'Đang kinh doanh',
            subtitle: 'Tắt để ẩn hàng hóa khỏi danh sách bán tại quầy.',
            value: _isActive,
            onChanged: (v) => setState(() => _isActive = v),
          ),
        ],
      ),
    );
  }

  Widget _toggleRow({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: ProductUi.t(11.5, FontWeight.w700, ProductUi.ink)),
              const SizedBox(height: 2),
              Text(subtitle, style: ProductUi.t(9.5, FontWeight.w500, ProductUi.sub, height: 1.3)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Transform.scale(
          scale: 0.8,
          child: Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: ProductUi.green,
            inactiveTrackColor: const Color(0xFFDDE2F5),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------- mô tả

  Widget _buildDescriptionSection() {
    return _section(
      icon: Icons.notes_rounded,
      title: 'Mô tả & Ghi chú',
      accent: ProductUi.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('Mô tả ngắn & công dụng'),
          const SizedBox(height: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: ProductUi.fieldBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: ProductUi.fieldBorder),
            ),
            child: TextField(
              controller: _descController,
              maxLines: 3,
              style: ProductUi.t(11.5, FontWeight.w500, ProductUi.ink, height: 1.45),
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                hintText: 'Công dụng, thành phần, hướng dẫn bảo quản...',
                hintStyle: ProductUi.t(11, FontWeight.w500, ProductUi.sub),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- bottom bar

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      decoration: const BoxDecoration(
        color: ProductUi.card,
        border: Border(top: BorderSide(color: ProductUi.softLine)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            InkWell(
              onTap: _isSaving ? null : () => Navigator.of(context).maybePop(),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 22),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFEDF0FC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('Hủy', style: ProductUi.t(12.5, FontWeight.w700, ProductUi.sub)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: InkWell(
                onTap: _isSaving ? null : _save,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: ProductUi.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.save_outlined, size: 16, color: Colors.white),
                            const SizedBox(width: 7),
                            Text('Lưu hàng hóa', style: ProductUi.t(13, FontWeight.w700, Colors.white)),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------ widget phụ

  Widget _section({
    required IconData icon,
    required String title,
    required Color accent,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 13),
      decoration: BoxDecoration(
        color: ProductUi.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ProductUi.softLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(color: ProductUi.roseTile, borderRadius: BorderRadius.circular(9)),
                child: Icon(icon, size: 15, color: accent),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: ProductUi.t(13, FontWeight.w700, accent))),
              ?trailing,
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _label(String text, {bool required = false, String? trailing, Widget? trailingWidget}) {
    return Row(
      children: [
        Text(text, style: ProductUi.t(10, FontWeight.w600, ProductUi.label)),
        if (required) Text(' *', style: ProductUi.t(10, FontWeight.w700, ProductUi.primary)),
        const Spacer(),
        if (trailing != null) Text(trailing, style: ProductUi.t(9.5, FontWeight.w500, ProductUi.sub)),
        ?trailingWidget,
      ],
    );
  }

  Widget _linkAction(String text, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: Row(
          children: [
            Icon(icon, size: 11, color: ProductUi.primary),
            const SizedBox(width: 3),
            Text(text, style: ProductUi.t(9.5, FontWeight.w700, ProductUi.primary)),
          ],
        ),
      ),
    );
  }

  Widget _field({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      height: 36,
      decoration: BoxDecoration(
        color: ProductUi.fieldBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ProductUi.fieldBorder),
      ),
      child: Center(child: child),
    );
  }

  Widget _dropdown<T>({
    required T? value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: ProductUi.fieldBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ProductUi.fieldBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          isDense: true,
          hint: Text(hint, style: ProductUi.t(11.5, FontWeight.w500, ProductUi.sub)),
          style: ProductUi.t(11.5, FontWeight.w600, ProductUi.ink),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _outlineAction({required IconData icon, required String label, VoidCallback? onTap}) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: enabled ? ProductUi.primary : ProductUi.fieldBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: enabled ? ProductUi.primary : ProductUi.sub),
            const SizedBox(width: 6),
            Text(
              label,
              style: ProductUi.t(11, FontWeight.w700, enabled ? ProductUi.primary : ProductUi.sub),
            ),
          ],
        ),
      ),
    );
  }
}

/// Chèn dấu chấm hàng nghìn khi gõ tiền, giữ con trỏ ở cuối.
class _ThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(text: '');
    }
    final trimmed = digits.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    final buffer = StringBuffer();
    for (var i = 0; i < trimmed.length; i++) {
      if (i > 0 && (trimmed.length - i) % 3 == 0) buffer.write('.');
      buffer.write(trimmed[i]);
    }
    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

