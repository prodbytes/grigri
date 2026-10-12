import 'package:flutter/material.dart';

import '../data/grigri_store.dart';
import '../model/plan.dart';
import '../theme.dart';
import 'common.dart';
import 'profile_editor.dart';
import 'swipe_deck.dart';

/// The plans deck: swipe right (or tap ✓) to ask to join a plan, left to
/// pass. The plan comes first on each card; the people in it below.
class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key, required this.onCreatePlan});

  /// Opens the plan editor, when the deck runs out.
  final VoidCallback onCreatePlan;

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final _controller = SwipeController();

  Future<void> _swiped(
    GrigriStore store,
    Plan plan, {
    required bool right,
  }) async {
    if (!right) {
      await store.pass(plan.id);
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final l = context.l10n;
    if (!await store.like(plan.id)) return;
    final organizer = store.climber(plan.organizerId).firstName;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          plan.memberIds.length > 1
              ? l.askedToJoinPendingGroup(organizer)
              : l.askedToJoinPending(organizer),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final plans = store.discover;
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.discoverTitle),
        actions: [
          IconButton(
            tooltip: l.refresh,
            icon: const Icon(Icons.refresh),
            onPressed: store.refreshDiscover,
          ),
        ],
      ),
      body: !store.isLoaded(Section.discover)
          ? const Center(child: CircularProgressIndicator())
          : plans.isEmpty
          ? EmptyState(
              icon: Icons.landscape_outlined,
              title: l.noPlansToJoinTitle,
              message: l.noPlansToJoinMessage,
              action: FilledButton.icon(
                icon: const Icon(Icons.add),
                label: Text(l.newPlan),
                onPressed: widget.onCreatePlan,
              ),
            )
          : Column(
              children: [
                if (store.me.location == null && store.me.areas.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.near_me_outlined,
                          size: 18,
                          color: Mountain.sky,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l.setWhereYouClimbHint,
                            style: const TextStyle(color: Mountain.snow),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const ProfileEditor(),
                            ),
                          ),
                          child: Text(l.setAction),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: SwipeDeck<Plan>(
                          items: plans,
                          keyOf: (p) => p.id,
                          controller: _controller,
                          yesLabel: l.swipeJoin.toUpperCase(),
                          noLabel: l.swipePass.toUpperCase(),
                          onSwiped: (plan, {required right}) =>
                              _swiped(store, plan, right: right),
                          builder: (context, plan) => _PlanCard(plan: plan),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      DeckButton(
                        icon: Icons.close,
                        color: Mountain.clay,
                        tooltip: l.pass,
                        onPressed: () => _controller.swipe(right: false),
                      ),
                      const SizedBox(width: 40),
                      DeckButton(
                        icon: Icons.check,
                        color: Mountain.olive,
                        filled: true,
                        tooltip: l.askToJoin,
                        onPressed: () => _controller.swipe(right: true),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

/// A plan on the deck: the plan, highlighted, then who's in it.
class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan});

  final Plan plan;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final text = Theme.of(context).textTheme;
    final l = context.l10n;
    final organizer = store.climber(plan.organizerId);
    final others = [
      for (final id in plan.memberIds)
        if (id != organizer.id) store.climber(id),
    ];
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PlanHighlight(
              plan,
              fit: store.fit(plan),
              distanceKm: store.distanceKm(plan.id),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.organizedBy.toUpperCase(),
                    style: text.labelSmall?.copyWith(
                      color: Mountain.granite,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => showProfileSheet(context, organizer),
                    child: ClimberHeader(organizer),
                  ),
                  const SizedBox(height: 10),
                  ProfileDetails(organizer, compact: true),
                  if (others.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      l.alsoInGroup.toUpperCase(),
                      style: text.labelSmall?.copyWith(
                        color: Mountain.granite,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    for (final c in others)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Avatar(c),
                        title: Text(c.nameAndAge),
                        subtitle: Text(
                          c.levels.entries
                              .map(
                                (e) =>
                                    '${e.key.label(l)} ${StoreScope.of(context).grades(e.value)}',
                              )
                              .join(' · '),
                          style: const TextStyle(color: Mountain.granite),
                        ),
                        onTap: () => showProfileSheet(context, c),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
