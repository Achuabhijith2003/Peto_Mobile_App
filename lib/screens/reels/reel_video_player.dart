import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/app_theme.dart';

class ReelVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final String? thumbnailUrl;
  final bool isActive;

  const ReelVideoPlayer({
    super.key,
    required this.videoUrl,
    this.thumbnailUrl,
    required this.isActive,
  });

  @override
  State<ReelVideoPlayer> createState() => _ReelVideoPlayerState();
}

class _ReelVideoPlayerState extends State<ReelVideoPlayer> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _isPlaying = false;
  bool _showPlayPauseIndicator = false;
  bool _isDisposed = false;
  int _retryCount = 0;

  // Aspect ratio display mode: default to true (show uncropped original size for landscape videos)
  bool _fitOriginal = true;

  @override
  void initState() {
    super.initState();
    if (widget.isActive) {
      _initController();
    }
  }

  void _disposeController() {
    _controller?.dispose();
    _controller = null;
    _isInitialized = false;
    _isPlaying = false;
  }

  void _initController() {
    if (_isDisposed) return;

    final cleanUrl = widget.videoUrl.trim();
    if (cleanUrl.isEmpty) {
      setState(() {
        _hasError = true;
        _isInitialized = false;
      });
      return;
    }

    setState(() {
      _hasError = false;
      _isInitialized = false;
    });

    try {
      final uri = Uri.tryParse(cleanUrl) ?? Uri.parse(Uri.encodeFull(cleanUrl));

      _controller?.dispose();
      final controller = VideoPlayerController.networkUrl(
        uri,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      _controller = controller;

      controller.initialize().then((_) {
        if (_isDisposed || !mounted || _controller != controller) return;
        controller.setLooping(true);

        setState(() {
          _isInitialized = true;
          _hasError = false;
          _retryCount = 0;
        });

        if (widget.isActive) {
          controller.play();
          _isPlaying = true;
        } else {
          controller.pause();
          _isPlaying = false;
        }
      }).catchError((e) {
        debugPrint('Reel video initialization error: $e');
        if (_isDisposed || !mounted || _controller != controller) return;

        // Automatic retry up to 2 times for the active reel
        if (widget.isActive && _retryCount < 2) {
          _retryCount++;
          Future.delayed(const Duration(milliseconds: 1000), () {
            if (!_isDisposed && mounted && widget.isActive) {
              _initController();
            }
          });
          return;
        }

        setState(() {
          _hasError = true;
        });
      });

      controller.addListener(() {
        if (_isDisposed || !mounted || _controller != controller) return;
        final isPlaying = controller.value.isPlaying;
        if (_isPlaying != isPlaying) {
          setState(() {
            _isPlaying = isPlaying;
          });
        }
      });
    } catch (e) {
      debugPrint('Reel video URL parse error: $e');
      if (!_isDisposed && mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  @override
  void didUpdateWidget(covariant ReelVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.videoUrl != widget.videoUrl) {
      if (widget.isActive) {
        _initController();
      } else {
        _disposeController();
      }
      return;
    }

    if (oldWidget.isActive != widget.isActive) {
      if (widget.isActive) {
        // When becoming active, initialize controller to acquire hardware decoder
        _initController();
      } else {
        // When leaving active view, immediately dispose controller to release decoder
        _disposeController();
        if (mounted) setState(() {});
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _disposeController();
    super.dispose();
  }

  void _handleTap() {
    if (!_isInitialized || _controller == null) return;
    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
      } else {
        _controller!.play();
      }
      _showPlayPauseIndicator = true;
    });

    Future.delayed(const Duration(milliseconds: 900), () {
      if (!_isDisposed && mounted) {
        setState(() {
          _showPlayPauseIndicator = false;
        });
      }
    });
  }

  Widget _buildThumbnailOrPlaceholder({bool showLoader = false}) {
    final hasThumb = widget.thumbnailUrl != null && widget.thumbnailUrl!.trim().isNotEmpty;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (hasThumb)
          CachedNetworkImage(
            imageUrl: widget.thumbnailUrl!.trim(),
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(color: Colors.black),
            errorWidget: (context, url, error) => Container(color: Colors.black),
          )
        else
          Container(color: Colors.black),
        if (showLoader)
          const Center(
            child: CircularProgressIndicator(
              color: AppColors.primaryContainer,
              strokeWidth: 2.5,
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam_off_outlined, size: 52, color: Colors.white54),
              const SizedBox(height: 14),
              const Text(
                'Video unavailable',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'Could not load video. Check your network or retry.',
                style: TextStyle(color: Colors.white60, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _initController,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isInitialized || _controller == null) {
      return _buildThumbnailOrPlaceholder(showLoader: widget.isActive);
    }

    final size = MediaQuery.of(context).size;
    final deviceRatio = size.width / size.height;
    final videoRatio = _controller!.value.aspectRatio > 0 ? _controller!.value.aspectRatio : 9 / 16;
    final isLandscape = videoRatio >= 1.0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Video Display: Uncropped in original size for landscape when _fitOriginal is true
          Center(
            child: (isLandscape && _fitOriginal)
                ? AspectRatio(
                    aspectRatio: videoRatio,
                    child: VideoPlayer(_controller!),
                  )
                : Transform.scale(
                    scale: videoRatio > deviceRatio
                        ? videoRatio / deviceRatio
                        : deviceRatio / videoRatio,
                    child: AspectRatio(
                      aspectRatio: videoRatio,
                      child: VideoPlayer(_controller!),
                    ),
                  ),
          ),

          // Aspect Ratio Mode Toggle for Landscape Videos (Top-Left)
          if (isLandscape)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _fitOriginal = !_fitOriginal;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _fitOriginal ? Icons.crop_original_rounded : Icons.crop_free_rounded,
                        color: Colors.white,
                        size: 15,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _fitOriginal ? 'Original Size' : 'Filled',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Center Animated Play/Pause feedback icon
          if (_showPlayPauseIndicator || !_isPlaying)
            Center(
              child: AnimatedOpacity(
                opacity: _showPlayPauseIndicator || !_isPlaying ? 0.85 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Icon(
                    _isPlaying ? Icons.play_arrow_rounded : Icons.pause_rounded,
                    color: Colors.white,
                    size: 54,
                  ),
                ),
              ),
            ),

          // Bottom Progress Line
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: VideoProgressIndicator(
              _controller!,
              allowScrubbing: true,
              colors: const VideoProgressColors(
                playedColor: AppColors.primaryContainer,
                bufferedColor: Colors.white24,
                backgroundColor: Colors.transparent,
              ),
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}
