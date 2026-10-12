import 'package:flutter/material.dart';

import '../data/grigri_store.dart';
import '../model/plan.dart';
import '../theme.dart';
import 'common.dart';

/// The Admin tab (admins only): every open join request, anyone's, to
/// approve (they join now, as if every member had said yes) or reject.
class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final requests = store.adminRequests;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin: join requests'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: store.refreshAdmin,
          ),
        ],
      ),
      body: !store.isLoaded(Section.admin)
          ? const Center(child: CircularProgressIndicator())
          : requests.isEmpty
          ? const EmptyState(
              icon: Icons.verified_outlined,
              title: 'No open requests',
              message:
                  'When anyone asks to join a plan, their request shows up '
                  'here for you to approve or reject.',
            )
          : RefreshIndicator(
              onRefresh: store.refreshAdmin,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final r in requests) _AdminRequestTile(request: r),
                ],
              ),
            ),
    );
  }
}

class _AdminRequestTile extends StatelessWidget {
  const _AdminRequestTile({required this.request});

  final JoinRequest request;

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String action,
    Color? color,
  }) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(action, style: TextStyle(color: color)),
            ),
          ],
        ),
      ) ==
      true;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final text = Theme.of(context).textTheme;
    final person = store.climber(request.climberId);
    final plan = store.plan(request.planId);
    final members = plan?.memberIds.length ?? 0;
    final yes = plan == null
        ? request.acceptedBy.length
        : plan.memberIds.where(request.acceptedBy.contains).length;
    final planTitle = plan?.title ?? 'a plan';
    return Card(
      key: ValueKey('admin ${request.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => showProfileSheet(context, person),
              child: ClimberHeader(
                person,
                radius: 22,
                subtitle: request.time == null
                    ? null
                    : 'Asked ${dayLabel(request.time!)}, ${clock(request.time!)}',
              ),
            ),
            const SizedBox(height: 10),
            Text(
              plan == null
                  ? planTitle
                  : '${plan.discipline.emoji} ${plan.title} · ${plan.place} · '
                        '${dayLabel(plan.start)}',
              style: text.bodyMedium?.copyWith(color: Mountain.snow),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                Tag(
                  '$yes of $members said yes',
                  icon: Icons.how_to_vote_outlined,
                  color: Mountain.sky,
                ),
                if (plan != null)
                  Tag(
                    plan.isFull
                        ? 'Full'
                        : '${plan.openSpots} of ${plan.spots} spots open',
                    color: plan.isFull ? Mountain.clay : Mountain.olive,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.close, color: Mountain.clay),
                    label: const Text(
                      'Reject',
                      style: TextStyle(color: Mountain.clay),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Mountain.clay),
                    ),
                    onPressed: () async {
                      if (!await _confirm(
                        context,
                        title: 'Reject ${person.name}?',
                        message:
                            'They won\'t join $planTitle, and they\'ll be told '
                            'the group declined.',
                        action: 'Reject',
                        color: Mountain.clay,
                      )) {
                        return;
                      }
                      await store.adminReject(request);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.check),
                    label: const Text('Approve'),
                    onPressed: plan != null && plan.isFull
                        ? null
                        : () async {
                            final messenger = ScaffoldMessenger.of(context);
                            if (!await _confirm(
                              context,
                              title: 'Approve ${person.name}?',
                              message:
                                  'They join $planTitle now, as if everyone '
                                  'in the group had said yes.',
                              action: 'Approve',
                            )) {
                              return;
                            }
                            final match = await store.adminAccept(request);
                            if (match != null) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '${match.newcomer.name} joined '
                                    '${match.plan.title}.',
                                  ),
                                ),
                              );
                            }
                          },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
