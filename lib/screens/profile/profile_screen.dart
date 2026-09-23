import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import '../../models/post_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/post_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/post_card.dart';
import '../../widgets/sponsored_post_card.dart';
import '../../widgets/comments_bottom_sheet.dart';
import '../../widgets/auth_prompt_bottom_sheet.dart';
import '../../widgets/verification_badge.dart';
import '../posts/create_post_screen.dart';
import 'edit_profile_screen.dart';
import 'bookmarks_screen.dart';
import 'followers_following_screen.dart';
import '../settings/settings_screen.dart';
import '../../models/pet_model.dart';
import '../../widgets/pet_showcase_section.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ApiService _apiService = ApiService();

  List<Post> _userPosts = [];
  List<Map<String, dynamic>> _profileAds = [];
  List<Pet> _myPets = [];
  bool _isLoadingPosts = false;
  bool _isGridView = false;
  int _followersCount = 0;
  int _followingCount = 0;
  String? _loadedUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfileData();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authProvider = Provider.of<AuthProvider>(context);
    if (authProvider.isAuthenticated && authProvider.user != null) {
      final userId = authProvider.user!.id;
      if (_loadedUserId != userId) {
        _loadedUserId = userId;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _loadProfileData();
        });
      }
    } else if (!authProvider.isAuthenticated && !authProvider.isLoading) {
      _loadedUserId = null;
    }
  }

  Future<void> _loadProfileData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated) return;

    final user = authProvider.user!;

    setState(() => _isLoadingPosts = true);

    // Refresh profile details, followers, and user posts concurrently
    try {
      await authProvider.refreshUser();

      final results = await Future.wait([
        _apiService.getUserPosts(user.id).catchError((_) => _apiService.getMyPosts()),
        _apiService.getFollowers(user.id).catchError((_) => _apiService.getCurrentUser()),
        _apiService.getFollowing(user.id).catchError((_) => _apiService.getCurrentUser()),
      ]);

      try {
        _profileAds = await _apiService.fetchFeedAds(placement: 'FEED');
      } catch (adErr) {
        debugPrint('Non-critical: error fetching feed ads: $adErr');
      }

      try {
        _myPets = await _apiService.getMyPets();
      } catch (petsErr) {
        debugPrint('Error loading my pets: $petsErr');
      }

      // Parse user posts
      final postsRes = results[0];
      if (postsRes.statusCode == 200 && postsRes.data != null) {
        final List rawPosts = postsRes.data['posts'] ?? postsRes.data['data'] ?? [];
        _userPosts = rawPosts.map((p) => Post.fromJson(p as Map<String, dynamic>)).toList();
      }

      // Parse followers
      final followersRes = results[1];
      if (followersRes.statusCode == 200 && followersRes.data != null) {
        final List fList = followersRes.data['followers'] ?? followersRes.data['data'] ?? [];
        _followersCount = fList.length;
      }

      // Parse following
      final followingRes = results[2];
      if (followingRes.statusCode == 200 && followingRes.data != null) {
        final List fList = followingRes.data['following'] ?? followingRes.data['data'] ?? [];
        _followingCount = fList.length;
      }
    } catch (e) {
      debugPrint('Error loading profile data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingPosts = false);
      }
    }
  }

  void _openWebsite(String url) {
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Website link copied: $url'),
        backgroundColor: AppColors.primaryContainer,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showPostDetailDialog(Post post) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PostCard(
                post: post,
                onLike: () {
                  final postProvider = Provider.of<PostProvider>(context, listen: false);
                  postProvider.toggleLike(post.id);
                  _toggleLocalPostLike(post.id);
                },
                onBookmark: () {
                  final postProvider = Provider.of<PostProvider>(context, listen: false);
                  postProvider.toggleBookmark(post.id, isCurrentlyBookmarked: post.isBookmarked);
                  _toggleLocalPostBookmark(post.id);
                },
                onComment: () {
                  Navigator.pop(ctx);
                  CommentsBottomSheet.show(
                    context,
                    postId: post.id,
                    postAuthorUsername: post.author.username,
                  );
                },
                onPostDeleted: () {
                  Navigator.pop(ctx);
                  _handleLocalPostDeleted(post.id);
                },
                onPostEdited: (newText) {
                  _handleLocalPostEdited(post.id, newText);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleLocalPostLike(String postId) {
    setState(() {
      final idx = _userPosts.indexWhere((p) => p.id == postId);
      if (idx != -1) {
        final p = _userPosts[idx];
        final newLiked = !p.isLiked;
        final newCount = newLiked ? p.likesCount + 1 : (p.likesCount > 0 ? p.likesCount - 1 : 0);
        _userPosts[idx] = p.copyWith(isLiked: newLiked, likesCount: newCount);
      }
    });
  }

  void _toggleLocalPostBookmark(String postId) {
    setState(() {
      final idx = _userPosts.indexWhere((p) => p.id == postId);
      if (idx != -1) {
        final p = _userPosts[idx];
        _userPosts[idx] = p.copyWith(isBookmarked: !p.isBookmarked);
      }
    });
  }

  void _handleLocalPostDeleted(String postId) {
    if (!mounted) return;
    setState(() {
      _userPosts.removeWhere((p) => p.id == postId);
    });
  }

  void _handleLocalPostEdited(String postId, String newContent) {
    if (!mounted) return;
    setState(() {
      final idx = _userPosts.indexWhere((p) => p.id == postId);
      if (idx != -1) {
        final p = _userPosts[idx];
        _userPosts[idx] = p.copyWith(content: newContent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    if (authProvider.isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primaryContainer),
        ),
      );
    }

    if (!authProvider.isAuthenticated) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Profile'),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Settings',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
            ),
          ],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircleAvatar(
                  radius: 40,
                  backgroundColor: AppColors.primaryFixed,
                  child: Icon(Icons.person_outline, size: 44, color: AppColors.primary),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Sign in to view your profile',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Manage your account, see your shared pet stories, and access saved bookmarks.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.onSurfaceVariant),
                ),
                const SizedBox(height: 24),
                CustomButton(
                  text: 'Sign In / Register',
                  width: 220,
                  onPressed: () {
                    AuthPromptBottomSheet.show(context, actionTitle: 'Profile');
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }

    final user = authProvider.user!;
    final coverUrl = user.coverUrl;
    final avatarUrl = user.avatarUrl;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              user.username.isNotEmpty ? '@${user.username}' : 'My Profile',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (user.isVerified) ...[
              const SizedBox(width: 4),
              VerificationBadge(
                badgeType: user.verificationBadgeType,
                size: 16,
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_outline),
            tooltip: 'Saved Posts',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BookmarksScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
              _loadProfileData();
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.error),
            tooltip: 'Sign Out',
            onPressed: () => authProvider.logout(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadProfileData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover Photo & Avatar Header
              SizedBox(
                height: 210,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Cover Image Container
                    Container(
                      height: 145,
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                      ),
                      child: coverUrl != null && coverUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: coverUrl,
                              fit: BoxFit.cover,
                              placeholder: (_, _) => Container(color: AppColors.surfaceContainerLow),
                              errorWidget: (_, _, _) => _buildCoverFallback(),
                            )
                          : _buildCoverFallback(),
                    ),

                    // Avatar Overlap
                    Positioned(
                      left: 20,
                      bottom: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.surface, width: 4),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 46,
                          backgroundColor: AppColors.primaryFixed,
                          backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                              ? CachedNetworkImageProvider(avatarUrl)
                              : null,
                          child: avatarUrl == null || avatarUrl.isEmpty
                              ? Text(
                                  user.displayName.isNotEmpty
                                      ? user.displayName[0].toUpperCase()
                                      : 'P',
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                )
                              : null,
                        ),
                      ),
                    ),

                    // Edit Profile & Settings Action Buttons
                    Positioned(
                      right: 16,
                      bottom: 8,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.surfaceContainerHigh),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            ),
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                              );
                              _loadProfileData();
                            },
                            icon: const Icon(Icons.edit_outlined, size: 16, color: AppColors.onSurface),
                            label: const Text(
                              'Edit Profile',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.onSurface,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.outlined(
                            style: IconButton.styleFrom(
                              side: const BorderSide(color: AppColors.surfaceContainerHigh),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              padding: const EdgeInsets.all(8),
                            ),
                            icon: const Icon(Icons.settings_outlined, size: 18, color: AppColors.onSurface),
                            tooltip: 'Settings',
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const SettingsScreen()),
                              );
                              _loadProfileData();
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // User details block
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Full Name
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            user.displayName,
                            style: const TextStyle(
                              fontFamily: 'Quicksand',
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppColors.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (user.isVerified) ...[
                          const SizedBox(width: 6),
                          VerificationBadge(
                            badgeType: user.verificationBadgeType,
                            size: 20,
                          ),
                        ],
                      ],
                    ),

                    // Username
                    Text(
                      '@${user.username}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.secondary,
                      ),
                    ),

                    // Bio
                    if (user.bio != null && user.bio!.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        user.bio!,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          color: AppColors.onSurface,
                        ),
                      ),
                    ],

                    // Meta Row: Location, Website
                    if ((user.location != null && user.location!.isNotEmpty) ||
                        (user.website != null && user.website!.isNotEmpty)) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 16,
                        runSpacing: 6,
                        children: [
                          if (user.location != null && user.location!.isNotEmpty)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.location_on_outlined, size: 15, color: AppColors.outline),
                                const SizedBox(width: 4),
                                Text(
                                  user.location!,
                                  style: const TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
                                ),
                              ],
                            ),
                          if (user.website != null && user.website!.isNotEmpty)
                            InkWell(
                              onTap: () => _openWebsite(user.website!),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.link_rounded, size: 15, color: AppColors.primary),
                                  const SizedBox(width: 4),
                                  Text(
                                    user.website!.replaceFirst(RegExp(r'^https?:\/\/'), ''),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],

                    // Stats Row: Posts, Followers, Following
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: AppColors.surfaceContainerHigh),
                          bottom: BorderSide(color: AppColors.surfaceContainerHigh),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem('Posts', _userPosts.length),
                          _buildStatItem(
                            'Followers',
                            _followersCount,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => FollowersFollowingScreen(
                                    userId: user.id,
                                    username: user.username,
                                    initialIndex: 0,
                                  ),
                                ),
                              ).then((_) => _loadProfileData());
                            },
                          ),
                          _buildStatItem(
                            'Following',
                            _followingCount,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => FollowersFollowingScreen(
                                    userId: user.id,
                                    username: user.username,
                                    initialIndex: 1,
                                  ),
                                ),
                              ).then((_) => _loadProfileData());
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Pet Showcase Section
              PetShowcaseSection(
                pets: _myPets,
                isOwnProfile: true,
                onRefresh: _loadProfileData,
              ),

              // Posts Header with Grid / List Toggle (Instagram vs Facebook)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Posts (${_userPosts.length})',
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
                            Icons.grid_on_rounded,
                            size: 20,
                            color: _isGridView ? AppColors.primary : AppColors.outline,
                          ),
                          onPressed: () => setState(() => _isGridView = true),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.view_agenda_outlined,
                            size: 20,
                            color: !_isGridView ? AppColors.primary : AppColors.outline,
                          ),
                          onPressed: () => setState(() => _isGridView = false),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Posts Content
              _isLoadingPosts
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : _userPosts.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                            child: Column(
                              children: [
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryFixed.withValues(alpha: 0.5),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.photo_library_outlined,
                                    size: 32,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'No posts shared yet',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Capture your favorite moments and share them with the pet community!',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
                                ),
                                const SizedBox(height: 16),
                                OutlinedButton.icon(
                                  onPressed: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => const CreatePostScreen()),
                                    );
                                    _loadProfileData();
                                  },
                                  icon: const Icon(Icons.add_photo_alternate_outlined),
                                  label: const Text('Create First Post'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _isGridView
                          ? _buildPostsGrid()
                          : _buildPostsList(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, int count, {VoidCallback? onTap}) {
    final item = Column(
      children: [
        Text(
          '$count',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: item,
        ),
      );
    }
    return item;
  }

  Widget _buildPostsGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _userPosts.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
        childAspectRatio: 1.0,
      ),
      itemBuilder: (context, index) {
        final post = _userPosts[index];
        final hasMedia = post.media.isNotEmpty;

        return InkWell(
          onTap: () => _showPostDetailDialog(post),
          borderRadius: BorderRadius.circular(8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              color: AppColors.surfaceContainerLow,
              child: hasMedia
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedNetworkImage(
                          imageUrl: post.media.first.url,
                          fit: BoxFit.cover,
                          placeholder: (_, _) => Container(color: AppColors.surfaceContainerLow),
                          errorWidget: (_, _, _) => const Center(
                            child: Icon(Icons.pets, color: AppColors.outline),
                          ),
                        ),
                        if (post.media.length > 1)
                          const Positioned(
                            top: 6,
                            right: 6,
                            child: Icon(
                              Icons.collections,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                      ],
                    )
                  : Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Center(
                        child: Text(
                          post.content,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.onSurface,
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPostsList() {
    final postProvider = Provider.of<PostProvider>(context, listen: false);

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _userPosts.length,
      itemBuilder: (context, index) {
        final post = _userPosts[index];
        final shouldShowAd = index == 1 && _profileAds.isNotEmpty;
        final adToShow = shouldShowAd ? _profileAds.first : null;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PostCard(
              post: post,
              onLike: () {
                postProvider.toggleLike(post.id);
                _toggleLocalPostLike(post.id);
              },
              onBookmark: () {
                postProvider.toggleBookmark(post.id, isCurrentlyBookmarked: post.isBookmarked);
                _toggleLocalPostBookmark(post.id);
              },
              onComment: () {
                CommentsBottomSheet.show(
                  context,
                  postId: post.id,
                  postAuthorUsername: post.author.username,
                );
              },
              onPostDeleted: () => _handleLocalPostDeleted(post.id),
              onPostEdited: (newText) => _handleLocalPostEdited(post.id, newText),
            ),
            if (adToShow != null)
              SponsoredPostCard(ad: adToShow),
          ],
        );
      },
    );
  }

  Widget _buildCoverFallback() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFFE2E8F0),
            Color(0xFFCBD5E1),
            Color(0xFFE2E8F0),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.pets_rounded,
          size: 44,
          color: AppColors.outline.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}
