import 'package:flutter/material.dart';

import '../data/roles.dart';
import '../theme.dart';
import 'common.dart';

/// Hands the app's [Roles] down to the screens that show them.
class RolesScope extends InheritedWidget {
  const RolesScope({super.key, required this.roles, required super.child});

  final Roles roles;

  static Roles of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RolesScope>()?.roles ??
      const Roles.none();

  @override
  bool updateShouldNotify(RolesScope oldWidget) => roles != oldWidget.roles;
}

/// The user's roles in Grigri, from rbacr: at the end of the profile.
class RolesCard extends StatefulWidget {
  const RolesCard({super.key});

  @override
  State<RolesCard> createState() => _RolesCardState();
}

class _RolesCardState extends State<RolesCard> {
  Roles? _roles;
  Future<({String email, List<String> roles})>? _mine;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final roles = RolesScope.of(context);
    if (roles != _roles) {
      _roles = roles;
      _mine = roles.available ? roles.mine() : null;
    }
  }

  void _retry() => setState(() {
    _mine = _roles!.mine();
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final quiet = text.bodySmall?.copyWith(color: Mountain.granite);
    final l = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.roles.toUpperCase(),
              style: text.labelSmall?.copyWith(
                color: Mountain.granite,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            if (_mine == null)
              Text(l.rolesSignedOut, style: quiet)
            else
              FutureBuilder(
                future: _mine,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Row(
                      children: [
                        Expanded(child: Text(l.rolesFailed, style: quiet)),
                        TextButton(onPressed: _retry, child: Text(l.retry)),
                      ],
                    );
                  }
                  final mine = snapshot.data;
                  if (mine == null) {
                    return const Padding(
                      padding: EdgeInsets.all(4),
                      child: SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (mine.roles.isEmpty)
                        Text(l.noRoles, style: quiet)
                      else
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final role in mine.roles)
                              Tag(role, color: Mountain.sky),
                          ],
                        ),
                      const SizedBox(height: 8),
                      Text(l.rolesAs(mine.email), style: quiet),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
