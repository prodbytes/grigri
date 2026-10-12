import 'climbing.dart';

/// A plan to climb: a specific outing (what, where, when, which grades),
/// separate from the people's profiles. Its members are its group, and
/// share its chat; the organizer is its first member.
class Plan {
  const Plan({
    required this.id,
    required this.organizerId,
    required this.title,
    required this.discipline,
    required this.place,
    required this.start,
    required this.hours,
    required this.grades,
    required this.spots,
    required this.memberIds,
    this.area = '',
    this.notes = '',
  });

  final String id;
  final String organizerId;
  final String title;
  final Discipline discipline;

  /// The crag or gym, e.g. "Siurana".
  final String place;

  /// The region, e.g. "Catalonia".
  final String area;
  final DateTime start;

  /// How long it lasts.
  final int hours;
  final GradeRange grades;

  /// How many people the group takes, the organizer included.
  final int spots;

  /// The group, organizer first, in the order they joined.
  final List<String> memberIds;
  final String notes;

  DateTime get end => start.add(Duration(hours: hours));
  int get openSpots => spots - memberIds.length;
  bool get isFull => openSpots <= 0;

  Plan copyWith({
    String? title,
    Discipline? discipline,
    String? place,
    String? area,
    DateTime? start,
    int? hours,
    GradeRange? grades,
    int? spots,
    List<String>? memberIds,
    String? notes,
  }) => Plan(
    id: id,
    organizerId: organizerId,
    title: title ?? this.title,
    discipline: discipline ?? this.discipline,
    place: place ?? this.place,
    area: area ?? this.area,
    start: start ?? this.start,
    hours: hours ?? this.hours,
    grades: grades ?? this.grades,
    spots: spots ?? this.spots,
    memberIds: memberIds ?? this.memberIds,
    notes: notes ?? this.notes,
  );

  Map<String, Object> toJson() => {
    'id': id,
    'organizerId': organizerId,
    'title': title,
    'discipline': discipline.name,
    'place': place,
    'area': area,
    'start': start.toIso8601String(),
    'hours': hours,
    'grades': grades.toJson(),
    'spots': spots,
    'memberIds': memberIds,
    'notes': notes,
  };

  static Plan fromJson(Map<String, Object?> json) => Plan(
    id: json['id']! as String,
    organizerId: json['organizerId']! as String,
    title: json['title']! as String,
    discipline: Discipline.values.byName(json['discipline']! as String),
    place: json['place']! as String,
    area: json['area'] as String? ?? '',
    start: DateTime.parse(json['start']! as String),
    hours: json['hours']! as int,
    grades: GradeRange.fromJson((json['grades']! as Map).cast()),
    spots: json['spots']! as int,
    memberIds: [for (final m in json['memberIds']! as List) m as String],
    notes: json['notes'] as String? ?? '',
  );
}

/// Someone asking to join a plan: they swiped right on it. They join when
/// every current member has accepted them; one rejection turns them down.
class JoinRequest {
  const JoinRequest({
    required this.planId,
    required this.climberId,
    this.acceptedBy = const {},
    this.rejected = false,
  });

  final String planId;
  final String climberId;

  /// The members who accepted.
  final Set<String> acceptedBy;

  /// Whether a member turned them down.
  final bool rejected;

  String get id => '$planId/$climberId';

  JoinRequest copyWith({Set<String>? acceptedBy, bool? rejected}) =>
      JoinRequest(
        planId: planId,
        climberId: climberId,
        acceptedBy: acceptedBy ?? this.acceptedBy,
        rejected: rejected ?? this.rejected,
      );

  Map<String, Object> toJson() => {
    'planId': planId,
    'climberId': climberId,
    'acceptedBy': acceptedBy.toList(),
    'rejected': rejected,
  };

  static JoinRequest fromJson(Map<String, Object?> json) => JoinRequest(
    planId: json['planId']! as String,
    climberId: json['climberId']! as String,
    acceptedBy: {
      for (final m in json['acceptedBy'] as List? ?? []) m as String,
    },
    rejected: json['rejected'] as bool? ?? false,
  );
}

/// A message in a plan's group chat. [authorId] is null for the chat's
/// own notes (someone joined, left).
class Message {
  const Message({
    required this.planId,
    required this.authorId,
    required this.text,
    required this.time,
  });

  final String planId;
  final String? authorId;
  final String text;
  final DateTime time;

  Map<String, Object?> toJson() => {
    'planId': planId,
    'authorId': authorId,
    'text': text,
    'time': time.toIso8601String(),
  };

  static Message fromJson(Map<String, Object?> json) => Message(
    planId: json['planId']! as String,
    authorId: json['authorId'] as String?,
    text: json['text']! as String,
    time: DateTime.parse(json['time']! as String),
  );
}
