import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/auth_provider.dart';
import '../../providers/reel_provider.dart';
import '../../services/feed_video_manager.dart';
import '../../theme/app_theme.dart';
import '../../widgets/auth_prompt_bottom_sheet.dart';
import '../../widgets/comments_bottom_sheet.dart';
import '../../widgets/report_bottom_sheet.dart';
import '../../models/reel_model.dart';
import 'reel_video_player.dart';

class ReelsScreen extends StatefulWidget {
  final Reel? initialReel;
  final bool showBackButton;
  final bool isActive;

  const ReelsScreen({
    super.key,
    this.initialReel,
    this.showBackButton = false,
    this.isActive = true,
  });

  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> with WidgetsBindingObserver {
  late PageController _pageController;
  int _currentPage = 0;
  bool _isAppInForeground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController();
    // Pause any feed videos playing in the background
    FeedVideoManager().pauseAll();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ReelProvider>(context, listen: false).fetchReels();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final isForeground = state == AppLifecycleState.resumed;
    if (_isAppInForeground != isForeground && mounted) {
      setState(() {
        _isAppInForeground = isForeground;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final reelProvider = Provider.of<ReelProvider>(context);

    // Merge initialReel if provided
    final List<Reel> displayReels = [];
    if (widget.initialReel != null) {
      displayReels.add(widget.initialReel!);
    }
    for (final r in reelProvider.reels) {
      if (widget.initialReel == null || r.id != widget.initialReel!.id) {
        displayReels.add(r);
      }
    }

    if (reelProvider.isLoading && displayReels.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: AppColors.primaryContainer)),
      );
    }

    if (displayReels.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.movie_creation_outlined, size: 60, color: Colors.white54),
                  const SizedBox(height: 16),
                  const Text(
                    'No reels available yet',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Check back later for new pet videos!',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () => reelProvider.fetchReels(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryContainer,
                      foregroundColor: AppColors.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
            if (widget.showBackButton)
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 12,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: displayReels.length,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemBuilder: (context, index) {
              final reel = displayReels[index];
              final isActive = widget.isActive && _isAppInForeground && _currentPage == index;

              return Stack(
                fit: StackFit.expand,
                children: [
                  // Media display: video or fallback image
                  if (reel.mediaUrl.isNotEmpty &&
                      (Reel.isVideoUrl(reel.mediaUrl) ||
                          reel.mediaUrl.toLowerCase().contains('/posts-videos/') ||
                          reel.mediaUrl.toLowerCase().contains('.mp4') ||
                          reel.mediaUrl.toLowerCase().contains('video')))
                    ReelVideoPlayer(
                      key: ValueKey('${reel.id}_${reel.mediaUrl}'),
                      videoUrl: reel.mediaUrl,
                      thumbnailUrl: reel.thumbnailUrl,
                      isActive: isActive,
                    )
                  else if (reel.mediaUrl.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: reel.mediaUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const Center(
                        child: CircularProgressIndicator(color: AppColors.primaryContainer),
                      ),
                      errorWidget: (context, url, error) => const Center(
                        child: Icon(Icons.pets, size: 60, color: Colors.white54),
                      ),
                    )
                  else
                    const Center(
                      child: Icon(Icons.videocam_off_outlined, size: 60, color: Colors.white54),
                    ),

                  // Gradient Overlay
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.black54, Colors.transparent, Colors.black87],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),

                  // Author info & caption (Bottom Left)
                  Positioned(
                    left: 16,
                    bottom: 32,
                    right: 80,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: AppColors.primaryFixed,
                              backgroundImage: reel.author.avatarUrl != null
                                  ? CachedNetworkImageProvider(reel.author.avatarUrl!)
                                  : null,
                              child: reel.author.avatarUrl == null
                                  ? Text(
                                      reel.author.username.isNotEmpty
                                          ? reel.author.username[0].toUpperCase()
                                          : 'P',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '@${reel.author.username}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        if (reel.caption != null && reel.caption!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            reel.caption!,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Action buttons (Bottom Right)
                  Positioned(
                    right: 16,
                    bottom: 40,
                    child: Column(
                      children: [
                        IconButton(
                          icon: Icon(
                            reel.isLiked ? Icons.favorite : Icons.favorite_border,
                            color: reel.isLiked ? AppColors.error : Colors.white,
                            size: 32,
                          ),
                          onPressed: () {
                            if (authProvider.isAuthenticated) {
                              reelProvider.toggleLike(reel.id);
                            } else {
                              AuthPromptBottomSheet.show(context, actionTitle: 'Like Reel');
                            }
                          },
                        ),
                        Text(
                          '${reel.likesCount}',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                        const SizedBox(height: 16),
                        IconButton(
                          icon: const Icon(Icons.mode_comment_outlined, color: Colors.white, size: 30),
                          onPressed: () {
                            CommentsBottomSheet.show(
                              context,
                              postId: reel.id,
                              postAuthorUsername: reel.author.username,
                            );
                          },
                        ),
                        Text(
                          '${reel.commentsCount}',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                        const SizedBox(height: 16),
                        IconButton(
                          icon: Icon(
                            reel.isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                            color: reel.isBookmarked ? AppColors.primaryContainer : Colors.white,
                            size: 30,
                          ),
                          onPressed: () {
                            if (authProvider.isAuthenticated) {
                              reelProvider.toggleBookmark(reel.id);
                            } else {
                              AuthPromptBottomSheet.show(context, actionTitle: 'Save Reel');
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        IconButton(
                          icon: const Icon(Icons.flag_outlined, color: Colors.white, size: 28),
                          onPressed: () {
                            ReportBottomSheet.show(
                              context,
                              targetType: 'reel',
                              targetId: reel.id,
                              targetTitle: reel.caption ?? 'Reel by ${reel.author.username}',
                            );
                          },
                        ),
                        const Text(
                          'Report',
                          style: TextStyle(color: Colors.white, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),

          // Optional Back Button (Top Left)
          if (widget.showBackButton)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 12,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
