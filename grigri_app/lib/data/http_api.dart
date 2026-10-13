import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../model/climber.dart';
import '../model/plan.dart';
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
  Future<String> createSession({required String idToken}) async {
    final json = await _send(
      'POST',
      ['session'],
      body: {'idToken': idToken},
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
  Future<void> pass(String planId) => _post(['plans', planId, 'pass']);

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
  Future<MessageList> messages(String planId, {DateTime? after}) async =>
      ApiJson.messageList(
        await _get([
          'plans',
          planId,
          'messages',
        ], after == null ? null : {'after': apiTime(after)}),
      );

  @override
  Future<Message> send(String planId, String text) async => ApiJson.message(
    await _post(['plans', planId, 'messages'], {'text': text}),
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

  /// A multipart POST straight to S3: the presigned fields, then the file.
  /// No Authorization header: the signature is in the fields.
  @override
  Future<void> uploadPhoto(PhotoUpload upload, Uint8List bytes) async {
    final request = http.MultipartRequest('POST', upload.url)
      ..fields.addAll(upload.fields)
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: 'photo.${upload.contentType.split('/').last}',
        ),
      );
    final http.StreamedResponse response;
    try {
      response = await _client.send(request).timeout(timeout);
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
  Future<RequestList> adminRequests() async =>
      ApiJson.requestList(await _get(['admin', 'requests']));

  @override
  Future<ApiMatch?> adminAccept(String planId, String climberId) async =>
      ApiJson.match(
        await _post(['admin', 'requests', planId, climberId, 'accept']),
      );

  @override
  Future<void> adminReject(String planId, String climberId) =>
      _post(['admin', 'requests', planId, climberId, 'reject']);
}
