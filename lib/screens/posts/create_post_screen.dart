import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/post_provider.dart';
import '../../services/media_upload_helper.dart';
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
      petId: widget.petId,
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
              onChanged: (_) => setState(() {}),
              style: const TextStyle(fontSize: 16),
              decoration: const InputDecoration(
                hintText: "What's your pet up to today?",
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                fillColor: Colors.transparent,
              ),
            ),
            const SizedBox(height: 16),

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
