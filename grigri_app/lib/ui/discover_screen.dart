import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../config.dart';
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
  /// The share button: small, to the right of ✓.
  static const _shareSize = 36.0;
  static const _shareGap = 16.0;

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
    // A demo plan matches at once, and the match screen says so.
    if (plan.demo) return;
    messenger.showSnackBar(SnackBar(content: Text(l.askedToJoinSent)));
  }

  /// Shares the top plan as text with the app's link, through the
  /// system's share sheet (the browser's, or copying, on the web).
  Future<void> _share(BuildContext button, Plan plan) async {
    final l = context.l10n;
    final box = button.findRenderObject() as RenderBox?;
    final text = l.sharePlanText(
      plan.discipline.label(l),
      plan.title,
      whenLabel(context, plan),
      AppConfig.origin.resolve('/app/').toString(),
    );
    await SharePlus.instance.share(
      ShareParams(
        text: text,
        subject: plan.title,
        // Where the sheet points from, on iPad.
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
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
            onPressed: () => store.refreshDiscover(again: true),
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
                if (store.me.location == null &&
                    store.me.areas.isEmpty &&
                    !store.locating)
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
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
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
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // As wide as the share button and its gap, so ✕
                      // and ✓ stay centered.
                      const SizedBox(width: _shareSize + _shareGap),
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
                      const SizedBox(width: _shareGap),
                      Builder(
                        builder: (context) => DeckButton(
                          icon: Icons.share_outlined,
                          color: Mountain.sky,
                          size: _shareSize,
                          tooltip: l.sharePlan,
                          onPressed: () => _share(context, plans.first),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

/// A plan on the deck: the plan, highlighted, then its organizer, with
/// how many others are in the group ("+3"); tapping that shows them.
class _PlanCard extends StatefulWidget {
  const _PlanCard({required this.plan});

  final Plan plan;

  @override
  State<_PlanCard> createState() => _PlanCardState();
}

class _PlanCardState extends State<_PlanCard> {
  /// The group's list, collapsed until the "+3" is tapped.
  bool _showGroup = false;

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
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
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PlanHighlight(plan, fit: store.fit(plan), compact: true),
            const SizedBox(height: 12),
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
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => showProfileSheet(context, organizer),
                          child: ClimberHeader(organizer, radius: 20),
                        ),
                      ),
                      if (others.isNotEmpty)
                        Tooltip(
                          message: _showGroup ? l.hideGroup : l.showGroup,
                          child: TextButton.icon(
                            onPressed: () =>
                                setState(() => _showGroup = !_showGroup),
                            icon: Icon(
                              _showGroup
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                            ),
                            label: Text('+${others.length}'),
                            iconAlignment: IconAlignment.end,
                            style: TextButton.styleFrom(
                              foregroundColor: Mountain.sky,
                              textStyle: text.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (_showGroup && others.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      l.alsoInGroup.toUpperCase(),
                      style: text.labelSmall?.copyWith(
                        color: Mountain.granite,
                        letterSpacing: 1.2,
                      ),
                    ),
                    for (final c in others)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Avatar(c),
                        title: Text(c.nameAndAge),
                        subtitle: Text(
                          c.levels.entries
                              .map(
                                (e) =>
                                    '${e.key.label(l)} ${store.grades(e.value)}',
                              )
                              .join(' · '),
                          style: const TextStyle(color: Mountain.granite),
                        ),
                        onTap: () => showProfileSheet(context, c),
                      ),
                  ],
                  const SizedBox(height: 8),
                  ProfileDetails(organizer, compact: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
