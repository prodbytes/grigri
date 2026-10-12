import 'climbing.dart';

/// A plan to climb: a specific outing (what, where, when, which grades),
/// separate from the people's profiles. Its members are its group, and
/// share its chat; the organizer is its first member. The group has no
/// size limit: it is as big as the people who match.
class Plan {
  const Plan({
    required this.id,
    required this.organizerId,
    required this.discipline,
    required this.place,
    required this.start,
    required this.end,
    required this.grades,
    required this.memberIds,
    this.sectorId,
    this.area = '',
    this.notes = '',
  });

  final String id;
  final String organizerId;
  final Discipline discipline;

  /// The sector, crag or gym, e.g. "El Pati".
  final String place;

  /// Where [place] is, from the sector index: the crag and country, e.g.
  /// "Siurana, Spain". Empty for a place typed in by hand.
  final String area;

  /// The [Sector.id] of [place] in the sector index; null for a place
  /// typed in by hand.
  final String? sectorId;
  final DateTime start;
  final DateTime end;
  final GradeRange grades;

  /// The group, organizer first, in the order they joined.
  final List<String> memberIds;
  final String notes;

  /// What the plan is called in lists and chats: where it is.
  String get title => place;

  Plan copyWith({
    Discipline? discipline,
    String? place,
    String? area,
    String? Function()? sectorId,
    DateTime? start,
    DateTime? end,
    GradeRange? grades,
    String? organizerId,
    List<String>? memberIds,
    String? notes,
  }) => Plan(
    id: id,
    organizerId: organizerId ?? this.organizerId,
    discipline: discipline ?? this.discipline,
    place: place ?? this.place,
    area: area ?? this.area,
    sectorId: sectorId != null ? sectorId() : this.sectorId,
    start: start ?? this.start,
    end: end ?? this.end,
    grades: grades ?? this.grades,
    memberIds: memberIds ?? this.memberIds,
    notes: notes ?? this.notes,
  );

  Map<String, Object> toJson() => {
    'id': id,
    'organizerId': organizerId,
    'discipline': discipline.name,
    'place': place,
    'area': area,
    'sectorId': ?sectorId,
    'start': start.toIso8601String(),
    'end': end.toIso8601String(),
    'grades': grades.toJson(),
    'memberIds': memberIds,
    'notes': notes,
  };

  static Plan fromJson(Map<String, Object?> json) {
    final start = DateTime.parse(json['start']! as String);
    return Plan(
      id: json['id']! as String,
      organizerId: json['organizerId']! as String,
      discipline: Discipline.values.byName(json['discipline']! as String),
      place: json['place']! as String,
      area: json['area'] as String? ?? '',
      sectorId: json['sectorId'] as String?,
      start: start,
      end: switch (json['end']) {
        final String end => DateTime.parse(end),
        // Plans saved before they had an end lasted some hours.
        _ => start.add(Duration(hours: json['hours'] as int? ?? 1)),
      },
      grades: GradeRange.fromJson((json['grades']! as Map).cast()),
      memberIds: [for (final m in json['memberIds']! as List) m as String],
      notes: json['notes'] as String? ?? '',
    );
  }
}

/// Someone asking to join a plan: they swiped right on it. They join when
/// every current member has accepted them; one rejection turns them down.
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

  /// When they asked; null when it was long enough ago not to matter.
  final DateTime? time;

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
        time: time,
      );

  Map<String, Object> toJson() => {
    'planId': planId,
    'climberId': climberId,
    'acceptedBy': acceptedBy.toList(),
    'rejected': rejected,
    if (time != null) 'time': time!.toIso8601String(),
  };

  static JoinRequest fromJson(Map<String, Object?> json) => JoinRequest(
    planId: json['planId']! as String,
    climberId: json['climberId']! as String,
    acceptedBy: {
      for (final m in json['acceptedBy'] as List? ?? []) m as String,
    },
    rejected: json['rejected'] as bool? ?? false,
    time: switch (json['time']) {
      final String t => DateTime.parse(t),
      _ => null,
    },
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
    required this.kind,
    required this.planId,
    required this.planTitle,
    required this.time,
    this.climberId,
    this.read = false,
  });

  final NoticeKind kind;

  /// Who asked to join, for a [NoticeKind.request].
  final String? climberId;
  final String planId;
  final String planTitle;
  final DateTime time;
  final bool read;

  /// A group answers a request once, and nobody can ask twice.
  String get id => kind == NoticeKind.request
      ? '$planId/request/$climberId'
      : '$planId/${kind.name}';

  Notice copyWith({bool? read}) => Notice(
    kind: kind,
    planId: planId,
    planTitle: planTitle,
    time: time,
    climberId: climberId,
    read: read ?? this.read,
  );

  Map<String, Object> toJson() => {
    'kind': kind.name,
    'planId': planId,
    'planTitle': planTitle,
    'time': time.toIso8601String(),
    'climberId': ?climberId,
    'read': read,
  };

  static Notice fromJson(Map<String, Object?> json) => Notice(
    kind: NoticeKind.values.byName(json['kind']! as String),
    planId: json['planId']! as String,
    planTitle: json['planTitle']! as String,
    time: DateTime.parse(json['time']! as String),
    climberId: json['climberId'] as String?,
    read: json['read'] as bool? ?? false,
  );
}

/// A message in a plan's group chat. [authorId] is null for the chat's
/// own notes (someone joined, left, asked to join).
class Message {
  const Message({
    required this.planId,
    required this.authorId,
    required this.text,
    required this.time,
    this.requestId,
  });

  final String planId;
  final String? authorId;
  final String text;
  final DateTime time;

  /// For a join request's note: the [JoinRequest.id], so the chat shows it
  /// as a card the group answers.
  final String? requestId;

  Map<String, Object?> toJson() => {
    'planId': planId,
    'authorId': authorId,
    'text': text,
    'time': time.toIso8601String(),
    'requestId': ?requestId,
  };

  static Message fromJson(Map<String, Object?> json) => Message(
    planId: json['planId']! as String,
    authorId: json['authorId'] as String?,
    text: json['text']! as String,
    time: DateTime.parse(json['time']! as String),
    requestId: json['requestId'] as String?,
  );
}
