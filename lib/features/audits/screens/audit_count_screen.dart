import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:abc_app/core/network/api_error.dart';
import 'package:abc_app/core/theme/app_theme.dart';
import 'package:abc_app/core/widgets/app_widgets.dart';
import 'package:abc_app/features/audits/models/audit_models.dart';
import 'package:abc_app/features/audits/services/audits_service.dart';

/// F07 — the counter for one audit row.
///
/// The lot was chosen by the owner and is fixed: the employee counts it and may correct its dates.
class AuditCountScreen extends StatefulWidget {
  const AuditCountScreen({
    super.key,
    required this.auditId,
    required this.itemId,
  });

  final String auditId;
  final String itemId;

  @override
  State<AuditCountScreen> createState() => _AuditCountScreenState();
}

class _AuditCountScreenState extends State<AuditCountScreen> {
  final _service = AuditsService();

  StockAuditItem? _item;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  final _countController = TextEditingController();
  final _damagedCountController = TextEditingController();
  final _reasonController = TextEditingController();
  final _fixedLotNumberController = TextEditingController();
  final _picker = ImagePicker();
  /// The evidence photos of the broken goods, sent with the count.
  final List<XFile> _photos = [];
  String? _expirationDate;
  String? _manufacturingDate;
  int _systemQty = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _countController.dispose();
    _damagedCountController.dispose();
    _reasonController.dispose();
    _fixedLotNumberController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final item = await _service.getAuditItem(widget.auditId, widget.itemId);
      if (!mounted) return;
      // Blind counting: the server only ever sends this employee their own count,
      // so the form must start from it and never from the other counter's number.
      final ownCount = item.counts.isEmpty ? null : item.counts.first;
      // A fresh row starts from the lot's own quantity so the employee only adjusts it.
      final isFreshRow = ownCount == null && item.discrepancyReason == null && item.countedQty == 0;
      setState(() {
        _item = item;
        _systemQty = item.snapshotQty;
        _countController.text = '${isFreshRow ? item.snapshotQty : ownCount?.countedQty ?? item.countedQty}';
        _damagedCountController.text = '${ownCount?.countedDamagedQty ?? item.countedDamagedQty}';
        _reasonController.text = ownCount?.discrepancyReason ?? item.discrepancyReason ?? '';
        _fixedLotNumberController.text = item.lotNumber ?? '';
        _expirationDate = _toDayValue(item.expirationDate);
        _manufacturingDate = _toDayValue(item.newLotManufacturingDate ?? item.manufacturingDate);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Takes a photo of the broken goods, or picks one from the gallery.
  Future<void> _pickPhoto(ImageSource source) async {
    if (_photos.length >= maxAuditImages) {
      setState(() => _error = 'Một lần đếm có tối đa $maxAuditImages ảnh.');
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
      if (size > maxAuditImageBytes) {
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
                _pickPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Chọn từ thư viện'),
              onTap: () {
                Navigator.of(ctx).pop();
                _pickPhoto(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveAndSubmit() async {
    final item = _item;
    if (item == null) return;

    final countedQty = int.tryParse(_countController.text.trim()) ?? -1;
    if (countedQty < 0) {
      setState(() => _error = 'Số lượng đếm phải là số lớn hơn hoặc bằng 0.');
      return;
    }
    // The broken goods are counted separately from the usable quantity; the total is derived.
    final countedDamagedQty = int.tryParse(_damagedCountController.text.trim()) ?? 0;
    if (countedDamagedQty < 0) {
      setState(() => _error = 'Số lượng hàng hỏng phải là số lớn hơn hoặc bằng 0.');
      return;
    }
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      setState(() => _error = 'Vui lòng nhập lý do chênh lệch.');
      return;
    }
    // Broken goods are documented with photos, so the owner can see what was found.
    if (countedDamagedQty > 0 && _photos.isEmpty) {
      setState(() => _error = 'Khi phát hiện hàng hỏng, bắt buộc có ít nhất một ảnh bằng chứng.');
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      await _service.updateCount(
        widget.auditId,
        widget.itemId,
        countedQty: countedQty,
        countedDamagedQty: countedDamagedQty,
        discrepancyReason: reason,
        lotItemId: item.lotItemId,
        newLotExpirationDate: _expirationDate,
        newLotManufacturingDate: _manufacturingDate,
        images: _photos.map((photo) => File(photo.path)).toList(),
      );
      await _service.submitItem(widget.auditId, widget.itemId);
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${item.sku} đã được gửi duyệt')),
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
    final item = _item;
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Đếm hàng'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                ),
              )
            : item == null
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: MessageBanner(
                      message: _error ?? 'Không tìm thấy dòng kiểm kê.',
                      isError: true,
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_error != null) MessageBanner(message: _error!, isError: true),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.productName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: AppTheme.primary,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'SKU: ${item.sku}'
                              '${item.attributeText.isEmpty ? '' : ' • ${item.attributeText}'}',
                              style: const TextStyle(fontSize: 12, color: AppTheme.muted),
                            ),
                            const SizedBox(height: 8),
                            StatusBadge(
                              label: item.itemStatus.label,
                              color: item.itemStatus == AuditItemStatus.inProgress
                                  ? AppTheme.warning
                                  : AppTheme.accent,
                            ),
                          ],
                        ),
                      ),
                      if (item.rejectionReason != null &&
                          item.rejectionReason!.isNotEmpty &&
                          item.itemStatus == AuditItemStatus.inProgress) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.dangerBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.danger.withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Bị trả lại để đếm lại'
                                '${item.rejectedBy == null ? '' : ' bởi ${item.rejectedBy!.name}'}',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.danger,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.rejectionReason!,
                                style: const TextStyle(fontSize: 12, color: AppTheme.danger),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      _buildFixedLotSection(item),
                      const SizedBox(height: 16),
                      _buildCounterSection(item),
                      const SizedBox(height: 16),
                      _buildReasonSection(),
                      const SizedBox(height: 16),
                      _buildPhotoSection(),
                      const SizedBox(height: 24),
                      if (item.itemStatus == AuditItemStatus.inProgress)
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _isSaving
                                    ? null
                                    : () => Navigator.of(context).pop(false),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                child: const Text('Hủy'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton(
                                onPressed: _isSaving ? null : _saveAndSubmit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.success,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                child: _isSaving
                                    ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text('Lưu & Gửi duyệt'),
                              ),
                            ),
                          ],
                        )
                      else
                        const MessageBanner(
                          message: 'Dòng kiểm kê không còn ở trạng thái đang thực hiện nên không thể sửa.',
                        ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildFixedLotSection(StockAuditItem item) {
    final expiryChanged = _expirationDate != _toDayValue(item.lotExpirationDate);
    final mfgChanged = _manufacturingDate != _toDayValue(item.lotManufacturingDate);
    final dateOrderInvalid = _expirationDate != null &&
        _manufacturingDate != null &&
        _manufacturingDate!.compareTo(_expirationDate!) > 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _fixedLotNumberController,
            readOnly: true,
            enabled: false,
            style: const TextStyle(fontSize: 14),
            decoration: const InputDecoration(labelText: 'Số lô'),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _DateField(
                  label: 'Hạn sử dụng',
                  value: _expirationDate,
                  onChanged: (value) => setState(() => _expirationDate = value),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DateField(
                  label: 'Ngày sản xuất',
                  value: _manufacturingDate,
                  onChanged: (value) => setState(() => _manufacturingDate = value),
                ),
              ),
            ],
          ),
          if (expiryChanged || mfgChanged) ...[
            const SizedBox(height: 8),
            Text(
              'Hệ thống đang ghi: HSD ${formatDay(item.lotExpirationDate)} • NSX ${formatDay(item.lotManufacturingDate)}',
              style: const TextStyle(fontSize: 11, color: AppTheme.warning),
            ),
          ],
          if (dateOrderInvalid)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Ngày sản xuất không được sau hạn sử dụng.',
                style: TextStyle(fontSize: 11.5, color: AppTheme.danger),
              ),
            ),
          const SizedBox(height: 8),
          const Text(
            'Lô đã được chủ cửa hàng chỉ định và không thể thay đổi. Bạn vẫn có thể sửa ngày của lô.',
            style: TextStyle(fontSize: 11.5, color: AppTheme.muted),
          ),
          const SizedBox(height: 4),
          const Text(
            'Bỏ trống nếu sản phẩm không có hạn sử dụng (quần áo, phụ kiện). Mỹ phẩm thì nhập hạn sử dụng của lô.',
            style: TextStyle(fontSize: 11, color: AppTheme.muted),
          ),
        ],
      ),
    );
  }

  Widget _buildCounterSection(StockAuditItem item) {
    final diff = int.tryParse(_countController.text.trim());
    final damaged = int.tryParse(_damagedCountController.text.trim()) ?? 0;
    final showDiff = diff != null;
    // The total is derived, never typed: usable + broken.
    final total = (diff ?? 0) + damaged;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Số lượng hệ thống: $_systemQty',
            style: const TextStyle(fontSize: 12.5, color: AppTheme.muted),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _countController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  decoration: const InputDecoration(labelText: 'Số lượng sử dụng được *'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline_rounded, color: AppTheme.muted),
                onPressed: () {
                  final current = int.tryParse(_countController.text.trim()) ?? 0;
                  _countController.text = '${current > 0 ? current - 1 : 0}';
                  setState(() {});
                },
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline_rounded, color: AppTheme.muted),
                onPressed: () {
                  final current = int.tryParse(_countController.text.trim()) ?? 0;
                  _countController.text = '${current + 1}';
                  setState(() {});
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _damagedCountController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  decoration: const InputDecoration(labelText: 'Số lượng hàng hỏng'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline_rounded, color: AppTheme.muted),
                onPressed: () {
                  final current = int.tryParse(_damagedCountController.text.trim()) ?? 0;
                  _damagedCountController.text = '${current > 0 ? current - 1 : 0}';
                  setState(() {});
                },
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline_rounded, color: AppTheme.muted),
                onPressed: () {
                  final current = int.tryParse(_damagedCountController.text.trim()) ?? 0;
                  _damagedCountController.text = '${current + 1}';
                  setState(() {});
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Tổng số lượng bàn giao: $total',
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.primary),
          ),
          const Text(
            'Tổng = số lượng sử dụng được + số lượng hàng hỏng. Tổng được tính tự động.',
            style: TextStyle(fontSize: 11, color: AppTheme.muted),
          ),
          if (showDiff) ...[
            const SizedBox(height: 8),
            Text(
              'Chênh lệch: ${diff - _systemQty >= 0 ? '+' : ''}${diff - _systemQty}',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: diff - _systemQty == 0 ? AppTheme.success : AppTheme.danger,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// The evidence photos of the broken goods. A photo is required when broken goods were counted.
  Widget _buildPhotoSection() {
    final damaged = int.tryParse(_damagedCountController.text.trim()) ?? 0;
    final required = damaged > 0;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Ảnh bằng chứng hàng hỏng',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.primary),
              ),
              if (required)
                const Text(
                  ' *',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.danger),
                ),
              const Spacer(),
              Text(
                '${_photos.length}/$maxAuditImages ảnh • JPEG, PNG, WebP • tối đa 5 MB',
                style: const TextStyle(fontSize: 10.5, color: AppTheme.muted),
              ),
            ],
          ),
          if (required) ...[
            const SizedBox(height: 4),
            const Text(
              'Bạn đã đếm ra hàng hỏng, nên cần ít nhất một ảnh để chủ cửa hàng đối chiếu.',
              style: TextStyle(fontSize: 11, color: AppTheme.warning),
            ),
          ],
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _isSaving || _photos.length >= maxAuditImages ? null : _showPhotoOptions,
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
        ],
      ),
    );
  }

  Widget _buildReasonSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Lý do chênh lệch *',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.primary),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _reasonController,
            maxLines: 3,
            maxLength: 1000,
            style: const TextStyle(fontSize: 14),
            decoration: const InputDecoration(
              hintText: 'Ví dụ: kệ B2 bị thiếu 2 sản phẩm, đã kiểm tra lại kỹ.',
            ),
          ),
          const Text(
            'Mọi dòng kiểm kê đều phải nhập lý do, kể cả khi không chênh lệch.',
            style: TextStyle(fontSize: 11, color: AppTheme.muted),
          ),
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: value != null ? DateTime.tryParse(value!) ?? now : now,
          firstDate: DateTime(now.year - 10),
          lastDate: DateTime(now.year + 20),
        );
        if (picked == null) return;
        final text =
            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
        onChanged(text);
      },
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(
          value == null ? 'Chọn ngày' : formatDay(DateTime.tryParse(value!)),
          style: const TextStyle(fontSize: 14),
        ),
      ),
    );
  }
}

String? _toDayValue(DateTime? value) {
  if (value == null) return null;
  final d = value.toLocal();
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
