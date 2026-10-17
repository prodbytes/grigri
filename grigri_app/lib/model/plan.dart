import 'climbing.dart';

/// Reads an API date (ISO 8601, UTC) as local time, for display.
DateTime _time(Object? value) => DateTime.parse(value! as String).toLocal();

/// Writes a date as the API takes it: ISO 8601, UTC.
String apiTime(DateTime t) => t.toUtc().toIso8601String();

/// One day of a plan: from [start] to [end] (at most 24 hours later).
typedef DayWindow = ({DateTime start, DateTime end});

/// Who lets people into a plan.
enum PlanType {
  /// Every member says yes (the default).
  private,

  /// Nobody: a swipe right joins at once.
  open,

  /// The organizer, a guide, alone; the plan has a [Price].
  guided,
}

/// The currencies a guided plan's price may be in (the server's list).
const currencies = ['EUR', 'USD', 'GBP', 'CHF', 'BRL'];

/// What a guided plan costs each climber, paid to the guide (not through
/// Grigri).
class Price {
  const Price({required this.amount, required this.currency});

  /// In [currency]'s units, at most two decimals.
  final num amount;

  /// One of [currencies].
  final String currency;

  Map<String, Object> toJson() => {'amount': amount, 'currency': currency};

  static Price? fromJson(Object? json) {
    if (json is! Map) return null;
    final amount = json['amount'];
    final currency = json['currency'];
    if (amount is! num || currency is! String) return null;
    return Price(amount: amount, currency: currency);
  }

  @override
  bool operator ==(Object other) =>
      other is Price && other.amount == amount && other.currency == currency;

  @override
  int get hashCode => Object.hash(amount, currency);
}

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
    required this.grades,
    required this.memberIds,
    this.start,
    this.end,
    this.moreDays = const [],
    this.sectorId,
    this.lat,
    this.lon,
    this.area = '',
    this.notes = '',
    this.type = PlanType.private,
    this.price,
    this.demo = false,
  });

  /// Given by the server; empty for a plan not created yet.
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

  /// Where [place] is on the map, from the sector index; null for a place
  /// typed in by hand (or a sector without a point).
  final double? lat;
  final double? lon;

  /// The first day's start and end; both null while the day is still to
  /// be decided (an undated plan).
  final DateTime? start;
  final DateTime? end;

  /// The days after the first, soonest first; empty for a one-day (or
  /// undated) plan.
  final List<DayWindow> moreDays;
  final GradeRange grades;

  /// The group, organizer first, in the order they joined.
  final List<String> memberIds;
  final String notes;

  /// Who lets people in.
  final PlanType type;

  /// A guided plan's price per climber; null on the others.
  final Price? price;

  /// Whose yes a request needs: every member (private), the organizer
  /// (guided) or nobody (open).
  List<String> get deciders => switch (type) {
    PlanType.private => memberIds,
    PlanType.open => const [],
    PlanType.guided => [organizerId],
  };

  /// Made up, to show how Grigri works (RC's and local's seed data): the
  /// app says so wherever it shows it. Only the server sets it.
  final bool demo;

  /// What the plan is called in lists and chats: where it is.
  String get title => place;

  /// Every day of the plan, the first one first; empty while undated.
  List<DayWindow> get days => [
    if (start != null && end != null) (start: start!, end: end!),
    ...moreDays,
  ];

  /// Whether the first day has begun (joining closes then); an undated
  /// plan never has.
  bool hasStarted(DateTime now) => start != null && !start!.isAfter(now);

  Plan copyWith({
    Discipline? discipline,
    String? place,
    String? area,
    String? Function()? sectorId,
    ({double lat, double lon})? Function()? point,
    DateTime? Function()? start,
    DateTime? Function()? end,
    List<DayWindow>? moreDays,
    GradeRange? grades,
    String? organizerId,
    List<String>? memberIds,
    String? notes,
    PlanType? type,
    Price? Function()? price,
  }) => Plan(
    id: id,
    organizerId: organizerId ?? this.organizerId,
    discipline: discipline ?? this.discipline,
    place: place ?? this.place,
    area: area ?? this.area,
    sectorId: sectorId != null ? sectorId() : this.sectorId,
    lat: point != null ? point()?.lat : lat,
    lon: point != null ? point()?.lon : lon,
    start: start != null ? start() : this.start,
    end: end != null ? end() : this.end,
    moreDays: moreDays ?? this.moreDays,
    grades: grades ?? this.grades,
    memberIds: memberIds ?? this.memberIds,
    notes: notes ?? this.notes,
    type: type ?? this.type,
    price: price != null ? price() : this.price,
    demo: demo,
  );

  /// The plan as the API takes it (`POST /api/plans`, `PUT
  /// /api/plans/{id}`): without id, organizer and members, which are the
  /// server's.
  Map<String, Object> toJson() => {
    'discipline': discipline.name,
    'place': place,
    'area': area,
    'sectorId': ?sectorId,
    'lat': ?lat,
    'lon': ?lon,
    if (start != null) 'start': apiTime(start!),
    if (end != null) 'end': apiTime(end!),
    'moreDays': [
      for (final d in moreDays)
        {'start': apiTime(d.start), 'end': apiTime(d.end)},
    ],
    'grades': grades.toJson(),
    'type': type.name,
    if (type == PlanType.guided && price != null) 'price': price!.toJson(),
    'notes': notes,
  };

  static Plan fromJson(Map<String, Object?> json) => Plan(
    id: json['id']! as String,
    organizerId: json['organizerId']! as String,
    discipline: Discipline.values.byName(json['discipline']! as String),
    place: json['place']! as String,
    area: json['area'] as String? ?? '',
    sectorId: json['sectorId'] as String?,
    lat: (json['lat'] as num?)?.toDouble(),
    lon: (json['lon'] as num?)?.toDouble(),
    start: json['start'] == null ? null : _time(json['start']),
    end: json['end'] == null ? null : _time(json['end']),
    moreDays: [
      for (final d in json['moreDays'] as List? ?? const [])
        (start: _time((d as Map)['start']), end: _time(d['end'])),
    ],
    grades: GradeRange.fromJson((json['grades']! as Map).cast()),
    memberIds: [for (final m in json['memberIds']! as List) m as String],
    notes: json['notes'] as String? ?? '',
    // Absent (plans made before types) or unknown to this app: private.
    type: PlanType.values.asNameMap()[json['type']] ?? PlanType.private,
    price: Price.fromJson(json['price']),
    demo: json['demo'] == true,
  );
}

/// Someone asking to join a plan: they swiped right on it. They join when
/// every one of the plan's [Plan.deciders] has accepted them (or an admin
/// approves them); one rejection turns them down.
class JoinRequest {
  const JoinRequest({
    required this.planId,
    required this.climberId,
    this.acceptedBy = const {},
    this.rejected = false,
    this.time,
    this.nudgedAt,
  });

  /// How long I wait between nudges (the server's limit).
  static const nudgeCooldown = Duration(hours: 12);

  final String planId;
  final String climberId;

  /// When they asked.
  final DateTime? time;

  /// The members who accepted.
  final Set<String> acceptedBy;

  /// Whether a member (or an admin) turned them down.
  final bool rejected;

  /// When the requester last nudged the members who haven't answered;
  /// null until they do.
  final DateTime? nudgedAt;

  /// Whether the requester may nudge the group now: still waiting, and
  /// not nudged in the last [nudgeCooldown].
  bool canNudge(DateTime now) {
    if (rejected) return false;
    final last = nudgedAt;
    return last == null || !now.isBefore(last.add(nudgeCooldown));
  }

  /// `<planId>/<climberId>`, as the API names it.
  String get id => '$planId/$climberId';

  JoinRequest copyWith({
    Set<String>? acceptedBy,
    bool? rejected,
    DateTime? nudgedAt,
  }) => JoinRequest(
    planId: planId,
    climberId: climberId,
    acceptedBy: acceptedBy ?? this.acceptedBy,
    rejected: rejected ?? this.rejected,
    time: time,
    nudgedAt: nudgedAt ?? this.nudgedAt,
  );

  static JoinRequest fromJson(Map<String, Object?> json) => JoinRequest(
    planId: json['planId']! as String,
    climberId: json['climberId']! as String,
    acceptedBy: {
      for (final m in json['acceptedBy'] as List? ?? []) m as String,
    },
    rejected: json['rejected'] as bool? ?? false,
    time: json['time'] == null ? null : _time(json['time']),
    nudgedAt: json['nudgedAt'] == null ? null : _time(json['nudgedAt']),
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

  /// Someone who asked to join a plan I'm in is still waiting for my
  /// answer (they nudged the members who haven't answered).
  nudge,
}

/// A notification for me: a group answered my request to join its plan,
/// or someone asked to join a plan I'm in (or nudged me to answer). It
/// keeps the plan's title (its place), in case the plan ends.
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

  /// Who asked to join, for a [NoticeKind.request] or [NoticeKind.nudge].
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
    this.attachment,
  });

  final String id;
  final String planId;
  final String? authorId;

  /// May be empty when the message carries an [attachment].
  final String text;
  final DateTime time;

  /// A member's photo or video.
  final Attachment? attachment;

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
    attachment: Attachment.fromJson(json['attachment']),
  );
}

/// What a chat message can carry: one photo or one video.
enum MediaKind { image, video }

/// A chat message's photo or video, served at `<site>/photos/<key>`.
class Attachment {
  const Attachment({required this.key, required this.kind});

  final String key;
  final MediaKind kind;

  /// Null for none, or for a kind this app doesn't know.
  static Attachment? fromJson(Object? json) {
    if (json is! Map) return null;
    final key = json['key'];
    final kind = switch (json['kind']) {
      'image' => MediaKind.image,
      'video' => MediaKind.video,
      _ => null,
    };
    if (key is! String || kind == null) return null;
    return Attachment(key: key, kind: kind);
  }
}
