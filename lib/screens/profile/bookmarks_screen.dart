import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/post_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/post_card.dart';
import '../../widgets/comments_bottom_sheet.dart';
import '../../widgets/auth_prompt_bottom_sheet.dart';

class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({super.key});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<PostProvider>(context, listen: false).fetchBookmarks();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final postProvider = Provider.of<PostProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Posts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => postProvider.fetchBookmarks(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => postProvider.fetchBookmarks(),
        child: postProvider.isLoadingBookmarks
            ? const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : postProvider.bookmarkedPosts.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.65,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryFixed.withValues(alpha: 0.5),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.bookmark_border_rounded,
                                    size: 44,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'No saved posts yet',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Bookmark posts and reels on your feed to access them quickly here.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.onSurfaceVariant,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: postProvider.bookmarkedPosts.length,
                    itemBuilder: (context, index) {
                      final post = postProvider.bookmarkedPosts[index];
                      return PostCard(
                        post: post,
                        onLike: () {
                          if (authProvider.isAuthenticated) {
                            postProvider.toggleLike(post.id);
                          } else {
                            AuthPromptBottomSheet.show(context, actionTitle: 'Like Post');
                          }
                        },
                        onBookmark: () {
                          postProvider.toggleBookmark(post.id, isCurrentlyBookmarked: post.isBookmarked);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Post removed from saved'),
                              action: SnackBarAction(
                                label: 'Undo',
                                onPressed: () => postProvider.toggleBookmark(post.id),
                              ),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        onComment: () {
                          CommentsBottomSheet.show(
                            context,
                            postId: post.id,
                            postAuthorUsername: post.author.username,
                          );
                        },
                      );
                    },
                  ),
      ),
    );
  }
}
