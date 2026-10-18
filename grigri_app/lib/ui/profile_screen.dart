import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_version.dart';
import '../data/app_store.dart';
import '../model/premium.dart';
import '../theme.dart';
import 'common.dart';
import 'gear_editor.dart';
import 'location_picker.dart';
import 'moderation.dart';
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
              child: ProfileDetails(me, gear: false),
            ),
          ),
          const SizedBox(height: 8),
          const _MyGear(),
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
          const SizedBox(height: 12),
          // The people I blocked (specs/moderation.md), to unblock them.
          Card(
            child: ListTile(
              key: const ValueKey('blocked people'),
              leading: const Icon(Icons.block, color: Mountain.granite),
              title: Text(l.blockedPeopleTitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const BlockedPeopleScreen(),
                ),
              ),
            ),
          ),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            children: [
              TextButton(
                onPressed: () => store.openSitePage('privacy.html'),
                child: Text(l.privacyPolicy),
              ),
              TextButton(
                onPressed: () => store.openSitePage('support.html'),
                child: Text(l.support),
              ),
            ],
          ),
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

/// My gear, in a card of its own: what I own and its photos, as my plans'
/// groups see it, with the gear editor a tap away.
class _MyGear extends StatelessWidget {
  const _MyGear();

  @override
  Widget build(BuildContext context) {
    final me = StoreScope.of(context).me;
    final text = Theme.of(context).textTheme;
    final l = context.l10n;
    final empty = me.gear.isEmpty && me.gearPhotos.isEmpty;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 8, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l.profileGear.toUpperCase(),
                    style: text.labelSmall?.copyWith(
                      color: Mountain.granite,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                TextButton.icon(
                  icon: Icon(empty ? Icons.add : Icons.edit_outlined),
                  label: Text(empty ? l.addGear : l.editGear),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const GearEditor()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: empty
                  ? Text(
                      l.gearEmpty,
                      style: text.bodySmall?.copyWith(color: Mountain.granite),
                    )
                  : GearDetails(me),
            ),
          ],
        ),
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

/// Premium (specs/premium.md): to advertise on Grigri and use the route
/// finder. On Android and the web, subscribing opens Stripe Checkout in
/// the browser; once Stripe tells the API, it shows here (the app checks
/// again when it comes back to the foreground, or on "I've paid: check
/// again"). On iOS the App Store sells it ([_AppStoreOffer]): its prices,
/// its purchase sheet, Restore purchases, and its terms; no Stripe.
/// Subscribed: until when, and where to manage it (Stripe's portal, or the
/// App Store's subscriptions).
class PremiumCard extends StatefulWidget {
  const PremiumCard({super.key});

  @override
  State<PremiumCard> createState() => _PremiumCardState();
}

class _PremiumCardState extends State<PremiumCard> {
  @override
  void initState() {
    super.initState();
    final store = StoreScope.read(context);
    store.refreshPremium();
    store.loadStoreProducts();
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
    // On iOS, a subscription bought through Stripe (on the web) is shown,
    // but not managed from here: no link out of the App Store's.
    final manageable =
        !store.sellsInAppStore || premium.source == PremiumSource.apple;
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
              if (manageable && premium.source != null) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  icon: const Icon(Icons.open_in_new),
                  label: Text(l.premiumManage),
                  onPressed: store.managePremium,
                ),
              ],
            ] else ...[
              Text(
                l.premiumPitch,
                style: const TextStyle(color: Mountain.snow),
              ),
              const SizedBox(height: 12),
              if (store.sellsInAppStore)
                const _AppStoreOffer()
              else if (prices.isEmpty)
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
                  onPressed: () => store.refreshPremium(fresh: true),
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

/// Premium on iOS, sold by the App Store (guideline 3.1.1): its products
/// at its localized prices, bought through its sheet; Restore purchases;
/// and the subscription's terms Apple requires next to the buttons (title,
/// length and price, auto-renewal, where to cancel, the privacy policy and
/// the terms of use). No buttons when the App Store can't sell them.
class _AppStoreOffer extends StatelessWidget {
  const _AppStoreOffer();

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final products = store.storeProducts;
    final text = Theme.of(context).textTheme;
    final l = context.l10n;
    final small = text.bodySmall?.copyWith(color: Mountain.granite);
    if (!store.storeProductsLoaded) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: SizedBox.square(
          dimension: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    final busy = store.buying || store.restoring;
    final restore = TextButton(
      onPressed: busy ? null : store.restoreAppStorePurchases,
      child: Text(l.premiumRestore),
    );
    if (products.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.premiumStoreUnavailable, style: small),
          Wrap(
            children: [
              TextButton(
                onPressed: store.loadStoreProducts,
                child: Text(l.tryAgain),
              ),
              restore,
            ],
          ),
        ],
      );
    }
    final monthly = products[PremiumPlan.monthly];
    final yearly = products[PremiumPlan.yearly];
    final terms = [
      if (monthly != null) l.premiumMonthly(monthly.price),
      if (yearly != null) l.premiumYearly(yearly.price),
    ].join(', ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (monthly != null)
              FilledButton(
                onPressed: busy
                    ? null
                    : () => store.buyInAppStore(PremiumPlan.monthly),
                child: Text(l.premiumMonthly(monthly.price)),
              ),
            if (yearly != null)
              FilledButton.tonal(
                onPressed: busy
                    ? null
                    : () => store.buyInAppStore(PremiumPlan.yearly),
                child: Text(l.premiumYearly(yearly.price)),
              ),
            if (busy)
              const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(l.premiumAppStoreTerms(terms), style: small),
        Wrap(
          children: [
            TextButton(
              onPressed: () => store.openLink(privacyPolicyUrl),
              child: Text(l.premiumPrivacyPolicy),
            ),
            TextButton(
              onPressed: () => store.openLink(appleEulaUrl),
              child: Text(l.premiumTermsOfUse),
            ),
            restore,
          ],
        ),
      ],
    );
  }
}
