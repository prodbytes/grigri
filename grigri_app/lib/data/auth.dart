import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

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

  /// Signs in with Google ([SignInMode.google]).
  Future<void> signIn();

  /// Who's calling, for every API request. Empty when signed out.
  Future<Map<String, String>> headers();

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
  /// `POST /api/session` with a Google ID token: the new session's token.
  Future<String> createSession({required String idToken});

  /// `DELETE /api/session`: ends the session [token].
  Future<void> deleteSession(String token);

  /// `DELETE /api/sessions`: ends every session of [token]'s owner.
  Future<void> deleteSessions(String token);
}

/// What proves who someone is, traded once for a session: a Google ID
/// token.
class Credential {
  const Credential({required this.user, required this.idToken});

  final AuthUser user;
  final String idToken;
}

typedef OnCredential = Future<void> Function(Credential credential);

/// How people prove who they are: Google.
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
  Future<void> signIn();

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
  Future<void> signIn() async {
    _error = null;
    notifyListeners();
    await method.signIn();
  }

  Future<void> _onCredential(Credential credential) async {
    // Google's event and the button's answer both bring the same one.
    if (_token != null || _signingIn) return;
    _signingIn = true;
    try {
      final token = await sessions.createSession(idToken: credential.idToken);
      try {
        await storage.write(token);
      } on Object {
        // Signed in for this run only.
      }
      _token = token;
      _user = credential.user;
      _error = null;
    } on Object {
      // Never log the details: they may carry account data.
      _error = SignInError.session;
      unawaited(_quietly(method.signOut));
    } finally {
      _signingIn = false;
    }
    notifyListeners();
  }

  void _fail(Object error) {
    _error = SignInError.google;
    notifyListeners();
  }

  @override
  Future<Map<String, String>> headers() async =>
      _token == null ? const {} : {'Authorization': 'Bearer $_token'};

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
/// client ID. A build without one still shows the button; signing in
/// fails. On the web, Google's button signs in (google_sign_in can't
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
  SignInMode get mode => kIsWeb && webClientId.isNotEmpty
      ? SignInMode.googleWebButton
      : SignInMode.google;

  @override
  Future<void> start({
    required OnCredential onCredential,
    required void Function(Object error) onError,
    required bool quietly,
  }) async {
    _onCredential = onCredential;
    _onError = onError;
    if (webClientId.isEmpty) return;
    if (!await (_ready ??= _initialize()) || !quietly) return;
    try {
      await _google.attemptLightweightAuthentication();
    } on Object {
      // Not signed in with Google: the button will ask.
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
      return true;
    } on Object {
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
    // Never log the exception's details: they may carry account data.
    final cancelled =
        error is GoogleSignInException &&
        error.code == GoogleSignInExceptionCode.canceled;
    if (!cancelled) _onError?.call(error);
  }

  @override
  Future<void> signIn() async {
    if (webClientId.isEmpty) {
      _onError?.call(StateError('no Google client ID'));
      return;
    }
    if (mode != SignInMode.google) return;
    if (!await (_ready ??= _initialize())) return;
    if (!_google.supportsAuthenticate()) return;
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
