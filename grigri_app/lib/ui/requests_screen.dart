import 'package:flutter/material.dart';

import '../data/grigri_store.dart';
import '../model/plan.dart';
import '../theme.dart';
import 'common.dart';
import 'notices_screen.dart';
import 'match_screen.dart';
import 'swipe_deck.dart';

/// The people deck: who asked to join plans I'm in. Swipe right (or ✓) to
/// accept, left to turn them down. They join when every member accepts.
class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> {
  final _controller = SwipeController();

  void _swiped(GrigriStore store, JoinRequest request, {required bool right}) {
    if (!right) {
      store.reject(request.id);
      return;
    }
    final match = store.accept(request.id);
    if (match != null) {
      MatchScreen.show(context, match);
    } else {
      final name = store.climber(request.climberId).name.split(' ').first;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'You said yes to $name. Waiting for the rest of the group.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final requests = store.toReview;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Requests'),
        actions: const [NoticesButton()],
      ),
      body: requests.isEmpty
          ? const EmptyState(
              icon: Icons.group_add_outlined,
              title: 'No one to review',
              message:
                  'When climbers ask to join a plan you\'re in, they show up '
                  'here. Everyone in the group must say yes.',
            )
          : Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: SwipeDeck<JoinRequest>(
                          items: requests,
                          keyOf: (r) => r.id,
                          controller: _controller,
                          yesLabel: 'ACCEPT',
                          noLabel: 'DECLINE',
                          onSwiped: (r, {required right}) =>
                              _swiped(store, r, right: right),
                          builder: (context, r) => _PersonCard(request: r),
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
                        tooltip: 'Decline',
                        onPressed: () => _controller.swipe(right: false),
                      ),
                      const SizedBox(width: 40),
                      DeckButton(
                        icon: Icons.check,
                        color: Mountain.olive,
                        filled: true,
                        tooltip: 'Accept',
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

/// Someone asking to join: their profile first, the plan they want above
/// it, and who in the group has said yes.
class _PersonCard extends StatelessWidget {
  const _PersonCard({required this.request});

  final JoinRequest request;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final text = Theme.of(context).textTheme;
    final plan = store.plan(request.planId)!;
    final person = store.climber(request.climberId);
    final others = plan.memberIds.where((id) => id != store.me.id);
    final yes = [
      for (final id in others)
        if (request.acceptedBy.contains(id))
          store.climber(id).name.split(' ').first,
    ];
    final pending = [
      for (final id in others)
        if (!request.acceptedBy.contains(id))
          store.climber(id).name.split(' ').first,
    ];
    final level = person.levels[plan.discipline];
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF2B4152),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Mountain.sky.withValues(alpha: 0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'WANTS TO JOIN',
                    style: text.labelSmall?.copyWith(
                      color: Mountain.sky,
                      letterSpacing: 1.6,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${plan.discipline.emoji} ${plan.title}',
                    style: text.titleMedium?.copyWith(
                      color: Mountain.sand,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${plan.place} · ${whenLabel(plan)} · ${plan.grades.label}',
                    style: text.bodySmall?.copyWith(color: Mountain.snow),
                  ),
                  if (others.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      [
                        if (yes.isNotEmpty) '${yes.join(', ')} said yes',
                        if (pending.isNotEmpty)
                          'waiting for ${pending.join(', ')}',
                      ].join(' · '),
                      style: text.bodySmall?.copyWith(color: Mountain.sky),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 22),
            Center(child: Avatar(person, radius: 52)),
            const SizedBox(height: 12),
            Center(
              child: Text(
                person.nameAndAge,
                style: text.headlineSmall?.copyWith(
                  color: Mountain.sand,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Center(
              child: Text(
                [
                  if (person.homeArea.isNotEmpty) person.homeArea,
                  if (person.yearsClimbing > 0)
                    '${person.yearsClimbing} years climbing',
                ].join(' · '),
                style: text.bodyMedium?.copyWith(color: Mountain.granite),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: Tag(
                level == null
                    ? 'No ${plan.discipline.label.toLowerCase()} grades yet'
                    : '${plan.discipline.label} ${level.label}',
                icon: level != null && level.overlaps(plan.grades)
                    ? Icons.check
                    : Icons.info_outline,
                color: level != null && level.overlaps(plan.grades)
                    ? Mountain.olive
                    : Mountain.tan,
              ),
            ),
            const SizedBox(height: 6),
            ProfileDetails(person),
          ],
        ),
      ),
    );
  }
}
