import 'climbing.dart';

/// A person's profile: who they are, what they climb and the gear they
/// have. When and where they climb belongs to their [Plan]s, which are
/// specific outings.
class Climber {
  const Climber({
    required this.id,
    required this.name,
    this.age,
    this.bio = '',
    this.photo,
    this.levels = const {},
    this.gear = const {},
    this.gearPhotos = const [],
  });

  /// The most gear photos a profile keeps.
  static const maxGearPhotos = 6;

  /// Given by the server at the first profile save; empty for a profile
  /// not saved yet.
  final String id;
  final String name;

  /// Optional: null when they'd rather not say.
  final int? age;
  final String bio;

  /// Their picture's key in the photo store (served at
  /// `<site>/photos/<key>`), or null for initials.
  final String? photo;

  /// The grades they climb, per discipline they do.
  final Map<Discipline, GradeRange> levels;
  final Set<Gear> gear;

  /// Pictures of their gear: keys in the photo store.
  final List<String> gearPhotos;

  Set<Discipline> get disciplines => levels.keys.toSet();

  /// "Name, age", or just the name when there's no age.
  String get nameAndAge => age == null ? name : '$name, $age';

  /// The first name, for short mentions.
  String get firstName => name.trim().split(RegExp(r'\s+')).first;

  /// The name's initials, for an avatar.
  String get initials {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    return words.take(2).map((w) => w[0].toUpperCase()).join();
  }

  static const _keep = Object();

  /// A copy with the given fields changed; `age: null` clears the age and
  /// `photo: null` the picture.
  Climber copyWith({
    String? name,
    Object? age = _keep,
    String? bio,
    Object? photo = _keep,
    Map<Discipline, GradeRange>? levels,
    Set<Gear>? gear,
    List<String>? gearPhotos,
  }) => Climber(
    id: id,
    name: name ?? this.name,
    age: identical(age, _keep) ? this.age : age as int?,
    bio: bio ?? this.bio,
    photo: identical(photo, _keep) ? this.photo : photo as String?,
    levels: levels ?? this.levels,
    gear: gear ?? this.gear,
    gearPhotos: gearPhotos ?? this.gearPhotos,
  );

  /// The profile as the API takes it (`PUT /api/me`): without the id.
  Map<String, Object?> toJson() => {
    'name': name,
    'age': age,
    'bio': bio,
    'photo': photo,
    'levels': {for (final e in levels.entries) e.key.name: e.value.toJson()},
    'gear': [for (final g in gear) g.name],
    'gearPhotos': gearPhotos,
  };

  /// Reads a profile from the API. Unknown disciplines and gear are
  /// skipped.
  static Climber fromJson(Map<String, Object?> json) => Climber(
    id: json['id']! as String,
    name: json['name']! as String,
    age: (json['age'] as num?)?.toInt(),
    bio: json['bio'] as String? ?? '',
    photo: json['photo'] as String?,
    levels: {
      for (final e in (json['levels'] as Map? ?? {}).entries)
        ?Discipline.values.asNameMap()[e.key]: GradeRange.fromJson(
          (e.value as Map).cast(),
        ),
    },
    gear: {
      for (final g in json['gear'] as List? ?? []) ?Gear.values.asNameMap()[g],
    },
    gearPhotos: [
      for (final p in json['gearPhotos'] as List? ?? []) p as String,
    ],
  );
}
