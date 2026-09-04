import 'user_model.dart';

class Reel {
  final String id;
  final String mediaUrl;
  final String? caption;
  final User author;
  final int likesCount;
  final int commentsCount;
  final bool isLiked;
  final bool isBookmarked;

  Reel({
    required this.id,
    required this.mediaUrl,
    this.caption,
    required this.author,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.isLiked = false,
    this.isBookmarked = false,
  });

  factory Reel.fromJson(Map<String, dynamic> json) {
    String mediaUrl = json['media_url']?.toString() ?? json['video_url']?.toString() ?? '';
    if (mediaUrl.isEmpty && json['media'] is List && (json['media'] as List).isNotEmpty) {
      final firstMedia = (json['media'] as List).first;
      if (firstMedia is Map) {
        mediaUrl = firstMedia['url']?.toString() ?? '';
      } else if (firstMedia is String) {
        mediaUrl = firstMedia;
      }
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
  }) {
    return Reel(
      id: id,
      mediaUrl: mediaUrl,
      caption: caption,
      author: author,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      isLiked: isLiked ?? this.isLiked,
      isBookmarked: isBookmarked ?? this.isBookmarked,
    );
  }
}
