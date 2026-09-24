import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/auth_prompt_bottom_sheet.dart';
import '../../widgets/skeleton_loader.dart';
import '../../widgets/follow_button.dart';
import 'public_profile_screen.dart';

class FollowersFollowingScreen extends StatefulWidget {
  final String userId;
  final String username;
  final int initialIndex;

  const FollowersFollowingScreen({
    super.key,
    required this.userId,
    required this.username,
    this.initialIndex = 0,
  });

  @override
  State<FollowersFollowingScreen> createState() => _FollowersFollowingScreenState();
}

class _FollowersFollowingScreenState extends State<FollowersFollowingScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  List<User> _followers = [];
  List<User> _following = [];
  final Set<String> _loadingUserIds = {};
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialIndex.clamp(0, 1),
    );
    _loadFollowData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFollowData() async {
    setState(() => _isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.user?.id;
    final currentUsername = authProvider.user?.username;
    final isSelf = currentUserId != null &&
        (currentUserId == widget.userId || currentUsername == widget.username);

    try {
      dynamic followersRes;
      dynamic followingRes;

      try {
        followersRes = await _apiService.getFollowers(widget.userId);
      } catch (e) {
        debugPrint('Get followers error: $e');
      }

      try {
        followingRes = await _apiService.getFollowing(widget.userId);
      } catch (e) {
        debugPrint('Get following error: $e');
      }

      List<User> parsedFollowers = [];
      if (followersRes != null && followersRes.statusCode == 200 && followersRes.data != null) {
        final raw = followersRes.data['data'] ?? followersRes.data['followers'] ?? [];
        if (raw is List) {
          parsedFollowers = raw.map((item) {
            final profile = item['follower'] ?? item['profiles'] ?? item['user'] ?? item;
            final userMap = profile is Map<String, dynamic>
                ? Map<String, dynamic>.from(profile)
                : <String, dynamic>{};
            if (item is Map<String, dynamic>) {
              if (item.containsKey('is_following')) userMap['is_following'] = item['is_following'];
              if (item.containsKey('isFollowing')) userMap['isFollowing'] = item['isFollowing'];
            }
            return User.fromJson(userMap);
          }).toList();
        }
      }

      List<User> parsedFollowing = [];
      if (followingRes != null && followingRes.statusCode == 200 && followingRes.data != null) {
        final raw = followingRes.data['data'] ?? followingRes.data['following'] ?? [];
        if (raw is List) {
          parsedFollowing = raw.map((item) {
            final profile = item['following'] ?? item['profiles'] ?? item['user'] ?? item;
            final userMap = profile is Map<String, dynamic>
                ? Map<String, dynamic>.from(profile)
                : <String, dynamic>{};
            if (item is Map<String, dynamic>) {
              if (item.containsKey('is_following')) userMap['is_following'] = item['is_following'];
              if (item.containsKey('isFollowing')) userMap['isFollowing'] = item['isFollowing'];
            }
            if (isSelf) {
              userMap['is_following'] = true;
              userMap['isFollowing'] = true;
            }
            return User.fromJson(userMap);
          }).toList();
        }
      }

      // If viewing another user's profile, ensure follower/following lists accurately reflect
      // whether the current logged-in user follows them
      if (!isSelf && authProvider.isAuthenticated && currentUserId != null) {
        try {
          final myFollowingRes = await _apiService.getFollowing(currentUserId);
          if (myFollowingRes.statusCode == 200 && myFollowingRes.data != null) {
            final raw = myFollowingRes.data['data'] ?? myFollowingRes.data['following'] ?? [];
            if (raw is List) {
              final myFollowingIds = raw.map((item) {
                final p = item['following'] ?? item['profiles'] ?? item['user'] ?? item;
                return p['id']?.toString();
              }).whereType<String>().toSet();

              parsedFollowers = parsedFollowers.map((u) {
                return u.copyWith(isFollowing: myFollowingIds.contains(u.id));
              }).toList();

              parsedFollowing = parsedFollowing.map((u) {
                return u.copyWith(isFollowing: myFollowingIds.contains(u.id));
              }).toList();
            }
          }
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _followers = parsedFollowers;
          _following = parsedFollowing;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading follow data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleFollow(User user, bool isFromFollowingTab) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated) {
      AuthPromptBottomSheet.show(context, actionTitle: 'Follow User');
      return;
    }

    if (_loadingUserIds.contains(user.id)) return;

    final newFollowState = !user.isFollowing;

    setState(() {
      _loadingUserIds.add(user.id);
      final fIdx = _followers.indexWhere((u) => u.id == user.id);
      if (fIdx != -1) {
        _followers[fIdx] = _followers[fIdx].copyWith(isFollowing: newFollowState);
      }
      final flIdx = _following.indexWhere((u) => u.id == user.id);
      if (flIdx != -1) {
        _following[flIdx] = _following[flIdx].copyWith(isFollowing: newFollowState);
      }
    });

    try {
      if (newFollowState) {
        await _apiService.followUser(user.id);
      } else {
        await _apiService.unfollowUser(user.id);
      }
    } catch (e) {
      debugPrint('Follow toggle error: $e');
      final errStr = e.toString().toLowerCase();
      if (newFollowState && errStr.contains('already following')) {
        return;
      }
      if (!newFollowState && errStr.contains('not following')) {
        return;
      }
      if (mounted) {
        setState(() {
          final fIdx = _followers.indexWhere((u) => u.id == user.id);
          if (fIdx != -1) {
            _followers[fIdx] = _followers[fIdx].copyWith(isFollowing: !newFollowState);
          }
          final flIdx = _following.indexWhere((u) => u.id == user.id);
          if (flIdx != -1) {
            _following[flIdx] = _following[flIdx].copyWith(isFollowing: !newFollowState);
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingUserIds.remove(user.id);
        });
      }
    }
  }

  List<User> _filterUsers(List<User> list) {
    if (_searchQuery.trim().isEmpty) return list;
    final q = _searchQuery.trim().toLowerCase();
    return list.where((u) {
      final name = u.displayName.toLowerCase();
      final uname = u.username.toLowerCase();
      return name.contains(q) || uname.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '@${widget.username}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.outline,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: [
            Tab(text: '${_followers.length} Followers'),
            Tab(text: '${_following.length} Following'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search Input Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Search followers or following...',
                hintStyle: const TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
                prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.outline),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18, color: AppColors.outline),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.surfaceContainerLow,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: AppColors.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
              ),
            ),
          ),

          const Divider(height: 1),

          // Tab Views
          Expanded(
            child: _isLoading
                ? const UserListSkeleton(itemCount: 8)
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildUserList(_filterUsers(_followers), isFollowersTab: true),
                      _buildUserList(_filterUsers(_following), isFollowersTab: false),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserList(List<User> users, {required bool isFollowersTab}) {
    if (users.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isFollowersTab ? Icons.people_outline : Icons.person_add_alt,
                size: 52,
                color: AppColors.outline.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 12),
              Text(
                _searchQuery.isNotEmpty
                    ? 'No matches found for "$_searchQuery"'
                    : (isFollowersTab ? 'No followers yet' : 'Not following anyone yet'),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFollowData,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: users.length,
        separatorBuilder: (_, _) => const SizedBox(height: 4),
        itemBuilder: (context, index) {
          final user = users[index];
          return _buildUserTile(user, isFollowersTab: isFollowersTab);
        },
      ),
    );
  }

  Widget _buildUserTile(User user, {required bool isFollowersTab}) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isSelf = authProvider.user?.id == user.id;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: AppColors.outlineVariant.withValues(alpha: 0.25),
        ),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PublicProfileScreen(
                userId: user.id,
                initialUser: user,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.primaryFixed,
                backgroundImage: (user.avatarUrl != null && user.avatarUrl!.isNotEmpty)
                    ? CachedNetworkImageProvider(user.avatarUrl!)
                    : null,
                child: (user.avatarUrl == null || user.avatarUrl!.isEmpty)
                    ? const Icon(Icons.person, color: AppColors.primary, size: 22)
                    : null,
              ),
              const SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.onSurface,
                      ),
                    ),
                    Text(
                      '@${user.username}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              // Action Button
              if (!isSelf)
                FollowButton(
                  isFollowing: user.isFollowing,
                  isLoading: _loadingUserIds.contains(user.id),
                  isCompact: true,
                  onPressed: () => _toggleFollow(user, !isFollowersTab),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
