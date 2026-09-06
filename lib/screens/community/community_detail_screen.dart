import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/community_model.dart';
import '../../models/post_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/post_provider.dart';
import '../../providers/community_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/post_card.dart';
import '../../widgets/comments_bottom_sheet.dart';
import '../../widgets/auth_prompt_bottom_sheet.dart';
import '../posts/create_post_screen.dart';
import 'edit_community_screen.dart';

class CommunityDetailScreen extends StatefulWidget {
  final String communityId;
  final Community? initialCommunity;

  const CommunityDetailScreen({
    super.key,
    required this.communityId,
    this.initialCommunity,
  });

  @override
  State<CommunityDetailScreen> createState() => _CommunityDetailScreenState();
}

class _CommunityDetailScreenState extends State<CommunityDetailScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();

  late TabController _tabController;
  Community? _community;
  bool _isLoadingCommunity = true;

  // Discussions state
  List<Post> _posts = [];
  bool _isLoadingPosts = false;
  String _feedSort = 'new'; // new, popular

  // Members state
  List<CommunityMember> _members = [];
  bool _isLoadingMembers = false;

  // Rules state
  List<CommunityRule> _rules = [];
  bool _isLoadingRules = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _community = widget.initialCommunity;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAllData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    await _fetchCommunityDetail();
    if (_community != null) {
      _fetchCommunityPosts();
      _fetchCommunityMembers();
      _fetchCommunityRules();
    }
  }

  Future<void> _fetchCommunityDetail() async {
    setState(() => _isLoadingCommunity = true);
    try {
      final res = await _apiService.getCommunityDetail(widget.communityId);
      if (res.statusCode == 200 && res.data != null) {
        final data = res.data['data'] ?? res.data;
        if (data is Map<String, dynamic>) {
          setState(() {
            _community = Community.fromJson(data);
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading community detail: $e');
    } finally {
      if (mounted) setState(() => _isLoadingCommunity = false);
    }
  }

  Future<void> _fetchCommunityPosts() async {
    if (_community == null) return;
    if (_community!.isPrivate && !_community!.isJoined) return;

    setState(() => _isLoadingPosts = true);
    try {
      final res = await _apiService.getCommunityFeed(widget.communityId, sort: _feedSort);
      if (res.statusCode == 200 && res.data != null) {
        final rawData = res.data['data'] ?? res.data;
        final List rawPosts = rawData is Map<String, dynamic>
            ? (rawData['posts'] ?? [])
            : (res.data['posts'] ?? (rawData is List ? rawData : []));

        if (mounted) {
          setState(() {
            _posts = rawPosts
                .whereType<Map<String, dynamic>>()
                .map((p) => Post.fromJson(p))
                .toList();
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading community feed: $e');
    } finally {
      if (mounted) setState(() => _isLoadingPosts = false);
    }
  }

  Future<void> _fetchCommunityMembers() async {
    setState(() => _isLoadingMembers = true);
    try {
      final res = await _apiService.getCommunityMembers(widget.communityId);
      if (res.statusCode == 200 && res.data != null) {
        final rawData = res.data['data'] ?? res.data;
        final List rawMembers = rawData is Map<String, dynamic>
            ? (rawData['members'] ?? [])
            : (res.data['members'] ?? (rawData is List ? rawData : []));

        if (mounted) {
          setState(() {
            _members = rawMembers
                .whereType<Map<String, dynamic>>()
                .map((m) => CommunityMember.fromJson(m))
                .toList();
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading community members: $e');
    } finally {
      if (mounted) setState(() => _isLoadingMembers = false);
    }
  }

  Future<void> _fetchCommunityRules() async {
    setState(() => _isLoadingRules = true);
    try {
      final res = await _apiService.getCommunityRules(widget.communityId);
      if (res.statusCode == 200 && res.data != null) {
        final rawData = res.data['data'] ?? res.data;
        final List rawRules = rawData is Map<String, dynamic>
            ? (rawData['rules'] ?? [])
            : (res.data['rules'] ?? (rawData is List ? rawData : []));

        if (mounted) {
          setState(() {
            _rules = rawRules
                .whereType<Map<String, dynamic>>()
                .map((r) => CommunityRule.fromJson(r))
                .toList();
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading community rules: $e');
    } finally {
      if (mounted) setState(() => _isLoadingRules = false);
    }
  }

  void _handleJoinToggle() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated) {
      AuthPromptBottomSheet.show(context, actionTitle: 'Join Community');
      return;
    }

    if (_community == null) return;
    if (_community!.isUserOwner(authProvider.user?.id)) {
      return; // Community owner cannot leave their circle
    }

    final commProvider = Provider.of<CommunityProvider>(context, listen: false);
    final nextJoined = !_community!.isJoined;
    final nextCount = nextJoined
        ? _community!.memberCount + 1
        : (_community!.memberCount > 0 ? _community!.memberCount - 1 : 0);

    setState(() {
      _community = _community!.copyWith(isJoined: nextJoined, memberCount: nextCount);
    });
    commProvider.updateCommunityLocally(_community!);

    try {
      if (nextJoined) {
        await _apiService.joinCommunity(widget.communityId);
      } else {
        await _apiService.leaveCommunity(widget.communityId);
      }
      _fetchCommunityMembers();
      _fetchCommunityPosts();
    } catch (e) {
      debugPrint('Join toggle error: $e');
      _fetchCommunityDetail();
    }
  }

  void _handleChangeMemberRole(CommunityMember member, String newRole) async {
    try {
      await _apiService.changeMemberRole(widget.communityId, member.userId, newRole);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newRole == 'moderator'
                ? 'Made @${member.username} a Moderator'
                : 'Demoted @${member.username} to Member'),
          ),
        );
        _fetchCommunityMembers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update member role.'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _showBanMemberDialog(CommunityMember member) {
    final reasonController = TextEditingController(text: 'Violating community guidelines');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.block_rounded, color: AppColors.error, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Ban @${member.username}?',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This user will be removed from the circle and prevented from re-joining or posting.',
              style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Ban Reason',
                hintText: 'e.g. Inappropriate behavior or spam',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final reason = reasonController.text.trim();
              Navigator.pop(ctx);
              try {
                await _apiService.banMember(
                  widget.communityId,
                  member.userId,
                  reason.isNotEmpty ? reason : 'Violating community guidelines',
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Banned @${member.username} from circle.')),
                  );
                  _fetchCommunityMembers();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to ban member.'), backgroundColor: AppColors.error),
                  );
                }
              }
            },
            child: const Text('Ban Member'),
          ),
        ],
      ),
    );
  }

  void _showAddRuleDialog() {
    final titleController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.gavel_rounded, color: AppColors.primary, size: 22),
            SizedBox(width: 8),
            Text('Add Community Rule', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Rule Title *',
                hintText: 'e.g. Respect all members',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              decoration: const InputDecoration(
                labelText: 'Rule Description',
                hintText: 'Explain the rule and expectations...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final title = titleController.text.trim();
              if (title.isEmpty) return;
              Navigator.pop(ctx);
              try {
                await _apiService.createCommunityRule(
                  widget.communityId,
                  title,
                  descController.text.trim(),
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Rule added successfully.')),
                  );
                  _fetchCommunityRules();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to add rule.'), backgroundColor: AppColors.error),
                  );
                }
              }
            },
            child: const Text('Save Rule'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteRule(CommunityRule rule) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Rule?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to remove the rule "${rule.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _apiService.deleteCommunityRule(widget.communityId, rule.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Rule removed.')),
                  );
                  _fetchCommunityRules();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to delete rule.'), backgroundColor: AppColors.error),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _createPostInCircle() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated) {
      AuthPromptBottomSheet.show(context, actionTitle: 'Create Post');
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreatePostScreen(
          communityId: widget.communityId,
        ),
      ),
    );
    _fetchCommunityPosts();
  }

  void _toggleLocalPostLike(String postId) {
    setState(() {
      final idx = _posts.indexWhere((p) => p.id == postId);
      if (idx != -1) {
        final p = _posts[idx];
        final newLiked = !p.isLiked;
        final newCount = newLiked ? p.likesCount + 1 : (p.likesCount > 0 ? p.likesCount - 1 : 0);
        _posts[idx] = p.copyWith(isLiked: newLiked, likesCount: newCount);
      }
    });
  }

  void _toggleLocalPostBookmark(String postId) {
    setState(() {
      final idx = _posts.indexWhere((p) => p.id == postId);
      if (idx != -1) {
        final p = _posts[idx];
        _posts[idx] = p.copyWith(isBookmarked: !p.isBookmarked);
      }
    });
  }

  void _openEditCommunity(Community community) async {
    final updated = await Navigator.push<Community>(
      context,
      MaterialPageRoute(
        builder: (_) => EditCommunityScreen(community: community),
      ),
    );
    if (updated != null && mounted) {
      setState(() {
        _community = updated;
      });
      _loadAllData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final comm = _community;
    final authProvider = Provider.of<AuthProvider>(context);
    final isOwner = comm != null && comm.isUserOwner(authProvider.user?.id);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          comm?.name ?? 'Community',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (isOwner)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit Community',
              onPressed: () => _openEditCommunity(comm),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAllData,
          ),
        ],
      ),
      body: _isLoadingCommunity && comm == null
          ? const Center(child: CircularProgressIndicator())
          : comm == null
              ? const Center(
                  child: Text('Community not found.'),
                )
              : RefreshIndicator(
                  onRefresh: _loadAllData,
                  child: NestedScrollView(
                    headerSliverBuilder: (context, innerBoxIsScrolled) => [
                      SliverToBoxAdapter(
                        child: _buildCommunityHeader(comm),
                      ),
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _SliverAppBarDelegate(
                          TabBar(
                            controller: _tabController,
                            indicatorColor: AppColors.primary,
                            labelColor: AppColors.primary,
                            unselectedLabelColor: AppColors.outline,
                            tabs: [
                              Tab(text: 'Discussions (${comm.postCount})'),
                              Tab(text: 'Members (${comm.memberCount})'),
                              const Tab(text: 'About & Rules'),
                            ],
                          ),
                        ),
                      ),
                    ],
                    body: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildDiscussionsTab(comm),
                        _buildMembersTab(),
                        _buildAboutAndRulesTab(comm),
                      ],
                    ),
                  ),
                ),
      floatingActionButton: comm != null && (!comm.isPrivate || comm.isJoined)
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.primaryContainer,
              foregroundColor: AppColors.onPrimaryContainer,
              onPressed: _createPostInCircle,
              icon: const Icon(Icons.add_comment_rounded),
              label: const Text('Post in Circle'),
            )
          : null,
    );
  }

  Widget _buildCommunityHeader(Community comm) {
    final bannerUri = comm.coverImageUrl;
    final iconUri = comm.iconUrl;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cover Photo Banner with overlapping Icon
        SizedBox(
          height: 180,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Cover Image Container
              Container(
                height: 130,
                width: double.infinity,
                color: AppColors.surfaceContainerLow,
                child: bannerUri != null && bannerUri.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: bannerUri,
                        fit: BoxFit.cover,
                        placeholder: (_, _) => Container(color: AppColors.surfaceContainerLow),
                        errorWidget: (_, _, _) => _buildBannerFallback(comm),
                      )
                    : _buildBannerFallback(comm),
              ),

              // Avatar Icon Overlap
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
                    radius: 38,
                    backgroundColor: AppColors.primaryFixed,
                    backgroundImage: iconUri != null && iconUri.isNotEmpty
                        ? CachedNetworkImageProvider(iconUri)
                        : null,
                    child: iconUri == null || iconUri.isEmpty
                        ? Text(
                            comm.name.isNotEmpty ? comm.name[0].toUpperCase() : 'C',
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          )
                        : null,
                  ),
                ),
              ),

              // Join Button / Owner Badge on Banner Right
              Positioned(
                right: 16,
                bottom: 8,
                child: comm.isUserOwner(Provider.of<AuthProvider>(context, listen: false).user?.id)
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            onTap: () => _openEditCommunity(comm),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.edit_outlined, size: 13, color: Colors.white),
                                  SizedBox(width: 4),
                                  Text(
                                    'Edit',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.outline.withValues(alpha: 0.25)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.shield_outlined, size: 13, color: AppColors.primary),
                                SizedBox(width: 4),
                                Text(
                                  'Owner',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: AppColors.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: comm.isJoined ? Colors.transparent : AppColors.primaryContainer,
                          foregroundColor: comm.isJoined ? AppColors.onSurface : AppColors.onPrimaryContainer,
                          side: BorderSide(
                            color: comm.isJoined ? AppColors.surfaceContainerHigh : AppColors.primaryContainer,
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                        ),
                        onPressed: _handleJoinToggle,
                        child: Text(
                          comm.isJoined ? 'Joined' : 'Join Circle',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
              ),
            ],
          ),
        ),

        // Community Details
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                comm.name,
                style: const TextStyle(
                  fontFamily: 'Quicksand',
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.onSurface,
                ),
              ),
              if (comm.slug.isNotEmpty) ...[
                Text(
                  '@${comm.slug}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.secondary,
                  ),
                ),
              ],
              if (comm.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  comm.description,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 12),

              // Badges & Metrics Row
              Wrap(
                spacing: 12,
                runSpacing: 6,
                children: [
                  // Category Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primaryFixed.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      comm.category,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),

                  // Visibility Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          comm.isPrivate ? Icons.lock_rounded : Icons.public_rounded,
                          size: 13,
                          color: AppColors.outline,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          comm.isPrivate ? 'Private' : 'Public',
                          style: const TextStyle(fontSize: 12, color: AppColors.outline),
                        ),
                      ],
                    ),
                  ),

                  // Member count
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.people_outline, size: 16, color: AppColors.outline),
                      const SizedBox(width: 4),
                      Text(
                        '${comm.memberCount} members',
                        style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                      ),
                    ],
                  ),

                  // Post count
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.forum_outlined, size: 16, color: AppColors.outline),
                      const SizedBox(width: 4),
                      Text(
                        '${comm.postCount} posts',
                        style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDiscussionsTab(Community comm) {
    if (comm.isPrivate && !comm.isJoined) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.lock_outline_rounded, size: 36, color: AppColors.outline),
              ),
              const SizedBox(height: 16),
              const Text(
                'Private Community',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'Join this circle to view discussions and interact with fellow members.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryContainer,
                  foregroundColor: AppColors.onPrimaryContainer,
                ),
                onPressed: _handleJoinToggle,
                child: const Text('Join Circle'),
              ),
            ],
          ),
        ),
      );
    }

    final postProvider = Provider.of<PostProvider>(context, listen: false);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // Sort Selector: New vs Popular
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const Text(
              'Sort by:',
              style: TextStyle(fontSize: 12, color: AppColors.outline),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('New'),
              selected: _feedSort == 'new',
              onSelected: (val) {
                if (val && _feedSort != 'new') {
                  setState(() => _feedSort = 'new');
                  _fetchCommunityPosts();
                }
              },
            ),
            const SizedBox(width: 6),
            ChoiceChip(
              label: const Text('Popular'),
              selected: _feedSort == 'popular',
              onSelected: (val) {
                if (val && _feedSort != 'popular') {
                  setState(() => _feedSort = 'popular');
                  _fetchCommunityPosts();
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (_isLoadingPosts)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (_posts.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
              child: Column(
                children: [
                  Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 48,
                    color: AppColors.outline.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No discussions yet',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Start the conversation in this circle!',
                    style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _createPostInCircle,
                    icon: const Icon(Icons.add),
                    label: const Text('Start First Discussion'),
                  ),
                ],
              ),
            ),
          )
        else
          ..._posts.map((post) {
            return PostCard(
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
            );
          }),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildMembersTab() {
    if (_isLoadingMembers) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    if (_members.isEmpty) {
      return const Center(
        child: Text('No members found in this circle.'),
      );
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.user?.id;
    final isViewerOwner = _community?.isUserOwner(currentUserId) ?? false;
    final isViewerMod = _community?.isUserModerator(currentUserId) ?? false;

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _members.length,
      separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.surfaceContainerHigh),
      itemBuilder: (context, index) {
        final member = _members[index];
        final isMemberOwner = member.role.toLowerCase() == 'owner';
        final isMemberMod = member.role.toLowerCase() == 'moderator';
        final isSelf = member.userId == currentUserId;

        // Owner can manage non-owners. Moderator can ban regular members (not owner, not fellow mods).
        final canManage = !isSelf && (
          (isViewerOwner && !isMemberOwner) ||
          (isViewerMod && !isViewerOwner && !isMemberOwner && !isMemberMod)
        );

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 4),
          leading: CircleAvatar(
            backgroundColor: AppColors.primaryFixed,
            backgroundImage: member.avatarUrl != null && member.avatarUrl!.isNotEmpty
                ? CachedNetworkImageProvider(member.avatarUrl!)
                : null,
            child: member.avatarUrl == null
                ? Text(
                    member.username.isNotEmpty ? member.username[0].toUpperCase() : 'M',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                  )
                : null,
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  member.fullName ?? member.username,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isMemberOwner || isMemberMod) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: isMemberOwner ? Colors.amber.withValues(alpha: 0.2) : Colors.blue.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isMemberOwner ? 'Owner' : 'Mod',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isMemberOwner ? Colors.amber.shade900 : Colors.blue.shade900,
                    ),
                  ),
                ),
              ],
            ],
          ),
          subtitle: Text(
            '@${member.username}',
            style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
          ),
          trailing: canManage
              ? PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20, color: AppColors.outline),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 6,
                  onSelected: (action) {
                    if (action == 'make_mod') {
                      _handleChangeMemberRole(member, 'moderator');
                    } else if (action == 'demote_mod') {
                      _handleChangeMemberRole(member, 'member');
                    } else if (action == 'ban') {
                      _showBanMemberDialog(member);
                    }
                  },
                  itemBuilder: (ctx) => [
                    if (isViewerOwner && !isMemberMod)
                      const PopupMenuItem<String>(
                        value: 'make_mod',
                        child: Row(
                          children: [
                            Icon(Icons.shield_outlined, color: Colors.blue, size: 18),
                            SizedBox(width: 10),
                            Text(
                              'Make Moderator',
                              style: TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (isViewerOwner && isMemberMod)
                      const PopupMenuItem<String>(
                        value: 'demote_mod',
                        child: Row(
                          children: [
                            Icon(Icons.remove_moderator_outlined, color: AppColors.outline, size: 18),
                            SizedBox(width: 10),
                            Text(
                              'Demote to Member',
                              style: TextStyle(
                                color: AppColors.onSurface,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const PopupMenuItem<String>(
                      value: 'ban',
                      child: Row(
                        children: [
                          Icon(Icons.block_rounded, color: AppColors.error, size: 18),
                          SizedBox(width: 10),
                          Text(
                            'Ban from Community',
                            style: TextStyle(
                              color: AppColors.error,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : null,
        );
      },
    );
  }

  Widget _buildAboutAndRulesTab(Community comm) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isOwner = comm.isUserOwner(authProvider.user?.id);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // About Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'About Circle',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              if (isOwner)
                TextButton.icon(
                  onPressed: () => _openEditCommunity(comm),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit Details'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            comm.description.isNotEmpty ? comm.description : 'No description provided.',
            style: const TextStyle(fontSize: 14, height: 1.4, color: AppColors.onSurface),
          ),
          const SizedBox(height: 24),

          // Community Rules Section Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Community Rules',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Following these rules keeps the circle helpful and safe.',
                    style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                  ),
                ],
              ),
              if (isOwner)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    side: const BorderSide(color: AppColors.primary),
                  ),
                  onPressed: _showAddRuleDialog,
                  icon: const Icon(Icons.add, size: 16, color: AppColors.primary),
                  label: const Text(
                    'Add Rule',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          if (_isLoadingRules)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (_rules.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                '1. Be kind and respectful.\n2. No spam or self-promotion without permission.\n3. Share helpful and pet-friendly content.',
                style: TextStyle(fontSize: 13, height: 1.5, color: AppColors.onSurface),
              ),
            )
          else
            ..._rules.asMap().entries.map((entry) {
              final idx = entry.key + 1;
              final rule = entry.value;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.surfaceContainerHigh),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        color: AppColors.primaryFixed,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '$idx',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            rule.title,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          if (rule.description.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              rule.description,
                              style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant, height: 1.3),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (isOwner)
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
                        tooltip: 'Delete rule',
                        onPressed: () => _confirmDeleteRule(rule),
                      ),
                  ],
                ),
              );
            }),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildBannerFallback(Community comm) {
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

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverAppBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppColors.surface,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
