import 'package:flutter/material.dart';

import '../data/grigri_store.dart';
import '../model/plan.dart';
import '../theme.dart';
import 'common.dart';
import 'match_screen.dart';
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

  void _swiped(GrigriStore store, Plan plan, {required bool right}) {
    if (!right) {
      store.pass(plan.id);
      return;
    }
    final match = store.like(plan.id);
    if (match != null) {
      MatchScreen.show(context, match);
    } else {
      final organizer = store.climber(plan.organizerId).name.split(' ').first;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            store.waiting.any((r) => r.planId == plan.id)
                ? 'Asked to join: pending. $organizer${plan.memberIds.length > 1 ? ' and the group' : ''} will decide; you\'ll get a notification.'
                : 'Not this time: the group passed.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final plans = store.discover;
    return Scaffold(
      appBar: AppBar(title: const Text('Discover plans')),
      body: plans.isEmpty
          ? EmptyState(
              icon: Icons.landscape_outlined,
              title: "You've seen every plan",
              message: 'Make your own, and climbers who fit will ask to join.',
              action: FilledButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('New plan'),
                onPressed: widget.onCreatePlan,
              ),
            )
          : Column(
              children: [
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
                          yesLabel: 'JOIN',
                          noLabel: 'PASS',
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
                        tooltip: 'Pass',
                        onPressed: () => _controller.swipe(right: false),
                      ),
                      const SizedBox(width: 40),
                      DeckButton(
                        icon: Icons.check,
                        color: Mountain.olive,
                        filled: true,
                        tooltip: 'Ask to join',
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
            PlanHighlight(plan, fit: store.fit(plan)),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ORGANIZED BY',
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
                      'ALSO IN THE GROUP',
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
                                    '${e.key.label} ${StoreScope.of(context).grades(e.value)}',
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
