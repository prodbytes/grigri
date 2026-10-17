import 'package:flutter/material.dart';

import '../data/grigri_store.dart';
import '../model/climber.dart';
import '../model/report.dart';
import '../theme.dart';
import 'common.dart';

// Reporting and blocking (specs/moderation.md): the ⋮ menu on profile
// sheets, plans, Discover cards and ads, the long press on chat messages,
// Profile → Blocked people, and Admin → Reports.

/// What a Report sends: the content's kind and id (and a message's or
/// photo's plan).
class ReportTarget {
  const ReportTarget(this.kind, this.targetId, {this.planId});

  final ReportKind kind;
  final String targetId;
  final String? planId;
}

/// The ⋮ menu: **Report** (when there's something to report) and
/// **Block** them (when there's someone, not me, to block). Nothing for
/// my own things.
class ModerationMenu extends StatelessWidget {
  const ModerationMenu({super.key, this.report, this.person, this.color});

  final ReportTarget? report;

  /// Whose it is, to block.
  final Climber? person;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final l = context.l10n;
    final someone = person != null && person!.id.isNotEmpty;
    final mine = someone && person!.id == store.me.id;
    if (mine || (report == null && !someone)) return const SizedBox.shrink();
    final blockable = someone && !store.hasBlocked(person!.id);
    return PopupMenuButton<String>(
      key: const ValueKey('moderation menu'),
      tooltip: l.moreActions,
      icon: Icon(Icons.more_vert, color: color),
      onSelected: (choice) {
        if (choice == 'report') showReportDialog(context, report!);
        if (choice == 'block') confirmBlockPerson(context, person!);
      },
      itemBuilder: (context) => [
        if (report != null)
          PopupMenuItem(
            value: 'report',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.flag_outlined),
              title: Text(l.report),
            ),
          ),
        if (blockable)
          PopupMenuItem(
            value: 'block',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.block, color: Mountain.clay),
              title: Text(l.blockPerson(person!.name)),
            ),
          ),
      ],
    );
  }
}

/// The long press on a chat message: Report it, or Block its author.
Future<void> showMessageActions(
  BuildContext context, {
  required ReportTarget report,
  required Climber author,
}) {
  final store = StoreScope.read(context);
  final l = context.l10n;
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Mountain.surface,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.flag_outlined),
            title: Text(l.report),
            onTap: () {
              Navigator.pop(sheet);
              showReportDialog(context, report);
            },
          ),
          if (!store.hasBlocked(author.id))
            ListTile(
              leading: const Icon(Icons.block, color: Mountain.clay),
              title: Text(l.blockPerson(author.name)),
              onTap: () {
                Navigator.pop(sheet);
                confirmBlockPerson(context, author);
              },
            ),
        ],
      ),
    ),
  );
}

/// Asks why (spam, harassment, inappropriate, fake profile, other) and,
/// optionally, more; sends the report and thanks me: it's reviewed within
/// 24 hours.
Future<void> showReportDialog(BuildContext context, ReportTarget target) async {
  final store = StoreScope.read(context);
  final messenger = ScaffoldMessenger.of(context);
  final l = context.l10n;
  final sent = await showDialog<bool>(
    context: context,
    builder: (_) => StoreScope(store: store, child: _ReportDialog(target)),
  );
  if (sent == true) {
    messenger.showSnackBar(SnackBar(content: Text(l.reportThanks)));
  }
}

class _ReportDialog extends StatefulWidget {
  const _ReportDialog(this.target);

  final ReportTarget target;

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  ReportReason? _reason;
  final _text = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final reason = _reason;
    if (reason == null) return;
    setState(() => _sending = true);
    final ok = await StoreScope.read(context).sendReport(
      kind: widget.target.kind,
      targetId: widget.target.targetId,
      planId: widget.target.planId,
      reason: reason,
      text: _text.text,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
    } else {
      setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(l.reportTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final reason in ReportReason.values)
                  ChoiceChip(
                    key: ValueKey('reason ${reason.name}'),
                    label: Text(reasonLabel(context, reason)),
                    selected: _reason == reason,
                    onSelected: (_) => setState(() => _reason = reason),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey('report text'),
              controller: _text,
              maxLength: 500,
              maxLines: 3,
              minLines: 1,
              decoration: InputDecoration(hintText: l.reportDetailsHint),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.pop(context, false),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: _reason == null || _sending ? null : _send,
          child: Text(l.reportSend),
        ),
      ],
    );
  }
}

String reasonLabel(BuildContext context, ReportReason reason) {
  final l = context.l10n;
  return switch (reason) {
    ReportReason.spam => l.reportReasonSpam,
    ReportReason.harassment => l.reportReasonHarassment,
    ReportReason.inappropriate => l.reportReasonInappropriate,
    ReportReason.fake => l.reportReasonFake,
    ReportReason.other => l.reportReasonOther,
  };
}

String reportKindLabel(BuildContext context, ReportKind kind) {
  final l = context.l10n;
  return switch (kind) {
    ReportKind.profile => l.reportKindProfile,
    ReportKind.plan => l.reportKindPlan,
    ReportKind.message => l.reportKindMessage,
    ReportKind.pic => l.reportKindPic,
    ReportKind.ad => l.reportKindAd,
  };
}

/// "Block them?", saying what it does; blocks them on yes.
Future<void> confirmBlockPerson(BuildContext context, Climber person) async {
  final store = StoreScope.read(context);
  final messenger = ScaffoldMessenger.of(context);
  final l = context.l10n;
  final yes = await showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: Text(l.blockNameQuestion(person.name)),
      content: Text(l.blockPersonMessage),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialog, false),
          child: Text(l.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialog, true),
          child: Text(l.block, style: const TextStyle(color: Mountain.clay)),
        ),
      ],
    ),
  );
  if (yes != true) return;
  if (await store.setPersonBlocked(person.id, true)) {
    messenger.showSnackBar(
      SnackBar(content: Text(l.blockedPersonDone(person.name))),
    );
  }
}

/// Profile → Blocked people: who I blocked, each with **Unblock**.
class BlockedPeopleScreen extends StatefulWidget {
  const BlockedPeopleScreen({super.key});

  @override
  State<BlockedPeopleScreen> createState() => _BlockedPeopleScreenState();
}

class _BlockedPeopleScreenState extends State<BlockedPeopleScreen> {
  @override
  void initState() {
    super.initState();
    StoreScope.read(context).refreshBlocks();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final people = store.blockedPeople;
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.blockedPeopleTitle)),
      body: !store.isLoaded(Section.blocks)
          ? const Center(child: CircularProgressIndicator())
          : people.isEmpty
          ? EmptyState(
              icon: Icons.block,
              title: l.blockedPeopleTitle,
              message: l.blockedPeopleEmpty,
            )
          : ListView(
              children: [
                for (final p in people)
                  ListTile(
                    key: ValueKey('blocked ${p.id}'),
                    leading: Avatar(p),
                    title: Text(p.name),
                    trailing: OutlinedButton(
                      onPressed: () => store.setPersonBlocked(p.id, false),
                      child: Text(l.unblock),
                    ),
                  ),
              ],
            ),
    );
  }
}

/// Admin → Reports: the open reports, oldest first, each with what was
/// reported (its text and photos), whose it is, who reported it and why,
/// and **Dismiss**, **Remove content** and **Block climber**.
class AdminReportsView extends StatefulWidget {
  const AdminReportsView({super.key});

  @override
  State<AdminReportsView> createState() => _AdminReportsViewState();
}

class _AdminReportsViewState extends State<AdminReportsView> {
  @override
  void initState() {
    super.initState();
    StoreScope.read(context).refreshAdminReports();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final reports = store.adminReports;
    final l = context.l10n;
    return RefreshIndicator(
      onRefresh: store.refreshAdminReports,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          if (!store.isLoaded(Section.adminReports))
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (reports.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  l.adminReportsEmpty,
                  style: const TextStyle(color: Mountain.granite),
                ),
              ),
            )
          else
            for (final r in reports) _ReportCard(r),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard(this.report);

  final Report report;

  Future<bool> _confirmBlock(BuildContext context, String name) async {
    final l = context.l10n;
    return await showDialog<bool>(
          context: context,
          builder: (dialog) => AlertDialog(
            title: Text(l.blockNameQuestion(name)),
            content: Text(l.blockMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialog, false),
                child: Text(l.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialog, true),
                child: Text(
                  l.block,
                  style: const TextStyle(color: Mountain.clay),
                ),
              ),
            ],
          ),
        ) ==
        true;
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final l = context.l10n;
    final subject = store.climber(report.subjectId);
    final reporter = store.climber(report.reporterId);
    final content = report.content;
    return Card(
      key: ValueKey('report ${report.id}'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Wraps on narrow phones.
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Tag(reportKindLabel(context, report.kind), color: Mountain.tan),
                Tag(reasonLabel(context, report.reason), color: Mountain.clay),
                Text(
                  dayAndTime(context, report.time),
                  style: const TextStyle(color: Mountain.granite),
                ),
              ],
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Avatar(subject),
              title: Text(subject.name),
              subtitle: Text(
                l.reportedBy(reporter.name),
                style: const TextStyle(color: Mountain.granite),
              ),
              onTap: () => showProfileSheet(context, subject),
            ),
            if (report.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '“${report.text}”',
                  style: const TextStyle(fontStyle: FontStyle.italic),
                ),
              ),
            // What was reported, as it was then.
            DecoratedBox(
              decoration: BoxDecoration(
                color: Mountain.surfaceHigh,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (content.title case final title? when title.isNotEmpty)
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    if (content.text case final text? when text.isNotEmpty)
                      Text(text),
                    if (content.link case final link?)
                      Text(link, style: const TextStyle(color: Mountain.sky)),
                    if (content.media.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final m in content.media)
                              m.video
                                  ? const Icon(
                                      Icons.videocam,
                                      size: 48,
                                      color: Mountain.granite,
                                    )
                                  : PhotoThumb(
                                      store.photo(m.key),
                                      label: reportKindLabel(
                                        context,
                                        report.kind,
                                      ),
                                    ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              alignment: WrapAlignment.end,
              children: [
                TextButton(
                  onPressed: () =>
                      store.resolveReport(report, ReportAction.dismiss),
                  child: Text(l.reportDismiss),
                ),
                OutlinedButton(
                  onPressed: () =>
                      store.resolveReport(report, ReportAction.remove),
                  child: Text(l.reportRemove),
                ),
                if (report.subjectId != store.me.id)
                  TextButton(
                    onPressed: () async {
                      if (!await _confirmBlock(context, subject.name)) return;
                      await store.resolveReport(report, ReportAction.block);
                    },
                    child: Text(
                      l.reportBlock,
                      style: const TextStyle(color: Mountain.clay),
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
