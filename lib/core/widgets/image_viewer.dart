import 'package:flutter/material.dart';

/// One photo the viewer can show.
class ViewerImage {
  const ViewerImage({required this.id, required this.url, this.caption});

  final String id;

  /// The signed link. Null when storage could not sign it.
  final String? url;

  /// A label shown under the photo, usually who took it and when.
  final String? caption;
}

/// A photo shown in the middle of the screen, over a black backdrop.
///
/// The photo is shown whole, never cropped: a tall photo fills the screen instead of being cut
/// off. [InteractiveViewer] lets the owner pinch to zoom and drag it around to read the details.
class ImageViewer extends StatefulWidget {
  const ImageViewer({
    super.key,
    required this.images,
    this.index = 0,
    this.onImageError,
  });

  /// The photos to show, in order.
  final List<ViewerImage>;

  /// The photo shown first.
  final int index;

  /// Called when a photo fails to load, so the caller can fetch a fresh signed link.
  final VoidCallback? onImageError;

  /// Opens the viewer over the current screen.
  static Future<void> show(
    BuildContext context, {
    required List<ViewerImage> images,
    int index = 0,
    VoidCallback? onImageError,
  }) {
    if (index < 0 || index >= images.length) return Future.value();
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => ImageViewer(
        images: images,
        index: index,
        onImageError: onImageError,
      ),
    );
  }

  @override
  State<ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<ImageViewer> {
  late int _index = widget.index;
  late final PageController _pages = PageController(initialPage: widget.index);

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = widget.images[_index];

    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pages,
            itemCount: widget.images.length,
            onPageChanged: (index) => setState(() => _index = index),
            itemBuilder: (context, index) {
              final current = widget.images[index];
              return InteractiveViewer(
                child: Center(
                  child: current.url == null || current.url!.isEmpty
                      ? const Icon(
                          Icons.broken_image_outlined,
                          size: 40,
                          color: Colors.white,
                        )
                      : Image.network(
                          current.url!,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            widget.onImageError?.call();
                            return const Icon(
                              Icons.broken_image_outlined,
                              size: 40,
                              color: Colors.white,
                            );
                          },
                        ),
                ),
              );
            },
          ),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded, color: Colors.white),
              tooltip: 'Đóng',
            ),
          ),
          if (image.caption != null || widget.images.length > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: 16,
              child: Column(
                children: [
                  if (image.caption != null)
                    Text(
                      image.caption!,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  if (widget.images.length > 1)
                    Text(
                      '${_index + 1} / ${widget.images.length}',
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                      textAlign: TextAlign.center,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
