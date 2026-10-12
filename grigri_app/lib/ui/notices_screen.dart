import 'package:flutter/material.dart';

import '../model/plan.dart';
import '../theme.dart';
import 'chat_screen.dart';
import 'common.dart';
import 'plan_screen.dart';

/// The Notifications tab: someone asked to join a plan I'm in, or a group
/// accepted or declined my request, newest first. The tabs mark them read
/// when I open it; [fresh] are the ones that were unread then, highlighted
/// along with any that arrive while it's open.
class NoticesScreen extends StatelessWidget {
  const NoticesScreen({super.key, this.fresh = const {}});

  final Set<String> fresh;

  @override
  Widget build(BuildContext context) {
    final notices = StoreScope.of(context).notices;
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: notices.isEmpty
          ? const EmptyState(
              icon: Icons.notifications_none,
              title: 'Nothing yet',
              message:
                  'When someone asks to join a plan you\'re in, or a group '
                  'answers your request, you\'ll hear about it here.',
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
    final (icon, color, title, body) = switch (notice.kind) {
      NoticeKind.request => (
        Icons.group_add,
        Mountain.sky,
        '${store.climber(notice.climberId!).name} wants to join',
        '${notice.planTitle} · answer in the group chat',
      ),
      NoticeKind.accepted => (
        Icons.check_circle,
        Mountain.olive,
        'You\'re in: ${notice.planTitle}',
        'The group accepted you. Say hi in the chat.',
      ),
      NoticeKind.declined => (
        Icons.cancel,
        Mountain.clay,
        'Not this time: ${notice.planTitle}',
        'The group declined your request.',
      ),
    };
    final Widget? open = switch (notice.kind) {
      NoticeKind.request ||
      NoticeKind.accepted => ChatScreen(planId: notice.planId),
      NoticeKind.declined =>
        store.plan(notice.planId) == null
            ? null
            : PlanScreen(planId: notice.planId),
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
          '$body\n${dayLabel(notice.time)}, ${clock(notice.time)}',
          style: const TextStyle(color: Mountain.granite),
        ),
        isThreeLine: true,
        trailing: isNew ? const Tag('New', color: Mountain.sky) : null,
        onTap: open == null
            ? null
            : () =>
                  Navigator.of(context)
                      .push(MaterialPageRoute<void>(builder: (_) => open)),
      ),
    );
  }
}
