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
import 'plans_screen.dart';
import 'profile_screen.dart';
import 'requests_screen.dart';

/// The app's tabs: Discover, Requests, Plans, Chats and Profile.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;
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
    final screens = [
      DiscoverScreen(onCreatePlan: _createPlan),
      const RequestsScreen(),
      PlansScreen(onCreatePlan: _createPlan),
      const ChatsScreen(),
      const ProfileScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _tab, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.landscape_outlined),
            selectedIcon: Icon(Icons.landscape),
            label: 'Discover',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: toReview > 0,
              label: Text('$toReview'),
              backgroundColor: Mountain.sky,
              textColor: Mountain.night,
              child: const Icon(Icons.group_add_outlined),
            ),
            selectedIcon: const Icon(Icons.group_add),
            label: 'Requests',
          ),
          const NavigationDestination(
            icon: Icon(Icons.event_note_outlined),
            selectedIcon: Icon(Icons.event_note),
            label: 'Plans',
          ),
          const NavigationDestination(
            icon: Icon(Icons.forum_outlined),
            selectedIcon: Icon(Icons.forum),
            label: 'Chats',
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
