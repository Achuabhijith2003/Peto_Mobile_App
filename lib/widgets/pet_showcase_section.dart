import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/pet_model.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/media_upload_helper.dart';
import '../screens/pets/pet_profile_screen.dart';

class PetShowcaseSection extends StatefulWidget {
  final List<Pet> pets;
  final bool isOwnProfile;
  final VoidCallback? onRefresh;

  const PetShowcaseSection({
    super.key,
    required this.pets,
    this.isOwnProfile = false,
    this.onRefresh,
  });

  @override
  State<PetShowcaseSection> createState() => _PetShowcaseSectionState();
}

class _PetShowcaseSectionState extends State<PetShowcaseSection> {
  final ApiService _apiService = ApiService();
  List<PetPendingInvite> _pendingInvites = [];
  final Set<String> _respondingInviteIds = {};

  @override
  void initState() {
    super.initState();
    if (widget.isOwnProfile) {
      _fetchPendingInvites();
    }
  }

  @override
  void didUpdateWidget(covariant PetShowcaseSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOwnProfile && (!oldWidget.isOwnProfile || widget.pets.length != oldWidget.pets.length)) {
      _fetchPendingInvites();
    }
  }

  Future<void> _fetchPendingInvites() async {
    if (!widget.isOwnProfile) return;
    try {
      final invites = await _apiService.getPendingPetInvites();
      if (mounted) {
        setState(() {
          _pendingInvites = invites;
        });
      }
    } catch (_) {}
  }

  Future<void> _respondInvite(String inviteId, bool accept, String petName) async {
    setState(() => _respondingInviteIds.add(inviteId));
    try {
      final success = await _apiService.respondPetInvite(inviteId, accept: accept);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(accept
                  ? 'You are now a co-parent of $petName!'
                  : 'Invitation for $petName declined.'),
              backgroundColor: accept ? Colors.green : Colors.orange,
            ),
          );
          _fetchPendingInvites();
          widget.onRefresh?.call();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to respond to invitation.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _respondingInviteIds.remove(inviteId));
      }
    }
  }

  void _showPetDetailsSheet(BuildContext context, Pet pet) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PetDetailsBottomSheet(
        pet: pet,
        isOwnProfile: widget.isOwnProfile,
        onRefresh: () {
          _fetchPendingInvites();
          widget.onRefresh?.call();
        },
      ),
    );
  }

  void _showAddPetSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddPetBottomSheet(
        onPetCreated: () {
          _fetchPendingInvites();
          widget.onRefresh?.call();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.pets.isEmpty && !widget.isOwnProfile) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.surfaceContainerHigh.withValues(alpha: 0.5)),
          bottom: BorderSide(color: AppColors.surfaceContainerHigh.withValues(alpha: 0.5)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.pets, size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      widget.isOwnProfile ? 'My Pets (${widget.pets.length})' : 'Pets Showcase (${widget.pets.length})',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.onSurface,
                      ),
                    ),
                  ],
                ),
                if (widget.isOwnProfile)
                  TextButton.icon(
                    onPressed: () => _showAddPetSheet(context),
                    icon: const Icon(Icons.add, size: 16, color: AppColors.primary),
                    label: const Text(
                      'Add Pet',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            ),
          ),

          // Pending Pet Invitations Banner (if any)
          if (_pendingInvites.isNotEmpty && widget.isOwnProfile) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.mark_email_unread_outlined, size: 15, color: Colors.amber.shade900),
                      const SizedBox(width: 6),
                      Text(
                        'Pending Invitations (${_pendingInvites.length})',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ..._pendingInvites.map((inv) {
                    final pet = inv.pet;
                    final inviter = inv.inviter;
                    final petName = pet?.name ?? 'Pet';
                    final isBusy = _respondingInviteIds.contains(inv.id);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.amber.shade200,
                            ),
                            child: ClipOval(
                              child: (pet?.avatarUrl != null && pet!.avatarUrl!.isNotEmpty)
                                  ? CachedNetworkImage(
                                      imageUrl: pet.avatarUrl!,
                                      fit: BoxFit.cover,
                                      errorWidget: (context, url, error) => const Center(
                                        child: Icon(Icons.pets, size: 18, color: Colors.amber),
                                      ),
                                    )
                                  : const Center(
                                      child: Icon(Icons.pets, size: 18, color: Colors.amber),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  petName,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.onSurface,
                                  ),
                                ),
                                Text(
                                  'Invited as ${inv.relationshipType.replaceAll('_', ' ')}${inviter?.username.isNotEmpty == true ? ' by @${inviter!.username}' : ''}',
                                  style: TextStyle(fontSize: 11, color: Colors.amber.shade900),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (isBusy)
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton.filled(
                                  onPressed: () => _respondInvite(inv.id, true, petName),
                                  icon: const Icon(Icons.check, size: 15),
                                  tooltip: 'Accept',
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.all(4),
                                    minimumSize: const Size(28, 28),
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                IconButton.outlined(
                                  onPressed: () => _respondInvite(inv.id, false, petName),
                                  icon: const Icon(Icons.close, size: 15),
                                  tooltip: 'Decline',
                                  style: IconButton.styleFrom(
                                    foregroundColor: Colors.grey.shade700,
                                    padding: const EdgeInsets.all(4),
                                    minimumSize: const Size(28, 28),
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],

          const SizedBox(height: 8),
          if (widget.pets.isEmpty && widget.isOwnProfile)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: InkWell(
                onTap: () => _showAddPetSheet(context),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.add, color: AppColors.primary, size: 18),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Add your first companion',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.onSurface,
                              ),
                            ),
                            Text(
                              'Showcase your pet, manage privacy and co-parents',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SizedBox(
              height: 140,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: widget.pets.length + (widget.isOwnProfile ? 1 : 0),
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (ctx, idx) {
                  if (idx == widget.pets.length && widget.isOwnProfile) {
                    return InkWell(
                      onTap: () => _showAddPetSheet(context),
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        width: 110,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: AppColors.surfaceContainerHigh,
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_circle_outline, size: 28, color: AppColors.primary),
                            SizedBox(height: 6),
                            Text(
                              'Add Pet',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final pet = widget.pets[idx];
                  return _PetCard(pet: pet, onTap: () => _showPetDetailsSheet(context, pet));
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _PetCard extends StatelessWidget {
  final Pet pet;
  final VoidCallback onTap;

  const _PetCard({required this.pet, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 115,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.surfaceContainerHigh.withValues(alpha: 0.7)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Avatar
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primaryContainer.withValues(alpha: 0.35),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.25), width: 1.5),
                  ),
                  child: ClipOval(
                    child: (pet.avatarUrl != null && pet.avatarUrl!.trim().isNotEmpty)
                        ? CachedNetworkImage(
                            imageUrl: pet.avatarUrl!.trim(),
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: AppColors.primaryContainer.withValues(alpha: 0.2),
                              child: const Center(
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: AppColors.primaryContainer.withValues(alpha: 0.2),
                              alignment: Alignment.center,
                              child: Text(pet.speciesEmoji, style: const TextStyle(fontSize: 24)),
                            ),
                          )
                        : Container(
                            alignment: Alignment.center,
                            child: Text(pet.speciesEmoji, style: const TextStyle(fontSize: 24)),
                          ),
                  ),
                ),
                Positioned(
                  bottom: -2,
                  right: -2,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Text(pet.speciesEmoji, style: const TextStyle(fontSize: 11)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Pet Name
            Text(
              pet.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            // Breed or Species
            Text(
              pet.displayBreed ?? pet.displaySpecies,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PetDetailsBottomSheet extends StatefulWidget {
  final Pet pet;
  final bool isOwnProfile;
  final VoidCallback? onRefresh;

  const _PetDetailsBottomSheet({
    required this.pet,
    this.isOwnProfile = false,
    this.onRefresh,
  });

  @override
  State<_PetDetailsBottomSheet> createState() => _PetDetailsBottomSheetState();
}

class _PetDetailsBottomSheetState extends State<_PetDetailsBottomSheet> {
  late Pet _pet;
  bool _isLoadingDetails = false;

  @override
  void initState() {
    super.initState();
    _pet = widget.pet;
    _fetchFullDetails();
  }

  Future<void> _fetchFullDetails() async {
    setState(() => _isLoadingDetails = true);
    try {
      final detailed = await ApiService().getPetById(_pet.id);
      if (mounted && detailed != null) {
        setState(() {
          _pet = detailed;
        });
      }
    } catch (_) {
      // Keep existing pet
    } finally {
      if (mounted) {
        setState(() => _isLoadingDetails = false);
      }
    }
  }

  void _showEnlargedPhoto(String photoUrl) {
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
                  borderRadius: BorderRadius.circular(12),
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

  void _openEditSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EditPetBottomSheet(
        pet: _pet,
        onPetUpdated: (updated) {
          setState(() {
            _pet = updated;
          });
          widget.onRefresh?.call();
        },
      ),
    );
  }

  void _openInviteSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => InviteCoParentBottomSheet(
        petId: _pet.id,
        petName: _pet.name,
        onInviteSent: () {
          _fetchFullDetails();
          widget.onRefresh?.call();
        },
      ),
    );
  }

  Future<void> _confirmDeletePet() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${_pet.name}?'),
        content: Text(
          'Are you sure you want to remove ${_pet.name} from your profile? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete Pet'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await ApiService().deletePet(_pet.id);
      if (mounted) {
        if (success) {
          Navigator.pop(context);
          widget.onRefresh?.call();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${_pet.name} has been removed.')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete pet. Please try again.')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.90;
    final canEdit = _pet.permissions.canEdit || widget.isOwnProfile;
    final hasPhoto = _pet.avatarUrl != null && _pet.avatarUrl!.trim().isNotEmpty;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Top Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.pets, size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    const Text(
                      'Pet Showcase',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 10),
                    // Visibility Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _pet.visibility == 'PUBLIC'
                            ? Colors.green.withValues(alpha: 0.12)
                            : _pet.visibility == 'CONNECTIONS'
                                ? Colors.blue.withValues(alpha: 0.12)
                                : Colors.orange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _pet.visibility == 'PUBLIC'
                              ? Colors.green.withValues(alpha: 0.3)
                              : _pet.visibility == 'CONNECTIONS'
                                  ? Colors.blue.withValues(alpha: 0.3)
                                  : Colors.orange.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _pet.visibility == 'PUBLIC'
                                ? Icons.public
                                : _pet.visibility == 'CONNECTIONS'
                                    ? Icons.people
                                    : Icons.lock,
                            size: 11,
                            color: _pet.visibility == 'PUBLIC'
                                ? Colors.green[700]
                                : _pet.visibility == 'CONNECTIONS'
                                    ? Colors.blue[700]
                                    : Colors.orange[800],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _pet.visibility == 'PUBLIC'
                                ? 'Public'
                                : _pet.visibility == 'CONNECTIONS'
                                    ? 'Connections'
                                    : 'Private',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: _pet.visibility == 'PUBLIC'
                                  ? Colors.green[700]
                                  : _pet.visibility == 'CONNECTIONS'
                                      ? Colors.blue[700]
                                      : Colors.orange[800],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          if (_isLoadingDetails)
            const LinearProgressIndicator(minHeight: 2, color: AppColors.primary),
          const Divider(height: 1),

          // Scrollable Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Pet Profile Card / Header
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Photo
                      GestureDetector(
                        onTap: hasPhoto ? () => _showEnlargedPhoto(_pet.avatarUrl!.trim()) : null,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 84,
                              height: 84,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.primaryContainer.withValues(alpha: 0.35),
                                border: Border.all(color: AppColors.primary.withValues(alpha: 0.4), width: 2.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: hasPhoto
                                    ? CachedNetworkImage(
                                        imageUrl: _pet.avatarUrl!.trim(),
                                        width: 84,
                                        height: 84,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) => Container(
                                          color: AppColors.primaryContainer.withValues(alpha: 0.2),
                                          child: const Center(
                                            child: SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            ),
                                          ),
                                        ),
                                        errorWidget: (context, url, error) => Container(
                                          color: AppColors.primaryContainer.withValues(alpha: 0.2),
                                          alignment: Alignment.center,
                                          child: Text(_pet.speciesEmoji, style: const TextStyle(fontSize: 38)),
                                        ),
                                      )
                                    : Container(
                                        alignment: Alignment.center,
                                        child: Text(_pet.speciesEmoji, style: const TextStyle(fontSize: 38)),
                                      ),
                              ),
                            ),
                            if (hasPhoto)
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: const Icon(Icons.fullscreen, size: 14, color: Colors.white),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Core details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _pet.name,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            // Species & Sex chips
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryContainer.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${_pet.speciesEmoji} ${_pet.displaySpecies}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                                if (_pet.sex != null && _pet.sex != 'UNKNOWN') ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: _pet.sex == 'MALE'
                                          ? Colors.blue.withValues(alpha: 0.15)
                                          : Colors.pink.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      _pet.sex == 'MALE' ? '♂ Male' : '♀ Female',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: _pet.sex == 'MALE' ? Colors.blue[700] : Colors.pink[700],
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if (_pet.displayBreed != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                _pet.displayBreed!,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                            ],
                            if (_pet.formattedAge != null) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.cake_outlined, size: 14, color: AppColors.primary),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      _pet.formattedAge!,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.onSurface,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Bio / Story
                  if (_pet.bio != null && _pet.bio!.trim().isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.surfaceContainerHigh.withValues(alpha: 0.6)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.format_quote, size: 16, color: AppColors.primary),
                              const SizedBox(width: 4),
                              Text(
                                'About ${_pet.name}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _pet.bio!.trim(),
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.45,
                              color: AppColors.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Showcase Attributes
                  const SizedBox(height: 20),
                  const Text(
                    'Profile Details',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.onSurface),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _infoBadge('Species', _pet.displaySpecies, Icons.pets),
                      if (_pet.breed != null && _pet.breed!.isNotEmpty)
                        _infoBadge('Primary Breed', _pet.breed!, Icons.category_outlined),
                      if (_pet.breedSecondary != null && _pet.breedSecondary!.isNotEmpty)
                        _infoBadge('Secondary Breed', _pet.breedSecondary!, Icons.tune),
                      if (_pet.sex != null && _pet.sex != 'UNKNOWN')
                        _infoBadge('Sex', _pet.sex == 'MALE' ? 'Male' : 'Female', Icons.transgender),
                      if (_pet.size != null && _pet.size!.isNotEmpty)
                        _infoBadge('Size', _formatSize(_pet.size!), Icons.straighten),
                      if (_pet.color != null && _pet.color!.isNotEmpty)
                        _infoBadge('Color', _pet.color!, Icons.palette_outlined),
                      if (_pet.dateOfBirth != null && _pet.dateOfBirth!.isNotEmpty)
                        _infoBadge(
                          _pet.isDateOfBirthApproximate ? 'Approx. Birthday' : 'Date of Birth',
                          _pet.dateOfBirth!,
                          Icons.calendar_today,
                        ),
                      if (_pet.formattedLocation != null)
                        _infoBadge('Location', _pet.formattedLocation!, Icons.location_on_outlined),
                    ],
                  ),

                  // Pet Parents & Guardians
                  if (_pet.parents.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.supervisor_account, size: 18, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Text(
                              'Pet Parents & Guardians (${_pet.parents.length})',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.onSurface,
                              ),
                            ),
                          ],
                        ),
                        if (_pet.permissions.canManageParents || widget.isOwnProfile)
                          TextButton.icon(
                            onPressed: _openInviteSheet,
                            icon: const Icon(Icons.person_add_alt_1, size: 14, color: AppColors.primary),
                            label: const Text(
                              'Invite',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
                        children: _pet.parents.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final p = entry.value;
                          final hasBorder = idx < _pet.parents.length - 1;

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
                                backgroundImage: p.avatarUrl.isNotEmpty
                                    ? CachedNetworkImageProvider(p.avatarUrl)
                                    : null,
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
                                      : AppColors.surfaceContainerHigh,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  p.isPrimary ? 'Primary Owner' : p.relationshipType.replaceAll('_', ' '),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: p.isPrimary ? AppColors.primary : AppColors.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),
                  // Button to Open Full Showcase (Gallery & Posts)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (ctx) => PetProfileScreen(
                              petId: _pet.id,
                              initialPet: _pet,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.auto_awesome, size: 16),
                      label: const Text('View Full Showcase (Gallery & Posts)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),

                  // Action Buttons
                  if (canEdit || _pet.permissions.canManageParents) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (canEdit) ...[
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _openEditSheet,
                              icon: const Icon(Icons.edit, size: 16),
                              label: const Text('Edit Details'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (_pet.permissions.canManageParents || widget.isOwnProfile) ...[
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _openInviteSheet,
                              icon: const Icon(Icons.person_add_alt_1, size: 16),
                              label: const Text('Invite Co-Parent'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (canEdit)
                          IconButton.outlined(
                            onPressed: _confirmDeletePet,
                            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                            tooltip: 'Delete Pet',
                            style: IconButton.styleFrom(
                              side: const BorderSide(color: Colors.red),
                              padding: const EdgeInsets.all(10),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoBadge(String label, String value, IconData icon) {
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

  String _formatSize(String size) {
    switch (size.toUpperCase()) {
      case 'EXTRA_SMALL':
        return 'Extra Small (< 5 kg)';
      case 'SMALL':
        return 'Small (5 - 10 kg)';
      case 'MEDIUM':
        return 'Medium (10 - 25 kg)';
      case 'LARGE':
        return 'Large (25 - 45 kg)';
      case 'EXTRA_LARGE':
        return 'Extra Large (45+ kg)';
      default:
        return size;
    }
  }
}

class _EditPetBottomSheet extends StatefulWidget {
  final Pet pet;
  final ValueChanged<Pet>? onPetUpdated;

  const _EditPetBottomSheet({
    required this.pet,
    this.onPetUpdated,
  });

  @override
  State<_EditPetBottomSheet> createState() => _EditPetBottomSheetState();
}

class _EditPetBottomSheetState extends State<_EditPetBottomSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _speciesNameController;
  late final TextEditingController _breedController;
  late final TextEditingController _breedSecondaryController;
  late final TextEditingController _colorController;
  late final TextEditingController _bioController;
  late final TextEditingController _countryController;
  late final TextEditingController _stateController;
  late final TextEditingController _cityController;
  late final TextEditingController _approxMonthsController;

  late String _selectedSpecies;
  late String _selectedSex;
  late String _selectedSize;
  late String _selectedVisibility;
  DateTime? _selectedBirthDate;
  bool _useApproxAge = false;

  String? _uploadedPhotoUrl;
  String? _uploadedPhotoMediaId;
  String? _localPhotoPath;
  bool _isUploadingPhoto = false;
  bool _isLoading = false;

  final List<Map<String, String>> _speciesList = const [
    {'value': 'DOG', 'label': 'Dog 🐶'},
    {'value': 'CAT', 'label': 'Cat 🐱'},
    {'value': 'BIRD', 'label': 'Bird 🦜'},
    {'value': 'RABBIT', 'label': 'Rabbit 🐰'},
    {'value': 'FISH', 'label': 'Fish 🐠'},
    {'value': 'HAMSTER', 'label': 'Hamster 🐹'},
    {'value': 'HORSE', 'label': 'Horse 🐴'},
    {'value': 'REPTILE', 'label': 'Reptile 🦎'},
    {'value': 'OTHER', 'label': 'Other 🐾'},
  ];

  final List<Map<String, String>> _sexList = const [
    {'value': 'UNKNOWN', 'label': 'Unknown / Not specified'},
    {'value': 'MALE', 'label': 'Male ♂'},
    {'value': 'FEMALE', 'label': 'Female ♀'},
  ];

  final List<Map<String, String>> _sizeList = const [
    {'value': '', 'label': 'Not specified'},
    {'value': 'EXTRA_SMALL', 'label': 'Extra Small (< 5 kg)'},
    {'value': 'SMALL', 'label': 'Small (5 - 10 kg)'},
    {'value': 'MEDIUM', 'label': 'Medium (10 - 25 kg)'},
    {'value': 'LARGE', 'label': 'Large (25 - 45 kg)'},
    {'value': 'EXTRA_LARGE', 'label': 'Extra Large (45+ kg)'},
  ];

  final List<Map<String, String>> _visibilityList = const [
    {'value': 'PUBLIC', 'label': 'Public (Visible on your profile & search)'},
    {'value': 'CONNECTIONS', 'label': 'Connections Only (Followers & mutuals)'},
    {'value': 'PRIVATE', 'label': 'Private (Only you & authorized parents)'},
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.pet;
    _nameController = TextEditingController(text: p.name);
    _speciesNameController = TextEditingController(text: p.speciesName ?? '');
    _breedController = TextEditingController(text: p.breed ?? '');
    _breedSecondaryController = TextEditingController(text: p.breedSecondary ?? '');
    _colorController = TextEditingController(text: p.color ?? '');
    _bioController = TextEditingController(text: p.bio ?? '');
    _countryController = TextEditingController(text: p.country ?? '');
    _stateController = TextEditingController(text: p.state ?? '');
    _cityController = TextEditingController(text: p.city ?? '');
    _approxMonthsController = TextEditingController(
      text: p.approximateAgeMonths != null ? p.approximateAgeMonths.toString() : '',
    );

    _selectedSpecies = p.species.toUpperCase();
    if (!_speciesList.any((s) => s['value'] == _selectedSpecies)) {
      _selectedSpecies = 'OTHER';
    }

    _selectedSex = (p.sex ?? 'UNKNOWN').toUpperCase();
    if (!_sexList.any((s) => s['value'] == _selectedSex)) {
      _selectedSex = 'UNKNOWN';
    }

    _selectedSize = (p.size ?? '').toUpperCase();
    if (!_sizeList.any((s) => s['value'] == _selectedSize)) {
      _selectedSize = '';
    }

    _selectedVisibility = (p.visibility).toUpperCase();
    if (!_visibilityList.any((v) => v['value'] == _selectedVisibility)) {
      _selectedVisibility = 'PUBLIC';
    }

    _useApproxAge = p.isDateOfBirthApproximate;
    if (p.dateOfBirth != null && p.dateOfBirth!.isNotEmpty) {
      try {
        _selectedBirthDate = DateTime.parse(p.dateOfBirth!);
      } catch (_) {}
    }

    _uploadedPhotoUrl = p.avatarUrl;
  }

  Future<void> _pickPetPhoto() async {
    setState(() => _isUploadingPhoto = true);
    try {
      final res = await MediaUploadHelper.showPickerAndUpload(
        context,
        title: 'Change Pet Profile Photo',
        allowVideo: false,
      );
      if (mounted && res != null) {
        setState(() {
          _localPhotoPath = res.localPath;
          if (res.uploadedUrl != null && res.uploadedUrl!.isNotEmpty) {
            _uploadedPhotoUrl = res.uploadedUrl;
          }
          if (res.mediaId != null && res.mediaId!.isNotEmpty) {
            _uploadedPhotoMediaId = res.mediaId;
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
      }
    }
  }

  void _removePetPhoto() {
    setState(() {
      _localPhotoPath = null;
      _uploadedPhotoUrl = null;
      _uploadedPhotoMediaId = null;
    });
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthDate ?? DateTime(now.year - 2, now.month, now.day),
      firstDate: DateTime(now.year - 35),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.onSurface,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedBirthDate = picked;
        _useApproxAge = false;
      });
    }
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your pet\'s name')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final Map<String, dynamic> updatePayload = {
      'name': name,
      'species': _selectedSpecies,
      'species_name': _selectedSpecies == 'OTHER' ? _speciesNameController.text.trim() : null,
      'breed': _breedController.text.trim(),
      'breed_secondary': _breedSecondaryController.text.trim(),
      'sex': _selectedSex,
      'size': _selectedSize.isNotEmpty ? _selectedSize : null,
      'color': _colorController.text.trim(),
      'bio': _bioController.text.trim(),
      'country': _countryController.text.trim(),
      'state': _stateController.text.trim(),
      'city': _cityController.text.trim(),
      'profile_visibility': _selectedVisibility,
    };

    if (_useApproxAge && _approxMonthsController.text.trim().isNotEmpty) {
      final months = int.tryParse(_approxMonthsController.text.trim());
      if (months != null && months > 0) {
        updatePayload['approximate_age_months'] = months;
        updatePayload['is_date_of_birth_approximate'] = true;
        updatePayload['date_of_birth'] = null;
      }
    } else if (_selectedBirthDate != null) {
      final d = _selectedBirthDate!;
      updatePayload['date_of_birth'] =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      updatePayload['is_date_of_birth_approximate'] = false;
    }

    if (_uploadedPhotoUrl != null && _uploadedPhotoUrl!.isNotEmpty) {
      updatePayload['profile_photo_url'] = _uploadedPhotoUrl;
      updatePayload['profile_media_url'] = _uploadedPhotoUrl;
    }
    if (_uploadedPhotoMediaId != null && _uploadedPhotoMediaId!.isNotEmpty) {
      updatePayload['profile_media_id'] = _uploadedPhotoMediaId;
    }

    final res = await ApiService().updatePet(widget.pet.id, updatePayload);
    setState(() => _isLoading = false);

    if (mounted) {
      if (res['success'] != false) {
        Pet? updatedPet;
        if (res['data'] is Map) {
          updatedPet = Pet.fromJson(Map<String, dynamic>.from(res['data']));
        } else {
          updatedPet = await ApiService().getPetById(widget.pet.id);
        }

        if (!mounted) return;
        if (updatedPet != null) {
          widget.onPetUpdated?.call(updatedPet);
        }
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${widget.pet.name}\'s profile was updated!')),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message']?.toString() ?? 'Failed to update pet')),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _speciesNameController.dispose();
    _breedController.dispose();
    _breedSecondaryController.dispose();
    _colorController.dispose();
    _bioController.dispose();
    _countryController.dispose();
    _stateController.dispose();
    _cityController.dispose();
    _approxMonthsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final maxHeight = MediaQuery.of(context).size.height * 0.90;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Edit ${widget.pet.name}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Scrollable Form Fields
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + bottomInset),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Photo management
                  Center(
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            GestureDetector(
                              onTap: _isUploadingPhoto ? null : _pickPetPhoto,
                              child: Container(
                                width: 96,
                                height: 96,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.primaryContainer.withValues(alpha: 0.35),
                                  border: Border.all(
                                    color: AppColors.primary.withValues(alpha: 0.5),
                                    width: 2.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.06),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: _isUploadingPhoto
                                      ? const Center(
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: AppColors.primary,
                                          ),
                                        )
                                      : _localPhotoPath != null &&
                                              File(_localPhotoPath!).existsSync()
                                          ? Image.file(
                                              File(_localPhotoPath!),
                                              fit: BoxFit.cover,
                                              width: 96,
                                              height: 96,
                                            )
                                          : _uploadedPhotoUrl != null &&
                                                  _uploadedPhotoUrl!.isNotEmpty
                                              ? CachedNetworkImage(
                                                  imageUrl: _uploadedPhotoUrl!,
                                                  fit: BoxFit.cover,
                                                  width: 96,
                                                  height: 96,
                                                  errorWidget: (_, _, _) =>
                                                      const Icon(Icons.pets, size: 44, color: AppColors.primary),
                                                )
                                              : const Center(
                                                  child: Icon(Icons.pets, size: 44, color: AppColors.primary),
                                                ),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: _isUploadingPhoto ? null : _pickPetPhoto,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextButton.icon(
                              onPressed: _isUploadingPhoto ? null : _pickPetPhoto,
                              icon: const Icon(Icons.photo_library, size: 16),
                              label: Text(
                                _uploadedPhotoUrl != null || _localPhotoPath != null
                                    ? 'Change Profile Photo'
                                    : 'Upload Profile Photo',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                            if (_uploadedPhotoUrl != null || _localPhotoPath != null)
                              TextButton(
                                onPressed: _removePetPhoto,
                                child: const Text(
                                  'Remove',
                                  style: TextStyle(fontSize: 12, color: Colors.red),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Name
                  _buildLabel('Pet Name *'),
                  TextField(
                    controller: _nameController,
                    decoration: _inputDecoration('e.g. Bella, Bruno, Milo'),
                  ),
                  const SizedBox(height: 14),

                  // Species
                  _buildLabel('Species *'),
                  DropdownButtonFormField<String>(
                    value: _selectedSpecies,
                    decoration: _inputDecoration('Select species'),
                    items: _speciesList
                        .map((s) => DropdownMenuItem(value: s['value'], child: Text(s['label']!)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedSpecies = val);
                    },
                  ),
                  if (_selectedSpecies == 'OTHER') ...[
                    const SizedBox(height: 10),
                    _buildLabel('Specify Species *'),
                    TextField(
                      controller: _speciesNameController,
                      decoration: _inputDecoration('e.g. Parrot, Ferret, Turtle'),
                    ),
                  ],
                  const SizedBox(height: 14),

                  // Primary & Secondary Breed
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Primary Breed'),
                            TextField(
                              controller: _breedController,
                              decoration: _inputDecoration('e.g. Golden Retriever'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Secondary Breed (Mix)'),
                            TextField(
                              controller: _breedSecondaryController,
                              decoration: _inputDecoration('e.g. Poodle Mix'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Sex
                  _buildLabel('Sex'),
                  DropdownButtonFormField<String>(
                    value: _selectedSex,
                    decoration: _inputDecoration('Select sex'),
                    items: _sexList
                        .map((s) => DropdownMenuItem(value: s['value'], child: Text(s['label']!)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedSex = val);
                    },
                  ),
                  const SizedBox(height: 14),

                  // Birthday / Age
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildLabel('Date of Birth / Age'),
                      Row(
                        children: [
                          Checkbox(
                            value: _useApproxAge,
                            onChanged: (val) => setState(() => _useApproxAge = val ?? false),
                          ),
                          const Text('Approx. age', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                  if (_useApproxAge)
                    TextField(
                      controller: _approxMonthsController,
                      keyboardType: TextInputType.number,
                      decoration: _inputDecoration('Approximate age in months (e.g. 18)'),
                    )
                  else
                    InkWell(
                      onTap: _pickBirthDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.surfaceContainerHigh),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 16, color: AppColors.primary),
                            const SizedBox(width: 10),
                            Text(
                              _selectedBirthDate != null
                                  ? '${_selectedBirthDate!.year}-${_selectedBirthDate!.month.toString().padLeft(2, '0')}-${_selectedBirthDate!.day.toString().padLeft(2, '0')}'
                                  : 'Tap to select birth date',
                              style: TextStyle(
                                fontSize: 13,
                                color: _selectedBirthDate != null
                                    ? AppColors.onSurface
                                    : AppColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 14),

                  // Size & Color
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Size'),
                            DropdownButtonFormField<String>(
                              value: _selectedSize,
                              decoration: _inputDecoration('Select size'),
                              items: _sizeList
                                  .map((s) => DropdownMenuItem(value: s['value'], child: Text(s['label']!)))
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedSize = val);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Color / Coat'),
                            TextField(
                              controller: _colorController,
                              decoration: _inputDecoration('e.g. Golden, Brown'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Location (Country, State, City)
                  _buildLabel('Location (City, State, Country)'),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _cityController,
                          decoration: _inputDecoration('City'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _stateController,
                          decoration: _inputDecoration('State'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _countryController,
                          decoration: _inputDecoration('Country'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Bio / Story
                  _buildLabel('Bio / Story'),
                  TextField(
                    controller: _bioController,
                    maxLines: 3,
                    decoration: _inputDecoration('Share a brief bio, habits, or favorite toys...'),
                  ),
                  const SizedBox(height: 14),

                  // Visibility Settings
                  _buildLabel('Showcase Visibility'),
                  DropdownButtonFormField<String>(
                    value: _selectedVisibility,
                    decoration: _inputDecoration('Select visibility'),
                    items: _visibilityList
                        .map((v) => DropdownMenuItem(
                              value: v['value'],
                              child: Text(v['label']!, style: const TextStyle(fontSize: 12)),
                            ))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedVisibility = val);
                    },
                  ),
                  const SizedBox(height: 24),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text(
                              'Save Changes',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.onSurface),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      filled: true,
      fillColor: AppColors.surfaceContainerLow,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.surfaceContainerHigh),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.surfaceContainerHigh),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );
  }
}

class _AddPetBottomSheet extends StatefulWidget {
  final VoidCallback? onPetCreated;

  const _AddPetBottomSheet({this.onPetCreated});

  @override
  State<_AddPetBottomSheet> createState() => _AddPetBottomSheetState();
}

class _AddPetBottomSheetState extends State<_AddPetBottomSheet> {
  final _nameController = TextEditingController();
  final _speciesNameController = TextEditingController();
  final _breedController = TextEditingController();
  final _breedSecondaryController = TextEditingController();
  final _colorController = TextEditingController();
  final _bioController = TextEditingController();
  final _countryController = TextEditingController();
  final _stateController = TextEditingController();
  final _cityController = TextEditingController();
  final _approxMonthsController = TextEditingController();

  String _selectedSpecies = 'DOG';
  String _selectedSex = 'UNKNOWN';
  String _selectedSize = '';
  String _selectedVisibility = 'PUBLIC';
  DateTime? _selectedBirthDate;
  bool _useApproxAge = false;

  String? _uploadedPhotoUrl;
  String? _uploadedPhotoMediaId;
  String? _localPhotoPath;
  bool _isUploadingPhoto = false;
  bool _isLoading = false;

  final List<Map<String, String>> _speciesList = const [
    {'value': 'DOG', 'label': 'Dog 🐶'},
    {'value': 'CAT', 'label': 'Cat 🐱'},
    {'value': 'BIRD', 'label': 'Bird 🦜'},
    {'value': 'RABBIT', 'label': 'Rabbit 🐰'},
    {'value': 'FISH', 'label': 'Fish 🐠'},
    {'value': 'HAMSTER', 'label': 'Hamster 🐹'},
    {'value': 'HORSE', 'label': 'Horse 🐴'},
    {'value': 'REPTILE', 'label': 'Reptile 🦎'},
    {'value': 'OTHER', 'label': 'Other 🐾'},
  ];

  final List<Map<String, String>> _sexList = const [
    {'value': 'UNKNOWN', 'label': 'Unknown / Not specified'},
    {'value': 'MALE', 'label': 'Male ♂'},
    {'value': 'FEMALE', 'label': 'Female ♀'},
  ];

  final List<Map<String, String>> _sizeList = const [
    {'value': '', 'label': 'Not specified'},
    {'value': 'EXTRA_SMALL', 'label': 'Extra Small (< 5 kg)'},
    {'value': 'SMALL', 'label': 'Small (5 - 10 kg)'},
    {'value': 'MEDIUM', 'label': 'Medium (10 - 25 kg)'},
    {'value': 'LARGE', 'label': 'Large (25 - 45 kg)'},
    {'value': 'EXTRA_LARGE', 'label': 'Extra Large (45+ kg)'},
  ];

  Future<void> _pickPetPhoto() async {
    setState(() => _isUploadingPhoto = true);
    try {
      final res = await MediaUploadHelper.showPickerAndUpload(
        context,
        title: 'Upload Pet Profile Photo',
        allowVideo: false,
      );
      if (mounted && res != null) {
        setState(() {
          _localPhotoPath = res.localPath;
          if (res.uploadedUrl != null && res.uploadedUrl!.isNotEmpty) {
            _uploadedPhotoUrl = res.uploadedUrl;
          }
          if (res.mediaId != null && res.mediaId!.isNotEmpty) {
            _uploadedPhotoMediaId = res.mediaId;
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
      }
    }
  }

  void _removePetPhoto() {
    setState(() {
      _localPhotoPath = null;
      _uploadedPhotoUrl = null;
      _uploadedPhotoMediaId = null;
    });
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthDate ?? DateTime(now.year - 2, now.month, now.day),
      firstDate: DateTime(now.year - 35),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.onSurface,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedBirthDate = picked;
        _useApproxAge = false;
      });
    }
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your pet\'s name')),
      );
      return;
    }

    if (_selectedSpecies == 'OTHER' && _speciesNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please specify the species name')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final Map<String, dynamic> petPayload = {
      'name': name,
      'species': _selectedSpecies,
      'sex': _selectedSex,
      'visibility': _selectedVisibility,
      'profile_visibility': _selectedVisibility,
    };

    if (_selectedSpecies == 'OTHER' && _speciesNameController.text.trim().isNotEmpty) {
      petPayload['species_name'] = _speciesNameController.text.trim();
    }
    if (_breedController.text.trim().isNotEmpty) {
      petPayload['breed'] = _breedController.text.trim();
    }
    if (_breedSecondaryController.text.trim().isNotEmpty) {
      petPayload['breed_secondary'] = _breedSecondaryController.text.trim();
    }
    if (_colorController.text.trim().isNotEmpty) {
      petPayload['color'] = _colorController.text.trim();
    }
    if (_selectedSize.isNotEmpty) {
      petPayload['size'] = _selectedSize;
    }
    if (_bioController.text.trim().isNotEmpty) {
      petPayload['bio'] = _bioController.text.trim();
    }
    if (_countryController.text.trim().isNotEmpty) {
      petPayload['country'] = _countryController.text.trim();
    }
    if (_stateController.text.trim().isNotEmpty) {
      petPayload['state'] = _stateController.text.trim();
    }
    if (_cityController.text.trim().isNotEmpty) {
      petPayload['city'] = _cityController.text.trim();
    }

    // Age / Birthday logic
    if (_useApproxAge && _approxMonthsController.text.trim().isNotEmpty) {
      final months = int.tryParse(_approxMonthsController.text.trim());
      if (months != null && months > 0) {
        petPayload['approximate_age_months'] = months;
        petPayload['is_date_of_birth_approximate'] = true;
      }
    } else if (_selectedBirthDate != null) {
      final d = _selectedBirthDate!;
      petPayload['date_of_birth'] =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      petPayload['is_date_of_birth_approximate'] = false;
    }

    // Photo URL
    if (_uploadedPhotoUrl != null && _uploadedPhotoUrl!.isNotEmpty) {
      petPayload['profile_photo_url'] = _uploadedPhotoUrl;
      petPayload['profile_media_url'] = _uploadedPhotoUrl;
    }
    if (_uploadedPhotoMediaId != null && _uploadedPhotoMediaId!.isNotEmpty) {
      petPayload['profile_media_id'] = _uploadedPhotoMediaId;
    }

    final res = await ApiService().createPet(petPayload);
    setState(() => _isLoading = false);

    if (mounted) {
      if (res['success'] != false) {
        Navigator.pop(context);
        widget.onPetCreated?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$name added to your showcase!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message']?.toString() ?? 'Failed to add pet')),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _speciesNameController.dispose();
    _breedController.dispose();
    _breedSecondaryController.dispose();
    _colorController.dispose();
    _bioController.dispose();
    _countryController.dispose();
    _stateController.dispose();
    _cityController.dispose();
    _approxMonthsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final maxHeight = MediaQuery.of(context).size.height * 0.90;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Add Pet Companion',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Scrollable Form Fields
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + bottomInset),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Pet Profile Photo (NO cover image)
                  Center(
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            GestureDetector(
                              onTap: _isUploadingPhoto ? null : _pickPetPhoto,
                              child: Container(
                                width: 96,
                                height: 96,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.primaryContainer.withValues(alpha: 0.35),
                                  border: Border.all(
                                    color: AppColors.primary.withValues(alpha: 0.5),
                                    width: 2.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.06),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: _isUploadingPhoto
                                      ? const Center(
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: AppColors.primary,
                                          ),
                                        )
                                      : _localPhotoPath != null &&
                                              File(_localPhotoPath!).existsSync()
                                          ? Image.file(
                                              File(_localPhotoPath!),
                                              fit: BoxFit.cover,
                                              width: 96,
                                              height: 96,
                                            )
                                          : _uploadedPhotoUrl != null &&
                                                  _uploadedPhotoUrl!.isNotEmpty
                                              ? CachedNetworkImage(
                                                  imageUrl: _uploadedPhotoUrl!,
                                                  fit: BoxFit.cover,
                                                  width: 96,
                                                  height: 96,
                                                  errorWidget: (_, _, _) =>
                                                      const Icon(Icons.pets, size: 44, color: AppColors.primary),
                                                )
                                              : const Center(
                                                  child: Icon(Icons.pets, size: 44, color: AppColors.primary),
                                                ),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: _isUploadingPhoto ? null : _pickPetPhoto,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextButton.icon(
                              onPressed: _isUploadingPhoto ? null : _pickPetPhoto,
                              icon: const Icon(Icons.photo_library, size: 16),
                              label: Text(
                                _uploadedPhotoUrl != null || _localPhotoPath != null
                                    ? 'Change Profile Photo'
                                    : 'Upload Profile Photo',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                            if (_uploadedPhotoUrl != null || _localPhotoPath != null)
                              TextButton(
                                onPressed: _removePetPhoto,
                                child: const Text(
                                  'Remove',
                                  style: TextStyle(fontSize: 12, color: Colors.red),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Section Title: Basic Information
                  const Text(
                    'Basic Information',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.onSurface),
                  ),
                  const SizedBox(height: 12),

                  // Pet Name (Required)
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Pet Name *',
                      hintText: 'e.g. Luna, Milo, Charlie',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Species Dropdown (Required)
                  DropdownButtonFormField<String>(
                    initialValue: _selectedSpecies,
                    decoration: const InputDecoration(
                      labelText: 'Species *',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: _speciesList
                        .map((s) => DropdownMenuItem(value: s['value'], child: Text(s['label']!)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedSpecies = val);
                    },
                  ),

                  // Custom Species Name (if Species == OTHER)
                  if (_selectedSpecies == 'OTHER') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _speciesNameController,
                      decoration: const InputDecoration(
                        labelText: 'Species Name (e.g. Ferret, Hedgehog) *',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),

                  // Breed & Secondary Breed
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _breedController,
                          decoration: const InputDecoration(
                            labelText: 'Breed (optional)',
                            hintText: 'e.g. Golden Retriever',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _breedSecondaryController,
                          decoration: const InputDecoration(
                            labelText: 'Mix / 2nd Breed',
                            hintText: 'e.g. Poodle Mix',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Sex & Size
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedSex,
                          decoration: const InputDecoration(
                            labelText: 'Sex',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: _sexList
                              .map((s) => DropdownMenuItem(value: s['value'], child: Text(s['label']!)))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedSex = val);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedSize,
                          decoration: const InputDecoration(
                            labelText: 'Size',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: _sizeList
                              .map((s) => DropdownMenuItem(
                                    value: s['value'],
                                    child: Text(s['label']!, overflow: TextOverflow.ellipsis),
                                  ))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedSize = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Color / Markings
                  TextField(
                    controller: _colorController,
                    decoration: const InputDecoration(
                      labelText: 'Color / Markings',
                      hintText: 'e.g. Golden Brown, White with black spots',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Section: Age / Birthday
                  const Text(
                    'Age & Birthday',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.onSurface),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ChoiceChip(
                        label: const Text('Exact Birthday'),
                        selected: !_useApproxAge,
                        onSelected: (selected) {
                          if (selected) setState(() => _useApproxAge = false);
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Approximate Age'),
                        selected: _useApproxAge,
                        onSelected: (selected) {
                          if (selected) setState(() => _useApproxAge = true);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (!_useApproxAge) ...[
                    OutlinedButton.icon(
                      onPressed: _pickBirthDate,
                      icon: const Icon(Icons.cake_outlined, size: 18),
                      label: Text(
                        _selectedBirthDate != null
                            ? 'Birthday: ${_selectedBirthDate!.year}-${_selectedBirthDate!.month.toString().padLeft(2, '0')}-${_selectedBirthDate!.day.toString().padLeft(2, '0')}'
                            : 'Select Date of Birth',
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 44),
                        alignment: Alignment.centerLeft,
                      ),
                    ),
                  ] else ...[
                    TextField(
                      controller: _approxMonthsController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Approximate Age (in months)',
                        hintText: 'e.g. 12 for 1 year, 24 for 2 years',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),

                  // Section: Location
                  const Text(
                    'Location',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.onSurface),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _cityController,
                          decoration: const InputDecoration(
                            labelText: 'City',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _stateController,
                          decoration: const InputDecoration(
                            labelText: 'State / Region',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _countryController,
                          decoration: const InputDecoration(
                            labelText: 'Country',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Section: Story / Bio
                  const Text(
                    'About & Story',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.onSurface),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _bioController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Bio / Personality / Story',
                      hintText: 'Tell the Peto community about their quirks, favorite toys, or rescue story...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Section: Visibility & Privacy
                  const Text(
                    'Showcase Privacy',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.onSurface),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedVisibility,
                    decoration: const InputDecoration(
                      labelText: 'Visibility',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'PUBLIC',
                        child: Row(
                          children: [
                            Icon(Icons.public, size: 16, color: Colors.green),
                            SizedBox(width: 8),
                            Text('Public (Everyone on Peto)'),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'CONNECTIONS',
                        child: Row(
                          children: [
                            Icon(Icons.people, size: 16, color: Colors.blue),
                            SizedBox(width: 8),
                            Text('Connections Only'),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'PRIVATE',
                        child: Row(
                          children: [
                            Icon(Icons.lock, size: 16, color: Colors.purple),
                            SizedBox(width: 8),
                            Text('Private (Pet Parents Only)'),
                          ],
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedVisibility = val);
                    },
                  ),
                  const SizedBox(height: 24),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 2,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            )
                          : const Text(
                              'Add to Pet Showcase',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
