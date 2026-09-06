import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/community_model.dart';
import '../../providers/community_provider.dart';
import '../../services/media_upload_helper.dart';
import '../../theme/app_theme.dart';
import 'community_detail_screen.dart';

class CreateCommunityScreen extends StatefulWidget {
  const CreateCommunityScreen({super.key});

  @override
  State<CreateCommunityScreen> createState() => _CreateCommunityScreenState();
}

class _CreateCommunityScreenState extends State<CreateCommunityScreen> {
  int _currentStep = 1; // 1: Info, 2: Privacy, 3: Rules, 4: Visuals & Preview
  bool _isLoading = false;
  String? _stepError;

  // Form Controllers & State
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedCategory = 'Dogs';
  String _visibility = 'public'; // public, private

  // Rules State
  final List<Map<String, String>> _rules = [
    {
      'title': 'Be Kind and Respectful',
      'description': 'Treat all members and their pets with kindness and respect.',
    },
    {
      'title': 'No Spam or Self-Promotion',
      'description': 'Keep discussions relevant, authentic, and pet-focused.',
    },
  ];
  final _newRuleTitleController = TextEditingController();
  final _newRuleDescController = TextEditingController();
  bool _isAddingRule = false;

  // Visuals State
  final _iconUrlController = TextEditingController();
  final _coverUrlController = TextEditingController();
  String? _localIconPath;
  String? _localCoverPath;
  bool _isUploadingIcon = false;
  bool _isUploadingCover = false;

  void _pickCircleIcon() async {
    setState(() => _isUploadingIcon = true);
    final res = await MediaUploadHelper.showPickerAndUpload(
      context,
      allowVideo: false,
      title: 'Upload Circle Avatar / Icon',
    );
    if (mounted) {
      setState(() {
        _isUploadingIcon = false;
        if (res != null) {
          _localIconPath = res.localPath;
          if (res.uploadedUrl != null) {
            _iconUrlController.text = res.uploadedUrl!;
          }
        }
      });
    }
  }

  void _pickCircleCover() async {
    setState(() => _isUploadingCover = true);
    final res = await MediaUploadHelper.showPickerAndUpload(
      context,
      allowVideo: false,
      title: 'Upload Cover Banner',
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
    'Pet Photography',
    'General',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _newRuleTitleController.dispose();
    _newRuleDescController.dispose();
    _iconUrlController.dispose();
    _coverUrlController.dispose();
    super.dispose();
  }

  String _autoGenerateSlug(String name) {
    final clean = name
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return clean.isNotEmpty ? clean : 'circle_${DateTime.now().millisecondsSinceEpoch}';
  }

  void _nextStep() {
    setState(() => _stepError = null);

    if (_currentStep == 1) {
      final name = _nameController.text.trim();
      if (name.isEmpty || name.length < 3) {
        setState(() => _stepError = 'Circle name must be at least 3 characters.');
        return;
      }
      setState(() => _currentStep = 2);
    } else if (_currentStep == 2) {
      setState(() => _currentStep = 3);
    } else if (_currentStep == 3) {
      setState(() => _currentStep = 4);
    }
  }

  void _prevStep() {
    if (_currentStep > 1) {
      setState(() {
        _stepError = null;
        _currentStep--;
      });
    }
  }

  void _addRule() {
    final title = _newRuleTitleController.text.trim();
    final desc = _newRuleDescController.text.trim();
    if (title.isEmpty) return;

    setState(() {
      _rules.add({'title': title, 'description': desc});
      _newRuleTitleController.clear();
      _newRuleDescController.clear();
      _isAddingRule = false;
    });
  }

  void _removeRule(int index) {
    setState(() {
      _rules.removeAt(index);
    });
  }

  void _handleCreate() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || name.length < 3) {
      setState(() {
        _currentStep = 1;
        _stepError = 'Circle name is required.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _stepError = null;
    });

    final commProvider = Provider.of<CommunityProvider>(context, listen: false);
    final slug = _autoGenerateSlug(name);

    final payload = {
      'name': name,
      'slug': slug,
      'description': _descriptionController.text.trim(),
      'category': _selectedCategory,
      'visibility': _visibility,
      if (_iconUrlController.text.trim().isNotEmpty)
        'icon_url': _iconUrlController.text.trim(),
      if (_coverUrlController.text.trim().isNotEmpty)
        'cover_image_url': _coverUrlController.text.trim(),
      'rules': _rules
          .map((r) => {
                'title': r['title'] ?? '',
                'description': r['description'] ?? '',
              })
          .toList(),
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
        setState(() {
          _stepError = 'Failed to create circle. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create a Circle', style: TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          // Step Progress Bar
          _buildProgressIndicator(),

          // Step Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_stepError != null) ...[
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, size: 18, color: AppColors.error),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _stepError!,
                              style: const TextStyle(fontSize: 12, color: AppColors.error, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (_currentStep == 1) _buildStep1Info(),
                  if (_currentStep == 2) _buildStep2Privacy(),
                  if (_currentStep == 3) _buildStep3Rules(),
                  if (_currentStep == 4) _buildStep4Visuals(),
                ],
              ),
            ),
          ),

          // Bottom Action Bar
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    final progress = _currentStep / 4.0;
    final titles = ['Basic Info', 'Privacy', 'Circle Rules', 'Visuals & Preview'];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Step $_currentStep of 4: ${titles[_currentStep - 1]}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.onSurface,
                ),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ],
          ),
        ),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: AppColors.surfaceContainerHigh,
          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
          minHeight: 3,
        ),
      ],
    );
  }

  // STEP 1: Basic Info
  Widget _buildStep1Info() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Start Your Community',
          style: TextStyle(
            fontFamily: 'Quicksand',
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Choose a memorable name and category for fellow pet lovers to find you.',
          style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
        ),
        const SizedBox(height: 24),

        // Circle Name Input
        const Text(
          'Circle Name *',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _nameController,
          decoration: InputDecoration(
            hintText: 'e.g. Golden Retriever Club',
            prefixIcon: const Icon(Icons.groups_outlined, color: AppColors.outline),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        const SizedBox(height: 20),

        // Category Selector
        const Text(
          'Category',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
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
                fontSize: 12,
              ),
              onSelected: (selected) {
                if (selected) setState(() => _selectedCategory = cat);
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 20),

        // Description
        const Text(
          'Description',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _descriptionController,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'What is this circle all about? Who should join?',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.all(14),
          ),
        ),
      ],
    );
  }

  // STEP 2: Privacy / Visibility
  Widget _buildStep2Privacy() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Circle Privacy',
          style: TextStyle(
            fontFamily: 'Quicksand',
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Choose how pet lovers discover and join your circle.',
          style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
        ),
        const SizedBox(height: 24),

        // Public Card
        InkWell(
          onTap: () => setState(() => _visibility = 'public'),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _visibility == 'public'
                  ? AppColors.primaryFixed.withValues(alpha: 0.3)
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _visibility == 'public' ? AppColors.primary : AppColors.surfaceContainerHigh,
                width: 2,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.public_rounded, color: Color(0xFF10B981), size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Public Circle',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          if (_visibility == 'public')
                            const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Anyone can view, join, and post in this community instantly. Great for building broad communities.',
                        style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant, height: 1.3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Private Card
        InkWell(
          onTap: () => setState(() => _visibility = 'private'),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _visibility == 'private'
                  ? AppColors.primaryFixed.withValues(alpha: 0.3)
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _visibility == 'private' ? AppColors.primary : AppColors.surfaceContainerHigh,
                width: 2,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.lock_rounded, color: Colors.amber, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Private Circle',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          if (_visibility == 'private')
                            const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Users must request to join. Discussions and posts are restricted to approved members only.',
                        style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant, height: 1.3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // STEP 3: Rules
  Widget _buildStep3Rules() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Community Rules',
                  style: TextStyle(
                    fontFamily: 'Quicksand',
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.onSurface,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Set guidelines to keep your circle friendly and safe.',
                  style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
            IconButton(
              icon: Icon(_isAddingRule ? Icons.close : Icons.add_circle, color: AppColors.primary),
              tooltip: _isAddingRule ? 'Cancel' : 'Add Rule',
              onPressed: () => setState(() => _isAddingRule = !_isAddingRule),
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (_isAddingRule) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('New Rule', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                TextField(
                  controller: _newRuleTitleController,
                  decoration: const InputDecoration(
                    labelText: 'Rule Title *',
                    hintText: 'e.g. Respect all members',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _newRuleDescController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    hintText: 'Explain the rule...',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _addRule,
                    child: const Text('Add to Rules'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        if (_rules.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'No rules defined yet. Click (+) above to add your first rule.',
                style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
              ),
            ),
          )
        else
          ..._rules.asMap().entries.map((entry) {
            final idx = entry.key + 1;
            final rule = entry.value;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.surfaceContainerHigh),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: AppColors.primaryFixed,
                    child: Text(
                      '$idx',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rule['title'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        if ((rule['description'] ?? '').isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            rule['description']!,
                            style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.outline),
                    onPressed: () => _removeRule(entry.key),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  // STEP 4: Visuals & Preview
  Widget _buildStep4Visuals() {
    final iconVal = _iconUrlController.text.trim();
    final coverVal = _coverUrlController.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Visuals & Preview',
          style: TextStyle(
            fontFamily: 'Quicksand',
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Add images to give your circle a unique identity.',
          style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
        ),
        const SizedBox(height: 20),

        // Icon Upload
        const Text('Circle Avatar / Icon', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 6),
        InkWell(
          onTap: _isUploadingIcon ? null : _pickCircleIcon,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              border: Border.all(color: AppColors.surfaceContainerHigh),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.primaryFixed,
                  backgroundImage: (_localIconPath != null && File(_localIconPath!).existsSync())
                      ? FileImage(File(_localIconPath!))
                      : iconVal.isNotEmpty
                          ? CachedNetworkImageProvider(iconVal)
                          : null,
                  child: (_localIconPath == null && iconVal.isEmpty)
                      ? const Icon(Icons.groups_rounded, color: AppColors.primary, size: 24)
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        iconVal.isNotEmpty || _localIconPath != null ? 'Avatar Selected' : 'Upload Circle Avatar',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      Text(
                        iconVal.isNotEmpty || _localIconPath != null ? 'Tap to change from device' : 'Choose photo from device gallery/camera',
                        style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                if (_isUploadingIcon)
                  const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                else
                  const Icon(Icons.add_photo_alternate_outlined, color: AppColors.primary),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Cover Upload
        const Text('Cover Banner', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 6),
        InkWell(
          onTap: _isUploadingCover ? null : _pickCircleCover,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              border: Border.all(color: AppColors.surfaceContainerHigh),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 44,
                    height: 44,
                    color: Colors.black12,
                    child: (_localCoverPath != null && File(_localCoverPath!).existsSync())
                        ? Image.file(File(_localCoverPath!), fit: BoxFit.cover)
                        : coverVal.isNotEmpty
                            ? CachedNetworkImage(imageUrl: coverVal, fit: BoxFit.cover, errorWidget: (_, _, _) => const Icon(Icons.panorama))
                            : const Icon(Icons.panorama_outlined, color: AppColors.outline),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        coverVal.isNotEmpty || _localCoverPath != null ? 'Cover Banner Selected' : 'Upload Cover Banner',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      Text(
                        coverVal.isNotEmpty || _localCoverPath != null ? 'Tap to change from device' : 'Choose banner from device gallery/camera',
                        style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                if (_isUploadingCover)
                  const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                else
                  const Icon(Icons.panorama_outlined, color: AppColors.primary),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Live Preview Card
        const Text('Live Preview', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 8),

        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.surfaceContainerHigh),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Banner Preview
              SizedBox(
                height: 90,
                width: double.infinity,
                child: (_localCoverPath != null && File(_localCoverPath!).existsSync())
                    ? Image.file(File(_localCoverPath!), fit: BoxFit.cover)
                    : coverVal.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: coverVal,
                            fit: BoxFit.cover,
                            errorWidget: (_, _, _) => _buildBannerPlaceholder(),
                          )
                        : _buildBannerPlaceholder(),
              ),

              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar Preview
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.primaryFixed,
                      backgroundImage: (_localIconPath != null && File(_localIconPath!).existsSync())
                          ? FileImage(File(_localIconPath!))
                          : iconVal.isNotEmpty
                              ? CachedNetworkImageProvider(iconVal)
                              : null,
                      child: (_localIconPath == null && iconVal.isEmpty)
                          ? Text(
                              _nameController.text.isNotEmpty ? _nameController.text[0].toUpperCase() : 'P',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 18),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _nameController.text.isNotEmpty ? _nameController.text : 'Your Circle Name',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryFixed.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  _selectedCategory,
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceContainerHigh,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  _visibility == 'private' ? 'Private' : 'Public',
                                  style: const TextStyle(fontSize: 10, color: AppColors.outline),
                                ),
                              ),
                            ],
                          ),
                          if (_descriptionController.text.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              _descriptionController.text,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBannerPlaceholder() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFE2E8F0), Color(0xFFCBD5E1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(Icons.pets, color: AppColors.outline.withValues(alpha: 0.4), size: 32),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.surfaceContainerHigh)),
      ),
      child: Row(
        children: [
          if (_currentStep > 1) ...[
            OutlinedButton(
              onPressed: _prevStep,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Back'),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : () {
                      if (_currentStep < 4) {
                        _nextStep();
                      } else {
                        _handleCreate();
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      _currentStep < 4 ? 'Continue' : 'Create Circle',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
