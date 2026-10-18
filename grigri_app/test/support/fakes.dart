import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:grigri_app/data/api.dart';
import 'package:grigri_app/data/app_store.dart';
import 'package:grigri_app/data/auth.dart';
import 'package:grigri_app/data/device_location.dart';
import 'package:grigri_app/data/grigri_store.dart';
import 'package:grigri_app/data/preferences.dart';
import 'package:grigri_app/data/realtime.dart';
import 'package:grigri_app/data/sector_index.dart';
import 'package:grigri_app/data/session_storage.dart';
import 'package:grigri_app/model/ad.dart';
import 'package:grigri_app/model/climber.dart';
import 'package:grigri_app/model/climbing.dart';
import 'package:grigri_app/model/match_score.dart';
import 'package:grigri_app/model/pics.dart';
import 'package:grigri_app/model/walls.dart';
import 'package:grigri_app/model/plan.dart';
import 'package:grigri_app/model/premium.dart';
import 'package:grigri_app/model/report.dart';
import 'package:grigri_app/model/sector.dart';

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

  /// The signed-in Google account's name, for the profile GET /api/me makes.
  String googleName = 'Pat Quill';
  bool admin;

  /// My roles from rbacr, as `GET /api/me` gives them; null: rbacr
  /// couldn't say.
  List<String>? roles = const [];

  /// My Premium, as `GET /api/me` and `GET /api/premium` give it.
  Premium myPremium = const Premium.none();

  /// Premium's prices; empty: it can't be bought (no Stripe keys).
  Map<PremiumPlan, PremiumPrice> premiumPrices = const {
    PremiumPlan.monthly: PremiumPrice(amount: 2000, currency: 'usd'),
    PremiumPlan.yearly: PremiumPrice(amount: 20000, currency: 'usd'),
  };

  /// The links the app opened in the browser.
  final opened = <Uri>[];

  /// Every ad, by id; how often the deck shows them.
  final ads = <String, Ad>{};
  int adEvery = 5;
  int _adIds = 0;

  /// Adds an ad (already reviewed, or pending).
  void addAd(Ad ad) => ads[ad.id] = ad;

  final climbers = <String, Climber>{};
  final plans = <String, Plan>{};
  final requestsById = <String, JoinRequest>{};
  final noticesFor = <String, List<Notice>>{};
  final allMessages = <Message>[];

  /// Every plan's "Your Pics", oldest first.
  final allPics = <PlanPic>[];

  /// GriGri Pics, by plan (the server finds them by the plan's place;
  /// tests set them).
  final grigriPics = <String, List<GrigriPic>>{};

  /// GriGri Pics' catalog, for the sign-in screen.
  final catalog = <GrigriPic>[];
  final passed = <String>{};

  /// Plans I left: a refresh keeps them out of my deck.
  final left = <String>{};
  final dismissed = <String>{};

  /// What the deck says about how far each plan is (the server works it
  /// out from my location and areas; tests set it).
  final distanceKm = <String, int>{};

  /// The match scores an admin's deck carries (the server's, from aityx;
  /// tests set them).
  final matchScores = <String, MatchScore>{};

  /// The deck's cover photos (the server's, from GriGri Pics; tests set
  /// them).
  final covers = <String, DeckCover>{};

  /// Who an admin blocked: they get 403 "blocked" from every route.
  final blocked = <String>{};

  /// Who I blocked myself (specs/moderation.md): their plans leave my deck.
  final personBlocks = <String>{};

  /// The open reports, oldest first, as admins see them.
  final reports = <Report>[];

  /// What admins did with reports: "report-1 dismiss", say.
  final resolved = <String>[];
  int _reportIds = 0;

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
    if (blocked.contains(meId)) throw const ApiException(403, 'blocked');
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

  /// [climberId] nudges the members who haven't answered their request on
  /// [planId], as the server does: a nudge notice each (one per request,
  /// replaced by the next), at most once every 12 hours. How many were
  /// nudged.
  int nudgeAs(String planId, String climberId) {
    final plan = plans[planId];
    if (plan == null) throw const ApiException(404, 'no such plan');
    if (plan.memberIds.contains(climberId)) {
      throw const ApiException(409, "you're already in this plan");
    }
    final id = '$planId/$climberId';
    final r = requestsById[id];
    if (r == null) {
      throw const ApiException(404, "you haven't asked to join this plan");
    }
    if (r.rejected) throw const ApiException(409, 'the request was declined');
    final now = _now();
    if (plan.hasStarted(now)) {
      throw const ApiException(409, 'the plan has started');
    }
    if (!r.canNudge(now)) {
      throw const ApiException(
        429,
        'you nudged the group less than 12 hours ago; try again later',
      );
    }
    final waitingFor = [
      for (final m in plan.memberIds)
        if (!r.acceptedBy.contains(m)) m,
    ];
    if (waitingFor.isEmpty) {
      throw const ApiException(409, 'nobody left to answer');
    }
    requestsById[id] = r.copyWith(nudgedAt: now);
    final noticeId = '$planId/nudge/$climberId';
    for (final m in waitingFor) {
      final list = noticesFor[m] ??= [];
      list
        ..removeWhere((n) => n.id == noticeId)
        ..add(
          Notice(
            id: noticeId,
            kind: NoticeKind.nudge,
            planId: planId,
            planTitle: plan.title,
            climberId: climberId,
            time: now,
          ),
        );
    }
    return waitingFor.length;
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
    if (!force && !plan.deciders.every(r.acceptedBy.contains)) return null;
    final grown = plan.copyWith(memberIds: [...plan.memberIds, r.climberId]);
    plans[plan.id] = grown;
    requestsById.remove(requestId);
    _note(plan.id, '${climbers[r.climberId]!.name} joined the plan 🎉');
    _notify(r.climberId, NoticeKind.accepted, plan.id);
    return ApiMatch(grown, r.climberId);
  }

  // --- The routes -----------------------------------------------------------

  @override
  Future<String> createSession(Credential credential) async {
    calls.add('POST /api/session');
    final fail = failNext;
    if (fail != null) {
      failNext = null;
      throw fail;
    }
    final body = credential.sessionBody;
    sessionBodies.add(body);
    if (body['idToken'] != 'google-id-token' &&
        body['appleIdToken'] != 'apple-id-token') {
      throw const ApiException(401, 'signed out');
    }
    return openSession('pat@example.com');
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

  @override
  Uri picUrl(String key) => Uri.parse('https://grigri.test/pics/$key');

  @override
  Future<List<GrigriPic>> picsCatalog() async => catalog;

  @override
  Future<Uint8List> photoBytes(String key) async {
    final bytes = uploads[key];
    if (bytes == null) throw const ApiException(404, 'No such photo.');
    return bytes;
  }

  /// The route finder's walls (the server's).
  final allWalls = <Wall>[];

  Map<String, Object?> _wallJson(Wall w) => {
    'id': w.id,
    'name': w.name,
    'cragId': w.cragId,
    'lat': w.lat,
    'lon': w.lon,
    'views': [
      for (final v in w.views)
        {'key': v.key, 'width': v.width, 'height': v.height, 'h': v.h},
    ],
    'routes': [
      for (final r in w.routes)
        {
          'id': r.id,
          'name': r.name,
          'grade': {'scale': r.scale.name, 'grade': r.grade},
          'bolts': [
            for (final (x, y) in r.bolts) [x, y],
          ],
          'addedBy': r.addedBy,
        },
    ],
  };

  /// Saved as the server would: through its JSON.
  Wall _saveWall(Wall w) {
    final saved = Wall.fromJson(
      jsonDecode(jsonEncode(_wallJson(w))) as Map<String, Object?>,
    );
    allWalls.removeWhere((x) => x.id == w.id);
    allWalls.add(saved);
    return saved;
  }

  void _premium() {
    if (!myPremium.active && !admin) {
      throw const ApiException(403, 'premium only');
    }
  }

  Wall _wall(String id) => allWalls.firstWhere(
    (w) => w.id == id,
    orElse: () => throw const ApiException(404, 'no such wall'),
  );

  @override
  Future<List<Wall>> walls(double lat, double lon) =>
      _route('GET /api/walls', () {
        _premium();
        return [
          for (final w in allWalls)
            if ((w.lat - lat).abs() < 0.03 && (w.lon - lon).abs() < 0.03) w,
        ];
      });

  @override
  Future<PhotoUpload> newWallPhoto(String contentType) =>
      _route('POST /api/walls/photo', () {
        _premium();
        final key = 'walls/me/wall-${++_ids}.jpg';
        return PhotoUpload(
          key: key,
          url: Uri.parse('https://bucket.test/'),
          fields: {'key': key},
          contentType: contentType,
        );
      });

  @override
  Future<Wall> createWall({
    required String name,
    required double lat,
    required double lon,
    String? cragId,
    required String key,
    required int width,
    required int height,
  }) => _route('POST /api/walls', () {
    _premium();
    if (!uploads.containsKey(key)) {
      throw const ApiException(400, "The photo isn't uploaded.");
    }
    return _saveWall(
      Wall(
        id: _id('wall'),
        name: name,
        cragId: cragId,
        lat: lat,
        lon: lon,
        views: [
          WallView(
            key: key,
            width: width,
            height: height,
            h: const [1, 0, 0, 0, 1, 0, 0, 0, 1],
          ),
        ],
        routes: const [],
      ),
    );
  });

  @override
  Future<Wall> addRoute(
    String wallId, {
    required String name,
    required GradeScale scale,
    required int grade,
    required List<(double, double)> bolts,
  }) => _route('POST /api/walls/$wallId/routes', () {
    _premium();
    final w = _wall(wallId);
    return _saveWall(
      Wall(
        id: w.id,
        name: w.name,
        cragId: w.cragId,
        lat: w.lat,
        lon: w.lon,
        views: w.views,
        routes: [
          ...w.routes,
          ClimbRoute(
            id: _id('route'),
            name: name,
            scale: scale,
            grade: grade,
            bolts: bolts,
            addedBy: meId!,
          ),
        ],
      ),
    );
  });

  @override
  Future<Wall> deleteRoute(String wallId, String routeId) =>
      _route('DELETE /api/walls/$wallId/routes/$routeId', () {
        _premium();
        final w = _wall(wallId);
        return _saveWall(
          Wall(
            id: w.id,
            name: w.name,
            cragId: w.cragId,
            lat: w.lat,
            lon: w.lon,
            views: w.views,
            routes: [
              for (final r in w.routes)
                if (r.id != routeId) r,
            ],
          ),
        );
      });

  @override
  Future<Wall> addWallView(
    String wallId, {
    required String key,
    required int width,
    required int height,
    required List<double> h,
  }) => _route('POST /api/walls/$wallId/views', () {
    _premium();
    final w = _wall(wallId);
    return _saveWall(
      Wall(
        id: w.id,
        name: w.name,
        cragId: w.cragId,
        lat: w.lat,
        lon: w.lon,
        views: [
          ...w.views,
          WallView(key: key, width: width, height: height, h: h),
        ],
        routes: w.routes,
      ),
    );
  });

  /// What `GET /api/realtime` answers: null, live updates off.
  RealtimeInfo? realtimeInfo;

  @override
  Future<RealtimeInfo?> realtime() =>
      _route('GET /api/realtime', () => realtimeInfo);

  @override
  Future<Me> me() => _route('GET /api/me', () {
    // Like the API: the first load makes my profile from my Google name.
    if (meId == null) {
      meId = 'me';
      climbers['me'] = Climber(id: 'me', name: googleName);
    }
    return Me(
      climber: climbers[meId],
      admin: admin,
      roles: roles,
      premium: myPremium,
    );
  });

  @override
  Future<PremiumOffer> premium() => _route(
    'GET /api/premium',
    () => PremiumOffer(
      myPremium,
      premiumPrices,
      appleAccountToken: appleAccountToken,
    ),
  );

  /// The appAccountToken `GET /api/premium` gives; null: no App Store
  /// purchases on this stage.
  String? appleAccountToken = '0c1e5f3a-9d2b-8c4e-a1f0-5b6d7e8f9a0b';

  /// The signed transactions the app sent, as [FakeAppStore] makes them:
  /// `jws|<product id>|<account token>`.
  final appleTransactions = <String>[];

  @override
  Future<PremiumOffer> premiumApple(String signedTransaction) =>
      _route('POST /api/premium/apple', () {
        appleTransactions.add(signedTransaction);
        final parts = signedTransaction.split('|');
        if (parts.length != 3 || parts[0] != 'jws') {
          throw const ApiException(400, 'bad signature');
        }
        if (parts[2] != appleAccountToken) {
          throw const ApiException(
            409,
            'this App Store purchase was made from another Grigri account',
          );
        }
        myPremium = Premium(
          active: true,
          plan: parts[1].endsWith('.yearly')
              ? PremiumPlan.yearly
              : PremiumPlan.monthly,
          until: DateTime(2031, 5, 1),
          source: PremiumSource.apple,
        );
        return PremiumOffer(
          myPremium,
          premiumPrices,
          appleAccountToken: appleAccountToken,
        );
      });

  @override
  Future<Uri> premiumCheckout(PremiumPlan plan) =>
      _route('POST /api/premium/checkout', () {
        if (premiumPrices.isEmpty) {
          throw const ApiException(503, "Premium isn't available yet");
        }
        if (myPremium.active) {
          throw const ApiException(409, "you're already Premium");
        }
        return Uri.parse('https://checkout.stripe.test/${plan.name}');
      });

  @override
  Future<Uri> premiumPortal() => _route('POST /api/premium/portal', () {
    if (!myPremium.active) throw const ApiException(404, 'no subscription');
    return Uri.parse('https://billing.stripe.test/portal');
  });

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

  @override
  Future<void> deleteAccount() async {
    final token = headers == null ? null : await _caller();
    await _route('DELETE /api/me', () {
      final id = meId;
      if (id != null) {
        // Like the API: out of every plan (the last one out ends it), my
        // requests withdrawn, my profile gone.
        for (final p in plans.values.toList()) {
          if (!p.memberIds.contains(id)) continue;
          final rest = [...p.memberIds]..remove(id);
          if (rest.isEmpty) {
            plans.remove(p.id);
          } else {
            plans[p.id] = p.copyWith(
              memberIds: rest,
              organizerId: p.organizerId == id ? rest.first : p.organizerId,
            );
          }
        }
        requestsById.removeWhere((_, r) => r.climberId == id);
        climbers.remove(id);
        meId = null;
      }
      // Signed out everywhere.
      if (token != null) {
        final email = sessions[token];
        sessions.removeWhere((_, owner) => owner == email);
      }
    });
  }

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
                  !p.hasStarted(now) &&
                  !p.memberIds.contains(meId) &&
                  !passed.contains(p.id) &&
                  !requestsById.containsKey('${p.id}/$meId') &&
                  !dismissed.contains(p.id) &&
                  !p.memberIds.any(personBlocks.contains),
            )
            .toList()
          ..sort((a, b) {
            final fit = (_fits(b) ? 1 : 0).compareTo(_fits(a) ? 1 : 0);
            return fit != 0
                ? fit
                : (a.start ?? DateTime(9999)).compareTo(
                    b.start ?? DateTime(9999),
                  );
          });
    return PlanList(
      list,
      _mention([
        ...list.expand(_planPeople),
        for (final a in ads.values) a.ownerId,
      ]),
      distanceKm: {for (final p in list) p.id: ?distanceKm[p.id]},
      covers: {for (final p in list) p.id: ?covers[p.id]},
      // As the API: admins' decks only.
      scores: admin
          ? {for (final p in list) p.id: ?matchScores[p.id]}
          : const {},
      // As the API: approved, not mine; none when they're off.
      ads: adEvery == 0
          ? const []
          : [
              for (final a in ads.values)
                if (a.status == AdStatus.approved &&
                    a.ownerId != meId &&
                    !skippedAds.contains(a.id))
                  a,
            ],
      adEvery: adEvery,
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
      moreDays: plan.moreDays,
      grades: plan.grades,
      memberIds: [meId!],
      notes: plan.notes,
      type: plan.type,
      price: plan.type == PlanType.guided ? plan.price : null,
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
      ..sort(
        (a, b) =>
            (a.start ?? DateTime(9999)).compareTo(b.start ?? DateTime(9999)),
      );
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
  Future<void> leave(
    String planId,
  ) => _route('POST /api/plans/$planId/leave', () {
    final p = plans[planId]!;
    final members = [...p.memberIds]..remove(meId);
    if (members.isEmpty) {
      plans.remove(planId);
      requestsById.removeWhere((_, r) => r.planId == planId);
    } else {
      // The API picks the new organizer at random; here, the first.
      final organizerId = p.organizerId == meId ? members.first : p.organizerId;
      plans[planId] = p.copyWith(organizerId: organizerId, memberIds: members);
      _note(
        planId,
        organizerId == p.organizerId
            ? '${climbers[meId]!.name} left the plan'
            : '${climbers[meId]!.name} left the plan; '
                  '${climbers[organizerId]!.name} organizes it now',
      );
    }
    passed.add(planId);
    left.add(planId);
  });

  @override
  Future<JoinRequest> join(String planId) =>
      _route('POST /api/plans/$planId/join', () {
        if (requestsById.containsKey('$planId/$meId')) {
          throw const ApiException(409, 'You already asked.');
        }
        ask(planId, meId!);
        final request = requestsById['$planId/$meId']!;
        // A demo plan's group says yes at once, and an open plan lets me
        // in (specs/matching.md).
        if (plans[planId]!.demo) {
          final accepted = request.copyWith(
            acceptedBy: plans[planId]!.memberIds.toSet(),
          );
          _settle(request.id, force: true);
          return accepted;
        }
        if (plans[planId]!.type == PlanType.open) {
          _settle(request.id);
          return request;
        }
        return request;
      });

  @override
  Future<({JoinRequest request, int nudged})> nudge(String planId) =>
      _route('POST /api/plans/$planId/nudge', () {
        final nudged = nudgeAs(planId, meId!);
        return (request: requestsById['$planId/$meId']!, nudged: nudged);
      });

  @override
  Future<void> pass(String planId) =>
      _route('POST /api/plans/$planId/pass', () => passed.add(planId));

  @override
  Future<void> clearPasses() => _route('DELETE /api/passes', () {
    // Not the ones I asked to join (a dismissed "no" stays hidden).
    passed.removeWhere(
      (p) => !requestsById.containsKey('$p/$meId') && !left.contains(p),
    );
  });

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
  Future<Message> send(String planId, String text, {String? attachment}) =>
      _route('POST /api/plans/$planId/messages', () {
        _member(planId);
        if (attachment != null && !uploads.containsKey(attachment)) {
          throw const ApiException(400, "The attachment isn't uploaded.");
        }
        final m = Message(
          id: _id('m'),
          planId: planId,
          authorId: meId,
          text: text,
          time: _now(),
          attachment: attachment == null
              ? null
              : Attachment(
                  key: attachment,
                  kind:
                      attachment.endsWith('.mp4') || attachment.endsWith('.mov')
                      ? MediaKind.video
                      : MediaKind.image,
                ),
        );
        allMessages.add(m);
        // A chat photo joins the plan's "Your Pics", as the server does.
        if (m.attachment?.kind == MediaKind.image) {
          allPics.add(
            PlanPic(
              id: _id('pic'),
              planId: planId,
              key: attachment!,
              uploaderId: meId!,
              time: m.time,
              fromChat: true,
            ),
          );
        }
        return m;
      });

  @override
  Future<PlanPicsList> planPics(String planId) =>
      _route('GET /api/plans/$planId/pics', () {
        if (!plans.containsKey(planId)) {
          throw const ApiException(404, 'No such plan.');
        }
        final member = plans[planId]!.memberIds.contains(meId);
        final yours = [
          if (member)
            for (final p in allPics)
              if (p.planId == planId) p,
        ];
        return PlanPicsList(
          PlanPics(
            yours: yours,
            grigri: grigriPics[planId] ?? const [],
            member: member,
          ),
          _mention([for (final p in yours) p.uploaderId]),
        );
      });

  @override
  Future<PhotoUpload> newPlanPic(String planId, String contentType) =>
      _route('POST /api/plans/$planId/pics/upload', () {
        _member(planId);
        final key = 'plans/$planId/pic-${++_ids}.jpg';
        return PhotoUpload(
          key: key,
          url: Uri.parse('https://bucket.test/'),
          fields: {'key': key, 'policy': 'made-up'},
          contentType: contentType,
        );
      });

  @override
  Future<PlanPic> addPlanPic(String planId, String key) =>
      _route('POST /api/plans/$planId/pics', () {
        _member(planId);
        if (!uploads.containsKey(key)) {
          throw const ApiException(400, "The photo isn't uploaded.");
        }
        final pic = PlanPic(
          id: _id('pic'),
          planId: planId,
          key: key,
          uploaderId: meId!,
          time: _now(),
        );
        allPics.add(pic);
        return pic;
      });

  @override
  Future<void> deletePlanPic(String planId, String picId) =>
      _route('DELETE /api/plans/$planId/pics/$picId', () {
        _member(planId);
        final pic = allPics.where((p) => p.id == picId).firstOrNull;
        if (pic == null) throw const ApiException(404, 'No such photo.');
        if (pic.uploaderId != meId && plans[planId]!.organizerId != meId) {
          throw const ApiException(403, 'Only whoever added it.');
        }
        allPics.remove(pic);
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
  Future<PhotoUpload> newChatMedia(String planId, String contentType) =>
      _route('POST /api/plans/$planId/media', () {
        _member(planId);
        const ext = {
          'image/jpeg': 'jpg',
          'image/png': 'png',
          'image/webp': 'webp',
          'video/mp4': 'mp4',
          'video/quicktime': 'mov',
        };
        final key = 'chat/$planId/media-${++_ids}.${ext[contentType]}';
        return PhotoUpload(
          key: key,
          url: Uri.parse('https://bucket.test/'),
          fields: {'key': key, 'policy': 'made-up'},
          contentType: contentType,
        );
      });

  /// What uploads reported as they went (0 to 1).
  final progress = <double>[];

  @override
  Future<void> uploadPhoto(
    PhotoUpload upload,
    Uint8List bytes, {
    void Function(double sent)? onProgress,
  }) async {
    calls.add('POST ${upload.url} (${upload.fields['key']})');
    for (final p in [0.5, 1.0]) {
      progress.add(p);
      onProgress?.call(p);
    }
    uploads[upload.key] = bytes;
  }

  void _admin() {
    if (!admin) throw const ApiException(403, 'Admins only.');
  }

  @override
  Future<MyAds> myAds() => _route(
    'GET /api/ads',
    () => MyAds([
      for (final a in ads.values.toList().reversed)
        if (a.ownerId == meId) a,
    ], premium: myPremium.active),
  );

  @override
  Future<PhotoUpload> newAdMedia(String contentType) =>
      _route('POST /api/ads/media', () {
        if (!myPremium.active) {
          throw const ApiException(403, 'ads are for Premium');
        }
        final ext = contentType.split('/').last;
        return PhotoUpload(
          key: 'ads/$meId/upload${++_adIds}.$ext',
          url: Uri.parse('https://upload.grigri.test/'),
          fields: const {},
          contentType: contentType,
        );
      });

  @override
  Future<Ad> createAd({
    required String text,
    required String link,
    String? mediaKey,
    List<AdRegion> regions = const [],
  }) => _route('POST /api/ads', () {
    if (!myPremium.active) throw const ApiException(403, 'ads are for Premium');
    final url = Uri.tryParse(link);
    if (url == null || !url.hasAuthority || !url.scheme.startsWith('http')) {
      throw const ApiException(400, 'link must be a web address (https://…)');
    }
    final ad = Ad(
      id: 'ad${++_adIds}',
      ownerId: meId!,
      text: text,
      link: url,
      mediaKey: mediaKey,
      regions: regions,
      mediaKind: mediaKey == null
          ? null
          : (mediaKey.endsWith('.mp4') || mediaKey.endsWith('.quicktime')
                ? MediaKind.video
                : MediaKind.image),
    );
    ads[ad.id] = ad;
    return ad;
  });

  /// What GET /api/places finds, by query.
  final Map<String, List<AdRegion>> places = {};

  @override
  Future<List<AdRegion>> searchPlaces(String query, String language) =>
      _route('GET /api/places', () {
        if (!myPremium.active) {
          throw const ApiException(403, 'ads are for Premium');
        }
        return places[query] ?? const [];
      });

  @override
  Future<void> deleteAd(String adId) => _route('DELETE /api/ads/$adId', () {
    ads.remove(adId);
  });

  /// Ads I skipped: never on my deck again.
  final skippedAds = <String>{};

  @override
  Future<void> skipAd(String adId) => _route('POST /api/ads/$adId/skip', () {
    skippedAds.add(adId);
  });

  @override
  Future<AdminAds> adminAds(AdStatus status) =>
      _route('GET /api/admin/ads?status=${status.name}', () {
        _admin();
        final list = [
          for (final a in ads.values.toList().reversed)
            if (a.status == status) a,
        ];
        return AdminAds(list, {
          for (final a in list) a.ownerId: ?climbers[a.ownerId],
        }, every: adEvery);
      });

  @override
  Future<Ad> reviewAd(String adId, {required bool approve}) =>
      _route('POST /api/admin/ads/$adId/${approve ? 'approve' : 'reject'}', () {
        _admin();
        final ad = ads[adId];
        if (ad == null) throw const ApiException(404, 'no such ad');
        return ads[adId] = ad.copyWith(
          status: approve ? AdStatus.approved : AdStatus.rejected,
        );
      });

  @override
  Future<void> setAdEvery(int every) =>
      _route('PUT /api/admin/ads/settings', () {
        _admin();
        adEvery = every;
      });

  @override
  Future<List<AdminClimber>> adminClimbers() =>
      _route('GET /api/admin/climbers', () {
        _admin();
        final everyone = climbers.values.toList()
          ..sort((a, b) => a.name.compareTo(b.name));
        return [
          for (final c in everyone)
            AdminClimber(
              c.copyWith(location: null, areas: const []),
              blocked: blocked.contains(c.id),
            ),
        ];
      });

  @override
  Future<void> setBlocked(String climberId, bool block) => _route(
    'POST /api/admin/climbers/$climberId/${block ? 'block' : 'unblock'}',
    () {
      _admin();
      if (block && climberId == meId) {
        throw const ApiException(400, "you can't block yourself");
      }
      if (!climbers.containsKey(climberId)) {
        throw const ApiException(404, 'no such climber');
      }
      block ? blocked.add(climberId) : blocked.remove(climberId);
    },
  );

  @override
  Future<void> sendReport({
    required ReportKind kind,
    required String targetId,
    String? planId,
    required ReportReason reason,
    String text = '',
  }) => _route('POST /api/reports', () {
    final subjectId = switch (kind) {
      ReportKind.profile => targetId,
      ReportKind.plan => plans[targetId]?.organizerId,
      ReportKind.message =>
        allMessages.where((m) => m.id == targetId).firstOrNull?.authorId,
      ReportKind.pic =>
        allPics.where((p) => p.id == targetId).firstOrNull?.uploaderId,
      ReportKind.ad => ads[targetId]?.ownerId,
    };
    if (subjectId == null) throw const ApiException(404, 'not found');
    if (subjectId == meId) {
      throw const ApiException(400, "you can't report your own");
    }
    reports.add(
      Report(
        id: 'report-${++_reportIds}',
        kind: kind,
        targetId: targetId,
        planId: planId,
        subjectId: subjectId,
        reporterId: meId!,
        reason: reason,
        text: text,
        time: _now(),
      ),
    );
  });

  @override
  Future<AdminReports> adminReports() => _route('GET /api/admin/reports', () {
    _admin();
    return AdminReports(
      [...reports],
      _mention([
        for (final r in reports) ...[r.subjectId, r.reporterId],
      ]),
    );
  });

  @override
  Future<void> resolveReport(String reportId, ReportAction action) =>
      _route('POST /api/admin/reports/$reportId/${action.name}', () {
        _admin();
        final report = reports.where((r) => r.id == reportId).firstOrNull;
        if (report == null) throw const ApiException(404, 'no such report');
        reports.remove(report);
        resolved.add('$reportId ${action.name}');
        if (action == ReportAction.block) blocked.add(report.subjectId);
      });

  @override
  Future<BlockList> blocks() => _route(
    'GET /api/blocks',
    () => BlockList([...personBlocks], _mention(personBlocks)),
  );

  @override
  Future<void> setPersonBlocked(String climberId, bool block) =>
      _route('${block ? 'POST' : 'DELETE'} /api/blocks/$climberId', () {
        if (block && climberId == meId) {
          throw const ApiException(400, "you can't block yourself");
        }
        if (!climbers.containsKey(climberId)) {
          throw const ApiException(404, 'no such climber');
        }
        if (!block) {
          personBlocks.remove(climberId);
          return;
        }
        personBlocks.add(climberId);
        // As the server: their open requests on plans I decide on are declined.
        for (final r in requestsById.values.toList()) {
          if (r.climberId == climberId &&
              !r.rejected &&
              (plans[r.planId]?.deciders.contains(meId) ?? false)) {
            _reject(r.id);
          }
        }
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
  Future<void> signIn() async => _onCredential?.call(
    const Credential(
      user: AuthUser(email: 'pat@example.com', name: 'Pat Quill'),
      idToken: 'google-id-token',
    ),
  );

  @override
  Future<void> signOut() async => signOuts++;
}

/// Sign in with Apple, made up: [next] is what Apple's sheet answers
/// (null: cancelled), or [error] when set.
class FakeApple implements AppleSignIn {
  FakeApple({this.available = true});

  @override
  final bool available;

  AppleCredential? next = const AppleCredential(
    user: AuthUser(name: 'Pat Quill'),
    idToken: 'apple-id-token',
    nonce: 'made-up-nonce-0123456789',
    authorizationCode: 'made-up-code',
  );
  Object? error;
  int sheets = 0;

  @override
  Future<AppleCredential?> signIn() async {
    sheets++;
    if (error case final e?) throw e;
    return next;
  }
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
/// the device, or the one in [storage]. Signs in with [FakeGoogle]. Live
/// updates over [realtime] when given.
GrigriStore storeFor(
  FakeApi api, {
  bool signedIn = true,
  SignInMode mode = SignInMode.google,
  MemorySessionStorage? storage,
  AppleSignIn? apple,
  Preferences? preferences,
  RealtimeTransport? realtime,
  DeviceLocation deviceLocation = const DeviceLocation.none(),
  math.Random? random,
  AppStore? appStore,
  ImageProvider Function(Uri url)? image,
}) {
  final auth = SessionAuth(
    method: FakeGoogle(mode: mode),
    apple: apple,
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
    openLink: (url) async {
      api.opened.add(url);
      return true;
    },
    auth: auth,
    image: image ?? (_) => MemoryImage(png),
    preferences: preferences,
    realtime: realtime,
    deviceLocation: deviceLocation,
    places: () async => fakePlaces,
    random: random,
    appStore: appStore,
  );
}

/// The App Store, faked (no StoreKit): its products at made-up localized
/// prices, and purchases reported at once (a synchronous stream), as
/// signed transactions `jws|<product id>|<account token>`.
class FakeAppStore implements AppStore {
  FakeAppStore({
    this.prices = const {
      PremiumPlan.monthly: '\$19.99',
      PremiumPlan.yearly: '\$199.99',
    },
  });

  /// The products' prices; empty: the App Store can't sell them.
  Map<PremiumPlan, String> prices;

  /// What buying ends in, as StoreKit reports it.
  StorePurchaseStatus outcome = StorePurchaseStatus.purchased;

  /// What was bought, as "`product id` for `account token`".
  final bought = <String>[];

  /// The purchases finished.
  final completed = <StorePurchase>[];

  /// My current subscriptions, which Restore purchases reports.
  List<StorePurchase> owned = [];

  final _purchases = StreamController<List<StorePurchase>>.broadcast(
    sync: true,
  );

  /// Reports purchases, as StoreKit does at launch or on a renewal.
  void report(List<StorePurchase> purchases) => _purchases.add(purchases);

  @override
  Stream<List<StorePurchase>> get purchases => _purchases.stream;

  @override
  Future<Map<PremiumPlan, StoreProduct>> products() async => {
    for (final MapEntry(key: plan, value: price) in prices.entries)
      plan: StoreProduct(
        id: appStoreProductIds[plan]!,
        plan: plan,
        price: price,
      ),
  };

  @override
  Future<bool> buy(StoreProduct product, {required String accountToken}) async {
    bought.add('${product.id} for $accountToken');
    report([
      StorePurchase(
        productId: product.id,
        status: outcome,
        signedTransaction: 'jws|${product.id}|$accountToken',
        needsCompleting: outcome == StorePurchaseStatus.purchased,
      ),
    ]);
    return true;
  }

  @override
  Future<void> restore() async {
    if (owned.isNotEmpty) report(owned);
  }

  @override
  Future<void> complete(StorePurchase purchase) async =>
      completed.add(purchase);
}

/// The sector index the store names a device's location from: made-up
/// places.
final fakePlaces = SectorIndex(const [
  Sector(
    id: 'osm:n1',
    name: 'Pared Gris',
    area: 'Valle Alto',
    country: 'Spain',
    lat: 41.5,
    lon: 1.0,
  ),
  Sector(id: 'osm:n2', name: 'Roca Fosca', country: 'France', lat: 45, lon: 6),
]);

/// A device that says it's at [here] (null: it can't tell), counting how
/// often it was asked.
class FakeDeviceLocation extends DeviceLocation {
  FakeDeviceLocation(this.here);

  final ({double lat, double lon})? here;
  int asked = 0;

  @override
  Future<({double lat, double lon})?> current() async {
    asked++;
    return here;
  }
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
