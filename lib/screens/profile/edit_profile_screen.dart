import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/media_upload_helper.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();

  late TextEditingController _fullNameController;
  late TextEditingController _usernameController;
  late TextEditingController _bioController;
  late TextEditingController _locationController;
  late TextEditingController _websiteController;
  late TextEditingController _phoneController;
  late TextEditingController _avatarUrlController;
  late TextEditingController _coverUrlController;

  String? _localAvatarPath;
  String? _localCoverPath;
  bool _isUploadingAvatar = false;
  bool _isUploadingCover = false;

  String _originalUsername = '';
  DateTime? _selectedDateOfBirth;
  bool _isSaving = false;
  bool _isCheckingUsername = false;
  String? _usernameFeedback;
  bool? _isUsernameAvailable;

  void _pickAvatar() async {
    setState(() => _isUploadingAvatar = true);
    final res = await MediaUploadHelper.showPickerAndUpload(
      context,
      allowVideo: false,
      title: 'Upload Profile Avatar',
    );
    if (mounted) {
      setState(() {
        _isUploadingAvatar = false;
        if (res != null) {
          _localAvatarPath = res.localPath;
          if (res.uploadedUrl != null) {
            _avatarUrlController.text = res.uploadedUrl!;
          }
        }
      });
    }
  }

  void _pickCover() async {
    setState(() => _isUploadingCover = true);
    final res = await MediaUploadHelper.showPickerAndUpload(
      context,
      allowVideo: false,
      title: 'Upload Cover Photo',
    );
    if (mounted) {
      setState(() {
        _isUploadingCover = false;
        if (res != null) {
          _localCoverPath = res.localPath;
          if (res.uploadedUrl != null) {
            _coverUrlController.text = res.uploadedUrl!;
          }
        }
      });
    }
  }

  @override
  void initState() {
    super.initState();
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    _fullNameController = TextEditingController(text: user?.fullName ?? '');
    _usernameController = TextEditingController(text: user?.username ?? '');
    _originalUsername = user?.username ?? '';
    _bioController = TextEditingController(text: user?.bio ?? '');
    _locationController = TextEditingController(text: user?.location ?? '');
    _websiteController = TextEditingController(text: user?.website ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
    _avatarUrlController = TextEditingController(text: user?.avatarUrl ?? '');
    _coverUrlController = TextEditingController(text: user?.coverUrl ?? '');

    if (user?.dateOfBirth != null && user!.dateOfBirth!.isNotEmpty) {
      _selectedDateOfBirth = DateTime.tryParse(user.dateOfBirth!);
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    _locationController.dispose();
    _websiteController.dispose();
    _phoneController.dispose();
    _avatarUrlController.dispose();
    _coverUrlController.dispose();
    super.dispose();
  }

  Future<void> _checkUsernameAvailability() async {
    final clean = _usernameController.text.trim().toLowerCase();
    if (clean.isEmpty || clean == _originalUsername.toLowerCase()) {
      setState(() {
        _usernameFeedback = null;
        _isUsernameAvailable = true;
      });
      return;
    }

    if (!RegExp(r'^[a-z0-9_]{3,20}$').hasMatch(clean)) {
      setState(() {
        _usernameFeedback = '3-20 characters, lowercase, numbers, underscores';
        _isUsernameAvailable = false;
      });
      return;
    }

    setState(() {
      _isCheckingUsername = true;
      _usernameFeedback = null;
    });

    try {
      final res = await _apiService.checkUsername(clean);
      final isAvailable = res.data['available'] == true;
      if (mounted) {
        setState(() {
          _isUsernameAvailable = isAvailable;
          _usernameFeedback = isAvailable ? 'Username is available!' : 'Username is already taken';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isUsernameAvailable = false;
          _usernameFeedback = 'Could not verify username';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isCheckingUsername = false);
      }
    }
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDateOfBirth ?? DateTime(now.year - 20),
      firstDate: DateTime(1920),
      lastDate: now,
    );
    if (picked != null) {
      setState(() => _selectedDateOfBirth = picked);
    }
  }

  void _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isUsernameAvailable == false) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a valid, available username'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final updateData = {
      'full_name': _fullNameController.text.trim(),
      'username': _usernameController.text.trim().toLowerCase(),
      'bio': _bioController.text.trim(),
      'location': _locationController.text.trim(),
      'website': _websiteController.text.trim(),
      'phone': _phoneController.text.trim(),
      'avatar_url': _avatarUrlController.text.trim(),
      'cover_url': _coverUrlController.text.trim(),
      if (_selectedDateOfBirth != null)
        'date_of_birth': DateFormat('yyyy-MM-dd').format(_selectedDateOfBirth!),
    };

    final success = await authProvider.updateUserProfile(updateData);
    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: AppColors.primaryContainer,
          ),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update profile. Please try again.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final coverPreview = _coverUrlController.text.trim();
    final avatarPreview = _avatarUrlController.text.trim();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: _isSaving ? null : _saveProfile,
              child: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'Save',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppColors.primary,
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover Photo Banner with overlapping Avatar
              SizedBox(
                height: 200,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Cover Image Container
                    Container(
                      height: 140,
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                      ),
                      child: (_localCoverPath != null && File(_localCoverPath!).existsSync())
                          ? Image.file(
                              File(_localCoverPath!),
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: 140,
                            )
                          : coverPreview.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: coverPreview,
                                  fit: BoxFit.cover,
                                  placeholder: (_, _) => Container(color: AppColors.surfaceContainerLow),
                                  errorWidget: (_, _, _) => _buildCoverFallback(),
                                )
                              : _buildCoverFallback(),
                    ),

                    // Change Cover Button (Top/Bottom Right on Cover)
                    Positioned(
                      right: 16,
                      bottom: 12,
                      child: InkWell(
                        onTap: _isUploadingCover ? null : _pickCover,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_isUploadingCover)
                                const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              else
                                const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 16),
                              const SizedBox(width: 6),
                              const Text(
                                'Upload Cover',
                                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Avatar Overlap
                    Positioned(
                      left: 20,
                      bottom: 0,
                      child: Stack(
                        children: [
                          Container(
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
                              radius: 44,
                              backgroundColor: AppColors.primaryFixed,
                              backgroundImage: (_localAvatarPath != null && File(_localAvatarPath!).existsSync())
                                  ? FileImage(File(_localAvatarPath!))
                                  : avatarPreview.isNotEmpty
                                      ? CachedNetworkImageProvider(avatarPreview)
                                      : null,
                              child: (_localAvatarPath == null && avatarPreview.isEmpty)
                                  ? const Icon(Icons.person, size: 44, color: AppColors.primary)
                                  : null,
                            ),
                          ),

                          // Camera upload badge on Avatar
                          Positioned(
                            bottom: 2,
                            right: 2,
                            child: InkWell(
                              onTap: _isUploadingAvatar ? null : _pickAvatar,
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.surface, width: 2.5),
                                ),
                                child: _isUploadingAvatar
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Form fields section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Media Upload Quick Action Row
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _isUploadingAvatar ? null : _pickAvatar,
                              icon: const Icon(Icons.account_circle_outlined, size: 18),
                              label: const Text('Change Avatar'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _isUploadingCover ? null : _pickCover,
                              icon: const Icon(Icons.panorama_outlined, size: 18),
                              label: const Text('Change Cover'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    const Divider(height: 1, color: AppColors.surfaceContainerHigh),
                    const SizedBox(height: 20),

                    // Full Name
                    CustomTextField(
                      label: 'Full Name',
                      hint: 'e.g. Sarah Jenkins',
                      controller: _fullNameController,
                      prefixIcon: const Icon(Icons.person_outline, color: AppColors.outline),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Full name is required';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Username with check availability action
                    CustomTextField(
                      label: 'Username',
                      hint: 'e.g. sarah_pets',
                      controller: _usernameController,
                      prefixIcon: const Icon(Icons.alternate_email, color: AppColors.outline),
                      suffixIcon: _isCheckingUsername
                          ? const Padding(
                              padding: EdgeInsets.all(12.0),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : IconButton(
                              icon: const Icon(Icons.check_circle_outline, color: AppColors.primary),
                              onPressed: _checkUsernameAvailability,
                            ),
                      onChanged: (_) => setState(() {
                        _isUsernameAvailable = null;
                        _usernameFeedback = null;
                      }),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Username is required';
                        final clean = val.trim().toLowerCase();
                        if (!RegExp(r'^[a-z0-9_]{3,20}$').hasMatch(clean)) {
                          return '3-20 characters, lowercase, numbers, underscores only';
                        }
                        return null;
                      },
                    ),
                    if (_usernameFeedback != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _usernameFeedback!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: _isUsernameAvailable == true ? Colors.green : AppColors.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Bio
                    CustomTextField(
                      label: 'Bio',
                      hint: 'Tell the pet community about yourself and your pets...',
                      controller: _bioController,
                      prefixIcon: const Icon(Icons.description_outlined, color: AppColors.outline),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),

                    // Location
                    CustomTextField(
                      label: 'Location',
                      hint: 'e.g. Seattle, WA',
                      controller: _locationController,
                      prefixIcon: const Icon(Icons.location_on_outlined, color: AppColors.outline),
                    ),
                    const SizedBox(height: 16),

                    // Website
                    CustomTextField(
                      label: 'Website',
                      hint: 'https://sarahpets.com',
                      controller: _websiteController,
                      keyboardType: TextInputType.url,
                      prefixIcon: const Icon(Icons.language_outlined, color: AppColors.outline),
                    ),
                    const SizedBox(height: 16),

                    // Phone
                    CustomTextField(
                      label: 'Phone Number',
                      hint: '+1 555-0199',
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      prefixIcon: const Icon(Icons.phone_outlined, color: AppColors.outline),
                    ),
                    const SizedBox(height: 16),

                    // Date of Birth
                    InkWell(
                      onTap: _pickDateOfBirth,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.outline.withValues(alpha: 0.3)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.calendar_today_outlined, size: 20, color: AppColors.outline),
                                const SizedBox(width: 12),
                                Text(
                                  _selectedDateOfBirth != null
                                      ? DateFormat.yMMMd().format(_selectedDateOfBirth!)
                                      : 'Date of Birth (Optional)',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: _selectedDateOfBirth != null ? AppColors.onSurface : AppColors.outline,
                                  ),
                                ),
                              ],
                            ),
                            const Icon(Icons.arrow_drop_down, color: AppColors.outline),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Save Button
                    CustomButton(
                      text: 'Save Changes',
                      width: double.infinity,
                      isLoading: _isSaving,
                      onPressed: _saveProfile,
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
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
          size: 40,
          color: AppColors.outline.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}
