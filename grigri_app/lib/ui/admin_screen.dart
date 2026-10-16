import 'package:flutter/material.dart';

import '../data/api.dart';
import '../data/grigri_store.dart';
import '../model/ad.dart';
import '../theme.dart';
import 'ad_card.dart';
import 'ads_screen.dart' show AdStatusTag;
import 'common.dart';

/// The Admin tab (admins only), with a sub-navigation: **Users**,
/// everyone by name, to block (they can't use Grigri, and their plans
/// leave the deck) or unblock; and **Ads** (specs/ads.md), to approve or
/// reject Premium climbers' ads and set how often the deck shows them.
class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final l = context.l10n;
    return DefaultTabController(
      length: 2,
      child: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text(l.adminAdsTitle),
            actions: [
              IconButton(
                tooltip: l.refresh,
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  if (DefaultTabController.of(context).index == 0) {
                    store.refreshAdmin();
                  } else {
                    for (final status in AdStatus.values) {
                      store.refreshAdminAds(status);
                    }
                  }
                },
              ),
            ],
            bottom: TabBar(
              tabs: [
                Tab(
                  icon: const Icon(Icons.people_outline),
                  text: l.adminUsersTab,
                ),
                Tab(
                  icon: const Icon(Icons.campaign_outlined),
                  text: l.adminAdsTab,
                ),
              ],
            ),
          ),
          body: const TabBarView(children: [_Users(), AdminAdsView()]),
        ),
      ),
    );
  }
}

class _Users extends StatelessWidget {
  const _Users();

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final climbers = store.adminClimbers;
    final l = context.l10n;
    return !store.isLoaded(Section.admin)
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: store.refreshAdmin,
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                if (climbers.isEmpty)
                  EmptyState(
                    icon: Icons.people_outline,
                    title: l.adminNoClimbersTitle,
                    message: l.adminNoClimbersMessage,
                  )
                else
                  for (final c in climbers) _ClimberTile(entry: c),
              ],
            ),
          );
  }
}

/// Admin → Ads: how often the deck shows an ad, then the ads in a status
/// (waiting first), each with its card's preview, who placed it, its
/// link, and **Approve** / **Reject**.
class AdminAdsView extends StatefulWidget {
  const AdminAdsView({super.key});

  @override
  State<AdminAdsView> createState() => _AdminAdsViewState();
}

class _AdminAdsViewState extends State<AdminAdsView> {
  AdStatus _status = AdStatus.pending;

  /// The deck's choices: none, or one ad after every N plans.
  static const _everyChoices = [0, 1, 2, 3, 4, 5, 7, 10, 15, 20, 30, 50];

  @override
  void initState() {
    super.initState();
    StoreScope.read(context).refreshAdminAds(_status);
  }

  void _show(AdStatus status) {
    setState(() => _status = status);
    StoreScope.read(context).refreshAdminAds(status);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final ads = store.adminAds(_status);
    final every = store.adminAdEvery;
    final l = context.l10n;
    String label(int n) => n == 0 ? l.adEveryOff : l.adEvery(n);
    return RefreshIndicator(
      onRefresh: () => store.refreshAdminAds(_status),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          Row(
            children: [
              Text(
                l.adsOnDiscover,
                style: const TextStyle(color: Mountain.granite),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButton<int>(
                  key: const ValueKey('ad every'),
                  isExpanded: true,
                  value: _everyChoices.contains(every) ? every : null,
                  hint: Text(label(every)),
                  items: [
                    for (final n in _everyChoices)
                      DropdownMenuItem(value: n, child: Text(label(n))),
                  ],
                  onChanged: (n) {
                    if (n != null) store.setAdEvery(n);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SegmentedButton<AdStatus>(
            segments: [
              ButtonSegment(
                value: AdStatus.pending,
                label: Text(l.adStatusPending),
              ),
              ButtonSegment(
                value: AdStatus.approved,
                label: Text(l.adStatusApproved),
              ),
              ButtonSegment(
                value: AdStatus.rejected,
                label: Text(l.adStatusRejected),
              ),
            ],
            selected: {_status},
            showSelectedIcon: false,
            onSelectionChanged: (s) => _show(s.first),
          ),
          const SizedBox(height: 12),
          if (!store.isLoaded(Section.adminAds))
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (ads.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  l.adminAdsEmpty,
                  style: const TextStyle(color: Mountain.granite),
                ),
              ),
            )
          else
            for (final ad in ads) _AdReview(ad),
        ],
      ),
    );
  }
}

class _AdReview extends StatelessWidget {
  const _AdReview(this.ad);

  final Ad ad;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final owner = store.climber(ad.ownerId);
    final l = context.l10n;
    return Card(
      key: ValueKey('admin ad ${ad.id}'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Avatar(owner),
              title: Text(owner.name),
              subtitle: Text(
                ad.link.toString(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Mountain.sky),
              ),
              onTap: () => showProfileSheet(context, owner),
            ),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: AspectRatio(aspectRatio: 3 / 4, child: AdCard(ad)),
              ),
            ),
            const SizedBox(height: 8),
            // Wraps on narrow phones: the tag, then the buttons.
            Wrap(
              spacing: 8,
              runSpacing: 4,
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                AdStatusTag(ad.status),
                if (ad.status != AdStatus.rejected)
                  TextButton(
                    onPressed: () => store.reviewAd(ad, approve: false),
                    child: Text(
                      l.adReject,
                      style: const TextStyle(color: Mountain.clay),
                    ),
                  ),
                if (ad.status != AdStatus.approved)
                  FilledButton(
                    onPressed: () => store.reviewAd(ad, approve: true),
                    child: Text(l.adApprove),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ClimberTile extends StatelessWidget {
  const _ClimberTile({required this.entry});

  final AdminClimber entry;

  Future<bool> _confirmBlock(BuildContext context, String name) async {
    final l = context.l10n;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l.blockNameQuestion(name)),
            content: Text(l.blockMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  l.block,
                  style: const TextStyle(color: Mountain.clay),
                ),
              ),
            ],
          ),
        ) ==
        true;
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final person = entry.climber;
    final l = context.l10n;
    // Never myself: I'd lock myself out (the API refuses it too).
    final Widget? action = person.id == store.me.id
        ? null
        : entry.blocked
        ? OutlinedButton(
            onPressed: () => store.setBlocked(person.id, false),
            child: Text(l.unblock),
          )
        : TextButton(
            onPressed: () async {
              if (!await _confirmBlock(context, person.name)) return;
              await store.setBlocked(person.id, true);
            },
            child: Text(l.block, style: const TextStyle(color: Mountain.clay)),
          );
    return ListTile(
      key: ValueKey('admin climber ${person.id}'),
      leading: Avatar(person),
      title: Text(person.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: entry.blocked
          ? Text(l.blocked, style: const TextStyle(color: Mountain.clay))
          : null,
      onTap: () => showProfileSheet(context, person),
      trailing: action,
    );
  }
}
