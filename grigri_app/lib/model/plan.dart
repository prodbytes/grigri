import 'climbing.dart';

/// Reads an API date (ISO 8601, UTC) as local time, for display.
DateTime _time(Object? value) => DateTime.parse(value! as String).toLocal();

/// Writes a date as the API takes it: ISO 8601, UTC.
String apiTime(DateTime t) => t.toUtc().toIso8601String();

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

  /// Given by the server; empty for a plan not created yet.
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

  /// The plan as the API takes it (`POST /api/plans`, `PUT
  /// /api/plans/{id}`): without id, organizer and members, which are the
  /// server's.
  Map<String, Object> toJson() => {
    'title': title,
    'discipline': discipline.name,
    'place': place,
    'area': area,
    'start': apiTime(start),
    'hours': hours,
    'grades': grades.toJson(),
    'spots': spots,
    'notes': notes,
  };

  static Plan fromJson(Map<String, Object?> json) => Plan(
    id: json['id']! as String,
    organizerId: json['organizerId']! as String,
    title: json['title']! as String,
    discipline: Discipline.values.byName(json['discipline']! as String),
    place: json['place']! as String,
    area: json['area'] as String? ?? '',
    start: _time(json['start']),
    hours: (json['hours']! as num).toInt(),
    grades: GradeRange.fromJson((json['grades']! as Map).cast()),
    spots: (json['spots']! as num).toInt(),
    memberIds: [for (final m in json['memberIds']! as List) m as String],
    notes: json['notes'] as String? ?? '',
  );
}

/// Someone asking to join a plan: they swiped right on it. They join when
/// every current member has accepted them (or an admin approves them); one
/// rejection turns them down.
class JoinRequest {
  const JoinRequest({
    required this.planId,
    required this.climberId,
    this.acceptedBy = const {},
    this.rejected = false,
    this.time,
  });

  final String planId;
  final String climberId;

  /// When they asked.
  final DateTime? time;

  /// The members who accepted.
  final Set<String> acceptedBy;

  /// Whether a member (or an admin) turned them down.
  final bool rejected;

  /// `<planId>/<climberId>`, as the API names it.
  String get id => '$planId/$climberId';

  JoinRequest copyWith({Set<String>? acceptedBy, bool? rejected}) =>
      JoinRequest(
        planId: planId,
        climberId: climberId,
        acceptedBy: acceptedBy ?? this.acceptedBy,
        rejected: rejected ?? this.rejected,
        time: time,
      );

  static JoinRequest fromJson(Map<String, Object?> json) => JoinRequest(
    planId: json['planId']! as String,
    climberId: json['climberId']! as String,
    acceptedBy: {
      for (final m in json['acceptedBy'] as List? ?? []) m as String,
    },
    rejected: json['rejected'] as bool? ?? false,
    time: json['time'] == null ? null : _time(json['time']),
  );
}

/// What a notification is about.
enum NoticeKind {
  /// A group accepted my request to join its plan.
  accepted,

  /// A group declined my request.
  declined,

  /// Someone asked to join a plan I'm in.
  request,
}

/// A notification for me: a group answered my request to join its plan,
/// or someone asked to join a plan I'm in. It keeps the plan's title, in
/// case the plan ends.
class Notice {
  const Notice({
    required this.id,
    required this.kind,
    required this.planId,
    required this.planTitle,
    required this.time,
    this.climberId,
    this.read = false,
  });

  final String id;
  final NoticeKind kind;

  /// Who asked to join, for a [NoticeKind.request].
  final String? climberId;
  final String planId;
  final String planTitle;
  final DateTime time;
  final bool read;

  Notice copyWith({bool? read}) => Notice(
    id: id,
    kind: kind,
    planId: planId,
    planTitle: planTitle,
    time: time,
    climberId: climberId,
    read: read ?? this.read,
  );

  /// Null for a kind this version of the app doesn't know.
  static Notice? fromJson(Map<String, Object?> json) {
    final kind = NoticeKind.values.asNameMap()[json['kind']];
    if (kind == null) return null;
    return Notice(
      id: json['id']! as String,
      kind: kind,
      planId: json['planId']! as String,
      planTitle: json['planTitle']! as String,
      time: _time(json['time']),
      climberId: json['climberId'] as String?,
      read: json['read'] as bool? ?? false,
    );
  }
}

/// A message in a plan's group chat. [authorId] is null for the chat's
/// own notes (someone joined, left, asked to join).
class Message {
  const Message({
    required this.id,
    required this.planId,
    required this.authorId,
    required this.text,
    required this.time,
    this.requestId,
  });

  final String id;
  final String planId;
  final String? authorId;
  final String text;
  final DateTime time;

  /// For a join request's note: the [JoinRequest.id], so the chat shows it
  /// as a card the group answers.
  final String? requestId;

  static Message fromJson(Map<String, Object?> json) => Message(
    id: json['id']! as String,
    planId: json['planId']! as String,
    authorId: json['authorId'] as String?,
    text: json['text']! as String,
    time: _time(json['time']),
    requestId: json['requestId'] as String?,
  );
}
