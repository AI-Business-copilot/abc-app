import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/image_viewer.dart';
import '../models/audit_models.dart';
import '../services/audits_service.dart';

/// The evidence photos of one counter's audit count.
///
/// The photos belong to the count, so the owner sees each counter's own set side by side. The
/// signed links expire after a few minutes, so they are fetched separately from the item payload
/// and refreshed when one fails to load.
class AuditCountImageStrip extends StatefulWidget {
  const AuditCountImageStrip({
    super.key,
    required this.auditId,
    required this.itemId,
    required this.countId,
    required this.images,
    required this.service,
  });

  final String auditId;
  final String itemId;
  final String countId;

  /// The photos from the item payload. Used until the signed links arrive.
  final List<AuditItemCountImage> images;

  final AuditsService service;

  @override
  State<AuditCountImageStrip> createState() => _AuditCountImageStripState();
}

class _AuditCountImageStripState extends State<AuditCountImageStrip> {
  late List<AuditItemCountImage> _images;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _images = widget.images;
    _load();
  }

  Future<void> _load() async {
    try {
      final images = await widget.service.getAuditCountImages(
        widget.auditId,
        widget.itemId,
        widget.countId,
      );
      if (!mounted) return;
      setState(() {
        _images = images;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      // Keep the metadata from the item payload so the photos still show as placeholders.
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_images.isEmpty && !_loading) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ảnh hàng hỏng',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.muted),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 100,
          child: _loading && _images.isEmpty
              ? const Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _images.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final image = _images[index];
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
                    return GestureDetector(
                      onTap: () => ImageViewer.show(
                        context,
                        images: _images
                            .map((item) => ViewerImage(
                                  id: item.id,
                                  url: item.url,
                                  caption: item.uploadedByName,
                                ))
                            .toList(),
                        index: index,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          url,
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            width: 100,
                            height: 100,
                            color: AppTheme.background,
                            alignment: Alignment.center,
                            child: const Text(
                              'Không tải được ảnh',
                              style: TextStyle(fontSize: 10, color: AppTheme.muted),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          loadingBuilder: (context, child, progress) =>
                              progress == null
                                  ? child
                                  : Container(
                                      width: 100,
                                      height: 100,
                                      color: AppTheme.background,
                                      alignment: Alignment.center,
                                      child: const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2),
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
