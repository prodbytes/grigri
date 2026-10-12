import 'package:flutter/material.dart';

import '../data/grigri_store.dart';
import '../theme.dart';
import 'chat_screen.dart';
import 'common.dart';

/// "It's a match!": someone joined a plan I'm in, or I joined one. The plan
/// is the highlight, with the group around it.
class MatchScreen extends StatelessWidget {
  const MatchScreen({super.key, required this.match});

  final Match match;

  /// Shows the match over the current screen.
  static Future<void> show(BuildContext context, Match match) =>
      Navigator.of(context).push(
        PageRouteBuilder(
          opaque: false,
          barrierColor: Colors.black54,
          transitionDuration: const Duration(milliseconds: 300),
          pageBuilder: (_, _, _) => MatchScreen(match: match),
          transitionsBuilder: (_, animation, _, child) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween(begin: 0.92, end: 1.0).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
              ),
              child: child,
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final text = Theme.of(context).textTheme;
    final plan = store.plan(match.plan.id) ?? match.plan;
    final members = [for (final id in plan.memberIds) store.climber(id)];
    final mine = match.newcomer.id == store.me.id;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF203445), Mountain.night, Mountain.night],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  children: [
                    const Text('🧗', style: TextStyle(fontSize: 48)),
                    const SizedBox(height: 8),
                    Text(
                      "It's a match!",
                      style: text.displaySmall?.copyWith(
                        color: Mountain.sand,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      mine
                          ? 'Everyone in the group said yes. You\'re climbing together:'
                          : '${match.newcomer.name} joins the group:',
                      style: text.bodyLarge?.copyWith(color: Mountain.granite),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    PlanHighlight(plan),
                    const SizedBox(height: 20),
                    AvatarRow(members, radius: 24),
                    const SizedBox(height: 8),
                    Text(
                      members
                          .map(
                            (m) => m.id == store.me.id
                                ? 'you'
                                : m.name.split(' ').first,
                          )
                          .join(', '),
                      style: text.bodyMedium?.copyWith(color: Mountain.snow),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        icon: const Icon(Icons.forum_outlined),
                        label: const Text('Open the group chat'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: () => Navigator.of(context).pushReplacement(
                          MaterialPageRoute<void>(
                            builder: (_) => ChatScreen(planId: plan.id),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Keep swiping'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
