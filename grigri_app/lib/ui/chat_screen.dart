import 'package:flutter/material.dart';

import '../model/plan.dart';
import '../theme.dart';
import 'common.dart';
import 'plan_screen.dart';

/// A plan's group chat: everyone in the plan, with the plan pinned on top.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.planId});

  final String planId;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _send() {
    StoreScope.read(context).send(widget.planId, _input.text);
    _input.clear();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final plan = store.plan(widget.planId);
    if (plan == null || !plan.memberIds.contains(store.me.id)) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
          icon: Icons.forum_outlined,
          title: 'Not in this group',
          message: 'You left this plan, so its chat is closed.',
        ),
      );
    }
    final text = Theme.of(context).textTheme;
    final messages = store.messages(plan.id).reversed.toList();
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => PlanScreen(planId: plan.id),
            ),
          ),
          child: Row(
            children: [
              AvatarRow([
                for (final id in plan.memberIds) store.climber(id),
              ], radius: 14),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.title,
                      style: text.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${plan.memberIds.length} climbers · ${dayLabel(plan.start)}',
                      style: text.bodySmall?.copyWith(color: Mountain.granite),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          _PinnedPlan(plan: plan),
          Expanded(
            child: ListView.builder(
              reverse: true,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: messages.length,
              itemBuilder: (context, i) {
                final m = messages[i];
                final previous = i + 1 < messages.length
                    ? messages[i + 1]
                    : null;
                return _Bubble(
                  message: m,
                  mine: m.authorId == store.me.id,
                  showAuthor: previous?.authorId != m.authorId,
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 8, 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'Message the group',
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton.filled(
                    tooltip: 'Send',
                    icon: const Icon(Icons.send),
                    onPressed: _send,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The plan, small, above the messages.
class _PinnedPlan extends StatelessWidget {
  const _PinnedPlan({required this.plan});

  final Plan plan;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: const Color(0xFF2B4152),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Mountain.sky.withValues(alpha: 0.3)),
    ),
    child: Row(
      children: [
        Text(plan.discipline.emoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            '${plan.place} · ${whenLabel(plan)} · ${plan.grades.label}',
            style: const TextStyle(color: Mountain.snow),
          ),
        ),
      ],
    ),
  );
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.mine,
    required this.showAuthor,
  });

  final Message message;
  final bool mine;
  final bool showAuthor;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final text = Theme.of(context).textTheme;
    if (message.authorId == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Center(child: Tag(message.text, color: Mountain.granite)),
      );
    }
    final author = store.climber(message.authorId!);
    return Padding(
      padding: EdgeInsets.only(top: showAuthor ? 10 : 2),
      child: Row(
        mainAxisAlignment: mine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!mine) ...[
            showAuthor ? Avatar(author, radius: 14) : const SizedBox(width: 28),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: mine ? Mountain.pine : Mountain.surfaceHigh,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(mine ? 18 : 4),
                  bottomRight: Radius.circular(mine ? 4 : 18),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!mine && showAuthor)
                    Text(
                      author.name.split(' ').first,
                      style: text.labelMedium?.copyWith(color: Mountain.tan),
                    ),
                  Text(message.text, style: text.bodyMedium),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Text(
                      clock(message.time),
                      style: text.labelSmall?.copyWith(color: Mountain.granite),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
