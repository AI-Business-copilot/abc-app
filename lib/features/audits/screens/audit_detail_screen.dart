import 'package:flutter/material.dart';
import 'package:abc_app/core/auth/permission_gate.dart';
import 'package:abc_app/core/network/api_error.dart';
import 'package:abc_app/core/theme/app_theme.dart';
import 'package:abc_app/core/widgets/app_widgets.dart';
import 'package:abc_app/features/auth/services/auth_service.dart';
import 'package:abc_app/features/audits/models/audit_models.dart';
import 'package:abc_app/features/audits/screens/audit_count_screen.dart';
import 'package:abc_app/features/audits/screens/audit_item_review_screen.dart';
import 'package:abc_app/features/audits/screens/audit_rows_screen.dart';
import 'package:abc_app/features/audits/services/audits_service.dart';

/// F07 — the audit detail: header stats plus the list of rows.
class AuditDetailScreen extends StatefulWidget {
  const AuditDetailScreen({super.key, required this.auditId});

  final String auditId;

  @override
  State<AuditDetailScreen> createState() => _AuditDetailScreenState();
}

class _AuditDetailScreenState extends State<AuditDetailScreen> {
  final _service = AuditsService();

  StockAudit? _audit;
  List<StockAuditItem> _items = [];
  bool _isLoading = true;
  bool _onlyMine = false;
  String? _error;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _onlyMine = AuthService.isStaff;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final audit = await _service.getAudit(widget.auditId);
      final items = await _service.getAuditItems(widget.auditId, mine: _onlyMine);
      if (!mounted) return;
      setState(() {
        _audit = audit;
        _items = items.items;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final audit = _audit;
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(audit?.auditCode ?? 'Đợt kiểm kê'),
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
            : audit == null
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: MessageBanner(message: _error ?? 'Không tìm thấy đợt kiểm kê.', isError: true),
                  )
                : RefreshIndicator(
                    color: AppTheme.primary,
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      children: [
                        if (_error != null) MessageBanner(message: _error!, isError: true),
                        if (_notice != null) MessageBanner(message: _notice!),
                        _HeaderCard(audit: audit),
                        const SizedBox(height: 12),
                        if (audit.status == AuditStatus.inProgress &&
                            AuthService.hasPermission(AppPermissions.auditApproveItem))
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: AppTheme.successBg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
                            ),
                            child: const Text(
                              'Duyệt từng dòng bên dưới. Đợt kiểm kê được áp dụng vào tồn kho ngay khi dòng cuối cùng được duyệt.',
                              style: TextStyle(fontSize: 12, color: AppTheme.success),
                            ),
                          ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Dòng kiểm kê',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: AppTheme.primary,
                              ),
                            ),
                            if (AuthService.isStaff)
                              Row(
                                children: [
                                  const Text(
                                    'Chỉ dòng của tôi',
                                    style: TextStyle(fontSize: 12, color: AppTheme.muted),
                                  ),
                                  Switch(
                                    value: _onlyMine,
                                    onChanged: (value) {
                                      setState(() => _onlyMine = value);
                                      _load();
                                    },
                                  ),
                                ],
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (_items.isEmpty)
                          EmptyStateView(
                            title: _onlyMine
                                ? 'Bạn chưa được giao dòng nào'
                                : 'Chưa có dòng kiểm kê',
                            subtitle: _onlyMine
                                ? 'Bỏ chọn "Chỉ dòng của tôi" để xem toàn bộ đợt kiểm kê.'
                                : 'Thêm SKU cần kiểm kê và giao từng dòng cho nhân viên.',
                            icon: Icons.playlist_add_check_rounded,
                            action: audit.status == AuditStatus.inProgress && !_onlyMine
                                ? PermissionGate(
                                    permission: AppPermissions.auditCreate,
                                    child: ElevatedButton(
                                      onPressed: _openRowsEditor,
                                      child: const Text('Thêm dòng'),
                                    ),
                                  )
                                : null,
                          )
                        else
                          for (final item in _items)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _AuditItemCard(
                                item: item,
                                audit: audit,
                                onChanged: _load,
                              ),
                            ),
                        if (audit.status == AuditStatus.inProgress &&
                            AuthService.hasPermission(AppPermissions.auditCreate))
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: OutlinedButton.icon(
                              onPressed: _openRowsEditor,
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: const Text('Thêm dòng'),
                            ),
                          ),
                      ],
                    ),
                  ),
      ),
    );
  }

  Future<void> _openRowsEditor() async {
    final audit = _audit;
    if (audit == null) return;
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AuditRowsScreen(auditId: audit.id, auditType: audit.auditType),
      ),
    );
    if (added == true) {
      setState(() => _notice = 'Đã cập nhật phân công.');
      _load();
    }
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.audit});

  final StockAudit audit;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (audit.status) {
      AuditStatus.inProgress => AppTheme.warning,
      AuditStatus.done => AppTheme.success,
      AuditStatus.cancelled => AppTheme.muted,
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
            children: [
              Expanded(
                child: Text(
                  audit.auditCode,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: AppTheme.primary,
                  ),
                ),
              ),
              StatusBadge(label: audit.status.label, color: statusColor),
            ],
          ),
          const SizedBox(height: 6),
          StatusBadge(
            label: audit.auditType.label,
            color: AppTheme.accent,
            background: AppTheme.accent.withValues(alpha: 0.08),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _Stat(label: 'Số dòng', value: '${audit.itemCount}'),
              _Stat(label: 'Bắt đầu', value: formatDay(audit.countStartAt)),
              if (audit.completedAt != null)
                _Stat(label: 'Hoàn thành', value: formatDay(audit.completedAt)),
            ],
          ),
          if (audit.createdBy != null && audit.createdBy!.name.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Người tạo: ${audit.createdBy!.name}',
              style: const TextStyle(fontSize: 11.5, color: AppTheme.muted),
            ),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

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
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.primary),
          ),
        ],
      ),
    );
  }
}

class _AuditItemCard extends StatelessWidget {
  const _AuditItemCard({
    required this.item,
    required this.audit,
    required this.onChanged,
  });

  final StockAuditItem item;
  final StockAudit audit;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (item.itemStatus) {
      AuditItemStatus.inProgress => AppTheme.warning,
      AuditItemStatus.pendingApproval => AppTheme.accent,
      AuditItemStatus.approved => AppTheme.success,
    };

    final canCount = audit.status == AuditStatus.inProgress &&
        item.itemStatus == AuditItemStatus.inProgress &&
        AuthService.hasPermission(AppPermissions.auditCount) &&
        (AuthService.isOwner || item.assignedTo?.id == AuthService.userId);

    final canReview = audit.status == AuditStatus.inProgress &&
        item.itemStatus == AuditItemStatus.pendingApproval &&
        AuthService.hasPermission(AppPermissions.auditApproveItem);

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        color: AppTheme.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'SKU: ${item.sku}'
                      '${item.attributeText.isEmpty ? '' : ' • ${item.attributeText}'}',
                      style: const TextStyle(fontSize: 11.5, color: AppTheme.muted),
                    ),
                  ],
                ),
              ),
              StatusBadge(label: item.itemStatus.label, color: statusColor),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _MiniStat(label: 'Lô', value: item.lotNumber ?? '—'),
              _MiniStat(label: 'Hệ thống', value: item.isNewLot ? '—' : '${item.snapshotQty}'),
              _MiniStat(label: 'Đếm', value: '${item.countedQty}'),
              _MiniStat(
                label: 'Chênh lệch',
                value: item.isNewLot ? '—' : '${item.computedDiff >= 0 ? '+' : ''}${item.computedDiff}',
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Giao cho: ${item.assignedTo?.name ?? '—'}',
            style: const TextStyle(fontSize: 11.5, color: AppTheme.muted),
          ),
          if (item.rejectionReason != null && item.rejectionReason!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.dangerBg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Trả lại để đếm lại: ${item.rejectionReason}',
                style: const TextStyle(fontSize: 11.5, color: AppTheme.danger),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              if (canCount)
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AuditCountScreen(
                            auditId: audit.id,
                            itemId: item.id,
                            auditType: audit.auditType,
                          ),
                        ),
                      );
                      onChanged();
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text('Đếm', style: TextStyle(fontSize: 13)),
                  ),
                ),
              if (canCount && canReview) const SizedBox(width: 8),
              if (canReview)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AuditItemReviewScreen(
                            auditId: audit.id,
                            itemId: item.id,
                          ),
                        ),
                      );
                      onChanged();
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text('Xem chi tiết', style: TextStyle(fontSize: 13)),
                  ),
                ),
              if (!canCount && !canReview)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AuditItemReviewScreen(
                            auditId: audit.id,
                            itemId: item.id,
                          ),
                        ),
                      );
                      onChanged();
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text('Xem chi tiết', style: TextStyle(fontSize: 13)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppTheme.subtle, fontWeight: FontWeight.w600),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.primary),
        ),
      ],
    );
  }
}
