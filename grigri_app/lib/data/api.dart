import 'dart:typed_data';

import '../model/ad.dart';
import '../model/climber.dart';
import '../model/climbing.dart';
import '../model/match_score.dart';
import '../model/pics.dart';
import '../model/plan.dart';
import '../model/walls.dart';
import '../model/premium.dart';
import '../model/report.dart';
import '../model/team.dart';
import 'realtime.dart';

/// The Grigri backend, one method per route of its contract
/// (specs/api.md). [HttpGrigriApi](http_api.dart) calls the real one;
/// tests use an in-memory fake.
abstract interface class GrigriApi {
  /// Where a photo's key is served: `<site>/photos/<key>`.
  Uri photoUrl(String key);

  /// Where a GriGri Pics photo is served: `<site>/pics/<key>`.
  Uri picUrl(String key);

  /// GriGri Pics' catalog, `<site>/pics/catalog.json`: a static file that
  /// needs no sign-in, so the sign-in screen can show crag photos. Every
  /// crag's photos, in the catalog's order, each with its crag's name.
  Future<List<GrigriPic>> picsCatalog();

  /// A photo's bytes, from where [photoUrl] says (the route finder reads
  /// walls' reference photos itself).
  Future<Uint8List> photoBytes(String key);

  /// `GET /api/me`: my profile (null until I save one) and whether I'm an
  /// admin.
  Future<Me> me();

  /// `GET /api/realtime`: where live updates come from; null when they're
  /// off (specs/live-updates.md).
  Future<RealtimeInfo?> realtime();

  /// `PUT /api/me`: creates or updates my profile.
  Future<Climber> saveMe(Climber profile);

  /// `DELETE /api/me` with `{"confirm": true}`: deletes my account for
  /// good (specs/sign-in.md#deleting-my-account). Every session of mine
  /// ends with it.
  Future<void> deleteAccount();

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

  /// `GET /api/notices`: mine, newest first. With the [stamp] my last
  /// answer had (`0`: none yet), [NoticeList.unchanged] when they still
  /// are as they were.
  Future<NoticeList> notices({String? stamp});

  /// `GET /api/updates`: [myPlans], [requests] and [notices] (with the
  /// [noticesStamp] my last answer had, `0` for none) in one request, the
  /// app's regular refresh.
  Future<Updates> updates({String noticesStamp = '0'});

  /// `POST /api/notices/read`.
  Future<void> readNotices();

  /// `GET /api/team/messages[?after=]`: my Grigri team chat, oldest first
  /// (specs/team-chat.md). Its welcome is the app's own.
  Future<List<TeamMessage>> teamMessages({DateTime? after});

  /// `POST /api/team/messages`: I write to the Grigri team (text only).
  Future<TeamMessage> sendToTeam(String text);

  /// `POST /api/team/read`: my team chat's badge goes.
  Future<void> readTeam();

  /// `GET /api/admin/team` (admins): the team chats with a message, the
  /// latest first.
  Future<TeamChatList> adminTeamChats();

  /// `GET /api/admin/team/{id}/messages[?after=]` (admins): a climber's
  /// team chat, with which admin wrote each answer.
  Future<TeamMessageList> adminTeamMessages(
    String climberId, {
    DateTime? after,
  });

  /// `POST /api/admin/team/{id}/messages` (admins): an answer as the
  /// Grigri team.
  Future<TeamMessage> answerAsTeam(String climberId, String text);

  /// `GET /api/plans/{id}/messages[?after=]`: oldest first.
  Future<MessageList> messages(String planId, {DateTime? after});

  /// `GET /api/chats/messages?chats=`: several chats' messages in one
  /// request (at most [maxChatsPerPoll]), each as [messages] answers it:
  /// planId → after (null: all of it). Chats I'm not in are left out.
  Future<ChatsMessages> chatsMessages(Map<String, DateTime?> chats);

  /// `POST /api/plans/{id}/messages`: text, an [attachment] (a key from
  /// [newChatMedia]), or both.
  Future<Message> send(String planId, String text, {String? attachment});

  /// `POST /api/photos`: where to upload a new photo.
  Future<PhotoUpload> newPhoto(PhotoKind kind, String contentType);

  /// `POST /api/plans/{id}/media`: where to upload a photo or video for
  /// the plan's chat.
  Future<PhotoUpload> newChatMedia(String planId, String contentType);

  /// `GET /api/plans/{id}/pics`: the plan's GriGri Pics and, for members,
  /// its "Your Pics".
  Future<PlanPicsList> planPics(String planId);

  /// `POST /api/plans/{id}/pics/upload`: where to upload a photo for the
  /// plan.
  Future<PhotoUpload> newPlanPic(String planId, String contentType);

  /// `POST /api/plans/{id}/pics`: adds an uploaded photo to the plan.
  Future<PlanPic> addPlanPic(String planId, String key);

  /// `DELETE /api/plans/{id}/pics/{picId}`.
  Future<void> deletePlanPic(String planId, String picId);

  /// Uploads a photo or video to the presigned POST [newPhoto],
  /// [newChatMedia] or [newPlanPic] gave; [onProgress] hears the share sent so far (0 to 1).
  Future<void> uploadPhoto(
    PhotoUpload upload,
    Uint8List bytes, {
    void Function(double sent)? onProgress,
  });

  /// `GET /api/walls?lat=&lon=`: the route finder's walls near a point
  /// (premium).
  Future<List<Wall>> walls(double lat, double lon);

  /// `POST /api/walls/photo`: where to upload a wall's reference photo.
  Future<PhotoUpload> newWallPhoto(String contentType);

  /// `POST /api/walls`: a new wall, from its first photo.
  Future<Wall> createWall({
    required String name,
    required double lat,
    required double lon,
    String? cragId,
    required String key,
    required int width,
    required int height,
  });

  /// `POST /api/walls/{id}/routes`: a route drawn on a wall.
  Future<Wall> addRoute(
    String wallId, {
    required String name,
    required GradeScale scale,
    required int grade,
    required List<(double, double)> bolts,
  });

  /// `DELETE /api/walls/{id}/routes/{routeId}`.
  Future<Wall> deleteRoute(String wallId, String routeId);

  /// `POST /api/walls/{id}/views`: the app learns a wall from another view.
  Future<Wall> addWallView(
    String wallId, {
    required String key,
    required int width,
    required int height,
    required List<double> h,
  });

  /// `GET /api/premium`: my Premium, and its prices (none when it can't be
  /// bought here). [fresh]: rbacr is asked afresh (`?fresh=1`), for when
  /// it may have just changed (back from paying, "check again").
  Future<PremiumOffer> premium({bool fresh = false});

  /// `POST /api/premium/checkout`: Stripe Checkout's page for [plan], to
  /// open in the browser.
  Future<Uri> premiumCheckout(PremiumPlan plan);

  /// `POST /api/premium/portal`: Stripe's billing portal (cancel, card,
  /// invoices), to open in the browser.
  Future<Uri> premiumPortal();

  /// `POST /api/premium/apple`: a StoreKit 2 transaction (its signed JWS)
  /// the iOS app bought or restored; my Premium after it.
  Future<PremiumOffer> premiumApple(String signedTransaction);

  /// `GET /api/ads`: my ads, newest first, and whether I'm Premium (ads
  /// need it).
  Future<MyAds> myAds();

  /// `POST /api/ads/media`: where to upload an ad's photo or video
  /// (Premium only).
  Future<PhotoUpload> newAdMedia(String contentType);

  /// `POST /api/ads`: a new ad, waiting for an admin (Premium only).
  Future<Ad> createAd({
    required String text,
    required String link,
    String? mediaKey,
    List<AdRegion> regions = const [],
  });

  /// `GET /api/places`: places named like [query] (a country, a region,
  /// a town…), for an ad's regions, named in [language] where they can
  /// be (Premium only).
  Future<List<AdRegion>> searchPlaces(String query, String language);

  /// `DELETE /api/ads/{id}`: takes my ad down for good.
  Future<void> deleteAd(String adId);

  /// `POST /api/ads/{id}/skip`: I skipped an ad on the deck; it never
  /// shows to me again.
  Future<void> skipAd(String adId);

  /// `GET /api/admin/ads?status=`: ads in a status, newest first, with
  /// their owners and how often the deck shows ads (admins only).
  Future<AdminAds> adminAds(AdStatus status);

  /// `POST /api/admin/ads/{id}/approve` or `/reject` (admins only).
  Future<Ad> reviewAd(String adId, {required bool approve});

  /// `PUT /api/admin/ads/settings`: one ad after every [every] plans; 0:
  /// none (admins only).
  Future<void> setAdEvery(int every);

  /// `GET /api/admin/climbers`: everyone, by name (admins only).
  Future<List<AdminClimber>> adminClimbers();

  /// `POST /api/admin/climbers/{id}/block` or `/unblock` (admins only).
  Future<void> setBlocked(String climberId, bool blocked);

  /// `POST /api/reports`: I report something objectionable (specs/moderation.md).
  Future<void> sendReport({
    required ReportKind kind,
    required String targetId,
    String? planId,
    required ReportReason reason,
    String text = '',
  });

  /// `GET /api/admin/reports`: the open reports, oldest first (admins
  /// only).
  Future<AdminReports> adminReports();

  /// `POST /api/admin/reports/{id}/dismiss`, `/remove` or `/block` (admins
  /// only).
  Future<void> resolveReport(String reportId, ReportAction action);

  /// `GET /api/blocks`: the people I blocked.
  Future<BlockList> blocks();

  /// `POST /api/blocks/{id}` (block) or `DELETE /api/blocks/{id}`
  /// (unblock): my own block, not an admin's.
  Future<void> setPersonBlocked(String climberId, bool blocked);
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

  /// 400 `{"error": "objectionable: …"}`: the filter refused the text
  /// (specs/moderation.md#the-filter); the app says so in its own words.
  bool get objectionable =>
      status == 400 && message.startsWith('objectionable');

  @override
  String toString() => 'ApiException($status): $message';
}

typedef Climbers = Map<String, Climber>;

class Me {
  const Me({
    required this.climber,
    required this.admin,
    this.roles,
    this.premium = const Premium.none(),
  });

  final Climber? climber;
  final bool admin;

  /// My Premium subscription.
  final Premium premium;

  /// My roles in Grigri, from rbacr (the API asks it); null when rbacr
  /// couldn't say.
  final List<String>? roles;
}

class PlanList {
  const PlanList(
    this.plans,
    this.climbers, {
    this.distanceKm = const {},
    this.covers = const {},
    this.scores = const {},
    this.ads = const [],
    this.adEvery = 0,
  });

  final List<Plan> plans;
  final Climbers climbers;

  /// Approved ads to show between the plans (specs/ads.md), and how
  /// often: one after every [adEvery] plans (0: none).
  final List<Ad> ads;
  final int adEvery;

  /// For the deck: each plan's cover photo, for the plans that have one.
  final Map<String, DeckCover> covers;

  /// For the deck: how far each plan is from my nearest location or area,
  /// in whole km, for the plans whose distance is known.
  final Map<String, int> distanceKm;

  /// Admins only: how likely each of the deck's best plans ends in a
  /// match for me; empty for everyone else.
  final Map<String, MatchScore> scores;
}

/// `GET /api/ads`.
class MyAds {
  const MyAds(this.ads, {required this.premium});

  final List<Ad> ads;
  final bool premium;
}

/// `GET /api/admin/ads`.
class AdminAds {
  const AdminAds(this.ads, this.climbers, {required this.every});

  final List<Ad> ads;
  final Climbers climbers;

  /// One ad after every [every] plans on the deck; 0: none.
  final int every;
}

/// `GET /api/admin/reports`.
class AdminReports {
  const AdminReports(this.reports, this.climbers);

  final List<Report> reports;

  /// Who's reported, and who reported.
  final Climbers climbers;
}

/// `GET /api/blocks`.
class BlockList {
  const BlockList(this.blocked, this.climbers);

  /// Who I blocked.
  final List<String> blocked;
  final Climbers climbers;
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
  const NoticeList(
    this.notices,
    this.climbers, {
    this.stamp,
    this.unchanged = false,
  });

  /// Mine, newest first; empty when [unchanged].
  final List<Notice> notices;
  final Climbers climbers;

  /// What to send next time, to hear [unchanged] if they still are (null:
  /// the server kept none, or the call sent no stamp).
  final String? stamp;

  /// Nothing changed since the stamp sent: keep the ones I have.
  final bool unchanged;
}

/// `GET /api/updates`: my plans, the requests waiting for me and my
/// notices, sharing one set of climbers.
class Updates {
  const Updates(this.plans, this.requests, this.notices);

  final MyPlans plans;
  final RequestList requests;
  final NoticeList notices;
}

/// How many chats one [GrigriApi.chatsMessages] asks about.
const maxChatsPerPoll = 50;

/// `GET /api/chats/messages`: each chat's messages, by plan id.
class ChatsMessages {
  const ChatsMessages(this.chats, this.climbers);

  final Map<String, List<Message>> chats;
  final Climbers climbers;
}

class PlanPicsList {
  const PlanPicsList(this.pics, this.climbers);

  final PlanPics pics;

  /// Who added the photos.
  final Climbers climbers;
}

class MessageList {
  const MessageList(this.messages, this.climbers);

  final List<Message> messages;
  final Climbers climbers;
}

/// The admins' list of team chats, and whose they are.
class TeamChatList {
  const TeamChatList(this.chats, this.climbers);

  final List<TeamChat> chats;
  final Climbers climbers;
}

/// A climber's team chat as admins see it: the climber and the admins who
/// answered in [climbers].
class TeamMessageList {
  const TeamMessageList(this.messages, this.climbers);

  final List<TeamMessage> messages;
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
    premium: Premium.fromJson(json['premium']),
  );

  static List<Wall> walls(Map<String, Object?> json) =>
      _list(json['walls']).map(Wall.fromJson).toList();

  static Wall wall(Map<String, Object?> json) =>
      Wall.fromJson(_map(json['wall']));

  static PremiumOffer premiumOffer(Map<String, Object?> json) => PremiumOffer(
    Premium.fromJson(json['premium']),
    {
      for (final plan in PremiumPlan.values)
        plan: ?PremiumPrice.fromJson((json['prices'] as Map?)?[plan.name]),
    },
    appleAccountToken: json['appleAccountToken'] is String
        ? json['appleAccountToken']! as String
        : null,
  );

  static Uri url(Map<String, Object?> json) =>
      Uri.parse(json['url']! as String);

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
    covers: {
      for (final e in (json['covers'] as Map? ?? {}).entries)
        e.key as String: ?DeckCover.fromJson(e.value),
    },
    scores: {
      for (final e in (json['scores'] as Map? ?? {}).entries)
        e.key as String: ?MatchScore.fromJson(_map(e.value)),
    },
    ads: _ads(json['ads']),
    adEvery: (json['adEvery'] as num?)?.toInt() ?? 0,
  );

  static List<Ad> _ads(Object? v) => [
    for (final a in _list(v)) ?Ad.fromJson(a),
  ];

  static Ad ad(Map<String, Object?> json) => Ad.fromJson(_map(json['ad']))!;

  static List<AdRegion> places(Map<String, Object?> json) => [
    if (json['places'] case final List<Object?> places)
      for (final p in places) ?AdRegion.fromJson(p),
  ];

  static MyAds myAds(Map<String, Object?> json) =>
      MyAds(_ads(json['ads']), premium: json['premium'] == true);

  static AdminAds adminAds(Map<String, Object?> json) => AdminAds(
    _ads(json['ads']),
    climbers(json),
    every: (json['every'] as num?)?.toInt() ?? 0,
  );

  static List<AdminClimber> adminClimbers(Map<String, Object?> json) => [
    for (final c in _list(json['climbers']))
      AdminClimber(Climber.fromJson(c), blocked: c['blocked'] == true),
  ];

  static AdminReports adminReports(Map<String, Object?> json) => AdminReports([
    for (final r in _list(json['reports'])) ?Report.fromJson(r),
  ], climbers(json));

  static BlockList blockList(Map<String, Object?> json) => BlockList([
    for (final id in (json['blocked'] as List?) ?? const []) id as String,
  ], climbers(json));

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

  static NoticeList noticeList(Map<String, Object?> json, [Climbers? shared]) =>
      NoticeList(
        [for (final n in _list(json['notices'])) ?Notice.fromJson(n)],
        shared ?? climbers(json),
        stamp: json['stamp'] as String?,
        unchanged: json['unchanged'] == true,
      );

  static Updates updates(Map<String, Object?> json) {
    final people = climbers(json);
    final plans = _map(json['plans']);
    final requests = _map(json['requests']);
    return Updates(
      myPlans({...plans, 'climbers': json['climbers']}),
      RequestList(
        _list(requests['requests']).map(JoinRequest.fromJson).toList(),
        _plansById(requests['plans']),
        people,
      ),
      noticeList(_map(json['notices']), people),
    );
  }

  static ChatsMessages chatsMessages(Map<String, Object?> json) =>
      ChatsMessages({
        for (final e in ((json['chats'] as Map?) ?? const {}).entries)
          e.key as String: _list(e.value).map(Message.fromJson).toList(),
      }, climbers(json));

  static MessageList messageList(Map<String, Object?> json) => MessageList(
    _list(json['messages']).map(Message.fromJson).toList(),
    climbers(json),
  );

  static List<TeamMessage> teamMessages(Map<String, Object?> json) =>
      _list(json['messages']).map(TeamMessage.fromJson).toList();

  static TeamMessage teamMessage(Map<String, Object?> json) =>
      TeamMessage.fromJson(_map(json['message']));

  static TeamChatList teamChats(Map<String, Object?> json) => TeamChatList(
    _list(json['chats']).map(TeamChat.fromJson).toList(),
    climbers(json),
  );

  static TeamMessageList teamMessageList(Map<String, Object?> json) =>
      TeamMessageList(teamMessages(json), climbers(json));

  static PlanPicsList planPics(Map<String, Object?> json) => PlanPicsList(
    PlanPics(
      yours: _list(json['yours']).map(PlanPic.fromJson).toList(),
      grigri: _list(json['grigri']).map(GrigriPic.fromJson).toList(),
      member: json['member'] == true,
    ),
    climbers(json),
  );

  static PlanPic planPic(Map<String, Object?> json) =>
      PlanPic.fromJson(_map(json['pic']));

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
