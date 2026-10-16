import 'package:flutter/material.dart';

import '../data/api.dart';
import '../data/grigri_store.dart';
import '../theme.dart';
import 'common.dart';

/// The Admin tab (admins only): everyone, by name, to block (they can't
/// use Grigri, and their plans leave the deck) or unblock.
class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final climbers = store.adminClimbers;
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.adminTitle),
        actions: [
          IconButton(
            tooltip: l.refresh,
            icon: const Icon(Icons.refresh),
            onPressed: store.refreshAdmin,
          ),
        ],
      ),
      body: !store.isLoaded(Section.admin)
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: store.refreshAdmin,
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  if (climbers.isEmpty)
                    EmptyState(
                      icon: Icons.people_outline,
                      title: l.adminNoClimbersTitle,
                      message: l.adminNoClimbersMessage,
                    )
                  else
                    for (final c in climbers) _ClimberTile(entry: c),
                ],
              ),
            ),
    );
  }
}

class _ClimberTile extends StatelessWidget {
  const _ClimberTile({required this.entry});

  final AdminClimber entry;

  Future<bool> _confirmBlock(BuildContext context, String name) async {
    final l = context.l10n;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l.blockNameQuestion(name)),
            content: Text(l.blockMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  l.block,
                  style: const TextStyle(color: Mountain.clay),
                ),
              ),
            ],
          ),
        ) ==
        true;
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final person = entry.climber;
    final l = context.l10n;
    // Never myself: I'd lock myself out (the API refuses it too).
    final Widget? action = person.id == store.me.id
        ? null
        : entry.blocked
        ? OutlinedButton(
            onPressed: () => store.setBlocked(person.id, false),
            child: Text(l.unblock),
          )
        : TextButton(
            onPressed: () async {
              if (!await _confirmBlock(context, person.name)) return;
              await store.setBlocked(person.id, true);
            },
            child: Text(l.block, style: const TextStyle(color: Mountain.clay)),
          );
    return ListTile(
      key: ValueKey('admin climber ${person.id}'),
      leading: Avatar(person),
      title: Text(person.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: entry.blocked
          ? Text(l.blocked, style: const TextStyle(color: Mountain.clay))
          : null,
      onTap: () => showProfileSheet(context, person),
      trailing: action,
    );
  }
}
