import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();

  User? _user;
  bool _isLoading = true;
  String? _errorMessage;

  User? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  AuthProvider() {
    checkAuthStatus();
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
        }
      }
    } catch (e) {
      _user = null;
      await _storageService.clearAuthData();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
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
          _isLoading = false;
          notifyListeners();
          return true;
        }
      }
      _errorMessage = response.data['message'] ?? 'Login failed';
    } catch (e) {
      _errorMessage = 'Invalid email or password';
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> register({
    required String username,
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.register({
        'username': username,
        'email': email,
        'password': password,
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
          }
          _isLoading = false;
          notifyListeners();
          return true;
        }
        // If session token was not returned (e.g. signup created user but requires login or next step), still consider signup successful
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _errorMessage = response.data['message'] ?? 'Registration failed';
    } catch (e) {
      debugPrint('Register error: $e');
      _errorMessage = 'Error creating account. Please check your details and try again.';
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<void> logout() async {
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
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Refresh user error: $e');
    }
  }

  Future<bool> updateUserProfile(Map<String, dynamic> data) async {
    try {
      final response = await _apiService.updateProfile(data);
      if (response.statusCode == 200) {
        await refreshUser();
        return true;
      }
    } catch (e) {
      debugPrint('Update profile error: $e');
    }
    return false;
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
