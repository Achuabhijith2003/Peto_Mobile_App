import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/post_model.dart';
import '../../models/user_model.dart';
import '../../models/community_model.dart';
import '../../services/api_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/post_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/post_card.dart';
import '../../widgets/community_card.dart';
import '../../widgets/comments_bottom_sheet.dart';
import '../../widgets/auth_prompt_bottom_sheet.dart';
import '../community/community_detail_screen.dart';
import '../profile/public_profile_screen.dart';
import '../../widgets/skeleton_loader.dart';
import '../../widgets/follow_button.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final ApiService _apiService = ApiService();

  Timer? _debounceTimer;
  bool _isLoading = false;
  bool _hasSearched = false;

  List<Post> _posts = [];
  List<User> _users = [];
  List<Community> _communities = [];

  final List<String> _trendingTags = [
    'GoldenRetriever',
    'KittenCare',
    'VetTips',
    'DogTraining',
    'PetAdoption',
    'Puppy',
    'CatLovers',
    'Rescue',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String text) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      if (text.trim().isNotEmpty) {
        _performSearch(text.trim());
      } else {
        setState(() {
          _posts = [];
          _users = [];
          _communities = [];
          _hasSearched = false;
          _isLoading = false;
        });
      }
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    try {
      final results = await Future.wait([
        _apiService.searchPosts(query).catchError((e) {
          debugPrint('Search posts error: $e');
          return Response(requestOptions: RequestOptions(), statusCode: 500);
        }),
        _apiService.searchUsers(query).catchError((e) {
          debugPrint('Search users error: $e');
          return Response(requestOptions: RequestOptions(), statusCode: 500);
        }),
        _apiService.getCommunities(search: query).catchError((e) {
          debugPrint('Search communities error: $e');
          return Response(requestOptions: RequestOptions(), statusCode: 500);
        }),
      ]);

      final postsRes = results[0];
      final usersRes = results[1];
      final commRes = results[2];

      List<Post> fetchedPosts = [];
      if (postsRes.statusCode == 200 && postsRes.data != null) {
        final raw = postsRes.data['data'] ?? postsRes.data['posts'] ?? [];
        if (raw is List) {
          fetchedPosts = raw.map((item) => Post.fromJson(item as Map<String, dynamic>)).toList();
        }
      }

      List<User> fetchedUsers = [];
      if (usersRes.statusCode == 200 && usersRes.data != null) {
        final raw = usersRes.data['data'] ?? usersRes.data['users'] ?? [];
        if (raw is List) {
          fetchedUsers = raw.map((item) => User.fromJson(item as Map<String, dynamic>)).toList();
        }
      }

      List<Community> fetchedCommunities = [];
      if (commRes.statusCode == 200 && commRes.data != null) {
        final raw = commRes.data['data']?['communities'] ??
            commRes.data['communities'] ??
            commRes.data['data'] ??
            [];
        if (raw is List) {
          fetchedCommunities = raw.map((item) => Community.fromJson(item as Map<String, dynamic>)).toList();
        }
      }

      if (mounted) {
        setState(() {
          _posts = fetchedPosts;
          _users = fetchedUsers;
          _communities = fetchedCommunities;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Search execution error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _selectTag(String tag) {
    _searchController.text = tag;
    _performSearch(tag);
  }

  Future<void> _toggleFollowUser(User user) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated) {
      AuthPromptBottomSheet.show(context, actionTitle: 'Follow User');
      return;
    }

    final newFollowState = !user.isFollowing;
    final updatedCount = newFollowState
        ? user.followersCount + 1
        : (user.followersCount > 0 ? user.followersCount - 1 : 0);

    setState(() {
      final index = _users.indexWhere((u) => u.id == user.id);
      if (index != -1) {
        _users[index] = user.copyWith(
          isFollowing: newFollowState,
          followersCount: updatedCount,
        );
      }
    });

    try {
      if (newFollowState) {
        await _apiService.followUser(user.id);
      } else {
        await _apiService.unfollowUser(user.id);
      }
    } catch (e) {
      debugPrint('Follow toggle failed: $e');
      final errStr = e.toString().toLowerCase();
      if (newFollowState && errStr.contains('already following')) {
        // Keep as followed
        return;
      }
      if (!newFollowState && errStr.contains('not following')) {
        // Keep as unfollowed
        return;
      }
      // Revert on real failure
      if (mounted) {
        setState(() {
          final index = _users.indexWhere((u) => u.id == user.id);
          if (index != -1) {
            _users[index] = user.copyWith(
              isFollowing: !newFollowState,
              followersCount: user.followersCount,
            );
          }
        });
      }
    }
  }

  Future<void> _toggleJoinCommunity(Community community) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated) {
      AuthPromptBottomSheet.show(context, actionTitle: 'Join Community');
      return;
    }

    final isCurrentlyJoined = community.isJoined;

    setState(() {
      final index = _communities.indexWhere((c) => c.id == community.id);
      if (index != -1) {
        _communities[index] = community.copyWith(
          isJoined: !isCurrentlyJoined,
          memberCount: isCurrentlyJoined
              ? (community.memberCount > 0 ? community.memberCount - 1 : 0)
              : community.memberCount + 1,
        );
      }
    });

    try {
      if (isCurrentlyJoined) {
        await _apiService.leaveCommunity(community.id);
      } else {
        await _apiService.joinCommunity(community.id);
      }
    } catch (e) {
      debugPrint('Join/leave community error: $e');
      if (mounted) {
        setState(() {
          final index = _communities.indexWhere((c) => c.id == community.id);
          if (index != -1) {
            _communities[index] = community.copyWith(
              isJoined: isCurrentlyJoined,
              memberCount: community.memberCount,
            );
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.search, color: AppColors.primary, size: 24),
            SizedBox(width: 8),
            Text(
              'Search Peto',
              style: TextStyle(
                fontFamily: 'Quicksand',
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.outline,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: [
            const Tab(text: 'Top'),
            Tab(text: 'Posts (${_posts.length})'),
            Tab(text: 'Users (${_users.length})'),
            Tab(text: 'Communities (${_communities.length})'),
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
              onChanged: _onSearchChanged,
              onSubmitted: (val) {
                if (val.trim().isNotEmpty) _performSearch(val.trim());
              },
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search posts, users, or communities...',
                hintStyle: const TextStyle(fontSize: 14, color: AppColors.onSurfaceVariant),
                prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: AppColors.outline),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.surfaceContainerLow,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(
                    color: AppColors.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
          ),

          // Trending / Suggestion Chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
            child: SizedBox(
              height: 34,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _trendingTags.length,
                itemBuilder: (context, index) {
                  final tag = _trendingTags[index];
                  final isSelected = _searchController.text.trim().toLowerCase() == tag.toLowerCase();

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      onTap: () => _selectTag(tag),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.outlineVariant.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '#$tag',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.white : AppColors.secondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          const Divider(height: 1),

          // Main Content / Tabs
          Expanded(
            child: _isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: AppColors.primary),
                        SizedBox(height: 12),
                        Text(
                          'Searching Peto...',
                          style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                : !_hasSearched
                    ? _buildDiscoveryLanding()
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildTopTab(),
                          _buildPostsList(),
                          _buildUsersList(),
                          _buildCommunitiesList(),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  // Initial Discovery Screen before search
  Widget _buildDiscoveryLanding() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 30),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primaryFixed.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.pets, size: 52, color: AppColors.primary),
          ),
          const SizedBox(height: 18),
          const Text(
            'Explore the Peto Community',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Search for other pet parents, adorable pet photos, care discussions, and community groups.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 28),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Popular Topics',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _trendingTags.map((tag) {
              return ActionChip(
                label: Text('#$tag'),
                labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                backgroundColor: AppColors.surfaceContainerLow,
                side: BorderSide(color: AppColors.outlineVariant.withValues(alpha: 0.4)),
                onPressed: () => _selectTag(tag),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // Top / Mixed Preview Tab
  Widget _buildTopTab() {
    final hasNoResults = _posts.isEmpty && _users.isEmpty && _communities.isEmpty;

    if (hasNoResults) {
      return _buildEmptyState('No matches found for "${_searchController.text}".');
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Users Preview Section
          if (_users.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Users',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.onSurface),
                ),
                TextButton(
                  onPressed: () => _tabController.animateTo(2),
                  child: const Text('See all', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            ..._users.take(3).map((user) => _buildUserTile(user)),
            const SizedBox(height: 16),
          ],

          // Communities Preview Section
          if (_communities.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Communities',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.onSurface),
                ),
                TextButton(
                  onPressed: () => _tabController.animateTo(3),
                  child: const Text('See all', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            ..._communities.take(3).map((comm) => CommunityCard(
                  community: comm,
                  onJoinToggle: () => _toggleJoinCommunity(comm),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CommunityDetailScreen(
                          communityId: comm.id,
                          initialCommunity: comm,
                        ),
                      ),
                    );
                  },
                )),
            const SizedBox(height: 16),
          ],

          // Posts Preview Section
          if (_posts.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Posts',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.onSurface),
                ),
                TextButton(
                  onPressed: () => _tabController.animateTo(1),
                  child: const Text('See all', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            ..._posts.take(3).map((post) => _buildPostItem(post)),
          ],
        ],
      ),
    );
  }

  // Posts Tab
  Widget _buildPostsList() {
    if (_posts.isEmpty) {
      return _buildEmptyState('No posts found for "${_searchController.text}".');
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _posts.length,
      itemBuilder: (context, index) {
        return _buildPostItem(_posts[index]);
      },
    );
  }

  Widget _buildPostItem(Post post) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final postProvider = Provider.of<PostProvider>(context, listen: false);

    return PostCard(
      post: post,
      onLike: () {
        if (authProvider.isAuthenticated) {
          postProvider.toggleLike(post.id);
        } else {
          AuthPromptBottomSheet.show(context, actionTitle: 'Like Post');
        }
      },
      onBookmark: () {
        if (authProvider.isAuthenticated) {
          postProvider.toggleBookmark(post.id);
        } else {
          AuthPromptBottomSheet.show(context, actionTitle: 'Save Post');
        }
      },
      onComment: () {
        CommentsBottomSheet.show(
          context,
          postId: post.id,
          postAuthorUsername: post.author.username,
        );
      },
    );
  }

  // Users Tab
  Widget _buildUsersList() {
    if (_isLoading) {
      return const UserListSkeleton(itemCount: 6);
    }

    if (_users.isEmpty) {
      return _buildEmptyState('No users found for "${_searchController.text}".');
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _users.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        return _buildUserTile(_users[index]);
      },
    );
  }

  Widget _buildUserTile(User user) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isSelf = authProvider.user?.id == user.id;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: AppColors.outlineVariant.withValues(alpha: 0.3),
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
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // User Avatar
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primaryFixed,
                backgroundImage: (user.avatarUrl != null && user.avatarUrl!.isNotEmpty)
                    ? CachedNetworkImageProvider(user.avatarUrl!)
                    : null,
                child: (user.avatarUrl == null || user.avatarUrl!.isEmpty)
                    ? const Icon(Icons.person, color: AppColors.primary, size: 24)
                    : null,
              ),
              const SizedBox(width: 12),

              // User Info
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
                        fontSize: 15,
                        color: AppColors.onSurface,
                      ),
                    ),
                    Text(
                      '@${user.username}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    if (user.bio != null && user.bio!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        user.bio!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Follow / Unfollow Action Button
              if (!isSelf)
                FollowButton(
                  isFollowing: user.isFollowing,
                  isCompact: true,
                  onPressed: () => _toggleFollowUser(user),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Communities Tab
  Widget _buildCommunitiesList() {
    if (_communities.isEmpty) {
      return _buildEmptyState('No communities found for "${_searchController.text}".');
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _communities.length,
      itemBuilder: (context, index) {
        final comm = _communities[index];
        return CommunityCard(
          community: comm,
          onJoinToggle: () => _toggleJoinCommunity(comm),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CommunityDetailScreen(
                  communityId: comm.id,
                  initialCommunity: comm,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 54, color: AppColors.outline.withValues(alpha: 0.5)),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Try searching with different keywords or browse trending tags above.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.outline),
            ),
          ],
        ),
      ),
    );
  }
}
