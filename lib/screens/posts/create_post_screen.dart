import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/post_provider.dart';
import '../../services/media_upload_helper.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_button.dart';

class CreatePostScreen extends StatefulWidget {
  final String? communityId;
  final String? petId;

  const CreatePostScreen({super.key, this.communityId, this.petId});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _contentController = TextEditingController();
  bool _isLoading = false;
  bool _isUploadingMedia = false;

  final List<PickedMediaResult> _mediaList = [];
  static const int _maxMediaCount = 5;

  final List<Map<String, dynamic>> _mentionedUsers = [];
  final List<Map<String, dynamic>> _taggedPets = [];
  List<dynamic> _mentionSuggestions = [];
  bool _isLoadingMentions = false;
  String? _currentMentionQuery;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  void _showMediaPickerOptions() async {
    final remainingSlots = _maxMediaCount - _mediaList.length;
    if (remainingSlots <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maximum 5 media items allowed per post'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final choice = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'Add Media (${_mediaList.length}/$_maxMediaCount)',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
                ),
                title: Text('Select Multiple Photos (Up to $remainingSlots)'),
                subtitle: const Text('Pick multiple images at once from your gallery'),
                onTap: () => Navigator.pop(ctx, 'multi_photos'),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryContainer.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt_outlined, color: AppColors.secondary),
                ),
                title: const Text('Take Photo with Camera'),
                subtitle: const Text('Snap a picture right now'),
                onTap: () => Navigator.pop(ctx, 'camera'),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.tertiaryContainer.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.video_library_outlined, color: AppColors.tertiary),
                ),
                title: const Text('Choose Video from Gallery'),
                subtitle: const Text('Upload a short video or clip'),
                onTap: () => Navigator.pop(ctx, 'video'),
              ),
            ],
          ),
        ),
      ),
    );

    if (choice == null || !mounted) return;

    if (choice == 'multi_photos') {
      setState(() => _isUploadingMedia = true);
      final results = await MediaUploadHelper.pickMultiPhotosAndUpload(
        context,
        maxCount: remainingSlots,
      );
      if (mounted) {
        setState(() {
          _isUploadingMedia = false;
          final valid = results.where((r) => r.uploadedUrl != null && r.uploadedUrl!.isNotEmpty);
          _mediaList.addAll(valid);
        });
      }
    } else if (choice == 'camera') {
      setState(() => _isUploadingMedia = true);
      final result = await MediaUploadHelper.showPickerAndUpload(
        context,
        allowVideo: false,
        title: 'Take Photo',
      );
      if (mounted) {
        setState(() {
          _isUploadingMedia = false;
          if (result != null && result.uploadedUrl != null && result.uploadedUrl!.isNotEmpty) {
            _mediaList.add(result);
          }
        });
      }
    } else if (choice == 'video') {
      setState(() => _isUploadingMedia = true);
      final result = await MediaUploadHelper.showPickerAndUpload(
        context,
        allowVideo: true,
        title: 'Choose Video',
      );
      if (mounted) {
        setState(() {
          _isUploadingMedia = false;
          if (result != null && result.uploadedUrl != null && result.uploadedUrl!.isNotEmpty) {
            _mediaList.add(result);
          }
        });
      }
    }
  }

  void _removeMediaAt(int index) {
    setState(() {
      _mediaList.removeAt(index);
    });
  }

  void _onTextChanged(String text) {
    setState(() {});
    final selection = _contentController.selection;
    if (selection.baseOffset < 0) return;

    final textBeforeCursor = text.substring(0, selection.baseOffset);
    final match = RegExp(r'@([a-zA-Z0-9_]*)$').firstMatch(textBeforeCursor);
    if (match != null) {
      final query = match.group(1) ?? '';
      _currentMentionQuery = query;
      _searchMentions(query);
    } else {
      if (_currentMentionQuery != null) {
        setState(() {
          _currentMentionQuery = null;
          _mentionSuggestions = [];
        });
      }
    }
  }

  void _searchMentions(String query) async {
    if (query.isEmpty) {
      setState(() => _mentionSuggestions = []);
      return;
    }
    setState(() => _isLoadingMentions = true);
    try {
      final results = await Future.wait([
        ApiService().searchUsers(query),
        ApiService().searchTaggablePets(query),
      ]);
      final userRes = results[0];
      final petRes = results[1];

      final combined = <dynamic>[];

      // Taggable Pets first
      if (petRes.statusCode == 200 && petRes.data != null) {
        final pets = petRes.data['data'] as List? ?? [];
        for (final p in pets) {
          if (p is Map) {
            combined.add({
              ...Map<String, dynamic>.from(p),
              'isPet': true,
            });
          }
        }
      }

      // Users
      if (userRes.statusCode == 200 && userRes.data != null) {
        final users = userRes.data['data'] as List? ?? [];
        for (final u in users) {
          if (u is Map) {
            combined.add({
              ...Map<String, dynamic>.from(u),
              'isPet': false,
            });
          }
        }
      }

      if (mounted) {
        setState(() {
          _mentionSuggestions = combined;
          _isLoadingMentions = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingMentions = false);
    }
  }

  void _selectMention(dynamic item) {
    if (_currentMentionQuery == null) return;
    final text = _contentController.text;
    final selection = _contentController.selection;
    final textBeforeCursor = text.substring(0, selection.baseOffset);
    final textAfterCursor = text.substring(selection.baseOffset);

    final isPet = item['isPet'] == true;
    final name = isPet
        ? (item['name']?.toString() ?? 'pet')
        : (item['username']?.toString() ?? 'user');

    final replaced = textBeforeCursor.replaceFirst(RegExp(r'@([a-zA-Z0-9_]*)$'), '@$name ');
    final newText = replaced + textAfterCursor;

    _contentController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: replaced.length),
    );

    final itemId = item['id']?.toString() ?? '';
    if (itemId.isNotEmpty) {
      if (isPet) {
        if (!_taggedPets.any((p) => p['id'].toString() == itemId)) {
          _taggedPets.add({
            'id': itemId,
            'name': item['name']?.toString() ?? 'Pet',
            'species': item['species']?.toString() ?? 'Other',
            'breed': item['breed']?.toString(),
            'avatarUrl': item['avatar_url']?.toString(),
          });
        }
      } else {
        if (!_mentionedUsers.any((u) => u['id'].toString() == itemId)) {
          _mentionedUsers.add({
            'id': itemId,
            'username': name,
            'fullName': item['full_name']?.toString() ?? name,
          });
        }
      }
    }

    setState(() {
      _currentMentionQuery = null;
      _mentionSuggestions = [];
    });
  }

  void _openPetPicker() async {
    final result = await showModalBottomSheet<List<Map<String, dynamic>>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _PetPickerBottomSheet(
        initiallySelected: _taggedPets,
      ),
    );

    if (result != null) {
      setState(() {
        _taggedPets.clear();
        _taggedPets.addAll(result);
      });
    }
  }

  void _submitPost() async {
    final validMedia = _mediaList.where((m) => m.uploadedUrl != null && m.uploadedUrl!.isNotEmpty).toList();
    if (_contentController.text.trim().isEmpty && validMedia.isEmpty) return;

    setState(() => _isLoading = true);
    final postProvider = Provider.of<PostProvider>(context, listen: false);
    final mediaUrls = validMedia.map((m) => m.uploadedUrl!).toList();

    final success = await postProvider.createPost(
      _contentController.text.trim(),
      mediaUrls: mediaUrls,
      mediaUrl: mediaUrls.isNotEmpty ? mediaUrls.first : null,
      communityId: widget.communityId,
      petId: _taggedPets.isNotEmpty ? _taggedPets.first['id'].toString() : widget.petId,
      mentionedUserIds: _mentionedUsers.map((u) => u['id']!.toString()).toList(),
      taggedPetIds: _taggedPets.map((p) => p['id']!.toString()).toList(),
    );

    setState(() => _isLoading = false);

    if (success && mounted) {
      Navigator.pop(context);
    }
  }

  Widget _buildMediaItem(PickedMediaResult item, int index) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.black12,
        border: Border.all(color: AppColors.surfaceContainerHigh, width: 1),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: item.isVideo
                  ? Container(
                      color: Colors.black87,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.videocam_rounded, size: 36, color: Colors.white),
                            const SizedBox(height: 6),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                item.localPath.split('/').last.split('\\').last,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white70, fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : (File(item.localPath).existsSync())
                      ? Image.file(
                          File(item.localPath),
                          fit: BoxFit.cover,
                        )
                      : CachedNetworkImage(
                          imageUrl: item.uploadedUrl ?? '',
                          fit: BoxFit.cover,
                          placeholder: (_, _) => const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          errorWidget: (_, _, _) => const Icon(Icons.pets),
                        ),
            ),
          ),

          // Delete Button (Top Right)
          Positioned(
            top: 6,
            right: 6,
            child: GestureDetector(
              onTap: () => _removeMediaAt(index),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 16),
              ),
            ),
          ),

          // Indicator Badge (Bottom Left)
          Positioned(
            bottom: 6,
            left: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    item.isVideo ? Icons.play_arrow_rounded : Icons.photo,
                    color: Colors.white,
                    size: 12,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    item.isVideo ? 'Video' : '#${index + 1}',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasValidContent = _contentController.text.trim().isNotEmpty || _mediaList.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Post'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: CustomButton(
              text: 'Post',
              isLoading: _isLoading || _isUploadingMedia,
              onPressed: hasValidContent ? _submitPost : null,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _contentController,
              maxLines: 5,
              onChanged: _onTextChanged,
              style: const TextStyle(fontSize: 16),
              decoration: const InputDecoration(
                hintText: "What's on your mind? Type @ to mention someone",
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                fillColor: Colors.transparent,
              ),
            ),

            // Mention Suggestions Dropdown
            if (_mentionSuggestions.isNotEmpty || _isLoadingMentions)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.outline.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Text(
                        'Mention suggestions',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.outline),
                      ),
                    ),
                    if (_isLoadingMentions)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                          ),
                        ),
                      )
                    else
                      ..._mentionSuggestions.map((item) {
                        final isPet = item['isPet'] == true;
                        final avatarUrl = item['avatar_url']?.toString();
                        final title = isPet
                            ? (item['name']?.toString() ?? 'Pet')
                            : (item['full_name']?.toString() ?? item['username']?.toString() ?? 'User');
                        final subtitle = isPet
                            ? '🐾 Pet · ${item['species'] ?? 'Animal'}${item['breed'] != null ? ' · ${item['breed']}' : ''}'
                            : '@${item['username'] ?? 'user'}';

                        return InkWell(
                          onTap: () => _selectMention(item),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: isPet
                                      ? AppColors.secondaryContainer
                                      : AppColors.primaryContainer,
                                  backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                                      ? CachedNetworkImageProvider(avatarUrl)
                                      : null,
                                  child: avatarUrl == null
                                      ? Icon(
                                          isPet ? Icons.pets : Icons.person,
                                          size: 14,
                                          color: isPet ? AppColors.secondary : AppColors.primary,
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.outline)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),

            // Tagged Pets Badges
            if (_taggedPets.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'Tagged:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.secondary),
                    ),
                    ..._taggedPets.map((p) => Chip(
                          avatar: const Icon(Icons.pets, size: 14, color: AppColors.primary),
                          label: Text(p['name']?.toString() ?? 'Pet'),
                          deleteIcon: const Icon(Icons.close, size: 14),
                          onDeleted: () {
                            setState(() {
                              _taggedPets.removeWhere((item) => item['id'] == p['id']);
                            });
                          },
                          backgroundColor: AppColors.surfaceContainerHigh,
                          padding: const EdgeInsets.all(0),
                          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        )),
                  ],
                ),
              ),
            ],

            // Tag Pet Button
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: OutlinedButton.icon(
                onPressed: _openPetPicker,
                icon: const Icon(Icons.pets, size: 16, color: AppColors.primary),
                label: Text(
                  _taggedPets.isEmpty ? 'Tag Pet' : 'Tag More Pets (${_taggedPets.length})',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Attached Media Strip
            if (_mediaList.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Attached Media (${_mediaList.length}/$_maxMediaCount)',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  if (_mediaList.length < _maxMediaCount)
                    GestureDetector(
                      onTap: _isUploadingMedia ? null : _showMediaPickerOptions,
                      child: const Text(
                        '+ Add More',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 160,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _mediaList.length + (_mediaList.length < _maxMediaCount ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index < _mediaList.length) {
                      return _buildMediaItem(_mediaList[index], index);
                    }
                    // "Add More" tile
                    return GestureDetector(
                      onTap: _isUploadingMedia ? null : _showMediaPickerOptions,
                      child: Container(
                        width: 110,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: AppColors.surfaceContainerLow,
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryContainer.withValues(alpha: 0.3),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.add, color: AppColors.primary, size: 22),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Add Media',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                              Text(
                                '${_maxMediaCount - _mediaList.length} left',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.outline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Add Media Button (when empty or available)
            if (_mediaList.isEmpty)
              InkWell(
                onTap: _isUploadingMedia ? null : _showMediaPickerOptions,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primaryContainer.withValues(alpha: 0.5),
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isUploadingMedia)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                        )
                      else
                        const Icon(Icons.add_photo_alternate_rounded, color: AppColors.primary, size: 24),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Upload Media (Up to 5 Photos / Videos)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: AppColors.primary,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Select multiple photos or add a video',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.outline,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PetPickerBottomSheet extends StatefulWidget {
  final List<Map<String, dynamic>> initiallySelected;

  const _PetPickerBottomSheet({required this.initiallySelected});

  @override
  State<_PetPickerBottomSheet> createState() => _PetPickerBottomSheetState();
}

class _PetPickerBottomSheetState extends State<_PetPickerBottomSheet> {
  final _searchController = TextEditingController();
  final List<Map<String, dynamic>> _selectedPets = [];
  List<dynamic> _pets = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedPets.addAll(widget.initiallySelected);
    _loadPets('');
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadPets(String query) async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService().searchTaggablePets(query);
      if (res.statusCode == 200 && res.data != null) {
        final list = res.data['data'] as List? ?? [];
        if (mounted) {
          setState(() {
            _pets = list;
            _isLoading = false;
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _togglePet(dynamic pet) {
    final petId = pet['id'].toString();
    final exists = _selectedPets.any((p) => p['id'].toString() == petId);
    setState(() {
      if (exists) {
        _selectedPets.removeWhere((p) => p['id'].toString() == petId);
      } else {
        if (_selectedPets.length >= 5) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You can tag up to 5 pets.')),
          );
          return;
        }
        _selectedPets.add({
          'id': petId,
          'name': pet['name']?.toString() ?? 'Pet',
          'species': pet['species']?.toString() ?? 'Other',
          'breed': pet['breed']?.toString(),
          'avatarUrl': pet['avatar_url']?.toString(),
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.75,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Tag Pets in Post',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.onSurface),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, _selectedPets),
                  child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _searchController,
              onChanged: _loadPets,
              decoration: InputDecoration(
                hintText: 'Search pets by name...',
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                fillColor: AppColors.surfaceContainerLow,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : _pets.isEmpty
                      ? const Center(
                          child: Text(
                            'No eligible pets found to tag',
                            style: TextStyle(color: AppColors.outline),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _pets.length,
                          itemBuilder: (ctx, i) {
                            final pet = _pets[i];
                            final petId = pet['id'].toString();
                            final isSelected = _selectedPets.any((p) => p['id'].toString() == petId);
                            final avatarUrl = pet['avatar_url']?.toString();

                            return CheckboxListTile(
                              value: isSelected,
                              activeColor: AppColors.primary,
                              onChanged: (_) => _togglePet(pet),
                              secondary: CircleAvatar(
                                radius: 18,
                                backgroundColor: AppColors.primaryContainer,
                                backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                                    ? CachedNetworkImageProvider(avatarUrl)
                                    : null,
                                child: avatarUrl == null ? const Icon(Icons.pets, size: 18, color: AppColors.primary) : null,
                              ),
                              title: Text(
                                pet['name']?.toString() ?? 'Pet',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              subtitle: Text(
                                '${pet['species'] ?? ''}${pet['breed'] != null ? ' • ${pet['breed']}' : ''}',
                                style: const TextStyle(fontSize: 12, color: AppColors.outline),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
