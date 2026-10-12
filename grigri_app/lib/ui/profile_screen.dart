import 'package:flutter/material.dart';

import '../app_version.dart';
import '../theme.dart';
import 'common.dart';
import 'profile_editor.dart';

/// My profile, as others see it when I ask to join their plans, with Edit.
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
          PopupMenuButton<String>(
            tooltip: 'More',
            onSelected: (_) async {
              final sure = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Sign out?'),
                  content: const Text(
                    'Your profile, plans and chats stay saved; sign back in '
                    'to see them.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Sign out'),
                    ),
                  ],
                ),
              );
              if (sure == true) await store.signOut();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'signOut', child: Text('Sign out')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: me.photo == null
                ? Avatar(me, radius: 52)
                : GestureDetector(
                    onTap: () => showPhoto(context, store.photo(me.photo!)),
                    child: Avatar(me, radius: 52),
                  ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              me.nameAndAge,
              style: text.headlineSmall?.copyWith(
                color: Mountain.sand,
                fontWeight: FontWeight.w700,
              ),
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
            'Your profile is about you: what you climb and the gear you have. '
            'When and where are for plans, made separately in Plans.',
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
