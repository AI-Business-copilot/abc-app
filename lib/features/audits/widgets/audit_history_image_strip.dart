import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/audit_models.dart';

/// The evidence photos filed under one history entry.
///
/// The photos of a history entry already carry their signed links, because they are signed
/// together with the history itself. They are shown read-only here: a filed photo belongs to a
/// moment that has passed, so there is nothing to refresh.
class AuditHistoryImageStrip extends StatelessWidget {
  const AuditHistoryImageStrip({super.key, required this.images});

  final List<AuditItemCountImage> images;

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ảnh hàng hỏng lúc đó',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.muted),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: images.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final image = images[index];
              final url = image.url;
              if (url == null || url.isEmpty) {
                return Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text(
                      'Không tải được ảnh',
                      style: TextStyle(fontSize: 10, color: AppTheme.muted),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              return ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  url,
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 100,
                    height: 100,
                    color: AppTheme.background,
                    child: const Center(
                      child: Text(
                        'Không tải được ảnh',
                        style: TextStyle(fontSize: 10, color: AppTheme.muted),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
