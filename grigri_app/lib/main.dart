import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_version.dart';
import 'config.dart';
import 'data/auth.dart';
import 'data/device_location.dart';
import 'data/grigri_store.dart';
import 'data/http_api.dart';
import 'data/mqtt_transport.dart';
import 'data/preferences.dart';
import 'data/session_storage.dart';
import 'log.dart';
import 'log_file.dart';
import 'theme.dart';
import 'ui/common.dart';
import 'ui/document_language/document_language.dart';
import 'ui/home_shell.dart';
import 'ui/sign_in_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Uncaught errors reach the log (specs/logging.md); Flutter still
  // reports them as before.
  final presentError = FlutterError.onError;
  FlutterError.onError = (details) {
    log.error('flutter', details.exceptionAsString(), null, details.stack);
    presentError?.call(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    log.error('uncaught', 'uncaught error', error, stack);
    return true;
  };
  log.info(
    'start',
    'Grigri ${AppVersion.version.isEmpty ? 'dev' : AppVersion.version}'
        ' stage=${AppVersion.stage.isEmpty ? 'local' : AppVersion.stage}'
        ' platform=${kIsWeb ? 'web' : defaultTargetPlatform.name}'
        ' api=${AppConfig.origin}'
        ' webClientId=${AppConfig.googleWebClientId.isEmpty ? 'none' : AppConfig.googleWebClientId}'
        ' iosClientId=${AppConfig.googleIosClientId.isEmpty ? 'none' : AppConfig.googleIosClientId}',
  );
  if (await openLogFile() case final write?) log.attachFile(write);
  late final Auth auth;
  final api = HttpGrigriApi(
    origin: AppConfig.origin,
    headers: () => auth.headers(),
  );
  auth = SessionAuth(
    method: GoogleSignInMethod(
      webClientId: AppConfig.googleWebClientId,
      iosClientId: AppConfig.googleIosClientId,
    ),
    sessions: api,
    storage: SessionStorage.device(),
  );
  final store = GrigriStore(
    api: api,
    auth: auth,
    preferences: await Preferences.open(),
    realtime: const MqttRealtimeTransport(),
    deviceLocation: const GeolocatorDeviceLocation(),
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
    );
  }
}

/// Signing in, then the tabs (the first sign-in creates my profile).
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
      Phase.ready => const HomeShell(),
      Phase.blocked => Scaffold(
        body: EmptyState(
          icon: Icons.block,
          title: l.blockedTitle,
          message: l.blockedMessage,
          action: Wrap(
            spacing: 12,
            children: [
              TextButton(onPressed: store.loadMe, child: Text(l.tryAgain)),
              FilledButton(onPressed: store.signOut, child: Text(l.signOut)),
            ],
          ),
        ),
      ),
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
