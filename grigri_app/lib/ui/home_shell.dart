import 'dart:async';
import 'dart:math' show max;

import 'package:flutter/material.dart';

import '../data/grigri_store.dart';
import '../data/realtime.dart';
import '../theme.dart';
import 'admin_screen.dart';
import 'chats_screen.dart';
import 'common.dart';
import 'discover_screen.dart';
import 'match_screen.dart';
import 'notices_screen.dart';
import 'plan_editor.dart';
import 'plans_screen.dart';
import 'profile_screen.dart';

/// The app's tabs: Discover, Plans, Chats, Notifications and Profile, and
/// Admin for admins. While the app is in the foreground it keeps a live
/// connection (specs/live-updates.md), whose hints refresh what changed,
/// and refreshes from the API: the tab I open, and every [refreshEvery]
/// my plans, requests, notifications and the open tab; only every
/// [liveRefreshEvery] while the live connection is up (a safety net).
class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    this.refreshEvery = const Duration(seconds: 15),
    this.liveRefreshEvery = const Duration(minutes: 2),
  });

  final Duration refreshEvery;
  final Duration liveRefreshEvery;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _tab = 0;

  static const _discover = 0;
  static const _plans = 1;
  static const _chats = 2;
  static const _notices = 3;
  static const _admin = 5;

  /// The notifications that were unread when I opened the tab.
  Set<String> _fresh = const {};

  Timer? _timer;
  StreamSubscription<Match>? _matches;
  late final GrigriStore _store;
  late final Cadence _cadence = Cadence(
    liveEvery: max(
      1,
      widget.liveRefreshEvery.inMilliseconds ~/
          widget.refreshEvery.inMilliseconds,
    ),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _store = StoreScope.read(context);
    _matches = _store.matches.listen((match) {
      if (mounted) MatchScreen.show(context, match);
    });
    _startTimer();
    _store.goLive();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _matches?.cancel();
    _store.goQuiet();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startTimer();
      _store.goLive();
      _tick();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _timer?.cancel();
      _timer = null;
      _store.goQuiet();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _cadence.reset();
    _timer = Timer.periodic(widget.refreshEvery, (_) {
      if (_cadence.tick(live: _store.live)) _tick();
    });
  }

  /// The regular refresh: what every tab's badges need, and the open tab.
  void _tick() {
    if (!mounted) return;
    final store = StoreScope.read(context);
    store.refreshPlans();
    store.refreshRequests();
    store.refreshNotices();
    _refreshTab(_tab, regular: true);
  }

  /// Refreshes what a tab shows.
  void _refreshTab(int tab, {bool regular = false}) {
    final store = StoreScope.read(context);
    switch (tab) {
      case _discover:
        store.refreshDiscover();
      case _plans when !regular:
        store.refreshPlans();
      case _chats:
        store.refreshChats();
      case _notices when !regular:
        store.refreshNotices();
      case _admin:
        store.refreshAdmin();
    }
  }

  /// Opening Notifications marks them read, keeping which were new; so
  /// does leaving it, for the ones that came in meanwhile.
  void _select(int tab) {
    final store = StoreScope.read(context);
    if (tab == _notices && _tab != _notices) {
      _fresh = {
        for (final n in store.notices)
          if (!n.read) n.id,
      };
    }
    if (tab == _notices || _tab == _notices) store.readNotices();
    if (tab != _tab) _refreshTab(tab);
    setState(() => _tab = tab);
  }

  void _createPlan() =>
      Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => const PlanEditor()));

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final toReview = store.toReview.length;
    final unread = store.unreadNotices;
    final admin = store.admin;
    if (!admin && _tab == _admin) _tab = 0;
    final screens = [
      DiscoverScreen(onCreatePlan: _createPlan),
      PlansScreen(onCreatePlan: _createPlan),
      ChatsScreen(onDiscover: () => _select(_discover)),
      NoticesScreen(fresh: _fresh),
      const ProfileScreen(),
      if (admin) const AdminScreen(),
    ];
    Widget badged(IconData icon, int count) => Badge(
      isLabelVisible: count > 0,
      label: Text('$count'),
      backgroundColor: Mountain.sky,
      textColor: Mountain.night,
      child: Icon(icon),
    );
    return Scaffold(
      body: IndexedStack(index: _tab, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: _select,
        // Six tabs don't leave room for every label on a narrow phone.
        labelBehavior: admin
            ? NavigationDestinationLabelBehavior.onlyShowSelected
            : null,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.landscape_outlined),
            selectedIcon: Icon(Icons.landscape),
            label: 'Discover',
          ),
          const NavigationDestination(
            icon: Icon(Icons.event_note_outlined),
            selectedIcon: Icon(Icons.event_note),
            label: 'Plans',
          ),
          NavigationDestination(
            icon: badged(Icons.forum_outlined, toReview),
            selectedIcon: badged(Icons.forum, toReview),
            label: 'Chats',
          ),
          NavigationDestination(
            icon: badged(Icons.notifications_outlined, unread),
            selectedIcon: badged(Icons.notifications, unread),
            label: 'Notifications',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
          if (admin)
            NavigationDestination(
              icon: badged(
                Icons.admin_panel_settings_outlined,
                store.adminRequests.length,
              ),
              selectedIcon: badged(
                Icons.admin_panel_settings,
                store.adminRequests.length,
              ),
              label: 'Admin',
            ),
        ],
      ),
    );
  }
}
