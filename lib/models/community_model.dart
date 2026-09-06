class CommunityRule {
  final String id;
  final String title;
  final String description;
  final int position;

  CommunityRule({
    required this.id,
    required this.title,
    required this.description,
    this.position = 0,
  });

  factory CommunityRule.fromJson(Map<String, dynamic> json) {
    return CommunityRule(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      position: json['position'] is int
          ? json['position']
          : int.tryParse(json['position']?.toString() ?? '0') ?? 0,
    );
  }
}

class CommunityMember {
  final String id;
  final String userId;
  final String username;
  final String? fullName;
  final String? avatarUrl;
  final String role; // owner, moderator, member
  final String status; // active, pending, banned
  final DateTime? joinedAt;

  CommunityMember({
    required this.id,
    required this.userId,
    required this.username,
    this.fullName,
    this.avatarUrl,
    required this.role,
    this.status = 'active',
    this.joinedAt,
  });

  factory CommunityMember.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] is Map<String, dynamic>
        ? json['profiles'] as Map<String, dynamic>
        : (json['profile'] is Map<String, dynamic> ? json['profile'] as Map<String, dynamic> : null);

    return CommunityMember(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? profile?['id']?.toString() ?? '',
      username: profile?['username']?.toString() ?? json['username']?.toString() ?? 'Member',
      fullName: profile?['full_name']?.toString() ?? json['full_name']?.toString(),
      avatarUrl: profile?['avatar_url']?.toString() ?? json['avatar_url']?.toString(),
      role: json['role']?.toString() ?? 'member',
      status: json['status']?.toString() ?? 'active',
      joinedAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }
}

class Community {
  final String id;
  final String name;
  final String slug;
  final String description;
  final String category;
  final String? coverImageUrl;
  final String? iconUrl;
  final String visibility; // public, private
  final int memberCount;
  final int postCount;
  final bool isJoined;
  final String? ownerId;
  final String? viewerRole;
  final String? viewerStatus;
  final List<CommunityRule> rules;

  Community({
    required this.id,
    required this.name,
    required this.slug,
    required this.description,
    required this.category,
    this.coverImageUrl,
    this.iconUrl,
    this.visibility = 'public',
    this.memberCount = 0,
    this.postCount = 0,
    this.isJoined = false,
    this.ownerId,
    this.viewerRole,
    this.viewerStatus,
    this.rules = const [],
  });

  String? get bannerUrl => coverImageUrl;

  bool get isPrivate => visibility.toLowerCase() == 'private';
  bool get isOwner => viewerRole?.toLowerCase() == 'owner';
  bool get isModerator => viewerRole?.toLowerCase() == 'moderator' || isOwner;

  bool isUserOwner(String? currentUserId) {
    if (isOwner) return true;
    if (currentUserId != null && ownerId != null && ownerId == currentUserId) {
      return true;
    }
    return false;
  }

  bool isUserModerator(String? currentUserId) {
    return isModerator || isUserOwner(currentUserId);
  }

  factory Community.fromJson(Map<String, dynamic> json) {
    final viewer = json['viewer'] is Map<String, dynamic> ? json['viewer'] as Map<String, dynamic> : null;
    final ownerIdStr = json['owner_id']?.toString() ??
        (json['owner'] is Map<String, dynamic> ? json['owner']['id']?.toString() : null);
    final role = viewer?['role']?.toString();
    final isRoleOwner = role?.toLowerCase() == 'owner';
    final isMember = isRoleOwner || (viewer != null ? viewer['is_member'] == true : (json['is_joined'] == true));

    var rulesList = <CommunityRule>[];
    if (json['rules'] is List) {
      rulesList = (json['rules'] as List)
          .whereType<Map<String, dynamic>>()
          .map((r) => CommunityRule.fromJson(r))
          .toList();
    }

    return Community(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Circle',
      slug: json['slug']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      category: json['category']?.toString() ?? 'General',
      coverImageUrl: json['cover_image_url']?.toString() ?? json['banner_url']?.toString(),
      iconUrl: json['icon_url']?.toString(),
      visibility: json['visibility']?.toString() ?? 'public',
      memberCount: json['member_count'] is int
          ? json['member_count']
          : int.tryParse(json['member_count']?.toString() ?? '0') ?? 0,
      postCount: json['post_count'] is int
          ? json['post_count']
          : int.tryParse(json['post_count']?.toString() ?? '0') ?? 0,
      isJoined: isMember,
      ownerId: ownerIdStr,
      viewerRole: role,
      viewerStatus: viewer?['status']?.toString(),
      rules: rulesList,
    );
  }

  Community copyWith({
    String? name,
    String? slug,
    String? description,
    String? category,
    String? coverImageUrl,
    String? iconUrl,
    String? visibility,
    bool? isJoined,
    int? memberCount,
    int? postCount,
    String? viewerRole,
    String? viewerStatus,
    List<CommunityRule>? rules,
  }) {
    return Community(
      id: id,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      description: description ?? this.description,
      category: category ?? this.category,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      iconUrl: iconUrl ?? this.iconUrl,
      visibility: visibility ?? this.visibility,
      memberCount: memberCount ?? this.memberCount,
      postCount: postCount ?? this.postCount,
      isJoined: isJoined ?? this.isJoined,
      ownerId: ownerId,
      viewerRole: viewerRole ?? this.viewerRole,
      viewerStatus: viewerStatus ?? this.viewerStatus,
      rules: rules ?? this.rules,
    );
  }
}
