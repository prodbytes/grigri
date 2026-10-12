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
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.adminTitle),
        actions: [
          IconButton(
            tooltip: l.refresh,
            icon: const Icon(Icons.refresh),
            onPressed: store.refreshAdmin,
          ),
        ],
      ),
      body: !store.isLoaded(Section.admin)
          ? const Center(child: CircularProgressIndicator())
          : requests.isEmpty
          ? EmptyState(
              icon: Icons.verified_outlined,
              title: l.noOpenRequestsTitle,
              message: l.noOpenRequestsMessage,
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
              child: Text(context.l10n.cancel),
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
    final l = context.l10n;
    final planTitle = plan?.title ?? l.aPlan;
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
                    : l.askedAt(
                        dayLabel(context, request.time!),
                        clock(request.time!),
                      ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              plan == null
                  ? planTitle
                  : [
                      '${plan.discipline.emoji} ${plan.place}',
                      if (plan.area.isNotEmpty) plan.area,
                      dayLabel(context, plan.start),
                    ].join(' · '),
              style: text.bodyMedium?.copyWith(color: Mountain.snow),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                Tag(
                  l.saidYesCount(yes, members),
                  icon: Icons.how_to_vote_outlined,
                  color: Mountain.sky,
                ),
                if (plan != null)
                  Tag(
                    store.grades(plan.grades),
                    icon: Icons.trending_up,
                    color: Mountain.olive,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.close, color: Mountain.clay),
                    label: Text(
                      l.reject,
                      style: const TextStyle(color: Mountain.clay),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Mountain.clay),
                    ),
                    onPressed: () async {
                      if (!await _confirm(
                        context,
                        title: l.rejectNameQuestion(person.name),
                        message: l.rejectMessage(planTitle),
                        action: l.reject,
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
                    label: Text(l.approve),
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      if (!await _confirm(
                        context,
                        title: l.approveNameQuestion(person.name),
                        message: l.approveMessage(planTitle),
                        action: l.approve,
                      )) {
                        return;
                      }
                      final match = await store.adminAccept(request);
                      if (match != null) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              l.adminJoined(
                                match.newcomer.name,
                                match.plan.title,
                              ),
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
