import 'package:flutter/material.dart';
import '../models/post_model.dart';
import '../services/api_service.dart';

class PostProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<Post> _posts = [];
  List<Post> _bookmarkedPosts = [];
  bool _isLoading = false;
  bool _isLoadingBookmarks = false;
  String? _selectedCategory;

  List<Post> get posts => _posts;
  List<Post> get bookmarkedPosts => _bookmarkedPosts;
  bool get isLoading => _isLoading;
  bool get isLoadingBookmarks => _isLoadingBookmarks;
  String? get selectedCategory => _selectedCategory;

  Future<void> fetchPosts({String? category}) async {
    _isLoading = true;
    _selectedCategory = category;
    notifyListeners();

    try {
      final response = await _apiService.getPosts(category: category);
      if (response.statusCode == 200 && response.data != null) {
        final List rawList = response.data['posts'] ?? response.data['data'] ?? response.data ?? [];
        _posts = rawList.map((item) => Post.fromJson(item)).toList();
      } else {
        _posts = [];
      }
    } catch (e) {
      debugPrint('Fetch posts API error: $e');
      _posts = [];
    } finally {
      _isLoading = false;
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

  Future<bool> createPost(String content, {String? mediaUrl, String? communityId}) async {
    try {
      final response = await _apiService.createPost({
        'content': content,
        'media_url': ?(mediaUrl != null && mediaUrl.isNotEmpty ? mediaUrl : null),
        'community_id': ?communityId,
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchPosts(category: _selectedCategory);
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

  Future<void> toggleBookmark(String postId) async {
    final postIndex = _posts.indexWhere((p) => p.id == postId);
    final bookmarkIndex = _bookmarkedPosts.indexWhere((p) => p.id == postId);

    if (postIndex == -1 && bookmarkIndex == -1) return;

    final target = postIndex != -1 ? _posts[postIndex] : _bookmarkedPosts[bookmarkIndex];
    final newBookmarked = !target.isBookmarked;

    if (postIndex != -1) {
      _posts[postIndex] = _posts[postIndex].copyWith(isBookmarked: newBookmarked);
    }

    if (newBookmarked) {
      if (!_bookmarkedPosts.any((p) => p.id == postId)) {
        _bookmarkedPosts.insert(0, (postIndex != -1 ? _posts[postIndex] : target).copyWith(isBookmarked: true));
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
        _posts[postIndex] = target;
      }
      if (target.isBookmarked) {
        if (!_bookmarkedPosts.any((p) => p.id == postId)) {
          _bookmarkedPosts.add(target);
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

  Future<PostComment?> addComment(String postId, String commentText) async {
    try {
      final response = await _apiService.createComment(postId, commentText);
      if (response.statusCode == 200 || response.statusCode == 201) {
        // Increment comment counter in local posts
        _incrementCommentsCount(postId, 1);

        final commentData = response.data['data'] ?? response.data;
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
}
