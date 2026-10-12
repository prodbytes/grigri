import 'dart:async';
import 'dart:math' show max;

import 'package:flutter/material.dart';

import '../data/realtime.dart';
import '../model/plan.dart';
import '../theme.dart';
import 'common.dart';
import 'match_screen.dart';
import 'plan_screen.dart';

/// A plan's group chat: everyone in the plan, with the plan pinned on top.
/// Join requests show in it as cards the group answers: everyone must say
/// yes, and one no turns them down. The ones still waiting for my answer
/// are also called out on top, under the plan.
class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.planId,
    this.pollEvery = const Duration(seconds: 3),
    this.livePollEvery = const Duration(minutes: 1),
  });

  final String planId;

  /// How often it checks for new messages while it's open.
  final Duration pollEvery;

  /// How often instead while live updates are connected (their hints bring
  /// new messages; this is a safety net).
  final Duration livePollEvery;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();
  Timer? _poll;
  bool _sending = false;
  late final Cadence _cadence = Cadence(
    liveEvery: max(
      1,
      widget.livePollEvery.inMilliseconds ~/ widget.pollEvery.inMilliseconds,
    ),
  );

  @override
  void initState() {
    super.initState();
    // After the first frame: loading notifies, which can't happen mid-build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final store = StoreScope.read(context);
      store.loadPlan(widget.planId);
      store.pollMessages(widget.planId);
    });
    _poll = Timer.periodic(widget.pollEvery, (_) {
      // Only while the app is in the foreground.
      final state = WidgetsBinding.instance.lifecycleState;
      if (!mounted || (state != null && state != AppLifecycleState.resumed)) {
        return;
      }
      final store = StoreScope.read(context);
      if (_cadence.tick(live: store.live)) store.pollMessages(widget.planId);
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _input.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text;
    if (text.trim().isEmpty || _sending) return;
    setState(() => _sending = true);
    final sent = await StoreScope.read(context).send(widget.planId, text);
    if (!mounted) return;
    setState(() => _sending = false);
    if (sent) _input.clear();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final plan = store.plan(widget.planId);
    if (plan == null && !store.isGone(widget.planId)) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
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
          _AnswerCallout(plan: plan),
          Expanded(
            child: ListView.builder(
              reverse: true,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: messages.length,
              itemBuilder: (context, i) {
                final m = messages[i];
                if (m.requestId != null) {
                  return _RequestCard(message: m, planId: plan.id);
                }
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
                    onPressed: _sending ? null : _send,
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
            '${whenLabel(plan)} · ${StoreScope.of(context).grades(plan.grades)}',
            style: const TextStyle(color: Mountain.snow),
          ),
        ),
      ],
    ),
  );
}

/// People asking to join who still need my answer, pinned on top of the
/// chat so I don't miss them: who they are and Decline / Accept. Once I've
/// answered they leave it; their card in the messages stays as the record.
class _AnswerCallout extends StatelessWidget {
  const _AnswerCallout({required this.plan});

  final Plan plan;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final toAnswer = [
      for (final r in store.toReview)
        if (r.planId == plan.id) r,
    ];
    if (toAnswer.isEmpty) return const SizedBox.shrink();
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.35,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
        child: Column(
          children: [
            for (final r in toAnswer)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: _CalloutRow(request: r, plan: plan),
              ),
          ],
        ),
      ),
    );
  }
}

/// One person in the [_AnswerCallout].
class _CalloutRow extends StatelessWidget {
  const _CalloutRow({required this.request, required this.plan});

  final JoinRequest request;
  final Plan plan;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final text = Theme.of(context).textTheme;
    final person = store.climber(request.climberId);
    final yes = plan.memberIds.where(request.acceptedBy.contains).length;
    return Container(
      key: ValueKey('callout ${request.id}'),
      padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
      decoration: BoxDecoration(
        color: Mountain.tan.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Mountain.tan.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => showProfileSheet(context, person),
              child: Row(
                children: [
                  Avatar(person, radius: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'WANTS TO JOIN · YOUR ANSWER',
                          style: text.labelSmall?.copyWith(
                            color: Mountain.tan,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          person.name,
                          style: text.titleSmall?.copyWith(
                            color: Mountain.sand,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '$yes of ${plan.memberIds.length} said yes',
                          style: text.bodySmall?.copyWith(color: Mountain.sky),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: 'Decline ${person.name}',
            icon: const Icon(Icons.close, color: Mountain.clay),
            onPressed: () => store.reject(request),
          ),
          IconButton.filled(
            tooltip: 'Accept ${person.name}',
            icon: const Icon(Icons.check),
            onPressed: () async {
              final match = await store.accept(request);
              if (match != null && context.mounted) {
                MatchScreen.show(context, match);
              }
            },
          ),
        ],
      ),
    );
  }
}

/// Someone asking to join, in the chat: who they are, who has said yes,
/// and Accept / Decline until I've answered.
class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.message, required this.planId});

  final Message message;
  final String planId;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final text = Theme.of(context).textTheme;
    final plan = store.plan(planId)!;
    final requestId = message.requestId!;
    final climberId = requestId.substring(requestId.lastIndexOf('/') + 1);
    final open = store.openRequests(planId).where((r) => r.id == requestId);
    final request =
        open.firstOrNull ??
        JoinRequest(
          planId: planId,
          climberId: climberId,
          rejected: !plan.memberIds.contains(climberId),
        );
    final person = store.climber(request.climberId);
    final joined = plan.memberIds.contains(person.id);
    if (open.isEmpty && !joined && !store.knowsRequests(planId)) {
      // Still loading the plan's requests.
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Center(child: Tag(message.text, color: Mountain.granite)),
      );
    }
    // Closed without joining: declined (by me, for sure, when I did it).
    final closed = open.isEmpty && !joined;
    String first(String id) =>
        id == store.me.id ? 'You' : store.climber(id).firstName;
    final yes = [
      for (final id in plan.memberIds)
        if (request.acceptedBy.contains(id)) first(id),
    ];
    final waiting = [
      for (final id in plan.memberIds)
        if (!request.acceptedBy.contains(id) && id != person.id) first(id),
    ];
    final level = person.levels[plan.discipline];
    final fits = level != null && level.overlaps(plan.grades);
    final answering =
        !joined &&
        !closed &&
        !request.rejected &&
        !request.acceptedBy.contains(store.me.id);
    return Center(
      child: Container(
        key: ValueKey('request ${request.id}'),
        constraints: const BoxConstraints(maxWidth: 440),
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Mountain.surfaceHigh,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: answering
                ? Mountain.sky
                : Mountain.granite.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ASKED TO JOIN · ${clock(message.time)}',
              style: text.labelSmall?.copyWith(
                color: Mountain.sky,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => showProfileSheet(context, person),
              child: Row(
                children: [
                  Avatar(person, radius: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          person.nameAndAge,
                          style: text.titleMedium?.copyWith(
                            color: Mountain.sand,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Tag(
                          level == null
                              ? 'No ${plan.discipline.label.toLowerCase()} grades yet'
                              : '${plan.discipline.label} ${store.grades(level)}',
                          icon: fits ? Icons.check : Icons.info_outline,
                          color: fits ? Mountain.olive : Mountain.tan,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Mountain.granite),
                ],
              ),
            ),
            const SizedBox(height: 10),
            if (joined)
              const Tag('Joined', icon: Icons.check, color: Mountain.olive)
            else if (closed && !store.declinedHere(request.id))
              const Tag('Closed', icon: Icons.close, color: Mountain.granite)
            else if (request.rejected)
              const Tag('Declined', icon: Icons.close, color: Mountain.clay)
            else
              Text(
                [
                  if (yes.isNotEmpty) '${yes.join(', ')} said yes',
                  if (waiting.isNotEmpty) 'waiting for ${waiting.join(', ')}',
                ].join(' · '),
                style: text.bodySmall?.copyWith(color: Mountain.sky),
              ),
            if (answering) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.close, color: Mountain.clay),
                      label: const Text(
                        'Decline',
                        style: TextStyle(color: Mountain.clay),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Mountain.clay),
                      ),
                      onPressed: () => store.reject(request),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.check),
                      label: const Text('Accept'),
                      onPressed: () async {
                        final match = await store.accept(request);
                        if (match != null && context.mounted) {
                          MatchScreen.show(context, match);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
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
                      author.firstName,
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
