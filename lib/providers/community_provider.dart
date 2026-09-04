import 'package:flutter/material.dart';
import '../models/community_model.dart';
import '../services/api_service.dart';

class CommunityProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<Community> _communities = [];
  bool _isLoading = false;
  String _selectedCategory = 'All';
  String _searchQuery = '';
  String _activeSort = 'popular'; // popular, new, joined

  String? _error;

  List<Community> get communities => _communities;
  bool get isLoading => _isLoading;
  String get selectedCategory => _selectedCategory;
  String get searchQuery => _searchQuery;
  String get activeSort => _activeSort;
  String get selectedSort => _activeSort;
  String? get error => _error;

  void setCategory(String category) {
    if (_selectedCategory == category) return;
    _selectedCategory = category;
    notifyListeners();
    fetchCommunities();
  }

  void setSort(String sort) {
    if (_activeSort == sort) return;
    _activeSort = sort;
    notifyListeners();
    fetchCommunities();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
    fetchCommunities();
  }

  Future<void> fetchCommunities() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.getCommunities(
        category: _selectedCategory,
        search: _searchQuery,
        sort: _activeSort,
      );

      if (response.statusCode == 200 && response.data != null) {
        final rawData = response.data['data'] ?? response.data;
        final List rawList = rawData is Map<String, dynamic>
            ? (rawData['communities'] ?? [])
            : (response.data['communities'] ?? (rawData is List ? rawData : []));

        _communities = rawList
            .whereType<Map<String, dynamic>>()
            .map((item) => Community.fromJson(item))
            .toList();
      } else {
        _communities = [];
      }
    } catch (e) {
      debugPrint('Fetch communities API error: $e');
      _error = 'Failed to load communities. Please check your connection.';
      _communities = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> toggleJoin(String communityId) async {
    final index = _communities.indexWhere((c) => c.id == communityId);
    if (index == -1) return false;

    final comm = _communities[index];
    final newJoined = !comm.isJoined;
    final newCount = newJoined ? comm.memberCount + 1 : (comm.memberCount > 0 ? comm.memberCount - 1 : 0);

    _communities[index] = comm.copyWith(isJoined: newJoined, memberCount: newCount);
    notifyListeners();

    try {
      if (newJoined) {
        await _apiService.joinCommunity(communityId);
      } else {
        await _apiService.leaveCommunity(communityId);
      }
      return newJoined;
    } catch (e) {
      debugPrint('Toggle community join API error: $e');
      // Revert on failure
      _communities[index] = comm;
      notifyListeners();
      return comm.isJoined;
    }
  }

  Future<Community?> createCommunity(Map<String, dynamic> data) async {
    try {
      final response = await _apiService.createCommunity(data);
      if (response.statusCode == 200 || response.statusCode == 201) {
        final commData = response.data['data'] ?? response.data;
        if (commData != null && commData is Map<String, dynamic>) {
          final newComm = Community.fromJson(commData);
          _communities.insert(0, newComm);
          notifyListeners();
          return newComm;
        }
      }
    } catch (e) {
      debugPrint('Create community error: $e');
    }
    return null;
  }

  void updateCommunityLocally(Community updated) {
    final index = _communities.indexWhere((c) => c.id == updated.id);
    if (index != -1) {
      _communities[index] = updated;
      notifyListeners();
    }
  }
}
