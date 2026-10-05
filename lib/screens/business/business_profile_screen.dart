import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/user_model.dart';
import '../../models/post_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/post_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/post_card.dart';
import '../../widgets/comments_bottom_sheet.dart';
import '../../widgets/auth_prompt_bottom_sheet.dart';
import '../../widgets/verification_badge.dart';
import '../posts/create_post_screen.dart';
import 'edit_business_screen.dart';

class BusinessProfileScreen extends StatefulWidget {
  final String businessId;

  const BusinessProfileScreen({super.key, required this.businessId});

  @override
  State<BusinessProfileScreen> createState() => _BusinessProfileScreenState();
}

class _BusinessProfileScreenState extends State<BusinessProfileScreen> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late TabController _tabController;

  BusinessModel? _business;
  bool _isLoading = true;
  String? _errorMessage;

  List<Post> _posts = [];
  bool _isLoadingPosts = false;
  bool _isUploadingCover = false;
  bool _isUploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadBusiness();
    _loadPosts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadBusiness() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await _apiService.getBusinessById(widget.businessId);
      if (data != null) {
        setState(() {
          _business = BusinessModel.fromJson(data);
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Business not found';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load business profile: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadPosts() async {
    setState(() => _isLoadingPosts = true);
    try {
      final list = await _apiService.getBusinessPosts(widget.businessId);
      setState(() {
        _posts = list
            .whereType<Map>()
            .map((p) => Post.fromJson(Map<String, dynamic>.from(p)))
            .toList();
        _isLoadingPosts = false;
      });
    } catch (e) {
      debugPrint('Error loading business posts: $e');
      setState(() => _isLoadingPosts = false);
    }
  }

  Future<void> _pickAvatar() async {
    if (_business == null) return;
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;

    setState(() => _isUploadingAvatar = true);
    try {
      final url = await _apiService.uploadBusinessAvatar(_business!.id, File(picked.path));
      if (url != null) {
        setState(() {
          _business = BusinessModel(
            id: _business!.id,
            name: _business!.name,
            legalName: _business!.legalName,
            username: _business!.username,
            countryCode: _business!.countryCode,
            state: _business!.state,
            city: _business!.city,
            websiteUrl: _business!.websiteUrl,
            publicEmail: _business!.publicEmail,
            publicPhone: _business!.publicPhone,
            businessCategory: _business!.businessCategory,
            description: _business!.description,
            avatarUrl: url,
            coverUrl: _business!.coverUrl,
            isVerified: _business!.isVerified,
            role: _business!.role,
            canManage: _business!.canManage,
          );
        });
        if (mounted) {
          final auth = Provider.of<AuthProvider>(context, listen: false);
          await auth.fetchManagedBusinesses();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload logo: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  Future<void> _pickCover() async {
    if (_business == null) return;
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;

    setState(() => _isUploadingCover = true);
    try {
      final url = await _apiService.uploadBusinessCover(_business!.id, File(picked.path));
      if (url != null) {
        setState(() {
          _business = BusinessModel(
            id: _business!.id,
            name: _business!.name,
            legalName: _business!.legalName,
            username: _business!.username,
            countryCode: _business!.countryCode,
            state: _business!.state,
            city: _business!.city,
            websiteUrl: _business!.websiteUrl,
            publicEmail: _business!.publicEmail,
            publicPhone: _business!.publicPhone,
            businessCategory: _business!.businessCategory,
            description: _business!.description,
            avatarUrl: _business!.avatarUrl,
            coverUrl: url,
            isVerified: _business!.isVerified,
            role: _business!.role,
            canManage: _business!.canManage,
          );
        });
        if (mounted) {
          final auth = Provider.of<AuthProvider>(context, listen: false);
          await auth.fetchManagedBusinesses();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload cover: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingCover = false);
    }
  }

  void _onCreatePost() {
    if (_business == null) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.activeIdentity.id != _business!.id) {
      auth.switchIdentity('BUSINESS', businessId: _business!.id);
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreatePostScreen()),
    ).then((_) => _loadPosts());
  }

  void _onEditBusiness() async {
    if (_business == null) return;
    final updated = await Navigator.push<BusinessModel>(
      context,
      MaterialPageRoute(builder: (_) => EditBusinessScreen(business: _business!)),
    );
    if (updated != null) {
      setState(() => _business = updated);
    } else {
      _loadBusiness();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    if (_errorMessage != null || _business == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Business Profile')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.business, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text(_errorMessage ?? 'Business not found'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadBusiness,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final b = _business!;
    final auth = Provider.of<AuthProvider>(context);
    final isCurrentActive = auth.activeIdentity.isBusiness && auth.activeIdentity.id == b.id;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cover Photo & Avatar Header
                  SizedBox(
                    height: 220,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Cover Image Container
                        Container(
                          height: 160,
                          width: double.infinity,
                          decoration: const BoxDecoration(
                            color: AppColors.surfaceContainerLow,
                          ),
                          child: b.coverUrl != null && b.coverUrl!.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: b.coverUrl!,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, _, _) => Container(color: Colors.amber.shade400),
                                )
                              : Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Colors.amber.shade600, Colors.orange.shade500],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                  ),
                                ),
                        ),

                        // Back Button
                        Positioned(
                          top: MediaQuery.of(context).padding.top + 8,
                          left: 16,
                          child: IconButton(
                            icon: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.4),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.arrow_back, color: Colors.white, size: 18),
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),

                        // Edit Button on Cover for Managers
                        if (b.canManage)
                          Positioned(
                            top: MediaQuery.of(context).padding.top + 8,
                            right: 16,
                            child: IconButton(
                              icon: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.4),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.edit, color: Colors.white, size: 18),
                              ),
                              onPressed: _onEditBusiness,
                              tooltip: 'Edit Business',
                            ),
                          ),

                        // Change Cover Button for Managers
                        if (b.canManage)
                          Positioned(
                            bottom: 68,
                            right: 16,
                            child: GestureDetector(
                              onTap: _isUploadingCover ? null : _pickCover,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.55),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _isUploadingCover
                                        ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                        : const Icon(Icons.camera_alt, color: Colors.white, size: 14),
                                    const SizedBox(width: 4),
                                    Text(
                                      _isUploadingCover ? 'Uploading...' : 'Change Cover',
                                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                        // Avatar Overlap (half on cover, half on white background)
                        Positioned(
                          left: 16,
                          bottom: 0,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 88,
                                height: 88,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 4),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.12),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: b.avatarUrl != null && b.avatarUrl!.isNotEmpty
                                      ? CachedNetworkImage(
                                          imageUrl: b.avatarUrl!,
                                          fit: BoxFit.cover,
                                        )
                                      : Container(
                                          color: Colors.amber.shade100,
                                          alignment: Alignment.center,
                                          child: Text(
                                            b.name.isNotEmpty ? b.name[0].toUpperCase() : 'B',
                                            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.amber),
                                          ),
                                        ),
                                ),
                              ),
                              if (b.canManage)
                                Positioned(
                                  bottom: 2,
                                  right: 2,
                                  child: GestureDetector(
                                    onTap: _isUploadingAvatar ? null : _pickAvatar,
                                    child: CircleAvatar(
                                      radius: 14,
                                      backgroundColor: AppColors.primary,
                                      child: _isUploadingAvatar
                                          ? const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                          : const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        // Switch Identity Action Button
                        if (b.canManage)
                          Positioned(
                            right: 16,
                            bottom: 8,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                if (isCurrentActive) {
                                  auth.switchIdentity('PERSON');
                                } else {
                                  auth.switchIdentity('BUSINESS', businessId: b.id);
                                }
                              },
                              icon: Icon(
                                isCurrentActive ? Icons.check_circle : Icons.swap_horiz,
                                size: 16,
                                color: isCurrentActive ? Colors.green : AppColors.primary,
                              ),
                              label: Text(
                                isCurrentActive ? 'Active Identity' : 'Switch Identity',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isCurrentActive ? Colors.green : AppColors.primary,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: isCurrentActive ? Colors.green : AppColors.primary),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Business Details Block
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                b.name,
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (b.isVerified) ...[
                              const SizedBox(width: 6),
                              const VerificationBadge(badgeType: 'BUSINESS_VERIFIED', size: 20),
                            ],
                          ],
                        ),
                        if (b.username != null && b.username!.isNotEmpty)
                          Text(
                            '@${b.username}',
                            style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w600),
                          ),
                        const SizedBox(height: 4),
                        Text(
                          'Legal: ${b.legalName}',
                          style: const TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                        if (b.businessCategory != null && b.businessCategory!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.amber.shade200),
                            ),
                            child: Text(
                              b.businessCategory!,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                            ),
                          ),
                        ],
                        if (b.description != null && b.description!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            b.description!,
                            style: const TextStyle(fontSize: 13, height: 1.3, color: Colors.black87),
                          ),
                        ],

                        // Quick info row
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 12,
                          runSpacing: 6,
                          children: [
                            if (b.city != null && b.city!.isNotEmpty)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.location_on, size: 14, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${b.city}, ${b.countryCode}',
                                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                                  ),
                                ],
                              ),
                            if (b.websiteUrl != null && b.websiteUrl!.isNotEmpty)
                              GestureDetector(
                                onTap: () => launchUrl(Uri.parse(b.websiteUrl!.startsWith('http') ? b.websiteUrl! : 'https://${b.websiteUrl!}')),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.language, size: 14, color: Colors.blue),
                                    const SizedBox(width: 4),
                                    Text(
                                      b.websiteUrl!.replaceAll(RegExp(r'^https?:\/\/'), ''),
                                      style: const TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),

                        // Owner Buttons Bar
                        if (b.canManage) ...[
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _onCreatePost,
                                  icon: const Icon(Icons.add, size: 16),
                                  label: const Text('Create Post', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _onEditBusiness,
                                  icon: const Icon(Icons.edit, size: 16),
                                  label: const Text('Edit Business', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.black87,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Tab bar
                  TabBar(
                    controller: _tabController,
                    labelColor: AppColors.primary,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: AppColors.primary,
                    indicatorWeight: 3,
                    labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    tabs: const [
                      Tab(text: 'Posts'),
                      Tab(text: 'About'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            // Posts Tab
            _isLoadingPosts
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _posts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.article_outlined, size: 48, color: Colors.grey),
                            const SizedBox(height: 10),
                            Text('No posts yet by ${b.name}', style: const TextStyle(color: Colors.grey)),
                            if (b.canManage) ...[
                              const SizedBox(height: 14),
                              ElevatedButton(
                                onPressed: _onCreatePost,
                                child: const Text('Publish First Post'),
                              ),
                            ],
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(top: 8, bottom: 24),
                        itemCount: _posts.length,
                        itemBuilder: (ctx, i) {
                          final post = _posts[i];
                          return PostCard(
                            post: post,
                            onLike: () {
                              final auth = Provider.of<AuthProvider>(context, listen: false);
                              if (auth.isAuthenticated) {
                                Provider.of<PostProvider>(context, listen: false).toggleLike(post.id);
                              } else {
                                AuthPromptBottomSheet.show(context, actionTitle: 'Like Post');
                              }
                            },
                            onBookmark: () {
                              final auth = Provider.of<AuthProvider>(context, listen: false);
                              if (auth.isAuthenticated) {
                                Provider.of<PostProvider>(context, listen: false).toggleBookmark(post.id);
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
                        },
                      ),

            // About Tab
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Business Information', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      const Divider(height: 24),
                      _buildInfoRow('Trading Name', b.name),
                      _buildInfoRow('Legal Name', b.legalName),
                      if (b.businessCategory != null) _buildInfoRow('Category', b.businessCategory!),
                      _buildInfoRow('Region / Country', b.countryCode),
                      if (b.city != null) _buildInfoRow('Location', '${b.city}${b.state != null ? ', ${b.state}' : ''}'),
                      if (b.publicEmail != null && b.publicEmail!.isNotEmpty) _buildInfoRow('Email', b.publicEmail!),
                      if (b.publicPhone != null && b.publicPhone!.isNotEmpty) _buildInfoRow('Phone', b.publicPhone!),
                      if (b.websiteUrl != null && b.websiteUrl!.isNotEmpty) _buildInfoRow('Website', b.websiteUrl!),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber.shade200),
                        ),
                        child: Row(
                          children: [
                            b.isVerified
                                ? const VerificationBadge(badgeType: 'BUSINESS_VERIFIED', size: 20)
                                : Icon(Icons.storefront_rounded, size: 20, color: Colors.amber.shade800),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                b.isVerified
                                    ? 'Verified Business Partner • Commercial registration and compliance verified.'
                                    : 'Registered Peto Business Identity',
                                style: TextStyle(fontSize: 12, color: Colors.amber.shade900, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
          ),
        ],
      ),
    );
  }
}
