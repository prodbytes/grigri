import 'dart:async';

import 'package:flutter/material.dart';

import '../data/grigri_store.dart';
import '../model/plan.dart';
import '../theme.dart';
import 'chats_screen.dart';
import 'common.dart';
import 'discover_screen.dart';
import 'match_screen.dart';
import 'plan_editor.dart';
import 'notices_screen.dart';
import 'plans_screen.dart';
import 'profile_screen.dart';

/// The app's tabs: Discover, Plans, Chats, Notifications and Profile.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  /// The Notifications tab's index.
  static const _notices = 3;

  /// The notifications that were unread when I opened the tab.
  Set<String> _fresh = const {};

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
    setState(() => _tab = tab);
  }

  Timer? _answers;

  @override
  void initState() {
    super.initState();
    // The made-up climbers answer requests a little later
    // (GrigriStore.answerAfter): check for their answers now and then.
    _answers = Timer.periodic(const Duration(seconds: 2), (_) => _settle());
  }

  @override
  void dispose() {
    _answers?.cancel();
    super.dispose();
  }

  /// Applies the groups' answers to my requests: a yes is a match, a no a
  /// note at the bottom. Both are in Notifications.
  void _settle() {
    if (!mounted) return;
    final store = StoreScope.of(context);
    for (final notice in store.settle()) {
      final plan = store.plan(notice.planId);
      if (notice.kind == NoticeKind.accepted && plan != null) {
        MatchScreen.show(context, Match(plan: plan, newcomer: store.me));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Not this time: ${notice.planTitle} said no.'),
          ),
        );
      }
    }
  }

  void _createPlan() =>
      Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => const PlanEditor()));

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final toReview = store.toReview.length;
    final unread = store.unreadNotices;
    final screens = [
      DiscoverScreen(onCreatePlan: _createPlan),
      PlansScreen(onCreatePlan: _createPlan),
      const ChatsScreen(),
      NoticesScreen(fresh: _fresh),
      const ProfileScreen(),
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
        ],
      ),
    );
  }
}
