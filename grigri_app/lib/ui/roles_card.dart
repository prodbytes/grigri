import 'package:flutter/material.dart';

import '../theme.dart';
import 'common.dart';

/// My roles in Grigri, from rbacr (the API asks it, specs/roles.md): at
/// the end of the profile.
class RolesCard extends StatefulWidget {
  const RolesCard({super.key});

  @override
  State<RolesCard> createState() => _RolesCardState();
}

class _RolesCardState extends State<RolesCard> {
  bool _retrying = false;

  Future<void> _retry() async {
    setState(() => _retrying = true);
    await StoreScope.read(context).refreshRoles();
    if (mounted) setState(() => _retrying = false);
  }

  @override
  Widget build(BuildContext context) {
    final roles = StoreScope.of(context).roles;
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
            if (roles == null)
              Row(
                children: [
                  Expanded(child: Text(l.rolesFailed, style: quiet)),
                  _retrying
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : TextButton(onPressed: _retry, child: Text(l.retry)),
                ],
              )
            else if (roles.isEmpty)
              Text(l.noRoles, style: quiet)
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final role in roles) Tag(role, color: Mountain.sky),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
