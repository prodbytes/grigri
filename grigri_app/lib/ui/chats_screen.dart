import 'package:flutter/material.dart';

import '../data/grigri_store.dart';
import '../theme.dart';
import 'chat_screen.dart';
import 'common.dart';

/// The group chats: one per plan I'm in, most recent first, with how many
/// join requests in each wait for my answer.
class ChatsScreen extends StatelessWidget {
  const ChatsScreen({super.key, required this.onDiscover});

  /// Goes to Discover, when there are no chats yet.
  final VoidCallback onDiscover;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final text = Theme.of(context).textTheme;
    final l = context.l10n;
    final chats =
        [
          for (final plan in store.myPlans)
            (plan: plan, last: store.messages(plan.id).lastOrNull),
        ]..sort((a, b) {
          final ta = a.last?.time ?? a.plan.start;
          final tb = b.last?.time ?? b.plan.start;
          return tb.compareTo(ta);
        });
    int toAnswer(String planId) =>
        store.toReview.where((r) => r.planId == planId).length;
    return Scaffold(
      appBar: AppBar(title: Text(l.chatsTitle)),
      body: !store.isLoaded(Section.plans)
          ? const Center(child: CircularProgressIndicator())
          : chats.isEmpty
          ? EmptyState(
              icon: Icons.forum_outlined,
              title: l.noChatsTitle,
              message: l.noChatsMessage,
              action: FilledButton.icon(
                icon: const Icon(Icons.landscape_outlined),
                label: Text(l.findPlan),
                onPressed: onDiscover,
              ),
            )
          : ListView.separated(
              itemCount: chats.length,
              separatorBuilder: (_, _) => const Divider(height: 1, indent: 76),
              itemBuilder: (context, i) {
                final (:plan, :last) = chats[i];
                final author = last?.authorId == null
                    ? null
                    : last!.authorId == store.me.id
                    ? l.you
                    : store.climber(last.authorId!).firstName;
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
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
                        ? last.text
                        : l.messagePreview(author, last.text),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Mountain.granite),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        dayLabel(context, plan.start),
                        style: text.labelSmall?.copyWith(
                          color: Mountain.granite,
                        ),
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
                    MaterialPageRoute<void>(
                      builder: (_) => ChatScreen(planId: plan.id),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
