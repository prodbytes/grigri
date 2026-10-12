import 'package:flutter/material.dart';

import 'app_version.dart';
import 'data/grigri_store.dart';
import 'data/roles.dart';
import 'theme.dart';
import 'ui/common.dart';
import 'ui/home_shell.dart';
import 'ui/roles_card.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    GrigriApp(store: await GrigriStore.load(), roles: Roles.fromSettings()),
  );
}

class GrigriApp extends StatelessWidget {
  const GrigriApp({
    super.key,
    required this.store,
    this.roles = const Roles.none(),
  });

  final GrigriStore store;

  /// The user's roles, from rbacr.
  final Roles roles;

  @override
  Widget build(BuildContext context) {
    // Dark only, for now: the mountain palette (theme.dart).
    return StoreScope(
      store: store,
      child: RolesScope(
        roles: roles,
        child: MaterialApp(
          title: AppVersion.title,
          debugShowCheckedModeBanner: false,
          theme: mountainTheme(),
          home: const HomeShell(),
        ),
      ),
    );
  }
}
