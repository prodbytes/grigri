import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:grigri_app/data/api.dart';
import 'package:grigri_app/data/auth.dart';
import 'package:grigri_app/data/grigri_store.dart';
import 'package:grigri_app/data/realtime.dart';
import 'package:grigri_app/data/session_storage.dart';
import 'package:grigri_app/model/climber.dart';
import 'package:grigri_app/model/climbing.dart';
import 'package:grigri_app/model/plan.dart';

/// A tiny valid PNG, standing in for photos.
final png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGNgYGD4DwABBAEAwS2OUAAAAABJRU5ErkJggg==',
);

/// An in-memory backend that follows the API's rules (specs/api.md) for
/// one caller, [meId], and records every route called. Its climbers are
/// made up, here in the tests (never in lib/). Its sessions follow
/// specs/sign-in.md: once [headers] is set, every route but the session
/// ones needs `Authorization: Bearer <a session token>`.
class FakeApi implements GrigriApi, SessionApi {
  FakeApi({this.admin = false});

  /// Who's calling (the app's [Auth.headers]); unchecked when null.
  Future<Map<String, String>> Function()? headers;

  /// The live sessions: token → whose.
  final sessions = <String, String>{};

  /// The bodies `POST /api/session` was called with.
  final sessionBodies = <Map<String, String>>[];

  int _sessionIds = 0;

  /// A new session for [email], as `POST /api/session` makes.
  String openSession(String email) {
    final token = 'session-${++_sessionIds}';
    sessions[token] = email;
    return token;
  }

  /// The session token [headers] carry, if it's live.
  Future<String?> _caller() async {
    final auth = (await headers!())['Authorization'];
    if (auth == null || !auth.startsWith('Bearer ')) return null;
    final token = auth.substring('Bearer '.length);
    return sessions.containsKey(token) ? token : null;
  }

  /// The caller's climber id once they have a profile.
  String? meId;
  bool admin;

  final climbers = <String, Climber>{};
  final plans = <String, Plan>{};
  final requestsById = <String, JoinRequest>{};
  final noticesFor = <String, List<Notice>>{};
  final allMessages = <Message>[];
  final passed = <String>{};
  final dismissed = <String>{};

  /// What the deck says about how far each plan is (the server works it
  /// out from my location and areas; tests set it).
  final distanceKm = <String, int>{};

  /// Every call, as "METHOD /api/route".
  final calls = <String>[];

  /// Photos uploaded to the presigned POSTs: key → bytes.
  final uploads = <String, Uint8List>{};

  /// The next call fails with this.
  ApiException? failNext;

  int _ids = 0;
  DateTime _last = DateTime.now().toUtc();

  /// Strictly increasing times, so `after=` polling is exact.
  DateTime _now() {
    final now = DateTime.now().toUtc();
    _last = now.isAfter(_last)
        ? now
        : _last.add(const Duration(milliseconds: 1));
    return _last;
  }

  String _id(String prefix) => '$prefix-${++_ids}';

  Future<T> _route<T>(String route, T Function() body) async {
    calls.add(route);
    final fail = failNext;
    if (fail != null) {
      failNext = null;
      throw fail;
    }
    if (headers != null && await _caller() == null) {
      throw const ApiException(401, 'signed out');
    }
    if (meId == null &&
        !route.endsWith(' /api/me') &&
        route != 'POST /api/photos') {
      throw const ApiException(409, 'no profile');
    }
    return body();
  }

  /// Profiles as the server shares them: without location and areas,
  /// which are private (mine too).
  Climbers _mention(Iterable<String> ids) => {
    for (final id in ids)
      if (climbers[id] case final c?)
        id: c.copyWith(location: null, areas: const []),
  };

  Iterable<String> _planPeople(Plan p) => p.memberIds;

  // --- Test helpers: what other people do ---------------------------------

  void addClimber(Climber c) => climbers[c.id] = c;

  void addPlan(Plan p) => plans[p.id] = p;

  /// [climberId] asks to join [planId].
  void ask(String planId, String climberId) {
    final r = JoinRequest(planId: planId, climberId: climberId, time: _now());
    requestsById[r.id] = r;
    allMessages.add(
      Message(
        id: _id('m'),
        planId: planId,
        authorId: null,
        text: '${climbers[climberId]!.name} asked to join',
        time: _now(),
        requestId: r.id,
      ),
    );
    for (final m in plans[planId]!.memberIds) {
      _notify(m, NoticeKind.request, planId, climberId: climberId);
    }
  }

  /// A member accepts a request, as the server does (joining when all
  /// have).
  ApiMatch? acceptAs(String memberId, String planId, String climberId) {
    final id = '$planId/$climberId';
    final r = requestsById[id]!;
    requestsById[id] = r.copyWith(acceptedBy: {...r.acceptedBy, memberId});
    return _settle(id);
  }

  /// Someone says something in a chat.
  void say(String planId, String authorId, String text) => allMessages.add(
    Message(
      id: _id('m'),
      planId: planId,
      authorId: authorId,
      text: text,
      time: _now(),
    ),
  );

  void _notify(
    String to,
    NoticeKind kind,
    String planId, {
    String? climberId,
  }) => (noticesFor[to] ??= []).add(
    Notice(
      id: _id('n'),
      kind: kind,
      planId: planId,
      planTitle: plans[planId]!.title,
      climberId: climberId,
      time: _now(),
    ),
  );

  void _note(String planId, String text) => allMessages.add(
    Message(
      id: _id('m'),
      planId: planId,
      authorId: null,
      text: text,
      time: _now(),
    ),
  );

  ApiMatch? _settle(String requestId, {bool force = false}) {
    final r = requestsById[requestId]!;
    final plan = plans[r.planId]!;
    if (r.rejected) return null;
    if (!force && !plan.memberIds.every(r.acceptedBy.contains)) return null;
    final grown = plan.copyWith(memberIds: [...plan.memberIds, r.climberId]);
    plans[plan.id] = grown;
    requestsById.remove(requestId);
    _note(plan.id, '${climbers[r.climberId]!.name} joined the plan 🎉');
    _notify(r.climberId, NoticeKind.accepted, plan.id);
    return ApiMatch(grown, r.climberId);
  }

  // --- The routes -----------------------------------------------------------

  @override
  Future<String> createSession({String? idToken, String? devUser}) async {
    calls.add('POST /api/session');
    final fail = failNext;
    if (fail != null) {
      failNext = null;
      throw fail;
    }
    sessionBodies.add({'idToken': ?idToken, 'devUser': ?devUser});
    final email = idToken == 'google-id-token' ? 'pat@example.com' : devUser;
    if (email == null) throw const ApiException(401, 'signed out');
    return openSession(email);
  }

  @override
  Future<void> deleteSession(String token) async {
    calls.add('DELETE /api/session');
    if (sessions.remove(token) == null) {
      throw const ApiException(401, 'signed out');
    }
  }

  @override
  Future<void> deleteSessions(String token) async {
    calls.add('DELETE /api/sessions');
    final fail = failNext;
    if (fail != null) {
      failNext = null;
      throw fail;
    }
    final email = sessions[token];
    if (email == null) throw const ApiException(401, 'signed out');
    sessions.removeWhere((_, owner) => owner == email);
  }

  @override
  Uri photoUrl(String key) => Uri.parse('https://grigri.test/photos/$key');

  /// What `GET /api/realtime` answers: null, live updates off.
  RealtimeInfo? realtimeInfo;

  @override
  Future<RealtimeInfo?> realtime() =>
      _route('GET /api/realtime', () => realtimeInfo);

  @override
  Future<Me> me() => _route(
    'GET /api/me',
    () => Me(climber: meId == null ? null : climbers[meId], admin: admin),
  );

  @override
  Future<Climber> saveMe(Climber profile) => _route('PUT /api/me', () {
    meId ??= 'me';
    final saved = Climber(
      id: meId!,
      name: profile.name,
      age: profile.age,
      bio: profile.bio,
      photo: profile.photo,
      levels: profile.levels,
      gear: profile.gear,
      gearPhotos: profile.gearPhotos,
      location: profile.location,
      areas: profile.areas,
    );
    climbers[meId!] = saved;
    return saved;
  });

  bool _fits(Plan p) {
    final level = climbers[meId]?.levels[p.discipline];
    return level != null && level.overlaps(p.grades);
  }

  @override
  Future<PlanList> discover() => _route('GET /api/discover', () {
    final now = DateTime.now();
    final list =
        plans.values
            .where(
              (p) =>
                  p.start.isAfter(now) &&
                  !p.memberIds.contains(meId) &&
                  !passed.contains(p.id) &&
                  !requestsById.containsKey('${p.id}/$meId') &&
                  !dismissed.contains(p.id),
            )
            .toList()
          ..sort((a, b) {
            final fit = (_fits(b) ? 1 : 0).compareTo(_fits(a) ? 1 : 0);
            return fit != 0 ? fit : a.start.compareTo(b.start);
          });
    return PlanList(
      list,
      _mention(list.expand(_planPeople)),
      distanceKm: {for (final p in list) p.id: ?distanceKm[p.id]},
    );
  });

  @override
  Future<Plan> createPlan(Plan plan) => _route('POST /api/plans', () {
    final created = Plan(
      id: _id('plan'),
      organizerId: meId!,
      discipline: plan.discipline,
      place: plan.place,
      area: plan.area,
      sectorId: plan.sectorId,
      lat: plan.lat,
      lon: plan.lon,
      start: plan.start,
      end: plan.end,
      grades: plan.grades,
      memberIds: [meId!],
      notes: plan.notes,
    );
    plans[created.id] = created;
    return created;
  });

  @override
  Future<Plan> updatePlan(Plan plan) => _route('PUT /api/plans/${plan.id}', () {
    final current = plans[plan.id]!;
    if (current.organizerId != meId) {
      throw const ApiException(403, 'Only the organizer can change it.');
    }
    return plans[plan.id] = plan.copyWith(memberIds: current.memberIds);
  });

  @override
  Future<MyPlans> myPlans() => _route('GET /api/plans', () {
    final mine = plans.values.where((p) => p.memberIds.contains(meId)).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    final asked = [
      for (final r in requestsById.values)
        if (r.climberId == meId && plans.containsKey(r.planId))
          (request: r, plan: plans[r.planId]!),
    ];
    return MyPlans(
      plans: mine,
      asked: asked,
      climbers: _mention({
        ...mine.expand(_planPeople),
        ...asked.expand((a) => _planPeople(a.plan)),
      }),
    );
  });

  @override
  Future<PlanDetail> plan(String id) => _route('GET /api/plans/$id', () {
    final p = plans[id];
    if (p == null) throw const ApiException(404, 'No such plan.');
    final open = p.memberIds.contains(meId)
        ? [
            for (final r in requestsById.values)
              if (r.planId == id && !r.rejected) r,
          ]
        : <JoinRequest>[];
    return PlanDetail(
      p,
      open,
      _mention({...p.memberIds, ...open.map((r) => r.climberId)}),
    );
  });

  @override
  Future<void> leave(String planId) =>
      _route('POST /api/plans/$planId/leave', () {
        final p = plans[planId]!;
        final members = [...p.memberIds]..remove(meId);
        if (members.isEmpty) {
          plans.remove(planId);
          requestsById.removeWhere((_, r) => r.planId == planId);
        } else {
          plans[planId] = p.copyWith(
            organizerId: p.organizerId == meId ? members.first : p.organizerId,
            memberIds: members,
          );
          _note(planId, '${climbers[meId]!.name} left the plan');
        }
        passed.add(planId);
      });

  @override
  Future<JoinRequest> join(String planId) =>
      _route('POST /api/plans/$planId/join', () {
        if (requestsById.containsKey('$planId/$meId')) {
          throw const ApiException(409, 'You already asked.');
        }
        ask(planId, meId!);
        return requestsById['$planId/$meId']!;
      });

  @override
  Future<void> pass(String planId) =>
      _route('POST /api/plans/$planId/pass', () => passed.add(planId));

  @override
  Future<RequestList> requests() => _route('GET /api/requests', () {
    final list = [
      for (final r in requestsById.values)
        if (!r.rejected &&
            !r.acceptedBy.contains(meId) &&
            (plans[r.planId]?.memberIds.contains(meId) ?? false))
          r,
    ];
    final byPlan = {for (final r in list) r.planId: plans[r.planId]!};
    return RequestList(
      list,
      byPlan,
      _mention({
        ...list.map((r) => r.climberId),
        ...byPlan.values.expand(_planPeople),
      }),
    );
  });

  void _member(String planId) {
    if (!(plans[planId]?.memberIds.contains(meId) ?? false)) {
      throw const ApiException(403, 'Only the group can answer.');
    }
  }

  @override
  Future<ApiMatch?> accept(String planId, String climberId) =>
      _route('POST /api/requests/$planId/$climberId/accept', () {
        _member(planId);
        return acceptAs(meId!, planId, climberId);
      });

  @override
  Future<void> reject(String planId, String climberId) =>
      _route('POST /api/requests/$planId/$climberId/reject', () {
        _member(planId);
        _reject('$planId/$climberId');
      });

  void _reject(String id) {
    final r = requestsById[id]!;
    requestsById[id] = r.copyWith(rejected: true);
    _notify(r.climberId, NoticeKind.declined, r.planId);
  }

  @override
  Future<void> dismiss(String planId, String climberId) =>
      _route('POST /api/requests/$planId/$climberId/dismiss', () {
        requestsById.remove('$planId/$climberId');
        dismissed.add(planId);
      });

  @override
  Future<NoticeList> notices() => _route('GET /api/notices', () {
    final mine = [...?noticesFor[meId]]
      ..sort((a, b) => b.time.compareTo(a.time));
    return NoticeList(mine, _mention([for (final n in mine) ?n.climberId]));
  });

  @override
  Future<void> readNotices() => _route('POST /api/notices/read', () {
    final mine = noticesFor[meId];
    if (mine == null) return;
    for (final (i, n) in mine.indexed) {
      mine[i] = n.copyWith(read: true);
    }
  });

  @override
  Future<MessageList> messages(String planId, {DateTime? after}) => _route(
    'GET /api/plans/$planId/messages${after == null ? '' : '?after'}',
    () {
      _member(planId);
      final list = [
        for (final m in allMessages)
          if (m.planId == planId && (after == null || m.time.isAfter(after))) m,
      ];
      return MessageList(list, _mention([for (final m in list) ?m.authorId]));
    },
  );

  @override
  Future<Message> send(String planId, String text) =>
      _route('POST /api/plans/$planId/messages', () {
        _member(planId);
        final m = Message(
          id: _id('m'),
          planId: planId,
          authorId: meId,
          text: text,
          time: _now(),
        );
        allMessages.add(m);
        return m;
      });

  @override
  Future<PhotoUpload> newPhoto(PhotoKind kind, String contentType) =>
      _route('POST /api/photos', () {
        final key = '${meId ?? 'new'}/${kind.name}-${++_ids}';
        return PhotoUpload(
          key: key,
          url: Uri.parse('https://bucket.test/'),
          fields: {'key': key, 'policy': 'made-up'},
          contentType: contentType,
        );
      });

  @override
  Future<void> uploadPhoto(PhotoUpload upload, Uint8List bytes) async {
    calls.add('POST ${upload.url} (${upload.fields['key']})');
    uploads[upload.key] = bytes;
  }

  void _admin() {
    if (!admin) throw const ApiException(403, 'Admins only.');
  }

  @override
  Future<RequestList> adminRequests() => _route('GET /api/admin/requests', () {
    _admin();
    final list = [
      for (final r in requestsById.values)
        if (!r.rejected) r,
    ];
    final byPlan = {for (final r in list) r.planId: plans[r.planId]!};
    return RequestList(
      list,
      byPlan,
      _mention({
        ...list.map((r) => r.climberId),
        ...byPlan.values.expand(_planPeople),
      }),
    );
  });

  @override
  Future<ApiMatch?> adminAccept(String planId, String climberId) =>
      _route('POST /api/admin/requests/$planId/$climberId/accept', () {
        _admin();
        return _settle('$planId/$climberId', force: true);
      });

  @override
  Future<void> adminReject(String planId, String climberId) =>
      _route('POST /api/admin/requests/$planId/$climberId/reject', () {
        _admin();
        _reject('$planId/$climberId');
      });
}

/// Google, made up: its button signs Pat in with a made-up ID token that
/// [FakeApi] takes.
class FakeGoogle extends SignInMethod {
  FakeGoogle({this.mode = SignInMode.google});

  @override
  final SignInMode mode;

  OnCredential? _onCredential;

  /// How many times the app signed out of Google.
  int signOuts = 0;

  @override
  Future<void> start({
    required OnCredential onCredential,
    required void Function(Object error) onError,
    required bool quietly,
  }) async => _onCredential = onCredential;

  @override
  Future<void> signIn({String? devEmail}) async => _onCredential?.call(
    const Credential(
      user: AuthUser(email: 'pat@example.com', name: 'Pat Quill'),
      idToken: 'google-id-token',
    ),
  );

  @override
  Future<void> signOut() async => signOuts++;
}

// --- Made-up climbers and plans -----------------------------------------------

DateTime inDays(int days, [int hour = 9]) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day + days, hour);
}

const me = Climber(
  id: 'me',
  name: 'Pat Quill',
  age: 30,
  bio: 'Weekend sport climber.',
  levels: {
    Discipline.sport: GradeRange(GradeScale.routes, 6, 11),
    Discipline.bouldering: GradeRange(GradeScale.boulders, 3, 6),
  },
  gear: {Gear.rope, Gear.quickdraws},
);

const robin = Climber(
  id: 'robin',
  name: 'Robin Vale',
  age: 34,
  levels: {Discipline.sport: GradeRange(GradeScale.routes, 10, 16)},
);
const kit = Climber(
  id: 'kit',
  name: 'Kit Marlow',
  levels: {Discipline.bouldering: GradeRange(GradeScale.boulders, 3, 7)},
);
const sasha = Climber(
  id: 'sasha',
  name: 'Sasha Brook',
  age: 27,
  levels: {Discipline.bouldering: GradeRange(GradeScale.boulders, 2, 5)},
);
const jules = Climber(
  id: 'jules',
  name: 'Jules Fern',
  age: 25,
  levels: {Discipline.gym: GradeRange(GradeScale.routes, 5, 9)},
);

/// A backend with [me] (unless [profile] is false), a few made-up
/// climbers and their plans: Kit and Sasha's bouldering at Block Hall
/// tomorrow, Robin's day at Grey Cliffs in three days, and my plan at Wall
/// Works, which Jules asked to join.
FakeApi sampleApi({bool admin = false, bool profile = true}) {
  final api = FakeApi(admin: admin);
  for (final c in [robin, kit, sasha, jules]) {
    api.addClimber(c);
  }
  if (profile) {
    api
      ..meId = 'me'
      ..addClimber(me);
  }
  api
    ..addPlan(
      Plan(
        id: 'boulder-night',
        organizerId: 'kit',
        discipline: Discipline.bouldering,
        place: 'Block Hall',
        start: inDays(1, 19),
        end: inDays(1, 22),
        grades: const GradeRange(GradeScale.boulders, 2, 6),
        memberIds: const ['kit', 'sasha'],
      ),
    )
    ..addPlan(
      Plan(
        id: 'crag-day',
        organizerId: 'robin',
        discipline: Discipline.sport,
        place: 'Grey Cliffs',
        area: 'Northvale, Nowhere',
        start: inDays(3),
        end: inDays(3, 16),
        grades: const GradeRange(GradeScale.routes, 6, 12),
        memberIds: const ['robin'],
      ),
    )
    ..addPlan(
      Plan(
        id: 'my-gym',
        organizerId: 'me',
        discipline: Discipline.gym,
        place: 'Wall Works',
        start: inDays(2, 18),
        end: inDays(2, 20),
        grades: const GradeRange(GradeScale.routes, 5, 10),
        memberIds: const ['me'],
      ),
    );
  if (profile) api.ask('my-gym', 'jules');
  return api;
}

/// The store over [api], with photos from memory and the app's own
/// sessions: signed in (unless [signedIn] is false) with a session kept on
/// the device, or the one in [storage]. Dev mode signs in with
/// [DevSignInMethod], the rest with [FakeGoogle]. Live updates over
/// [realtime] when given.
GrigriStore storeFor(
  FakeApi api, {
  bool signedIn = true,
  SignInMode mode = SignInMode.google,
  MemorySessionStorage? storage,
  RealtimeTransport? realtime,
}) {
  final auth = SessionAuth(
    method: mode == SignInMode.dev ? DevSignInMethod() : FakeGoogle(mode: mode),
    sessions: api,
    storage:
        storage ??
        MemorySessionStorage(
          signedIn ? api.openSession('pat@example.com') : null,
        ),
  );
  api.headers = auth.headers;
  return GrigriStore(
    api: api,
    auth: auth,
    image: (_) => MemoryImage(png),
    realtime: realtime,
  );
}

/// Where the fake live updates say to connect.
final fakeRealtimeInfo = RealtimeInfo(
  url: Uri.parse('wss://mqtt.example.com/mqtt'),
  authorizer: 'grigri-test-realtime',
  topic: 'grigri/test/climbers/me/#',
  clientIdPrefix: 'me-',
);

/// Live updates, made up: records each connection; tests send hints down
/// [current] and drop it.
class FakeRealtimeTransport implements RealtimeTransport {
  final connects = <({Uri url, String clientId, String topic})>[];
  final channels = <FakeRealtimeChannel>[];

  /// Connections are refused while true.
  bool refuse = false;

  FakeRealtimeChannel get current => channels.last;

  @override
  Future<RealtimeChannel> connect({
    required Uri url,
    required String clientId,
    required String topic,
  }) async {
    connects.add((url: url, clientId: clientId, topic: topic));
    if (refuse) throw StateError('refused');
    final channel = FakeRealtimeChannel();
    channels.add(channel);
    return channel;
  }
}

class FakeRealtimeChannel implements RealtimeChannel {
  final _messages = StreamController<String>.broadcast();
  final _closed = Completer<void>();

  bool get isClosed => _closed.isCompleted;

  /// A message from the broker.
  void send(String payload) => _messages.add(payload);

  /// The connection drops.
  void drop() {
    if (!_closed.isCompleted) _closed.complete();
  }

  @override
  Stream<String> get messages => _messages.stream;

  @override
  Future<void> get closed => _closed.future;

  @override
  void close() => drop();
}

/// The session token kept on [store]'s device.
String? keptToken(GrigriStore store) =>
    ((store.auth as SessionAuth).storage as MemorySessionStorage).token;
