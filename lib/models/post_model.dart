import 'user_model.dart';

class PostMedia {
  final String url;
  final String? type; // image, video

  PostMedia({required this.url, this.type = 'image'});

  static String sanitizeUrl(String rawUrl) {
    return rawUrl
        .replaceAll('/posts-images/posts-images/', '/posts-images/')
        .replaceAll('/posts-videos/posts-videos/', '/posts-videos/');
  }

  static bool isVideoUrl(String url, {String? type}) {
    if (type?.toLowerCase() == 'video') return true;
    final lower = url.toLowerCase();
    if (lower.contains('/posts-videos/')) return true;
    return RegExp(r'\.(mp4|webm|mov|mkv|avi)(\?.*)?$', caseSensitive: false).hasMatch(lower);
  }

  bool get isVideo => isVideoUrl(url, type: type);

  factory PostMedia.fromJson(dynamic json) {
    if (json is String) {
      final sanitized = sanitizeUrl(json);
      final inferredType = isVideoUrl(sanitized) ? 'video' : 'image';
      return PostMedia(url: sanitized, type: inferredType);
    } else if (json is Map<String, dynamic>) {
      final rawUrl = json['url']?.toString() ?? json['path']?.toString() ?? '';
      final sanitized = sanitizeUrl(rawUrl);
      var mediaType = json['type']?.toString();
      if (mediaType == null || mediaType.isEmpty) {
        mediaType = isVideoUrl(sanitized) ? 'video' : 'image';
      }
      return PostMedia(
        url: sanitized,
        type: mediaType,
      );
    }
    return PostMedia(url: '');
  }

  Map<String, dynamic> toJson() => {'url': url, 'type': type};
}

class PostComment {
  final String id;
  final String content;
  final User author;
  final DateTime createdAt;

  PostComment({
    required this.id,
    required this.content,
    required this.author,
    required this.createdAt,
  });

  factory PostComment.fromJson(Map<String, dynamic> json) {
    User commentAuthor;
    if (json['author'] != null && json['author'] is Map<String, dynamic>) {
      commentAuthor = User.fromJson(json['author'] as Map<String, dynamic>);
    } else if (json['profiles'] != null && json['profiles'] is Map<String, dynamic>) {
      final p = json['profiles'] as Map<String, dynamic>;
      commentAuthor = User(
        id: p['id']?.toString() ?? '',
        email: '',
        username: p['username']?.toString() ?? p['full_name']?.toString() ?? 'Pet Lover',
        avatarUrl: p['avatar_url']?.toString(),
      );
    } else if (json['user'] != null && json['user'] is Map<String, dynamic>) {
      commentAuthor = User.fromJson(json['user'] as Map<String, dynamic>);
    } else {
      commentAuthor = User(id: '', email: '', username: 'Pet Lover');
    }

    return PostComment(
      id: json['id']?.toString() ?? '',
      content: json['comment']?.toString() ?? json['content']?.toString() ?? '',
      author: commentAuthor,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class Post {
  final String id;
  final String content;
  final User author;
  final List<PostMedia> media;
  final String? communityId;
  final String? communityName;
  final int likesCount;
  final int commentsCount;
  final bool isLiked;
  final bool isBookmarked;
  final DateTime createdAt;

  Post({
    required this.id,
    required this.content,
    required this.author,
    this.media = const [],
    this.communityId,
    this.communityName,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.isLiked = false,
    this.isBookmarked = false,
    required this.createdAt,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    var mediaList = <PostMedia>[];
    if (json['media'] != null && json['media'] is List) {
      mediaList = (json['media'] as List)
          .map((m) => PostMedia.fromJson(m))
          .where((m) => m.url.isNotEmpty)
          .toList();
    } else if (json['media_url'] != null && json['media_url'].toString().isNotEmpty) {
      mediaList = [PostMedia.fromJson(json['media_url'])];
    } else if (json['video_url'] != null && json['video_url'].toString().isNotEmpty) {
      mediaList = [PostMedia.fromJson(json['video_url'])];
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

    return Post(
      id: json['id']?.toString() ?? '',
      content: json['content']?.toString() ?? json['text']?.toString() ?? '',
      author: authorUser,
      media: mediaList,
      communityId: json['community_id']?.toString(),
      communityName: json['community_name']?.toString() ?? json['community']?['name']?.toString(),
      likesCount: likes,
      commentsCount: comments,
      isLiked: isLiked,
      isBookmarked: isBookmarked,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Post copyWith({
    int? likesCount,
    int? commentsCount,
    bool? isLiked,
    bool? isBookmarked,
  }) {
    return Post(
      id: id,
      content: content,
      author: author,
      media: media,
      communityId: communityId,
      communityName: communityName,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      isLiked: isLiked ?? this.isLiked,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      createdAt: createdAt,
    );
  }
}
