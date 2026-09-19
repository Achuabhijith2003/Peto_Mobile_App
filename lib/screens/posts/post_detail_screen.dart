import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/post_model.dart';
import '../../providers/post_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/comments_bottom_sheet.dart';
import '../../widgets/post_card.dart';

class PostDetailScreen extends StatefulWidget {
  final String postId;
  final Post? initialPost;
  final bool autoOpenComments;

  const PostDetailScreen({
    super.key,
    required this.postId,
    this.initialPost,
    this.autoOpenComments = false,
  });

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final ApiService _apiService = ApiService();
  Post? _post;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.initialPost != null) {
      _post = widget.initialPost;
      _isLoading = false;
      if (widget.autoOpenComments) {
        _triggerCommentsAfterBuild();
      }
    } else {
      _fetchPost();
    }
  }

  Future<void> _fetchPost() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _apiService.getPostById(widget.postId);
      if (response.statusCode == 200 && response.data != null) {
        final postData = response.data['data'] ?? response.data['post'] ?? response.data;
        if (postData != null && postData is Map<String, dynamic>) {
          setState(() {
            _post = Post.fromJson(postData);
            _isLoading = false;
          });

          if (widget.autoOpenComments) {
            _triggerCommentsAfterBuild();
          }
          return;
        }
      }
      setState(() {
        _errorMessage = 'Post not found or has been deleted.';
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[PostDetailScreen] Error fetching post: $e');
      setState(() {
        _errorMessage = 'Failed to load post. Please try again.';
        _isLoading = false;
      });
    }
  }

  void _triggerCommentsAfterBuild() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _post == null) return;
      CommentsBottomSheet.show(
        context,
        postId: _post!.id,
        postAuthorUsername: _post!.author.username,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Post',
          style: TextStyle(
            color: AppColors.onBackground,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.onBackground, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_errorMessage != null || _post == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.article_outlined, size: 64, color: AppColors.outline.withValues(alpha: 0.5)),
              const SizedBox(height: 16),
              Text(
                _errorMessage ?? 'Post unavailable',
                style: const TextStyle(
                  color: AppColors.onBackground,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchPost,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: PostCard(
          post: _post!,
          onLike: () {
            final postProvider = Provider.of<PostProvider>(context, listen: false);
            postProvider.toggleLike(_post!.id);
            setState(() {
              _post = Post(
                id: _post!.id,
                content: _post!.content,
                author: _post!.author,
                media: _post!.media,
                communityId: _post!.communityId,
                communityName: _post!.communityName,
                likesCount: _post!.isLiked ? _post!.likesCount - 1 : _post!.likesCount + 1,
                commentsCount: _post!.commentsCount,
                isLiked: !_post!.isLiked,
                isBookmarked: _post!.isBookmarked,
                createdAt: _post!.createdAt,
              );
            });
          },
          onBookmark: () {
            final postProvider = Provider.of<PostProvider>(context, listen: false);
            postProvider.toggleBookmark(_post!.id, isCurrentlyBookmarked: _post!.isBookmarked);
            setState(() {
              _post = Post(
                id: _post!.id,
                content: _post!.content,
                author: _post!.author,
                media: _post!.media,
                communityId: _post!.communityId,
                communityName: _post!.communityName,
                likesCount: _post!.likesCount,
                commentsCount: _post!.commentsCount,
                isLiked: _post!.isLiked,
                isBookmarked: !_post!.isBookmarked,
                createdAt: _post!.createdAt,
              );
            });
          },
          onComment: () {
            CommentsBottomSheet.show(
              context,
              postId: _post!.id,
              postAuthorUsername: _post!.author.username,
            );
          },
          onPostDeleted: () {
            Navigator.pop(context);
          },
          onPostEdited: (newText) {
            setState(() {
              _post = Post(
                id: _post!.id,
                content: newText,
                author: _post!.author,
                media: _post!.media,
                communityId: _post!.communityId,
                communityName: _post!.communityName,
                likesCount: _post!.likesCount,
                commentsCount: _post!.commentsCount,
                isLiked: _post!.isLiked,
                isBookmarked: _post!.isBookmarked,
                createdAt: _post!.createdAt,
              );
            });
          },
        ),
      ),
    );
  }
}
