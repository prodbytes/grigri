import 'package:flutter/material.dart';

import '../data/grigri_store.dart';
import '../model/plan.dart';
import '../theme.dart';
import 'admin_screen.dart';
import 'chat_screen.dart';
import 'common.dart';
import 'plan_screen.dart';
import 'team_chat_screen.dart';

/// The Notifications tab: someone asked to join a plan I'm in (or nudged
/// me to answer), or a group accepted or declined my request, newest
/// first. The tabs mark them read
/// when I open it; [fresh] are the ones that were unread then, highlighted
/// along with any that arrive while it's open.
class NoticesScreen extends StatelessWidget {
  const NoticesScreen({super.key, this.fresh = const {}});

  final Set<String> fresh;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final notices = store.notices;
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.notificationsTitle)),
      body: !store.isLoaded(Section.notices)
          ? const Center(child: CircularProgressIndicator())
          : notices.isEmpty
          ? EmptyState(
              icon: Icons.notifications_none,
              title: l.nothingYetTitle,
              message: l.nothingYetMessage,
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final n in notices)
                  _NoticeTile(
                    notice: n,
                    isNew: !n.read || fresh.contains(n.id),
                  ),
              ],
            ),
    );
  }
}

class _NoticeTile extends StatelessWidget {
  const _NoticeTile({required this.notice, required this.isNew});

  final Notice notice;
  final bool isNew;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final l = context.l10n;
    final (icon, color, title, body) = switch (notice.kind) {
      NoticeKind.request => (
        Icons.group_add,
        Mountain.sky,
        l.noticeWantsToJoin(store.climber(notice.climberId ?? '').name),
        l.noticeAnswerInChat(notice.planTitle),
      ),
      NoticeKind.nudge => (
        Icons.notifications_active,
        Mountain.tan,
        l.noticeNudgeTitle(store.climber(notice.climberId ?? '').name),
        l.noticeNudgeBody(notice.planTitle),
      ),
      NoticeKind.accepted => (
        Icons.check_circle,
        Mountain.olive,
        l.noticeYoureIn(notice.planTitle),
        l.noticeAcceptedBody,
      ),
      NoticeKind.declined => (
        Icons.cancel,
        Mountain.clay,
        l.noticeNotThisTime(notice.planTitle),
        l.noticeDeclinedBody,
      ),
      NoticeKind.report => (
        Icons.flag,
        Mountain.tan,
        l.noticeReportsTitle,
        l.noticeReportsBody,
      ),
      // Not listed here (it badges Chats), but just in case.
      NoticeKind.team => (
        Icons.forum,
        Mountain.sky,
        l.teamChatTitle,
        l.teamMessageHint,
      ),
    };
    final Widget open = switch (notice.kind) {
      NoticeKind.request ||
      NoticeKind.nudge ||
      NoticeKind.accepted => ChatScreen(planId: notice.planId),
      NoticeKind.declined => PlanScreen(planId: notice.planId),
      NoticeKind.report => const AdminScreen(initialTab: 2),
      NoticeKind.team => const TeamChatScreen(),
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: isNew
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: Mountain.sky),
            )
          : null,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Icon(icon, color: color, size: 30),
        title: Text(title),
        subtitle: Text(
          '$body\n${dayAndTime(context, notice.time)}',
          style: const TextStyle(color: Mountain.granite),
        ),
        isThreeLine: true,
        trailing: isNew ? Tag(l.newTag, color: Mountain.sky) : null,
        onTap: () =>
            Navigator.of(context)
                .push(MaterialPageRoute<void>(builder: (_) => open)),
      ),
    );
  }
}
