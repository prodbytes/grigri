import 'package:flutter/material.dart';

import '../model/plan.dart';
import '../model/report.dart';
import '../theme.dart';
import 'chat_screen.dart';
import 'common.dart';
import 'chat_media.dart';
import 'moderation.dart';
import 'plan_editor.dart';
import 'plan_gear.dart';
import 'plan_pics.dart';
import 'route_finder_screen.dart';

/// One plan I'm in, or asked to join: the plan, its photos ("Your Pics"
/// and GriGri Pics), its group, the group's gear against what the plan
/// needs, who's asking to join (answered in the group chat), and what I
/// can do with it.
class PlanScreen extends StatefulWidget {
  const PlanScreen({
    super.key,
    required this.planId,
    this.pick = pickChatMedia,
  });

  final String planId;

  /// Picks a photo for the plan's "Your Pics"; tests swap it.
  final ChatMediaPicker pick;

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  @override
  void initState() {
    super.initState();
    // After the first frame: loading notifies, which can't happen mid-build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final store = StoreScope.read(context);
      store.loadPlan(widget.planId);
      store.loadPics(widget.planId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final l = context.l10n;
    final plan = store.isGone(widget.planId) ? null : store.plan(widget.planId);
    if (plan == null) {
      return Scaffold(
        appBar: AppBar(),
        body: store.isLoadingPlan(widget.planId)
            ? const Center(child: CircularProgressIndicator())
            : EmptyState(
                icon: Icons.landscape_outlined,
                title: l.planGoneTitle,
                message: l.planGoneMessage,
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
        title: Text(organizing ? l.yourPlan : l.planTitle),
        actions: [
          if (organizing)
            IconButton(
              tooltip: l.edit,
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => PlanEditor(plan: plan)),
              ),
            ),
          // ⋮: report the plan, or block its organizer (not on my own).
          if (!organizing)
            ModerationMenu(
              report: ReportTarget(ReportKind.plan, plan.id),
              person: store.climber(plan.organizerId),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          PlanHighlight(plan),
          PlanPicsSections(plan: plan, pick: widget.pick),
          if (!member && mine != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: mine.rejected
                  ? Tag(
                      l.declinedGroupSaidNo,
                      icon: Icons.close,
                      color: Mountain.clay,
                    )
                  : Tag(
                      l.pendingSaidYes(
                        plan.deciders.where(mine.acceptedBy.contains).length,
                        plan.deciders.length,
                      ),
                      icon: Icons.hourglass_top,
                      color: Mountain.sky,
                    ),
            ),
          ],
          const SizedBox(height: 20),
          Text(
            l.theGroupCount(plan.memberIds.length).toUpperCase(),
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
              title: Text(id == store.me.id ? l.you : store.climber(id).name),
              subtitle: Text(
                id == plan.organizerId ? l.organizer : l.member,
                style: const TextStyle(color: Mountain.granite),
              ),
              onTap: () => showProfileSheet(context, store.climber(id)),
            ),
          const SizedBox(height: 16),
          PlanGearSection(plan),
          if (member && pending.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              l.askingToJoin.toUpperCase(),
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
                  l.saidYesCount(
                    plan.deciders.where(r.acceptedBy.contains).length,
                    plan.deciders.length,
                  ),
                  style: const TextStyle(color: Mountain.sky),
                ),
                trailing: !plan.deciders.contains(store.me.id)
                    ? Tag(l.theGuideDecides, color: Mountain.granite)
                    : r.acceptedBy.contains(store.me.id)
                    ? Tag(l.youSaidYes, color: Mountain.olive)
                    : Tag(l.answerInChat, color: Mountain.sky),
                onTap: () =>
                    showProfileSheet(context, store.climber(r.climberId)),
              ),
          ],
          const SizedBox(height: 24),
          // Premium: the routes on the rock, through the camera, where the
          // plan is (or, for a place typed by hand, where I am).
          // (Admins hold Premium too: rbacr's admin implies premium.)
          if (store.premium.active &&
              (plan.lat != null || store.me.location != null)) ...[
            OutlinedButton.icon(
              key: const ValueKey('route finder'),
              icon: const Icon(Icons.view_in_ar),
              label: Text(l.routeFinder),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => RouteFinderScreen(
                    lat: plan.lat ?? store.me.location!.lat,
                    lon: plan.lon ?? store.me.location!.lon,
                    place: plan.place,
                    cragId: plan.sectorId,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (member) ...[
            FilledButton.icon(
              icon: const Icon(Icons.forum_outlined),
              label: Text(l.groupChat),
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
                l.cancelPlan,
                style: const TextStyle(color: Mountain.clay),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Mountain.clay),
              ),
              onPressed: () async {
                final navigator = Navigator.of(context);
                if (await cancelPlan(context, plan)) navigator.pop();
              },
            ),
          ],
        ],
      ),
    );
  }
}

/// I cancel a plan I'm in, once I confirm: it leaves my plans and chats.
/// Alone, the plan is gone; otherwise the others keep it and, when I
/// organized it, one of them, picked at random, organizes it now. True
/// when cancelled.
Future<bool> cancelPlan(BuildContext context, Plan plan) async {
  final store = StoreScope.read(context);
  final l = context.l10n;
  final sure = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l.cancelPlanQuestion),
      content: Text(
        plan.memberIds.length == 1
            ? l.cancelPlanMessage
            : plan.organizerId == store.me.id
            ? l.cancelPlanOrganizerMessage
            : l.cancelPlanOthersMessage,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l.keepPlan),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(
            l.confirmCancelPlan,
            style: const TextStyle(color: Mountain.clay),
          ),
        ),
      ],
    ),
  );
  if (sure != true || !context.mounted) return false;
  return store.leave(plan.id);
}
