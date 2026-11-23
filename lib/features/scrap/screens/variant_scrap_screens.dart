import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:abc_app/core/network/api_error.dart';
import 'package:abc_app/core/theme/app_theme.dart';
import 'package:abc_app/core/widgets/app_widgets.dart';
import 'package:abc_app/features/lots/models/lot_models.dart';
import 'package:abc_app/features/lots/services/lots_service.dart';
import 'package:abc_app/features/scrap/models/scrap_models.dart';
import 'package:abc_app/features/scrap/services/scrap_upload_service.dart';

/// F08 — the staff quarantines a product that has no lot item.
///
/// A product with no lot cannot use the lot quarantine, so the quantity pulled off the shelf is
/// recorded on the variant. Once quarantined, a scrap order can be raised for it.
class QuarantineVariantScreen extends StatefulWidget {
  const QuarantineVariantScreen({
    super.key,
    required this.variantId,
    required this.sku,
    required this.productName,
    required this.stock,
  });

  final String variantId;
  final String sku;
  final String productName;
  final int stock;

  @override
  State<QuarantineVariantScreen> createState() => _QuarantineVariantScreenState();
}

class _QuarantineVariantScreenState extends State<QuarantineVariantScreen> {
  final _service = LotsService();

  late final TextEditingController _qtyController =
      TextEditingController(text: '${widget.stock}');
  final _noteController = TextEditingController();
  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _qtyController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final quantity = int.tryParse(_qtyController.text.trim());
    if (quantity == null || quantity <= 0) {
      setState(() => _error = 'Số lượng phải là số nguyên lớn hơn 0.');
      return;
    }
    if (quantity > widget.stock) {
      setState(() => _error = 'Sản phẩm này chỉ còn ${widget.stock} sản phẩm.');
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      await _service.quarantineVariant(
        widget.variantId,
        quantity: quantity,
        note: _noteController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã cách ly sản phẩm')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Cách ly sản phẩm'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_error != null) MessageBanner(message: _error!, isError: true),
            Text(
              '${widget.productName} · ${widget.sku}',
              style: const TextStyle(fontSize: 13, color: AppTheme.muted),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _qtyController,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                labelText: 'Số lượng cách ly (tối đa ${widget.stock})',
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _noteController,
              maxLines: 2,
              maxLength: 500,
              style: const TextStyle(fontSize: 14),
              decoration: const InputDecoration(
                labelText: 'Ghi chú (không bắt buộc)',
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Spacer(),
                OutlinedButton(
                  onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                  child: const Text('Hủy'),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _isSaving ? null : _submit,
                  child: _isSaving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Cách ly'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// F08 — the staff raises a scrap order for a quarantined product that has no lot item.
///
/// The evidence photos (1 to 10) are sent with the create request and cannot be added
/// or removed afterwards.
class CreateVariantScrapScreen extends StatefulWidget {
  const CreateVariantScrapScreen({
    super.key,
    required this.quarantine,
  });

  final VariantQuarantine quarantine;

  @override
  State<CreateVariantScrapScreen> createState() => _CreateVariantScrapScreenState();
}

class _CreateVariantScrapScreenState extends State<CreateVariantScrapScreen> {
  final _uploadService = ScrapUploadService();
  final _picker = ImagePicker();

  late final TextEditingController _qtyController =
      TextEditingController(text: '${widget.quarantine.quarantineQty}');
  final _reasonController = TextEditingController();
  final List<XFile> _photos = [];
  bool _isSaving = false;
  String? _error;

  int get _maxQuantity => widget.quarantine.quarantineQty;

  @override
  void dispose() {
    _qtyController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    if (_photos.length >= maxScrapImages) {
      setState(() => _error = 'Mỗi phiếu có tối đa $maxScrapImages ảnh.');
      return;
    }
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (picked == null || !mounted) return;

      final size = await File(picked.path).length();
      if (size > maxScrapImageBytes) {
        setState(() => _error = 'Ảnh lớn hơn 5 MB. Hãy chọn ảnh nhỏ hơn.');
        return;
      }

      setState(() {
        _photos.add(picked);
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Không mở được máy ảnh hoặc thư viện ảnh.');
    }
  }

  void _showPhotoOptions() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: const Text('Chụp ảnh'),
              onTap: () {
                Navigator.of(ctx).pop();
                _pick(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Chọn từ thư viện'),
              onTap: () {
                Navigator.of(ctx).pop();
                _pick(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final quantity = int.tryParse(_qtyController.text.trim());
    if (quantity == null || quantity <= 0 || quantity > _maxQuantity) {
      setState(() => _error = 'Số lượng phải là số nguyên từ 1 đến $_maxQuantity.');
      return;
    }
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      setState(() => _error = 'Vui lòng nhập lý do hủy hàng.');
      return;
    }
    if (_photos.isEmpty) {
      setState(() => _error = 'Vui lòng thêm ít nhất một ảnh bằng chứng.');
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      await _uploadService.createScrapOrder(
        variantId: widget.quarantine.variantId,
        scrapReason: reason,
        scrapQty: quantity,
        images: _photos.map((photo) => File(photo.path)).toList(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã tạo phiếu hủy hàng')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final quarantine = widget.quarantine;
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Tạo phiếu hủy hàng'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_error != null) MessageBanner(message: _error!, isError: true),
            Text(
              '${quarantine.productName} · ${quarantine.sku} · đang cách ly ${quarantine.quarantineQty}',
              style: const TextStyle(fontSize: 13, color: AppTheme.muted),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _qtyController,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              decoration: InputDecoration(labelText: 'Số lượng hủy (tối đa $_maxQuantity)'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _reasonController,
              maxLines: 1,
              maxLength: 255,
              style: const TextStyle(fontSize: 14),
              decoration: const InputDecoration(
                labelText: 'Lý do hủy',
                hintText: 'Ví dụ: hư hỏng, bao bì xé, không bán được',
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Ảnh bằng chứng',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.primary),
                ),
                Text(
                  '${_photos.length}/$maxScrapImages ảnh • JPEG, PNG, WebP • tối đa 5 MB',
                  style: const TextStyle(fontSize: 10.5, color: AppTheme.muted),
                ),
              ],
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _photos.length >= maxScrapImages ? null : _showPhotoOptions,
              icon: const Icon(Icons.add_a_photo_rounded, size: 18),
              label: const Text('Thêm ảnh'),
            ),
            if (_photos.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 110,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _photos.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final photo = _photos[index];
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(
                            File(photo.path),
                            width: 110,
                            height: 110,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: GestureDetector(
                            onTap: () => setState(() => _photos.removeAt(index)),
                            child: const CircleAvatar(
                              radius: 12,
                              backgroundColor: Colors.black54,
                              child: Icon(Icons.close_rounded, size: 15, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                const Spacer(),
                OutlinedButton(
                  onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                  child: const Text('Hủy'),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _isSaving ? null : _submit,
                  child: _isSaving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Tạo phiếu'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
