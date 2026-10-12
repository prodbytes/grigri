import 'climbing.dart';

/// A person's profile: who they are and how, when and where they like to
/// climb. Separate from their [Plan]s, which are specific outings.
class Climber {
  const Climber({
    required this.id,
    required this.name,
    this.age,
    this.bio = '',
    this.homeArea = '',
    this.yearsClimbing = 0,
    this.levels = const {},
    this.availability = const {},
    this.places = const [],
    this.gear = const {},
  });

  final String id;
  final String name;

  /// Optional: null when they'd rather not say.
  final int? age;
  final String bio;

  /// Where they live or usually climb from, e.g. "Barcelona".
  final String homeArea;
  final int yearsClimbing;

  /// The grades they climb, per discipline they do.
  final Map<Discipline, GradeRange> levels;

  /// When they like to climb.
  final Set<Slot> availability;

  /// Crags and gyms they like to climb at.
  final List<String> places;
  final Set<Gear> gear;

  Set<Discipline> get disciplines => levels.keys.toSet();

  /// "Name, age", or just the name when there's no age.
  String get nameAndAge => age == null ? name : '$name, $age';

  /// The name's initials, for an avatar.
  String get initials {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    return words.take(2).map((w) => w[0].toUpperCase()).join();
  }

  static const _keep = Object();

  /// A copy with the given fields changed; `age: null` clears the age.
  Climber copyWith({
    String? name,
    Object? age = _keep,
    String? bio,
    String? homeArea,
    int? yearsClimbing,
    Map<Discipline, GradeRange>? levels,
    Set<Slot>? availability,
    List<String>? places,
    Set<Gear>? gear,
  }) => Climber(
    id: id,
    name: name ?? this.name,
    age: identical(age, _keep) ? this.age : age as int?,
    bio: bio ?? this.bio,
    homeArea: homeArea ?? this.homeArea,
    yearsClimbing: yearsClimbing ?? this.yearsClimbing,
    levels: levels ?? this.levels,
    availability: availability ?? this.availability,
    places: places ?? this.places,
    gear: gear ?? this.gear,
  );

  Map<String, Object> toJson() => {
    'id': id,
    'name': name,
    'age': ?age,
    'bio': bio,
    'homeArea': homeArea,
    'yearsClimbing': yearsClimbing,
    'levels': {for (final e in levels.entries) e.key.name: e.value.toJson()},
    'availability': [for (final s in availability) s.toJson()],
    'places': places,
    'gear': [for (final g in gear) g.name],
  };

  static Climber fromJson(Map<String, Object?> json) => Climber(
    id: json['id']! as String,
    name: json['name']! as String,
    age: json['age'] as int?,
    bio: json['bio'] as String? ?? '',
    homeArea: json['homeArea'] as String? ?? '',
    yearsClimbing: json['yearsClimbing'] as int? ?? 0,
    levels: {
      for (final e in (json['levels'] as Map? ?? {}).entries)
        Discipline.values.byName(e.key as String): GradeRange.fromJson(
          (e.value as Map).cast(),
        ),
    },
    availability: {
      for (final s in json['availability'] as List? ?? [])
        Slot.fromJson(s as String),
    },
    places: [for (final p in json['places'] as List? ?? []) p as String],
    gear: {
      for (final g in json['gear'] as List? ?? [])
        Gear.values.byName(g as String),
    },
  );
}
