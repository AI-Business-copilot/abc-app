import 'package:flutter/material.dart';
import 'package:abc_app/core/network/api_error.dart';
import 'package:abc_app/core/theme/app_theme.dart';
import 'package:abc_app/core/widgets/app_widgets.dart';
import 'package:abc_app/features/audits/models/audit_models.dart';
import 'package:abc_app/features/audits/services/audits_service.dart';

/// F07 — the counter for one audit row.
///
/// The audit type decides the lot block: a new-lot audit asks the employee for the lot
/// number and expiry, a re-audit keeps the lot the owner assigned but lets the employee
/// correct its dates.
class AuditCountScreen extends StatefulWidget {
  const AuditCountScreen({
    super.key,
    required this.auditId,
    required this.itemId,
    required this.auditType,
  });

  final String auditId;
  final String itemId;
  final AuditType auditType;

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
  final _reasonController = TextEditingController();
  final _lotNumberController = TextEditingController();
  final _fixedLotNumberController = TextEditingController();
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
    _reasonController.dispose();
    _lotNumberController.dispose();
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
      // A fresh re-audit row starts from the lot's own quantity so the employee only adjusts it.
      final isFreshRow = item.discrepancyReason == null && item.countedQty == 0;
      setState(() {
        _item = item;
        _systemQty = item.snapshotQty;
        _countController.text =
            '${item.lotMode == LotMode.existing && isFreshRow ? item.snapshotQty : item.countedQty}';
        _reasonController.text = item.discrepancyReason ?? '';
        _lotNumberController.text = item.lotNumber ?? '';
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

  Future<void> _saveAndSubmit() async {
    final item = _item;
    if (item == null) return;

    final countedQty = int.tryParse(_countController.text.trim()) ?? -1;
    if (countedQty < 0) {
      setState(() => _error = 'Số lượng đếm phải là số lớn hơn hoặc bằng 0.');
      return;
    }
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      setState(() => _error = 'Vui lòng nhập lý do chênh lệch.');
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      if (widget.auditType == AuditType.newLots) {
        final lotNumber = _lotNumberController.text.trim();
        if (lotNumber.isEmpty || _expirationDate == null) {
          setState(() {
            _error = 'Lô mới cần có số lô và hạn sử dụng.';
            _isSaving = false;
          });
          return;
        }
        await _service.updateCount(
          widget.auditId,
          widget.itemId,
          countedQty: countedQty,
          discrepancyReason: reason,
          newLotNumber: lotNumber,
          newLotExpirationDate: _expirationDate,
          newLotManufacturingDate: _manufacturingDate,
        );
      } else {
        await _service.updateCount(
          widget.auditId,
          widget.itemId,
          countedQty: countedQty,
          discrepancyReason: reason,
          lotItemId: item.lotItemId,
          newLotExpirationDate: _expirationDate,
          newLotManufacturingDate: _manufacturingDate,
        );
      }
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
                      if (widget.auditType == AuditType.reAudit)
                        _buildFixedLotSection(item)
                      else
                        _buildNewLotSection(),
                      const SizedBox(height: 16),
                      _buildCounterSection(item),
                      const SizedBox(height: 16),
                      _buildReasonSection(),
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

  Widget _buildNewLotSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.warningBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Lô mới chưa có trong hệ thống. Lô sẽ được tạo khi chủ cửa hàng áp dụng đợt kiểm kê.',
            style: TextStyle(fontSize: 11.5, color: AppTheme.warning),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _lotNumberController,
            maxLength: 100,
            style: const TextStyle(fontSize: 14),
            decoration: const InputDecoration(
              labelText: 'Số lô *',
              counterText: '',
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _DateField(
                  label: 'Hạn sử dụng *',
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
        ],
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
                  label: 'Hạn sử dụng *',
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
        ],
      ),
    );
  }

  Widget _buildCounterSection(StockAuditItem item) {
    final diff = int.tryParse(_countController.text.trim());
    final showDiff = !item.isNewLot && diff != null;
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
          if (!item.isNewLot) ...[
            Text(
              'Số lượng hệ thống: $_systemQty',
              style: const TextStyle(fontSize: 12.5, color: AppTheme.muted),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _countController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  decoration: const InputDecoration(labelText: 'Số lượng đếm *'),
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
