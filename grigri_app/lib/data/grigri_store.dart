import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../config.dart';
import '../l10n/app_localizations.dart';
import '../log.dart';
import '../model/ad.dart';
import '../model/premium.dart';
import '../model/climber.dart';
import '../model/climbing.dart';
import '../model/location.dart';
import '../model/match_score.dart';
import '../model/pics.dart';
import '../model/plan.dart';
import '../model/report.dart';
import '../model/sector.dart';
import 'api.dart';
import 'app_store.dart';
import 'auth.dart';
import 'device_location.dart';
import 'links.dart';
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

  /// Signed in, but an admin blocked me: only signing out.
  blocked,
}

/// The parts of the app's data that load separately.
enum Section {
  discover,
  plans,
  requests,
  notices,
  admin,
  ads,
  adminAds,
  adminReports,
  blocks,
}

/// A card on the Discover deck: a plan, or an ad between plans
/// (specs/ads.md).
sealed class DeckItem {
  const DeckItem();

  /// Unique on the deck.
  String get key;
}

class DeckPlan extends DeckItem {
  const DeckPlan(this.plan);

  final Plan plan;

  @override
  String get key => 'plan:${plan.id}';
}

class DeckAd extends DeckItem {
  const DeckAd(this.ad);

  final Ad ad;

  @override
  String get key => 'ad:${ad.id}';
}

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
/// requests, notifications, chats, my profile, and (for admins) everyone,
/// to block or unblock. Screens read it and call its actions; it refreshes from the
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
    this.openLink = openInBrowser,
    this.appStore,
    math.Random? random,
  }) : _random = random ?? math.Random(),
       _image = image ?? ((url) => NetworkImage(url.toString())),
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
    // From the start: StoreKit hands over purchases left unfinished last
    // time as soon as someone listens.
    _storePurchases = appStore?.purchases.listen(_onStorePurchases);
  }

  /// Live updates (none without a transport: polling only).
  Realtime? _live;

  final GrigriApi api;
  final Auth auth;
  final ImageProvider Function(Uri url) _image;
  final Preferences _preferences;

  /// Where the phone or browser is, to fill in my location.
  final DeviceLocation deviceLocation;

  /// Opens Stripe's pages, and ads' links, in the browser.
  final OpenLink openLink;

  /// The App Store, which sells Premium on iOS (specs/premium.md); null
  /// elsewhere (Android and the web pay through Stripe).
  final AppStore? appStore;

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
    null when e.objectionable => l10n.errorObjectionable,
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
  Premium _premium = const Premium.none();
  Map<PremiumPlan, PremiumPrice> _premiumPrices = const {};
  List<Ad> _deckAds = [];
  int _adEvery = 0;

  /// Ads swiped this session: they don't come back until ⟳.
  final _seenAds = <String>{};

  /// Ads I skipped: never again (the API leaves them out of my deck too).
  final _skippedAds = <String>{};

  /// How many plans come before each of the next ads: [adEvery], give or
  /// take a little, drawn as the deck needs them and kept until that ad
  /// is swiped, so the deck doesn't reshuffle as it rebuilds.
  final _adGaps = <int>[];
  final math.Random _random;

  /// Plans swiped since the deck last showed an ad.
  int _plansSinceAd = 0;
  List<Ad> _myAds = [];
  final _adminAds = <AdStatus, List<Ad>>{};
  int _adminAdEvery = 0;
  List<String>? _roles;
  bool _signedIn = false;

  final _climbers = <String, Climber>{};
  final _plans = <String, Plan>{};
  List<String> _discover = [];
  Map<String, int> _distanceKm = {};
  Map<String, DeckCover> _covers = {};
  Map<String, MatchScore> _matchScores = {};
  List<String> _mine = [];
  List<JoinRequest> _asked = [];
  List<JoinRequest> _toReview = [];
  List<AdminClimber> _adminClimbers = [];
  List<Report> _adminReports = [];

  /// The people I blocked (specs/moderation.md#blocking-someone).
  Set<String> _blockedPeople = {};
  final _open = <String, List<JoinRequest>>{};
  final _declinedHere = <String>{};
  List<Notice> _notices = [];
  final _messages = <String, List<Message>>{};
  final _pics = <String, PlanPics>{};
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
    _premium = const Premium.none();
    _premiumPrices = const {};
    _appleAccountToken = null;
    _buying = false;
    _deckAds = [];
    _adEvery = 0;
    _seenAds.clear();
    _skippedAds.clear();
    _adGaps.clear();
    _plansSinceAd = 0;
    _myAds = [];
    _adminAds.clear();
    _adminAdEvery = 0;
    _roles = null;
    _locating = false;
    _climbers.clear();
    _plans.clear();
    _discover = [];
    _distanceKm = {};
    _covers = {};
    _matchScores = {};
    _mine = [];
    _asked = [];
    _toReview = [];
    _adminClimbers = [];
    _adminReports = [];
    _blockedPeople = {};
    _open.clear();
    _declinedHere.clear();
    _notices = [];
    _messages.clear();
    _pics.clear();
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
      _premium = me.premium;
      _me = climber;
      _climbers[climber.id] = climber;
      _phase = Phase.ready;
      notifyListeners();
      _deliverWaiting();
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

  /// Deletes my account for good (`DELETE /api/me`): the API ends every
  /// session of mine with it, so this device then forgets its session and
  /// goes back to the sign-in screen. False, saying why, when it failed
  /// (nothing changes here; trying again finishes the job).
  Future<bool> deleteAccount() async {
    try {
      await _call(api.deleteAccount);
    } on ApiException catch (e) {
      // A 401 already signed out (and said so).
      if (e.status != _stale && e.status != 401) {
        _errors.add(l10n.errorDeleteAccount);
      }
      return false;
    }
    await auth.signedOut();
    return true;
  }

  // --- Reading -----------------------------------------------------------

  bool get admin => _admin;

  /// My Premium subscription (specs/premium.md).
  Premium get premium => _premium;

  /// What Premium costs; empty until loaded, or when it can't be bought.
  Map<PremiumPlan, PremiumPrice> get premiumPrices => _premiumPrices;

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
      _premium = me.premium;
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

  /// A GriGri Pics photo's image.
  ImageProvider grigriPic(String key) => _image(api.picUrl(key));

  /// A plan's photos, once loaded ([loadPics]).
  PlanPics? pics(String planId) => _pics[planId];

  /// Plans to swipe on, best fits first (the server's order).
  List<Plan> get discover => [for (final id in _discover) ?_plans[id]];

  /// The Discover deck: its plans, with an approved ad after about every
  /// [adEvery] plans swiped (each gap a little more or less, at random;
  /// counting the plans swiped since the last ad, so an ad comes up as
  /// the deck goes, not further down each time). Ads swiped this session,
  /// and ads I skipped, are left out. No plans: no ads either.
  List<DeckItem> get deck {
    final plans = discover;
    final ads = [
      for (final a in _deckAds)
        if (!_seenAds.contains(a.id) && !_skippedAds.contains(a.id)) a,
    ];
    if (_adEvery <= 0 || ads.isEmpty || plans.isEmpty) {
      return [for (final p in plans) DeckPlan(p)];
    }
    final items = <DeckItem>[];
    var next = math.max(0, _adGap(0) - _plansSinceAd);
    var shown = 0;
    var ad = 0;
    for (final p in plans) {
      if (shown == next && ad < ads.length) {
        items.add(DeckAd(ads[ad++]));
        next = shown + _adGap(ad);
      }
      items.add(DeckPlan(p));
      shown++;
    }
    if (shown == next && ad < ads.length) items.add(DeckAd(ads[ad]));
    return items;
  }

  /// One ad after about every this many plans on the deck; 0: none.
  int get adEvery => _adEvery;

  /// The plans before the [i]th next ad: [adEvery] ± 30%, at least 1.
  int _adGap(int i) {
    while (_adGaps.length <= i) {
      final spread = (_adEvery * 0.3).floor();
      _adGaps.add(
        math.max(1, _adEvery - spread + _random.nextInt(2 * spread + 1)),
      );
    }
    return _adGaps[i];
  }

  /// How far a plan on the deck is from my nearest location or area, in
  /// km; null when it isn't known.
  int? distanceKm(String planId) => _distanceKm[planId];

  /// A plan's cover photo on the deck, when it has one.
  DeckCover? cover(String planId) => _covers[planId];

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
  ].where((r) => r.id == id).firstOrNull;

  /// Whether I turned this request down (in this session).
  bool declinedHere(String requestId) => _declinedHere.contains(requestId);

  /// Everyone, by name, and whether they're blocked (admins).
  List<AdminClimber> get adminClimbers => _adminClimbers;

  /// My notifications, newest first.
  /// (Not about someone I blocked.)
  List<Notice> get notices => [
    for (final n in _notices)
      if (!_blockedPeople.contains(n.climberId)) n,
  ];

  int get unreadNotices => notices.where((n) => !n.read).length;

  /// A plan's group chat, oldest first.
  /// (Without the messages of people I blocked: hidden on my side only.)
  List<Message> messages(String planId) => [
    for (final m in _messages[planId] ?? const <Message>[])
      if (!_blockedPeople.contains(m.authorId)) m,
  ];

  /// The people I blocked, by name.
  List<Climber> get blockedPeople =>
      [for (final id in _blockedPeople) climber(id)]
        ..sort((a, b) => a.name.compareTo(b.name));

  /// Whether I blocked them.
  bool hasBlocked(String climberId) => _blockedPeople.contains(climberId);

  /// The open reports, oldest first (admins).
  List<Report> get adminReports => _adminReports;

  /// Why a plan suits me.
  Fit fit(Plan plan) {
    final level = _me?.levels[plan.discipline];
    return Fit(grades: level != null && level.overlaps(plan.grades));
  }

  // --- Calling the API ---------------------------------------------------

  /// Calls the API; a 401 (the session ended) signs out. A 409 "no
  /// profile" goes back to creating one. A 403 "blocked" leaves only
  /// signing out ([Phase.blocked]).
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
      if (e.blocked) {
        _clear();
        _phase = Phase.blocked;
        notifyListeners();
        throw const ApiException(_stale, 'stale');
      }
      // My profile went missing: loading it again makes a new one.
      if (e.noProfile && _phase == Phase.ready) unawaited(loadMe());
      rethrow;
    }
  }

  /// The status of an answer that came after a sign-out: dropped quietly.
  static const _stale = -1;

  /// An error from a call made outside the store (the route finder's), as
  /// the store's own: a 401 signs out; the rest go to [errors].
  void report(ApiException e) {
    if (e.status == 401) {
      _errors.add(l10n.errorSignedOut);
      unawaited(auth.signedOut());
      return;
    }
    _errors.add(_describe(e));
  }

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
      case HintKind.pics:
        if (planId != null && _pics.containsKey(planId)) {
          await loadPics(planId);
        }
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
  /// the deck; for admins, everyone too.
  Future<void> refreshAll() async {
    await Future.wait([
      refreshPlans(),
      refreshRequests(),
      refreshDiscover(),
      refreshBlocks(),
      if (_admin) refreshAdmin(),
      if (_admin) refreshAdminReports(),
      if (_premium.active) refreshMyAds(),
    ]);
    await refreshNotices();
  }

  /// The deck again, with [again] the plans I passed on too (Discover's
  /// refresh button: I may have changed my mind).
  Future<void> refreshDiscover({bool again = false}) async {
    if (again) {
      _seenAds.clear();
      await _ok(api.clearPasses);
    }
    await _refreshDeck();
  }

  Future<void> _refreshDeck() => _refresh(api.discover, (list) {
    _learn(list.climbers);
    for (final p in list.plans) {
      _plans[p.id] = p;
    }
    _discover = [for (final p in list.plans) p.id];
    _distanceKm = list.distanceKm;
    _covers = list.covers;
    _matchScores = list.scores;
    _deckAds = list.ads;
    if (_adEvery != list.adEvery) _adGaps.clear();
    _adEvery = list.adEvery;
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

  /// Everyone, to block or unblock (admins).
  Future<void> refreshAdmin() async {
    if (!_admin) return;
    await _refresh(api.adminClimbers, (list) {
      _adminClimbers = list;
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

  /// A plan's photos: its GriGri Pics and, when I'm in it, "Your Pics".
  Future<void> loadPics(String planId) =>
      _refresh(() => api.planPics(planId), (list) {
        _learn(list.climbers);
        _pics[planId] = list.pics;
      });

  /// Adds a photo to a plan's "Your Pics": uploaded first ([onProgress]
  /// hears how much has gone). False when it failed.
  Future<bool> addPlanPic(
    String planId,
    Uint8List bytes, {
    void Function(double sent)? onProgress,
  }) async {
    final pic = await _act(() async {
      final type = photoContentType(bytes);
      if (type == null) {
        throw const ApiException(
          400,
          'Use a JPEG, PNG or WebP photo.',
          client: ClientError.photoType,
        );
      }
      final upload = await _call(() => api.newPlanPic(planId, type));
      await api.uploadPhoto(upload, bytes, onProgress: onProgress);
      return _call(() => api.addPlanPic(planId, upload.key));
    });
    if (pic == null) return false;
    final have = _pics[planId];
    if (have != null && !have.yours.any((p) => p.id == pic.id)) {
      _pics[planId] = have.copyWith(yours: [...have.yours, pic]);
    }
    notifyListeners();
    return true;
  }

  /// Deletes a photo from its plan's "Your Pics" (whoever added it, or the
  /// organizer). A chat photo stays in the chat. False when it failed.
  Future<bool> deletePlanPic(PlanPic pic) async {
    final done = await _ok(() => api.deletePlanPic(pic.planId, pic.id));
    if (!done) return false;
    final have = _pics[pic.planId];
    if (have != null) {
      _pics[pic.planId] = have.copyWith(
        yours: [
          for (final p in have.yours)
            if (p.id != pic.id) p,
        ],
      );
    }
    notifyListeners();
    return true;
  }

  /// Whether I may delete a plan photo: I added it, or I organize the plan.
  bool canDeletePic(PlanPic pic) =>
      pic.uploaderId == me.id ||
      _plans[pic.planId]?.organizerId == me.id ||
      _admin;

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
    if (_discover.remove(planId)) _plansSinceAd++;
    notifyListeners();
    await _ok(() => api.pass(planId));
  }

  /// I swipe right on a plan: I ask to join it. Its deciders (every
  /// member, or a guided plan's guide) decide; I'm told when they have. An
  /// open plan lets me in at once, and a demo plan's group says yes at
  /// once (the server's): the match screen opens. False when it failed.
  Future<bool> like(String planId) async {
    final plan = _plans[planId];
    final instant = plan != null && (plan.demo || plan.type == PlanType.open);
    if (_discover.remove(planId)) _plansSinceAd++;
    notifyListeners();
    final request = await _act(() => api.join(planId));
    if (request == null) return false;
    if (instant) {
      // In at once: the "accepted" notice opens the match screen.
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
        final type = _mediaType(media);
        final upload = await _call(() => api.newChatMedia(planId, type));
        await api.uploadPhoto(upload, media.bytes, onProgress: onProgress);
        key = upload.key;
      }
      return api.send(planId, trimmed, attachment: key);
    });
    if (message == null) return false;
    _addMessages(planId, [message]);
    // A chat photo joins the plan's "Your Pics" (the server adds it).
    if (message.attachment?.kind == MediaKind.image &&
        _pics.containsKey(planId)) {
      unawaited(loadPics(planId));
    }
    return true;
  }

  /// The type a photo or video is uploaded as; refuses anything but a
  /// JPEG, PNG or WebP photo or an MP4 or MOV video, and videos over
  /// [maxVideoBytes].
  static String _mediaType(ChatMedia media) {
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
    return type;
  }

  // --- Ads (specs/ads.md) -------------------------------------------------

  /// An ad on the deck was swiped: the plans count again to the next one.
  /// [open] (swiped right) opens its link in the browser, and the ad
  /// leaves the deck for this session; skipped (left), it never shows to
  /// me again (`POST /api/ads/{id}/skip`).
  Future<void> swipeAd(Ad ad, {required bool open}) async {
    (open ? _seenAds : _skippedAds).add(ad.id);
    _plansSinceAd = 0;
    if (_adGaps.isNotEmpty) _adGaps.removeAt(0);
    notifyListeners();
    if (open) {
      await _openOrSay(ad.link);
    } else {
      // Quiet: unsaved, it still stays off the deck until I sign out.
      try {
        await _call(() => api.skipAd(ad.id));
      } on ApiException catch (_) {}
    }
  }

  /// My ads, newest first.
  List<Ad> get myAds => _myAds;

  Future<void> refreshMyAds() => _refresh(api.myAds, (mine) {
    _myAds = mine.ads;
    _loaded.add(Section.ads);
  });

  /// Adds an ad (Premium only): its photo or video uploaded first
  /// ([onProgress] hears how much has gone). It waits for an admin. True
  /// when it was saved.
  Future<bool> createAd({
    required String text,
    required String link,
    ChatMedia? media,
    void Function(double sent)? onProgress,
  }) async {
    final ad = await _act(() async {
      String? key;
      if (media != null) {
        final type = _mediaType(media);
        final upload = await _call(() => api.newAdMedia(type));
        await api.uploadPhoto(upload, media.bytes, onProgress: onProgress);
        key = upload.key;
      }
      return api.createAd(text: text.trim(), link: link.trim(), mediaKey: key);
    });
    if (ad == null) return false;
    _myAds = [ad, ..._myAds];
    notifyListeners();
    return true;
  }

  /// Takes my ad down for good.
  Future<bool> deleteAd(String adId) async {
    if (!await _ok(() => api.deleteAd(adId))) return false;
    _myAds = [
      for (final a in _myAds)
        if (a.id != adId) a,
    ];
    notifyListeners();
    return true;
  }

  /// Ads in a status, for admins to review (newest first).
  List<Ad> adminAds(AdStatus status) => _adminAds[status] ?? const [];

  /// How often the deck shows ads, as admins set it: one after every
  /// this many plans; 0: none.
  int get adminAdEvery => _adminAdEvery;

  Future<void> refreshAdminAds(AdStatus status) async {
    if (!_admin) return;
    await _refresh(() => api.adminAds(status), (list) {
      _learn(list.climbers);
      _adminAds[status] = list.ads;
      _adminAdEvery = list.every;
      _loaded.add(Section.adminAds);
    });
  }

  /// An admin approves or rejects an ad; it moves to that list.
  Future<bool> reviewAd(Ad ad, {required bool approve}) async {
    final reviewed = await _act(() => api.reviewAd(ad.id, approve: approve));
    if (reviewed == null) return false;
    for (final status in AdStatus.values) {
      _adminAds[status] = [
        if (status == reviewed.status) reviewed,
        for (final a in _adminAds[status] ?? const <Ad>[])
          if (a.id != ad.id) a,
      ];
    }
    notifyListeners();
    return true;
  }

  /// An admin sets how often the deck shows ads.
  Future<bool> setAdEvery(int every) async {
    if (!await _ok(() => api.setAdEvery(every))) return false;
    _adminAdEvery = every;
    notifyListeners();
    return true;
  }

  // --- Premium -----------------------------------------------------------

  /// My Premium and its prices again (the profile, and coming back from
  /// Stripe's pages in the browser).
  Future<void> refreshPremium() async {
    await _refresh(api.premium, _applyOffer);
    await _premiumChanged();
  }

  void _applyOffer(PremiumOffer offer) {
    _premium = offer.premium;
    _premiumPrices = offer.prices;
    _appleAccountToken = offer.appleAccountToken;
  }

  /// Just subscribed: the Ads tab appears, with my ads.
  Future<void> _premiumChanged() async {
    if (_premium.active && !_loaded.contains(Section.ads)) {
      await refreshMyAds();
    }
  }

  /// Opens Stripe Checkout for [plan] in the browser; true when it opened.
  /// Premium shows once Stripe tells the API (a refresh). Not on iOS: the
  /// App Store sells it there ([buyInAppStore]).
  Future<bool> subscribe(PremiumPlan plan) async {
    final url = await _act(() => api.premiumCheckout(plan));
    return url != null && await _openOrSay(url);
  }

  /// Where my subscription is managed: the App Store's subscriptions for
  /// one bought there, Stripe's billing portal (cancel, card, invoices)
  /// for one bought through Stripe.
  Future<bool> managePremium() async {
    if (_premium.source == PremiumSource.apple) {
      return _openOrSay(appStoreSubscriptionsUrl);
    }
    final url = await _act(api.premiumPortal);
    return url != null && await _openOrSay(url);
  }

  // --- Premium through the App Store (iOS) ---------------------------------

  /// Whether Premium is sold here through the App Store (iOS).
  bool get sellsInAppStore => appStore != null;

  StreamSubscription<List<StorePurchase>>? _storePurchases;
  Map<PremiumPlan, StoreProduct> _storeProducts = const {};
  bool _storeProductsLoaded = false;
  Future<void>? _loadingStoreProducts;
  String? _appleAccountToken;
  bool _buying = false;
  bool _restoring = false;

  /// Purchases StoreKit reported before I was signed in and loaded.
  final _waitingPurchases = <StorePurchase>[];

  /// Purchases on their way to the API.
  final _deliveries = <Future<void>>{};

  /// The App Store's products with their localized prices; empty until
  /// loaded, or when the App Store can't sell them.
  Map<PremiumPlan, StoreProduct> get storeProducts => _storeProducts;

  /// Whether the App Store's products have been asked for.
  bool get storeProductsLoaded => _storeProductsLoaded;

  /// A purchase is under way (the App Store's sheet, then the API).
  bool get buying => _buying;

  /// Restoring purchases.
  bool get restoring => _restoring;

  /// Asks the App Store for its products (once; again after a failure).
  Future<void> loadStoreProducts() {
    final store = appStore;
    if (store == null || (_storeProductsLoaded && _storeProducts.isNotEmpty)) {
      return Future.value();
    }
    return _loadingStoreProducts ??= () async {
      try {
        _storeProducts = await store.products();
      } finally {
        _storeProductsLoaded = true;
        _loadingStoreProducts = null;
        notifyListeners();
      }
    }();
  }

  /// Buys [plan] through the App Store, for my account (the API's
  /// appAccountToken). Premium shows once the API has the transaction.
  Future<void> buyInAppStore(PremiumPlan plan) async {
    final store = appStore;
    final product = _storeProducts[plan];
    if (store == null || product == null || _buying) return;
    if (_appleAccountToken == null) await refreshPremium();
    final token = _appleAccountToken;
    if (token == null) {
      _errors.add(l10n.premiumUnavailable);
      return;
    }
    _buying = true;
    notifyListeners();
    try {
      if (!await store.buy(product, accountToken: token)) _buying = false;
    } on Object catch (e) {
      log.warn('premium', 'App Store purchase failed: $e');
      _buying = false;
      _errors.add(l10n.premiumPurchaseFailed);
    }
    notifyListeners();
  }

  /// Restore purchases (Apple requires it): my App Store subscription,
  /// sent to the API again, say on a new phone.
  Future<void> restoreAppStorePurchases() async {
    final store = appStore;
    if (store == null || _restoring) return;
    _restoring = true;
    notifyListeners();
    try {
      await store.restore();
      await Future.wait([..._deliveries]);
      if (!_premium.active) _errors.add(l10n.premiumNothingToRestore);
    } on Object catch (e) {
      log.warn('premium', 'App Store restore failed: $e');
      _errors.add(l10n.premiumStoreUnavailable);
    } finally {
      _restoring = false;
      notifyListeners();
    }
  }

  void _onStorePurchases(List<StorePurchase> purchases) {
    for (final p in purchases) {
      switch (p.status) {
        case StorePurchaseStatus.pending:
          // Waiting (Ask to Buy, a card to confirm): it comes back later.
          _buying = false;
        case StorePurchaseStatus.canceled:
          _buying = false;
          unawaited(_complete(p));
        case StorePurchaseStatus.error:
          _buying = false;
          _errors.add(l10n.premiumPurchaseFailed);
          unawaited(_complete(p));
        case StorePurchaseStatus.purchased || StorePurchaseStatus.restored:
          if (_phase == Phase.ready) {
            _deliver(p);
          } else {
            _waitingPurchases.add(p);
          }
      }
    }
    notifyListeners();
  }

  /// Sends the purchases StoreKit reported before I was loaded.
  void _deliverWaiting() {
    final waiting = [..._waitingPurchases];
    _waitingPurchases.clear();
    waiting.forEach(_deliver);
  }

  /// Sends a purchase's signed transaction to the API, then finishes it.
  /// A purchase the API can never take (another account's, not Grigri's)
  /// is finished too; one that failed on the way (offline, the server) is
  /// left for StoreKit to hand over again.
  void _deliver(StorePurchase p) {
    late final Future<void> delivery;
    delivery = () async {
      try {
        final offer = await _call(() => api.premiumApple(p.signedTransaction));
        _applyOffer(offer);
        await _complete(p);
        await _premiumChanged();
      } on ApiException catch (e) {
        final retry =
            e.status == 0 ||
            e.status == 401 ||
            e.status == _stale ||
            e.status >= 500 ||
            e.client != null;
        if (e.status != _stale && e.status != 401) _errors.add(_describe(e));
        if (!retry) await _complete(p);
      } finally {
        _buying = false;
        _deliveries.remove(delivery);
        notifyListeners();
      }
    }();
    _deliveries.add(delivery);
  }

  Future<void> _complete(StorePurchase p) async {
    if (!p.needsCompleting) return;
    try {
      await appStore?.complete(p);
    } on Object catch (e) {
      log.warn('premium', 'App Store completePurchase failed: $e');
    }
  }

  /// Opens one of the site's own pages in the browser, e.g.
  /// `privacy.html` or `support.html` (specs/app-store.md).
  Future<bool> openSitePage(String page) =>
      _openOrSay(AppConfig.origin.resolve('/$page'));

  Future<bool> _openOrSay(Uri url) async {
    if (await openLink(url)) return true;
    _errors.add(l10n.errorOpenLink);
    return false;
  }

  // --- Moderation: reports and blocks (specs/moderation.md) ---------------

  /// I report something objectionable; true when it was sent (the caller
  /// thanks me: it's reviewed within 24 hours).
  Future<bool> sendReport({
    required ReportKind kind,
    required String targetId,
    String? planId,
    required ReportReason reason,
    String text = '',
  }) => _ok(
    () => api.sendReport(
      kind: kind,
      targetId: targetId,
      planId: planId,
      reason: reason,
      text: text,
    ),
  );

  /// The people I blocked.
  Future<void> refreshBlocks() => _refresh(api.blocks, (list) {
    _learn(list.climbers);
    _blockedPeople = list.blocked.toSet();
    _loaded.add(Section.blocks);
  });

  /// I block someone, or unblock them. Blocking takes their plans off my
  /// deck and their requests off my list at once (the server declines
  /// them), and hides their messages from me. True when it worked.
  Future<bool> setPersonBlocked(String climberId, bool blocked) async {
    if (!await _ok(() => api.setPersonBlocked(climberId, blocked))) {
      return false;
    }
    if (blocked) {
      _blockedPeople = {..._blockedPeople, climberId};
      _discover = [
        for (final id in _discover)
          if (!(_plans[id]?.memberIds.contains(climberId) ?? false)) id,
      ];
      _toReview = [
        for (final r in _toReview)
          if (r.climberId != climberId) r,
      ];
    } else {
      _blockedPeople = {..._blockedPeople}..remove(climberId);
    }
    notifyListeners();
    await Future.wait([_refreshDeck(), refreshRequests()]);
    return true;
  }

  /// The open reports (admins).
  Future<void> refreshAdminReports() async {
    if (!_admin) return;
    await _refresh(api.adminReports, (list) {
      _learn(list.climbers);
      _adminReports = list.reports;
      _loaded.add(Section.adminReports);
    });
  }

  /// An admin handles a report: dismisses it, removes the content, or
  /// blocks its climber. It leaves the list; true when it worked.
  Future<bool> resolveReport(Report report, ReportAction action) async {
    if (!await _ok(() => api.resolveReport(report.id, action))) return false;
    _adminReports = [
      for (final r in _adminReports)
        if (r.id != report.id) r,
    ];
    notifyListeners();
    if (action == ReportAction.block) await refreshAdmin();
    return true;
  }

  // --- Admin -------------------------------------------------------------

  /// An admin blocks someone (they can't use Grigri, and their plans
  /// leave the deck) or unblocks them; true when it worked.
  Future<bool> setBlocked(String climberId, bool blocked) async {
    final ok = await _ok(() => api.setBlocked(climberId, blocked));
    if (ok) {
      _adminClimbers = [
        for (final c in _adminClimbers)
          c.climber.id == climberId
              ? AdminClimber(c.climber, blocked: blocked)
              : c,
      ];
      notifyListeners();
    }
    return ok;
  }

  @override
  void dispose() {
    _storePurchases?.cancel();
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
