import 'package:flutter/material.dart';

import '../model/plan.dart';
import '../theme.dart';
import 'common.dart';
import 'plan_screen.dart';

/// The bell in the tabs' bars: opens my notifications, with a badge for
/// the unread ones.
class NoticesButton extends StatelessWidget {
  const NoticesButton({super.key});

  @override
  Widget build(BuildContext context) {
    final unread = StoreScope.of(context).unreadNotices;
    return IconButton(
      tooltip: 'Notifications',
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text('$unread'),
        backgroundColor: Mountain.sky,
        textColor: Mountain.night,
        child: Icon(
          unread > 0 ? Icons.notifications : Icons.notifications_outlined,
        ),
      ),
      onPressed: () => Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => const NoticesScreen())),
    );
  }
}

/// My notifications: groups that accepted or declined my requests to join,
/// newest first. Opening it marks them read; the ones that were new stay
/// highlighted while it's open.
class NoticesScreen extends StatefulWidget {
  const NoticesScreen({super.key});

  @override
  State<NoticesScreen> createState() => _NoticesScreenState();
}

class _NoticesScreenState extends State<NoticesScreen> {
  Set<String>? _new;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_new != null) return;
    final store = StoreScope.of(context);
    _new = {
      for (final n in store.notices)
        if (!n.read) n.id,
    };
    // Not during the build: the store's listeners rebuild.
    WidgetsBinding.instance.addPostFrameCallback((_) => store.readNotices());
  }

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
                  'When a group accepts or declines your request to join its '
                  'plan, you\'ll hear about it here.',
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final n in notices)
                  _NoticeTile(notice: n, isNew: _new!.contains(n.id)),
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
    final accepted = notice.kind == NoticeKind.accepted;
    final color = accepted ? Mountain.olive : Mountain.clay;
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
        leading: Icon(
          accepted ? Icons.check_circle : Icons.cancel,
          color: color,
          size: 30,
        ),
        title: Text(
          accepted
              ? 'You\'re in: ${notice.planTitle}'
              : 'Not this time: ${notice.planTitle}',
        ),
        subtitle: Text(
          '${accepted ? 'The group accepted you. Say hi in the chat.' : 'The group declined your request.'}'
          '\n${dayLabel(notice.time)}, ${clock(notice.time)}',
          style: const TextStyle(color: Mountain.granite),
        ),
        isThreeLine: true,
        trailing: isNew ? const Tag('New', color: Mountain.sky) : null,
        onTap: accepted
            ? () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => PlanScreen(planId: notice.planId),
                ),
              )
            : null,
      ),
    );
  }
}
