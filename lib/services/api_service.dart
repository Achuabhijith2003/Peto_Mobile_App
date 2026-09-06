import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'storage_service.dart';

class ApiService {
  // 10.0.2.2 targets localhost from Android Emulator
  static const String defaultBaseUrl = 'https://peto-web.onrender.com/api';
  
  late final Dio _dio;
  final StorageService _storageService = StorageService();

  ApiService({String? baseUrl}) {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl ?? defaultBaseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storageService.getToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          if (options.data is FormData) {
            // Remove Content-Type header so Dio calculates boundary automatically
            options.headers.remove('Content-Type');
            options.headers.remove('content-type');
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) async {
          if (error.response?.statusCode == 401 &&
              !error.requestOptions.path.contains('/auth/login') &&
              !error.requestOptions.path.contains('/auth/signup') &&
              !error.requestOptions.path.contains('/auth/refresh')) {
            final refreshToken = await _storageService.getRefreshToken();
            if (refreshToken != null && refreshToken.isNotEmpty) {
              try {
                final refreshResponse = await _dio.post(
                  '/auth/refresh',
                  data: {'refreshToken': refreshToken},
                );

                if (refreshResponse.data != null &&
                    refreshResponse.data['success'] == true &&
                    refreshResponse.data['token'] != null) {
                  final newToken = refreshResponse.data['token'];
                  final newRefreshToken = refreshResponse.data['refreshToken'];

                  await _storageService.saveToken(newToken);
                  if (newRefreshToken != null) {
                    await _storageService.saveRefreshToken(newRefreshToken);
                  }

                  // Retry original request with new token
                  final opts = error.requestOptions;
                  opts.headers['Authorization'] = 'Bearer $newToken';
                  final cloneReq = await _dio.fetch(opts);
                  return handler.resolve(cloneReq);
                }
              } catch (_) {
                await _storageService.clearAuthData();
              }
            }
          }
          return handler.next(error);
        },
      ),
    );
  }

  Dio get client => _dio;

  // ----------------------
  // HEALTH CHECK API (/health)
  // ----------------------
  Future<Map<String, dynamic>> checkHealth() async {
    try {
      final rootDio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 20),
        ),
      );
      final response = await rootDio.get('https://peto-web.onrender.com/health');
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        final isOk = data['success'] == true && data['status'] == 'OK';
        return {
          'isHealthy': isOk,
          'message': isOk ? 'API Server OK' : 'API status degraded',
          'timestamp': data['timestamp'],
        };
      }
      return {
        'isHealthy': false,
        'message': 'API returned HTTP ${response.statusCode}',
      };
    } catch (e) {
      return {
        'isHealthy': false,
        'message': 'Unable to connect to https://peto-web.onrender.com',
      };
    }
  }

  // ----------------------
  // AUTH API (/api/auth)
  // ----------------------
  Future<Response> login(String email, String password) async {
    return await _dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
  }

  Future<Response> register(Map<String, dynamic> data) async {
    return await _dio.post('/auth/signup', data: {
      'email': data['email'],
      'password': data['password'],
      'username': data['username'],
      'fullName': data['fullName'] ?? data['username'] ?? '',
      'full_name': data['full_name'] ?? data['username'] ?? '',
    });
  }

  Future<Response> forgotPassword(String email, {String? redirectTo}) async {
    final Map<String, dynamic> data = {'email': email};
    if (redirectTo != null) {
      data['redirectTo'] = redirectTo;
    }
    return await _dio.post('/auth/forgot-password', data: data);
  }

  // ----------------------
  // USERS API (/api/users)
  // ----------------------
  Future<Response> getCurrentUser() async {
    return await _dio.get('/users/me');
  }

  Future<Response> createProfile(Map<String, dynamic> data) async {
    return await _dio.post('/users/profile', data: data);
  }

  Future<Response> checkUsername(String username) async {
    return await _dio.get('/users/check-username', queryParameters: {'username': username});
  }

  Future<Response> updateProfile(Map<String, dynamic> data) async {
    return await _dio.patch('/users/me', data: data);
  }

  Future<Response> searchUsers(String query) async {
    return await _dio.get('/users/search', queryParameters: {'q': query});
  }

  Future<Response> getUserById(String id) async {
    return await _dio.get('/users/$id');
  }

  Future<Response> getUserPosts(String userId) async {
    return await _dio.get('/posts/users/$userId/posts');
  }

  // ----------------------
  // FOLLOW / UNFOLLOW (/api/user)
  // ----------------------
  Future<Response> followUser(String targetUserId) async {
    return await _dio.post('/user/$targetUserId/follow');
  }

  Future<Response> unfollowUser(String targetUserId) async {
    return await _dio.delete('/user/$targetUserId/follow');
  }

  Future<Response> getFollowers(String userId) async {
    return await _dio.get('/user/$userId/followers');
  }

  Future<Response> getFollowing(String userId) async {
    return await _dio.get('/user/$userId/following');
  }

  // ----------------------
  // POSTS API (/api/posts)
  // ----------------------
  Future<Response> getPosts({int page = 1, int limit = 7, String? category}) async {
    return await _dio.get('/posts/feed', queryParameters: {
      'page': page,
      'limit': limit,
      'category': ?category,
    });
  }

  Future<Response> getMyPosts() async {
    return await _dio.get('/posts/my');
  }

  Future<Response> getReels() async {
    return await _dio.get('/posts/reels');
  }

  Future<Response> searchPosts(String query) async {
    return await _dio.get('/posts/search', queryParameters: {'q': query});
  }

  Future<Response> createPost(Map<String, dynamic> data) async {
    return await _dio.post('/posts', data: data);
  }

  Future<Response> updatePost(String id, Map<String, dynamic> data) async {
    return await _dio.patch('/posts/$id', data: data);
  }

  Future<Response> deletePost(String id) async {
    return await _dio.delete('/posts/$id');
  }

  // ----------------------
  // LIKES API (/api/posts/:id/like)
  // ----------------------
  Future<Response> likePost(String postId) async {
    return await _dio.post('/posts/$postId/like');
  }

  Future<Response> unlikePost(String postId) async {
    return await _dio.delete('/posts/$postId/like');
  }

  // ----------------------
  // COMMENTS API (/api/posts/:id/comments & /api/comments/:id)
  // ----------------------
  Future<Response> getComments(String postId) async {
    return await _dio.get('/posts/$postId/comments');
  }

  Future<Response> createComment(String postId, String content) async {
    return await _dio.post(
      '/posts/$postId/comments',
      data: {'comment': content, 'content': content},
    );
  }

  Future<Response> deleteComment(String commentId) async {
    return await _dio.delete('/comments/$commentId');
  }

  // ----------------------
  // BOOKMARKS API (/api/my/bookmarks & /api/my/posts/:id/bookmark)
  // ----------------------
  Future<Response> getBookmarks() async {
    return await _dio.get('/my/bookmarks');
  }

  Future<Response> bookmarkPost(String postId) async {
    return await _dio.post('/my/posts/$postId/bookmark');
  }

  Future<Response> removeBookmark(String postId) async {
    return await _dio.delete('/my/posts/$postId/bookmark');
  }

  // ----------------------
  // COMMUNITIES API (/api/communities)
  // ----------------------
  Future<Response> getCommunities({
    String? category,
    String? search,
    String? sort,
    int page = 1,
  }) async {
    return await _dio.get('/communities', queryParameters: {
      if (category != null && category.toLowerCase() != 'all') 'category': category,
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      'sort': ?sort,
      'page': page,
      'limit': 20,
    });
  }

  Future<Response> getCommunityDetail(String id) async {
    return await _dio.get('/communities/$id');
  }

  Future<Response> getCommunityFeed(String id, {int page = 1, String sort = 'new'}) async {
    return await _dio.get('/communities/$id/posts', queryParameters: {
      'page': page,
      'limit': 15,
      'sort': sort,
    });
  }

  Future<Response> getCommunityMembers(String id, {int page = 1}) async {
    return await _dio.get('/communities/$id/members', queryParameters: {
      'page': page,
      'limit': 20,
    });
  }

  Future<Response> getCommunityRules(String id) async {
    return await _dio.get('/communities/$id/rules');
  }

  Future<Response> createCommunity(Map<String, dynamic> data) async {
    return await _dio.post('/communities', data: data);
  }

  Future<Response> updateCommunity(String id, Map<String, dynamic> data) async {
    return await _dio.patch('/communities/$id', data: data);
  }

  Future<Response> joinCommunity(String id) async {
    return await _dio.post('/communities/$id/join');
  }

  Future<Response> leaveCommunity(String id) async {
    return await _dio.delete('/communities/$id/membership');
  }

  Future<Response> changeMemberRole(String communityId, String targetUserId, String role) async {
    return await _dio.patch('/communities/$communityId/members/$targetUserId/role', data: {
      'role': role,
    });
  }

  Future<Response> banMember(String communityId, String targetUserId, String reason) async {
    return await _dio.post('/communities/$communityId/bans', data: {
      'user_id': targetUserId,
      'reason': reason,
    });
  }

  Future<Response> unbanMember(String communityId, String targetUserId) async {
    return await _dio.delete('/communities/$communityId/bans/$targetUserId');
  }

  Future<Response> createCommunityRule(String communityId, String title, String description) async {
    return await _dio.post('/communities/$communityId/rules', data: {
      'title': title,
      'description': description,
    });
  }

  Future<Response> deleteCommunityRule(String communityId, String ruleId) async {
    return await _dio.delete('/communities/$communityId/rules/$ruleId');
  }

  // ----------------------
  // NOTIFICATIONS API (/api/notifications)
  // ----------------------
  Future<Response> getNotifications() async {
    return await _dio.get('/notifications');
  }

  Future<Response> markAllNotificationsRead() async {
    return await _dio.patch('/notifications/read-all');
  }

  // ----------------------
  // MEDIA UPLOAD API (/api/media/upload)
  // ----------------------
  static DioMediaType _resolveMediaType(String pathOrName) {
    final lower = pathOrName.toLowerCase();
    if (lower.endsWith('.png')) return DioMediaType('image', 'png');
    if (lower.endsWith('.webp')) return DioMediaType('image', 'webp');
    if (lower.endsWith('.gif')) return DioMediaType('image', 'gif');
    if (lower.endsWith('.mp4')) return DioMediaType('video', 'mp4');
    if (lower.endsWith('.mov')) return DioMediaType('video', 'quicktime');
    if (lower.endsWith('.avi')) return DioMediaType('video', 'x-msvideo');
    if (lower.endsWith('.mkv')) return DioMediaType('video', 'x-matroska');
    if (lower.endsWith('.webm')) return DioMediaType('video', 'webm');
    return DioMediaType('image', 'jpeg');
  }

  Future<MediaUploadResult> uploadMediaFile(
    String filePath, {
    String? fileName,
    void Function(int sent, int total)? onProgress,
  }) async {
    try {
      final token = await _storageService.getToken();
      if (token == null || token.isEmpty) {
        return MediaUploadResult(
          success: false,
          errorMessage: 'Please log in to upload media.',
        );
      }

      final file = File(filePath);
      if (!await file.exists()) {
        return MediaUploadResult(
          success: false,
          errorMessage: 'Selected file could not be found.',
        );
      }

      final name = fileName ?? filePath.split('/').last.split('\\').last;
      final mediaType = _resolveMediaType(name);

      final multipartFile = await MultipartFile.fromFile(
        filePath,
        filename: name,
        contentType: mediaType,
      );

      final formData = FormData();
      formData.files.add(MapEntry('media', multipartFile));

      final response = await _dio.post(
        '/media/upload',
        data: formData,
        onSendProgress: onProgress,
        options: Options(
          sendTimeout: const Duration(minutes: 5),
          receiveTimeout: const Duration(minutes: 5),
        ),
      );

      if ((response.statusCode == 200 || response.statusCode == 201) && response.data != null) {
        final data = response.data;
        final mediaUrl = data['mediaUrl'] ??
            data['url'] ??
            (data['data'] is List && (data['data'] as List).isNotEmpty
                ? ((data['data'] as List).first is Map
                    ? ((data['data'] as List).first['url'] ?? (data['data'] as List).first['path'])
                    : (data['data'] as List).first)
                : (data['data'] is Map ? (data['data']['url'] ?? data['data']['path']) : null));

        if (mediaUrl != null && mediaUrl.toString().isNotEmpty) {
          return MediaUploadResult(
            success: true,
            mediaUrl: mediaUrl.toString(),
          );
        }
      }

      final msg = response.data is Map ? response.data['message'] : null;
      return MediaUploadResult(
        success: false,
        errorMessage: msg?.toString() ?? 'Server rejected the file upload.',
      );
    } catch (e) {
      String message = 'Upload failed';
      if (e is DioException) {
        debugPrint('Upload media DioException: [${e.response?.statusCode}] ${e.response?.data}');
        if (e.response?.statusCode == 401) {
          message = 'Session expired. Please log in again.';
        } else if (e.response?.statusCode == 413) {
          message = 'File size is too large (max 30MB images, 200MB videos).';
        } else if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.sendTimeout ||
            e.type == DioExceptionType.receiveTimeout) {
          message = 'Connection timed out while uploading. Please try again.';
        } else if (e.response?.data is Map && e.response?.data['message'] != null) {
          message = e.response!.data['message'].toString();
        }
      } else {
        debugPrint('Upload media error: $e');
      }
      return MediaUploadResult(
        success: false,
        errorMessage: message,
      );
    }
  }
}

class MediaUploadResult {
  final bool success;
  final String? mediaUrl;
  final String? errorMessage;

  MediaUploadResult({
    required this.success,
    this.mediaUrl,
    this.errorMessage,
  });
}

