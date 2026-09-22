class PetParent {
  final String id;
  final String userId;
  final String relationshipType;
  final bool isPrimary;
  final String status;
  final String username;
  final String fullName;
  final String avatarUrl;
  final bool verified;

  PetParent({
    required this.id,
    required this.userId,
    required this.relationshipType,
    required this.isPrimary,
    required this.status,
    required this.username,
    required this.fullName,
    required this.avatarUrl,
    required this.verified,
  });

  factory PetParent.fromJson(Map<String, dynamic> json) {
    return PetParent(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      relationshipType: json['relationship_type']?.toString() ?? 'CO_OWNER',
      isPrimary: json['is_primary'] == true,
      status: json['status']?.toString() ?? 'ACTIVE',
      username: json['username']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      avatarUrl: json['avatar_url']?.toString() ?? '',
      verified: json['verified'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'relationship_type': relationshipType,
      'is_primary': isPrimary,
      'status': status,
      'username': username,
      'full_name': fullName,
      'avatar_url': avatarUrl,
      'verified': verified,
    };
  }
}

class PetMedia {
  final String id;
  final String mediaId;
  final String mediaType;
  final String mediaUrl;
  final String? caption;
  final bool isProfile;
  final bool isCover;

  PetMedia({
    required this.id,
    required this.mediaId,
    required this.mediaType,
    required this.mediaUrl,
    this.caption,
    required this.isProfile,
    required this.isCover,
  });

  factory PetMedia.fromJson(Map<String, dynamic> json) {
    return PetMedia(
      id: json['id']?.toString() ?? '',
      mediaId: json['media_id']?.toString() ?? '',
      mediaType: json['media_type']?.toString() ?? 'IMAGE',
      mediaUrl: json['media_url']?.toString() ?? '',
      caption: json['caption'] as String?,
      isProfile: json['is_profile'] == true,
      isCover: json['is_cover'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'media_id': mediaId,
      'media_type': mediaType,
      'media_url': mediaUrl,
      'caption': caption,
      'is_profile': isProfile,
      'is_cover': isCover,
    };
  }
}

class PetViewerPermissions {
  final bool canView;
  final bool canEdit;
  final bool canUploadMedia;
  final bool canManageParents;
  final bool canManagePrivacy;

  PetViewerPermissions({
    this.canView = true,
    this.canEdit = false,
    this.canUploadMedia = false,
    this.canManageParents = false,
    this.canManagePrivacy = false,
  });

  factory PetViewerPermissions.fromJson(Map<String, dynamic> json) {
    return PetViewerPermissions(
      canView: json['can_view'] != false,
      canEdit: json['can_edit'] == true,
      canUploadMedia: json['can_upload_media'] == true,
      canManageParents: json['can_manage_parents'] == true,
      canManagePrivacy: json['can_manage_privacy'] == true,
    );
  }
}

class Pet {
  final String id;
  final String name;
  final String species; // DOG, CAT, BIRD, RABBIT, etc.
  final String? speciesName;
  final String? breed;
  final String? sex;
  final String? dateOfBirth;
  final int? approximateAgeMonths;
  final String? size;
  final String? color;
  final String? bio;
  final String? country;
  final String? state;
  final String? city;
  final String visibility; // PUBLIC, CONNECTIONS, PRIVATE
  final String? avatarUrl;
  final String? coverUrl;
  final List<PetParent> parents;
  final List<PetMedia> media;
  final PetViewerPermissions permissions;

  Pet({
    required this.id,
    required this.name,
    required this.species,
    this.speciesName,
    this.breed,
    this.sex,
    this.dateOfBirth,
    this.approximateAgeMonths,
    this.size,
    this.color,
    this.bio,
    this.country,
    this.state,
    this.city,
    this.visibility = 'PUBLIC',
    this.avatarUrl,
    this.coverUrl,
    this.parents = const [],
    this.media = const [],
    PetViewerPermissions? permissions,
  }) : permissions = permissions ?? PetViewerPermissions();

  String get displaySpecies {
    if (species.toUpperCase() == 'OTHER' && speciesName != null && speciesName!.trim().isNotEmpty) {
      return speciesName!;
    }
    return species;
  }

  String get speciesEmoji {
    switch (species.toUpperCase()) {
      case 'DOG':
        return '🐶';
      case 'CAT':
        return '🐱';
      case 'BIRD':
        return '🦜';
      case 'RABBIT':
        return '🐰';
      case 'FISH':
        return '🐠';
      case 'HAMSTER':
        return '🐹';
      case 'HORSE':
        return '🐴';
      case 'REPTILE':
        return '🦎';
      default:
        return '🐾';
    }
  }

  String? get formattedAge {
    if (dateOfBirth != null && dateOfBirth!.isNotEmpty) {
      try {
        final birth = DateTime.parse(dateOfBirth!);
        final now = DateTime.now();
        int years = now.year - birth.year;
        int months = now.month - birth.month;
        if (months < 0) {
          years--;
          months += 12;
        }
        if (years > 0) {
          return '$years yr${years > 1 ? "s" : ""}${months > 0 ? " $months mo" : ""}';
        }
        return '${months > 0 ? months : 1} month${months > 1 ? "s" : ""}';
      } catch (_) {}
    }
    if (approximateAgeMonths != null && approximateAgeMonths! > 0) {
      final yrs = approximateAgeMonths! ~/ 12;
      final mos = approximateAgeMonths! % 12;
      if (yrs > 0) {
        return 'Approx. $yrs yr${yrs > 1 ? "s" : ""}${mos > 0 ? " $mos mo" : ""}';
      }
      return 'Approx. $approximateAgeMonths! month${approximateAgeMonths! > 1 ? "s" : ""}';
    }
    return null;
  }

  factory Pet.fromJson(Map<String, dynamic> json) {
    var rawParents = json['parents'];
    List<PetParent> parsedParents = [];
    if (rawParents is List) {
      parsedParents = rawParents
          .whereType<Map>()
          .map((p) => PetParent.fromJson(Map<String, dynamic>.from(p)))
          .toList();
    }

    var rawMedia = json['media'];
    List<PetMedia> parsedMedia = [];
    if (rawMedia is List) {
      parsedMedia = rawMedia
          .whereType<Map>()
          .map((m) => PetMedia.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    }

    return Pet(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unnamed Pet',
      species: json['species']?.toString() ?? 'DOG',
      speciesName: json['species_name'] as String?,
      breed: json['breed'] as String?,
      sex: json['sex'] as String?,
      dateOfBirth: json['date_of_birth'] as String?,
      approximateAgeMonths: json['approximate_age_months'] is int
          ? json['approximate_age_months']
          : int.tryParse(json['approximate_age_months']?.toString() ?? ''),
      size: json['size'] as String?,
      color: json['color'] as String?,
      bio: json['bio'] as String?,
      country: json['country'] as String?,
      state: json['state'] as String?,
      city: json['city'] as String?,
      visibility: json['visibility']?.toString() ?? 'PUBLIC',
      avatarUrl: (json['profile_photo_url'] ?? json['avatar_url']) as String?,
      coverUrl: (json['cover_photo_url'] ?? json['cover_url']) as String?,
      parents: parsedParents,
      media: parsedMedia,
      permissions: json['viewer_permissions'] is Map
          ? PetViewerPermissions.fromJson(Map<String, dynamic>.from(json['viewer_permissions']))
          : PetViewerPermissions(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'species': species,
      'species_name': speciesName,
      'breed': breed,
      'sex': sex,
      'date_of_birth': dateOfBirth,
      'approximate_age_months': approximateAgeMonths,
      'size': size,
      'color': color,
      'bio': bio,
      'country': country,
      'state': state,
      'city': city,
      'visibility': visibility,
      'profile_photo_url': avatarUrl,
      'cover_photo_url': coverUrl,
      'parents': parents.map((p) => p.toJson()).toList(),
      'media': media.map((m) => m.toJson()).toList(),
    };
  }
}
