import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'storage_service.dart';
import '../models/policy_model.dart';
import '../models/pet_model.dart';

class ApiService {
  // 10.0.2.2 targets localhost from Android Emulator
  static const String defaultBaseUrl = 'https://peto-web.onrender.com/api';
  
  static Function(String?)? onMaintenanceDetected;

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
          // Detect Controlled Maintenance Mode (HTTP 503)
          if (error.response?.statusCode == 503) {
            final data = error.response?.data;
            final isMaintenance = data is Map &&
                (data['maintenance'] == true ||
                    data['message']?.toString().toLowerCase().contains('maintenance') == true);
            if (isMaintenance) {
              final msg = data['message']?.toString();
              onMaintenanceDetected?.call(msg);
            }
          }

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
          'status': data['status']?.toString() ?? (isOk ? 'OK' : 'DEGRADED'),
          'maintenance': data['maintenance'] == true || data['status'] == 'MAINTENANCE',
          'message': data['message']?.toString() ?? (isOk ? 'API Server OK' : 'Scheduled maintenance underway'),
          'timestamp': data['timestamp'],
        };
      }
      return {
        'isHealthy': false,
        'status': 'ERROR',
        'maintenance': false,
        'message': 'API returned HTTP ${response.statusCode}',
      };
    } catch (e) {
      return {
        'isHealthy': false,
        'status': 'OFFLINE',
        'maintenance': false,
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

  Future<Response> getPostById(String id) async {
    return await _dio.get('/posts/$id');
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

  Future<Response> createComment(String postId, String content, {String? parentCommentId}) async {
    final Map<String, dynamic> data = {'comment': content};
    if (parentCommentId != null && parentCommentId.isNotEmpty) {
      data['parent_comment_id'] = parentCommentId;
    }
    return await _dio.post(
      '/posts/$postId/comments',
      data: data,
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
  Future<Response> getNotifications({int page = 1, int limit = 20}) async {
    return await _dio.get('/notifications', queryParameters: {
      'page': page,
      'limit': limit,
    });
  }

  Future<Response> getUnreadNotificationCount() async {
    return await _dio.get('/notifications/unread-count');
  }

  Future<Response> markNotificationRead(String id) async {
    return await _dio.patch('/notifications/$id/read');
  }

  Future<Response> markAllNotificationsRead() async {
    return await _dio.patch('/notifications/read-all');
  }

  Future<Response> deleteNotification(String id) async {
    return await _dio.delete('/notifications/$id');
  }

  Future<Response> getNotificationSettings() async {
    return await _dio.get('/notifications/settings');
  }

  Future<Response> updateNotificationSettings(Map<String, dynamic> data) async {
    return await _dio.put('/notifications/settings', data: data);
  }

  Future<Response> registerDeviceToken(String fcmToken, {String platform = 'android'}) async {
    return await _dio.post('/notifications/device-token', data: {
      'fcmToken': fcmToken,
      'platform': platform,
    });
  }

  Future<Response> unregisterDeviceToken(String fcmToken) async {
    return await _dio.delete('/notifications/device-token', data: {
      'fcmToken': fcmToken,
    });
  }

  // ----------------------
  // MEDIA UPLOAD API (/api/media/upload)
  // ----------------------
  static DioMediaType _resolveMediaType(String pathOrName, {bool? isVideo}) {
    final lower = pathOrName.toLowerCase();
    if (lower.endsWith('.png')) return DioMediaType('image', 'png');
    if (lower.endsWith('.webp')) return DioMediaType('image', 'webp');
    if (lower.endsWith('.gif')) return DioMediaType('image', 'gif');
    if (lower.endsWith('.heic')) return DioMediaType('image', 'heic');
    if (lower.endsWith('.heif')) return DioMediaType('image', 'heif');
    if (lower.endsWith('.mp4')) return DioMediaType('video', 'mp4');
    if (lower.endsWith('.mov')) return DioMediaType('video', 'quicktime');
    if (lower.endsWith('.avi')) return DioMediaType('video', 'x-msvideo');
    if (lower.endsWith('.mkv')) return DioMediaType('video', 'x-matroska');
    if (lower.endsWith('.webm')) return DioMediaType('video', 'webm');
    if (lower.endsWith('.3gp')) return DioMediaType('video', '3gpp');
    if (lower.endsWith('.m4v')) return DioMediaType('video', 'x-m4v');
    if (lower.endsWith('.ts')) return DioMediaType('video', 'mp2t');

    if (isVideo == true) {
      return DioMediaType('video', 'mp4');
    }
    return DioMediaType('image', 'jpeg');
  }

  Future<MediaUploadResult> uploadMediaFile(
    String filePath, {
    String? fileName,
    bool isVideo = false,
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
      final mediaType = _resolveMediaType(name, isVideo: isVideo);

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

        final mediaId = data['mediaId'] ??
            (data['data'] is List && (data['data'] as List).isNotEmpty
                ? ((data['data'] as List).first is Map
                    ? (data['data'] as List).first['id']?.toString()
                    : null)
                : (data['data'] is Map ? data['data']['id']?.toString() : null));

        if (mediaUrl != null && mediaUrl.toString().isNotEmpty) {
          return MediaUploadResult(
            success: true,
            mediaUrl: mediaUrl.toString(),
            mediaId: mediaId?.toString(),
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

  Future<Map<String, dynamic>> createReport({
    required String targetType,
    required String targetId,
    required String reason,
    String? description,
  }) async {
    try {
      final response = await _dio.post(
        '/reports',
        data: {
          'target_type': targetType,
          'target_id': targetId,
          'reason': reason,
          if (description != null && description.trim().isNotEmpty)
            'description': description.trim(),
        },
      );
      return {
        'success': true,
        'message': response.data['message'] ?? 'Report submitted successfully.',
        'data': response.data['data'],
      };
    } on DioException catch (e) {
      final resData = e.response?.data;
      String errMsg = 'Failed to submit report. Please try again.';
      if (resData is Map && resData['message'] != null) {
        errMsg = resData['message'].toString();
      }
      return {
        'success': false,
        'message': errMsg,
        'statusCode': e.response?.statusCode,
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  /// Fetch active sponsored advertisements for feeds (supports both unified AdDecisionEngine and direct fallback)
  Future<List<Map<String, dynamic>>> fetchFeedAds({String placement = 'FEED'}) async {
    try {
      // 1. Try unified AdDecisionEngine first
      final decision = await fetchUnifiedAdDecision(placement: placement);
      if (decision != null && decision['hasAd'] == true && decision['ad'] != null) {
        final adData = Map<String, dynamic>.from(decision['ad']);
        adData['source'] = decision['source'] ?? adData['source'] ?? 'PETO';
        return [adData];
      }

      // 2. Graceful fallback to legacy direct feed
      final response = await _dio.get(
        '/ads/feed',
        queryParameters: {'placement': placement},
      );
      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic>? adsList = response.data['ads'];
        if (adsList != null) {
          return List<Map<String, dynamic>>.from(
            adsList.whereType<Map>().map((e) => Map<String, dynamic>.from(e)),
          );
        }
      }
    } catch (_) {
      // Non-blocking fallback
    }
    return [];
  }

  /// Request unified ad decision from AdDecisionEngine (Peto internal auction vs External AdMob)
  Future<Map<String, dynamic>?> fetchUnifiedAdDecision({
    String placement = 'FEED',
    int? organicCount,
  }) async {
    try {
      final device = Platform.isAndroid ? 'ANDROID' : (Platform.isIOS ? 'IOS' : 'WEB');
      final response = await _dio.get(
        '/ads/decision',
        queryParameters: {
          'placement': placement,
          'device': device,
          'organicCount': ?organicCount,
        },
      );
      if (response.statusCode == 200 && response.data != null && response.data['hasAd'] == true) {
        return Map<String, dynamic>.from(response.data);
      }
    } catch (_) {
      // Non-blocking fallback
    }
    return null;
  }

  /// Track external ad network telemetry event
  Future<void> trackExternalAdEvent({
    required String eventType,
    required String provider,
    String? placement,
    String? creativeId,
    String? adUnitId,
    String? status,
    String? errorCode,
    int? latencyMs,
  }) async {
    try {
      final platform = Platform.isAndroid ? 'ANDROID' : (Platform.isIOS ? 'IOS' : 'WEB');
      await _dio.post(
        '/ads/events',
        data: {
          'eventType': eventType,
          'adSource': 'EXTERNAL',
          'provider': provider,
          'placement': placement ?? 'FEED',
          'platform': platform,
          'creativeId': creativeId,
          'adUnitId': adUnitId,
          'status': status ?? 'SUCCESS',
          'errorCode': errorCode,
          'latencyMs': latencyMs,
        },
      );
    } catch (_) {
      // Non-blocking
    }
  }

  /// Track ad impression
  Future<void> trackAdImpression(String campaignId, {String? creativeId}) async {
    try {
      await _dio.post(
        '/ads/$campaignId/impression',
        data: {'creativeId': creativeId},
      );
    } catch (_) {}
  }

  /// Track ad click
  Future<void> trackAdClick(String campaignId, {String? creativeId}) async {
    try {
      await _dio.post(
        '/ads/$campaignId/click',
        data: {'creativeId': creativeId},
      );
    } catch (_) {}
  }

  /// Track ad user feedback (hide, report, not interested)
  Future<void> trackAdFeedback(
    String campaignId, {
    required String action,
    String? reason,
    String? details,
    String? creativeId,
  }) async {
    try {
      await _dio.post(
        '/ads/$campaignId/feedback',
        data: {
          'action': action,
          'reason': reason,
          'details': details,
          'creativeId': creativeId,
        },
      );
    } catch (_) {}
  }

  /// Fetch all active compliance policies
  Future<List<PolicyModel>> fetchPublicPolicies() async {
    try {
      final response = await _dio.get('/policies');
      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic>? list = response.data['data'];
        if (list != null) {
          return list
              .whereType<Map<String, dynamic>>()
              .map((item) => PolicyModel.fromJson(item))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('Error fetching public policies: $e');
    }
    return [];
  }

  /// Fetch single policy by slug (e.g. 'terms-of-service', 'privacy-policy')
  Future<PolicyModel?> fetchPolicyBySlug(String slug) async {
    try {
      final response = await _dio.get('/policies/$slug');
      if (response.statusCode == 200 && response.data != null && response.data['data'] != null) {
        return PolicyModel.fromJson(Map<String, dynamic>.from(response.data['data']));
      }
    } catch (e) {
      debugPrint('Error fetching policy $slug: $e');
    }
    return null;
  }

  /// Get PDF download URL for policy
  String getPolicyPdfUrl(String slug) {
    final base = _dio.options.baseUrl.isNotEmpty ? _dio.options.baseUrl : defaultBaseUrl;
    return '$base/policies/$slug/pdf';
  }

  /// Change password for authenticated user
  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/change-password',
        data: {
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        },
      );
      if (response.data is Map<String, dynamic>) {
        return Map<String, dynamic>.from(response.data);
      }
      return {'success': true, 'message': 'Password updated successfully.'};
    } on DioException catch (e) {
      final data = e.response?.data;
      final msg = (data is Map && data['message'] != null)
          ? data['message'].toString()
          : (data is Map && data['error'] != null)
              ? data['error'].toString()
              : (e.message ?? 'Failed to update password');
      return {'success': false, 'message': msg};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Fetch verification status for authenticated user
  Future<Map<String, dynamic>> fetchVerificationStatus() async {
    try {
      final response = await _dio.get('/advertisers/verification/status');
      if (response.data is Map<String, dynamic>) {
        return Map<String, dynamic>.from(response.data);
      }
    } catch (e) {
      debugPrint('Error fetching verification status: $e');
    }
    return {'success': false, 'has_application': false};
  }

  /// Submit individual identity verification request with optional document
  Future<Map<String, dynamic>> submitIndividualVerification({
    required String legalName,
    required String country,
    required String documentType,
    required String documentNumber,
    String? filePath,
  }) async {
    try {
      final submitResponse = await _dio.post(
        '/advertisers/verification/submit',
        data: {
          'entity_type': 'INDIVIDUAL',
          'legal_name': legalName,
          'country': country,
          'document_type': documentType,
          'document_number': documentNumber,
        },
      );

      final appData = submitResponse.data;
      if (appData == null || appData['success'] != true) {
        return {
          'success': false,
          'message': appData?['error'] ?? 'Failed to submit verification request',
        };
      }

      final appId = appData['application']?['id']?.toString();

      if (filePath != null && filePath.isNotEmpty && appId != null) {
        final fileName = filePath.split(Platform.pathSeparator).last;
        final formData = FormData.fromMap({
          'applicationId': appId,
          'documentType': documentType,
          'documentNumber': documentNumber,
          'countryCode': country,
          'isFront': 'true',
          'document': await MultipartFile.fromFile(filePath, filename: fileName),
        });

        await _dio.post(
          '/advertisers/verification/documents',
          data: formData,
        );
      }

      return {
        'success': true,
        'message': 'Verification application submitted successfully.',
        'application': appData['application'],
      };
    } on DioException catch (e) {
      final data = e.response?.data;
      final msg = (data is Map && data['error'] != null)
          ? data['error'].toString()
          : (data is Map && data['message'] != null)
              ? data['message'].toString()
              : (e.message ?? 'Verification submission failed');
      return {'success': false, 'message': msg};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Get Google OAuth authorization URL from backend
  Future<String?> getGoogleAuthUrl({String? redirectUrl}) async {
    try {
      final response = await _dio.get(
        '/auth/google/url',
        queryParameters: redirectUrl != null ? {'redirect_to': redirectUrl} : null,
      );
      if (response.statusCode == 200 && response.data != null && response.data['url'] != null) {
        return response.data['url'].toString();
      }
    } catch (e) {
      debugPrint('Error getting Google auth URL: $e');
    }
    return null;
  }

  /// Synchronize Google session tokens with backend & auto-create profile if new
  Future<Map<String, dynamic>> syncGoogleAuth({
    required String token,
    String? refreshToken,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/google',
        data: {
          'token': token,
          'refreshToken': refreshToken,
        },
      );
      if (response.data is Map<String, dynamic>) {
        return Map<String, dynamic>.from(response.data);
      }
      return {'success': true, 'token': token, 'refreshToken': refreshToken};
    } on DioException catch (e) {
      final data = e.response?.data;
      final msg = (data is Map && data['message'] != null)
          ? data['message'].toString()
          : (e.message ?? 'Google authentication failed');
      return {'success': false, 'message': msg};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Exchange temporary 6-digit sync code for tokens and user profile
  Future<Map<String, dynamic>> exchangeGoogleCode(String code) async {
    try {
      final response = await _dio.post(
        '/auth/google/exchange-code',
        data: {'code': code.trim()},
      );
      if (response.data is Map<String, dynamic>) {
        return Map<String, dynamic>.from(response.data);
      }
      return {'success': false, 'message': 'Invalid response from server.'};
    } on DioException catch (e) {
      final data = e.response?.data;
      final msg = (data is Map && data['message'] != null)
          ? data['message'].toString()
          : (e.message ?? 'Failed to exchange code');
      return {'success': false, 'message': msg};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ==========================================
  // PET SYSTEM & SHOWCASE ENDPOINTS
  // ==========================================

  /// Fetch authenticated user's pets
  Future<List<Pet>> getMyPets() async {
    try {
      Response response;
      try {
        response = await _dio.get('/pets/my');
      } on DioException catch (e) {
        if (e.response?.statusCode == 404) {
          response = await _dio.get('/pet/my');
        } else {
          rethrow;
        }
      }

      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic>? list = response.data['data'];
        if (list != null) {
          return list
              .whereType<Map>()
              .map((p) => Pet.fromJson(Map<String, dynamic>.from(p)))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('Error getting my pets: $e');
    }
    return [];
  }

  /// Fetch pets showcased on a user profile (respecting visibility permissions)
  Future<List<Pet>> getUserPets(String userId) async {
    try {
      Response response;
      try {
        response = await _dio.get('/pets/user/$userId');
      } on DioException catch (e) {
        if (e.response?.statusCode == 404) {
          response = await _dio.get('/pet/user/$userId');
        } else {
          rethrow;
        }
      }

      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic>? list = response.data['data'];
        if (list != null) {
          return list
              .whereType<Map>()
              .map((p) => Pet.fromJson(Map<String, dynamic>.from(p)))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('Error getting user pets: $e');
    }
    return [];
  }

  /// Fetch detailed pet showcase by ID (with server-side visibility check)
  Future<Pet?> getPetById(String petId) async {
    try {
      Response response;
      try {
        response = await _dio.get('/pets/$petId');
      } on DioException catch (e) {
        if (e.response?.statusCode == 404) {
          response = await _dio.get('/pet/$petId');
        } else {
          rethrow;
        }
      }

      if (response.statusCode == 200 && response.data != null && response.data['data'] != null) {
        return Pet.fromJson(Map<String, dynamic>.from(response.data['data']));
      }
    } catch (e) {
      debugPrint('Error getting pet details: $e');
    }
    return null;
  }

  /// Create a new pet profile (with fallback between /pets and /pet)
  Future<Map<String, dynamic>> createPet(Map<String, dynamic> petData) async {
    try {
      Response response;
      try {
        response = await _dio.post('/pets', data: petData);
      } on DioException catch (e) {
        if (e.response?.statusCode == 404) {
          response = await _dio.post('/pet', data: petData);
        } else {
          rethrow;
        }
      }

      if (response.data is Map<String, dynamic>) {
        return Map<String, dynamic>.from(response.data);
      }
      return {'success': true};
    } on DioException catch (e) {
      final data = e.response?.data;
      final msg = (data is Map && data['message'] != null)
          ? data['message'].toString()
          : (e.message ?? 'Failed to add pet');
      return {'success': false, 'message': msg};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Update pet profile details
  Future<Map<String, dynamic>> updatePet(String petId, Map<String, dynamic> petData) async {
    try {
      Response response;
      try {
        response = await _dio.patch('/pets/$petId', data: petData);
      } on DioException catch (e) {
        if (e.response?.statusCode == 404) {
          response = await _dio.patch('/pet/$petId', data: petData);
        } else {
          rethrow;
        }
      }

      if (response.data is Map<String, dynamic>) {
        return Map<String, dynamic>.from(response.data);
      }
      return {'success': true};
    } on DioException catch (e) {
      final data = e.response?.data;
      final msg = (data is Map && data['message'] != null)
          ? data['message'].toString()
          : (e.message ?? 'Failed to update pet');
      return {'success': false, 'message': msg};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Update pet visibility (PUBLIC, CONNECTIONS, PRIVATE)
  Future<bool> updatePetVisibility(String petId, String visibility) async {
    try {
      Response response;
      try {
        response = await _dio.patch(
          '/pets/$petId/visibility',
          data: {'visibility': visibility},
        );
      } on DioException catch (e) {
        if (e.response?.statusCode == 404) {
          response = await _dio.patch(
            '/pet/$petId/visibility',
            data: {'visibility': visibility},
          );
        } else {
          rethrow;
        }
      }
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error updating pet visibility: $e');
      return false;
    }
  }

  /// Delete pet profile
  Future<bool> deletePet(String petId) async {
    try {
      Response response;
      try {
        response = await _dio.delete('/pets/$petId');
      } on DioException catch (e) {
        if (e.response?.statusCode == 404) {
          response = await _dio.delete('/pet/$petId');
        } else {
          rethrow;
        }
      }
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error deleting pet: $e');
      return false;
    }
  }

  /// Fetch pending pet parent invitations for current user
  Future<List<PetPendingInvite>> getPendingPetInvites() async {
    try {
      final response = await _dio.get('/pets/invites/pending');
      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic>? list = response.data['data'];
        if (list != null) {
          return list
              .whereType<Map>()
              .map((inv) => PetPendingInvite.fromJson(Map<String, dynamic>.from(inv)))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('Error getting pending pet invites: $e');
    }
    return [];
  }

  /// Respond to a pet parent invitation (Accept or Decline)
  Future<bool> respondPetInvite(String inviteId, {String? petId, required bool accept}) async {
    try {
      Response response;
      if (petId != null && petId.isNotEmpty) {
        response = await _dio.post(
          '/pets/$petId/parents/respond',
          data: {'accept': accept, 'invite_id': inviteId},
        );
      } else {
        response = await _dio.post(
          '/pets/invites/$inviteId/respond',
          data: {'accept': accept},
        );
      }
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error responding to pet invite: $e');
      return false;
    }
  }

  /// Invite a user to be a pet parent / co-owner
  Future<Map<String, dynamic>> invitePetParent(
    String petId, {
    required String invitee,
    required String relationship,
    List<String>? permissions,
  }) async {
    try {
      final response = await _dio.post(
        '/pets/$petId/parents/invite',
        data: {
          'invitee': invitee,
          'relationship': relationship,
          if (permissions != null) 'permissions': permissions,
        },
      );
      if (response.data is Map<String, dynamic>) {
        return Map<String, dynamic>.from(response.data);
      }
      return {'success': true};
    } on DioException catch (e) {
      final data = e.response?.data;
      final msg = (data is Map && data['message'] != null)
          ? data['message'].toString()
          : (e.message ?? 'Failed to send invite');
      return {'success': false, 'message': msg};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Remove an authorized parent from a pet
  Future<bool> removePetParent(String petId, String parentUserId) async {
    try {
      final response = await _dio.delete('/pets/$petId/parents/$parentUserId');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error removing pet parent: $e');
      return false;
    }
  }

  /// Attach an uploaded media item to a pet's gallery or profile
  Future<bool> addPetMedia(
    String petId, {
    required String mediaId,
    String role = 'GALLERY',
    String? caption,
  }) async {
    try {
      final response = await _dio.post(
        '/pets/$petId/media',
        data: {
          'media_id': mediaId,
          'role': role,
          if (caption != null) 'caption': caption,
        },
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('Error adding pet media: $e');
      return false;
    }
  }

  /// Delete a media item from a pet's showcase
  Future<bool> deletePetMedia(String petId, String mediaId) async {
    try {
      final response = await _dio.delete('/pets/$petId/media/$mediaId');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error deleting pet media: $e');
      return false;
    }
  }

  /// Fetch social posts for a specific pet
  Future<List<dynamic>> getPetPosts(String petId) async {
    try {
      final response = await _dio.get('/pets/$petId/posts');
      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic>? list = response.data['posts'] ?? response.data['data'];
        if (list != null) {
          return list;
        }
      }
    } catch (e) {
      debugPrint('Error getting pet posts: $e');
    }
    return [];
  }
}

class MediaUploadResult {
  final bool success;
  final String? mediaUrl;
  final String? mediaId;
  final String? errorMessage;

  MediaUploadResult({
    required this.success,
    this.mediaUrl,
    this.mediaId,
    this.errorMessage,
  });
}

