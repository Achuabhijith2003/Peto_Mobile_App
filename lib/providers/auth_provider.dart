import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:app_links/app_links.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../main.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  User? _user;
  bool _isLoading = true;
  String? _errorMessage;

  User? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  AuthProvider() {
    checkAuthStatus();
    _initDeepLinks();
  }

  void _initDeepLinks() {
    try {
      _appLinks = AppLinks();
      _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
        _handleDeepLink(uri);
      });
      _appLinks.getInitialLink().then((uri) {
        if (uri != null) _handleDeepLink(uri);
      });
    } catch (e) {
      debugPrint('Deep links init error: $e');
    }
  }

  void _handleDeepLink(Uri uri) {
    debugPrint('Received incoming deep link: $uri');
    if (uri.scheme == 'peto' && (uri.host == 'auth-callback' || uri.path.contains('auth-callback'))) {
      final token = uri.queryParameters['token'];
      final refreshToken = uri.queryParameters['refreshToken'];
      if (token != null && token.isNotEmpty) {
        loginWithTokens(token: token, refreshToken: refreshToken).then((success) {
          if (success) {
            PetoUserApp.navigatorKey.currentState?.popUntil((route) => route.isFirst);
          }
        });
      }
    }
  }

  List<BusinessModel> _managedBusinesses = [];
  ActiveIdentityModel? _activeIdentity;

  List<BusinessModel> get managedBusinesses => _managedBusinesses;
  ActiveIdentityModel get activeIdentity => _activeIdentity ?? _getPersonalIdentity();
  bool get isActingAsBusiness => activeIdentity.isBusiness;

  ActiveIdentityModel _getPersonalIdentity() {
    return ActiveIdentityModel(
      type: 'PERSON',
      id: _user?.id ?? '',
      name: _user?.displayName ?? 'Personal Profile',
      avatarUrl: _user?.avatarUrl,
      isVerified: _user?.isVerified ?? false,
    );
  }

  Future<void> fetchManagedBusinesses() async {
    if (!isAuthenticated) {
      _managedBusinesses = [];
      _activeIdentity = _getPersonalIdentity();
      notifyListeners();
      return;
    }
    try {
      final list = await _apiService.getMyBusinesses();
      _managedBusinesses = list.map((b) => BusinessModel.fromJson(Map<String, dynamic>.from(b))).toList();

      final savedType = await _storageService.getString('active_acting_identity_type');
      final savedId = await _storageService.getString('active_acting_identity_id');

      if (savedType == 'BUSINESS' && savedId != null) {
        final match = _managedBusinesses.firstWhere(
          (b) => b.id == savedId,
          orElse: () => BusinessModel(id: '', name: '', legalName: '', countryCode: ''),
        );
        if (match.id.isNotEmpty) {
          _activeIdentity = ActiveIdentityModel(
            type: 'BUSINESS',
            id: match.id,
            name: match.name,
            avatarUrl: match.avatarUrl,
            isVerified: match.isVerified,
            role: match.role,
            business: match,
          );
          notifyListeners();
          return;
        }
      }
      _activeIdentity = _getPersonalIdentity();
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching managed businesses: $e');
    }
  }

  Future<void> switchIdentity(String type, {String? businessId}) async {
    if (type == 'BUSINESS' && businessId != null) {
      final match = _managedBusinesses.firstWhere(
        (b) => b.id == businessId,
        orElse: () => BusinessModel(id: '', name: '', legalName: '', countryCode: ''),
      );
      if (match.id.isNotEmpty) {
        _activeIdentity = ActiveIdentityModel(
          type: 'BUSINESS',
          id: match.id,
          name: match.name,
          avatarUrl: match.avatarUrl,
          isVerified: match.isVerified,
          role: match.role,
          business: match,
        );
        await _storageService.setString('active_acting_identity_type', 'BUSINESS');
        await _storageService.setString('active_acting_identity_id', match.id);
        notifyListeners();
        return;
      }
    }

    _activeIdentity = _getPersonalIdentity();
    await _storageService.setString('active_acting_identity_type', 'PERSON');
    await _storageService.remove('active_acting_identity_id');
    notifyListeners();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  Future<void> checkAuthStatus() async {
    _isLoading = true;
    notifyListeners();

    try {
      final token = await _storageService.getToken();
      if (token != null && token.isNotEmpty) {
        final response = await _apiService.getCurrentUser();
        if (response.statusCode == 200 && response.data != null) {
          final userData = response.data['user'] ?? response.data;
          _user = User.fromJson(userData);
          await _storageService.saveUserData(jsonEncode(_user!.toJson()));
          PushNotificationService().syncTokenWithBackend();
          await fetchManagedBusinesses();
        }
      }
    } catch (e) {
      _user = null;
      _managedBusinesses = [];
      _activeIdentity = null;
      await _storageService.clearAuthData();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  String _humanizeAuthError(String? rawMsg) {
    if (rawMsg == null || rawMsg.trim().isEmpty) {
      return 'An unexpected error occurred. Please try again.';
    }
    final lower = rawMsg.toLowerCase();
    if (lower.contains('already registered') || lower.contains('user already exists') || lower.contains('email already')) {
      return 'An account with this email address already exists. Please sign in instead.';
    }
    if (lower.contains('username') && (lower.contains('taken') || lower.contains('already'))) {
      return 'This username is already taken. Please choose another username.';
    }
    if (lower.contains('username must be') || lower.contains('invalid username')) {
      return 'Username must be 3-20 characters long and contain only lowercase letters, numbers, and underscores.';
    }
    if (lower.contains('password') && (lower.contains('8 characters') || lower.contains('short') || lower.contains('least'))) {
      return 'Password must be at least 8 characters long.';
    }
    if (lower.contains('13 years') || lower.contains('age')) {
      return 'You must confirm that you are at least 13 years old to use Peto.';
    }
    if (lower.contains('terms') || lower.contains('privacy')) {
      return 'You must affirmatively accept Peto\'s Terms of Service and Privacy Policy to continue.';
    }
    if (lower.contains('rate limit') || lower.contains('too many requests')) {
      return 'Too many attempts. Please wait a moment and try again.';
    }
    if (lower.contains('invalid email') || lower.contains('email is invalid')) {
      return 'Please enter a valid email address.';
    }
    return rawMsg;
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.login(email, password);
      if (response.statusCode == 200 || response.statusCode == 201) {
        final token = response.data['token'];
        final refreshToken = response.data['refreshToken'];
        final userData = response.data['user'] ?? response.data;

        if (token != null) {
          await _storageService.saveToken(token);
          if (refreshToken != null) {
            await _storageService.saveRefreshToken(refreshToken);
          }

          _user = User.fromJson(userData);
          await _storageService.saveUserData(jsonEncode(_user!.toJson()));
          PushNotificationService().syncTokenWithBackend();
          await fetchManagedBusinesses();
          _isLoading = false;
          notifyListeners();
          return true;
        }
      }
      _errorMessage = _humanizeAuthError(response.data['message']?.toString() ?? 'Login failed');
    } catch (e) {
      if (e is DioException) {
        final serverMsg = e.response?.data is Map
            ? (e.response?.data['message']?.toString() ?? e.response?.data['error']?.toString())
            : null;
        _errorMessage = _humanizeAuthError(serverMsg ?? 'Invalid email or password');
      } else {
        _errorMessage = 'Invalid email or password';
      }
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  /// Log in directly using session tokens (from Google OAuth or deep link)
  Future<bool> loginWithTokens({
    required String token,
    String? refreshToken,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _storageService.saveToken(token);
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await _storageService.saveRefreshToken(refreshToken);
      }

      // Sync user with backend to ensure profile exists and load current user
      final syncRes = await _apiService.syncGoogleAuth(token: token, refreshToken: refreshToken);
      if (syncRes['user'] != null) {
        final userData = syncRes['user'];
        _user = User.fromJson(userData);
        await _storageService.saveUserData(jsonEncode(_user!.toJson()));
      } else {
        // Fallback: fetch current user via /users/me
        final meRes = await _apiService.getCurrentUser();
        if (meRes.statusCode == 200 && meRes.data != null) {
          final userData = meRes.data['user'] ?? meRes.data;
          _user = User.fromJson(userData);
          await _storageService.saveUserData(jsonEncode(_user!.toJson()));
        }
      }

      PushNotificationService().syncTokenWithBackend();
      await fetchManagedBusinesses();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error logging in with tokens: $e');
      _errorMessage = 'Failed to complete authentication.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Log in using a 6-digit sync code from the web callback screen
  Future<bool> loginWithGoogleCode(String code) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _apiService.exchangeGoogleCode(code);
      if (res['success'] == true && res['token'] != null) {
        return await loginWithTokens(
          token: res['token'],
          refreshToken: res['refreshToken'],
        );
      } else {
        _errorMessage = res['message']?.toString() ?? 'Invalid code entered';
      }
    } catch (e) {
      _errorMessage = 'Failed to verify code. Please try again.';
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> register({
    required String email,
    required String password,
    String? username,
    String? firstName,
    String? lastName,
    String? fullName,
    bool acceptedTerms = true,
    bool ageConfirmed = true,
    bool marketingConsent = false,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.register({
        'email': email,
        'password': password,
        'username': username,
        'firstName': firstName,
        'lastName': lastName,
        'fullName': fullName,
        'acceptedTerms': acceptedTerms,
        'ageConfirmed': ageConfirmed,
        'marketingConsent': marketingConsent,
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        final token = response.data['token'] ?? response.data['session']?['access_token'];
        final refreshToken = response.data['refreshToken'] ?? response.data['session']?['refresh_token'];
        final userData = response.data['user'] ?? response.data;

        if (token != null) {
          await _storageService.saveToken(token);
          if (refreshToken != null) {
            await _storageService.saveRefreshToken(refreshToken);
          }

          if (userData != null && userData is Map<String, dynamic>) {
            _user = User.fromJson(userData);
            await _storageService.saveUserData(jsonEncode(_user!.toJson()));
            PushNotificationService().syncTokenWithBackend();
          }
          _isLoading = false;
          notifyListeners();
          return true;
        }
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _errorMessage = _humanizeAuthError(response.data['message']);
    } catch (e) {
      debugPrint('Register error: $e');
      if (e is DioException) {
        final serverMsg = e.response?.data is Map
            ? (e.response?.data['message']?.toString() ?? e.response?.data['error']?.toString())
            : null;
        if (serverMsg != null && serverMsg.isNotEmpty) {
          _errorMessage = _humanizeAuthError(serverMsg);
        } else if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout) {
          _errorMessage = 'Connection timed out. Please check your internet connection.';
        } else if (e.type == DioExceptionType.connectionError) {
          _errorMessage = 'Unable to connect to Peto servers. Please check your internet connection.';
        } else {
          _errorMessage = 'Unable to complete registration. Please check your details and try again.';
        }
      } else {
        _errorMessage = e.toString();
      }
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<void> logout() async {
    await PushNotificationService().unregisterToken();
    await _storageService.clearAuthData();
    _user = null;
    notifyListeners();
  }

  Future<bool> createProfile(Map<String, dynamic> data) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.createProfile(data);
      if (response.statusCode == 200 || response.statusCode == 201) {
        await refreshUser();
        return true;
      }
      _errorMessage = response.data['message'] ?? 'Failed to create profile';
    } catch (e) {
      debugPrint('Create profile error: $e');
      _errorMessage = 'Failed to create profile. Please check your inputs.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return false;
  }

  Future<void> refreshUser() async {
    try {
      final response = await _apiService.getCurrentUser();
      if (response.statusCode == 200 && response.data != null) {
        final userData = response.data['user'] is Map<String, dynamic>
            ? Map<String, dynamic>.from(response.data['user'])
            : Map<String, dynamic>.from(response.data);

        if (response.data['profile'] != null) {
          userData['profile'] = response.data['profile'];
        }

        _user = User.fromJson(userData);
        await _storageService.saveUserData(jsonEncode(_user!.toJson()));
        await fetchManagedBusinesses();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Refresh user error: $e');
    }
  }

  Future<bool> updateUserProfile(Map<String, dynamic> data) async {
    try {
      final avatarUrl = data['avatar_url']?.toString() ?? data['avatarUrl']?.toString();
      final coverUrl = data['cover_url']?.toString() ?? data['coverUrl']?.toString();
      final fullName = data['full_name']?.toString() ?? data['fullName']?.toString();
      final username = data['username']?.toString();

      if (_user != null) {
        _user = _user!.copyWith(
          avatarUrl: (avatarUrl != null && avatarUrl.isNotEmpty) ? avatarUrl : _user!.avatarUrl,
          coverUrl: (coverUrl != null && coverUrl.isNotEmpty) ? coverUrl : _user!.coverUrl,
          fullName: (fullName != null && fullName.isNotEmpty) ? fullName : _user!.fullName,
          username: (username != null && username.isNotEmpty) ? username : _user!.username,
        );
        await _storageService.saveUserData(jsonEncode(_user!.toJson()));
        notifyListeners();
      }

      final response = await _apiService.updateProfile(data);
      if (response.statusCode == 200 || response.statusCode == 201) {
        await refreshUser();
        return true;
      }
    } catch (e) {
      debugPrint('Update profile error: $e');
    }
    return false;
  }

  Future<void> updateAvatarUrl(String url) async {
    if (_user != null) {
      _user = _user!.copyWith(avatarUrl: url);
      await _storageService.saveUserData(jsonEncode(_user!.toJson()));
      notifyListeners();
    }
    await refreshUser();
  }

  Future<void> updateCoverUrl(String url) async {
    if (_user != null) {
      _user = _user!.copyWith(coverUrl: url);
      await _storageService.saveUserData(jsonEncode(_user!.toJson()));
      notifyListeners();
    }
    await refreshUser();
  }

  Future<Map<String, dynamic>> forgotPassword(String email, {String? redirectTo}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.forgotPassword(email.trim(), redirectTo: redirectTo);
      if (response.statusCode == 200 || response.statusCode == 201) {
        final message = response.data['message'] ??
            'Password reset link has been sent to your email address.';
        return {'success': true, 'message': message};
      }
      final msg = response.data['message'] ?? 'Failed to send reset email';
      _errorMessage = msg;
      return {'success': false, 'message': msg};
    } catch (e) {
      debugPrint('Forgot password error: $e');
      String msg = 'Failed to send reset link. Please check your email.';
      if (e is DioException && e.response?.data != null && e.response?.data['message'] != null) {
        msg = e.response!.data['message'].toString();
      }
      _errorMessage = msg;
      return {'success': false, 'message': msg};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
