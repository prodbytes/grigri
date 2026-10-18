import 'package:flutter/material.dart';

import '../data/grigri_store.dart';
import '../model/plan.dart';
import '../theme.dart';
import 'chat_screen.dart';
import 'common.dart';
import 'team_chat_screen.dart';

/// The chats: the Grigri team chat always on top (specs/team-chat.md),
/// then the group chats, one per plan I'm in, most recent first, with how
/// many join requests in each wait for my answer. Admins also see every
/// climber's team chat, under "Team chats".
class ChatsScreen extends StatelessWidget {
  const ChatsScreen({super.key, required this.onDiscover});

  /// Goes to Discover, when there are no chats yet.
  final VoidCallback onDiscover;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final text = Theme.of(context).textTheme;
    final l = context.l10n;
    // A photo or video says so (its text, if any, after).
    String preview(Message m) => switch (m.attachment?.kind) {
      null => m.text,
      final kind =>
        '${kind == MediaKind.video ? '🎬' : '📷'} '
            '${m.text.isEmpty ? (kind == MediaKind.video ? l.videoMessage : l.photoMessage) : m.text}',
    };
    final chats =
        [
          for (final plan in store.myPlans)
            (plan: plan, last: store.messages(plan.id).lastOrNull),
        ]..sort((a, b) {
          final ta = a.last?.time ?? a.plan.start ?? DateTime(0);
          final tb = b.last?.time ?? b.plan.start ?? DateTime(0);
          return tb.compareTo(ta);
        });
    int toAnswer(String planId) =>
        store.toReview.where((r) => r.planId == planId).length;
    Widget planTile(int i) {
      final (:plan, :last) = chats[i];
      final author = last?.authorId == null
          ? null
          : last!.authorId == store.me.id
          ? l.you
          : store.climber(last.authorId!).firstName;
      return ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: const Color(0xFF2B4152),
          child: Text(
            plan.discipline.emoji,
            style: const TextStyle(fontSize: 22),
          ),
        ),
        title: Text(
          plan.title,
          style: text.titleMedium?.copyWith(color: Mountain.sand),
        ),
        subtitle: Text(
          last == null
              ? l.climberCount(plan.memberIds.length)
              : author == null
              ? preview(last)
              : l.messagePreview(author, preview(last)),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Mountain.granite),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              daysLabel(context, plan),
              style: text.labelSmall?.copyWith(color: Mountain.granite),
            ),
            if (toAnswer(plan.id) > 0) ...[
              const SizedBox(height: 4),
              Badge(
                label: Text(l.toAnswer(toAnswer(plan.id))),
                backgroundColor: Mountain.sky,
                textColor: Mountain.night,
              ),
            ],
          ],
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => ChatScreen(planId: plan.id)),
        ),
      );
    }

    void openTeam([String? climberId]) => Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TeamChatScreen(climberId: climberId),
      ),
    );
    const divider = Divider(height: 1, indent: 76);
    final teamChats = store.admin ? store.teamChats : const [];
    return Scaffold(
      appBar: AppBar(title: Text(l.chatsTitle)),
      body: !store.isLoaded(Section.plans)
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                // Always there: the Grigri team chat.
                ListTile(
                  key: const ValueKey('team chat'),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  leading: const TeamAvatar(radius: 24),
                  title: Text(
                    l.teamChatTitle,
                    style: text.titleMedium?.copyWith(color: Mountain.sand),
                  ),
                  subtitle: Text(
                    teamPreview(context, store.teamMessages),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Mountain.granite),
                  ),
                  trailing: store.teamUnread && !store.admin
                      ? const Badge(
                          smallSize: 10,
                          backgroundColor: Mountain.sky,
                        )
                      : null,
                  onTap: openTeam,
                ),
                divider,
                if (chats.isEmpty)
                  EmptyState(
                    icon: Icons.forum_outlined,
                    title: l.noChatsTitle,
                    message: l.noChatsMessage,
                    action: FilledButton.icon(
                      icon: const Icon(Icons.landscape_outlined),
                      label: Text(l.findPlan),
                      onPressed: onDiscover,
                    ),
                  )
                else
                  for (var i = 0; i < chats.length; i++) ...[
                    if (i > 0) divider,
                    planTile(i),
                  ],
                if (teamChats.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
                    child: Text(
                      l.teamChatsSection.toUpperCase(),
                      style: text.labelSmall?.copyWith(
                        color: Mountain.sky,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ),
                  for (final (i, c) in teamChats.indexed) ...[
                    if (i > 0) divider,
                    ListTile(
                      key: ValueKey('team chat ${c.climberId}'),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      leading: Avatar(store.climber(c.climberId), radius: 24),
                      title: Text(
                        store.climber(c.climberId).name,
                        style: text.titleMedium?.copyWith(color: Mountain.sand),
                      ),
                      subtitle: Text(
                        c.lastFromTeam
                            ? l.messagePreview(l.teamChatTitle, c.lastText)
                            : c.lastText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Mountain.granite),
                      ),
                      // Waiting for the team's answer.
                      trailing: c.lastFromTeam
                          ? null
                          : Badge(
                              label: Text(l.teamAwaitingAnswer),
                              backgroundColor: Mountain.sky,
                              textColor: Mountain.night,
                            ),
                      onTap: () => openTeam(c.climberId),
                    ),
                  ],
                ],
              ],
            ),
    );
  }
}
