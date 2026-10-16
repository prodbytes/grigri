import 'dart:typed_data';

import '../model/climber.dart';
import '../model/match_score.dart';
import '../model/plan.dart';
import 'realtime.dart';

/// The Grigri backend, one method per route of its contract
/// (specs/api.md). [HttpGrigriApi](http_api.dart) calls the real one;
/// tests use an in-memory fake.
abstract interface class GrigriApi {
  /// Where a photo's key is served: `<site>/photos/<key>`.
  Uri photoUrl(String key);

  /// `GET /api/me`: my profile (null until I save one) and whether I'm an
  /// admin.
  Future<Me> me();

  /// `GET /api/realtime`: where live updates come from; null when they're
  /// off (specs/live-updates.md).
  Future<RealtimeInfo?> realtime();

  /// `PUT /api/me`: creates or updates my profile.
  Future<Climber> saveMe(Climber profile);

  /// `GET /api/discover`: plans to swipe on, best first (how well they
  /// match my profile plus how close they are), with their distances, and
  /// for admins the best ones' match scores.
  Future<PlanList> discover();

  /// `POST /api/plans`: a new plan, organized by me.
  Future<Plan> createPlan(Plan plan);

  /// `PUT /api/plans/{id}`: the organizer's changes.
  Future<Plan> updatePlan(Plan plan);

  /// `GET /api/plans`: the plans I'm in, and the ones I asked to join.
  Future<MyPlans> myPlans();

  /// `GET /api/plans/{id}`: a plan, with its open requests when I'm in it.
  Future<PlanDetail> plan(String id);

  /// `POST /api/plans/{id}/leave`.
  Future<void> leave(String planId);

  /// `POST /api/plans/{id}/join`: swipe right.
  Future<JoinRequest> join(String planId);

  /// `POST /api/plans/{id}/nudge`: reminds the members who haven't
  /// answered my open request on the plan (once every 12 hours; 429
  /// sooner). My request, with its new [JoinRequest.nudgedAt], and how
  /// many members were nudged.
  Future<({JoinRequest request, int nudged})> nudge(String planId);

  /// `POST /api/plans/{id}/pass`: swipe left.
  Future<void> pass(String planId);

  /// `DELETE /api/passes`: the plans I passed on come back to the deck
  /// (not ones I asked to join).
  Future<void> clearPasses();

  /// `GET /api/requests`: requests on my plans waiting for my answer.
  Future<RequestList> requests();

  /// `POST /api/requests/{planId}/{climberId}/accept`.
  Future<ApiMatch?> accept(String planId, String climberId);

  /// `POST /api/requests/{planId}/{climberId}/reject`.
  Future<void> reject(String planId, String climberId);

  /// `POST /api/requests/{planId}/{climberId}/dismiss`: the requester
  /// clears a declined request.
  Future<void> dismiss(String planId, String climberId);

  /// `GET /api/notices`: mine, newest first.
  Future<NoticeList> notices();

  /// `POST /api/notices/read`.
  Future<void> readNotices();

  /// `GET /api/plans/{id}/messages[?after=]`: oldest first.
  Future<MessageList> messages(String planId, {DateTime? after});

  /// `POST /api/plans/{id}/messages`: text, an [attachment] (a key from
  /// [newChatMedia]), or both.
  Future<Message> send(String planId, String text, {String? attachment});

  /// `POST /api/photos`: where to upload a new photo.
  Future<PhotoUpload> newPhoto(PhotoKind kind, String contentType);

  /// `POST /api/plans/{id}/media`: where to upload a photo or video for
  /// the plan's chat.
  Future<PhotoUpload> newChatMedia(String planId, String contentType);

  /// Uploads a photo or video to the presigned POST [newPhoto] or
  /// [newChatMedia] gave; [onProgress] hears the share sent so far (0 to 1).
  Future<void> uploadPhoto(
    PhotoUpload upload,
    Uint8List bytes, {
    void Function(double sent)? onProgress,
  });

  /// `GET /api/admin/climbers`: everyone, by name (admins only).
  Future<List<AdminClimber>> adminClimbers();

  /// `POST /api/admin/climbers/{id}/block` or `/unblock` (admins only).
  Future<void> setBlocked(String climberId, bool blocked);
}

/// A failure the app itself describes (no server message to show): the
/// store words it in the user's language.
enum ClientError {
  /// The server took too long to answer.
  timeout,

  /// The server couldn't be reached.
  unreachable,

  /// The server failed without a message of its own.
  failed,
  photoTimeout,
  photoUnreachable,

  /// A photo upload failed.
  photoFailed,

  /// A photo the app can't upload (not JPEG, PNG or WebP).
  photoType,

  /// Chat media the app can't send (not a JPEG, PNG or WebP photo, or an
  /// MP4 or MOV video).
  mediaType,

  /// A chat video over [maxVideoBytes].
  videoTooBig,
}

/// The largest photo the API takes (the pickers downsize well under it).
const maxPhotoBytes = 2 * 1024 * 1024;

/// The largest chat video the API takes.
const maxVideoBytes = 50 * 1024 * 1024;

/// The longest video the camera records for a chat (where the device
/// lets the app say).
const maxVideoDuration = Duration(seconds: 30);

/// An error answer from the API: its status and the server's message.
class ApiException implements Exception {
  const ApiException(this.status, this.message, {this.client});

  /// The HTTP status; 0 when the server couldn't be reached.
  final int status;

  /// The server's message (shown as is), or, for a [client] error, an
  /// English one for logs.
  final String message;

  /// Set when the app, not the server, describes the failure.
  final ClientError? client;

  /// 409 `{"error": "no profile"}`: signed in, but no profile saved yet.
  bool get noProfile => status == 409 && message == 'no profile';

  /// 403 `{"error": "blocked"}`: an admin blocked me.
  bool get blocked => status == 403 && message == 'blocked';

  @override
  String toString() => 'ApiException($status): $message';
}

typedef Climbers = Map<String, Climber>;

class Me {
  const Me({required this.climber, required this.admin, this.roles});

  final Climber? climber;
  final bool admin;

  /// My roles in Grigri, from rbacr (the API asks it); null when rbacr
  /// couldn't say.
  final List<String>? roles;
}

class PlanList {
  const PlanList(
    this.plans,
    this.climbers, {
    this.distanceKm = const {},
    this.scores = const {},
  });

  final List<Plan> plans;
  final Climbers climbers;

  /// For the deck: how far each plan is from my nearest location or area,
  /// in whole km, for the plans whose distance is known.
  final Map<String, int> distanceKm;

  /// Admins only: how likely each of the deck's best plans ends in a
  /// match for me; empty for everyone else.
  final Map<String, MatchScore> scores;
}

/// Someone in the admin's list, and whether they're blocked.
class AdminClimber {
  const AdminClimber(this.climber, {required this.blocked});

  final Climber climber;
  final bool blocked;
}

class MyPlans {
  const MyPlans({
    required this.plans,
    required this.asked,
    required this.climbers,
  });

  /// The plans I'm in, soonest first.
  final List<Plan> plans;

  /// My requests still waiting, or declined and not dismissed, with their
  /// plans.
  final List<({JoinRequest request, Plan plan})> asked;
  final Climbers climbers;
}

class PlanDetail {
  const PlanDetail(this.plan, this.requests, this.climbers);

  final Plan plan;

  /// Its open requests; empty when I'm not in it.
  final List<JoinRequest> requests;
  final Climbers climbers;
}

class RequestList {
  const RequestList(this.requests, this.plans, this.climbers);

  final List<JoinRequest> requests;
  final Map<String, Plan> plans;
  final Climbers climbers;
}

class NoticeList {
  const NoticeList(this.notices, this.climbers);

  final List<Notice> notices;
  final Climbers climbers;
}

class MessageList {
  const MessageList(this.messages, this.climbers);

  final List<Message> messages;
  final Climbers climbers;
}

/// Someone joined a plan: the plan as it is now, and who.
class ApiMatch {
  const ApiMatch(this.plan, this.newcomerId);

  final Plan plan;
  final String newcomerId;
}

enum PhotoKind { profile, gear }

/// A presigned S3 POST for one photo: the form [fields] go first, then the
/// file; the photo is then known by its [key].
class PhotoUpload {
  const PhotoUpload({
    required this.key,
    required this.url,
    required this.fields,
    required this.contentType,
  });

  final String key;
  final Uri url;
  final Map<String, String> fields;
  final String contentType;
}

/// The image type of a photo's bytes, as `POST /api/photos` takes it, or
/// null when it isn't a JPEG, PNG or WebP.
String? photoContentType(Uint8List bytes) {
  bool starts(List<int> magic, [int at = 0]) {
    if (bytes.length < at + magic.length) return false;
    for (var i = 0; i < magic.length; i++) {
      if (bytes[at + i] != magic[i]) return false;
    }
    return true;
  }

  if (starts([0xFF, 0xD8, 0xFF])) return 'image/jpeg';
  if (starts([0x89, 0x50, 0x4E, 0x47])) return 'image/png';
  if (starts([0x52, 0x49, 0x46, 0x46]) && starts([0x57, 0x45, 0x42, 0x50], 8)) {
    return 'image/webp';
  }
  return null;
}

/// The type of a chat photo's or video's bytes, as
/// `POST /api/plans/{id}/media` takes it: a photo as [photoContentType],
/// or an MP4 or QuickTime (MOV) video. Null for anything else (3GP
/// videos included: browsers can't play them).
String? mediaContentType(Uint8List bytes) {
  final photo = photoContentType(bytes);
  if (photo != null) return photo;
  if (bytes.length < 12) return null;
  // ISO base media files: a size, then 'ftyp' and the major brand.
  final ftyp = String.fromCharCodes(bytes.sublist(4, 8));
  if (ftyp != 'ftyp') return null;
  final brand = String.fromCharCodes(bytes.sublist(8, 12));
  if (brand == 'qt  ') return 'video/quicktime';
  if (brand.startsWith('3g')) return null;
  return 'video/mp4';
}

// --- JSON ------------------------------------------------------------------

/// Reads the API's JSON shapes (specs/api.md).
abstract final class ApiJson {
  static Map<String, Object?> _map(Object? v) => (v! as Map).cast();

  static List<Map<String, Object?>> _list(Object? v) => [
    for (final e in (v as List?) ?? const []) _map(e),
  ];

  static Climbers climbers(Map<String, Object?> json) => {
    for (final e in ((json['climbers'] as Map?) ?? const {}).entries)
      e.key as String: Climber.fromJson(_map(e.value)),
  };

  static Map<String, Plan> _plansById(Object? v) => {
    for (final e in ((v as Map?) ?? const {}).entries)
      e.key as String: Plan.fromJson(_map(e.value)),
  };

  static Me me(Map<String, Object?> json) => Me(
    climber: json['climber'] == null
        ? null
        : Climber.fromJson(_map(json['climber'])),
    admin: json['admin'] == true,
    roles: json['roles'] is List
        ? [for (final r in json['roles']! as List) r as String]
        : null,
  );

  static Climber climber(Map<String, Object?> json) =>
      Climber.fromJson(_map(json['climber']));

  static Plan plan(Map<String, Object?> json) =>
      Plan.fromJson(_map(json['plan']));

  static PlanList planList(Map<String, Object?> json) => PlanList(
    _list(json['plans']).map(Plan.fromJson).toList(),
    climbers(json),
    distanceKm: {
      for (final e in (json['distanceKm'] as Map? ?? {}).entries)
        e.key as String: (e.value as num).round(),
    },
    scores: {
      for (final e in (json['scores'] as Map? ?? {}).entries)
        e.key as String: ?MatchScore.fromJson(_map(e.value)),
    },
  );

  static List<AdminClimber> adminClimbers(Map<String, Object?> json) => [
    for (final c in _list(json['climbers']))
      AdminClimber(Climber.fromJson(c), blocked: c['blocked'] == true),
  ];

  static MyPlans myPlans(Map<String, Object?> json) => MyPlans(
    plans: _list(json['plans']).map(Plan.fromJson).toList(),
    asked: [
      for (final a in _list(json['asked']))
        (
          request: JoinRequest.fromJson(_map(a['request'])),
          plan: Plan.fromJson(_map(a['plan'])),
        ),
    ],
    climbers: climbers(json),
  );

  static PlanDetail planDetail(Map<String, Object?> json) => PlanDetail(
    plan(json),
    _list(json['requests']).map(JoinRequest.fromJson).toList(),
    climbers(json),
  );

  static JoinRequest request(Map<String, Object?> json) =>
      JoinRequest.fromJson(_map(json['request']));

  static ({JoinRequest request, int nudged}) nudge(Map<String, Object?> json) =>
      (request: request(json), nudged: (json['nudged'] as num?)?.toInt() ?? 0);

  static RequestList requestList(Map<String, Object?> json) => RequestList(
    _list(json['requests']).map(JoinRequest.fromJson).toList(),
    _plansById(json['plans']),
    climbers(json),
  );

  static ApiMatch? match(Map<String, Object?> json) {
    final m = json['match'];
    if (m == null) return null;
    final map = _map(m);
    return ApiMatch(
      Plan.fromJson(_map(map['plan'])),
      map['newcomerId']! as String,
    );
  }

  static NoticeList noticeList(Map<String, Object?> json) => NoticeList([
    for (final n in _list(json['notices'])) ?Notice.fromJson(n),
  ], climbers(json));

  static MessageList messageList(Map<String, Object?> json) => MessageList(
    _list(json['messages']).map(Message.fromJson).toList(),
    climbers(json),
  );

  static Message message(Map<String, Object?> json) =>
      Message.fromJson(_map(json['message']));

  static PhotoUpload photoUpload(
    Map<String, Object?> json,
    String contentType,
  ) => PhotoUpload(
    key: json['key']! as String,
    url: Uri.parse(json['url']! as String),
    fields: {
      for (final e in ((json['fields'] as Map?) ?? const {}).entries)
        e.key as String: '${e.value}',
    },
    contentType: contentType,
  );
}
