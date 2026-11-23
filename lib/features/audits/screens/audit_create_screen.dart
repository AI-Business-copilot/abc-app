import 'package:flutter/material.dart';
import 'package:abc_app/core/network/api_error.dart';
import 'package:abc_app/core/theme/app_theme.dart';
import 'package:abc_app/core/widgets/app_widgets.dart';
import 'package:abc_app/features/audits/services/audits_service.dart';

/// F07 — the owner creates a stock audit. Every row counts a lot that is already in the system.
class AuditCreateScreen extends StatefulWidget {
  const AuditCreateScreen({super.key});

  @override
  State<AuditCreateScreen> createState() => _AuditCreateScreenState();
}

class _AuditCreateScreenState extends State<AuditCreateScreen> {
  final _service = AuditsService();

  final _noteController = TextEditingController();
  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      final audit = await _service.createAudit(
        note: _noteController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã tạo đợt kiểm kê ${audit.auditCode}')),
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
        title: const Text('Tạo đợt kiểm kê'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null) MessageBanner(message: _error!, isError: true),
              const Text(
                'Loại kiểm kê',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.primary),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.border),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.history_rounded, size: 18, color: AppTheme.primary),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Kiểm kê lô có sẵn',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Mỗi dòng gắn với một lô có sẵn. Nhân viên đếm và có thể sửa ngày của lô.',
                style: TextStyle(fontSize: 11.5, color: AppTheme.muted),
              ),
              const SizedBox(height: 20),
              const Text(
                'Ghi chú (không bắt buộc)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.primary),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _noteController,
                maxLines: 3,
                style: const TextStyle(fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Ví dụ: kiểm kê kho trước giờ đóng cửa',
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSaving ? null : _create,
                child: _isSaving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Tạo đợt kiểm kê'),
              ),
              const SizedBox(height: 10),
              const Text(
                'Sau khi tạo, chủ cửa hàng thêm dòng kiểm kê (nhân viên + SKU + lô) ở trang chi tiết.',
                style: TextStyle(fontSize: 11.5, color: AppTheme.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
