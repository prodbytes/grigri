import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_version.dart';
import '../model/premium.dart';
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
          const SizedBox(height: 8),
          const PremiumCard(),
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
          const SizedBox(height: 24),
          const _DeleteAccount(),
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

/// Deleting my account (App Store guideline 5.1.1(v); specs/sign-in.md):
/// a confirmation that says what goes, and a box to tick before the
/// destructive button works. Done, the app is signed out (the API ended
/// every session) and back on the sign-in screen.
class _DeleteAccount extends StatelessWidget {
  const _DeleteAccount();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Center(
      child: TextButton.icon(
        style: TextButton.styleFrom(foregroundColor: Mountain.clay),
        icon: const Icon(Icons.delete_forever_outlined),
        label: Text(l.deleteAccount),
        onPressed: () async {
          final store = StoreScope.read(context);
          final sure = await showDialog<bool>(
            context: context,
            builder: (_) => const _DeleteAccountDialog(),
          );
          if (sure != true) return;
          await store.deleteAccount();
        },
      ),
    );
  }
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  bool _understood = false;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(l.deleteAccountQuestion),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.deleteAccountMessage),
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _understood,
              onChanged: (v) => setState(() => _understood = v ?? false),
              title: Text(l.deleteAccountUnderstand),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l.cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Mountain.clay,
            foregroundColor: Mountain.night,
          ),
          onPressed: _understood ? () => Navigator.pop(context, true) : null,
          child: Text(l.deleteAccountConfirm),
        ),
      ],
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

/// Premium (specs/premium.md): to advertise on Grigri. Subscribing opens
/// Stripe Checkout in the browser; once Stripe tells the API, it shows
/// here (the app checks again when it comes back to the foreground, or on
/// "I've paid: check again"). Subscribed: until when, and Stripe's portal
/// to cancel or change the card.
class PremiumCard extends StatefulWidget {
  const PremiumCard({super.key});

  @override
  State<PremiumCard> createState() => _PremiumCardState();
}

class _PremiumCardState extends State<PremiumCard> {
  @override
  void initState() {
    super.initState();
    StoreScope.read(context).refreshPremium();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final premium = store.premium;
    final prices = store.premiumPrices;
    final text = Theme.of(context).textTheme;
    final l = context.l10n;
    final date = premium.until == null
        ? ''
        : DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag())
              .format(premium.until!);
    return Card(
      key: const ValueKey('premium card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.workspace_premium, color: Mountain.sand),
                const SizedBox(width: 8),
                Text(
                  l.premiumTitle,
                  style: text.titleMedium?.copyWith(
                    color: Mountain.sand,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (premium.active) ...[
              Text(
                premium.ending
                    ? l.premiumEndsOn(date)
                    : l.premiumActiveUntil(date),
                style: const TextStyle(color: Mountain.snow),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                icon: const Icon(Icons.open_in_new),
                label: Text(l.premiumManage),
                onPressed: store.managePremium,
              ),
            ] else ...[
              Text(
                l.premiumPitch,
                style: const TextStyle(color: Mountain.snow),
              ),
              const SizedBox(height: 12),
              if (prices.isEmpty)
                Text(
                  l.premiumUnavailable,
                  style: text.bodySmall?.copyWith(color: Mountain.granite),
                )
              else ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (prices[PremiumPlan.monthly] case final p?)
                      FilledButton(
                        onPressed: () => store.subscribe(PremiumPlan.monthly),
                        child: Text(l.premiumMonthly(p.label)),
                      ),
                    if (prices[PremiumPlan.yearly] case final p?)
                      FilledButton.tonal(
                        onPressed: () => store.subscribe(PremiumPlan.yearly),
                        child: Text(l.premiumYearly(p.label)),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  l.premiumCheckoutHint,
                  style: text.bodySmall?.copyWith(color: Mountain.granite),
                ),
                TextButton(
                  onPressed: store.refreshPremium,
                  child: Text(l.premiumCheckRefresh),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
