import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../services/media_upload_helper.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import 'login_screen.dart';

class CreateProfileScreen extends StatefulWidget {
  final String? prefilledUsername;
  final String? prefilledEmail;

  const CreateProfileScreen({
    super.key,
    this.prefilledUsername,
    this.prefilledEmail,
  });

  @override
  State<CreateProfileScreen> createState() => _CreateProfileScreenState();
}

class _CreateProfileScreenState extends State<CreateProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();
  final _locationController = TextEditingController();
  final _websiteController = TextEditingController();
  final _phoneController = TextEditingController();
  final _avatarUrlController = TextEditingController();

  String? _avatarLocalPath;
  String? _avatarUrl;
  bool _isUploadingAvatar = false;
  DateTime? _selectedDateOfBirth;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    _usernameController.text = widget.prefilledUsername ?? user?.username ?? '';
    _fullNameController.text = user?.fullName ?? '';
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
    super.dispose();
  }

  Future<void> _pickAndUploadAvatar() async {
    setState(() => _isUploadingAvatar = true);

    final result = await MediaUploadHelper.showPickerAndUpload(
      context,
      allowVideo: false,
      title: 'Upload Profile Photo',
    );

    if (mounted) {
      setState(() {
        _isUploadingAvatar = false;
        if (result != null && result.uploadedUrl != null) {
          _avatarLocalPath = result.localPath;
          _avatarUrl = result.uploadedUrl;
          _avatarUrlController.text = result.uploadedUrl!;
        }
      });
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

  void _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final effectiveAvatar = _avatarUrl ?? _avatarUrlController.text.trim();

    final profileData = {
      'fullName': _fullNameController.text.trim(),
      'username': _usernameController.text.trim().toLowerCase(),
      'bio': _bioController.text.trim(),
      'location': _locationController.text.trim(),
      'website': _websiteController.text.trim(),
      'phone': _phoneController.text.trim(),
      if (effectiveAvatar.isNotEmpty) 'avatar_url': effectiveAvatar,
      if (_selectedDateOfBirth != null)
        'dateOfBirth': DateFormat('yyyy-MM-dd').format(_selectedDateOfBirth!),
    };

    final success = await authProvider.createProfile(profileData);
    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        // Move to login screen as requested
        await authProvider.logout();
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => LoginScreen(
                initialEmail: widget.prefilledEmail,
                successMessage: 'Profile completed successfully! Please sign in to continue.',
              ),
            ),
            (route) => false,
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authProvider.errorMessage ?? 'Failed to complete profile'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _skipForNow() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.logout();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => LoginScreen(
            initialEmail: widget.prefilledEmail,
            successMessage: 'Account created! Please sign in to continue.',
          ),
        ),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveAvatar = _avatarUrl ?? _avatarUrlController.text.trim();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Profile'),
        actions: [
          TextButton(
            onPressed: _skipForNow,
            child: const Text('Skip', style: TextStyle(color: AppColors.outline, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Step Indicator Badge
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.looks_two_rounded, size: 16, color: AppColors.secondary),
                        SizedBox(width: 6),
                        Text(
                          'Step 2 of 2 • Profile Details',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                const Text(
                  'Complete Your Profile',
                  style: TextStyle(
                    fontFamily: 'Quicksand',
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Tell us a bit more about yourself to connect with fellow pet lovers!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),

                // Interactive Avatar with Camera Upload Badge
                Center(
                  child: GestureDetector(
                    onTap: _isUploadingAvatar ? null : _pickAndUploadAvatar,
                    child: Stack(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primaryFixed,
                            border: Border.all(color: AppColors.primary, width: 2),
                          ),
                          child: ClipOval(
                            child: _isUploadingAvatar
                                ? const Center(
                                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                                  )
                                : (_avatarLocalPath != null && File(_avatarLocalPath!).existsSync())
                                    ? Image.file(
                                        File(_avatarLocalPath!),
                                        fit: BoxFit.cover,
                                        width: 100,
                                        height: 100,
                                      )
                                    : effectiveAvatar.isNotEmpty
                                        ? CachedNetworkImage(
                                            imageUrl: effectiveAvatar,
                                            fit: BoxFit.cover,
                                            width: 100,
                                            height: 100,
                                            placeholder: (_, _) => const Center(
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            ),
                                            errorWidget: (_, _, _) => const Icon(Icons.pets, size: 48, color: AppColors.primary),
                                          )
                                        : const Icon(Icons.pets_rounded, size: 48, color: AppColors.primary),
                          ),
                        ),
                        // Camera upload icon badge
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _isUploadingAvatar ? null : _pickAndUploadAvatar,
                  icon: const Icon(Icons.photo_library_outlined, size: 16),
                  label: Text(
                    effectiveAvatar.isNotEmpty ? 'Change Profile Photo' : 'Upload Profile Photo',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 16),

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

                // Username
                CustomTextField(
                  label: 'Username',
                  hint: 'e.g. sarah_pets',
                  controller: _usernameController,
                  prefixIcon: const Icon(Icons.alternate_email, color: AppColors.outline),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Username is required';
                    final clean = val.trim().toLowerCase();
                    if (!RegExp(r'^[a-z0-9_]{3,20}$').hasMatch(clean)) {
                      return '3-20 characters, lowercase, numbers, underscores';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Bio
                CustomTextField(
                  label: 'Bio',
                  hint: 'Pet parent to 2 golden retrievers. Passionate about animal rescue & pet care...',
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

                // Submit Button -> Moves to Login Screen
                CustomButton(
                  text: 'Save & Go to Sign In',
                  width: double.infinity,
                  isLoading: _isLoading,
                  onPressed: _handleSubmit,
                ),
                const SizedBox(height: 12),

                TextButton(
                  onPressed: _skipForNow,
                  child: const Text(
                    'Skip & Sign In',
                    style: TextStyle(color: AppColors.outline, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
