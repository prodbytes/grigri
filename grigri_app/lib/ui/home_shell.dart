import 'package:flutter/material.dart';

import '../theme.dart';
import 'chats_screen.dart';
import 'common.dart';
import 'discover_screen.dart';
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
