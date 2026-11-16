import 'package:flutter/material.dart';
import 'package:abc_app/core/theme/app_theme.dart';
import 'package:abc_app/features/auth/services/auth_service.dart';

/// Renders [child] only when the session has [permission]. Otherwise [fallback] is shown.
///
/// Mirrors `abc-frontend/src/components/common/permission-gate.tsx`.
class PermissionGate extends StatelessWidget {
  const PermissionGate({
    super.key,
    required this.permission,
    required this.child,
    this.fallback,
  });

  final String permission;
  final Widget child;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    if (AuthService.hasPermission(permission)) return child;
    return fallback ?? const SizedBox.shrink();
  }
}

/// A screen-level block shown when the user lacks a permission.
class PermissionDeniedView extends StatelessWidget {
  const PermissionDeniedView({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline_rounded, size: 36, color: AppTheme.muted),
            const SizedBox(height: 10),
            Text(
              message ?? 'Bạn không có quyền dùng chức năng này.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: AppTheme.primary),
            ),
          ],
        ),
      ),
    );
  }
}
