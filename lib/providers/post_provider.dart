import 'package:flutter/material.dart';
import '../models/post_model.dart';
import '../services/api_service.dart';

class PostProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<Post> _posts = [];
  List<Post> _bookmarkedPosts = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
  static const int _limit = 7;
  bool _isLoadingBookmarks = false;
  String? _selectedCategory;

  List<Post> get posts => _posts;
  List<Post> get bookmarkedPosts => _bookmarkedPosts;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  int get currentPage => _currentPage;
  bool get isLoadingBookmarks => _isLoadingBookmarks;
  String? get selectedCategory => _selectedCategory;

  Future<void> fetchPosts({String? category, bool refresh = false}) async {
    _isLoading = true;
    _currentPage = 1;
    _hasMore = true;
    _selectedCategory = category;
    notifyListeners();

    try {
      final response = await _apiService.getPosts(page: 1, limit: _limit, category: category);
      if (response.statusCode == 200 && response.data != null) {
        final List rawList = response.data['posts'] ?? response.data['data'] ?? response.data ?? [];
        _posts = rawList.map((item) => Post.fromJson(item)).toList();
        if (rawList.length < _limit) {
          _hasMore = false;
        }
      } else {
        _posts = [];
        _hasMore = false;
      }
    } catch (e) {
      debugPrint('Fetch posts API error: $e');
      _posts = [];
      _hasMore = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchMorePosts() async {
    if (_isLoading || _isLoadingMore || !_hasMore) return;

    _isLoadingMore = true;
    notifyListeners();

    final nextPage = _currentPage + 1;

    try {
      final response = await _apiService.getPosts(
        page: nextPage,
        limit: _limit,
        category: _selectedCategory,
      );
      if (response.statusCode == 200 && response.data != null) {
        final List rawList = response.data['posts'] ?? response.data['data'] ?? response.data ?? [];
        final List<Post> newPosts = rawList.map((item) => Post.fromJson(item)).toList();

        final existingIds = _posts.map((p) => p.id).toSet();
        final uniqueNew = newPosts.where((p) => !existingIds.contains(p.id)).toList();
        _posts.addAll(uniqueNew);

        _currentPage = nextPage;
        if (newPosts.length < _limit) {
          _hasMore = false;
        }
      } else {
        _hasMore = false;
      }
    } catch (e) {
      debugPrint('Fetch more posts API error: $e');
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> fetchBookmarks() async {
    _isLoadingBookmarks = true;
    notifyListeners();

    try {
      final response = await _apiService.getBookmarks();
      if (response.statusCode == 200 && response.data != null) {
        final List rawList = response.data['bookmarks'] ?? response.data['data'] ?? response.data ?? [];
        _bookmarkedPosts = rawList.map((item) => Post.fromJson(item)).toList();
      } else {
        _bookmarkedPosts = [];
      }
    } catch (e) {
      debugPrint('Fetch bookmarks API error: $e');
      _bookmarkedPosts = [];
    } finally {
      _isLoadingBookmarks = false;
      notifyListeners();
    }
  }

  Future<bool> createPost(
    String content, {
    List<String>? mediaUrls,
    String? mediaUrl,
    String? communityId,
    String? petId,
  }) async {
    try {
      final List<String> allMedia = [];
      if (mediaUrls != null && mediaUrls.isNotEmpty) {
        allMedia.addAll(mediaUrls);
      } else if (mediaUrl != null && mediaUrl.isNotEmpty) {
        allMedia.add(mediaUrl);
      }

      final response = await _apiService.createPost({
        'content': content,
        'text': content,
        'media': allMedia,
        'media_url': allMedia.isNotEmpty ? allMedia.first : null,
        'community_id': communityId,
        if (petId != null) 'pet_id': petId,
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchPosts(category: _selectedCategory, refresh: true);
        return true;
      }
    } catch (e) {
      debugPrint('Create post API error: $e');
    }
    return false;
  }

  Future<void> toggleLike(String postId) async {
    final postIndex = _posts.indexWhere((p) => p.id == postId);
    final bookmarkIndex = _bookmarkedPosts.indexWhere((p) => p.id == postId);

    if (postIndex == -1 && bookmarkIndex == -1) return;

    final target = postIndex != -1 ? _posts[postIndex] : _bookmarkedPosts[bookmarkIndex];
    final newLikedState = !target.isLiked;
    final newCount = newLikedState
        ? target.likesCount + 1
        : (target.likesCount > 0 ? target.likesCount - 1 : 0);

    if (postIndex != -1) {
      _posts[postIndex] = _posts[postIndex].copyWith(isLiked: newLikedState, likesCount: newCount);
    }
    if (bookmarkIndex != -1) {
      _bookmarkedPosts[bookmarkIndex] = _bookmarkedPosts[bookmarkIndex].copyWith(isLiked: newLikedState, likesCount: newCount);
    }
    notifyListeners();

    try {
      if (newLikedState) {
        await _apiService.likePost(postId);
      } else {
        await _apiService.unlikePost(postId);
      }
    } catch (e) {
      debugPrint('Toggle like API error: $e');
      // Revert on error
      if (postIndex != -1) {
        _posts[postIndex] = target;
      }
      if (bookmarkIndex != -1) {
        _bookmarkedPosts[bookmarkIndex] = target;
      }
      notifyListeners();
    }
  }

  Future<void> toggleBookmark(String postId, {bool? isCurrentlyBookmarked}) async {
    final postIndex = _posts.indexWhere((p) => p.id == postId);
    final bookmarkIndex = _bookmarkedPosts.indexWhere((p) => p.id == postId);

    bool currentBookmarked;
    if (isCurrentlyBookmarked != null) {
      currentBookmarked = isCurrentlyBookmarked;
    } else if (postIndex != -1) {
      currentBookmarked = _posts[postIndex].isBookmarked;
    } else if (bookmarkIndex != -1) {
      currentBookmarked = _bookmarkedPosts[bookmarkIndex].isBookmarked;
    } else {
      currentBookmarked = false;
    }

    final newBookmarked = !currentBookmarked;

    if (postIndex != -1) {
      _posts[postIndex] = _posts[postIndex].copyWith(isBookmarked: newBookmarked);
    }

    if (newBookmarked) {
      if (!_bookmarkedPosts.any((p) => p.id == postId)) {
        if (postIndex != -1) {
          _bookmarkedPosts.insert(0, _posts[postIndex]);
        }
      }
    } else {
      _bookmarkedPosts.removeWhere((p) => p.id == postId);
    }
    notifyListeners();

    try {
      if (newBookmarked) {
        await _apiService.bookmarkPost(postId);
      } else {
        await _apiService.removeBookmark(postId);
      }
    } catch (e) {
      debugPrint('Toggle bookmark API error: $e');
      // Revert on error
      if (postIndex != -1) {
        _posts[postIndex] = _posts[postIndex].copyWith(isBookmarked: currentBookmarked);
      }
      if (currentBookmarked) {
        if (postIndex != -1 && !_bookmarkedPosts.any((p) => p.id == postId)) {
          _bookmarkedPosts.insert(0, _posts[postIndex]);
        }
      } else {
        _bookmarkedPosts.removeWhere((p) => p.id == postId);
      }
      notifyListeners();
    }
  }

  // ----------------------
  // COMMENTS MANAGEMENT
  // ----------------------
  Future<List<PostComment>> fetchComments(String postId) async {
    try {
      final response = await _apiService.getComments(postId);
      if (response.statusCode == 200 && response.data != null) {
        final List rawList = response.data['comments'] ?? response.data['data'] ?? [];
        return rawList.map((c) => PostComment.fromJson(c as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('Fetch comments API error: $e');
    }
    return [];
  }

  Future<PostComment?> addComment(String postId, String commentText, {String? parentCommentId}) async {
    try {
      final response = await _apiService.createComment(postId, commentText, parentCommentId: parentCommentId);
      if (response.statusCode == 200 || response.statusCode == 201) {
        // Increment comment counter in local posts
        _incrementCommentsCount(postId, 1);

        final commentData = response.data['comment'] ?? response.data['data'] ?? response.data;
        if (commentData != null && commentData is Map<String, dynamic>) {
          return PostComment.fromJson(commentData);
        }
      }
    } catch (e) {
      debugPrint('Add comment API error: $e');
    }
    return null;
  }

  Future<bool> deleteComment(String postId, String commentId) async {
    try {
      final response = await _apiService.deleteComment(commentId);
      if (response.statusCode == 200) {
        _incrementCommentsCount(postId, -1);
        return true;
      }
    } catch (e) {
      debugPrint('Delete comment API error: $e');
    }
    return false;
  }

  void _incrementCommentsCount(String postId, int delta) {
    final postIndex = _posts.indexWhere((p) => p.id == postId);
    if (postIndex != -1) {
      final current = _posts[postIndex];
      final newCount = (current.commentsCount + delta).clamp(0, 999999);
      _posts[postIndex] = current.copyWith(commentsCount: newCount);
    }

    final bookmarkIndex = _bookmarkedPosts.indexWhere((p) => p.id == postId);
    if (bookmarkIndex != -1) {
      final current = _bookmarkedPosts[bookmarkIndex];
      final newCount = (current.commentsCount + delta).clamp(0, 999999);
      _bookmarkedPosts[bookmarkIndex] = current.copyWith(commentsCount: newCount);
    }

    notifyListeners();
  }

  Future<bool> deletePost(String postId) async {
    try {
      final response = await _apiService.deletePost(postId);
      if (response.statusCode == 200 || response.statusCode == 204) {
        _posts.removeWhere((p) => p.id == postId);
        _bookmarkedPosts.removeWhere((p) => p.id == postId);
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('Delete post API error: $e');
    }
    return false;
  }

  Future<bool> updatePost(String postId, String newContent) async {
    try {
      final response = await _apiService.updatePost(postId, {'text': newContent, 'content': newContent});
      if (response.statusCode == 200) {
        final postIndex = _posts.indexWhere((p) => p.id == postId);
        if (postIndex != -1) {
          final old = _posts[postIndex];
          _posts[postIndex] = Post(
            id: old.id,
            content: newContent,
            author: old.author,
            media: old.media,
            communityId: old.communityId,
            communityName: old.communityName,
            likesCount: old.likesCount,
            commentsCount: old.commentsCount,
            isLiked: old.isLiked,
            isBookmarked: old.isBookmarked,
            createdAt: old.createdAt,
          );
        }

        final bookmarkIndex = _bookmarkedPosts.indexWhere((p) => p.id == postId);
        if (bookmarkIndex != -1) {
          final old = _bookmarkedPosts[bookmarkIndex];
          _bookmarkedPosts[bookmarkIndex] = Post(
            id: old.id,
            content: newContent,
            author: old.author,
            media: old.media,
            communityId: old.communityId,
            communityName: old.communityName,
            likesCount: old.likesCount,
            commentsCount: old.commentsCount,
            isLiked: old.isLiked,
            isBookmarked: old.isBookmarked,
            createdAt: old.createdAt,
          );
        }

        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('Update post API error: $e');
    }
    return false;
  }
}
