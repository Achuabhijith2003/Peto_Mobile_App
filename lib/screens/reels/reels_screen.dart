import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/auth_provider.dart';
import '../../providers/reel_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/auth_prompt_bottom_sheet.dart';
import '../../widgets/comments_bottom_sheet.dart';

class ReelsScreen extends StatefulWidget {
  const ReelsScreen({super.key});

  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ReelProvider>(context, listen: false).fetchReels();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final reelProvider = Provider.of<ReelProvider>(context);

    if (reelProvider.isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: AppColors.primaryContainer)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        scrollDirection: Axis.vertical,
        itemCount: reelProvider.reels.length,
        itemBuilder: (context, index) {
          final reel = reelProvider.reels[index];
          return Stack(
            fit: StackFit.expand,
            children: [
              // Media display
              CachedNetworkImage(
                imageUrl: reel.mediaUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(color: AppColors.primaryContainer),
                ),
                errorWidget: (context, url, error) => const Center(
                  child: Icon(Icons.pets, size: 60, color: Colors.white54),
                ),
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
                                  reel.author.username[0].toUpperCase(),
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
                    if (reel.caption != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        reel.caption!,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
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
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
