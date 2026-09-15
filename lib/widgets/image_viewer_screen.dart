import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/post_model.dart';
import '../models/user_model.dart';
import '../theme/app_theme.dart';

class ImageViewerScreen extends StatefulWidget {
  final List<PostMedia> mediaList;
  final int initialIndex;
  final User? author;
  final String? caption;

  const ImageViewerScreen({
    super.key,
    required this.mediaList,
    this.initialIndex = 0,
    this.author,
    this.caption,
  });

  static void show(
    BuildContext context, {
    required List<PostMedia> mediaList,
    int initialIndex = 0,
    User? author,
    String? caption,
  }) {
    Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        pageBuilder: (context, animation, secondaryAnimation) => ImageViewerScreen(
          mediaList: mediaList,
          initialIndex: initialIndex,
          author: author,
          caption: caption,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  State<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<ImageViewerScreen> {
  late final PageController _pageController;
  late int _currentIndex;
  bool _showOverlay = true;

  final Map<int, TransformationController> _transformControllers = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.mediaList.isEmpty ? 0 : widget.mediaList.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
  }

  TransformationController _getController(int index) {
    if (!_transformControllers.containsKey(index)) {
      _transformControllers[index] = TransformationController();
    }
    return _transformControllers[index]!;
  }

  void _handleDoubleTap(int index) {
    final controller = _getController(index);
    if (controller.value.isIdentity()) {
      // Zoom in by 2.5x centered
      controller.value = Matrix4.diagonal3Values(2.5, 2.5, 1.0);
    } else {
      // Reset back to normal 1.0x
      controller.value = Matrix4.identity();
    }
    setState(() {});
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final controller in _transformControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasMultiple = widget.mediaList.length > 1;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => setState(() => _showOverlay = !_showOverlay),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Interactive PageView for all media images
            PageView.builder(
              controller: _pageController,
              itemCount: widget.mediaList.length,
              onPageChanged: (idx) {
                setState(() => _currentIndex = idx);
              },
              itemBuilder: (context, index) {
                final media = widget.mediaList[index];
                final controller = _getController(index);

                return GestureDetector(
                  onDoubleTap: () => _handleDoubleTap(index),
                  child: Center(
                    child: InteractiveViewer(
                      transformationController: controller,
                      minScale: 0.8,
                      maxScale: 4.5,
                      clipBehavior: Clip.none,
                      child: CachedNetworkImage(
                        imageUrl: media.url,
                        fit: BoxFit.contain,
                        placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        ),
                        errorWidget: (context, url, error) => Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.broken_image_rounded, color: Colors.white54, size: 54),
                            SizedBox(height: 8),
                            Text(
                              'Failed to load image',
                              style: TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            // Top App Bar Overlay
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              top: _showOverlay ? 0 : -100,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.85),
                      Colors.black.withValues(alpha: 0.0),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 8,
                  bottom: 24,
                  left: 16,
                  right: 16,
                ),
                child: Row(
                  children: [
                    // Close Button
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 26),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 8),

                    // Author info
                    if (widget.author != null) ...[
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.primaryContainer,
                        backgroundImage: widget.author!.avatarUrl != null && widget.author!.avatarUrl!.isNotEmpty
                            ? CachedNetworkImageProvider(widget.author!.avatarUrl!)
                            : null,
                        child: widget.author!.avatarUrl == null || widget.author!.avatarUrl!.isEmpty
                            ? Text(
                                widget.author!.username.isNotEmpty ? widget.author!.username[0].toUpperCase() : 'P',
                                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                              )
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.author!.username,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ] else
                      const Spacer(),

                    // Page Counter Pill
                    if (hasMultiple)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          '${_currentIndex + 1} / ${widget.mediaList.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Bottom Caption & Indicators Overlay
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              bottom: _showOverlay ? 0 : -140,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.0),
                      Colors.black.withValues(alpha: 0.85),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).padding.bottom + 16,
                  top: 24,
                  left: 20,
                  right: 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Dot indicator for multiple images
                    if (hasMultiple)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(
                              widget.mediaList.length,
                              (idx) => AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: _currentIndex == idx ? 16 : 6,
                                height: 6,
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(3),
                                  color: _currentIndex == idx ? Colors.white : Colors.white38,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                    // Caption
                    if (widget.caption != null && widget.caption!.trim().isNotEmpty)
                      Text(
                        widget.caption!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          height: 1.35,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
