import 'user_model.dart';

class Reel {
  final String id;
  final String mediaUrl;
  final String? thumbnailUrl;
  final String? caption;
  final User author;
  final int likesCount;
  final int commentsCount;
  final bool isLiked;
  final bool isBookmarked;

  Reel({
    required this.id,
    required this.mediaUrl,
    this.thumbnailUrl,
    this.caption,
    required this.author,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.isLiked = false,
    this.isBookmarked = false,
  });

  static String sanitizeUrl(String rawUrl) {
    return rawUrl
        .replaceAll('/posts-images/posts-images/', '/posts-images/')
        .replaceAll('/posts-videos/posts-videos/', '/posts-videos/');
  }

  static bool isVideoUrl(String url) {
    if (url.isEmpty) return false;
    final lower = url.toLowerCase();
    if (lower.contains('/posts-videos/')) return true;
    if (lower.contains('/video/') || lower.contains('/videos/')) return true;
    return RegExp(r'\.(mp4|webm|mov|mkv|avi|m4v)(\?.*)?$', caseSensitive: false).hasMatch(lower);
  }

  factory Reel.fromJson(Map<String, dynamic> json) {
    String mediaUrl = '';
    String? thumbUrl = json['thumbnail_url']?.toString() ?? json['thumbnail']?.toString();

    if (json['media'] is List && (json['media'] as List).isNotEmpty) {
      final mediaList = json['media'] as List;
      dynamic videoItem;

      for (final m in mediaList) {
        if (m is Map) {
          if (m['type']?.toString().toLowerCase() == 'video') {
            videoItem = m;
            break;
          }
          final u = m['url']?.toString() ?? m['path']?.toString() ?? m['src']?.toString() ?? '';
          if (isVideoUrl(u)) {
            videoItem = m;
            break;
          }
        } else if (m is String && isVideoUrl(m)) {
          videoItem = m;
          break;
        }
      }

      if (videoItem != null) {
        if (videoItem is Map) {
          mediaUrl = videoItem['url']?.toString() ?? videoItem['path']?.toString() ?? videoItem['src']?.toString() ?? '';
          thumbUrl = thumbUrl ?? videoItem['thumbnail_url']?.toString() ?? videoItem['thumbnail']?.toString();
        } else if (videoItem is String) {
          mediaUrl = videoItem;
        }
      }
    }

    if (mediaUrl.isEmpty) {
      mediaUrl = json['video_url']?.toString() ?? json['media_url']?.toString() ?? '';
    }

    if (mediaUrl.isEmpty && json['media'] is List && (json['media'] as List).isNotEmpty) {
      final first = (json['media'] as List).first;
      if (first is Map) {
        mediaUrl = first['url']?.toString() ?? first['path']?.toString() ?? first['src']?.toString() ?? '';
        thumbUrl = thumbUrl ?? first['thumbnail_url']?.toString() ?? first['thumbnail']?.toString();
      } else if (first is String) {
        mediaUrl = first;
      }
    }

    mediaUrl = sanitizeUrl(mediaUrl);
    if (thumbUrl != null && thumbUrl.isNotEmpty) {
      thumbUrl = sanitizeUrl(thumbUrl);
    }

    User authorUser;
    if (json['author'] != null && json['author'] is Map<String, dynamic>) {
      authorUser = User.fromJson(json['author'] as Map<String, dynamic>);
    } else if (json['profiles'] != null && json['profiles'] is Map<String, dynamic>) {
      final p = json['profiles'] as Map<String, dynamic>;
      authorUser = User(
        id: p['id']?.toString() ?? json['user_id']?.toString() ?? '',
        email: '',
        username: p['username']?.toString() ?? p['full_name']?.toString() ?? 'Pet Lover',
        avatarUrl: p['avatar_url']?.toString(),
      );
    } else if (json['user'] != null && json['user'] is Map<String, dynamic>) {
      authorUser = User.fromJson(json['user'] as Map<String, dynamic>);
    } else {
      authorUser = User(id: json['user_id']?.toString() ?? '', email: '', username: 'Pet Lover');
    }

    final stats = json['stats'] is Map<String, dynamic> ? json['stats'] as Map<String, dynamic> : null;
    final viewer = json['viewer'] is Map<String, dynamic> ? json['viewer'] as Map<String, dynamic> : null;

    final rawLikes = json['likes_count'] ?? stats?['likes'];
    final rawComments = json['comments_count'] ?? stats?['comments'];

    final likes = rawLikes is int ? rawLikes : int.tryParse(rawLikes?.toString() ?? '0') ?? 0;
    final comments = rawComments is int ? rawComments : int.tryParse(rawComments?.toString() ?? '0') ?? 0;

    final isLiked = json['is_liked'] == true || viewer?['liked'] == true;
    final isBookmarked = json['is_bookmarked'] == true || viewer?['bookmarked'] == true;

    return Reel(
      id: json['id']?.toString() ?? '',
      mediaUrl: mediaUrl,
      thumbnailUrl: thumbUrl,
      caption: json['caption']?.toString() ?? json['content']?.toString() ?? json['text']?.toString(),
      author: authorUser,
      likesCount: likes,
      commentsCount: comments,
      isLiked: isLiked,
      isBookmarked: isBookmarked,
    );
  }

  Reel copyWith({
    int? likesCount,
    int? commentsCount,
    bool? isLiked,
    bool? isBookmarked,
    String? thumbnailUrl,
  }) {
    return Reel(
      id: id,
      mediaUrl: mediaUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      caption: caption,
      author: author,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      isLiked: isLiked ?? this.isLiked,
      isBookmarked: isBookmarked ?? this.isBookmarked,
    );
  }
}
