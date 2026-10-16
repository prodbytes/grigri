import 'package:flutter/material.dart';

import '../app_version.dart';
import '../theme.dart';
import 'common.dart';
import 'location_picker.dart';
import 'profile_editor.dart';
import 'roles_card.dart';

/// My profile, as others see it when I ask to join their plans, with Edit.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final me = store.me;
    final text = Theme.of(context).textTheme;
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.profileTitle),
        actions: [
          PopupMenuButton<String>(
            tooltip: l.more,
            onSelected: (choice) async {
              final everywhere = choice == 'signOutEverywhere';
              final sure = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(
                    everywhere
                        ? l.signOutEverywhereQuestion
                        : l.signOutQuestion,
                  ),
                  content: Text(
                    everywhere ? l.signOutEverywhereMessage : l.signOutMessage,
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(l.cancel),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(everywhere ? l.signOutEverywhere : l.signOut),
                    ),
                  ],
                ),
              );
              if (sure != true) return;
              await (everywhere ? store.signOutEverywhere() : store.signOut());
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'signOut', child: Text(l.signOut)),
              PopupMenuItem(
                value: 'signOutEverywhere',
                child: Text(l.signOutEverywhere),
              ),
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
              label: Text(l.editProfile),
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
          const SizedBox(height: 8),
          const _WhereIClimb(),
          const SizedBox(height: 12),
          const SizedBox(height: 4),
          const LanguagePicker(),
          const SizedBox(height: 12),
          Text(
            l.profileFootnote,
            style: text.bodySmall?.copyWith(color: Mountain.granite),
          ),
          const SizedBox(height: 12),
          const RolesCard(),
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

/// My location, private, which ranks my deck: set here without opening the
/// editor. The app fills it in from the device when I have none
/// ([GrigriStore.fillLocation]); tapping picks another place, or where I am
/// now, and saves it at once.
class _WhereIClimb extends StatelessWidget {
  const _WhereIClimb();

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final location = store.me.location;
    final text = Theme.of(context).textTheme;
    final l = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.whereYouClimb.toUpperCase(),
              style: text.labelSmall?.copyWith(
                color: Mountain.granite,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              l.whereYouClimbHint,
              style: text.bodySmall?.copyWith(color: Mountain.granite),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: store.locating
                  ? const SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location, color: Mountain.sky),
              title: Text(location?.name ?? l.setYourLocation),
              subtitle: Text(
                l.yourLocation,
                style: const TextStyle(color: Mountain.granite),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: store.locating
                  ? null
                  : () async {
                      final picked = await pickLocation(
                        context,
                        title: l.yourLocation,
                      );
                      if (picked == null || picked == store.me.location) {
                        return;
                      }
                      await store.saveProfile(
                        store.me.copyWith(location: picked),
                      );
                    },
            ),
          ],
        ),
      ),
    );
  }
}
