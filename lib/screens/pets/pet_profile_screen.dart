import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../../models/pet_model.dart';
import '../../services/api_service.dart';
import '../../services/media_upload_helper.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';

class PetProfileScreen extends StatefulWidget {
  final String petId;
  final Pet? initialPet;

  const PetProfileScreen({
    super.key,
    required this.petId,
    this.initialPet,
  });

  @override
  State<PetProfileScreen> createState() => _PetProfileScreenState();
}

class _PetProfileScreenState extends State<PetProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _apiService = ApiService();

  Pet? _pet;
  bool _isLoading = true;
  String? _errorMessage;

  // Actions loading
  bool _isActionLoading = false;
  bool _isUploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _pet = widget.initialPet;
    _tabController = TabController(length: 2, vsync: this);

    _fetchPetDetails();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchPetDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final pet = await _apiService.getPetById(widget.petId);
      if (mounted) {
        if (pet != null) {
          setState(() {
            _pet = pet;
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = 'Pet showcase not found or access restricted.';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load pet: $e';
          _isLoading = false;
        });
      }
    }
  }



  void _showEnlargedPhoto(String photoUrl) {
    if (photoUrl.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black87,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: CachedNetworkImage(
                    imageUrl: photoUrl,
                    fit: BoxFit.contain,
                    placeholder: (context, url) => const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                    errorWidget: (context, url, error) => const Center(
                      child: Icon(Icons.broken_image, color: Colors.white70, size: 60),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                radius: 18,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.close, color: Colors.white, size: 20),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEnlargedVideo(String videoUrl) {
    if (videoUrl.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => _PetVideoPlayerDialog(videoUrl: videoUrl),
    );
  }

  Future<void> _confirmDeleteMedia(PetMedia item) async {
    final pet = _pet;
    if (pet == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(item.isVideo ? 'Remove Video' : 'Remove Photo'),
        content: Text(
          'Are you sure you want to remove this ${item.isVideo ? 'video' : 'photo'} from ${pet.name}\'s showcase gallery?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final targetId = item.id.isNotEmpty ? item.id : item.mediaId;
      final success = await _apiService.deletePetMedia(pet.id, targetId);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${item.isVideo ? 'Video' : 'Photo'} removed from gallery.'),
              backgroundColor: Colors.green,
            ),
          );
          _fetchPetDetails();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to remove media from gallery.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _uploadGalleryPhoto() async {
    final pet = _pet;
    if (pet == null) return;

    final uploadResult = await MediaUploadHelper.showPickerAndUpload(
      context,
      title: 'Add to Showcase (Photo / Video)',
      allowVideo: true,
    );

    if (uploadResult != null && (uploadResult.mediaId != null || uploadResult.uploadedUrl != null)) {
      setState(() => _isUploadingPhoto = true);
      try {
        final success = await _apiService.addPetMedia(
          pet.id,
          mediaId: uploadResult.mediaId ?? '',
          mediaUrl: uploadResult.uploadedUrl,
          role: 'GALLERY',
        );

        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(uploadResult.isVideo
                  ? 'Video added to pet showcase!'
                  : 'Photo added to pet showcase!'),
              backgroundColor: Colors.green,
            ),
          );
          _fetchPetDetails();
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to link media to gallery.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Upload error: $e'), backgroundColor: AppColors.error),
          );
        }
      } finally {
        if (mounted) setState(() => _isUploadingPhoto = false);
      }
    }
  }

  void _showInviteCoParentSheet() {
    final pet = _pet;
    if (pet == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => InviteCoParentBottomSheet(
        petId: pet.id,
        petName: pet.name,
        onInviteSent: () {
          _fetchPetDetails();
        },
      ),
    );
  }

  Future<void> _handleRespondInvite(bool accept) async {
    final pet = _pet;
    if (pet == null) return;

    setState(() => _isActionLoading = true);
    try {
      final success = await _apiService.respondPetInvite(
        '', // server checks by petId if inviteId is empty
        petId: pet.id,
        accept: accept,
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(accept ? 'Invitation accepted!' : 'Invitation declined.'),
              backgroundColor: accept ? Colors.green : Colors.orange,
            ),
          );
          _fetchPetDetails();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to process invitation response.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.user?.id;

    if (_isLoading && _pet == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pet Showcase')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null && _pet == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pet Showcase')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline, size: 56, color: AppColors.primary),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15, color: AppColors.onSurfaceVariant),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _fetchPetDetails,
                  child: const Text('Try Again'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final pet = _pet!;
    final canEdit = pet.permissions.canEdit;
    final canUpload = pet.permissions.canUploadMedia || canEdit;
    final canManageParents = pet.permissions.canManageParents || canEdit;

    // Check if the current user has a pending invite for this pet
    final pendingInviteForMe = pet.parents.firstWhere(
      (p) => p.userId == currentUserId && p.status == 'PENDING_INVITE',
      orElse: () => PetParent(
        id: '',
        userId: '',
        relationshipType: '',
        isPrimary: false,
        status: '',
        username: '',
        fullName: '',
        avatarUrl: '',
        verified: false,
      ),
    );
    final hasPendingInvite = pendingInviteForMe.userId.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 250,
              pinned: true,
              elevation: 0,
              backgroundColor: AppColors.surface,
              title: Text(
                pet.name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              actions: [
                if (canManageParents)
                  IconButton(
                    icon: const Icon(Icons.person_add_alt_1_outlined),
                    tooltip: 'Invite Co-Parent',
                    onPressed: _showInviteCoParentSheet,
                  ),
                if (canUpload)
                  IconButton(
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    tooltip: 'Add Showcase Photo',
                    onPressed: _uploadGalleryPhoto,
                  ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Subtle background gradient
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppColors.primary.withValues(alpha: 0.15),
                            AppColors.surface,
                          ],
                        ),
                      ),
                    ),
                    // Centered Profile Avatar
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 36),
                        GestureDetector(
                          onTap: (pet.avatarUrl != null && pet.avatarUrl!.isNotEmpty)
                              ? () => _showEnlargedPhoto(pet.avatarUrl!)
                              : null,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 104,
                                height: 104,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.primaryContainer.withValues(alpha: 0.3),
                                  border: Border.all(
                                    color: AppColors.primary.withValues(alpha: 0.5),
                                    width: 3,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.1),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: (pet.avatarUrl != null && pet.avatarUrl!.isNotEmpty)
                                      ? CachedNetworkImage(
                                          imageUrl: pet.avatarUrl!,
                                          fit: BoxFit.cover,
                                          placeholder: (context, url) => Container(
                                            color: AppColors.primaryContainer.withValues(alpha: 0.2),
                                            child: const Center(
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            ),
                                          ),
                                          errorWidget: (context, url, error) => Container(
                                            color: AppColors.primaryContainer.withValues(alpha: 0.2),
                                            alignment: Alignment.center,
                                            child: Text(pet.speciesEmoji, style: const TextStyle(fontSize: 48)),
                                          ),
                                        )
                                      : Container(
                                          alignment: Alignment.center,
                                          child: Text(pet.speciesEmoji, style: const TextStyle(fontSize: 48)),
                                        ),
                                ),
                              ),
                              Positioned(
                                bottom: 2,
                                right: 2,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(color: Colors.black26, blurRadius: 4),
                                    ],
                                  ),
                                  child: Text(pet.speciesEmoji, style: const TextStyle(fontSize: 16)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              pet.name,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.onSurface,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Visibility badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: pet.visibility == 'PUBLIC'
                                    ? Colors.green.withValues(alpha: 0.12)
                                    : pet.visibility == 'CONNECTIONS'
                                        ? Colors.blue.withValues(alpha: 0.12)
                                        : Colors.orange.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                pet.visibility,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: pet.visibility == 'PUBLIC'
                                      ? Colors.green[700]
                                      : pet.visibility == 'CONNECTIONS'
                                          ? Colors.blue[700]
                                          : Colors.orange[800],
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (pet.displayBreed != null || pet.displaySpecies.isNotEmpty)
                          Text(
                            pet.displayBreed ?? pet.displaySpecies,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Pending Invite Notification Banner
            if (hasPendingInvite)
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.mark_email_unread_outlined, color: Colors.amber.shade900, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'You are invited to co-parent ${pet.name}!',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Role: ${pendingInviteForMe.relationshipType.replaceAll('_', ' ')}. Once accepted, you will have shared parent access.',
                        style: TextStyle(fontSize: 11, color: Colors.amber.shade900),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: _isActionLoading ? null : () => _handleRespondInvite(true),
                            icon: const Icon(Icons.check, size: 14),
                            label: const Text('Accept'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: _isActionLoading ? null : () => _handleRespondInvite(false),
                            icon: const Icon(Icons.close, size: 14),
                            label: const Text('Decline'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.grey.shade700,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

            // Tab Bar
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverTabBarDelegate(
                TabBar(
                  controller: _tabController,
                  indicatorColor: AppColors.primary,
                  indicatorWeight: 3,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.onSurfaceVariant,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  tabs: [
                    const Tab(
                      icon: Icon(Icons.info_outline, size: 18),
                      text: 'About',
                    ),
                    Tab(
                      icon: const Icon(Icons.photo_library_outlined, size: 18),
                      text: 'Gallery (${pet.media.length})',
                    ),
                  ],
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            // Tab 1: About
            _buildAboutTab(pet, canManageParents),

            // Tab 2: Gallery
            _buildGalleryTab(pet, canUpload),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------
  // TAB 1: ABOUT
  // ----------------------------------------------------
  Widget _buildAboutTab(Pet pet, bool canManageParents) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Bio / Story
        if (pet.bio != null && pet.bio!.trim().isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.surfaceContainerHigh.withValues(alpha: 0.6)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.format_quote, size: 18, color: AppColors.primary),
                    SizedBox(width: 6),
                    Text(
                      'Story & Personality',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  pet.bio!.trim(),
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: AppColors.onSurface,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],

        // Traits and Attributes
        const Text(
          'Physical & Profile Traits',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.onSurface),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildTraitChip('Species', pet.displaySpecies, Icons.pets),
            if (pet.breed != null && pet.breed!.isNotEmpty)
              _buildTraitChip('Breed', pet.breed!, Icons.category_outlined),
            if (pet.breedSecondary != null && pet.breedSecondary!.isNotEmpty)
              _buildTraitChip('Secondary', pet.breedSecondary!, Icons.tune),
            if (pet.sex != null && pet.sex != 'UNKNOWN')
              _buildTraitChip('Sex', pet.sex == 'MALE' ? 'Male' : 'Female', Icons.transgender),
            if (pet.size != null && pet.size!.isNotEmpty)
              _buildTraitChip('Size', pet.size!, Icons.straighten),
            if (pet.color != null && pet.color!.isNotEmpty)
              _buildTraitChip('Color', pet.color!, Icons.palette_outlined),
            if (pet.formattedAge != null)
              _buildTraitChip('Age', pet.formattedAge!, Icons.cake_outlined),
            if (pet.formattedLocation != null)
              _buildTraitChip('Location', pet.formattedLocation!, Icons.location_on_outlined),
          ],
        ),
        const SizedBox(height: 24),

        // Authorized Parents & Guardians
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.supervisor_account, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  'Authorized Pet Parents (${pet.parents.length})',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.onSurface,
                  ),
                ),
              ],
            ),
            if (canManageParents)
              TextButton.icon(
                onPressed: _showInviteCoParentSheet,
                icon: const Icon(Icons.add, size: 14, color: AppColors.primary),
                label: const Text(
                  'Invite',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.surfaceContainerHigh.withValues(alpha: 0.6)),
          ),
          child: Column(
            children: pet.parents.asMap().entries.map((entry) {
              final idx = entry.key;
              final p = entry.value;
              final hasBorder = idx < pet.parents.length - 1;

              return Container(
                decoration: BoxDecoration(
                  border: hasBorder
                      ? Border(
                          bottom: BorderSide(
                            color: AppColors.surfaceContainerHigh.withValues(alpha: 0.5),
                          ),
                        )
                      : null,
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  leading: CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.primaryContainer.withValues(alpha: 0.4),
                    backgroundImage: p.avatarUrl.isNotEmpty ? CachedNetworkImageProvider(p.avatarUrl) : null,
                    child: p.avatarUrl.isEmpty
                        ? Text(
                            p.username.isNotEmpty ? p.username[0].toUpperCase() : 'U',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          )
                        : null,
                  ),
                  title: Row(
                    children: [
                      Flexible(
                        child: Text(
                          p.fullName.isNotEmpty ? p.fullName : '@${p.username}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (p.verified) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.verified, size: 14, color: Colors.blue),
                      ],
                    ],
                  ),
                  subtitle: Text(
                    '@${p.username}',
                    style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: p.isPrimary
                          ? AppColors.primaryContainer.withValues(alpha: 0.6)
                          : p.status == 'PENDING_INVITE'
                              ? Colors.amber.shade100
                              : AppColors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      p.isPrimary
                          ? 'Primary Owner'
                          : p.status == 'PENDING_INVITE'
                              ? 'Pending Invite'
                              : p.relationshipType.replaceAll('_', ' '),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: p.isPrimary
                            ? AppColors.primary
                            : p.status == 'PENDING_INVITE'
                                ? Colors.amber.shade900
                                : AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildTraitChip(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.surfaceContainerHigh.withValues(alpha: 0.8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.primary),
          const SizedBox(width: 5),
          Text(
            '$label: ',
            style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.onSurface),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------
  // TAB 2: GALLERY
  // ----------------------------------------------------
  Widget _buildGalleryTab(Pet pet, bool canUpload) {
    final mediaList = pet.media;

    if (mediaList.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.photo_library_outlined, size: 56, color: AppColors.surfaceContainerHigh),
              const SizedBox(height: 12),
              const Text(
                'No Showcase Media Yet',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.onSurface),
              ),
              const SizedBox(height: 6),
              const Text(
                'Upload photos and videos to create a visual gallery for this pet!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
              ),
              if (canUpload) ...[
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _isUploadingPhoto ? null : _uploadGalleryPhoto,
                  icon: _isUploadingPhoto
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.add_photo_alternate, size: 16),
                  label: const Text('Add Photo or Video'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    final col1 = <Widget>[];
    final col2 = <Widget>[];

    if (canUpload) {
      col1.add(_buildAddMediaCard());
    }

    for (int i = 0; i < mediaList.length; i++) {
      final item = mediaList[i];
      final tile = _buildGalleryMediaTile(item, canUpload);
      // Alternate between columns
      final slotIndex = canUpload ? i + 1 : i;
      if (slotIndex % 2 == 0) {
        col1.add(tile);
      } else {
        col2.add(tile);
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: col1,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: col2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddMediaCard() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: _isUploadingPhoto ? null : _uploadGalleryPhoto,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 130,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.35),
              width: 1.5,
            ),
          ),
          child: Center(
            child: _isUploadingPhoto
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate_outlined, size: 28, color: AppColors.primary),
                      SizedBox(height: 6),
                      Text(
                        'Add Media',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildGalleryMediaTile(PetMedia item, bool canUpload) {
    final isVideo = item.isVideo;
    final displayUrl = (isVideo && item.thumbnailUrl != null && item.thumbnailUrl!.isNotEmpty)
        ? item.thumbnailUrl!
        : item.mediaUrl;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () {
          if (isVideo) {
            _showEnlargedVideo(item.mediaUrl);
          } else {
            _showEnlargedPhoto(item.mediaUrl);
          }
        },
        onLongPress: canUpload ? () => _confirmDeleteMedia(item) : null,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.black12,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                if (displayUrl.isNotEmpty)
                  CachedNetworkImage(
                    imageUrl: displayUrl,
                    fit: BoxFit.fitWidth,
                    width: double.infinity,
                    placeholder: (context, url) => Container(
                      height: 140,
                      color: AppColors.surfaceContainerLow,
                      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: 120,
                      color: Colors.black87,
                      child: Center(
                        child: Icon(
                          isVideo ? Icons.videocam : Icons.broken_image,
                          color: Colors.white54,
                          size: 26,
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    height: 120,
                    color: Colors.black87,
                    child: Center(
                      child: Icon(
                        isVideo ? Icons.videocam : Icons.image,
                        color: Colors.white54,
                        size: 26,
                      ),
                    ),
                  ),

                // Video center play badge overlay
                if (isVideo)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.15),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white70, width: 1.2),
                          ),
                          child: const Icon(Icons.play_arrow_rounded, size: 24, color: Colors.white),
                        ),
                      ),
                    ),
                  ),

                // Video badge indicator (top-right)
                if (isVideo)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.videocam, size: 10, color: Colors.white),
                          SizedBox(width: 3),
                          Text(
                            'VIDEO',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Delete button for owners/caregivers (top-left)
                if (canUpload)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: GestureDetector(
                      onTap: () => _confirmDeleteMedia(item),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, size: 14, color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverTabBarDelegate(this._tabBar);

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
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return false;
  }
}

// ----------------------------------------------------
// INVITE CO-PARENT BOTTOM SHEET
// ----------------------------------------------------
class InviteCoParentBottomSheet extends StatefulWidget {
  final String petId;
  final String petName;
  final VoidCallback onInviteSent;

  const InviteCoParentBottomSheet({
    super.key,
    required this.petId,
    required this.petName,
    required this.onInviteSent,
  });

  @override
  State<InviteCoParentBottomSheet> createState() => _InviteCoParentBottomSheetState();
}

class _InviteCoParentBottomSheetState extends State<InviteCoParentBottomSheet> {
  final _inviteeController = TextEditingController();
  String _relationship = 'CO_OWNER';
  bool _isSending = false;
  String? _errorMessage;
  String? _successMessage;

  final List<Map<String, String>> _relationshipOptions = [
    {'value': 'CO_OWNER', 'label': 'Co-Owner (Full Shared Access)'},
    {'value': 'CARE_TAKER', 'label': 'Caretaker (Daily Care)'},
    {'value': 'GUARDIAN', 'label': 'Guardian (Authorized Contact)'},
    {'value': 'FAMILY_MEMBER', 'label': 'Family Member'},
  ];

  @override
  void dispose() {
    _inviteeController.dispose();
    super.dispose();
  }

  Future<void> _sendInvitation() async {
    final invitee = _inviteeController.text.trim();
    if (invitee.isEmpty) {
      setState(() => _errorMessage = 'Please enter a username or email.');
      return;
    }

    setState(() {
      _isSending = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final res = await ApiService().invitePetParent(
        widget.petId,
        invitee: invitee,
        relationship: _relationship,
      );

      if (mounted) {
        if (res['success'] == true) {
          setState(() {
            _successMessage = 'Invitation sent successfully to "$invitee"!';
            _inviteeController.clear();
          });
          widget.onInviteSent();
          Future.delayed(const Duration(milliseconds: 1200), () {
            if (mounted) Navigator.pop(context);
          });
        } else {
          setState(() {
            _errorMessage = res['message'] ?? 'Failed to send invitation.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.toString());
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + bottomInset),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.person_add_alt_1, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Invite Co-Parent for ${widget.petName}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Invite another user to co-parent or care for your pet. They will receive an invitation to accept or decline.',
            style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 16),

          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, size: 16, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(fontSize: 12, color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          if (_successMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline, size: 16, color: Colors.green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _successMessage!,
                      style: const TextStyle(fontSize: 12, color: Colors.green),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Invitee input field
          const Text(
            'Username or Email',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.onSurface),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _inviteeController,
            decoration: InputDecoration(
              hintText: 'e.g. johndoe or john@example.com',
              hintStyle: const TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
              prefixIcon: const Icon(Icons.alternate_email, size: 18),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 14),

          // Relationship Selector
          const Text(
            'Relationship / Role',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.onSurface),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.surfaceContainerHigh),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _relationship,
                isExpanded: true,
                items: _relationshipOptions.map((opt) {
                  return DropdownMenuItem<String>(
                    value: opt['value']!,
                    child: Text(opt['label']!, style: const TextStyle(fontSize: 13)),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _relationship = val);
                },
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Send Invitation Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSending ? null : _sendInvitation,
              icon: _isSending
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded, size: 16),
              label: Text(_isSending ? 'Sending Invitation...' : 'Send Invitation'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PetVideoPlayerDialog extends StatefulWidget {
  final String videoUrl;
  const _PetVideoPlayerDialog({required this.videoUrl});

  @override
  State<_PetVideoPlayerDialog> createState() => _PetVideoPlayerDialogState();
}

class _PetVideoPlayerDialogState extends State<_PetVideoPlayerDialog> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _isInitialized = true);
          _controller.play();
          _controller.setLooping(true);
        }
      }).catchError((err) {
        debugPrint('Pet gallery video player error: $err');
        if (mounted) setState(() => _hasError = true);
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (_isInitialized)
              GestureDetector(
                onTap: () {
                  setState(() {
                    _controller.value.isPlaying ? _controller.pause() : _controller.play();
                  });
                },
                child: AspectRatio(
                  aspectRatio: _controller.value.aspectRatio > 0 ? _controller.value.aspectRatio : 16 / 9,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      VideoPlayer(_controller),
                      if (!_controller.value.isPlaying)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(
                            color: Colors.black45,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.play_arrow, color: Colors.white, size: 48),
                        ),
                    ],
                  ),
                ),
              )
            else if (_hasError)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                    SizedBox(height: 12),
                    Text(
                      'Failed to load video.',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              )
            else
              const Padding(
                padding: EdgeInsets.all(48),
                child: CircularProgressIndicator(color: Colors.white),
              ),
            Positioned(
              top: 8,
              right: 8,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                radius: 18,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.close, color: Colors.white, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
