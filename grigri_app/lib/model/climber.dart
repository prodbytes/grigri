import 'dart:convert';
import 'dart:typed_data';

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

  /// The most gear photos a profile keeps (they're stored on the device).
  static const maxGearPhotos = 6;

  final String id;
  final String name;

  /// Optional: null when they'd rather not say.
  final int? age;
  final String bio;

  /// Their picture (JPEG bytes, already downsized), or null for initials.
  final Uint8List? photo;

  /// The grades they climb, per discipline they do.
  final Map<Discipline, GradeRange> levels;
  final Set<Gear> gear;

  /// Pictures of their gear (JPEG bytes, already downsized).
  final List<Uint8List> gearPhotos;

  Set<Discipline> get disciplines => levels.keys.toSet();

  /// "Name, age", or just the name when there's no age.
  String get nameAndAge => age == null ? name : '$name, $age';

  /// The name's initials, for an avatar.
  String get initials {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    return words.take(2).map((w) => w[0].toUpperCase()).join();
  }

  static const _keep = Object();

  /// A copy with the given fields changed; `age: null` clears the age and
  /// [clearPhoto] removes the picture.
  Climber copyWith({
    String? name,
    Object? age = _keep,
    String? bio,
    Uint8List? photo,
    bool clearPhoto = false,
    Map<Discipline, GradeRange>? levels,
    Set<Gear>? gear,
    List<Uint8List>? gearPhotos,
  }) => Climber(
    id: id,
    name: name ?? this.name,
    age: identical(age, _keep) ? this.age : age as int?,
    bio: bio ?? this.bio,
    photo: clearPhoto ? null : photo ?? this.photo,
    levels: levels ?? this.levels,
    gear: gear ?? this.gear,
    gearPhotos: gearPhotos ?? this.gearPhotos,
  );

  Map<String, Object> toJson() => {
    'id': id,
    'name': name,
    'age': ?age,
    'bio': bio,
    if (photo != null) 'photo': base64Encode(photo!),
    'levels': {for (final e in levels.entries) e.key.name: e.value.toJson()},
    'gear': [for (final g in gear) g.name],
    'gearPhotos': [for (final p in gearPhotos) base64Encode(p)],
  };

  /// Reads a saved profile. Fields older versions saved (home area, years
  /// climbing, availability, places) are ignored.
  static Climber fromJson(Map<String, Object?> json) => Climber(
    id: json['id']! as String,
    name: json['name']! as String,
    age: json['age'] as int?,
    bio: json['bio'] as String? ?? '',
    photo: switch (json['photo']) {
      final String p => base64Decode(p),
      _ => null,
    },
    levels: {
      for (final e in (json['levels'] as Map? ?? {}).entries)
        Discipline.values.byName(e.key as String): GradeRange.fromJson(
          (e.value as Map).cast(),
        ),
    },
    gear: {
      for (final g in json['gear'] as List? ?? [])
        Gear.values.byName(g as String),
    },
    gearPhotos: [
      for (final p in json['gearPhotos'] as List? ?? [])
        base64Decode(p as String),
    ],
  );
}
