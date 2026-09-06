import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../services/feed_video_manager.dart';
import '../theme/app_theme.dart';

class PostVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final String? videoId;
  final VoidCallback? onTapVideo;

  const PostVideoPlayer({
    super.key,
    required this.videoUrl,
    this.videoId,
    this.onTapVideo,
  });

  @override
  State<PostVideoPlayer> createState() => _PostVideoPlayerState();
}

class _PostVideoPlayerState extends State<PostVideoPlayer> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _isMuted = true;
  double _visibleFraction = 0.0;

  String get _id => widget.videoId ?? widget.videoUrl;

  @override
  void initState() {
    super.initState();
    _isMuted = FeedVideoManager().isMuted;
    _initializePlayer();
  }

  void _initializePlayer() {
    setState(() {
      _hasError = false;
      _isInitialized = false;
    });

    try {
      final uri = Uri.parse(widget.videoUrl);
      _controller = VideoPlayerController.networkUrl(uri)
        ..initialize().then((_) {
          if (!mounted) return;
          _controller.setLooping(true);
          _controller.setVolume(_isMuted ? 0.0 : 1.0);

          setState(() {
            _isInitialized = true;
          });

          // Register pause callback with manager
          FeedVideoManager().register(_id, _onManagerRequestedPause);

          // Auto-play if prominently visible and no other video is playing
          if (_visibleFraction >= 0.7 && FeedVideoManager().activeVideoId == null) {
            _play();
          }
        }).catchError((error) {
          debugPrint('PostVideoPlayer init error: $error');
          if (mounted) {
            setState(() {
              _hasError = true;
            });
          }
        });

      _controller.addListener(() {
        if (mounted) setState(() {});
      });
    } catch (e) {
      debugPrint('PostVideoPlayer parse error: $e');
      setState(() {
        _hasError = true;
      });
    }
  }

  void _onManagerRequestedPause() {
    if (mounted && _isInitialized && _controller.value.isPlaying) {
      _controller.pause();
      setState(() {});
    }
  }

  void _play() {
    if (!_isInitialized) return;
    _controller.setVolume(_isMuted ? 0.0 : 1.0);
    _controller.play();
    FeedVideoManager().play(_id, _onManagerRequestedPause);
    if (mounted) setState(() {});
  }

  void _pause() {
    if (!_isInitialized) return;
    _controller.pause();
    FeedVideoManager().pause(_id);
    if (mounted) setState(() {});
  }

  void _toggleMute() {
    if (!_isInitialized) return;
    setState(() {
      _isMuted = !_isMuted;
      FeedVideoManager().isMuted = _isMuted;
      _controller.setVolume(_isMuted ? 0.0 : 1.0);
    });
  }

  void _handleVisibilityChanged(VisibilityInfo info) {
    _visibleFraction = info.visibleFraction;
    if (!mounted || !_isInitialized) return;

    // If less than 40% of the video is visible, pause it immediately
    if (info.visibleFraction < 0.4) {
      if (_controller.value.isPlaying) {
        _pause();
      }
    } else if (info.visibleFraction >= 0.7) {
      // If at least 70% visible and no video is currently active, play this one
      if (!_controller.value.isPlaying && FeedVideoManager().activeVideoId == null) {
        _play();
      }
    }
  }

  void _onTapBody() {
    if (widget.onTapVideo != null) {
      _pause();
      widget.onTapVideo!();
    } else {
      if (_controller.value.isPlaying) {
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
      FeedVideoManager().unregister(oldWidget.videoId ?? oldWidget.videoUrl);
      _controller.dispose();
      _initializePlayer();
    }
  }

  @override
  void dispose() {
    FeedVideoManager().unregister(_id);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        height: 220,
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam_off_outlined, size: 40, color: AppColors.outline),
              const SizedBox(height: 8),
              const Text(
                'Unable to play video',
                style: TextStyle(fontSize: 13, color: AppColors.outline),
              ),
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

    if (!_isInitialized) {
      return Container(
        height: 220,
        decoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.primaryContainer,
          ),
        ),
      );
    }

    final double aspectRatio = _controller.value.aspectRatio > 0
        ? _controller.value.aspectRatio
        : (16 / 9);

    final isPlaying = _controller.value.isPlaying;

    return VisibilityDetector(
      key: Key('feed_video_$_id'),
      onVisibilityChanged: _handleVisibilityChanged,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          color: Colors.black,
          constraints: const BoxConstraints(
            maxHeight: 400,
            minHeight: 180,
          ),
          child: AspectRatio(
            aspectRatio: aspectRatio,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Video Surface
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _onTapBody,
                  child: VideoPlayer(_controller),
                ),

                // Center Play Icon when paused
                if (!isPlaying)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _onTapBody,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(12),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 44,
                      ),
                    ),
                  ),

                // "Watch in Reels" badge (Bottom Left)
                Positioned(
                  bottom: 12,
                  left: 12,
                  child: GestureDetector(
                    onTap: _onTapBody,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white24, width: 0.5),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.play_circle_outline, color: Colors.white, size: 14),
                          SizedBox(width: 5),
                          Text(
                            'Watch in Reels',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Mute/Unmute button (Top Right)
                Positioned(
                  top: 10,
                  right: 10,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _toggleMute,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                        color: Colors.white,
                        size: 18,
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
                    _controller,
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
          ),
        ),
      ),
    );
  }
}
