import 'package:flutter/material.dart';

import '../data/grigri_store.dart';
import '../model/plan.dart';
import '../theme.dart';
import 'common.dart';
import 'plan_screen.dart';

/// My plans: the ones I'm in (organizing, or accepted into), each with a
/// menu to cancel it, and the ones I asked to join: pending while the
/// group decides, or declined.
class PlansScreen extends StatelessWidget {
  const PlansScreen({super.key, required this.onCreatePlan});

  final VoidCallback onCreatePlan;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final text = Theme.of(context).textTheme;
    final mine = store.myPlans;
    final waiting = store.waiting;
    final declined = store.declined;
    final l = context.l10n;
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
      appBar: AppBar(title: Text(l.yourPlans)),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: Text(l.newPlan),
        onPressed: onCreatePlan,
      ),
      body: !store.isLoaded(Section.plans)
          ? const Center(child: CircularProgressIndicator())
          : mine.isEmpty && waiting.isEmpty && declined.isEmpty
          ? EmptyState(
              icon: Icons.event_note_outlined,
              title: l.noPlansYetTitle,
              message: l.noPlansYetMessage,
              action: FilledButton.icon(
                icon: const Icon(Icons.add),
                label: Text(l.newPlan),
                onPressed: onCreatePlan,
              ),
            )
          : RefreshIndicator(
              onRefresh: store.refreshPlans,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                children: [
                  if (mine.isNotEmpty) heading(l.plansClimbing),
                  for (final plan in mine) _PlanTile(plan: plan),
                  if (waiting.isNotEmpty || declined.isNotEmpty)
                    heading(l.plansAskedToJoin),
                  for (final r in waiting) _RequestTile(request: r),
                  for (final r in declined) _RequestTile(request: r),
                ],
              ),
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
    final l = context.l10n;
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
                      whenLabel(context, plan),
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
                        if (plan.organizerId == store.me.id)
                          Tag(l.organizing, color: Mountain.tan)
                        else
                          Tag(
                            l.accepted,
                            icon: Icons.check,
                            color: Mountain.olive,
                          ),
                        if (toReview > 0)
                          Tag(l.toReview(toReview), color: Mountain.sky),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Mountain.granite),
                onSelected: (_) => cancelPlan(context, plan),
                itemBuilder: (_) => [
                  PopupMenuItem<String>(
                    value: 'cancel',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.logout, color: Mountain.clay),
                      title: Text(
                        l.cancelPlan,
                        style: const TextStyle(color: Mountain.clay),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A plan I asked to join: pending, and who it's waiting for, or
/// declined, which I can dismiss.
class _RequestTile extends StatelessWidget {
  const _RequestTile({required this.request});

  final JoinRequest request;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final text = Theme.of(context).textTheme;
    final plan = store.plan(request.planId);
    if (plan == null) return const SizedBox.shrink();
    final l = context.l10n;
    final pending = [
      for (final id in plan.memberIds)
        if (!request.acceptedBy.contains(id)) store.climber(id).firstName,
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
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${plan.place} · ${dayLabel(context, plan.start)}\n'
              '${request.rejected ? l.groupSaidNo : l.waitingForNames(pending.join(', '))}',
              style: text.bodyMedium?.copyWith(color: Mountain.granite),
            ),
            const SizedBox(height: 6),
            request.rejected
                ? Tag(l.declined, icon: Icons.close, color: Mountain.clay)
                : Tag(
                    l.pending,
                    icon: Icons.hourglass_top,
                    color: Mountain.sky,
                  ),
          ],
        ),
        trailing: request.rejected
            ? IconButton(
                tooltip: l.dismiss,
                icon: const Icon(Icons.close, color: Mountain.granite),
                onPressed: () => store.dismiss(request),
              )
            : null,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => PlanScreen(planId: plan.id)),
        ),
      ),
    );
  }
}
