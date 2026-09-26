import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/post_provider.dart';
import '../../providers/notification_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/post_card.dart';
import '../../widgets/sponsored_post_card.dart';
import '../../services/api_service.dart';
import '../../widgets/comments_bottom_sheet.dart';
import '../../widgets/auth_prompt_bottom_sheet.dart';
import '../posts/create_post_screen.dart';
import '../notifications/notification_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _feedAds = [];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadFeedAds();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<PostProvider>(context, listen: false).fetchPosts();
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.isAuthenticated) {
        Provider.of<NotificationProvider>(context, listen: false).fetchUnreadCount();
      }
    });
  }

  Future<void> _loadFeedAds() async {
    final ads = await ApiService().fetchFeedAds(placement: 'FEED');
    if (mounted) {
      setState(() {
        _feedAds = ads;
      });
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      final postProvider = Provider.of<PostProvider>(context, listen: false);
      if (!postProvider.isLoading &&
          !postProvider.isLoadingMore &&
          postProvider.hasMore) {
        postProvider.fetchMorePosts();
      }
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final postProvider = Provider.of<PostProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/images/peto_logo.png',
              width: 28,
              height: 28,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Icon(Icons.pets, color: AppColors.primaryContainer, size: 26),
            ),
            const SizedBox(width: 8),
            const Text(
              'Peto',
              style: TextStyle(
                fontFamily: 'Quicksand',
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        actions: [
          Consumer<NotificationProvider>(
            builder: (context, notifProvider, _) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_none_outlined),
                    onPressed: () {
                      if (!authProvider.isAuthenticated) {
                        AuthPromptBottomSheet.show(
                          context,
                          actionTitle: 'Notifications',
                        );
                        return;
                      }
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NotificationScreen(),
                        ),
                      );
                    },
                  ),
                  if (notifProvider.unreadCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: IgnorePointer(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: const BoxDecoration(
                            color: AppColors.error,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                          child: Text(
                            '${notifProvider.unreadCount > 99 ? '99+' : notifProvider.unreadCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final p1 = Provider.of<PostProvider>(context, listen: false).fetchPosts(refresh: true);
          if (authProvider.isAuthenticated) {
            Provider.of<NotificationProvider>(context, listen: false).fetchUnreadCount();
          }
          await p1;
        },
        color: AppColors.primary,
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Create Post Quick Card
              Card(
                child: InkWell(
                  onTap: () {
                    if (authProvider.isAuthenticated) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CreatePostScreen(),
                        ),
                      );
                    } else {
                      AuthPromptBottomSheet.show(
                        context,
                        actionTitle: 'Create Post',
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: AppColors.primaryFixed,
                          child: const Icon(
                            Icons.person,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            "Share a moment of your pet...",
                            style: TextStyle(
                              color: AppColors.onSurfaceVariant,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.image_outlined,
                          color: AppColors.primaryContainer,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Feed list
              if (postProvider.isLoading && postProvider.posts.isEmpty) ...[
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(),
                  ),
                ),
              ] else if (postProvider.posts.isEmpty) ...[
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Text(
                      'No posts found for this category.',
                      style: TextStyle(color: AppColors.onSurfaceVariant),
                    ),
                  ),
                ),
              ] else ...[
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: postProvider.posts.length,
                  itemBuilder: (context, index) {
                    final post = postProvider.posts[index];
                    final shouldShowAd = index > 0 && index % 4 == 3 && _feedAds.isNotEmpty;
                    final adToShow = shouldShowAd
                        ? _feedAds[(index ~/ 4) % _feedAds.length]
                        : null;

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PostCard(
                          post: post,
                          onLike: () {
                            if (authProvider.isAuthenticated) {
                              postProvider.toggleLike(post.id);
                            } else {
                              AuthPromptBottomSheet.show(
                                context,
                                actionTitle: 'Like Post',
                              );
                            }
                          },
                          onBookmark: () {
                            if (authProvider.isAuthenticated) {
                              postProvider.toggleBookmark(post.id);
                            } else {
                              AuthPromptBottomSheet.show(
                                context,
                                actionTitle: 'Save Post',
                              );
                            }
                          },
                          onComment: () {
                            CommentsBottomSheet.show(
                              context,
                              postId: post.id,
                              postAuthorUsername: post.author.username,
                            );
                          },
                        ),
                        if (adToShow != null)
                          SponsoredPostCard(ad: adToShow),
                      ],
                    );
                  },
                ),

                // Bottom loading indicator when fetching next 7 posts
                if (postProvider.isLoadingMore)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary,
                            ),
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Loading more posts...',
                            style: TextStyle(
                              color: AppColors.onSurfaceVariant,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Instagram-style "You're all caught up" card
                if (!postProvider.hasMore && postProvider.posts.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 20),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.outlineVariant.withValues(alpha: 0.5),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_circle_outline,
                            color: Colors.green,
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          "You're all caught up",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppColors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "You've seen all the recent posts from everyone in the Peto community.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primaryContainer,
        foregroundColor: AppColors.onPrimaryContainer,
        child: const Icon(Icons.add),
        onPressed: () {
          if (authProvider.isAuthenticated) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreatePostScreen()),
            );
          } else {
            AuthPromptBottomSheet.show(context, actionTitle: 'Create Post');
          }
        },
      ),
    );
  }
}
