import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Who is signed in, as far as the app needs to know.
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

/// Signing in and out, and the headers that tell the API who's calling.
/// Notifies when the user changes.
abstract class Auth extends ChangeNotifier {
  AuthUser? get user;

  SignInMode get mode;

  /// Whether [start] is done (until then, nobody is known to be signed in).
  bool get started;

  /// The last sign-in failure to show, if any.
  String? get error;

  /// Initializes, and signs back in quietly when it can.
  Future<void> start();

  /// Signs in: with Google ([SignInMode.google]) or with [devEmail]
  /// ([SignInMode.dev]).
  Future<void> signIn({String? devEmail});

  /// Who's calling, for every API request. Empty when signed out.
  Future<Map<String, String>> headers();

  /// Tries to get fresh credentials quietly after the API said 401; true
  /// when there are new ones to retry with.
  Future<bool> refresh();

  Future<void> signOut();
}

/// Google sign-in (google_sign_in): an ID token whose audience is the web
/// client ID, sent as a bearer token. On the web, Google's button signs in
/// (google_sign_in can't start it from a button of ours there); on Android
/// and iOS, the web client ID is the server client ID.
class GoogleAuth extends Auth {
  GoogleAuth({required this.webClientId, this.iosClientId = ''});

  final String webClientId;
  final String iosClientId;

  GoogleSignInAccount? _account;
  bool _started = false;
  String? _error;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _events;

  GoogleSignIn get _google => GoogleSignIn.instance;

  bool get _ios => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  AuthUser? get user => _account == null
      ? null
      : AuthUser(email: _account!.email, name: _account!.displayName);

  @override
  SignInMode get mode => webClientId.isEmpty
      ? SignInMode.unconfigured
      : kIsWeb
      ? SignInMode.googleWebButton
      : SignInMode.google;

  @override
  bool get started => _started;

  @override
  String? get error => _error;

  @override
  Future<void> start() async {
    if (webClientId.isEmpty) {
      _started = true;
      notifyListeners();
      return;
    }
    try {
      await _google.initialize(
        clientId: kIsWeb
            ? webClientId
            : _ios && iosClientId.isNotEmpty
            ? iosClientId
            : null,
        serverClientId: kIsWeb ? null : webClientId,
      );
      _events = _google.authenticationEvents.listen(
        _onEvent,
        onError: (Object e) => _fail(e),
      );
      await _google.attemptLightweightAuthentication();
    } on Object catch (e) {
      _fail(e, quiet: true);
    }
    _started = true;
    notifyListeners();
  }

  void _onEvent(GoogleSignInAuthenticationEvent event) {
    _account = switch (event) {
      GoogleSignInAuthenticationEventSignIn(:final user) => user,
      GoogleSignInAuthenticationEventSignOut() => null,
    };
    _error = null;
    notifyListeners();
  }

  void _fail(Object e, {bool quiet = false}) {
    // Never log the exception's details: they may carry account data.
    final cancelled =
        e is GoogleSignInException &&
        e.code == GoogleSignInExceptionCode.canceled;
    if (!quiet && !cancelled) {
      _error = 'Couldn\'t sign in with Google. Try again.';
      notifyListeners();
    }
  }

  @override
  Future<void> signIn({String? devEmail}) async {
    if (mode != SignInMode.google || !_google.supportsAuthenticate()) return;
    try {
      _account = await _google.authenticate();
      _error = null;
      notifyListeners();
    } on Object catch (e) {
      _fail(e);
    }
  }

  @override
  Future<Map<String, String>> headers() async {
    final token = _account?.authentication.idToken;
    return token == null ? const {} : {'Authorization': 'Bearer $token'};
  }

  @override
  Future<bool> refresh() async {
    if (kIsWeb || _account == null) return false;
    try {
      final account = await _google.attemptLightweightAuthentication();
      if (account == null) return false;
      _account = account;
      return account.authentication.idToken != null;
    } on Object {
      return false;
    }
  }

  @override
  Future<void> signOut() async {
    _account = null;
    notifyListeners();
    try {
      await _google.signOut();
    } on Object {
      // Signed out here anyway.
    }
  }

  @override
  void dispose() {
    _events?.cancel();
    super.dispose();
  }
}

/// The local API's dev mode: whoever's email is typed in, sent as
/// X-Grigri-Dev-User. Only built when [AppConfig.devSignIn] allows it.
class DevAuth extends Auth {
  AuthUser? _user;

  @override
  AuthUser? get user => _user;

  @override
  SignInMode get mode => SignInMode.dev;

  @override
  bool get started => true;

  @override
  String? get error => null;

  @override
  Future<void> start() async {}

  @override
  Future<void> signIn({String? devEmail}) async {
    final email = devEmail?.trim() ?? '';
    if (email.isEmpty) return;
    _user = AuthUser(email: email);
    notifyListeners();
  }

  @override
  Future<Map<String, String>> headers() async =>
      _user == null ? const {} : {'X-Grigri-Dev-User': _user!.email};

  @override
  Future<bool> refresh() async => false;

  @override
  Future<void> signOut() async {
    _user = null;
    notifyListeners();
  }
}
