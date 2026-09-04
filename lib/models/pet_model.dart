class Pet {
  final String id;
  final String name;
  final String species; // Dog, Cat, Bird, Exotic, etc.
  final String? breed;
  final int? ageYears;
  final String? bio;
  final String? avatarUrl;

  Pet({
    required this.id,
    required this.name,
    required this.species,
    this.breed,
    this.ageYears,
    this.bio,
    this.avatarUrl,
  });

  factory Pet.fromJson(Map<String, dynamic> json) {
    return Pet(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unnamed Pet',
      species: json['species']?.toString() ?? 'Dog',
      breed: json['breed'] as String?,
      ageYears: json['age'] is int ? json['age'] : int.tryParse(json['age']?.toString() ?? ''),
      bio: json['bio'] as String?,
      avatarUrl: json['avatar_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'species': species,
      'breed': breed,
      'age': ageYears,
      'bio': bio,
      'avatar_url': avatarUrl,
    };
  }
}
