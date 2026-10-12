/// Climbing vocabulary shared by profiles and plans: disciplines, grades,
/// and when people climb.
library;

/// How people climb.
enum Discipline {
  sport('Sport', '🧗'),
  trad('Trad', '⛰️'),
  bouldering('Bouldering', '🪨'),
  gym('Gym', '🏢');

  const Discipline(this.label, this.emoji);

  final String label;
  final String emoji;

  /// The grade scale this discipline is graded on.
  GradeScale get scale =>
      this == bouldering ? GradeScale.vScale : GradeScale.french;
}

/// A grade scale, easiest first.
enum GradeScale {
  french([
    '4a', '4b', '4c', '5a', '5b', '5c', //
    '6a', '6a+', '6b', '6b+', '6c', '6c+',
    '7a', '7a+', '7b', '7b+', '7c', '7c+',
    '8a', '8a+', '8b', '8b+', '8c', '8c+', '9a',
  ]),
  vScale([
    'VB', 'V0', 'V1', 'V2', 'V3', 'V4', 'V5', 'V6', 'V7', 'V8', //
    'V9', 'V10', 'V11', 'V12', 'V13',
  ]);

  const GradeScale(this.grades);

  final List<String> grades;
}

/// A span of grades on one scale, as indices into [GradeScale.grades].
class GradeRange {
  const GradeRange(this.scale, this.min, this.max) : assert(min <= max);

  final GradeScale scale;
  final int min;
  final int max;

  String get label => min == max
      ? scale.grades[min]
      : '${scale.grades[min]}–${scale.grades[max]}';

  /// Whether the two ranges share a grade (never across scales).
  bool overlaps(GradeRange other) =>
      scale == other.scale && min <= other.max && other.min <= max;

  Map<String, Object> toJson() => {'scale': scale.name, 'min': min, 'max': max};

  static GradeRange fromJson(Map<String, Object?> json) => GradeRange(
    GradeScale.values.byName(json['scale']! as String),
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

/// A part of the day people like to climb in.
enum DayPart {
  morning('Morning'),
  afternoon('Afternoon'),
  evening('Evening');

  const DayPart(this.label);

  final String label;

  /// The part of the day an hour falls in.
  static DayPart of(int hour) => hour < 12
      ? morning
      : hour < 17
      ? afternoon
      : evening;
}

/// Weekday names, Monday first, as DateTime.weekday numbers them (1–7).
const weekdayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// A weekday (1 = Monday … 7 = Sunday) and part of the day.
class Slot {
  const Slot(this.weekday, this.part) : assert(weekday >= 1 && weekday <= 7);

  final int weekday;
  final DayPart part;

  /// The slot a date and time falls in.
  factory Slot.at(DateTime time) => Slot(time.weekday, DayPart.of(time.hour));

  String get label =>
      '${weekdayLabels[weekday - 1]} ${part.label.toLowerCase()}';

  String toJson() => '$weekday:${part.name}';

  static Slot fromJson(String json) {
    final [day, part] = json.split(':');
    return Slot(int.parse(day), DayPart.values.byName(part));
  }

  @override
  bool operator ==(Object other) =>
      other is Slot && other.weekday == weekday && other.part == part;

  @override
  int get hashCode => Object.hash(weekday, part);
}

/// Gear someone can bring.
enum Gear {
  rope('Rope'),
  quickdraws('Quickdraws'),
  rack('Trad rack'),
  crashPad('Crash pad'),
  car('Car');

  const Gear(this.label);

  final String label;
}
