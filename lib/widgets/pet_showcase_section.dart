import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/pet_model.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/media_upload_helper.dart';

class PetShowcaseSection extends StatelessWidget {
  final List<Pet> pets;
  final bool isOwnProfile;
  final VoidCallback? onRefresh;

  const PetShowcaseSection({
    super.key,
    required this.pets,
    this.isOwnProfile = false,
    this.onRefresh,
  });

  void _showPetDetailsSheet(BuildContext context, Pet pet) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PetDetailsBottomSheet(pet: pet, onRefresh: onRefresh),
    );
  }

  void _showAddPetSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddPetBottomSheet(onPetCreated: onRefresh),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (pets.isEmpty && !isOwnProfile) {
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
                      isOwnProfile ? 'My Pets (${pets.length})' : 'Pets Showcase (${pets.length})',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.onSurface,
                      ),
                    ),
                  ],
                ),
                if (isOwnProfile)
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
          const SizedBox(height: 8),
          if (pets.isEmpty && isOwnProfile)
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
                itemCount: pets.length + (isOwnProfile ? 1 : 0),
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (ctx, idx) {
                  if (idx == pets.length && isOwnProfile) {
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

                  final pet = pets[idx];
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
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.primaryContainer.withValues(alpha: 0.4),
                  backgroundImage: pet.avatarUrl != null && pet.avatarUrl!.isNotEmpty
                      ? CachedNetworkImageProvider(pet.avatarUrl!)
                      : null,
                  child: pet.avatarUrl == null || pet.avatarUrl!.isEmpty
                      ? Text(pet.speciesEmoji, style: const TextStyle(fontSize: 24))
                      : null,
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
              pet.breed?.isNotEmpty == true ? pet.breed! : pet.displaySpecies,
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

class _PetDetailsBottomSheet extends StatelessWidget {
  final Pet pet;
  final VoidCallback? onRefresh;

  const _PetDetailsBottomSheet({required this.pet, this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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

            // Pet Header Row
            Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: AppColors.primaryContainer.withValues(alpha: 0.4),
                  backgroundImage: pet.avatarUrl != null && pet.avatarUrl!.isNotEmpty
                      ? CachedNetworkImageProvider(pet.avatarUrl!)
                      : null,
                  child: pet.avatarUrl == null || pet.avatarUrl!.isEmpty
                      ? Text(pet.speciesEmoji, style: const TextStyle(fontSize: 28))
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              pet.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.onSurface,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primaryContainer.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              pet.displaySpecies,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (pet.breed != null && pet.breed!.isNotEmpty)
                        Text(
                          pet.breed!,
                          style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                        ),
                      if (pet.formattedAge != null)
                        Text(
                          'Age: ${pet.formattedAge!}',
                          style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                        ),
                    ],
                  ),
                ),
              ],
            ),

            if (pet.bio != null && pet.bio!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  pet.bio!,
                  style: const TextStyle(fontSize: 12, height: 1.4, color: AppColors.onSurface),
                ),
              ),
            ],

            const SizedBox(height: 16),
            const Text(
              'Showcase Info',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.onSurface),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (pet.sex != null && pet.sex!.isNotEmpty)
                  _infoChip('Sex', pet.sex!),
                if (pet.size != null && pet.size!.isNotEmpty)
                  _infoChip('Size', pet.size!),
                if (pet.color != null && pet.color!.isNotEmpty)
                  _infoChip('Color', pet.color!),
                if (pet.city != null && pet.city!.isNotEmpty)
                  _infoChip('City', pet.city!),
                _infoChip('Visibility', pet.visibility),
              ],
            ),

            if (pet.parents.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Pet Parents & Guardians',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.onSurface),
              ),
              const SizedBox(height: 8),
              ...pet.parents.map(
                (p) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundImage: p.avatarUrl.isNotEmpty
                        ? CachedNetworkImageProvider(p.avatarUrl)
                        : null,
                    child: p.avatarUrl.isEmpty
                        ? Text(p.username.isNotEmpty ? p.username[0].toUpperCase() : 'P')
                        : null,
                  ),
                  title: Text(
                    p.fullName.isNotEmpty ? p.fullName : '@${p.username}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    p.isPrimary ? 'Primary Owner' : p.relationshipType,
                    style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.surfaceContainerHigh),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
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
