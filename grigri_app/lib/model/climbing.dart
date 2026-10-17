/// Climbing vocabulary shared by profiles and plans: disciplines, grades
/// and gear. Their names in the user's language are in the translation
/// bundles (lib/ui/l10n.dart).
library;

/// How people climb.
enum Discipline {
  sport('🧗'),
  trad('⛰️'),
  bouldering('🪨'),
  gym('🏢');

  const Discipline(this.emoji);

  final String emoji;

  /// The grade scale this discipline is graded on.
  GradeScale get scale =>
      this == bouldering ? GradeScale.boulders : GradeScale.routes;
}

/// How grades are written, like Celsius and Fahrenheit: a display choice
/// that never changes the grades themselves.
enum GradeSystem {
  /// French grades for routes, Fontainebleau for boulders.
  european,

  /// YDS for routes, the V scale for boulders.
  american,
}

/// A grade scale, easiest first, written in each [GradeSystem]: the same
/// index is the same grade in both.
enum GradeScale {
  routes(
    [
      '4a', '4b', '4c', '5a', '5b', '5c', //
      '6a', '6a+', '6b', '6b+', '6c', '6c+',
      '7a', '7a+', '7b', '7b+', '7c', '7c+',
      '8a', '8a+', '8b', '8b+', '8c', '8c+', '9a',
    ],
    [
      '5.5', '5.6', '5.7', '5.8', '5.9', '5.10a', //
      '5.10b', '5.10c', '5.10d', '5.11a', '5.11b', '5.11c',
      '5.11d', '5.12a', '5.12b', '5.12c', '5.12d', '5.13a',
      '5.13b', '5.13c', '5.13d', '5.14a', '5.14b', '5.14c', '5.14d',
    ],
  ),
  boulders(
    [
      '3', '4', '5', '5+', '6A', '6B', '6C', '7A', '7A+', '7B', //
      '7C', '7C+', '8A', '8A+', '8B',
    ],
    [
      'VB', 'V0', 'V1', 'V2', 'V3', 'V4', 'V5', 'V6', 'V7', 'V8', //
      'V9', 'V10', 'V11', 'V12', 'V13',
    ],
  );

  const GradeScale(this.european, this.american);

  final List<String> european;
  final List<String> american;

  /// The grades, written in [system].
  List<String> grades(GradeSystem system) =>
      system == GradeSystem.european ? european : american;
}

/// A span of grades on one scale, as indices into [GradeScale.grades].
class GradeRange {
  const GradeRange(this.scale, this.min, this.max) : assert(min <= max);

  final GradeScale scale;
  final int min;
  final int max;

  /// "6a–7a" in European grades, "5.10b–5.11d" in American ones.
  String label(GradeSystem system) {
    final grades = scale.grades(system);
    return min == max ? grades[min] : '${grades[min]}–${grades[max]}';
  }

  /// Whether the two ranges share a grade (never across scales).
  bool overlaps(GradeRange other) =>
      scale == other.scale && min <= other.max && other.min <= max;

  Map<String, Object> toJson() => {'scale': scale.name, 'min': min, 'max': max};

  static GradeRange fromJson(Map<String, Object?> json) => GradeRange(
    switch (json['scale']! as String) {
      // The scales' names before they were written in two systems.
      'french' => GradeScale.routes,
      'vScale' => GradeScale.boulders,
      final name => GradeScale.values.byName(name),
    },
    json['min']! as int,
    json['max']! as int,
  );

  @override
  bool operator ==(Object other) =>
      other is GradeRange &&
      other.scale == scale &&
      other.min == min &&
      other.max == max;

  @override
  int get hashCode => Object.hash(scale, min, max);
}

/// Gear someone owns and can bring. The group shares the [shared] kind
/// (a rope does for two climbers); each climber needs their own of the
/// rest (a harness).
enum Gear {
  rope(shared: true),
  quickdraws(shared: true),
  rack(shared: true),
  belayDevice(shared: true),
  crashPad(shared: true),
  car(shared: true),
  harness(shared: false),
  helmet(shared: false),
  shoes(shared: false);

  const Gear({required this.shared});

  final bool shared;
}
