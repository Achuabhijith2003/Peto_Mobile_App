import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/post_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_button.dart';

class CreatePostScreen extends StatefulWidget {
  final String? communityId;

  const CreatePostScreen({super.key, this.communityId});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _contentController = TextEditingController();
  final _mediaUrlController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _contentController.dispose();
    _mediaUrlController.dispose();
    super.dispose();
  }

  void _submitPost() async {
    if (_contentController.text.trim().isEmpty) return;

    setState(() => _isLoading = true);
    final postProvider = Provider.of<PostProvider>(context, listen: false);
    final success = await postProvider.createPost(
      _contentController.text.trim(),
      mediaUrl: _mediaUrlController.text.trim().isNotEmpty
          ? _mediaUrlController.text.trim()
          : null,
      communityId: widget.communityId,
    );

    setState(() => _isLoading = false);

    if (success && mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Post'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: CustomButton(
              text: 'Post',
              isLoading: _isLoading,
              onPressed: _submitPost,
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _contentController,
              maxLines: 5,
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
            TextField(
              controller: _mediaUrlController,
              decoration: const InputDecoration(
                labelText: 'Image / Video URL (Optional)',
                hintText: 'https://images.unsplash.com/...',
                prefixIcon: Icon(Icons.image_outlined, color: AppColors.outline),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
