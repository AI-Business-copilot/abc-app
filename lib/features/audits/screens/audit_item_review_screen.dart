import 'package:flutter/material.dart';
import 'package:abc_app/core/network/api_error.dart';
import 'package:abc_app/core/theme/app_theme.dart';
import 'package:abc_app/core/widgets/app_widgets.dart';
import 'package:abc_app/features/auth/services/auth_service.dart';
import 'package:abc_app/features/audits/models/audit_models.dart';
import 'package:abc_app/features/audits/services/audits_service.dart';

/// F07 — the owner reviews one counted row: approve it, send it back with a reason,
/// or hand it to another employee.
class AuditItemReviewScreen extends StatefulWidget {
  const AuditItemReviewScreen({
    super.key,
    required this.auditId,
    required this.itemId,
  });

  final String auditId;
  final String itemId;

  @override
  State<AuditItemReviewScreen> createState() => _AuditItemReviewScreenState();
}

class _AuditItemReviewScreenState extends State<AuditItemReviewScreen> {
  final _service = AuditsService();

  StockAudit? _audit;
  StockAuditItem? _item;
  List<StaffMember> _members = [];
  bool _isLoading = true;
  bool _isActing = false;
  bool _isRejecting = false;
  String? _error;
  String? _notice;

  final _rejectReasonController = TextEditingController();
  String? _targetUserId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _rejectReasonController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final audit = await _service.getAudit(widget.auditId);
      final item = await _service.getAuditItem(widget.auditId, widget.itemId);
      List<StaffMember> members = const [];
      if (AuthService.hasPermission(AppPermissions.auditCreate)) {
        try {
          members = (await _service.getMembers()).where((m) => m.isAssignable).toList();
        } catch (_) {
          members = const [];
        }
      }
      if (!mounted) return;
      setState(() {
        _audit = audit;
        _item = item;
        _members = members;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _approve() async {
    setState(() {
      _isActing = true;
      _error = null;
    });
    try {
      final result = await _service.approveItem(widget.auditId, widget.itemId);
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.auditAutoApplied
                ? 'Đã duyệt. Tất cả dòng đã duyệt nên đợt kiểm kê được áp dụng vào tồn kho.'
                : 'Đã duyệt dòng kiểm kê.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  Future<void> _reject() async {
    final reason = _rejectReasonController.text.trim();
    if (reason.isEmpty) {
      setState(() => _error = 'Vui lòng nhập lý do để nhân viên biết cần đếm lại gì.');
      return;
    }
    setState(() {
      _isActing = true;
      _error = null;
    });
    try {
      await _service.rejectItem(widget.auditId, widget.itemId, reason);
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã trả dòng kiểm kê lại cho nhân viên để đếm lại')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  Future<void> _reassign() async {
    if (_targetUserId == null) return;
    setState(() {
      _isActing = true;
      _error = null;
    });
    try {
      final updated = await _service.reassignItem(
        widget.auditId,
        widget.itemId,
        _targetUserId!,
      );
      if (!mounted) return;
      setState(() {
        _item = updated;
        _targetUserId = null;
        _notice = 'Đã chuyển ${updated.sku} cho ${updated.assignedTo?.name ?? 'nhân viên mới'}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = _item;
    final audit = _audit;
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Chi tiết dòng kiểm kê'),
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
                      if (_notice != null) MessageBanner(message: _notice!),
                      _buildItemCard(item, audit),
                      if (audit?.status == AuditStatus.inProgress &&
                          item.itemStatus == AuditItemStatus.pendingApproval &&
                          AuthService.hasPermission(AppPermissions.auditApproveItem))
                        _buildReviewCard(),
                      if (audit?.status == AuditStatus.inProgress &&
                          item.itemStatus == AuditItemStatus.inProgress &&
                          AuthService.hasPermission(AppPermissions.auditCreate))
                        _buildReassignCard(item),
                    ],
                  ),
      ),
    );
  }

  Widget _buildItemCard(StockAuditItem item, StockAudit? audit) {
    final diff = item.computedDiff;
    final isNewLot = item.isNewLot;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
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
                  ],
                ),
              ),
              StatusBadge(
                label: item.itemStatus.label,
                color: switch (item.itemStatus) {
                  AuditItemStatus.inProgress => AppTheme.warning,
                  AuditItemStatus.pendingApproval => AppTheme.accent,
                  AuditItemStatus.approved => AppTheme.success,
                },
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              if (!isNewLot) _Field(label: 'Lô', value: item.lotNumber ?? '—'),
              _Field(label: 'Hạn sử dụng', value: formatDay(item.expirationDate)),
              _Field(label: 'Ngày sản xuất', value: formatDay(item.manufacturingDate)),
            ],
          ),
          if (item.datesCorrected) ...[
            const SizedBox(height: 6),
            Text(
              'Hệ thống đang ghi: HSD ${formatDay(item.lotExpirationDate)} • NSX ${formatDay(item.lotManufacturingDate)}',
              style: const TextStyle(fontSize: 11, color: AppTheme.warning),
            ),
          ],
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                if (!isNewLot)
                  Expanded(
                    child: _BigStat(
                      label: 'Trong hệ thống',
                      value: '${item.snapshotQty}',
                      color: AppTheme.primary,
                    ),
                  ),
                Expanded(
                  child: _BigStat(
                    label: 'Số lượng đếm',
                    value: '${item.countedQty}',
                    color: AppTheme.primary,
                  ),
                ),
                if (!isNewLot)
                  Expanded(
                    child: _BigStat(
                      label: 'Chênh lệch',
                      value: '${diff >= 0 ? '+' : ''}$diff',
                      color: diff == 0 ? AppTheme.success : AppTheme.danger,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.warningBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Lý do kiểm kê',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.warning),
                ),
                const SizedBox(height: 4),
                Text(
                  item.discrepancyReason?.isNotEmpty == true
                      ? item.discrepancyReason!
                      : 'Không có lý do nào được nhập.',
                  style: const TextStyle(fontSize: 12.5, color: AppTheme.primary),
                ),
              ],
            ),
          ),
          if (item.rejectionReason != null && item.rejectionReason!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
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
                    '${item.rejectedBy == null ? '' : ' bởi ${item.rejectedBy!.name}'}'
                    '${item.rejectedAt == null ? '' : ' lúc ${formatDateTime(item.rejectedAt)}'}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.danger,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.rejectionReason!,
                    style: const TextStyle(fontSize: 12.5, color: AppTheme.danger),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              _Field(label: 'Giao cho', value: item.assignedTo?.name ?? '—'),
              _Field(label: 'Người gửi', value: item.submittedBy?.name ?? '—'),
              _Field(label: 'Người duyệt', value: item.approvedBy?.name ?? '—'),
            ],
          ),
          if (audit != null) ...[
            const SizedBox(height: 8),
            Text(
              'Đợt kiểm kê ${audit.auditCode} • ${audit.auditType.label}',
              style: const TextStyle(fontSize: 11.5, color: AppTheme.muted),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReviewCard() {
    if (_isRejecting) {
      return Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Vì sao trả lại kết quả đếm này? *',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.primary),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _rejectReasonController,
              maxLines: 3,
              maxLength: 1000,
              style: const TextStyle(fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Ví dụ: vui lòng đếm lại kệ B2, số lượng có vẻ quá thấp.',
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isActing
                        ? null
                        : () => setState(() {
                              _isRejecting = false;
                              _error = null;
                            }),
                    child: const Text('Hủy'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isActing ? null : _reject,
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
                    child: const Text('Trả lại để đếm lại'),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Duyệt dòng kiểm kê',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.primary),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _isActing ? null : _approve,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Duyệt'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: _isActing
                      ? null
                      : () => setState(() {
                            _isRejecting = true;
                            _error = null;
                          }),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.danger,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Từ chối'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReassignCard(StockAuditItem item) {
    final options = _members.where((m) => m.userId != item.assignedTo?.id).toList();
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Phân công lại',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.primary),
          ),
          const SizedBox(height: 4),
          const Text(
            'Chuyển dòng này cho nhân viên khác khi người phụ trách đã nghỉ việc hoặc không có mặt hôm nay.',
            style: TextStyle(fontSize: 11.5, color: AppTheme.muted),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _targetUserId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Giao cho'),
            items: options
                .map(
                  (member) => DropdownMenuItem(
                    value: member.userId,
                    child: Text(
                      member.fullName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _targetUserId = value),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isActing || _targetUserId == null ? null : _reassign,
              child: const Text('Chuyển cho nhân viên này'),
            ),
          ),
          if (options.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Không còn nhân viên nào khác đang hoạt động để nhận dòng này.',
                style: TextStyle(fontSize: 11.5, color: AppTheme.warning),
              ),
            ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: AppTheme.subtle,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.primary),
          ),
        ],
      ),
    );
  }
}

class _BigStat extends StatelessWidget {
  const _BigStat({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label.toUpperCase(),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: AppTheme.subtle,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color),
        ),
      ],
    );
  }
}
