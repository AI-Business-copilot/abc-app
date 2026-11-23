import 'package:flutter/material.dart';
import 'package:abc_app/core/network/api_error.dart';
import 'package:abc_app/core/theme/app_theme.dart';
import 'package:abc_app/core/widgets/app_widgets.dart';
import 'package:abc_app/features/auth/services/auth_service.dart';
import 'package:abc_app/features/audits/models/audit_models.dart';
import 'package:abc_app/features/audits/services/audits_service.dart';
import 'package:abc_app/features/audits/widgets/audit_count_image_strip.dart';
import 'package:abc_app/features/audits/widgets/audit_history_image_strip.dart';

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
  bool _isRecounting = false;
  String? _error;
  String? _notice;

  final _rejectReasonController = TextEditingController();
  final _recountReasonController = TextEditingController();
  String? _targetUserId;
  String? _secondCounterUserId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _rejectReasonController.dispose();
    _recountReasonController.dispose();
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

  /// The owner sends a conflicting row back to BOTH counters so they count again.
  Future<void> _requestRecount() async {
    final reason = _recountReasonController.text.trim();
    if (reason.isEmpty) {
      setState(() => _error = 'Vui lòng nhập lý do để cả hai người kiểm kê biết cần đếm lại gì.');
      return;
    }
    setState(() {
      _isActing = true;
      _error = null;
    });
    try {
      await _service.requestRecount(widget.auditId, widget.itemId, reason);
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã trả dòng kiểm kê lại cho cả hai người để đếm lại')),
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
    // Every row is counted by two people, so the second counter is required.
    if (_secondCounterUserId == null) {
      setState(() => _error = 'Chọn người kiểm kê thứ hai.');
      return;
    }
    if (_secondCounterUserId == _targetUserId) {
      setState(() => _error = 'Người kiểm kê thứ hai phải khác người được giao.');
      return;
    }
    setState(() {
      _isActing = true;
      _error = null;
    });
    try {
      final updated = await _service.reassignItem(
        widget.auditId,
        widget.itemId,
        _targetUserId!,
        secondCounterUserId: _secondCounterUserId!,
      );
      if (!mounted) return;
      setState(() {
        _item = updated;
        _targetUserId = null;
        _secondCounterUserId = null;
        _notice =
            'Đã giao ${updated.sku} cho ${updated.assignedTo?.name ?? 'nhân viên mới'} '
            'và ${updated.secondCounter?.name ?? 'người kiểm kê thứ hai'}';
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
                      if (item.countAgreement != CountAgreement.single)
                        _buildDualCountCard(item),
                      if (audit?.status == AuditStatus.inProgress &&
                          item.itemStatus == AuditItemStatus.pendingApproval &&
                          AuthService.hasPermission(AppPermissions.auditApproveItem))
                        _buildReviewCard(),
                      if (audit?.status == AuditStatus.inProgress &&
                          item.countAgreement == CountAgreement.conflict &&
                          AuthService.hasPermission(AppPermissions.auditCreate))
                        _buildRecountCard(),
                      if ((audit?.status == AuditStatus.inProgress ||
                              audit?.status == AuditStatus.draft) &&
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

    // A row of a draft has not been counted yet, so it must not claim to be counting.
    final isDraftRow =
        audit?.status == AuditStatus.draft && item.itemStatus == AuditItemStatus.inProgress;
    final statusColor = isDraftRow
        ? AppTheme.muted
        : switch (item.itemStatus) {
            AuditItemStatus.inProgress => AppTheme.warning,
            AuditItemStatus.pendingApproval => AppTheme.accent,
            AuditItemStatus.approved => AppTheme.success,
          };

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
                label: audit == null
                    ? item.itemStatus.label
                    : item.itemStatus.labelForAudit(audit.status),
                color: statusColor,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _Field(label: 'Lô', value: item.lotNumber ?? '—'),
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
          // The row's own reason belongs to the first counter, so every counter's reason and
          // broken goods are listed here. A staff member only ever sees their own.
          if (item.counterDetails.isNotEmpty)
            for (final detail in item.counterDetails) ...[
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.warningBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lý do kiểm kê · ${detail.counter?.name ?? 'Người kiểm kê'}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.warning,
                      ),
                    ),
                    if (detail.countedDamagedQty > 0)
                      Text(
                        'Hàng hỏng: ${detail.countedDamagedQty} sản phẩm hư hỏng',
                        style: const TextStyle(fontSize: 12, color: AppTheme.muted),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      detail.discrepancyReason?.isNotEmpty == true
                          ? detail.discrepancyReason!
                          : 'Không có lý do nào được nhập.',
                      style: const TextStyle(fontSize: 12.5, color: AppTheme.primary),
                    ),
                  ],
                ),
              ),
            ],
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
          if (item.histories.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Lịch sử dòng',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Mỗi lần được duyệt, từ chối hoặc yêu cầu đếm lại đều được ghi lại kèm số của '
                    'từng người kiểm kê.',
                    style: TextStyle(fontSize: 11.5, color: AppTheme.muted),
                  ),
                  const SizedBox(height: 8),
                  ...item.histories.map(
                    (history) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.background,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${history.action.label} • lần ${history.revision}'
                              '${history.createdAt == null ? '' : ' • ${formatDateTime(history.createdAt)}'}'
                              '${history.actor == null ? '' : ' • ${history.actor!.name}'}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Số của dòng lúc đó: ${history.countedQty} dùng được'
                              '${history.countedDamagedQty > 0 ? ', ${history.countedDamagedQty} hàng hỏng' : ''}',
                              style: const TextStyle(fontSize: 11.5, color: AppTheme.muted),
                            ),
                            for (final count in history.counts) ...[
                              const SizedBox(height: 4),
                              Text(
                                '${count.counter?.name ?? 'Người kiểm kê'}: '
                                '${count.countedQty} dùng được'
                                '${count.countedDamagedQty > 0 ? ', ${count.countedDamagedQty} hàng hỏng' : ''}'
                                '${count.discrepancyReason == null || count.discrepancyReason!.isEmpty ? '' : ' • ${count.discrepancyReason}'}',
                                style: const TextStyle(fontSize: 11.5, color: AppTheme.primary),
                              ),
                            ],
                            // The photos taken at that moment.
                            if (history.images.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              AuditHistoryImageStrip(
                                images: history.images,
                                counts: history.counts,
                              ),
                            ],
                            // The reason sits below the numbers and the photos.
                            if (history.reason != null && history.reason!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.warningBg,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: AppTheme.warning.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Lý do ${history.action.label.toLowerCase()}',
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.warning,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      history.reason!,
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        color: AppTheme.warning,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              _Field(label: 'Giao cho', value: item.assignedTo?.name ?? '—'),
              _Field(label: 'Người kiểm kê thứ hai', value: item.secondCounter?.name ?? '—'),
              _Field(label: 'Người gửi', value: item.submittedBy?.name ?? '—'),
              _Field(label: 'Người duyệt', value: item.approvedBy?.name ?? '—'),
            ],
          ),
          if (audit != null) ...[
            const SizedBox(height: 8),
            Text(
              'Đợt kiểm kê ${audit.auditCode} • Kiểm kê lô có sẵn',
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

  /// The owner sees both counters side by side: this is the comparison that drives the decision.
  Widget _buildDualCountCard(StockAuditItem item) {
    final isConflict = item.countAgreement == CountAgreement.conflict;
    final isAgreed = item.countAgreement == CountAgreement.agreed;
    final accent = isConflict
        ? AppTheme.danger
        : isAgreed
            ? AppTheme.success
            : AppTheme.warning;

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Hai người kiểm kê',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.primary),
                ),
              ),
              StatusBadge(label: item.countAgreement.label, color: accent),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            isConflict
                ? 'Hai người đếm khác nhau. Bạn quyết định: cho họ đếm lại hoặc dùng số liệu hiện tại.'
                : isAgreed
                    ? 'Hai người đếm khớp nhau. Dòng này đã sẵn sàng để bạn duyệt.'
                    : item.countAgreement == CountAgreement.notStarted
                        ? 'Chưa ai đếm dòng này. Hai người kiểm kê sẽ đếm riêng.'
                        : 'Đang chờ người kiểm kê còn lại gửi số liệu.',
            style: const TextStyle(fontSize: 11.5, color: AppTheme.muted),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _BigStat(
                  label: 'Trong hệ thống',
                  value: '${item.snapshotQty}',
                  color: AppTheme.primary,
                ),
              ),
              Expanded(
                child: _BigStat(
                  label: 'Người 1',
                  value: item.counts.isNotEmpty ? '${item.counts[0].totalCountedQty}' : '—',
                  color: AppTheme.primary,
                ),
              ),
              Expanded(
                child: _BigStat(
                  label: 'Người 2',
                  value: item.counts.length > 1 ? '${item.counts[1].totalCountedQty}' : '—',
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final row in item.counterRows)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            row.name,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primary,
                            ),
                          ),
                        ),
                        Text(
                          row.hasCount ? (row.isSubmitted ? 'Đã gửi' : 'Chưa gửi') : 'Chưa đếm',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: !row.hasCount
                                ? AppTheme.muted
                                : row.isSubmitted
                                    ? AppTheme.success
                                    : AppTheme.warning,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      row.hasCount
                          ? 'Dùng được: ${row.countedQty} • Hàng hỏng: ${row.countedDamagedQty} '
                              '• Tổng: ${row.countedQty! + (row.countedDamagedQty ?? 0)}'
                          : 'Chưa đếm dòng này.',
                      style: const TextStyle(fontSize: 11.5, color: AppTheme.muted),
                    ),
                    if (row.count?.discrepancyReason != null &&
                        row.count!.discrepancyReason!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      // The reason is written freely, so it gets its own labelled block and wraps
                      // over as many lines as it needs.
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Lý do chênh lệch',
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.muted,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              row.count!.discrepancyReason!,
                              style: const TextStyle(fontSize: 11.5, color: AppTheme.primary),
                            ),
                          ],
                        ),
                      ),
                    ],
                    // The photos each counter took of the broken goods, so the owner can judge the row.
                    if (row.images.isNotEmpty && row.countId != null) ...[
                      const SizedBox(height: 8),
                      AuditCountImageStrip(
                        auditId: widget.auditId,
                        countId: row.countId!,
                        images: row.images,
                        itemId: widget.itemId,
                        service: _service,
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// The owner's resolution for a conflicting row: send both counters back for a recount.
  Widget _buildRecountCard() {
    if (_isRecounting) {
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
              'Vì sao cần đếm lại? *',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.primary),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _recountReasonController,
              maxLines: 3,
              maxLength: 1000,
              style: const TextStyle(fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Ví dụ: hai bên đếm khác nhau, đếm lại kệ B2 cho khớp.',
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
                              _isRecounting = false;
                              _error = null;
                            }),
                    child: const Text('Hủy'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isActing ? null : _requestRecount,
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.warning),
                    child: const Text('Cho đếm lại'),
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
        color: AppTheme.dangerBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.danger.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Hai người có số liệu khác nhau',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.danger),
          ),
          const SizedBox(height: 4),
          const Text(
            'Bạn là người quyết định. Cho cả hai kiểm kê đếm lại từ đầu, hoặc dùng số liệu hiện tại để duyệt.',
            style: TextStyle(fontSize: 11.5, color: AppTheme.danger),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isActing
                  ? null
                  : () => setState(() {
                        _isRecounting = true;
                        _error = null;
                      }),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.warning,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('Cho cả hai đếm lại'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReassignCard(StockAuditItem item) {
    final options = _members.where((m) => m.userId != item.assignedTo?.id).toList();
    // The second counter must be someone other than the primary assignee.
    final secondOptions = options.where((m) => m.userId != _targetUserId).toList();
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
          DropdownButtonFormField<String>(
            initialValue: _secondCounterUserId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Người kiểm kê thứ hai *'),
            items: secondOptions
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
            onChanged: (value) => setState(() => _secondCounterUserId = value),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isActing || _targetUserId == null || _secondCounterUserId == null
                  ? null
                  : _reassign,
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
