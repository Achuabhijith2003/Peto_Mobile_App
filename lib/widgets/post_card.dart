import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../models/post_model.dart';
import '../theme/app_theme.dart';
import 'comments_bottom_sheet.dart';
import 'post_video_player.dart';
import '../models/reel_model.dart';
import '../screens/reels/reels_screen.dart';

class PostCard extends StatelessWidget {
  final Post post;
  final VoidCallback onLike;
  final VoidCallback onBookmark;
  final VoidCallback? onComment;
  final VoidCallback? onTap;

  const PostCard({
    super.key,
    required this.post,
    required this.onLike,
    required this.onBookmark,
    this.onComment,
    this.onTap,
  });

  void _handleCommentTap(BuildContext context) {
    if (onComment != null) {
      onComment!();
    } else {
      CommentsBottomSheet.show(
        context,
        postId: post.id,
        postAuthorUsername: post.author.username,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat.yMMMd().format(post.createdAt);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.surfaceContainerHigh, width: 1),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Author Avatar, Name, Community tag, Time
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.primaryFixed,
                    backgroundImage: post.author.avatarUrl != null
                        ? CachedNetworkImageProvider(post.author.avatarUrl!)
                        : null,
                    child: post.author.avatarUrl == null
                        ? Text(
                            post.author.username.isNotEmpty
                                ? post.author.username[0].toUpperCase()
                                : 'P',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.author.username,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppColors.onSurface,
                          ),
                        ),
                        if (post.communityName != null) ...[
                          Text(
                            'in ${post.communityName}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.secondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Text(
                    formattedDate,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Content text
              if (post.content.isNotEmpty) ...[
                Text(
                  post.content,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.4,
                    color: AppColors.onSurface,
                  ),
                ),
              ],

              // Media attachment (single or multi-media carousel)
              if (post.media.isNotEmpty) ...[
                const SizedBox(height: 12),
                if (post.media.length == 1)
                  if (post.media.first.isVideo)
                    PostVideoPlayer(
                      videoUrl: post.media.first.url,
                      videoId: post.id,
                      onTapVideo: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ReelsScreen(
                              initialReel: Reel(
                                id: post.id,
                                mediaUrl: post.media.first.url,
                                caption: post.content,
                                author: post.author,
                                likesCount: post.likesCount,
                                commentsCount: post.commentsCount,
                                isLiked: post.isLiked,
                                isBookmarked: post.isBookmarked,
                              ),
                              showBackButton: true,
                            ),
                          ),
                        );
                      },
                    )
                  else
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: post.media.first.url,
                        width: double.infinity,
                        height: 220,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          height: 220,
                          color: AppColors.surfaceContainerLow,
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          height: 160,
                          color: AppColors.surfaceContainerLow,
                          child: const Icon(Icons.pets, size: 40, color: AppColors.outline),
                        ),
                      ),
                    )
                else
                  _PostMediaCarousel(media: post.media, post: post),
              ],

              const SizedBox(height: 12),
              const Divider(height: 1, color: AppColors.surfaceContainerHigh),
              const SizedBox(height: 4),

              // Action Row: Like, Comment, Bookmark
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Like Button
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: onLike,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: Row(
                        children: [
                          Icon(
                            post.isLiked ? Icons.favorite : Icons.favorite_border,
                            color: post.isLiked ? AppColors.error : AppColors.outline,
                            size: 22,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${post.likesCount}',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: post.isLiked ? AppColors.error : AppColors.outline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Comment Button
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => _handleCommentTap(context),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.mode_comment_outlined,
                            size: 20,
                            color: AppColors.outline,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${post.commentsCount}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: AppColors.outline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Bookmark Button
                  IconButton(
                    onPressed: onBookmark,
                    icon: Icon(
                      post.isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                      color: post.isBookmarked ? AppColors.primary : AppColors.outline,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostMediaCarousel extends StatefulWidget {
  final List<PostMedia> media;
  final Post post;

  const _PostMediaCarousel({required this.media, required this.post});

  @override
  State<_PostMediaCarousel> createState() => _PostMediaCarouselState();
}

class _PostMediaCarouselState extends State<_PostMediaCarousel> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 260,
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: PageView.builder(
                  itemCount: widget.media.length,
                  onPageChanged: (idx) => setState(() => _currentIndex = idx),
                  itemBuilder: (context, index) {
                    final item = widget.media[index];
                    if (item.isVideo) {
                      return PostVideoPlayer(
                        videoUrl: item.url,
                        videoId: '${widget.post.id}_$index',
                        onTapVideo: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ReelsScreen(
                                initialReel: Reel(
                                  id: widget.post.id,
                                  mediaUrl: item.url,
                                  caption: widget.post.content,
                                  author: widget.post.author,
                                  likesCount: widget.post.likesCount,
                                  commentsCount: widget.post.commentsCount,
                                  isLiked: widget.post.isLiked,
                                  isBookmarked: widget.post.isBookmarked,
                                ),
                                showBackButton: true,
                              ),
                            ),
                          );
                        },
                      );
                    }
                    return CachedNetworkImage(
                      imageUrl: item.url,
                      width: double.infinity,
                      height: 260,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: AppColors.surfaceContainerLow,
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: AppColors.surfaceContainerLow,
                        child: const Icon(Icons.pets, size: 40, color: AppColors.outline),
                      ),
                    );
                  },
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_currentIndex + 1}/${widget.media.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            widget.media.length,
            (idx) => AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: _currentIndex == idx ? 16 : 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 2.5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                color: _currentIndex == idx
                    ? AppColors.primary
                    : AppColors.outline.withValues(alpha: 0.3),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

