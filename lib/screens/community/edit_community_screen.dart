import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/community_model.dart';
import '../../services/api_service.dart';
import '../../services/media_upload_helper.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_button.dart';

class EditCommunityScreen extends StatefulWidget {
  final Community community;

  const EditCommunityScreen({
    super.key,
    required this.community,
  });

  @override
  State<EditCommunityScreen> createState() => _EditCommunityScreenState();
}

class _EditCommunityScreenState extends State<EditCommunityScreen> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _iconUrlController;
  late TextEditingController _coverUrlController;

  late String _selectedCategory;
  late String _visibility; // 'public' or 'private'

  bool _isLoading = false;
  bool _isUploadingIcon = false;
  bool _isUploadingCover = false;

  final List<String> _categories = [
    'Dogs',
    'Cats',
    'Birds',
    'Fish & Aquatics',
    'Reptiles',
    'Small Pets',
    'Pet Training',
    'Health & Care',
    'Adoption & Rescue',
    'General',
  ];

  @override
  void initState() {
    super.initState();
    final c = widget.community;
    _nameController = TextEditingController(text: c.name);
    _descriptionController = TextEditingController(text: c.description);
    _iconUrlController = TextEditingController(text: c.iconUrl ?? '');
    _coverUrlController = TextEditingController(text: c.coverImageUrl ?? '');

    _selectedCategory = _categories.contains(c.category) ? c.category : 'General';
    _visibility = c.visibility.toLowerCase() == 'private' ? 'private' : 'public';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _iconUrlController.dispose();
    _coverUrlController.dispose();
    super.dispose();
  }

  Future<void> _pickIcon() async {
    setState(() => _isUploadingIcon = true);
    final res = await MediaUploadHelper.showPickerAndUpload(
      context,
      allowVideo: false,
      title: 'Change Circle Icon',
    );
    if (mounted) {
      setState(() {
        _isUploadingIcon = false;
        if (res?.uploadedUrl != null) {
          _iconUrlController.text = res!.uploadedUrl!;
        }
      });
    }
  }

  Future<void> _pickCover() async {
    setState(() => _isUploadingCover = true);
    final res = await MediaUploadHelper.showPickerAndUpload(
      context,
      allowVideo: false,
      title: 'Change Cover Banner',
    );
    if (mounted) {
      setState(() {
        _isUploadingCover = false;
        if (res?.uploadedUrl != null) {
          _coverUrlController.text = res!.uploadedUrl!;
        }
      });
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final payload = {
      'name': _nameController.text.trim(),
      'description': _descriptionController.text.trim(),
      'category': _selectedCategory,
      'visibility': _visibility,
      'icon_url': _iconUrlController.text.trim().isNotEmpty ? _iconUrlController.text.trim() : null,
      'cover_image_url': _coverUrlController.text.trim().isNotEmpty ? _coverUrlController.text.trim() : null,
    };

    try {
      final response = await _apiService.updateCommunity(widget.community.id, payload);

      if (response.statusCode == 200) {
        final updatedCommunity = widget.community.copyWith(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          category: _selectedCategory,
          visibility: _visibility,
          iconUrl: _iconUrlController.text.trim().isNotEmpty ? _iconUrlController.text.trim() : null,
          coverImageUrl: _coverUrlController.text.trim().isNotEmpty ? _coverUrlController.text.trim() : null,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Community updated successfully!'),
              backgroundColor: AppColors.tertiary,
            ),
          );
          Navigator.pop(context, updatedCommunity);
        }
      } else {
        final msg = response.data is Map ? response.data['message'] : null;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg?.toString() ?? 'Failed to update community.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error updating community: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating community: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final coverUrl = _coverUrlController.text.trim();
    final iconUrl = _iconUrlController.text.trim();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Community', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: CustomButton(
              text: 'Save',
              isLoading: _isLoading || _isUploadingCover || _isUploadingIcon,
              width: 80,
              onPressed: _saveChanges,
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover Banner & Icon Visuals Editor
              const Text(
                'Circle Visuals',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.onSurface),
              ),
              const SizedBox(height: 10),

              // Banner Preview Container
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    height: 130,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.4)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: coverUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: coverUrl,
                              fit: BoxFit.cover,
                              errorWidget: (_, _, _) => _buildBannerPlaceholder(),
                            )
                          : _buildBannerPlaceholder(),
                    ),
                  ),

                  // Change Banner Button
                  Positioned(
                    top: 8,
                    right: 8,
                    child: ElevatedButton.icon(
                      onPressed: _isUploadingCover ? null : _pickCover,
                      icon: _isUploadingCover
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.camera_alt_outlined, size: 16),
                      label: const Text('Banner', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black.withValues(alpha: 0.65),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                    ),
                  ),

                  // Avatar Icon Overlap
                  Positioned(
                    left: 16,
                    bottom: -28,
                    child: Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 34,
                            backgroundColor: AppColors.primaryFixed,
                            backgroundImage: iconUrl.isNotEmpty ? CachedNetworkImageProvider(iconUrl) : null,
                            child: iconUrl.isEmpty
                                ? const Icon(Icons.pets, size: 30, color: AppColors.primary)
                                : null,
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: InkWell(
                            onTap: _isUploadingIcon ? null : _pickIcon,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: _isUploadingIcon
                                  ? const SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white),
                                    )
                                  : const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 48),

              // Community Name
              const Text(
                'Community Name',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.onSurface),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nameController,
                validator: (val) {
                  if (val == null || val.trim().length < 3) {
                    return 'Name must be at least 3 characters.';
                  }
                  if (val.trim().length > 100) {
                    return 'Name cannot exceed 100 characters.';
                  }
                  return null;
                },
                decoration: InputDecoration(
                  hintText: 'e.g. Golden Retriever Enthusiasts',
                  filled: true,
                  fillColor: AppColors.surfaceContainerLow,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppColors.outlineVariant.withValues(alpha: 0.4)),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // Category
              const Text(
                'Category',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.onSurface),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.4)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedCategory,
                    isExpanded: true,
                    items: _categories.map((cat) {
                      return DropdownMenuItem(value: cat, child: Text(cat));
                    }).toList(),
                    onChanged: (newVal) {
                      if (newVal != null) setState(() => _selectedCategory = newVal);
                    },
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // Description
              const Text(
                'Description',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.onSurface),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'What is your community circle about?',
                  filled: true,
                  fillColor: AppColors.surfaceContainerLow,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppColors.outlineVariant.withValues(alpha: 0.4)),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Privacy / Visibility Toggle
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _visibility == 'private' ? Icons.lock_outline : Icons.public,
                              color: AppColors.primary,
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _visibility == 'private' ? 'Private Community' : 'Public Community',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ],
                        ),
                        Switch(
                          value: _visibility == 'private',
                          activeThumbColor: AppColors.primary,
                          onChanged: (isPrivate) {
                            setState(() => _visibility = isPrivate ? 'private' : 'public');
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _visibility == 'private'
                          ? 'Only approved members can view discussions and media.'
                          : 'Anyone in Peto can view posts and join this circle freely.',
                      style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Save Button
              CustomButton(
                text: 'Save Community Changes',
                isLoading: _isLoading,
                onPressed: _saveChanges,
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBannerPlaceholder() {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_outlined, size: 28, color: AppColors.outline.withValues(alpha: 0.4)),
          const SizedBox(width: 8),
          Text(
            'Add Cover Banner',
            style: TextStyle(fontSize: 13, color: AppColors.outline.withValues(alpha: 0.6)),
          ),
        ],
      ),
    );
  }
}
