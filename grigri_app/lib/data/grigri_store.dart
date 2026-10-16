import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../l10n/app_localizations.dart';
import '../model/climber.dart';
import '../model/climbing.dart';
import '../model/location.dart';
import '../model/match_score.dart';
import '../model/plan.dart';
import '../model/sector.dart';
import 'api.dart';
import 'auth.dart';
import 'device_location.dart';
import 'preferences.dart';
import 'realtime.dart';
import 'sector_index.dart';

/// A newcomer joined a plan I'm in, or I joined one: the match screen
/// shows it.
class Match {
  const Match({required this.plan, required this.newcomer});

  final Plan plan;
  final Climber newcomer;
}

/// Where the app is, from signing in to the tabs.
enum Phase {
  /// Checking whether someone is signed in.
  starting,

  /// The sign-in screen.
  signedOut,

  /// Signed in, loading my profile.
  loading,

  /// The tabs.
  ready,

  /// Signed in, but my profile couldn't be loaded: try again.
  failed,
}

/// The parts of the app's data that load separately.
enum Section { discover, plans, requests, notices, admin }

/// A photo or video picked for a chat message.
class ChatMedia {
  const ChatMedia(this.bytes, this.kind);

  final Uint8List bytes;
  final MediaKind kind;
}

/// A photo in the profile editor: one already saved ([key]), or one just
/// picked and not uploaded yet ([bytes]).
class EditablePhoto {
  const EditablePhoto.saved(String this.key) : bytes = null;
  const EditablePhoto.picked(Uint8List this.bytes) : key = null;

  final String? key;
  final Uint8List? bytes;
}

/// The app's data, a cache over the [GrigriApi]: the decks, my plans and
/// requests, notifications, chats, my profile, and (for admins) every open
/// request. Screens read it and call its actions; it refreshes from the
/// API when they ask, and on live updates' hints (see specs/matching.md,
/// Refreshing, and specs/live-updates.md).
class GrigriStore extends ChangeNotifier {
  GrigriStore({
    required this.api,
    required this.auth,
    ImageProvider Function(Uri url)? image,
    Preferences? preferences,
    RealtimeTransport? realtime,
    this.deviceLocation = const DeviceLocation.none(),
    Future<SectorIndex> Function()? places,
  }) : _image = image ?? ((url) => NetworkImage(url.toString())),
       _places = places ?? SectorIndex.load,
       _preferences = preferences ?? Preferences.none() {
    _gradeSystem = _preferences.gradeSystem;
    final language = _preferences.language;
    _language =
        AppLocalizations.supportedLocales.any((l) => l.languageCode == language)
        ? language
        : null;
    auth.addListener(_authChanged);
    if (realtime != null) {
      _live = Realtime(
        transport: realtime,
        info: () => _call(api.realtime),
        token: auth.sessionToken,
        onHint: (hint) => unawaited(handleHint(hint)),
        onReconnected: () => unawaited(_catchUp()),
      )..addListener(notifyListeners);
    }
  }

  /// Live updates (none without a transport: polling only).
  Realtime? _live;

  final GrigriApi api;
  final Auth auth;
  final ImageProvider Function(Uri url) _image;
  final Preferences _preferences;

  /// Where the phone or browser is, to fill in my location.
  final DeviceLocation deviceLocation;

  /// The sector index, to name a place the device found.
  final Future<SectorIndex> Function() _places;
  late GradeSystem _gradeSystem;

  /// How I like grades written, everywhere in the app; kept on the device.
  GradeSystem get gradeSystem => _gradeSystem;

  set gradeSystem(GradeSystem system) {
    _gradeSystem = system;
    notifyListeners();
    _preferences.setGradeSystem(system);
  }

  /// [range] written the way I like.
  String grades(GradeRange range) => range.label(_gradeSystem);

  String? _language;

  /// The language I picked for the app, kept on the device; null follows
  /// the device's language (English when the app doesn't speak it).
  Locale? get locale => _language == null ? null : Locale(_language!);

  set locale(Locale? locale) {
    _language = locale?.languageCode;
    notifyListeners();
    _preferences.setLanguage(_language);
  }

  /// The app's texts in the language it shows, for the messages the store
  /// words itself; the app sets it as the language resolves.
  AppLocalizations l10n = lookupAppLocalizations(const Locale('en'));

  /// What failed, in the server's words, or in the app's for the failures
  /// it describes itself.
  String _describe(ApiException e) => switch (e.client) {
    null => e.message,
    ClientError.timeout => l10n.errorTimeout,
    ClientError.unreachable => l10n.errorUnreachable,
    ClientError.failed => l10n.errorStatus(e.status),
    ClientError.photoTimeout => l10n.errorPhotoTimeout,
    ClientError.photoUnreachable => l10n.errorPhotoUnreachable,
    ClientError.photoFailed => l10n.errorPhotoStatus(e.status),
    ClientError.photoType => l10n.errorPhotoType,
    ClientError.mediaType => l10n.errorMediaType,
    ClientError.videoTooBig => l10n.errorVideoTooBig(maxVideoBytes >> 20),
  };

  Phase _phase = Phase.starting;
  Phase get phase => _phase;

  /// Why my profile couldn't be loaded ([Phase.failed]).
  String? loadError;

  Climber? _me;
  bool _admin = false;
  List<String>? _roles;
  bool _signedIn = false;

  final _climbers = <String, Climber>{};
  final _plans = <String, Plan>{};
  List<String> _discover = [];
  Map<String, int> _distanceKm = {};
  Map<String, MatchScore> _matchScores = {};
  List<String> _mine = [];
  List<JoinRequest> _asked = [];
  List<JoinRequest> _toReview = [];
  List<JoinRequest> _adminRequests = [];
  ScoreRun? _scoreRun;
  List<ScoredPair> _adminScores = [];
  final _open = <String, List<JoinRequest>>{};
  final _declinedHere = <String>{};
  List<Notice> _notices = [];
  final _messages = <String, List<Message>>{};
  final _gone = <String>{};
  final _loaded = <Section>{};
  final _loadingPlans = <String>{};

  /// Accepted notices already shown as a match.
  final _announced = <String>{};

  final _errors = StreamController<String>.broadcast();
  final _matches = StreamController<Match>.broadcast();

  /// Messages to show at the bottom of the screen: what failed, in the
  /// server's words.
  Stream<String> get errors => _errors.stream;

  /// Groups that accepted me, found while refreshing: the match screen
  /// shows them.
  Stream<Match> get matches => _matches.stream;

  // --- Session -----------------------------------------------------------

  /// Starts: signed in at once with a kept session.
  Future<void> start() async {
    if (!auth.started) await auth.start();
    _authChanged();
    await _loading;
  }

  /// Loading my profile, after signing in.
  Future<void>? _loading;

  /// Counts sign-ins and sign-outs, so answers for an earlier session are
  /// dropped.
  int _session = 0;

  void _authChanged() {
    if (!auth.started) return;
    final signedIn = auth.signedIn;
    if (signedIn == _signedIn && _phase != Phase.starting) return;
    _signedIn = signedIn;
    _clear();
    if (!signedIn) {
      _loading = null;
      _phase = Phase.signedOut;
      notifyListeners();
    } else {
      _loading = loadMe();
    }
  }

  void _clear() {
    _live?.stop();
    _session++;
    _me = null;
    _admin = false;
    _roles = null;
    _locating = false;
    _climbers.clear();
    _plans.clear();
    _discover = [];
    _distanceKm = {};
    _matchScores = {};
    _mine = [];
    _asked = [];
    _toReview = [];
    _adminRequests = [];
    _scoreRun = null;
    _adminScores = [];
    _open.clear();
    _declinedHere.clear();
    _notices = [];
    _messages.clear();
    _gone.clear();
    _loaded.clear();
    _loadingPlans.clear();
    _announced.clear();
  }

  /// Loads my profile (`GET /api/me`, which creates it from my Google
  /// account the first time), then everything else.
  Future<void> loadMe() async {
    _phase = Phase.loading;
    loadError = null;
    notifyListeners();
    try {
      final me = await _call(api.me);
      final climber = me.climber;
      if (climber == null) throw const ApiException(409, 'no profile');
      _admin = me.admin;
      _roles = me.roles;
      _me = climber;
      _climbers[climber.id] = climber;
      _phase = Phase.ready;
      notifyListeners();
      unawaited(fillLocation());
      await refreshAll();
    } on ApiException catch (e) {
      if (_phase == Phase.signedOut || e.status == _stale) return;
      loadError = _describe(e);
      _phase = Phase.failed;
      notifyListeners();
    }
  }

  /// Signs out here (`DELETE /api/session`).
  Future<void> signOut() => auth.signOut();

  /// Signs out on every device (`DELETE /api/sessions`); says so when the
  /// API couldn't be told.
  Future<void> signOutEverywhere() async {
    if (!await auth.signOutEverywhere()) {
      _errors.add(l10n.errorSignOutEverywhere);
    }
  }

  // --- Reading -----------------------------------------------------------

  bool get admin => _admin;

  /// My roles in Grigri, from rbacr through the API, sorted; null when
  /// rbacr couldn't say.
  List<String>? get roles => _roles;

  /// Asks the API for my roles (and whether I'm an admin) again.
  Future<void> refreshRoles() async {
    final session = _session;
    try {
      final me = await _call(api.me);
      if (session != _session) return;
      _roles = me.roles;
      _admin = me.admin;
      notifyListeners();
    } on ApiException {
      // The card keeps offering Retry.
    }
  }

  /// My profile (a blank one until it's loaded, so screens on their way
  /// out after a sign-out still build).
  Climber get me => _me ?? const Climber(id: '', name: '');

  /// Someone, as far as the app knows them.
  Climber climber(String id) =>
      _climbers[id] ?? Climber(id: id, name: l10n.someone);

  Plan? plan(String id) => _plans[id];

  /// Whether a plan turned out not to exist (anymore) or to be off limits.
  bool isGone(String planId) => _gone.contains(planId);

  bool isLoadingPlan(String planId) => _loadingPlans.contains(planId);

  bool isLoaded(Section section) => _loaded.contains(section);

  /// A photo's image.
  ImageProvider photo(String key) => _image(api.photoUrl(key));

  /// Plans to swipe on, best fits first (the server's order).
  List<Plan> get discover => [for (final id in _discover) ?_plans[id]];

  /// How far a plan on the deck is from my nearest location or area, in
  /// km; null when it isn't known.
  int? distanceKm(String planId) => _distanceKm[planId];

  /// Admins only: how likely a plan on the deck ends in a match for me;
  /// null when the API didn't score it (or I'm not an admin).
  MatchScore? matchScore(String planId) => _matchScores[planId];

  /// Plans I'm in, soonest first.
  List<Plan> get myPlans => [for (final id in _mine) ?_plans[id]];

  /// My swipes right still waiting for members to decide.
  List<JoinRequest> get waiting => [
    for (final r in _asked)
      if (!r.rejected) r,
  ];

  /// My swipes right that a group turned down, until I dismiss them.
  List<JoinRequest> get declined => [
    for (final r in _asked)
      if (r.rejected) r,
  ];

  /// My request to join a plan, if I asked.
  JoinRequest? myRequest(String planId) =>
      _asked.where((r) => r.planId == planId).firstOrNull;

  /// People asking to join plans I'm in, that I haven't answered yet.
  List<JoinRequest> get toReview => _toReview;

  /// A plan's open requests, as far as the app knows (I see them when I'm
  /// in it).
  List<JoinRequest> openRequests(String planId) {
    final byId = <String, JoinRequest>{
      for (final r in _open[planId] ?? const <JoinRequest>[]) r.id: r,
      for (final r in _toReview)
        if (r.planId == planId) r.id: r,
    };
    return byId.values.toList();
  }

  /// Whether a plan's open requests have been loaded ([loadPlan]).
  bool knowsRequests(String planId) => _open.containsKey(planId);

  /// A join request, by [JoinRequest.id], while it's open (or mine).
  JoinRequest? request(String id) => [
    ..._toReview,
    for (final list in _open.values) ...list,
    ..._asked,
    ..._adminRequests,
  ].where((r) => r.id == id).firstOrNull;

  /// Whether I turned this request down (in this session).
  bool declinedHere(String requestId) => _declinedHere.contains(requestId);

  /// Every open request (admins).
  List<JoinRequest> get adminRequests => _adminRequests;

  /// The latest match scoring run (admins); null: never run, or not
  /// loaded.
  ScoreRun? get scoreRun => _scoreRun;

  /// Its best scores, best first (admins).
  List<ScoredPair> get adminScores => _adminScores;

  /// My notifications, newest first.
  List<Notice> get notices => _notices;

  int get unreadNotices => _notices.where((n) => !n.read).length;

  /// A plan's group chat, oldest first.
  List<Message> messages(String planId) => _messages[planId] ?? const [];

  /// Why a plan suits me.
  Fit fit(Plan plan) {
    final level = _me?.levels[plan.discipline];
    return Fit(grades: level != null && level.overlaps(plan.grades));
  }

  // --- Calling the API ---------------------------------------------------

  /// Calls the API; a 401 (the session ended) signs out. A 409 "no
  /// profile" goes back to creating one.
  Future<T> _call<T>(Future<T> Function() call) async {
    final session = _session;
    try {
      final result = await call();
      if (session != _session) throw const ApiException(_stale, 'stale');
      return result;
    } on ApiException catch (e) {
      if (e.status == _stale || session != _session) {
        throw const ApiException(_stale, 'stale');
      }
      if (e.status == 401) {
        _errors.add(l10n.errorSignedOut);
        // Auth notifies, and _authChanged clears everything.
        await auth.signedOut();
        rethrow;
      }
      // My profile went missing: loading it again makes a new one.
      if (e.noProfile && _phase == Phase.ready) unawaited(loadMe());
      rethrow;
    }
  }

  /// The status of an answer that came after a sign-out: dropped quietly.
  static const _stale = -1;

  /// Runs an action: its error, in the server's words, goes to [errors].
  Future<T?> _act<T>(Future<T> Function() call) async {
    try {
      return await _call(call);
    } on ApiException catch (e) {
      if (e.status != 401 && e.status != _stale) _errors.add(_describe(e));
      return null;
    }
  }

  /// Runs an action that answers nothing: true when it worked.
  Future<bool> _ok(Future<void> Function() call) async =>
      await _act(() async {
        await call();
        return true;
      }) ??
      false;

  /// Runs a refresh: [fetch], then [apply] its answer (unless it came
  /// after a sign-out). Quiet when it fails: the next one tries again.
  Future<bool> _refresh<T>(
    Future<T> Function() fetch,
    void Function(T answer) apply,
  ) async {
    if (_phase != Phase.ready) return false;
    try {
      apply(await _call(fetch));
      notifyListeners();
      return true;
    } on ApiException {
      return false;
    }
  }

  void _learn(Map<String, Climber> climbers) {
    _climbers.addAll(climbers);
    final me = _me == null ? null : climbers[_me!.id];
    // Others' copies of my profile come without my location and areas
    // (they're private): keep mine.
    if (me != null) {
      _me = me.copyWith(location: _me!.location, areas: _me!.areas);
      _climbers[me.id] = _me!;
    }
  }

  // --- Live updates ------------------------------------------------------

  /// Whether a live connection is up: polling slows down meanwhile.
  bool get live => _live?.connected ?? false;

  /// Live updates on: while the tabs are on screen and the app is in the
  /// foreground (HomeShell says when).
  void goLive() {
    if (_phase == Phase.ready) _live?.start();
  }

  /// Live updates off: in the background, or leaving the tabs.
  void goQuiet() => _live?.stop();

  /// A hint: refetches just what it names, through the API.
  Future<void> handleHint(Hint hint) async {
    if (_phase != Phase.ready) return;
    final planId = hint.planId;
    final chat = planId != null && _messages.containsKey(planId);
    final open = planId != null && _open.containsKey(planId);
    switch (hint.kind) {
      case HintKind.message:
        if (planId != null && (chat || _mine.contains(planId))) {
          await pollMessages(planId);
        }
      case HintKind.request:
        await Future.wait([
          refreshRequests(),
          refreshNotices(),
          if (chat) pollMessages(planId),
          if (open) loadPlan(planId),
        ]);
      case HintKind.notice:
        await Future.wait([refreshNotices(), refreshPlans()]);
      case HintKind.plan:
        await Future.wait([
          refreshPlans(),
          refreshRequests(),
          if (chat) pollMessages(planId),
          if (open) loadPlan(planId),
        ]);
      case HintKind.match || HintKind.unknown:
        await Future.wait([
          refreshPlans(),
          refreshRequests(),
          refreshNotices(),
        ]);
    }
  }

  /// Back online after a drop: what hints may have said meanwhile.
  Future<void> _catchUp() async {
    if (_phase != Phase.ready) return;
    await Future.wait([
      refreshPlans(),
      refreshRequests(),
      refreshNotices(),
      for (final id in _messages.keys.toList()) pollMessages(id),
    ]);
  }

  // --- Refreshing --------------------------------------------------------

  /// My plans, my requests, the requests waiting for me, notifications and
  /// the deck; for admins, every open request too.
  Future<void> refreshAll() async {
    await Future.wait([
      refreshPlans(),
      refreshRequests(),
      refreshDiscover(),
      if (_admin) refreshAdmin(),
    ]);
    await refreshNotices();
  }

  /// The deck again, with [again] the plans I passed on too (Discover's
  /// refresh button: I may have changed my mind).
  Future<void> refreshDiscover({bool again = false}) async {
    if (again) await _ok(api.clearPasses);
    await _refreshDeck();
  }

  Future<void> _refreshDeck() => _refresh(api.discover, (list) {
    _learn(list.climbers);
    for (final p in list.plans) {
      _plans[p.id] = p;
    }
    _discover = [for (final p in list.plans) p.id];
    _distanceKm = list.distanceKm;
    _matchScores = list.scores;
    _loaded.add(Section.discover);
  });

  Future<void> refreshPlans() => _refresh(api.myPlans, (mine) {
    _learn(mine.climbers);
    for (final p in mine.plans) {
      _plans[p.id] = p;
      _gone.remove(p.id);
    }
    for (final a in mine.asked) {
      _plans[a.plan.id] = a.plan;
    }
    _mine = [for (final p in mine.plans) p.id];
    _asked = [for (final a in mine.asked) a.request];
    _loaded.add(Section.plans);
  });

  Future<void> refreshRequests() => _refresh(api.requests, (list) {
    _learn(list.climbers);
    _plans.addAll(list.plans);
    _toReview = list.requests;
    _loaded.add(Section.requests);
  });

  /// Notifications; a group's yes I haven't seen yet opens the match
  /// screen.
  Future<void> refreshNotices() async {
    final fresh = <Notice>[];
    final ok = await _refresh(api.notices, (list) {
      _learn(list.climbers);
      _notices = [...list.notices]..sort((a, b) => b.time.compareTo(a.time));
      _loaded.add(Section.notices);
      fresh.addAll([
        for (final n in _notices)
          if (n.kind == NoticeKind.accepted &&
              !n.read &&
              !_announced.contains(n.id))
            n,
      ]);
      _announced.addAll(fresh.map((n) => n.id));
    });
    if (!ok || fresh.isEmpty) return;
    if (fresh.any((n) => !_mine.contains(n.planId))) await refreshPlans();
    final me = _me;
    if (me == null) return;
    for (final n in fresh.reversed) {
      final plan = _plans[n.planId];
      if (plan != null && plan.memberIds.contains(me.id)) {
        _matches.add(Match(plan: plan, newcomer: me));
      }
    }
  }

  /// Every open request, and the match scores' preview (admins).
  Future<void> refreshAdmin() async {
    if (!_admin) return;
    await Future.wait([
      _refresh(api.adminRequests, (list) {
        _learn(list.climbers);
        _plans.addAll(list.plans);
        _adminRequests = list.requests;
        _loaded.add(Section.admin);
      }),
      _refresh(api.adminScores, (scores) {
        _learn(scores.climbers);
        _plans.addAll(scores.plans);
        _scoreRun = scores.run;
        _adminScores = [
          for (final s in scores.scores)
            if (_plans.containsKey(s.planId)) s,
        ];
      }),
    ]);
  }

  /// One plan, with its open requests when I'm in it.
  Future<void> loadPlan(String planId) async {
    if (_phase != Phase.ready) return;
    _loadingPlans.add(planId);
    notifyListeners();
    try {
      final detail = await _call(() => api.plan(planId));
      _learn(detail.climbers);
      _plans[planId] = detail.plan;
      _open[planId] = detail.requests;
      _gone.remove(planId);
    } on ApiException catch (e) {
      if (e.status == 404 || e.status == 403) _gone.add(planId);
    } finally {
      _loadingPlans.remove(planId);
      notifyListeners();
    }
  }

  /// A plan's chat: all of it the first time, then what's new.
  Future<void> pollMessages(String planId) {
    final have = _messages[planId];
    return _refresh(
      () => api.messages(
        planId,
        after: have == null || have.isEmpty ? null : have.last.time,
      ),
      (list) {
        _learn(list.climbers);
        _addMessages(planId, list.messages, replace: have == null);
      },
    );
  }

  /// Every chat's latest messages, for Chats.
  Future<void> refreshChats() async {
    await Future.wait([for (final id in _mine) pollMessages(id)]);
  }

  void _addMessages(
    String planId,
    List<Message> messages, {
    bool replace = false,
  }) {
    final byId = <String, Message>{
      if (!replace)
        for (final m in _messages[planId] ?? const <Message>[]) m.id: m,
      for (final m in messages) m.id: m,
    };
    final list = byId.values.toList()..sort((a, b) => a.time.compareTo(b.time));
    _messages[planId] = list;
    notifyListeners();
  }

  // --- Swiping -----------------------------------------------------------

  /// I swipe left on a plan: it leaves my deck.
  Future<void> pass(String planId) async {
    _discover.remove(planId);
    notifyListeners();
    await _ok(() => api.pass(planId));
  }

  /// I swipe right on a plan: I ask to join it. Its members decide; I'm
  /// told when they have. A demo plan's say yes at once (the server's),
  /// and the match screen opens. False when it failed.
  Future<bool> like(String planId) async {
    final demo = _plans[planId]?.demo ?? false;
    _discover.remove(planId);
    notifyListeners();
    final request = await _act(() => api.join(planId));
    if (request == null) return false;
    if (demo) {
      // A demo plan's group says yes at once: the match screen opens.
      await refreshNotices();
      return true;
    }
    _asked = [..._asked.where((r) => r.id != request.id), request];
    notifyListeners();
    return true;
  }

  /// I accept someone into a plan I'm in. When every member has accepted,
  /// they join, and I get a [Match].
  Future<Match?> accept(JoinRequest request) async {
    final match = await _act(
      () => api.accept(request.planId, request.climberId),
    );
    _toReview = [..._toReview.where((r) => r.id != request.id)];
    await _afterAnswer(request.planId);
    if (match == null) return null;
    _plans[match.plan.id] = match.plan;
    notifyListeners();
    return Match(plan: match.plan, newcomer: climber(match.newcomerId));
  }

  /// I turn someone down for a plan I'm in: one "no" is enough.
  Future<bool> reject(JoinRequest request) async {
    if (!await _ok(() => api.reject(request.planId, request.climberId))) {
      return false;
    }
    _declinedHere.add(request.id);
    _toReview = [..._toReview.where((r) => r.id != request.id)];
    await _afterAnswer(request.planId);
    return true;
  }

  Future<void> _afterAnswer(String planId) async {
    notifyListeners();
    await Future.wait([
      loadPlan(planId),
      pollMessages(planId),
      refreshRequests(),
      refreshPlans(),
    ]);
  }

  /// I remind the members who haven't answered my request to join a plan.
  /// True when they were nudged; my request then knows when (the button
  /// waits out the cooldown).
  Future<bool> nudge(JoinRequest request) async {
    final answer = await _act(() => api.nudge(request.planId));
    if (answer == null) return false;
    _asked = [
      for (final r in _asked) r.id == answer.request.id ? answer.request : r,
    ];
    notifyListeners();
    return true;
  }

  /// I clear a group's "no" from my plans; the plan stays out of my deck.
  Future<void> dismiss(JoinRequest request) async {
    _asked = [..._asked.where((r) => r.id != request.id)];
    notifyListeners();
    await _ok(() => api.dismiss(request.planId, request.climberId));
  }

  /// Marks my notifications read.
  Future<void> readNotices() async {
    if (unreadNotices == 0) return;
    _notices = [for (final n in _notices) n.copyWith(read: true)];
    notifyListeners();
    await _ok(api.readNotices);
  }

  // --- Plans -------------------------------------------------------------

  /// Publishes a new plan, organized by me; null when it failed.
  Future<Plan?> createPlan(Plan draft) async {
    final plan = await _act(() => api.createPlan(draft));
    if (plan == null) return null;
    _plans[plan.id] = plan;
    _mine = [..._mine, plan.id];
    _sortMine();
    notifyListeners();
    unawaited(refreshPlans());
    return plan;
  }

  /// Saves my changes to a plan I organize.
  Future<bool> updatePlan(Plan plan) async {
    final saved = await _act(() => api.updatePlan(plan));
    if (saved == null) return false;
    _plans[saved.id] = saved;
    _sortMine();
    notifyListeners();
    return true;
  }

  void _sortMine() => _mine.sort(
    (a, b) => (_plans[a]?.start ?? DateTime(0)).compareTo(
      _plans[b]?.start ?? DateTime(0),
    ),
  );

  /// I leave (cancel) a plan: it's out of my plans and chats. When the
  /// organizer leaves, a member picked at random (by the API) organizes it;
  /// when the last member leaves, the plan is gone.
  Future<bool> leave(String planId) async {
    if (!await _ok(() => api.leave(planId))) return false;
    _mine = [..._mine.where((id) => id != planId)];
    _messages.remove(planId);
    _open.remove(planId);
    _toReview = [..._toReview.where((r) => r.planId != planId)];
    notifyListeners();
    unawaited(refreshPlans());
    return true;
  }

  // --- Profile -----------------------------------------------------------

  /// Saves my profile (creating it the first time): uploads the photos
  /// just picked, then `PUT /api/me` with their keys. False when it failed.
  Future<bool> saveProfile(
    Climber profile, {
    EditablePhoto? photo,
    List<EditablePhoto> gearPhotos = const [],
  }) async {
    Future<String> keyOf(EditablePhoto p, PhotoKind kind) async {
      if (p.key case final key?) return key;
      final bytes = p.bytes!;
      final type = photoContentType(bytes);
      if (type == null) {
        throw const ApiException(
          400,
          'Use a JPEG, PNG or WebP photo.',
          client: ClientError.photoType,
        );
      }
      final upload = await _call(() => api.newPhoto(kind, type));
      await api.uploadPhoto(upload, bytes);
      return upload.key;
    }

    final saved = await _act(() async {
      final photoKey = photo == null
          ? null
          : await keyOf(photo, PhotoKind.profile);
      final gearKeys = [
        for (final p in gearPhotos) await keyOf(p, PhotoKind.gear),
      ];
      return api.saveMe(
        profile.copyWith(photo: photoKey, gearPhotos: gearKeys),
      );
    });
    if (saved == null) return false;
    _me = saved;
    _climbers[saved.id] = saved;
    notifyListeners();
    // My grades, location and areas rank the deck.
    unawaited(refreshDiscover());
    return true;
  }

  bool _locating = false;

  /// Taking my location from the device ([fillLocation]); Discover holds
  /// off asking for it meanwhile.
  bool get locating => _locating;

  /// Where the device is, as a location named after the nearest place in
  /// the sector index ("Near Siurana, Spain"), rounded to about 1 km; null
  /// when the device can't tell.
  Future<Location?> locateMe() async {
    final here = await deviceLocation.current();
    if (here == null) return null;
    double round(double v) => (v * 100).roundToDouble() / 100;
    Sector? near;
    try {
      near = (await _places()).nearest(here.lat, here.lon);
    } on Object {
      near = null;
    }
    final place = near == null
        ? null
        : near.area.isEmpty
        ? near.fullName
        : near.where;
    return Location(
      name: place == null ? l10n.currentLocation : l10n.nearPlace(place),
      lat: round(here.lat),
      lon: round(here.lon),
    );
  }

  /// With no location on my profile, takes it from the phone or browser
  /// and saves it, instead of asking (my areas don't count: the location
  /// defaults to where I am); Discover asks only when the device can't
  /// tell.
  Future<void> fillLocation() async {
    final me = _me;
    if (me == null || me.location != null) return;
    final session = _session;
    _locating = true;
    notifyListeners();
    final found = await locateMe();
    if (session != _session) return;
    _locating = false;
    notifyListeners();
    final now = _me;
    if (found == null || now == null || now.location != null) return;
    await saveProfile(now.copyWith(location: found));
  }

  // --- Chat --------------------------------------------------------------

  /// Sends a message to a plan's group: text, a photo or video
  /// ([media]: uploaded first, [onProgress] hearing how much has gone), or
  /// both. False when it failed.
  Future<bool> send(
    String planId,
    String text, {
    ChatMedia? media,
    void Function(double sent)? onProgress,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty && media == null) return false;
    final message = await _act(() async {
      String? key;
      if (media != null) {
        final type = mediaContentType(media.bytes);
        final kind = type?.startsWith('video/') == true
            ? MediaKind.video
            : MediaKind.image;
        if (type == null || kind != media.kind) {
          throw const ApiException(
            400,
            'Use a JPEG, PNG or WebP photo, or an MP4 or MOV video.',
            client: ClientError.mediaType,
          );
        }
        if (kind == MediaKind.video && media.bytes.length > maxVideoBytes) {
          throw const ApiException(
            413,
            'The video is too big.',
            client: ClientError.videoTooBig,
          );
        }
        final upload = await _call(() => api.newChatMedia(planId, type));
        await api.uploadPhoto(upload, media.bytes, onProgress: onProgress);
        key = upload.key;
      }
      return api.send(planId, trimmed, attachment: key);
    });
    if (message == null) return false;
    _addMessages(planId, [message]);
    return true;
  }

  // --- Admin -------------------------------------------------------------

  /// An admin lets someone in, as if every member had said yes.
  Future<Match?> adminAccept(JoinRequest request) async {
    final match = await _act(
      () => api.adminAccept(request.planId, request.climberId),
    );
    await _afterAdmin(request);
    if (match == null) return null;
    _plans[match.plan.id] = match.plan;
    return Match(plan: match.plan, newcomer: climber(match.newcomerId));
  }

  /// An admin turns someone down.
  Future<bool> adminReject(JoinRequest request) async {
    final ok = await _ok(
      () => api.adminReject(request.planId, request.climberId),
    );
    await _afterAdmin(request);
    return ok;
  }

  Future<void> _afterAdmin(JoinRequest request) async {
    _adminRequests = [..._adminRequests.where((r) => r.id != request.id)];
    notifyListeners();
    await Future.wait([refreshAdmin(), refreshRequests(), refreshPlans()]);
  }

  @override
  void dispose() {
    _live?.dispose();
    auth.removeListener(_authChanged);
    _errors.close();
    _matches.close();
    super.dispose();
  }
}

/// How a plan fits my profile. Profiles hold no time or place (those are
/// the plan's), so it's the grades.
class Fit {
  const Fit({required this.grades});

  /// My grades for its discipline overlap its grades.
  final bool grades;

  int get score => grades ? 1 : 0;
}
