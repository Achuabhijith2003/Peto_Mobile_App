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
  final bool isVerified;
  final String? verificationBadgeType;
  final String? type;
  final bool isBusiness;
  final String? category;

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
    this.isVerified = false,
    this.verificationBadgeType,
    this.type,
    this.isBusiness = false,
    this.category,
  });

  bool get verified => isVerified;
  bool get isBusinessBadge => verificationBadgeType == 'BUSINESS';
  bool get isAdvertiserBadge => verificationBadgeType == 'ADVERTISER';
  bool get isPersonBadge => verificationBadgeType == 'PERSON';

  String get displayName =>
      (fullName != null && fullName!.trim().isNotEmpty) ? fullName! : (username.isNotEmpty ? username : 'Pet Parent');

  String? get bio => profile?.bio;
  String? get location => profile?.location;
  String? get website => profile?.website;
  String? get phone => profile?.phone;
  String? get dateOfBirth => profile?.dateOfBirth;

  static String? _firstNonEmpty(List<dynamic> items) {
    for (final item in items) {
      if (item != null) {
        final str = item.toString().trim();
        if (str.isNotEmpty) return str;
      }
    }
    return null;
  }

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
      avatarUrl: _firstNonEmpty([
        profileData['avatar_url'],
        profileData['avatarUrl'],
        json['avatar_url'],
        json['avatarUrl'],
      ]),
      coverUrl: _firstNonEmpty([
        profileData['cover_url'],
        profileData['coverUrl'],
        profileData['banner_url'],
        json['cover_url'],
        json['coverUrl'],
      ]),
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
      isVerified: json['verified'] == true ||
          json['is_verified'] == true ||
          profileData['verified'] == true ||
          profileData['is_verified'] == true,
      verificationBadgeType: json['verification_badge_type']?.toString() ??
          json['verificationBadgeType']?.toString() ??
          profileData['verification_badge_type']?.toString() ??
          profileData['verificationBadgeType']?.toString(),
      type: json['type']?.toString(),
      isBusiness: json['is_business'] == true ||
          json['type']?.toString().toUpperCase() == 'BUSINESS' ||
          json['verification_badge_type']?.toString().toUpperCase() == 'BUSINESS',
      category: json['category']?.toString(),
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
      'verified': isVerified,
      'verification_badge_type': verificationBadgeType,
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
    bool? isVerified,
    String? verificationBadgeType,
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
      isVerified: isVerified ?? this.isVerified,
      verificationBadgeType: verificationBadgeType ?? this.verificationBadgeType,
    );
  }
}

class BusinessModel {
  final String id;
  final String name;
  final String legalName;
  final String? username;
  final String countryCode;
  final String? state;
  final String? city;
  final String? websiteUrl;
  final String? publicEmail;
  final String? publicPhone;
  final String? businessCategory;
  final String? description;
  final String? avatarUrl;
  final String? coverUrl;
  final bool isVerified;
  final String? role;
  final bool canManage;

  BusinessModel({
    required this.id,
    required this.name,
    required this.legalName,
    this.username,
    required this.countryCode,
    this.state,
    this.city,
    this.websiteUrl,
    this.publicEmail,
    this.publicPhone,
    this.businessCategory,
    this.description,
    this.avatarUrl,
    this.coverUrl,
    this.isVerified = false,
    this.role,
    this.canManage = false,
  });

  String get category => businessCategory ?? '';

  factory BusinessModel.fromJson(Map<String, dynamic> json) {
    final verif = json['verification'] is Map ? json['verification'] as Map : null;
    final isV = json['is_verified'] == true ||
        verif?['verified'] == true ||
        verif?['status'] == 'APPROVED';
    final role = json['role']?.toString();
    final canM = json['canManage'] == true ||
        json['can_manage'] == true ||
        role == 'OWNER' ||
        role == 'ADMIN' ||
        json['isOwner'] == true;

    return BusinessModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Business',
      legalName: json['legal_name']?.toString() ?? json['name']?.toString() ?? '',
      username: json['username']?.toString(),
      countryCode: json['country_code']?.toString() ?? 'IN',
      state: json['state']?.toString(),
      city: json['city']?.toString(),
      websiteUrl: json['website_url']?.toString(),
      publicEmail: json['public_email']?.toString(),
      publicPhone: json['public_phone']?.toString(),
      businessCategory: json['business_category']?.toString(),
      description: json['description']?.toString(),
      avatarUrl: json['avatar_url']?.toString(),
      coverUrl: json['cover_url']?.toString(),
      isVerified: isV,
      role: role,
      canManage: canM,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'legal_name': legalName,
      'username': username,
      'country_code': countryCode,
      'state': state,
      'city': city,
      'website_url': websiteUrl,
      'public_email': publicEmail,
      'public_phone': publicPhone,
      'business_category': businessCategory,
      'description': description,
      'avatar_url': avatarUrl,
      'cover_url': coverUrl,
      'is_verified': isVerified,
      'role': role,
      'canManage': canManage,
    };
  }
}

class ActiveIdentityModel {
  final String type; // 'PERSON' or 'BUSINESS'
  final String id;
  final String name;
  final String? avatarUrl;
  final bool isVerified;
  final String? role;
  final BusinessModel? business;

  ActiveIdentityModel({
    required this.type,
    required this.id,
    required this.name,
    this.avatarUrl,
    this.isVerified = false,
    this.role,
    this.business,
  });

  bool get isBusiness => type == 'BUSINESS';
}

