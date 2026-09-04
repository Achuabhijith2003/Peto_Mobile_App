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
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
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
      'fullName': data['username'] ?? data['fullName'] ?? '',
      'full_name': data['username'] ?? data['full_name'] ?? '',
    });
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
  Future<Response> getPosts({int page = 1, String? category}) async {
    return await _dio.get('/posts/feed', queryParameters: {
      'page': page,
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
  // BOOKMARKS API (/api/my/bookmarks & /api/posts/:id/bookmark)
  // ----------------------
  Future<Response> getBookmarks() async {
    return await _dio.get('/my/bookmarks');
  }

  Future<Response> bookmarkPost(String postId) async {
    return await _dio.post('/posts/$postId/bookmark');
  }

  Future<Response> removeBookmark(String postId) async {
    return await _dio.delete('/posts/$postId/bookmark');
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

  Future<Response> joinCommunity(String id) async {
    return await _dio.post('/communities/$id/join');
  }

  Future<Response> leaveCommunity(String id) async {
    return await _dio.delete('/communities/$id/membership');
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
}
