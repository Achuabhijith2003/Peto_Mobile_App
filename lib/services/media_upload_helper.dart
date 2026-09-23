import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'api_service.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_prompt_bottom_sheet.dart';

class PickedMediaResult {
  final String? uploadedUrl;
  final String? mediaId;
  final String localPath;
  final bool isVideo;

  PickedMediaResult({
    this.uploadedUrl,
    this.mediaId,
    required this.localPath,
    this.isVideo = false,
  });
}

class MediaUploadHelper {
  static final ImagePicker _picker = ImagePicker();
  static final ApiService _apiService = ApiService();

  static Future<PickedMediaResult?> showPickerAndUpload(
    BuildContext context, {
    bool allowVideo = false,
    String title = 'Upload from Device',
  }) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated) {
      AuthPromptBottomSheet.show(context, actionTitle: title);
      return null;
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
                title,
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
                title: const Text('Choose Photo from Gallery', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () => Navigator.pop(ctx, 'photo_gallery'),
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
                title: const Text('Take Photo with Camera', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () => Navigator.pop(ctx, 'photo_camera'),
              ),
              if (allowVideo) ...[
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.tertiaryContainer.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.video_library_outlined, color: AppColors.tertiary),
                  ),
                  title: const Text('Choose Video from Gallery', style: TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () => Navigator.pop(ctx, 'video_gallery'),
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.videocam_outlined, color: Colors.deepPurple),
                  ),
                  title: const Text('Record Video with Camera', style: TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () => Navigator.pop(ctx, 'video_camera'),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (choice == null) return null;

    XFile? pickedFile;
    bool isVideo = false;

    try {
      if (choice == 'photo_gallery') {
        pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      } else if (choice == 'photo_camera') {
        pickedFile = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
      } else if (choice == 'video_gallery') {
        pickedFile = await _picker.pickVideo(source: ImageSource.gallery);
        isVideo = true;
      } else if (choice == 'video_camera') {
        pickedFile = await _picker.pickVideo(source: ImageSource.camera);
        isVideo = true;
      }
    } catch (e) {
      debugPrint('Error picking file: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick file: $e'), backgroundColor: AppColors.error),
        );
      }
      return null;
    }

    if (pickedFile == null) return null;

    if (!context.mounted) return null;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                isVideo
                    ? 'Uploading & optimizing video, please wait...'
                    : 'Uploading media to server...',
              ),
            ),
          ],
        ),
        duration: Duration(seconds: isVideo ? 180 : 45),
      ),
    );

    final result = await _apiService.uploadMediaFile(
      pickedFile.path,
      fileName: pickedFile.name,
      isVideo: isVideo,
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      if (result.success && result.mediaUrl != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Upload complete!'),
            backgroundColor: AppColors.tertiary,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        final errorMsg = result.errorMessage ?? 'Upload failed. Please try again.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }

    return PickedMediaResult(
      localPath: pickedFile.path,
      uploadedUrl: result.mediaUrl,
      mediaId: result.mediaId,
      isVideo: isVideo,
    );
  }

  static Future<List<PickedMediaResult>> pickMultiPhotosAndUpload(
    BuildContext context, {
    int maxCount = 5,
  }) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated) {
      AuthPromptBottomSheet.show(context, actionTitle: 'Upload Photos');
      return [];
    }

    final List<XFile> pickedFiles = await _picker.pickMultiImage(
      limit: maxCount,
      imageQuality: 85,
    );

    if (pickedFiles.isEmpty) return [];

    if (!context.mounted) return [];

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            const SizedBox(width: 14),
            Text('Uploading ${pickedFiles.length} photo(s)...'),
          ],
        ),
        duration: const Duration(seconds: 90),
      ),
    );

    final List<PickedMediaResult> results = [];
    for (final file in pickedFiles) {
      final res = await _apiService.uploadMediaFile(file.path, fileName: file.name);
      results.add(PickedMediaResult(
        localPath: file.path,
        uploadedUrl: res.mediaUrl,
        mediaId: res.mediaId,
        isVideo: false,
      ));
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Uploaded ${results.where((r) => r.uploadedUrl != null).length} photo(s)!'),
          backgroundColor: AppColors.tertiary,
          duration: const Duration(seconds: 2),
        ),
      );
    }

    return results;
  }
}
