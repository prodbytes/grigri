import 'package:flutter/material.dart';

import 'app_version.dart';
import 'data/grigri_store.dart';
import 'theme.dart';
import 'ui/common.dart';
import 'ui/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(GrigriApp(store: await GrigriStore.load()));
}

class GrigriApp extends StatelessWidget {
  const GrigriApp({super.key, required this.store});

  final GrigriStore store;

  @override
  Widget build(BuildContext context) {
    // Dark only, for now: the mountain palette (theme.dart).
    return StoreScope(
      store: store,
      child: MaterialApp(
        title: AppVersion.title,
        debugShowCheckedModeBanner: false,
        theme: mountainTheme(),
        home: const HomeShell(),
      ),
    );
  }
}
