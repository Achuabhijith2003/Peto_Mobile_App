import 'package:flutter/material.dart';
import '../models/reel_model.dart';
import '../services/api_service.dart';

class ReelProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<Reel> _reels = [];
  bool _isLoading = false;

  List<Reel> get reels => _reels;
  bool get isLoading => _isLoading;

  Future<void> fetchReels() async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiService.getReels();
      if (response.statusCode == 200 && response.data != null) {
        final List rawList = response.data['reels'] ?? response.data['posts'] ?? response.data['data'] ?? response.data ?? [];
        _reels = rawList.map((item) => Reel.fromJson(item)).toList();
      } else {
        _reels = [];
      }
    } catch (e) {
      debugPrint('Fetch reels API error: $e');
      _reels = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleLike(String reelId) async {
    final index = _reels.indexWhere((r) => r.id == reelId);
    if (index != -1) {
      final reel = _reels[index];
      final newLiked = !reel.isLiked;
      final newCount = newLiked ? reel.likesCount + 1 : (reel.likesCount > 0 ? reel.likesCount - 1 : 0);

      _reels[index] = reel.copyWith(isLiked: newLiked, likesCount: newCount);
      notifyListeners();

      try {
        if (newLiked) {
          await _apiService.likePost(reelId);
        } else {
          await _apiService.unlikePost(reelId);
        }
      } catch (e) {
        debugPrint('Reel like API error: $e');
      }
    }
  }

  Future<void> toggleBookmark(String reelId) async {
    final index = _reels.indexWhere((r) => r.id == reelId);
    if (index != -1) {
      final reel = _reels[index];
      final newBookmarked = !reel.isBookmarked;
      _reels[index] = reel.copyWith(isBookmarked: newBookmarked);
      notifyListeners();

      try {
        if (newBookmarked) {
          await _apiService.bookmarkPost(reelId);
        } else {
          await _apiService.removeBookmark(reelId);
        }
      } catch (e) {
        debugPrint('Reel bookmark API error: $e');
      }
    }
  }
}
