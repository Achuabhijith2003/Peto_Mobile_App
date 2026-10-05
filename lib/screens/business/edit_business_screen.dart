import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class EditBusinessScreen extends StatefulWidget {
  final BusinessModel business;

  const EditBusinessScreen({super.key, required this.business});

  @override
  State<EditBusinessScreen> createState() => _EditBusinessScreenState();
}

class _EditBusinessScreenState extends State<EditBusinessScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();

  late TextEditingController _nameController;
  late TextEditingController _legalNameController;
  late TextEditingController _usernameController;
  late TextEditingController _categoryController;
  late TextEditingController _descriptionController;
  late TextEditingController _websiteController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _countryController;

  String? _avatarUrl;
  String? _coverUrl;
  bool _isUploadingAvatar = false;
  bool _isUploadingCover = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final b = widget.business;
    _nameController = TextEditingController(text: b.name);
    _legalNameController = TextEditingController(text: b.legalName);
    _usernameController = TextEditingController(text: b.username ?? '');
    _categoryController = TextEditingController(text: b.businessCategory ?? '');
    _descriptionController = TextEditingController(text: b.description ?? '');
    _websiteController = TextEditingController(text: b.websiteUrl ?? '');
    _emailController = TextEditingController(text: b.publicEmail ?? '');
    _phoneController = TextEditingController(text: b.publicPhone ?? '');
    _cityController = TextEditingController(text: b.city ?? '');
    _stateController = TextEditingController(text: b.state ?? '');
    _countryController = TextEditingController(text: b.countryCode);
    _avatarUrl = b.avatarUrl;
    _coverUrl = b.coverUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _legalNameController.dispose();
    _usernameController.dispose();
    _categoryController.dispose();
    _descriptionController.dispose();
    _websiteController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;

    setState(() => _isUploadingAvatar = true);
    try {
      final url = await _apiService.uploadBusinessAvatar(widget.business.id, File(picked.path));
      if (url != null) {
        setState(() => _avatarUrl = url);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Business logo updated successfully')),
          );
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
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;

    setState(() => _isUploadingCover = true);
    try {
      final url = await _apiService.uploadBusinessCover(widget.business.id, File(picked.path));
      if (url != null) {
        setState(() => _coverUrl = url);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cover image updated successfully')),
          );
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

  void _onSavePressed() {
    if (!_formKey.currentState!.validate()) return;

    final isCritical = widget.business.isVerified &&
        (_nameController.text.trim() != widget.business.name.trim() ||
            _legalNameController.text.trim() != widget.business.legalName.trim() ||
            _countryController.text.trim().toUpperCase() != widget.business.countryCode.trim().toUpperCase());

    if (isCritical) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          icon: const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 40),
          title: const Text(
            'Business Verification Will Be Removed',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          content: const Text(
            'You are changing information used to verify this Business.\n\n'
            'If you continue:\n'
            '• The yellow verification badge will be removed.\n'
            '• The Business will require reverification.\n'
            '• An authorized Business manager must submit a new verification request.',
            style: TextStyle(fontSize: 13, height: 1.4),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _executeSave();
              },
              child: const Text('Continue & Update'),
            ),
          ],
        ),
      );
      return;
    }

    _executeSave();
  }

  Future<void> _executeSave() async {
    setState(() => _isSaving = true);
    try {
      final payload = {
        'name': _nameController.text.trim(),
        'legal_name': _legalNameController.text.trim(),
        'username': _usernameController.text.trim(),
        'business_category': _categoryController.text.trim(),
        'description': _descriptionController.text.trim(),
        'website_url': _websiteController.text.trim(),
        'public_email': _emailController.text.trim(),
        'public_phone': _phoneController.text.trim(),
        'city': _cityController.text.trim(),
        'state': _stateController.text.trim(),
        'country_code': _countryController.text.trim().toUpperCase(),
      };

      final updated = await _apiService.updateBusinessProfile(widget.business.id, payload);
      if (mounted) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        await authProvider.fetchManagedBusinesses();
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Business profile updated successfully')),
        );
        Navigator.pop(context, updated != null ? BusinessModel.fromJson(updated) : null);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Edit Business Profile'),
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _onSavePressed,
            child: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Save',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover Picker
              const Text(
                'COVER IMAGE',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.onSurfaceVariant, letterSpacing: 0.5),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _isUploadingCover ? null : _pickCover,
                child: Container(
                  height: 140,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(16),
                    image: _coverUrl != null && _coverUrl!.isNotEmpty
                        ? DecorationImage(
                            image: CachedNetworkImageProvider(_coverUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _isUploadingCover
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            _isUploadingCover ? 'Uploading...' : 'Change Cover',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Avatar / Logo Picker
              const Text(
                'BUSINESS LOGO',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.onSurfaceVariant, letterSpacing: 0.5),
              ),
              const SizedBox(height: 8),
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 46,
                      backgroundColor: Colors.amber.shade200,
                      backgroundImage: _avatarUrl != null && _avatarUrl!.isNotEmpty
                          ? CachedNetworkImageProvider(_avatarUrl!)
                          : null,
                      child: _avatarUrl == null || _avatarUrl!.isEmpty
                          ? Text(
                              widget.business.name.isNotEmpty ? widget.business.name[0].toUpperCase() : 'B',
                              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.amber),
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _isUploadingAvatar ? null : _pickAvatar,
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: AppColors.primary,
                          child: _isUploadingAvatar
                              ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              CustomTextField(
                controller: _nameController,
                label: 'Business Display Name',
                validator: (val) => val == null || val.trim().isEmpty ? 'Display name is required' : null,
              ),
              const SizedBox(height: 16),

              CustomTextField(
                controller: _legalNameController,
                label: 'Legal Registered Name',
                validator: (val) => val == null || val.trim().isEmpty ? 'Legal name is required' : null,
              ),
              const SizedBox(height: 16),

              CustomTextField(
                controller: _usernameController,
                label: 'Username / Handle',
                hint: 'handle_name',
              ),
              const SizedBox(height: 16),

              CustomTextField(
                controller: _categoryController,
                label: 'Industry / Category',
                hint: 'e.g. Pet Food & Nutrition, Veterinary',
              ),
              const SizedBox(height: 16),

              CustomTextField(
                controller: _descriptionController,
                label: 'About / Description',
                maxLines: 3,
                hint: 'Tell Peto users about your business...',
              ),
              const SizedBox(height: 16),

              CustomTextField(
                controller: _websiteController,
                label: 'Website URL',
                hint: 'https://brand.com',
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 16),

              CustomTextField(
                controller: _emailController,
                label: 'Public Contact Email',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),

              CustomTextField(
                controller: _phoneController,
                label: 'Public Contact Phone',
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      controller: _cityController,
                      label: 'City',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CustomTextField(
                      controller: _countryController,
                      label: 'Country (2-letter)',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              CustomButton(
                text: 'Save Changes',
                isLoading: _isSaving,
                onPressed: _onSavePressed,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
