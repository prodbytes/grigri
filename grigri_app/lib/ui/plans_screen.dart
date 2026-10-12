import 'package:flutter/material.dart';

import '../model/plan.dart';
import '../theme.dart';
import 'common.dart';
import 'plan_screen.dart';

/// My plans: the ones I'm in (organizing or joined), and the ones I asked
/// to join that are still waiting for the group.
class PlansScreen extends StatelessWidget {
  const PlansScreen({super.key, required this.onCreatePlan});

  final VoidCallback onCreatePlan;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final text = Theme.of(context).textTheme;
    final mine = store.myPlans;
    final waiting = store.waiting;
    Widget heading(String s) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Text(
        s.toUpperCase(),
        style: text.labelSmall?.copyWith(
          color: Mountain.granite,
          letterSpacing: 1.2,
        ),
      ),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Your plans')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('New plan'),
        onPressed: onCreatePlan,
      ),
      body: mine.isEmpty && waiting.isEmpty
          ? const EmptyState(
              icon: Icons.event_note_outlined,
              title: 'No plans yet',
              message:
                  'Make a plan (what, where, when) and climbers who fit will '
                  'ask to join. Or swipe right on one in Discover.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
              children: [
                if (mine.isNotEmpty) heading('Climbing'),
                for (final plan in mine) _PlanTile(plan: plan),
                if (waiting.isNotEmpty) heading('Waiting for the group'),
                for (final r in waiting) _WaitingTile(request: r),
              ],
            ),
    );
  }
}

class _PlanTile extends StatelessWidget {
  const _PlanTile({required this.plan});

  final Plan plan;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final text = Theme.of(context).textTheme;
    final toReview = store.toReview.where((r) => r.planId == plan.id).length;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => PlanScreen(planId: plan.id)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF2B4152),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  plan.discipline.emoji,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.title,
                      style: text.titleMedium?.copyWith(color: Mountain.sand),
                    ),
                    Text(
                      '${plan.place} · ${whenLabel(plan)}',
                      style: text.bodySmall?.copyWith(color: Mountain.granite),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        AvatarRow([
                          for (final id in plan.memberIds) store.climber(id),
                        ], radius: 12),
                        Text(
                          '${plan.memberIds.length}/${plan.spots}',
                          style: text.bodySmall?.copyWith(
                            color: Mountain.granite,
                          ),
                        ),
                        if (plan.organizerId == store.me.id)
                          const Tag('Organizing', color: Mountain.tan),
                        if (toReview > 0)
                          Tag('$toReview to review', color: Mountain.sky),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WaitingTile extends StatelessWidget {
  const _WaitingTile({required this.request});

  final JoinRequest request;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final plan = store.plan(request.planId)!;
    final pending = [
      for (final id in plan.memberIds)
        if (!request.acceptedBy.contains(id))
          store.climber(id).name.split(' ').first,
    ];
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Text(
          plan.discipline.emoji,
          style: const TextStyle(fontSize: 24),
        ),
        title: Text(plan.title),
        subtitle: Text(
          '${plan.place} · ${dayLabel(plan.start)}\nWaiting for ${pending.join(', ')}',
          style: const TextStyle(color: Mountain.granite),
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.hourglass_top, color: Mountain.sky),
      ),
    );
  }
}
