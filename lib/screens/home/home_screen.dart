import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/post_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/post_card.dart';
import '../../widgets/comments_bottom_sheet.dart';
import '../../widgets/auth_prompt_bottom_sheet.dart';
import '../posts/create_post_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<PostProvider>(context, listen: false).fetchPosts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final postProvider = Provider.of<PostProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.pets, color: AppColors.primaryContainer, size: 26),
            SizedBox(width: 8),
            Text(
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
          IconButton(
            icon: const Icon(Icons.notifications_none_outlined),
            onPressed: () {
              if (!authProvider.isAuthenticated) {
                AuthPromptBottomSheet.show(
                  context,
                  actionTitle: 'Notifications',
                );
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
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
            if (postProvider.isLoading) ...[
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
                  return PostCard(
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
                  );
                },
              ),
            ],
          ],
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
