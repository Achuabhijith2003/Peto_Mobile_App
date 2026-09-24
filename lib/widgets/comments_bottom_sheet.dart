import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../models/post_model.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../providers/post_provider.dart';
import '../theme/app_theme.dart';
import '../screens/profile/public_profile_screen.dart';
import 'auth_prompt_bottom_sheet.dart';

class CommentsBottomSheet extends StatefulWidget {
  final String postId;
  final String? postAuthorUsername;

  const CommentsBottomSheet({
    super.key,
    required this.postId,
    this.postAuthorUsername,
  });

  static Future<void> show(
    BuildContext context, {
    required String postId,
    String? postAuthorUsername,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CommentsBottomSheet(
        postId: postId,
        postAuthorUsername: postAuthorUsername,
      ),
    );
  }

  @override
  State<CommentsBottomSheet> createState() => _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends State<CommentsBottomSheet> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  List<PostComment> _comments = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  PostComment? _replyingTo;
  final Set<String> _expandedReplies = {};

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleReplyClick(PostComment comment) {
    setState(() {
      _replyingTo = comment;
    });
    _controller.text = '@${comment.author.username} ';
    _focusNode.requestFocus();
  }

  void _cancelReply() {
    setState(() {
      _replyingTo = null;
    });
    _controller.clear();
  }

  void _toggleReplies(String commentId) {
    setState(() {
      if (_expandedReplies.contains(commentId)) {
        _expandedReplies.remove(commentId);
      } else {
        _expandedReplies.add(commentId);
      }
    });
  }

  Future<void> _loadComments() async {
    final postProvider = Provider.of<PostProvider>(context, listen: false);
    final comments = await postProvider.fetchComments(widget.postId);
    if (mounted) {
      setState(() {
        _comments = comments;
        _isLoading = false;
      });
    }
  }

  Future<void> _submitComment() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSubmitting) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated) {
      AuthPromptBottomSheet.show(context, actionTitle: 'Comment');
      return;
    }

    setState(() => _isSubmitting = true);
    final postProvider = Provider.of<PostProvider>(context, listen: false);

    // If replying to a reply, target the top-level parent comment
    final parentId = _replyingTo != null
        ? (_replyingTo!.parentCommentId ?? _replyingTo!.id)
        : null;

    final newComment = await postProvider.addComment(
      widget.postId,
      text,
      parentCommentId: parentId,
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (newComment != null) {
        final targetParentId = parentId;
        _controller.clear();
        setState(() {
          _comments.add(newComment);
          if (targetParentId != null) {
            _expandedReplies.add(targetParentId);
          }
          _replyingTo = null;
        });
        _loadComments();
        // Scroll to bottom
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to post comment. Please try again.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _deleteComment(PostComment comment) async {
    final postProvider = Provider.of<PostProvider>(context, listen: false);
    final success = await postProvider.deleteComment(widget.postId, comment.id);
    if (success && mounted) {
      setState(() {
        _comments.removeWhere((c) => c.id == comment.id);
      });
    }
  }

  String _formatTimestamp(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat.MMMd().format(dt);
  }

  void _openUserProfile(User author) {
    final targetId = author.id.isNotEmpty ? author.id : author.username;
    if (targetId.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PublicProfileScreen(
          userId: targetId,
          initialUser: author,
        ),
      ),
    );
  }

  Widget _buildCommentContentWithMentions(String text, List<PostMention> mentions, {double fontSize = 14}) {
    if (text.isEmpty) return const SizedBox.shrink();

    final mentionMap = <String, PostMention>{};
    for (final m in mentions) {
      if (m.username.isNotEmpty) {
        mentionMap[m.username.toLowerCase()] = m;
      }
    }

    final spans = <InlineSpan>[];
    final regex = RegExp(r'(@[a-zA-Z0-9_]+)');
    int lastIndex = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: text.substring(lastIndex, match.start),
          style: TextStyle(
            fontSize: fontSize,
            height: 1.3,
            color: AppColors.onSurface,
          ),
        ));
      }

      final mentionTag = match.group(0)!;
      final rawUsername = mentionTag.substring(1).toLowerCase();
      final mentionInfo = mentionMap[rawUsername];

      spans.add(TextSpan(
        text: mentionTag,
        style: TextStyle(
          fontSize: fontSize,
          height: 1.3,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
        recognizer: TapGestureRecognizer()
          ..onTap = () {
            final targetId = (mentionInfo?.id != null && mentionInfo!.id.isNotEmpty)
                ? mentionInfo.id
                : rawUsername;
            final targetUsername = (mentionInfo?.username != null && mentionInfo!.username.isNotEmpty)
                ? mentionInfo.username
                : rawUsername;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PublicProfileScreen(
                  userId: targetId,
                  initialUser: User(
                    id: targetId,
                    email: '',
                    username: targetUsername,
                    fullName: mentionInfo?.fullName,
                    avatarUrl: mentionInfo?.avatarUrl,
                  ),
                ),
              ),
            );
          },
      ));

      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastIndex),
        style: TextStyle(
          fontSize: fontSize,
          height: 1.3,
          color: AppColors.onSurface,
        ),
      ));
    }

    return Text.rich(TextSpan(children: spans));
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final currentUserId = authProvider.user?.id;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: keyboardHeight),
        child: Column(
          children: [
            // Top Drag Handle
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.outline.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Comments',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.onSurface,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_comments.length}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.secondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: AppColors.outline),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.surfaceContainerHigh),

            // Comments List
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : _comments.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  size: 48,
                                  color: AppColors.outline.withValues(alpha: 0.5),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'No comments yet',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Start the conversation with pet lovers!',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : Builder(
                          builder: (context) {
                            final topLevelComments = _comments
                                .where((c) => c.parentCommentId == null || c.parentCommentId!.isEmpty)
                                .toList();
                            final Map<String, List<PostComment>> repliesMap = {};
                            for (final c in _comments) {
                              if (c.parentCommentId != null && c.parentCommentId!.isNotEmpty) {
                                repliesMap.putIfAbsent(c.parentCommentId!, () => []).add(c);
                              }
                            }

                            return ListView.separated(
                              controller: _scrollController,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              itemCount: topLevelComments.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 16),
                              itemBuilder: (context, index) {
                                final comment = topLevelComments[index];
                                final isOwner = currentUserId != null &&
                                    currentUserId == comment.author.id;
                                final replies = repliesMap[comment.id] ?? [];
                                final isExpanded = _expandedReplies.contains(comment.id);

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        CircleAvatar(
                                          radius: 18,
                                          backgroundColor: AppColors.primaryFixed,
                                          backgroundImage: comment.author.avatarUrl != null
                                              ? CachedNetworkImageProvider(comment.author.avatarUrl!)
                                              : null,
                                          child: comment.author.avatarUrl == null
                                              ? Text(
                                                  comment.author.username.isNotEmpty
                                                      ? comment.author.username[0].toUpperCase()
                                                      : 'P',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                    color: AppColors.primary,
                                                  ),
                                                )
                                              : null,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  GestureDetector(
                                                    onTap: () => _openUserProfile(comment.author),
                                                    child: Text(
                                                      comment.author.username,
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 13,
                                                        color: AppColors.onSurface,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    _formatTimestamp(comment.createdAt),
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 3),
                                              _buildCommentContentWithMentions(comment.content, comment.mentions),
                                              const SizedBox(height: 6),
                                              GestureDetector(
                                                onTap: () => _handleReplyClick(comment),
                                                child: const Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.reply_rounded, size: 14, color: AppColors.secondary),
                                                    SizedBox(width: 4),
                                                    Text(
                                                      'Reply',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w600,
                                                        color: AppColors.secondary,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (isOwner)
                                          IconButton(
                                            icon: const Icon(
                                              Icons.delete_outline,
                                              size: 18,
                                              color: AppColors.outline,
                                            ),
                                            onPressed: () => _deleteComment(comment),
                                          ),
                                      ],
                                    ),

                                    // View / Hide replies toggle
                                    if (replies.isNotEmpty) ...[
                                      Padding(
                                        padding: const EdgeInsets.only(left: 48, top: 6),
                                        child: GestureDetector(
                                          onTap: () => _toggleReplies(comment.id),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                isExpanded
                                                    ? Icons.keyboard_arrow_up_rounded
                                                    : Icons.subdirectory_arrow_right_rounded,
                                                size: 14,
                                                color: AppColors.secondary,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                isExpanded
                                                    ? 'Hide replies'
                                                    : 'View ${replies.length} ${replies.length == 1 ? 'reply' : 'replies'}',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.secondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],

                                    // Indented Nested Replies
                                    if (replies.isNotEmpty && isExpanded) ...[
                                      Container(
                                        margin: const EdgeInsets.only(left: 36, top: 10),
                                        padding: const EdgeInsets.only(left: 12),
                                        decoration: BoxDecoration(
                                          border: Border(
                                            left: BorderSide(
                                              color: AppColors.secondary.withValues(alpha: 0.35),
                                              width: 2,
                                            ),
                                          ),
                                        ),
                                        child: Column(
                                          children: replies.map((reply) {
                                            final isReplyOwner = currentUserId != null &&
                                                currentUserId == reply.author.id;

                                            return Padding(
                                              padding: const EdgeInsets.only(bottom: 12),
                                              child: Row(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  CircleAvatar(
                                                    radius: 14,
                                                    backgroundColor: AppColors.primaryFixed,
                                                    backgroundImage: reply.author.avatarUrl != null
                                                        ? CachedNetworkImageProvider(reply.author.avatarUrl!)
                                                        : null,
                                                    child: reply.author.avatarUrl == null
                                                        ? Text(
                                                            reply.author.username.isNotEmpty
                                                                ? reply.author.username[0].toUpperCase()
                                                                : 'P',
                                                            style: const TextStyle(
                                                              fontWeight: FontWeight.bold,
                                                              fontSize: 11,
                                                              color: AppColors.primary,
                                                            ),
                                                          )
                                                        : null,
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Row(
                                                          children: [
                                                            GestureDetector(
                                                              onTap: () => _openUserProfile(reply.author),
                                                              child: Text(
                                                                reply.author.username,
                                                                style: const TextStyle(
                                                                  fontWeight: FontWeight.bold,
                                                                  fontSize: 12,
                                                                  color: AppColors.onSurface,
                                                                ),
                                                              ),
                                                            ),
                                                            const SizedBox(width: 6),
                                                            Text(
                                                              _formatTimestamp(reply.createdAt),
                                                              style: TextStyle(
                                                                fontSize: 10,
                                                                color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        const SizedBox(height: 2),
                                                        _buildCommentContentWithMentions(reply.content, reply.mentions, fontSize: 13),
                                                        const SizedBox(height: 4),
                                                        GestureDetector(
                                                          onTap: () => _handleReplyClick(reply),
                                                          child: const Row(
                                                            mainAxisSize: MainAxisSize.min,
                                                            children: [
                                                              Icon(Icons.reply_rounded, size: 13, color: AppColors.secondary),
                                                              SizedBox(width: 3),
                                                              Text(
                                                                'Reply',
                                                                style: TextStyle(
                                                                  fontSize: 11,
                                                                  fontWeight: FontWeight.w600,
                                                                  color: AppColors.secondary,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  if (isReplyOwner)
                                                    IconButton(
                                                      icon: const Icon(
                                                        Icons.delete_outline,
                                                        size: 16,
                                                        color: AppColors.outline,
                                                      ),
                                                      padding: EdgeInsets.zero,
                                                      constraints: const BoxConstraints(),
                                                      onPressed: () => _deleteComment(reply),
                                                    ),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ],
                                  ],
                                );
                              },
                            );
                          },
                        ),
            ),

            // Replying to banner
            if (_replyingTo != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.secondaryContainer.withValues(alpha: 0.3),
                  border: const Border(
                    top: BorderSide(color: AppColors.surfaceContainerHigh, width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.reply_rounded, size: 16, color: AppColors.secondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Replying to @${_replyingTo!.author.username}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.secondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      color: AppColors.outline,
                      onPressed: _cancelReply,
                    ),
                  ],
                ),
              ),

            // Bottom Input Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(
                  top: BorderSide(color: AppColors.surfaceContainerHigh, width: 1),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          textCapitalization: TextCapitalization.sentences,
                          maxLines: 4,
                          minLines: 1,
                          style: const TextStyle(fontSize: 14),
                          decoration: InputDecoration(
                            hintText: _replyingTo != null
                                ? 'Reply to @${_replyingTo!.author.username}...'
                                : widget.postAuthorUsername != null
                                    ? 'Add a comment for ${widget.postAuthorUsername}...'
                                    : 'Add a comment...',
                            hintStyle: const TextStyle(
                              fontSize: 13,
                              color: AppColors.outline,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                          ),
                          onSubmitted: (_) => _submitComment(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _isSubmitting
                        ? const SizedBox(
                            width: 36,
                            height: 36,
                            child: Padding(
                              padding: EdgeInsets.all(8.0),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : IconButton(
                            icon: const Icon(Icons.send_rounded),
                            color: AppColors.primaryContainer,
                            onPressed: _submitComment,
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
