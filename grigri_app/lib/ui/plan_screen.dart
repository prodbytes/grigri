import 'package:flutter/material.dart';

import '../theme.dart';
import 'chat_screen.dart';
import 'common.dart';
import 'plan_editor.dart';

/// One plan I'm in, or asked to join: the plan, its group, who's asking to
/// join (answered in the group chat), and what I can do with it.
class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key, required this.planId});

  final String planId;

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  @override
  void initState() {
    super.initState();
    // After the first frame: loading notifies, which can't happen mid-build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) StoreScope.read(context).loadPlan(widget.planId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final plan = store.isGone(widget.planId) ? null : store.plan(widget.planId);
    if (plan == null) {
      return Scaffold(
        appBar: AppBar(),
        body: store.isLoadingPlan(widget.planId)
            ? const Center(child: CircularProgressIndicator())
            : const EmptyState(
                icon: Icons.landscape_outlined,
                title: 'Plan gone',
                message: 'Everyone left this plan, or it\'s no longer open.',
              ),
      );
    }
    final text = Theme.of(context).textTheme;
    final organizing = plan.organizerId == store.me.id;
    final member = plan.memberIds.contains(store.me.id);
    final mine = store.myRequest(plan.id);
    final pending = store
        .openRequests(plan.id)
        .where((r) => !r.rejected && !plan.memberIds.contains(r.climberId));
    return Scaffold(
      appBar: AppBar(
        title: Text(organizing ? 'Your plan' : 'Plan'),
        actions: [
          if (organizing)
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => PlanEditor(plan: plan)),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          PlanHighlight(plan),
          if (!member && mine != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: mine.rejected
                  ? const Tag(
                      'Declined: the group said no',
                      icon: Icons.close,
                      color: Mountain.clay,
                    )
                  : Tag(
                      'Pending: ${mine.acceptedBy.length} of '
                      '${plan.memberIds.length} said yes',
                      icon: Icons.hourglass_top,
                      color: Mountain.sky,
                    ),
            ),
          ],
          const SizedBox(height: 20),
          Text(
            'THE GROUP · ${plan.memberIds.length} OF ${plan.spots}',
            style: text.labelSmall?.copyWith(
              color: Mountain.granite,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          for (final id in plan.memberIds)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Avatar(store.climber(id)),
              title: Text(id == store.me.id ? 'You' : store.climber(id).name),
              subtitle: Text(
                id == plan.organizerId ? 'Organizer' : 'Member',
                style: const TextStyle(color: Mountain.granite),
              ),
              onTap: () => showProfileSheet(context, store.climber(id)),
            ),
          if (member && pending.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'ASKING TO JOIN',
              style: text.labelSmall?.copyWith(
                color: Mountain.granite,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            for (final r in pending)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Avatar(store.climber(r.climberId)),
                title: Text(store.climber(r.climberId).name),
                subtitle: Text(
                  '${r.acceptedBy.length} of ${plan.memberIds.length} said yes',
                  style: const TextStyle(color: Mountain.sky),
                ),
                trailing: r.acceptedBy.contains(store.me.id)
                    ? const Tag('You said yes', color: Mountain.olive)
                    : const Tag('Answer in the chat', color: Mountain.sky),
                onTap: () =>
                    showProfileSheet(context, store.climber(r.climberId)),
              ),
          ],
          const SizedBox(height: 24),
          if (member) ...[
            FilledButton.icon(
              icon: const Icon(Icons.forum_outlined),
              label: const Text('Group chat'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ChatScreen(planId: plan.id),
                ),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.logout, color: Mountain.clay),
              label: Text(
                plan.memberIds.length == 1
                    ? 'Cancel the plan'
                    : 'Leave the plan',
                style: const TextStyle(color: Mountain.clay),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Mountain.clay),
              ),
              onPressed: () async {
                final sure = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(
                      plan.memberIds.length == 1
                          ? 'Cancel the plan?'
                          : 'Leave the plan?',
                    ),
                    content: Text(
                      plan.memberIds.length == 1
                          ? 'It and its chat will be gone.'
                          : organizing
                          ? '${store.climber(plan.memberIds[1]).name} will organize it.'
                          : 'You can\'t rejoin it later.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Stay'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text(
                          'Leave',
                          style: TextStyle(color: Mountain.clay),
                        ),
                      ),
                    ],
                  ),
                );
                if (sure == true && context.mounted) {
                  final navigator = Navigator.of(context);
                  if (await store.leave(plan.id)) navigator.pop();
                }
              },
            ),
          ],
        ],
      ),
    );
  }
}
