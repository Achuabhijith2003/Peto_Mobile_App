class UserProfile {
  final String? fullName;
  final String? bio;
  final String? location;
  final String? coverUrl;
  final String? website;
  final String? phone;
  final String? dateOfBirth;

  UserProfile({
    this.fullName,
    this.bio,
    this.location,
    this.coverUrl,
    this.website,
    this.phone,
    this.dateOfBirth,
  });

  String? get bannerUrl => coverUrl;

  factory UserProfile.fromJson(Map<String, dynamic>? json) {
    if (json == null) return UserProfile();
    return UserProfile(
      fullName: json['full_name']?.toString() ?? json['fullName']?.toString(),
      bio: json['bio']?.toString(),
      location: json['location']?.toString(),
      coverUrl: json['cover_url']?.toString() ?? json['banner_url']?.toString(),
      website: json['website']?.toString(),
      phone: json['phone']?.toString(),
      dateOfBirth: json['date_of_birth']?.toString() ?? json['dateOfBirth']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'full_name': fullName,
      'bio': bio,
      'location': location,
      'cover_url': coverUrl,
      'website': website,
      'phone': phone,
      'date_of_birth': dateOfBirth,
    };
  }
}

class User {
  final String id;
  final String email;
  final String username;
  final String? fullName;
  final String? avatarUrl;
  final String? coverUrl;
  final UserProfile? profile;
  final int postsCount;
  final int followersCount;
  final int followingCount;
  final bool isFollowing;

  User({
    required this.id,
    required this.email,
    required this.username,
    this.fullName,
    this.avatarUrl,
    this.coverUrl,
    this.profile,
    this.postsCount = 0,
    this.followersCount = 0,
    this.followingCount = 0,
    this.isFollowing = false,
  });

  String get displayName =>
      (fullName != null && fullName!.trim().isNotEmpty) ? fullName! : (username.isNotEmpty ? username : 'Pet Parent');

  String? get bio => profile?.bio;
  String? get location => profile?.location;
  String? get website => profile?.website;
  String? get phone => profile?.phone;
  String? get dateOfBirth => profile?.dateOfBirth;

  factory User.fromJson(Map<String, dynamic> json) {
    final profileData = json['profile'] is Map<String, dynamic>
        ? json['profile'] as Map<String, dynamic>
        : json;

    final resolvedProfile = UserProfile.fromJson(profileData);

    return User(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      username: json['username']?.toString() ?? profileData['username']?.toString() ?? '',
      fullName: profileData['full_name']?.toString() ??
          profileData['fullName']?.toString() ??
          json['full_name']?.toString() ??
          json['name']?.toString(),
      avatarUrl: json['avatar_url']?.toString() ?? profileData['avatar_url']?.toString(),
      coverUrl: json['cover_url']?.toString() ?? profileData['cover_url']?.toString() ?? profileData['banner_url']?.toString(),
      profile: resolvedProfile,
      postsCount: json['posts_count'] is int
          ? json['posts_count']
          : int.tryParse(json['posts_count']?.toString() ?? '0') ?? 0,
      followersCount: json['followers_count'] is int
          ? json['followers_count']
          : int.tryParse(json['followers_count']?.toString() ?? '0') ?? 0,
      followingCount: json['following_count'] is int
          ? json['following_count']
          : int.tryParse(json['following_count']?.toString() ?? '0') ?? 0,
      isFollowing: json['isFollowing'] == true ||
          json['is_following'] == true ||
          json['following'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'username': username,
      'full_name': fullName,
      'avatar_url': avatarUrl,
      'cover_url': coverUrl,
      'profile': profile?.toJson(),
      'posts_count': postsCount,
      'followers_count': followersCount,
      'following_count': followingCount,
      'is_following': isFollowing,
    };
  }

  User copyWith({
    String? username,
    String? fullName,
    String? avatarUrl,
    String? coverUrl,
    UserProfile? profile,
    int? postsCount,
    int? followersCount,
    int? followingCount,
    bool? isFollowing,
  }) {
    return User(
      id: id,
      email: email,
      username: username ?? this.username,
      fullName: fullName ?? this.fullName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      coverUrl: coverUrl ?? this.coverUrl,
      profile: profile ?? this.profile,
      postsCount: postsCount ?? this.postsCount,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      isFollowing: isFollowing ?? this.isFollowing,
    );
  }
}
