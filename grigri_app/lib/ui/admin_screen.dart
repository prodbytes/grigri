import 'package:flutter/material.dart';

import '../data/grigri_store.dart';
import '../model/match_score.dart';
import '../model/plan.dart';
import '../theme.dart';
import 'common.dart';
import 'match_score.dart';

/// The Admin tab (admins only): a preview of the latest match scoring
/// run, then every open join request, anyone's, to approve (they join
/// now, as if every member had said yes) or reject.
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
          : RefreshIndicator(
              onRefresh: store.refreshAdmin,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const _ScoresPreview(),
                  const SizedBox(height: 16),
                  if (requests.isEmpty)
                    EmptyState(
                      icon: Icons.verified_outlined,
                      title: l.noOpenRequestsTitle,
                      message: l.noOpenRequestsMessage,
                    )
                  else
                    for (final r in requests) _AdminRequestTile(request: r),
                ],
              ),
            ),
    );
  }
}

/// The latest match scoring run (scripts/score-matches.sh): when, how
/// many pairs, and its best scores: who, which plan, how likely.
class _ScoresPreview extends StatelessWidget {
  const _ScoresPreview();

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final run = store.scoreRun;
    final scores = store.adminScores;
    final text = Theme.of(context).textTheme;
    final l = context.l10n;
    return Card(
      key: const ValueKey('admin scores'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.insights_outlined, color: Mountain.sky),
                const SizedBox(width: 8),
                Text(l.adminScoresTitle, style: text.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            if (run == null)
              Text(
                l.adminScoresNone,
                style: const TextStyle(color: Mountain.granite),
              )
            else ...[
              Text(
                l.adminScoresRun(
                  dayLabel(context, run.finishedAt),
                  clock(run.finishedAt),
                  run.scored,
                  run.pairs,
                  run.climbers,
                  run.plans,
                ),
                style: const TextStyle(color: Mountain.granite),
              ),
              if (run.failed > 0 || run.skipped > 0)
                Text(
                  l.adminScoresProblems(run.failed, run.skipped),
                  style: const TextStyle(color: Mountain.clay),
                ),
              const SizedBox(height: 6),
              if (scores.isEmpty)
                Text(
                  l.adminScoresEmpty,
                  style: const TextStyle(color: Mountain.granite),
                )
              else
                for (final s in scores) _ScoreRow(pair: s),
            ],
          ],
        ),
      ),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({required this.pair});

  final ScoredPair pair;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final person = store.climber(pair.climberId);
    final plan = store.plan(pair.planId);
    final l = context.l10n;
    return ListTile(
      key: ValueKey('score ${pair.climberId} ${pair.planId}'),
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Avatar(person),
      title: Text(
        '${person.name} → ${plan == null ? l.aPlan : '${plan.discipline.emoji} ${plan.place}'}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        pair.match.reason.label(l),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Mountain.granite),
      ),
      trailing: MatchScoreTag(pair.match, compact: true),
      onTap: () => showProfileSheet(context, person),
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
