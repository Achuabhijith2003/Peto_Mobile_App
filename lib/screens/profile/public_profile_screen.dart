import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/user_model.dart';
import '../../models/post_model.dart';
import '../../services/api_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/post_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/post_card.dart';
import '../../widgets/sponsored_post_card.dart';
import '../../widgets/comments_bottom_sheet.dart';
import '../../widgets/auth_prompt_bottom_sheet.dart';
import '../../widgets/verification_badge.dart';
import 'followers_following_screen.dart';
import '../../models/pet_model.dart';
import '../../widgets/pet_showcase_section.dart';
import '../../widgets/skeleton_loader.dart';
import '../../widgets/follow_button.dart';

class PublicProfileScreen extends StatefulWidget {
  final String userId;
  final User? initialUser;

  const PublicProfileScreen({
    super.key,
    required this.userId,
    this.initialUser,
  });

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  final ApiService _apiService = ApiService();
  User? _user;
  List<Post> _posts = [];
  List<Map<String, dynamic>> _profileAds = [];
  List<Pet> _pets = [];
  bool _isLoading = true;
  bool _isFollowing = false;
  int _followersCount = 0;
  int _followingCount = 0;
  bool _isFollowLoading = false;
  bool _isGridView = false;

  @override
  void initState() {
    super.initState();
    _user = widget.initialUser;
    if (_user != null) {
      _isFollowing = _user!.isFollowing;
      _followersCount = _user!.followersCount;
      _followingCount = _user!.followingCount;
    }
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.user?.id;
    final isAuthenticated = authProvider.isAuthenticated;

    try {
      final userRes = await _apiService.getUserById(widget.userId).catchError(
            (_) => Response(requestOptions: RequestOptions(), statusCode: 500),
          );

      String resolvedId = widget.userId;

      if (userRes.statusCode == 200 && userRes.data != null) {
        final userData = userRes.data['data'] ?? userRes.data['user'] ?? userRes.data;
        if (userData is Map<String, dynamic>) {
          final loadedUser = User.fromJson(userData);
          _user = loadedUser;
          _isFollowing = loadedUser.isFollowing;
          _followersCount = loadedUser.followersCount;
          _followingCount = loadedUser.followingCount;
          resolvedId = loadedUser.id;
        }
      }

      final isSelf = currentUserId != null && currentUserId == resolvedId;

      final results = await Future.wait([
        _apiService.getUserPosts(resolvedId).catchError(
              (_) => Response(requestOptions: RequestOptions(), statusCode: 500),
            ),
        _apiService.getFollowers(resolvedId).catchError(
              (_) => Response(requestOptions: RequestOptions(), statusCode: 500),
            ),
        _apiService.getFollowing(resolvedId).catchError(
              (_) => Response(requestOptions: RequestOptions(), statusCode: 500),
            ),
        if (!isSelf && isAuthenticated)
          _apiService.getFollowStatus(resolvedId).catchError(
                (_) => Response(requestOptions: RequestOptions(), statusCode: 500),
              )
        else
          Future.value(Response(requestOptions: RequestOptions(), statusCode: 404)),
      ]);

      try {
        _profileAds = await _apiService.fetchFeedAds(placement: 'FEED');
      } catch (_) {}
      try {
        _pets = await _apiService.getUserPets(resolvedId);
      } catch (_) {}

      final postsRes = results[0];
      final followersRes = results[1];
      final followingRes = results[2];

      if (postsRes.statusCode == 200 && postsRes.data != null) {
        final List rawPosts = postsRes.data['posts'] ?? postsRes.data['data'] ?? [];
        _posts = rawPosts.map((p) => Post.fromJson(p as Map<String, dynamic>)).toList();
      }

      if (followersRes.statusCode == 200 && followersRes.data != null) {
        final List fList = followersRes.data['followers'] ?? followersRes.data['data'] ?? [];
        _followersCount = fList.length;
      }

      if (followingRes.statusCode == 200 && followingRes.data != null) {
        final List fList = followingRes.data['following'] ?? followingRes.data['data'] ?? [];
        _followingCount = fList.length;
      }

      if (!isSelf && results.length > 3) {
        final statusRes = results[3];
        if (statusRes.statusCode == 200 && statusRes.data != null) {
          final isF = statusRes.data['isFollowing'] == true || statusRes.data['is_following'] == true;
          _isFollowing = isF;
        }
      }
    } catch (e) {
      debugPrint('Error loading public profile: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleFollow() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated) {
      AuthPromptBottomSheet.show(context, actionTitle: 'Follow User');
      return;
    }

    if (_isFollowLoading) return;

    final targetId = _user?.id ?? widget.userId;
    final newState = !_isFollowing;
    setState(() {
      _isFollowLoading = true;
      _isFollowing = newState;
      _followersCount += newState ? 1 : (_followersCount > 0 ? -1 : 0);
    });

    try {
      if (newState) {
        await _apiService.followUser(targetId);
      } else {
        await _apiService.unfollowUser(targetId);
      }
    } catch (e) {
      debugPrint('Follow/unfollow error: $e');
      final errStr = e.toString().toLowerCase();
      if (newState && errStr.contains('already following')) {
        if (mounted) {
          setState(() {
            _isFollowing = true;
          });
        }
      } else if (!newState && errStr.contains('not following')) {
        if (mounted) {
          setState(() {
            _isFollowing = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isFollowing = !newState;
            _followersCount += !newState ? 1 : (_followersCount > 0 ? -1 : 0);
          });
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isFollowLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isSelf = authProvider.user?.id == widget.userId;

    final user = _user;
    final username = user?.username ?? 'user';
    final displayName = user?.displayName ?? 'Pet Parent';
    final avatarUrl = user?.avatarUrl;
    final coverUrl = user?.coverUrl;
    final bio = user?.bio;
    final location = user?.location;
    final isVerified = user?.isVerified == true || widget.initialUser?.isVerified == true;
    final badgeType = user?.verificationBadgeType ?? widget.initialUser?.verificationBadgeType;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '@$username',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            if (isVerified) ...[
              const SizedBox(width: 4),
              VerificationBadge(
                badgeType: badgeType,
                size: 16,
              ),
            ],
          ],
        ),
      ),
      body: _isLoading
          ? const ProfileSkeleton()
          : _user == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.person_off_outlined, size: 56, color: AppColors.onSurfaceVariant),
                        const SizedBox(height: 16),
                        Text(
                          'User @${widget.initialUser?.username ?? widget.userId} not found',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.onSurface),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'The user profile may have been removed or does not exist.',
                          style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Go Back'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  color: AppColors.primary,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with Cover & Avatar
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          height: 140,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primaryContainer.withValues(alpha: 0.8),
                                AppColors.primary.withValues(alpha: 0.8),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: coverUrl != null && coverUrl.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: coverUrl,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, _, _) => const SizedBox(),
                                )
                              : null,
                        ),
                        Positioned(
                          bottom: -40,
                          left: 20,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 4),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 40,
                              backgroundColor: AppColors.primaryFixed,
                              backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                                  ? CachedNetworkImageProvider(avatarUrl)
                                  : null,
                              child: (avatarUrl == null || avatarUrl.isEmpty)
                                  ? const Icon(Icons.person, size: 40, color: AppColors.primary)
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 48),

                    // User Details & Follow Button
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            displayName,
                                            style: const TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.onSurface,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                         if (isVerified) ...[
                                           const SizedBox(width: 6),
                                           VerificationBadge(
                                             badgeType: badgeType,
                                             size: 18,
                                           ),
                                         ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '@$username',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: AppColors.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (!isSelf)
                                FollowButton(
                                  isFollowing: _isFollowing,
                                  isLoading: _isFollowLoading,
                                  onPressed: _toggleFollow,
                                ),
                            ],
                          ),

                          if (bio != null && bio.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              bio,
                              style: const TextStyle(fontSize: 14, color: AppColors.onSurface),
                            ),
                          ],

                          if (location != null && location.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.location_on_outlined, size: 16, color: AppColors.onSurfaceVariant),
                                const SizedBox(width: 4),
                                Text(
                                  location,
                                  style: const TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ],

                          const SizedBox(height: 16),

                          // Stats Row
                          Row(
                            children: [
                              _buildStatItem('Posts', _posts.length.toString()),
                              const SizedBox(width: 20),
                              _buildStatItem(
                                'Followers',
                                '$_followersCount',
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => FollowersFollowingScreen(
                                        userId: _user?.id ?? widget.userId,
                                        username: username,
                                        initialIndex: 0,
                                      ),
                                    ),
                                  ).then((_) => _loadData());
                                },
                              ),
                              const SizedBox(width: 20),
                              _buildStatItem(
                                'Following',
                                '$_followingCount',
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => FollowersFollowingScreen(
                                        userId: _user?.id ?? widget.userId,
                                        username: username,
                                        initialIndex: 1,
                                      ),
                                    ),
                                  ).then((_) => _loadData());
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),
                    const Divider(height: 1),

                    // Pet Showcase Section
                    PetShowcaseSection(
                      pets: _pets,
                      isOwnProfile: false,
                    ),

                    // Posts View Toggle
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Posts (${_posts.length})',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.onSurface,
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: Icon(
                                  Icons.view_agenda_outlined,
                                  color: !_isGridView ? AppColors.primary : AppColors.onSurfaceVariant,
                                ),
                                onPressed: () => setState(() => _isGridView = false),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.grid_view,
                                  color: _isGridView ? AppColors.primary : AppColors.onSurfaceVariant,
                                ),
                                onPressed: () => setState(() => _isGridView = true),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Posts Content
                    if (_posts.isEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.all(40),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.photo_library_outlined, size: 48, color: AppColors.outline.withValues(alpha: 0.5)),
                              const SizedBox(height: 12),
                              const Text(
                                'No posts yet',
                                style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else if (_isGridView) ...[
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(12),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: _posts.length,
                        itemBuilder: (context, index) {
                          final post = _posts[index];
                          final hasMedia = post.media.isNotEmpty;
                          final mediaUrl = hasMedia ? post.media.first.url : null;

                          return InkWell(
                            onTap: () => setState(() => _isGridView = false),
                            borderRadius: BorderRadius.circular(12),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                color: AppColors.surfaceContainerLow,
                                child: hasMedia && mediaUrl != null
                                    ? CachedNetworkImage(
                                        imageUrl: mediaUrl,
                                        fit: BoxFit.cover,
                                        placeholder: (_, _) => Container(color: AppColors.surfaceContainerLow),
                                        errorWidget: (_, _, _) => const Center(child: Icon(Icons.broken_image)),
                                      )
                                    : Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Center(
                                          child: Text(
                                            post.content,
                                            maxLines: 4,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 11, color: AppColors.onSurface),
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                          );
                        },
                      ),
                    ] else ...[
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _posts.length,
                        itemBuilder: (context, index) {
                          final post = _posts[index];
                          final postProvider = Provider.of<PostProvider>(context);
                          final shouldShowAd = index == 1 && _profileAds.isNotEmpty;
                          final adToShow = shouldShowAd ? _profileAds.first : null;

                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              PostCard(
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
                              ),
                              if (adToShow != null)
                                SponsoredPostCard(ad: adToShow),
                            ],
                          );
                        },
                      ),
                    ],

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatItem(String label, String value, {VoidCallback? onTap}) {
    final item = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.onSurface,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: item,
        ),
      );
    }
    return item;
  }
}
