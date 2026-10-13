import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../log.dart';
import 'api.dart';
import 'session_storage.dart';

/// Who signed in, as far as the app needs to know. Only known right after
/// signing in (a session resumed from storage doesn't say).
class AuthUser {
  const AuthUser({required this.email, this.name});

  final String email;

  /// Their Google display name, to start the profile with.
  final String? name;
}

/// How the sign-in screen signs people in.
enum SignInMode {
  /// A "Sign in with Google" button that calls [Auth.signIn].
  google,

  /// Google's own button, rendered by google_sign_in on the web.
  googleWebButton,

  /// The local API's dev mode: an email, no Google (local builds only).
  dev,

  /// This build has no Google client ID: sign-in can't work.
  unconfigured,
}

/// Signing in and out, and the header that tells the API who's calling.
/// Notifies when someone signs in or out.
abstract class Auth extends ChangeNotifier {
  /// Whether there's a session to call the API with.
  bool get signedIn;

  /// Who signed in, when it was in this run (null for a resumed session).
  AuthUser? get user;

  SignInMode get mode;

  /// Whether [start] is done (until then, nobody is known to be signed in).
  bool get started;

  /// The last sign-in failure to show, if any (the sign-in screen words
  /// it in the user's language).
  SignInError? get error;

  /// Initializes: signed in at once when a session was kept.
  Future<void> start();

  /// Signs in: with Google ([SignInMode.google]) or with [devEmail]
  /// ([SignInMode.dev]).
  Future<void> signIn({String? devEmail});

  /// Who's calling, for every API request. Empty when signed out.
  Future<Map<String, String>> headers();

  /// The API session token itself, for live updates' connection (the
  /// MQTT authorizer takes it); null when signed out. Never log it.
  Future<String?> sessionToken() async {
    final authorization = (await headers())['Authorization'];
    const bearer = 'Bearer ';
    if (authorization == null || !authorization.startsWith(bearer)) {
      return null;
    }
    return authorization.substring(bearer.length);
  }

  /// The API said 401: the session is gone. Forgets it, without telling
  /// the API.
  Future<void> signedOut();

  /// Ends this session (`DELETE /api/session`, best effort) and forgets it.
  Future<void> signOut();

  /// Ends all my sessions (`DELETE /api/sessions`), then forgets this one.
  /// False when the API couldn't be told (still signed in).
  Future<bool> signOutEverywhere();
}

/// Why signing in failed.
enum SignInError {
  /// The API didn't start a session for the credential.
  session,

  /// Google's sign-in failed.
  google,
}

/// The API's session routes: the only calls made without a session, or
/// with one given explicitly.
abstract interface class SessionApi {
  /// `POST /api/session` with a Google ID token, or, in the local API's
  /// dev mode, an email: the new session's token.
  Future<String> createSession({String? idToken, String? devUser});

  /// `DELETE /api/session`: ends the session [token].
  Future<void> deleteSession(String token);

  /// `DELETE /api/sessions`: ends every session of [token]'s owner.
  Future<void> deleteSessions(String token);
}

/// What proves who someone is, traded once for a session: a Google ID
/// token, or a dev email.
class Credential {
  const Credential({required this.user, this.idToken, this.devUser});

  final AuthUser user;
  final String? idToken;
  final String? devUser;
}

typedef OnCredential = Future<void> Function(Credential credential);

/// How people prove who they are: Google, or the local dev email.
abstract class SignInMethod {
  SignInMode get mode;

  /// Initializes. [onCredential] gets each sign-in (also the ones the
  /// method starts itself, like Google's button on the web), [onError] its
  /// failures. With [quietly], it may sign back in without asking.
  Future<void> start({
    required OnCredential onCredential,
    required void Function(Object error) onError,
    required bool quietly,
  });

  /// The app's sign-in button; done once [OnCredential] is.
  Future<void> signIn({String? devEmail});

  /// Signs out of the method (Google), so the next sign-in asks again.
  Future<void> signOut();
}

/// Sessions with the API (specs/sign-in.md): a [SignInMethod]'s credential
/// is traded once for the API's session token (`POST /api/session`), kept
/// in [storage] and sent as a bearer token on every call. Google isn't
/// asked again until the API says 401 or the person signs out.
class SessionAuth extends Auth {
  SessionAuth({
    required this.method,
    required this.sessions,
    required this.storage,
  });

  final SignInMethod method;
  final SessionApi sessions;
  final SessionStorage storage;

  String? _token;
  AuthUser? _user;
  bool _started = false;
  bool _signingIn = false;
  SignInError? _error;

  @override
  bool get signedIn => _token != null;

  @override
  AuthUser? get user => _token == null ? null : _user;

  @override
  SignInMode get mode => method.mode;

  @override
  bool get started => _started;

  @override
  SignInError? get error => _error;

  @override
  Future<void> start() async {
    if (_started) return;
    final kept = await storage.read();
    _token = kept == null || kept.isEmpty ? null : kept;
    log.info(
      'auth',
      'start: ${method.mode.name}, kept session: ${_token != null}',
    );
    final starting = method.start(
      onCredential: _onCredential,
      onError: _fail,
      quietly: _token == null,
    );
    // With a kept session there's no need to wait for Google.
    if (_token == null) {
      await starting;
    } else {
      unawaited(starting);
    }
    _started = true;
    notifyListeners();
  }

  @override
  Future<void> signIn({String? devEmail}) async {
    _error = null;
    notifyListeners();
    await method.signIn(devEmail: devEmail);
  }

  Future<void> _onCredential(Credential credential) async {
    // Google's event and the button's answer both bring the same one.
    if (_token != null || _signingIn) return;
    _signingIn = true;
    log.info(
      'auth',
      'got a ${credential.idToken != null ? 'Google ID token' : 'dev email'}; asking the API for a session',
    );
    try {
      final token = await sessions.createSession(
        idToken: credential.idToken,
        devUser: credential.devUser,
      );
      try {
        await storage.write(token);
      } on Object {
        // Signed in for this run only.
      }
      _token = token;
      _user = credential.user;
      _error = null;
      log.info('auth', 'signed in: the API started a session');
    } on Object catch (e) {
      // The log scrubs account data (emails, tokens) from the details.
      log.error('auth', 'the API didn\'t start a session', e);
      _error = SignInError.session;
      unawaited(_quietly(method.signOut));
    } finally {
      _signingIn = false;
    }
    notifyListeners();
  }

  void _fail(Object error) {
    log.error('auth', 'Google sign-in failed', error);
    _error = SignInError.google;
    notifyListeners();
  }

  @override
  Future<Map<String, String>> headers() async =>
      _token == null ? const {} : {'Authorization': 'Bearer $_token'};

  @override
  Future<String?> sessionToken() async => _token;

  /// Forgets the session: in memory at once (notifying), then on the
  /// device and with Google.
  Future<void> _forget() async {
    _token = null;
    _user = null;
    notifyListeners();
    await storage.delete();
    await _quietly(method.signOut);
  }

  @override
  Future<void> signedOut() async {
    if (_token == null) return;
    await _forget();
  }

  @override
  Future<void> signOut() async {
    final token = _token;
    if (token == null) return;
    // Signed out here even when the API can't be told.
    await _forget();
    await _quietly(() => sessions.deleteSession(token));
  }

  @override
  Future<bool> signOutEverywhere() async {
    final token = _token;
    if (token == null) return true;
    try {
      await sessions.deleteSessions(token);
    } on ApiException catch (e) {
      // A 401: this session was already gone.
      if (e.status != 401) return false;
    } on Object {
      return false;
    }
    await _forget();
    return true;
  }

  static Future<void> _quietly(Future<void> Function() call) async {
    try {
      await call();
    } on Object {
      // Best effort.
    }
  }
}

/// Google sign-in (google_sign_in): an ID token whose audience is the web
/// client ID. On the web, Google's button signs in (google_sign_in can't
/// start it from a button of ours there); on Android and iOS, the web
/// client ID is the server client ID.
class GoogleSignInMethod extends SignInMethod {
  GoogleSignInMethod({required this.webClientId, this.iosClientId = ''});

  final String webClientId;
  final String iosClientId;

  OnCredential? _onCredential;
  void Function(Object error)? _onError;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _events;
  Future<bool>? _ready;

  GoogleSignIn get _google => GoogleSignIn.instance;

  bool get _ios => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  SignInMode get mode => webClientId.isEmpty
      ? SignInMode.unconfigured
      : kIsWeb
      ? SignInMode.googleWebButton
      : SignInMode.google;

  @override
  Future<void> start({
    required OnCredential onCredential,
    required void Function(Object error) onError,
    required bool quietly,
  }) async {
    if (webClientId.isEmpty) return;
    _onCredential = onCredential;
    _onError = onError;
    if (!await (_ready ??= _initialize()) || !quietly) return;
    try {
      await _google.attemptLightweightAuthentication();
    } on Object catch (e) {
      // Not signed in with Google: the button will ask.
      log.info('auth', 'no quiet Google sign-in (${e.runtimeType})');
    }
  }

  Future<bool> _initialize() async {
    try {
      await _google.initialize(
        clientId: kIsWeb
            ? webClientId
            : _ios && iosClientId.isNotEmpty
            ? iosClientId
            : null,
        serverClientId: kIsWeb ? null : webClientId,
      );
      _events = _google.authenticationEvents.listen((event) {
        if (event case GoogleSignInAuthenticationEventSignIn(:final user)) {
          unawaited(_forward(user));
        }
      }, onError: _report);
      log.info('auth', 'Google sign-in initialized');
      return true;
    } on Object catch (e) {
      log.error('auth', 'Google sign-in couldn\'t initialize', e);
      return false;
    }
  }

  Future<void> _forward(GoogleSignInAccount account) async {
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      _onError?.call(StateError('no ID token'));
      return;
    }
    await _onCredential?.call(
      Credential(
        user: AuthUser(email: account.email, name: account.displayName),
        idToken: idToken,
      ),
    );
  }

  void _report(Object error) {
    // The log scrubs account data (emails, tokens) from the details.
    final cancelled =
        error is GoogleSignInException &&
        error.code == GoogleSignInExceptionCode.canceled;
    if (cancelled) {
      log.info('auth', 'Google sign-in cancelled');
    } else {
      _onError?.call(error);
    }
  }

  @override
  Future<void> signIn({String? devEmail}) async {
    if (mode != SignInMode.google) return;
    log.info('auth', 'sign-in button pressed');
    if (!await (_ready ??= _initialize())) return;
    if (!_google.supportsAuthenticate()) {
      log.warn('auth', 'Google sign-in can\'t authenticate on this platform');
      return;
    }
    try {
      // It also comes as an event; the session is made once.
      await _forward(await _google.authenticate());
    } on Object catch (e) {
      _report(e);
    }
  }

  @override
  Future<void> signOut() async {
    final ready = _ready;
    if (ready == null || !await ready) return;
    await _google.signOut();
  }

  void dispose() => _events?.cancel();
}

/// The local API's dev mode: whoever's email is typed in, traded for a
/// session like a Google token. Only built when [AppConfig.devSignIn]
/// allows it.
class DevSignInMethod extends SignInMethod {
  OnCredential? _onCredential;

  @override
  SignInMode get mode => SignInMode.dev;

  @override
  Future<void> start({
    required OnCredential onCredential,
    required void Function(Object error) onError,
    required bool quietly,
  }) async => _onCredential = onCredential;

  @override
  Future<void> signIn({String? devEmail}) async {
    final email = devEmail?.trim() ?? '';
    if (email.isEmpty) return;
    await _onCredential?.call(
      Credential(
        user: AuthUser(email: email),
        devUser: email,
      ),
    );
  }

  @override
  Future<void> signOut() async {}
}
