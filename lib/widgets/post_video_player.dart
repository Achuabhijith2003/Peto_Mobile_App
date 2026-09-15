import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../services/feed_video_manager.dart';
import '../theme/app_theme.dart';

class PostVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final String? videoId;
  final VoidCallback? onTapVideo;
  final double? height;

  const PostVideoPlayer({
    super.key,
    required this.videoUrl,
    this.videoId,
    this.onTapVideo,
    this.height,
  });

  @override
  State<PostVideoPlayer> createState() => _PostVideoPlayerState();
}

class _PostVideoPlayerState extends State<PostVideoPlayer> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _isMuted = true;
  double _visibleFraction = 0.0;
  bool _isDisposed = false;

  String get _id => widget.videoId ?? widget.videoUrl;

  @override
  void initState() {
    super.initState();
    _isMuted = FeedVideoManager().isMuted;
    // We defer heavy video initialization until the card becomes visible
  }

  void _disposeController() {
    FeedVideoManager().unregister(_id);
    _controller?.dispose();
    _controller = null;
    _isInitialized = false;
  }

  void _initializePlayer() {
    if (_isDisposed) return;

    final cleanUrl = widget.videoUrl.trim();
    if (cleanUrl.isEmpty) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _isInitialized = false;
        });
      }
      return;
    }

    _disposeController();

    if (mounted) {
      setState(() {
        _hasError = false;
        _isInitialized = false;
      });
    }

    try {
      final uri = Uri.tryParse(cleanUrl) ?? Uri.parse(Uri.encodeFull(cleanUrl));
      final controller = VideoPlayerController.networkUrl(uri);
      _controller = controller;

      controller.initialize().then((_) {
        if (_isDisposed || !mounted || _controller != controller) {
          controller.dispose();
          return;
        }

        controller.setLooping(true);
        controller.setVolume(_isMuted ? 0.0 : 1.0);

        setState(() {
          _isInitialized = true;
          _hasError = false;
        });

        // Register pause callback with manager
        FeedVideoManager().register(_id, _onManagerRequestedPause);

        // Auto-play if prominently visible and no other video is playing
        if (_visibleFraction >= 0.7 && FeedVideoManager().activeVideoId == null) {
          _play();
        }
      }).catchError((error) {
        debugPrint('PostVideoPlayer init error: $error');
        if (_isDisposed || !mounted || _controller != controller) return;
        setState(() {
          _hasError = true;
          _isInitialized = false;
        });
      });

      controller.addListener(() {
        if (_isDisposed || !mounted || _controller != controller) return;
        setState(() {});
      });
    } catch (e) {
      debugPrint('PostVideoPlayer parse error: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _isInitialized = false;
        });
      }
    }
  }

  void _onManagerRequestedPause() {
    if (mounted && _isInitialized && _controller != null && _controller!.value.isPlaying) {
      _controller!.pause();
      setState(() {});
    }
  }

  void _play() {
    if (!_isInitialized || _controller == null) return;
    _controller!.setVolume(_isMuted ? 0.0 : 1.0);
    _controller!.play();
    FeedVideoManager().play(_id, _onManagerRequestedPause);
    if (mounted) setState(() {});
  }

  void _pause() {
    if (!_isInitialized || _controller == null) return;
    _controller!.pause();
    FeedVideoManager().pause(_id);
    if (mounted) setState(() {});
  }

  void _toggleMute() {
    if (!_isInitialized || _controller == null) return;
    setState(() {
      _isMuted = !_isMuted;
      FeedVideoManager().isMuted = _isMuted;
      _controller!.setVolume(_isMuted ? 0.0 : 1.0);
    });
  }

  void _handleVisibilityChanged(VisibilityInfo info) {
    _visibleFraction = info.visibleFraction;
    if (!mounted || _isDisposed) return;

    // If completely offscreen, dispose decoder to free resources for other videos
    if (info.visibleFraction == 0.0) {
      if (_controller != null) {
        _disposeController();
        if (mounted) setState(() {});
      }
      return;
    }

    // If enters screen and not initialized and no persistent error, initialize player
    if (info.visibleFraction > 0.1 && !_isInitialized && _controller == null && !_hasError) {
      _initializePlayer();
      return;
    }

    if (!_isInitialized || _controller == null) return;

    // If less than 40% of the video is visible, pause it
    if (info.visibleFraction < 0.4) {
      if (_controller!.value.isPlaying) {
        _pause();
      }
    } else if (info.visibleFraction >= 0.7) {
      // If at least 70% visible and no video is currently active, play this one
      if (!_controller!.value.isPlaying && FeedVideoManager().activeVideoId == null) {
        _play();
      }
    }
  }

  void _onTapBody() {
    if (widget.onTapVideo != null) {
      _pause();
      widget.onTapVideo!();
    } else {
      if (_controller != null && _controller!.value.isPlaying) {
        _pause();
      } else {
        _play();
      }
    }
  }

  @override
  void didUpdateWidget(covariant PostVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _disposeController();
      if (_visibleFraction > 0.1) {
        _initializePlayer();
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _disposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key('feed_video_$_id'),
      onVisibilityChanged: _handleVisibilityChanged,
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    // If fixed height is provided (e.g. inside carousel)
    if (widget.height != null) {
      if (_hasError) {
        return Container(
          width: double.infinity,
          height: widget.height,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.videocam_off_outlined, size: 40, color: AppColors.outline),
                const SizedBox(height: 8),
                const Text('Unable to play video', style: TextStyle(fontSize: 13, color: AppColors.outline)),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _initializePlayer,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Retry'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                ),
              ],
            ),
          ),
        );
      }

      if (!_isInitialized || _controller == null) {
        return Container(
          width: double.infinity,
          height: widget.height,
          decoration: BoxDecoration(
            color: Colors.black12,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Center(
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryContainer),
          ),
        );
      }

      final isPlaying = _controller!.value.isPlaying;

      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          color: Colors.black,
          width: double.infinity,
          height: widget.height,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _onTapBody,
                  child: FittedBox(
                    fit: BoxFit.cover,
                    clipBehavior: Clip.hardEdge,
                    child: SizedBox(
                      width: _controller!.value.size.width > 0 ? _controller!.value.size.width : 16,
                      height: _controller!.value.size.height > 0 ? _controller!.value.size.height : 9,
                      child: VideoPlayer(_controller!),
                    ),
                  ),
                ),
              ),
              ..._buildOverlayControls(isPlaying),
            ],
          ),
        ),
      );
    }

    // Dynamic dimension adaptation according to the video's actual dimensions
    final double rawAspectRatio = (_controller != null &&
            _controller!.value.isInitialized &&
            _controller!.value.aspectRatio > 0)
        ? _controller!.value.aspectRatio
        : (16 / 9);

    // Clamped between 0.8 (4:5 vertical) and 1.91 (16:9 landscape)
    final double clampedAspectRatio = rawAspectRatio.clamp(0.8, 1.91);

    if (_hasError) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AspectRatio(
          aspectRatio: clampedAspectRatio,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.videocam_off_outlined, size: 40, color: AppColors.outline),
                  const SizedBox(height: 8),
                  const Text('Unable to play video', style: TextStyle(fontSize: 13, color: AppColors.outline)),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _initializePlayer,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Retry'),
                    style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (!_isInitialized || _controller == null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AspectRatio(
          aspectRatio: clampedAspectRatio,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryContainer),
            ),
          ),
        ),
      );
    }

    final isPlaying = _controller!.value.isPlaying;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxHeight: 480,
          minHeight: 180,
        ),
        child: AspectRatio(
          aspectRatio: clampedAspectRatio,
          child: Container(
            color: Colors.black,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _onTapBody,
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: rawAspectRatio,
                        child: VideoPlayer(_controller!),
                      ),
                    ),
                  ),
                ),
                ..._buildOverlayControls(isPlaying),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildOverlayControls(bool isPlaying) {
    return [
      // Center Play Icon when paused
      if (!isPlaying)
        GestureDetector(
          onTap: _onTapBody,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.play_arrow_rounded,
              color: Colors.white,
              size: 36,
            ),
          ),
        ),

      // Bottom Control Overlay (Mute button)
      Positioned(
        bottom: 8,
        right: 8,
        child: GestureDetector(
          onTap: _toggleMute,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              _isMuted ? Icons.volume_off : Icons.volume_up,
              color: Colors.white,
              size: 16,
            ),
          ),
        ),
      ),

      // Progress indicator at the very bottom
      Positioned(
        bottom: 0,
        left: 0,
        right: 0,
        child: VideoProgressIndicator(
          _controller!,
          allowScrubbing: false,
          colors: const VideoProgressColors(
            playedColor: AppColors.primary,
            bufferedColor: Colors.white24,
            backgroundColor: Colors.transparent,
          ),
        ),
      ),
    ];
  }
}
