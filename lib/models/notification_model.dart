import 'user_model.dart';

class NotificationItem {
  final String id;
  final String recipientId;
  final String? actorId;
  final String? postId;
  final String? commentId;
  final String type;
  final String message;
  final bool isRead;
  final DateTime createdAt;
  final User? actor;

  NotificationItem({
    required this.id,
    required this.recipientId,
    this.actorId,
    this.postId,
    this.commentId,
    required this.type,
    required this.message,
    this.isRead = false,
    required this.createdAt,
    this.actor,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    User? actorUser;
    final actorData = json['actor'] ?? json['profiles'] ?? json['user'];
    if (actorData is Map<String, dynamic>) {
      actorUser = User(
        id: actorData['id']?.toString() ?? json['actor_id']?.toString() ?? '',
        email: actorData['email']?.toString() ?? '',
        username: actorData['username']?.toString() ?? actorData['full_name']?.toString() ?? 'Someone',
        avatarUrl: actorData['avatar_url']?.toString(),
      );
    }

    return NotificationItem(
      id: json['id']?.toString() ?? '',
      recipientId: json['recipient_id']?.toString() ?? json['user_id']?.toString() ?? '',
      actorId: json['actor_id']?.toString(),
      postId: json['post_id']?.toString(),
      commentId: json['comment_id']?.toString(),
      type: json['type']?.toString().toLowerCase() ?? 'system',
      message: json['message']?.toString() ?? '',
      isRead: json['is_read'] == true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      actor: actorUser,
    );
  }

  NotificationItem copyWith({
    bool? isRead,
  }) {
    return NotificationItem(
      id: id,
      recipientId: recipientId,
      actorId: actorId,
      postId: postId,
      commentId: commentId,
      type: type,
      message: message,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
      actor: actor,
    );
  }
}
