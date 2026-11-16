import 'package:flutter/material.dart';
import 'package:abc_app/core/network/api_error.dart';
import 'package:abc_app/core/theme/app_theme.dart';
import 'package:abc_app/core/widgets/app_widgets.dart';
import 'package:abc_app/features/auth/services/auth_service.dart';
import 'package:abc_app/features/audits/models/audit_models.dart';
import 'package:abc_app/features/audits/screens/audit_create_screen.dart';
import 'package:abc_app/features/audits/screens/audit_detail_screen.dart';
import 'package:abc_app/features/audits/services/audits_service.dart';

/// F07 — the list of stock audits, with a status filter.
class AuditsListScreen extends StatefulWidget {
  const AuditsListScreen({super.key});

  @override
  State<AuditsListScreen> createState() => _AuditsListScreenState();
}

class _AuditsListScreenState extends State<AuditsListScreen> {
  final _service = AuditsService();

  List<StockAudit> _audits = [];
  PaginationInfo _pagination = PaginationInfo.empty;
  String? _status;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({int? page}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final result = await _service.listAudits(status: _status, page: page ?? 1);
      if (!mounted) return;
      setState(() {
        _audits = result.audits;
        _pagination = result.pagination;
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
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            FilterChipBar<String?>(
              options: const [null, 'IN_PROGRESS', 'DONE', 'CANCELLED'],
              selected: _status,
              labelOf: (value) {
                switch (value) {
                  case 'IN_PROGRESS':
                    return 'Đang thực hiện';
                  case 'DONE':
                    return 'Hoàn thành';
                  case 'CANCELLED':
                    return 'Đã hủy';
                  default:
                    return 'Tất cả';
                }
              },
              onSelected: (value) {
                setState(() => _status = value);
                _load();
              },
            ),
            Expanded(
              child: RefreshIndicator(
                color: AppTheme.primary,
                onRefresh: _load,
                child: _isLoading && _audits.isEmpty
                    ? const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                        ),
                      )
                    : _error != null
                        ? ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              const SizedBox(height: 40),
                              MessageBanner(message: _error!, isError: true),
                            ],
                          )
                        : _audits.isEmpty
                            ? ListView(
                                children: const [
                                  SizedBox(height: 40),
                                  EmptyStateView(
                                    title: 'Chưa có đợt kiểm kê nào',
                                    subtitle: 'Chủ cửa hàng tạo đợt kiểm kê và giao dòng cho nhân viên.',
                                    icon: Icons.fact_check_outlined,
                                  ),
                                ],
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                                itemCount: _audits.length,
                                separatorBuilder: (_, _) => const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final audit = _audits[index];
                                  return _AuditCard(
                                    audit: audit,
                                    onTap: () async {
                                      await Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => AuditDetailScreen(auditId: audit.id),
                                        ),
                                      );
                                      _load();
                                    },
                                  );
                                },
                              ),
              ),
            ),
            if (_pagination.totalPages > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Trang ${_pagination.page}/${_pagination.totalPages}',
                      style: const TextStyle(fontSize: 12, color: AppTheme.muted),
                    ),
                    Row(
                      children: [
                        OutlinedButton(
                          onPressed: _pagination.page <= 1
                              ? null
                              : () => _load(page: _pagination.page - 1),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          child: const Text('Trước', style: TextStyle(fontSize: 12)),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: _pagination.page >= _pagination.totalPages
                              ? null
                              : () => _load(page: _pagination.page + 1),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          child: const Text('Sau', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            if (AuthService.hasPermission(AppPermissions.auditCreate))
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final created = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(builder: (_) => const AuditCreateScreen()),
                      );
                      if (created == true) _load();
                    },
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Tạo đợt kiểm kê'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AuditCard extends StatelessWidget {
  const _AuditCard({required this.audit, required this.onTap});

  final StockAudit audit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = audit.status;
    final color = switch (status) {
      AuditStatus.inProgress => AppTheme.warning,
      AuditStatus.done => AppTheme.success,
      AuditStatus.cancelled => AppTheme.muted,
    };

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    audit.auditCode,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${audit.itemCount} dòng • Bắt đầu ${formatDay(audit.countStartAt)}',
                    style: const TextStyle(fontSize: 11.5, color: AppTheme.muted),
                  ),
                  if (audit.completedAt != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Hoàn thành ${formatDay(audit.completedAt)}',
                      style: const TextStyle(fontSize: 11.5, color: AppTheme.muted),
                    ),
                  ],
                ],
              ),
            ),
            StatusBadge(label: status.label, color: color),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, size: 20, color: AppTheme.subtle),
          ],
        ),
      ),
    );
  }
}
