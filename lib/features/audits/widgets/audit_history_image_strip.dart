import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/image_viewer.dart';
import '../models/audit_models.dart';

/// The evidence photos of one moment, grouped by the employee who took them.
class _ImageGroup {
  _ImageGroup(this.key, this.name);

  final String key;
  final String name;
  final List<AuditItemCountImage> images = [];
}

/// The evidence photos filed under one history entry.
///
/// The photos of a history entry already carry their signed links, because they are signed
/// together with the history itself. They are shown read-only here: a filed photo belongs to a
/// moment that has passed, so there is nothing to refresh.
///
/// The photos are kept out of the history itself: the history is a record of numbers, and a row
/// of thumbnails would bury them. The button opens them in a dialog instead.
class AuditHistoryImageStrip extends StatelessWidget {
  const AuditHistoryImageStrip({
    super.key,
    required this.images,
    this.counts = const [],
  });

  final List<AuditItemCountImage> images;

  /// The counters of that moment, used to name the groups of photos.
  final List<AuditItemHistoryCount> counts;

  /// The counters are kept apart: each employee's photos sit under their own name, the same way
  /// their numbers sit under their own row. A photo is matched to a counter by the uploader, and
  /// the name comes from the history so it is the name the owner saw at that moment.
  List<_ImageGroup> _groupImages() {
    final groups = <String, _ImageGroup>{};

    // The counters come first, so the order follows the row.
    for (final count in counts) {
      groups[count.counterUserId] = _ImageGroup(
        count.counterUserId,
        count.counter?.name ?? 'Người kiểm kê',
      );
    }

    for (final image in images) {
      final group = groups[image.uploadedBy];
      if (group != null) {
        group.images.add(image);
        continue;
      }
      final fresh = _ImageGroup(
        image.uploadedBy,
        image.uploadedByName.isEmpty ? 'Người kiểm kê' : image.uploadedByName,
      );
      fresh.images.add(image);
      groups[image.uploadedBy] = fresh;
    }

    return groups.values.where((group) => group.images.isNotEmpty).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) return const SizedBox.shrink();

    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        onPressed: () => _openGallery(context),
        icon: const Icon(Icons.visibility_outlined, size: 16),
        label: Text('Xem ảnh (${images.length})'),
        style: OutlinedButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          textStyle: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Future<void> _openGallery(BuildContext context) {
    final groups = _groupImages();
    // The viewer walks the photos in the order they are shown, so the groups stay in order.
    final flat = groups.expand((group) => group.images).toList();

    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ảnh bằng chứng'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final group in groups) ...[
                  Text(
                    group.name,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: group.images.length,
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 160,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 4 / 3,
                        ),
                    itemBuilder: (context, index) {
                      final image = group.images[index];
                      final url = image.url;
                      if (url == null || url.isEmpty) {
                        return Container(
                          decoration: BoxDecoration(
                            color: AppTheme.background,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: Text(
                              'Không tải được ảnh',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppTheme.muted,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }
                      final position = flat.indexOf(image);
                      return GestureDetector(
                        onTap: () {
                          Navigator.of(context).pop();
                          ImageViewer.show(
                            context,
                            images: flat
                                .map(
                                  (item) => ViewerImage(
                                    id: item.id,
                                    url: item.url,
                                    caption: item.uploadedByName,
                                  ),
                                )
                                .toList(),
                            index: position,
                          );
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            url,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                                  color: AppTheme.background,
                                  child: const Center(
                                    child: Text(
                                      'Không tải được ảnh',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: AppTheme.muted,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }
}
