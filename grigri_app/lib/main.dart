import 'dart:async';

import 'package:flutter/material.dart';

import 'app_version.dart';
import 'config.dart';
import 'data/auth.dart';
import 'data/grigri_store.dart';
import 'data/http_api.dart';
import 'data/preferences.dart';
import 'theme.dart';
import 'ui/common.dart';
import 'ui/home_shell.dart';
import 'ui/profile_editor.dart';
import 'ui/sign_in_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final Auth auth = AppConfig.devSignIn
      ? DevAuth()
      : GoogleAuth(
          webClientId: AppConfig.googleWebClientId,
          iosClientId: AppConfig.googleIosClientId,
        );
  final store = GrigriStore(
    api: HttpGrigriApi(origin: AppConfig.origin, headers: auth.headers),
    auth: auth,
    preferences: await Preferences.open(),
  );
  runApp(GrigriApp(store: store));
  unawaited(store.start());
}

class GrigriApp extends StatefulWidget {
  const GrigriApp({super.key, required this.store});

  final GrigriStore store;

  @override
  State<GrigriApp> createState() => _GrigriAppState();
}

class _GrigriAppState extends State<GrigriApp> {
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  final _navigator = GlobalKey<NavigatorState>();
  StreamSubscription<String>? _errors;
  Phase? _phase;

  /// Leaving the tabs (signed out, or back to creating a profile) closes
  /// the screens opened over them.
  void _phaseChanged() {
    final phase = widget.store.phase;
    if (phase == _phase) return;
    if (_phase == Phase.ready) {
      _navigator.currentState?.popUntil((route) => route.isFirst);
    }
    _phase = phase;
  }

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_phaseChanged);
    _errors = widget.store.errors.listen(
      (message) => _messenger.currentState
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message))),
    );
  }

  @override
  void dispose() {
    widget.store.removeListener(_phaseChanged);
    _errors?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Dark only, for now: the mountain palette (theme.dart).
    return StoreScope(
      store: widget.store,
      child: MaterialApp(
        title: AppVersion.title,
        debugShowCheckedModeBanner: false,
        theme: mountainTheme(),
        scaffoldMessengerKey: _messenger,
        navigatorKey: _navigator,
        home: const Root(),
      ),
    );
  }
}

/// Signing in, then creating a profile the first time, then the tabs.
class Root extends StatelessWidget {
  const Root({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return switch (store.phase) {
      Phase.starting || Phase.loading => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      Phase.signedOut => const SignInScreen(),
      Phase.needsProfile => const ProfileEditor(create: true),
      Phase.ready => const HomeShell(),
      Phase.failed => Scaffold(
        body: EmptyState(
          icon: Icons.cloud_off,
          title: 'Couldn\'t load your profile',
          message: store.loadError ?? 'Something went wrong.',
          action: Wrap(
            spacing: 12,
            children: [
              FilledButton(
                onPressed: store.loadMe,
                child: const Text('Try again'),
              ),
              TextButton(
                onPressed: store.signOut,
                child: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    };
  }
}
