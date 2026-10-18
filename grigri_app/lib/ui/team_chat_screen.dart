import 'dart:async';
import 'dart:math' show max;

import 'package:flutter/material.dart';

import '../data/grigri_store.dart';
import '../data/realtime.dart';
import '../model/climber.dart';
import '../model/team.dart';
import '../theme.dart';
import 'common.dart';

/// The Grigri logo as an avatar: the Grigri team in chats.
class TeamAvatar extends StatelessWidget {
  const TeamAvatar({super.key, this.radius = 20});

  final double radius;

  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: radius,
    backgroundColor: const Color(0xFF2B4152),
    child: ClipOval(
      child: Image.asset(
        'assets/logo.png',
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) =>
            Icon(Icons.landscape, size: radius, color: Mountain.sand),
      ),
    ),
  );
}

/// A Grigri team chat (specs/team-chat.md). Without [climberId]: mine,
/// with the Grigri team, which opens with its welcome (thanks, and a
/// request for feedback: the app's own words, never stored). With one
/// (admins): that climber's, answered as the Grigri team; each answer
/// says, for the admins only, which admin wrote it. Text only.
class TeamChatScreen extends StatefulWidget {
  const TeamChatScreen({
    super.key,
    this.climberId,
    this.pollEvery = const Duration(seconds: 3),
    this.livePollEvery = const Duration(minutes: 1),
  });

  /// Whose team chat (admins); null: mine.
  final String? climberId;

  /// How often it checks for new messages while it's open.
  final Duration pollEvery;

  /// How often instead while live updates are connected.
  final Duration livePollEvery;

  @override
  State<TeamChatScreen> createState() => _TeamChatScreenState();
}

class _TeamChatScreenState extends State<TeamChatScreen>
    with WidgetsBindingObserver {
  final _input = TextEditingController();
  Timer? _poll;
  bool _sending = false;
  late final Cadence _cadence = Cadence(
    liveEvery: max(
      1,
      widget.livePollEvery.inMilliseconds ~/ widget.pollEvery.inMilliseconds,
    ),
  );

  bool get _asTeam => widget.climberId != null;

  void _load(GrigriStore store) {
    if (_asTeam) {
      store.pollTeamOf(widget.climberId!);
    } else {
      store.pollTeam();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final store = StoreScope.read(context);
      _load(store);
      store.readTeam();
    });
    _poll = Timer.periodic(widget.pollEvery, (_) {
      final state = WidgetsBinding.instance.lifecycleState;
      if (!mounted || (state != null && state != AppLifecycleState.resumed)) {
        return;
      }
      final store = StoreScope.read(context);
      if (_cadence.tick(live: store.live)) _load(store);
    });
  }

  /// The app went to the background (live updates stopped).
  bool _away = false;

  // Back in the foreground: polls at once, as a plan's chat does (the
  // connection that opens on resume doesn't catch up).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _away = true;
    } else if (state == AppLifecycleState.resumed && _away && mounted) {
      _away = false;
      _cadence.reset();
      _load(StoreScope.read(context));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    _input.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text;
    if (text.trim().isEmpty || _sending) return;
    setState(() => _sending = true);
    final store = StoreScope.read(context);
    final sent = _asTeam
        ? await store.answerAsTeam(widget.climberId!, text)
        : await store.sendToTeam(text);
    if (!mounted) return;
    setState(() => _sending = false);
    if (sent) _input.clear();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final l = context.l10n;
    final text = Theme.of(context).textTheme;
    final climber = _asTeam ? store.climber(widget.climberId!) : null;
    final messages =
        (_asTeam ? store.teamMessagesOf(widget.climberId!) : store.teamMessages)
            .reversed
            .toList();
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            if (climber != null)
              Avatar(climber, radius: 16)
            else
              const TeamAvatar(radius: 16),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    climber?.name ?? l.teamChatTitle,
                    style: text.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (climber != null)
                    Text(
                      l.teamChatTitle,
                      style: text.bodySmall?.copyWith(color: Mountain.granite),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              // The welcome, always first (so last, reversed).
              itemCount: messages.length + 1,
              itemBuilder: (context, i) {
                if (i == messages.length) {
                  return _TeamBubble(
                    key: const ValueKey('team welcome'),
                    text: l.teamChatWelcome,
                    mine: _asTeam,
                    fromTeam: true,
                    showAuthor: true,
                  );
                }
                final m = messages[i];
                final previous = i + 1 < messages.length
                    ? messages[i + 1]
                    : null;
                // Admins see which admin answered; the climber never does.
                final by = _asTeam && m.fromTeam && m.adminId != null
                    ? l.teamAnswerBy(
                        m.adminId == store.me.id
                            ? l.you
                            : store.climber(m.adminId!).firstName,
                      )
                    : null;
                return _TeamBubble(
                  key: ValueKey('team message ${m.id}'),
                  text: m.text,
                  time: m.time,
                  // Mine: what I wrote, or (admins) the team's answers.
                  mine: m.fromTeam == _asTeam,
                  fromTeam: m.fromTeam,
                  climber: m.fromTeam ? null : climber,
                  by: by,
                  showAuthor:
                      previous == null || previous.fromTeam != m.fromTeam,
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
                      key: const ValueKey('team input'),
                      controller: _input,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 2000,
                      buildCounter: (
                        _, {
                        required currentLength,
                        required isFocused,
                        maxLength,
                      }) => null,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: _asTeam
                            ? l.teamAnswerHint
                            : l.teamMessageHint,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton.filled(
                    tooltip: l.send,
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

class _TeamBubble extends StatelessWidget {
  const _TeamBubble({
    super.key,
    required this.text,
    required this.mine,
    required this.fromTeam,
    required this.showAuthor,
    this.time,
    this.climber,
    this.by,
  });

  final String text;
  final bool mine;
  final bool fromTeam;
  final bool showAuthor;

  /// None for the welcome.
  final DateTime? time;

  /// The climber who wrote it, when admins see it.
  final Climber? climber;

  /// (Admins) which admin answered.
  final String? by;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme;
    final l = context.l10n;
    final author = fromTeam ? l.teamChatTitle : climber?.firstName;
    return Padding(
      padding: EdgeInsets.only(top: showAuthor ? 10 : 2),
      child: Row(
        mainAxisAlignment: mine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!mine) ...[
            if (!showAuthor)
              const SizedBox(width: 28)
            else if (fromTeam)
              const TeamAvatar(radius: 14)
            else if (climber case final c?)
              Avatar(c, radius: 14)
            else
              const SizedBox(width: 28),
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
                  if (showAuthor && (!mine || by != null) && author != null)
                    Text(
                      by ?? author,
                      style: style.labelMedium?.copyWith(color: Mountain.tan),
                    ),
                  Text(text, style: style.bodyMedium),
                  if (time != null)
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Text(
                        clock(time!),
                        style: style.labelSmall?.copyWith(
                          color: Mountain.granite,
                        ),
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

/// The Grigri team chat's last message, for the Chats list: the welcome
/// until anyone writes.
String teamPreview(BuildContext context, List<TeamMessage> messages) {
  final l = context.l10n;
  final last = messages.lastOrNull;
  if (last == null) return l.teamChatWelcome;
  return last.fromTeam
      ? l.messagePreview(l.teamChatTitle, last.text)
      : l.messagePreview(l.you, last.text);
}
