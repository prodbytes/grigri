import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../model/climber.dart';
import '../model/climbing.dart';
import '../model/plan.dart';
import 'api.dart';
import 'auth.dart';
import 'preferences.dart';

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

  /// Signed in without a profile: "Create your profile" first.
  needsProfile,

  /// The tabs.
  ready,

  /// Signed in, but my profile couldn't be loaded: try again.
  failed,
}

/// The parts of the app's data that load separately.
enum Section { discover, plans, requests, notices, admin }

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
/// API when they ask (see specs/matching.md, Refreshing).
class GrigriStore extends ChangeNotifier {
  GrigriStore({
    required this.api,
    required this.auth,
    ImageProvider Function(Uri url)? image,
    Preferences? preferences,
  }) : _image = image ?? ((url) => NetworkImage(url.toString())),
       _preferences = preferences ?? Preferences.none() {
    _gradeSystem = _preferences.gradeSystem;
    auth.addListener(_authChanged);
  }

  final GrigriApi api;
  final Auth auth;
  final ImageProvider Function(Uri url) _image;
  final Preferences _preferences;
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

  Phase _phase = Phase.starting;
  Phase get phase => _phase;

  /// Why my profile couldn't be loaded ([Phase.failed]).
  String? loadError;

  Climber? _me;
  bool _admin = false;
  bool _signedIn = false;

  final _climbers = <String, Climber>{};
  final _plans = <String, Plan>{};
  List<String> _discover = [];
  Map<String, int> _distanceKm = {};
  List<String> _mine = [];
  List<JoinRequest> _asked = [];
  List<JoinRequest> _toReview = [];
  List<JoinRequest> _adminRequests = [];
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
    _session++;
    _me = null;
    _admin = false;
    _climbers.clear();
    _plans.clear();
    _discover = [];
    _distanceKm = {};
    _mine = [];
    _asked = [];
    _toReview = [];
    _adminRequests = [];
    _open.clear();
    _declinedHere.clear();
    _notices = [];
    _messages.clear();
    _gone.clear();
    _loaded.clear();
    _loadingPlans.clear();
    _announced.clear();
  }

  /// Loads my profile (`GET /api/me`), then everything else.
  Future<void> loadMe() async {
    _phase = Phase.loading;
    loadError = null;
    notifyListeners();
    try {
      final me = await _call(api.me);
      _admin = me.admin;
      _me = me.climber;
      if (me.climber case final c?) _climbers[c.id] = c;
      _phase = me.climber == null ? Phase.needsProfile : Phase.ready;
      notifyListeners();
      if (_phase == Phase.ready) await refreshAll();
    } on ApiException catch (e) {
      if (_phase == Phase.signedOut || e.status == _stale) return;
      loadError = e.message;
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
      _errors.add('Couldn\'t sign out everywhere. Try again.');
    }
  }

  /// The name to start a new profile with: Google's, when there is one.
  String get suggestedName => auth.user?.name ?? '';

  // --- Reading -----------------------------------------------------------

  bool get admin => _admin;

  /// My profile (a blank one until it's loaded, so screens on their way
  /// out after a sign-out still build).
  Climber get me => _me ?? const Climber(id: '', name: '');

  Climber? get meOrNull => _me;

  /// Someone, as far as the app knows them.
  Climber climber(String id) =>
      _climbers[id] ?? Climber(id: id, name: 'Someone');

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
        _errors.add('Signed out: please sign in again.');
        // Auth notifies, and _authChanged clears everything.
        await auth.signedOut();
        rethrow;
      }
      if (e.noProfile && _phase == Phase.ready) {
        _me = null;
        _phase = Phase.needsProfile;
        notifyListeners();
      }
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
      if (e.status != 401 && e.status != _stale) _errors.add(e.message);
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

  Future<void> refreshDiscover() => _refresh(api.discover, (list) {
    _learn(list.climbers);
    for (final p in list.plans) {
      _plans[p.id] = p;
    }
    _discover = [for (final p in list.plans) p.id];
    _distanceKm = list.distanceKm;
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

  Future<void> refreshAdmin() async {
    if (!_admin) return;
    await _refresh(api.adminRequests, (list) {
      _learn(list.climbers);
      _plans.addAll(list.plans);
      _adminRequests = list.requests;
      _loaded.add(Section.admin);
    });
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
  /// told when they have. False when it failed.
  Future<bool> like(String planId) async {
    _discover.remove(planId);
    notifyListeners();
    final request = await _act(() => api.join(planId));
    if (request == null) return false;
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

  /// I leave a plan's group. When the organizer leaves, the next member
  /// organizes it; when the last member leaves, the plan is gone.
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
        throw const ApiException(400, 'Use a JPEG, PNG or WebP photo.');
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
    if (_phase == Phase.needsProfile) {
      _phase = Phase.ready;
      notifyListeners();
      unawaited(refreshAll());
    } else {
      notifyListeners();
      // My grades, location and areas rank the deck.
      unawaited(refreshDiscover());
    }
    return true;
  }

  // --- Chat --------------------------------------------------------------

  /// Sends a message to a plan's group; false when it failed.
  Future<bool> send(String planId, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    final message = await _act(() => api.send(planId, trimmed));
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
