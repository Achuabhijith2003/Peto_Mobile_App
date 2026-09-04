import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/community_model.dart';
import '../../providers/community_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import 'community_detail_screen.dart';

class CreateCommunityScreen extends StatefulWidget {
  const CreateCommunityScreen({super.key});

  @override
  State<CreateCommunityScreen> createState() => _CreateCommunityScreenState();
}

class _CreateCommunityScreenState extends State<CreateCommunityScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _slugController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _iconUrlController = TextEditingController();
  final _coverUrlController = TextEditingController();

  String _selectedCategory = 'Dogs';
  String _visibility = 'public'; // public, private
  bool _isLoading = false;

  final List<String> _categories = [
    'Dogs',
    'Cats',
    'Birds',
    'Reptiles',
    'Small Pets',
    'Exotic',
    'General',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _slugController.dispose();
    _descriptionController.dispose();
    _iconUrlController.dispose();
    _coverUrlController.dispose();
    super.dispose();
  }

  void _generateSlug(String name) {
    if (_slugController.text.isEmpty || _slugController.text.startsWith(RegExp(r'^[a-z0-9_]*$'))) {
      final clean = name
          .trim()
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]'), '_')
          .replaceAll(RegExp(r'_+'), '_');
      _slugController.text = clean;
    }
  }

  void _handleCreate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final commProvider = Provider.of<CommunityProvider>(context, listen: false);

    final payload = {
      'name': _nameController.text.trim(),
      'slug': _slugController.text.trim().toLowerCase(),
      'description': _descriptionController.text.trim(),
      'category': _selectedCategory,
      'visibility': _visibility,
      if (_iconUrlController.text.trim().isNotEmpty)
        'icon_url': _iconUrlController.text.trim(),
      if (_coverUrlController.text.trim().isNotEmpty)
        'cover_image_url': _coverUrlController.text.trim(),
    };

    final Community? created = await commProvider.createCommunity(payload);
    if (mounted) {
      setState(() => _isLoading = false);
      if (created != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => CommunityDetailScreen(
              communityId: created.id,
              initialCommunity: created,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to create circle. Please try again.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Circle'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Intro
              const Text(
                'Start a Pet Circle',
                style: TextStyle(
                  fontFamily: 'Quicksand',
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Create a space for pet lovers to share stories, advice, and meetups.',
                style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: 20),

              // Community Name
              CustomTextField(
                label: 'Circle Name',
                hint: 'e.g. Golden Retriever Pals',
                controller: _nameController,
                prefixIcon: const Icon(Icons.groups_outlined, color: AppColors.outline),
                onChanged: _generateSlug,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Circle name is required';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Handle / Slug
              CustomTextField(
                label: 'Circle Handle (@slug)',
                hint: 'golden_retriever_pals',
                controller: _slugController,
                prefixIcon: const Icon(Icons.alternate_email, color: AppColors.outline),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Slug is required';
                  final clean = val.trim().toLowerCase();
                  if (!RegExp(r'^[a-z0-9_]{3,30}$').hasMatch(clean)) {
                    return '3-30 chars, lowercase, numbers, underscores only';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Category Selector
              const Text(
                'Category',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _categories.map((cat) {
                  final isSelected = _selectedCategory == cat;
                  return ChoiceChip(
                    label: Text(cat),
                    selected: isSelected,
                    selectedColor: AppColors.primaryContainer,
                    labelStyle: TextStyle(
                      color: isSelected ? AppColors.onPrimaryContainer : AppColors.onSurface,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedCategory = cat);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Description
              CustomTextField(
                label: 'About this Circle',
                hint: 'What is this community all about? Who should join?',
                controller: _descriptionController,
                maxLines: 3,
                prefixIcon: const Icon(Icons.description_outlined, color: AppColors.outline),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Description is required';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Visibility Choice
              const Text(
                'Visibility',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _visibility = 'public'),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _visibility == 'public'
                              ? AppColors.primaryFixed.withValues(alpha: 0.5)
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _visibility == 'public' ? AppColors.primary : AppColors.surfaceContainerHigh,
                            width: 1.5,
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.public, color: AppColors.primary, size: 20),
                            SizedBox(width: 8),
                            Text('Public Circle', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _visibility = 'private'),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _visibility == 'private'
                              ? AppColors.primaryFixed.withValues(alpha: 0.5)
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _visibility == 'private' ? AppColors.primary : AppColors.surfaceContainerHigh,
                            width: 1.5,
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.lock_outline, color: AppColors.primary, size: 20),
                            SizedBox(width: 8),
                            Text('Private Circle', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Icon URL
              CustomTextField(
                label: 'Circle Icon URL (Optional)',
                hint: 'https://images.unsplash.com/...',
                controller: _iconUrlController,
                prefixIcon: const Icon(Icons.image_outlined, color: AppColors.outline),
              ),
              const SizedBox(height: 16),

              // Cover Image URL
              CustomTextField(
                label: 'Cover Banner URL (Optional)',
                hint: 'https://images.unsplash.com/...',
                controller: _coverUrlController,
                prefixIcon: const Icon(Icons.panorama_outlined, color: AppColors.outline),
              ),
              const SizedBox(height: 32),

              // Submit Button
              CustomButton(
                text: 'Create Circle',
                width: double.infinity,
                isLoading: _isLoading,
                onPressed: _handleCreate,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
