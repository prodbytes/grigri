import 'package:flutter/material.dart';

import '../theme.dart';
import 'chat_screen.dart';
import 'common.dart';

/// The group chats: one per plan I'm in, most recent first.
class ChatsScreen extends StatelessWidget {
  const ChatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final text = Theme.of(context).textTheme;
    final chats =
        [
          for (final plan in store.myPlans)
            (plan: plan, last: store.messages(plan.id).lastOrNull),
        ]..sort((a, b) {
          final ta = a.last?.time ?? a.plan.start;
          final tb = b.last?.time ?? b.plan.start;
          return tb.compareTo(ta);
        });
    return Scaffold(
      appBar: AppBar(title: const Text('Chats')),
      body: chats.isEmpty
          ? const EmptyState(
              icon: Icons.forum_outlined,
              title: 'No chats yet',
              message: 'When you match on a plan, its group chat opens here.',
            )
          : ListView.separated(
              itemCount: chats.length,
              separatorBuilder: (_, _) => const Divider(height: 1, indent: 76),
              itemBuilder: (context, i) {
                final (:plan, :last) = chats[i];
                final author = last?.authorId == null
                    ? null
                    : last!.authorId == store.me.id
                    ? 'You'
                    : store.climber(last.authorId!).name.split(' ').first;
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
                        ? '${plan.memberIds.length} climbers'
                        : author == null
                        ? last.text
                        : '$author: ${last.text}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Mountain.granite),
                  ),
                  trailing: Text(
                    dayLabel(plan.start),
                    style: text.labelSmall?.copyWith(color: Mountain.granite),
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
