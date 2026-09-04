import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class CreateProfileScreen extends StatefulWidget {
  const CreateProfileScreen({super.key});

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

  DateTime? _selectedDateOfBirth;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user != null) {
      _usernameController.text = user.username;
      _fullNameController.text = user.fullName ?? '';
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
    super.dispose();
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

    final profileData = {
      'fullName': _fullNameController.text.trim(),
      'username': _usernameController.text.trim().toLowerCase(),
      'bio': _bioController.text.trim(),
      'location': _locationController.text.trim(),
      'website': _websiteController.text.trim(),
      'phone': _phoneController.text.trim(),
      if (_avatarUrlController.text.trim().isNotEmpty)
        'avatar_url': _avatarUrlController.text.trim(),
      if (_selectedDateOfBirth != null)
        'dateOfBirth': DateFormat('yyyy-MM-dd').format(_selectedDateOfBirth!),
    };

    final success = await authProvider.createProfile(profileData);
    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        Navigator.of(context).popUntil((route) => route.isFirst);
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

  void _skipForNow() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final avatarPreview = _avatarUrlController.text.trim();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Profile'),
        actions: [
          TextButton(
            onPressed: _skipForNow,
            child: const Text('Skip', style: TextStyle(color: AppColors.outline)),
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
                // Header Icon / Greeting
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.primaryFixed,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.pets_rounded,
                    size: 36,
                    color: AppColors.primary,
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

                // Avatar Preview
                CircleAvatar(
                  radius: 46,
                  backgroundColor: AppColors.primaryFixed,
                  backgroundImage: avatarPreview.isNotEmpty
                      ? CachedNetworkImageProvider(avatarPreview)
                      : null,
                  child: avatarPreview.isEmpty
                      ? const Icon(Icons.person, size: 48, color: AppColors.primary)
                      : null,
                ),
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

                // Avatar URL
                CustomTextField(
                  label: 'Avatar Photo URL (Optional)',
                  hint: 'https://images.unsplash.com/...',
                  controller: _avatarUrlController,
                  prefixIcon: const Icon(Icons.image_outlined, color: AppColors.outline),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),

                // Bio
                CustomTextField(
                  label: 'Bio',
                  hint: 'Pet mom to 2 golden retrievers. Passionate about animal rescue & pet care...',
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

                // Submit Button
                CustomButton(
                  text: 'Save & Continue',
                  width: double.infinity,
                  isLoading: _isLoading,
                  onPressed: _handleSubmit,
                ),
                const SizedBox(height: 12),

                TextButton(
                  onPressed: _skipForNow,
                  child: const Text(
                    'I\'ll do this later',
                    style: TextStyle(color: AppColors.outline),
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
