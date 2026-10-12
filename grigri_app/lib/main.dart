import 'dart:async';

import 'package:flutter/material.dart';

import 'app_version.dart';
import 'config.dart';
import 'data/auth.dart';
import 'data/grigri_store.dart';
import 'data/http_api.dart';
import 'data/preferences.dart';
import 'data/roles.dart';
import 'theme.dart';
import 'ui/common.dart';
import 'ui/document_language/document_language.dart';
import 'ui/home_shell.dart';
import 'ui/profile_editor.dart';
import 'ui/roles_card.dart';
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
  runApp(GrigriApp(store: store, roles: Roles.fromSettings()));
  unawaited(store.start());
}

class GrigriApp extends StatefulWidget {
  const GrigriApp({
    super.key,
    required this.store,
    this.roles = const Roles.none(),
  });

  final GrigriStore store;

  /// The user's roles, from rbacr.
  final Roles roles;

  @override
  State<GrigriApp> createState() => _GrigriAppState();
}

class _GrigriAppState extends State<GrigriApp> {
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  final _navigator = GlobalKey<NavigatorState>();
  StreamSubscription<String>? _errors;
  Phase? _phase;
  late Locale? _locale = widget.store.locale;

  /// Leaving the tabs (signed out, or back to creating a profile) closes
  /// the screens opened over them. Picking a language rebuilds the app in
  /// it.
  void _storeChanged() {
    if (widget.store.locale != _locale) {
      setState(() => _locale = widget.store.locale);
    }
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
    widget.store.addListener(_storeChanged);
    _errors = widget.store.errors.listen(
      (message) => _messenger.currentState
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message))),
    );
  }

  @override
  void dispose() {
    widget.store.removeListener(_storeChanged);
    _errors?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Dark only, for now: the mountain palette (theme.dart).
    return StoreScope(
      store: widget.store,
      child: RolesScope(
        roles: widget.roles,
        child: MaterialApp(
          title: AppVersion.title,
          debugShowCheckedModeBanner: false,
          theme: mountainTheme(),
          // The language picked in the profile, or the device's (English
          // when the app doesn't speak it): specs/i18n.md.
          locale: _locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) {
            // The store words some messages itself (what failed).
            final l10n = AppLocalizations.of(context);
            widget.store.l10n = l10n;
            setDocumentLanguage(l10n.localeName);
            return child!;
          },
          scaffoldMessengerKey: _messenger,
          navigatorKey: _navigator,
          home: const Root(),
        ),
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
    final l = context.l10n;
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
          title: l.loadFailedTitle,
          message: store.loadError ?? l.errorGeneric,
          action: Wrap(
            spacing: 12,
            children: [
              FilledButton(onPressed: store.loadMe, child: Text(l.tryAgain)),
              TextButton(onPressed: store.signOut, child: Text(l.signOut)),
            ],
          ),
        ),
      ),
    };
  }
}
