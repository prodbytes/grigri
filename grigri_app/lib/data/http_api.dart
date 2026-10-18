import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../model/ad.dart';
import '../model/climber.dart';
import '../model/climbing.dart';
import '../model/pics.dart';
import '../model/walls.dart';
import '../model/plan.dart';
import '../model/premium.dart';
import '../model/report.dart';
import '../model/team.dart';
import '../log.dart';
import 'api.dart';
import 'auth.dart';
import 'realtime.dart';

/// The headers that say who's calling: the API's session token as a
/// bearer token. Empty when signed out.
typedef AuthHeaders = Future<Map<String, String>> Function();

/// [GrigriApi] and the [SessionApi] over HTTP, against `<origin>/api`.
/// Errors come back as an [ApiException] with the server's message;
/// nothing here logs a token or puts one in a URL. Failed calls are logged
/// (method, path, status, the server's message), never their bodies.
class HttpGrigriApi implements GrigriApi, SessionApi {
  HttpGrigriApi({
    required this.origin,
    required this.headers,
    http.Client? client,
    this.timeout = const Duration(seconds: 20),
  }) : _client = client ?? http.Client();

  /// The site: the API is under `/api`, the photos under `/photos`.
  final Uri origin;
  final AuthHeaders headers;
  final Duration timeout;
  final http.Client _client;

  Uri _url(List<String> segments, [Map<String, String>? query]) =>
      origin.replace(
        pathSegments: ['api', ...segments],
        queryParameters: query == null || query.isEmpty ? null : query,
      );

  @override
  Uri photoUrl(String key) =>
      origin.replace(pathSegments: ['photos', ...key.split('/')]);

  @override
  Future<Uint8List> photoBytes(String key) async {
    final http.Response response;
    try {
      response = await _client.get(photoUrl(key)).timeout(timeout);
    } on TimeoutException {
      throw const ApiException(
        0,
        'The photo took too long.',
        client: ClientError.photoTimeout,
      );
    } on http.ClientException {
      throw const ApiException(
        0,
        "Couldn't reach the photo.",
        client: ClientError.photoUnreachable,
      );
    }
    if (response.statusCode != 200) {
      throw ApiException(
        response.statusCode,
        "Couldn't load the photo.",
        client: ClientError.photoFailed,
      );
    }
    return response.bodyBytes;
  }

  @override
  Uri picUrl(String key) =>
      origin.replace(pathSegments: ['pics', ...key.split('/')]);

  @override
  Future<List<GrigriPic>> picsCatalog() async {
    final url = origin.replace(pathSegments: ['pics', 'catalog.json']);
    final http.Response response;
    try {
      response = await _client.get(url).timeout(timeout);
    } on TimeoutException {
      throw const ApiException(0, 'The catalog took too long.');
    } on http.ClientException {
      throw const ApiException(0, "Couldn't reach the catalog.");
    }
    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, "Couldn't load the catalog.");
    }
    final json = jsonDecode(utf8.decode(response.bodyBytes));
    final crags = json is Map ? json['crags'] : null;
    return [
      if (crags is List)
        for (final crag in crags.whereType<Map<String, Object?>>())
          if (crag['photos'] case final List photos)
            for (final photo in photos.whereType<Map<String, Object?>>())
              if (photo['key'] is String)
                GrigriPic.fromJson({...photo, 'crag': crag['name']}),
    ];
  }

  Future<Map<String, Object?>> _send(
    String method,
    List<String> segments, {
    Object? body,
    Map<String, String>? query,
    Map<String, String>? auth,
  }) async {
    final request = http.Request(method, _url(segments, query))
      ..headers.addAll(auth ?? await headers())
      ..headers['Accept'] = 'application/json';
    if (body != null) {
      request
        ..headers['Content-Type'] = 'application/json'
        ..body = jsonEncode(body);
    }
    final what = '$method /api/${segments.join('/')}';
    final http.Response response;
    try {
      response = await http.Response.fromStream(
        await _client.send(request).timeout(timeout),
      ).timeout(timeout);
    } on TimeoutException {
      log.warn('api', '$what: timed out after ${timeout.inSeconds} s');
      throw const ApiException(
        0,
        'The server took too long to answer.',
        client: ClientError.timeout,
      );
    } on http.ClientException catch (e) {
      log.warn('api', '$what: unreachable (${origin.host}): ${e.message}');
      throw const ApiException(
        0,
        'Couldn\'t reach the server.',
        client: ClientError.unreachable,
      );
    }
    Object? json;
    if (response.body.isNotEmpty) {
      try {
        json = jsonDecode(utf8.decode(response.bodyBytes));
      } on FormatException {
        json = null;
      }
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      log.warn(
        'api',
        '$what: ${response.statusCode}'
            '${json is Map && json['error'] is String ? ' ${json['error']}' : ''}',
      );
      if (json is Map && json['error'] is String) {
        throw ApiException(response.statusCode, json['error'] as String);
      }
      throw ApiException(
        response.statusCode,
        'Something went wrong (${response.statusCode}).',
        client: ClientError.failed,
      );
    }
    if (json is Map) return json.cast();
    return const {};
  }

  Future<Map<String, Object?>> _get(
    List<String> segments, [
    Map<String, String>? query,
  ]) => _send('GET', segments, query: query);

  Future<Map<String, Object?>> _post(List<String> segments, [Object? body]) =>
      _send('POST', segments, body: body ?? const <String, Object>{});

  Future<Map<String, Object?>> _put(List<String> segments, Object body) =>
      _send('PUT', segments, body: body);

  static Map<String, String> _bearer(String token) => {
    'Authorization': 'Bearer $token',
  };

  @override
  Future<String> createSession(Credential credential) async {
    final json = await _send(
      'POST',
      ['session'],
      body: credential.sessionBody,
      auth: const {},
    );
    final token = json['token'];
    if (token is! String || token.isEmpty) {
      throw const ApiException(0, 'The server didn\'t start a session.');
    }
    return token;
  }

  @override
  Future<void> deleteSession(String token) =>
      _send('DELETE', ['session'], auth: _bearer(token));

  @override
  Future<void> deleteSessions(String token) =>
      _send('DELETE', ['sessions'], auth: _bearer(token));

  @override
  Future<Me> me() async => ApiJson.me(await _get(['me']));

  @override
  Future<RealtimeInfo?> realtime() async =>
      RealtimeInfo.fromJson(await _get(['realtime']));

  @override
  Future<Climber> saveMe(Climber profile) async =>
      ApiJson.climber(await _put(['me'], profile.toJson()));

  @override
  Future<void> deleteAccount() =>
      _send('DELETE', ['me'], body: const {'confirm': true});

  @override
  Future<PlanList> discover() async =>
      ApiJson.planList(await _get(['discover']));

  @override
  Future<Plan> createPlan(Plan plan) async =>
      ApiJson.plan(await _post(['plans'], plan.toJson()));

  @override
  Future<Plan> updatePlan(Plan plan) async =>
      ApiJson.plan(await _put(['plans', plan.id], plan.toJson()));

  @override
  Future<MyPlans> myPlans() async => ApiJson.myPlans(await _get(['plans']));

  @override
  Future<PlanDetail> plan(String id) async =>
      ApiJson.planDetail(await _get(['plans', id]));

  @override
  Future<void> leave(String planId) => _post(['plans', planId, 'leave']);

  @override
  Future<JoinRequest> join(String planId) async =>
      ApiJson.request(await _post(['plans', planId, 'join']));

  @override
  Future<({JoinRequest request, int nudged})> nudge(String planId) async =>
      ApiJson.nudge(await _post(['plans', planId, 'nudge']));

  @override
  Future<void> pass(String planId) => _post(['plans', planId, 'pass']);

  @override
  Future<void> clearPasses() => _send('DELETE', ['passes']);

  @override
  Future<RequestList> requests() async =>
      ApiJson.requestList(await _get(['requests']));

  @override
  Future<ApiMatch?> accept(String planId, String climberId) async =>
      ApiJson.match(await _post(['requests', planId, climberId, 'accept']));

  @override
  Future<void> reject(String planId, String climberId) =>
      _post(['requests', planId, climberId, 'reject']);

  @override
  Future<void> dismiss(String planId, String climberId) =>
      _post(['requests', planId, climberId, 'dismiss']);

  @override
  Future<NoticeList> notices() async =>
      ApiJson.noticeList(await _get(['notices']));

  @override
  Future<void> readNotices() => _post(['notices', 'read']);

  @override
  Future<List<TeamMessage>> teamMessages({DateTime? after}) async =>
      ApiJson.teamMessages(
        await _get([
          'team',
          'messages',
        ], after == null ? null : {'after': apiTime(after)}),
      );

  @override
  Future<TeamMessage> sendToTeam(String text) async =>
      ApiJson.teamMessage(await _post(['team', 'messages'], {'text': text}));

  @override
  Future<void> readTeam() => _post(['team', 'read']);

  @override
  Future<TeamChatList> adminTeamChats() async =>
      ApiJson.teamChats(await _get(['admin', 'team']));

  @override
  Future<TeamMessageList> adminTeamMessages(
    String climberId, {
    DateTime? after,
  }) async => ApiJson.teamMessageList(
    await _get([
      'admin',
      'team',
      climberId,
      'messages',
    ], after == null ? null : {'after': apiTime(after)}),
  );

  @override
  Future<TeamMessage> answerAsTeam(String climberId, String text) async =>
      ApiJson.teamMessage(
        await _post(['admin', 'team', climberId, 'messages'], {'text': text}),
      );

  @override
  Future<MessageList> messages(String planId, {DateTime? after}) async =>
      ApiJson.messageList(
        await _get([
          'plans',
          planId,
          'messages',
        ], after == null ? null : {'after': apiTime(after)}),
      );

  @override
  Future<Message> send(
    String planId,
    String text, {
    String? attachment,
  }) async => ApiJson.message(
    await _post(
      ['plans', planId, 'messages'],
      {'text': text, 'attachment': ?attachment},
    ),
  );

  @override
  Future<PhotoUpload> newPhoto(PhotoKind kind, String contentType) async =>
      ApiJson.photoUpload(
        await _post(
          ['photos'],
          {'kind': kind.name, 'contentType': contentType},
        ),
        contentType,
      );

  @override
  Future<PhotoUpload> newChatMedia(String planId, String contentType) async =>
      ApiJson.photoUpload(
        await _post(['plans', planId, 'media'], {'contentType': contentType}),
        contentType,
      );

  @override
  Future<List<Wall>> walls(double lat, double lon) async =>
      ApiJson.walls(await _get(['walls'], {'lat': '$lat', 'lon': '$lon'}));

  @override
  Future<PhotoUpload> newWallPhoto(String contentType) async =>
      ApiJson.photoUpload(
        await _post(['walls', 'photo'], {'contentType': contentType}),
        contentType,
      );

  @override
  Future<Wall> createWall({
    required String name,
    required double lat,
    required double lon,
    String? cragId,
    required String key,
    required int width,
    required int height,
  }) async => ApiJson.wall(
    await _post(
      ['walls'],
      {
        'name': name,
        'lat': lat,
        'lon': lon,
        'cragId': ?cragId,
        'view': {'key': key, 'width': width, 'height': height},
      },
    ),
  );

  @override
  Future<Wall> addRoute(
    String wallId, {
    required String name,
    required GradeScale scale,
    required int grade,
    required List<(double, double)> bolts,
  }) async => ApiJson.wall(
    await _post(
      ['walls', wallId, 'routes'],
      {
        'name': name,
        'grade': {'scale': scale.name, 'grade': grade},
        'bolts': [
          for (final (x, y) in bolts) [x, y],
        ],
      },
    ),
  );

  @override
  Future<Wall> deleteRoute(String wallId, String routeId) async =>
      ApiJson.wall(await _send('DELETE', ['walls', wallId, 'routes', routeId]));

  @override
  Future<Wall> addWallView(
    String wallId, {
    required String key,
    required int width,
    required int height,
    required List<double> h,
  }) async => ApiJson.wall(
    await _post(
      ['walls', wallId, 'views'],
      {'key': key, 'width': width, 'height': height, 'h': h},
    ),
  );

  @override
  Future<PlanPicsList> planPics(String planId) async =>
      ApiJson.planPics(await _get(['plans', planId, 'pics']));

  @override
  Future<PhotoUpload> newPlanPic(String planId, String contentType) async =>
      ApiJson.photoUpload(
        await _post(
          ['plans', planId, 'pics', 'upload'],
          {'contentType': contentType},
        ),
        contentType,
      );

  @override
  Future<PlanPic> addPlanPic(String planId, String key) async =>
      ApiJson.planPic(await _post(['plans', planId, 'pics'], {'key': key}));

  @override
  Future<void> deletePlanPic(String planId, String picId) =>
      _send('DELETE', ['plans', planId, 'pics', picId]);

  /// A multipart POST straight to S3: the presigned fields, then the file.
  /// No Authorization header: the signature is in the fields. The file goes
  /// in chunks, so [onProgress] hears how much has gone (on the web the
  /// browser takes it all at once, then sends it).
  @override
  Future<void> uploadPhoto(
    PhotoUpload upload,
    Uint8List bytes, {
    void Function(double sent)? onProgress,
  }) async {
    const chunk = 64 * 1024;
    Stream<List<int>> chunks() async* {
      for (var at = 0; at < bytes.length; at += chunk) {
        final end = at + chunk < bytes.length ? at + chunk : bytes.length;
        yield Uint8List.sublistView(bytes, at, end);
        onProgress?.call(end / bytes.length);
      }
    }

    final request = http.MultipartRequest('POST', upload.url)
      ..fields.addAll(upload.fields)
      ..files.add(
        http.MultipartFile(
          'file',
          chunks(),
          bytes.length,
          filename: 'upload.${upload.contentType.split('/').last}',
        ),
      );
    // Videos are big: the usual time, plus 10 s per MB (about 100 KB/s at
    // worst), so a 50 MB one gets about 9 minutes.
    final limit = timeout + Duration(seconds: 10 * (bytes.length >> 20));
    final http.StreamedResponse response;
    try {
      response = await _client.send(request).timeout(limit);
      await response.stream.drain<void>();
    } on TimeoutException {
      throw const ApiException(
        0,
        'The photo upload took too long.',
        client: ClientError.photoTimeout,
      );
    } on http.ClientException {
      throw const ApiException(
        0,
        'Couldn\'t upload the photo.',
        client: ClientError.photoUnreachable,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        response.statusCode,
        'The photo upload failed (${response.statusCode}).',
        client: ClientError.photoFailed,
      );
    }
  }

  @override
  Future<PremiumOffer> premium({bool fresh = false}) async =>
      ApiJson.premiumOffer(
        await _get(['premium'], fresh ? const {'fresh': '1'} : null),
      );

  @override
  Future<Uri> premiumCheckout(PremiumPlan plan) async =>
      ApiJson.url(await _post(['premium', 'checkout'], {'plan': plan.name}));

  @override
  Future<Uri> premiumPortal() async =>
      ApiJson.url(await _post(['premium', 'portal']));

  @override
  Future<PremiumOffer> premiumApple(String signedTransaction) async =>
      ApiJson.premiumOffer(
        await _post(['premium', 'apple'], {'transaction': signedTransaction}),
      );

  @override
  Future<MyAds> myAds() async => ApiJson.myAds(await _get(['ads']));

  @override
  Future<PhotoUpload> newAdMedia(String contentType) async =>
      ApiJson.photoUpload(
        await _post(['ads', 'media'], {'contentType': contentType}),
        contentType,
      );

  @override
  Future<Ad> createAd({
    required String text,
    required String link,
    String? mediaKey,
    List<AdRegion> regions = const [],
  }) async => ApiJson.ad(
    await _post(
      ['ads'],
      {
        'text': text,
        'link': link,
        if (mediaKey != null) 'media': {'key': mediaKey},
        if (regions.isNotEmpty)
          'regions': [for (final r in regions) r.toJson()],
      },
    ),
  );

  @override
  Future<List<AdRegion>> searchPlaces(String query, String language) async =>
      ApiJson.places(await _get(['places'], {'q': query, 'lang': language}));

  @override
  Future<void> deleteAd(String adId) => _send('DELETE', ['ads', adId]);

  @override
  Future<void> skipAd(String adId) => _post(['ads', adId, 'skip']);

  @override
  Future<AdminAds> adminAds(AdStatus status) async =>
      ApiJson.adminAds(await _get(['admin', 'ads'], {'status': status.name}));

  @override
  Future<Ad> reviewAd(String adId, {required bool approve}) async => ApiJson.ad(
    await _post(['admin', 'ads', adId, approve ? 'approve' : 'reject']),
  );

  @override
  Future<void> setAdEvery(int every) =>
      _put(['admin', 'ads', 'settings'], {'every': every});

  @override
  Future<List<AdminClimber>> adminClimbers() async =>
      ApiJson.adminClimbers(await _get(['admin', 'climbers']));

  @override
  Future<void> setBlocked(String climberId, bool blocked) =>
      _post(['admin', 'climbers', climberId, blocked ? 'block' : 'unblock']);

  @override
  Future<void> sendReport({
    required ReportKind kind,
    required String targetId,
    String? planId,
    required ReportReason reason,
    String text = '',
  }) => _post(
    ['reports'],
    {
      'kind': kind.name,
      'targetId': targetId,
      'planId': ?planId,
      'reason': reason.name,
      if (text.trim().isNotEmpty) 'text': text.trim(),
    },
  );

  @override
  Future<AdminReports> adminReports() async =>
      ApiJson.adminReports(await _get(['admin', 'reports']));

  @override
  Future<void> resolveReport(String reportId, ReportAction action) =>
      _post(['admin', 'reports', reportId, action.name]);

  @override
  Future<BlockList> blocks() async => ApiJson.blockList(await _get(['blocks']));

  @override
  Future<void> setPersonBlocked(String climberId, bool blocked) => blocked
      ? _post(['blocks', climberId])
      : _send('DELETE', ['blocks', climberId]);
}
