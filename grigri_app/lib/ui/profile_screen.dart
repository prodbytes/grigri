import 'package:flutter/material.dart';

import '../app_version.dart';
import '../theme.dart';
import 'common.dart';
import 'notices_screen.dart';
import 'profile_editor.dart';

/// My profile, as others see it on the Requests deck, with Edit.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final me = store.me;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          const NoticesButton(),
          PopupMenuButton<String>(
            onSelected: (_) async {
              final sure = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Start over?'),
                  content: const Text(
                    'Your profile, plans, matches and chats go back to the demo data.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text(
                        'Start over',
                        style: TextStyle(color: Mountain.clay),
                      ),
                    ),
                  ],
                ),
              );
              if (sure == true) store.reset();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'reset', child: Text('Reset the demo data')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(child: Avatar(me, radius: 52)),
          const SizedBox(height: 12),
          Center(
            child: Text(
              '${me.name}, ${me.age}',
              style: text.headlineSmall?.copyWith(
                color: Mountain.sand,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Center(
            child: Text(
              [
                if (me.homeArea.isNotEmpty) me.homeArea,
                if (me.yearsClimbing > 0) '${me.yearsClimbing} years climbing',
              ].join(' · '),
              style: text.bodyMedium?.copyWith(color: Mountain.granite),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: FilledButton.tonalIcon(
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit profile'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const ProfileEditor()),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ProfileDetails(me),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Your profile is about you: how, when and where you like to climb. '
            'Each outing is a plan, made separately in Plans.',
            style: text.bodySmall?.copyWith(color: Mountain.granite),
          ),
          if (AppVersion.version.isNotEmpty) ...[
            const SizedBox(height: 24),
            Center(
              child: Text(
                '${AppVersion.title} ${AppVersion.version}',
                style: text.labelSmall?.copyWith(color: Mountain.granite),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
