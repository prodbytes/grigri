import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../config.dart';
import 'auth.dart';

/// Sign in with Apple (sign_in_with_apple; specs/sign-in.md), asking for
/// the name and email (which Apple lets the person hide behind a relay
/// address). On iOS, Apple's own sheet (for the bundle ID); on the web,
/// Apple's popup, and on Android Apple's page in a Custom Tab, both for
/// the Services ID, returning to its redirect URI. Each sign-in has a
/// fresh random nonce: Apple signs its SHA-256 into the identity token,
/// and the API checks it against the nonce the app sends.
class NativeAppleSignIn implements AppleSignIn {
  const NativeAppleSignIn();

  static bool get _ios =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  bool get available =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<AppleCredential?> signIn() async {
    final nonce = generateNonce();
    final AuthorizationCredentialAppleID apple;
    try {
      apple = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: sha256.convert(utf8.encode(nonce)).toString(),
        webAuthenticationOptions: _ios
            ? null
            : WebAuthenticationOptions(
                clientId: AppConfig.appleServiceId,
                redirectUri: AppConfig.appleRedirectUri,
              ),
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return null;
      rethrow;
    } on SignInWithAppleCredentialsException catch (e) {
      // The web's popup, closed or cancelled.
      if (webCancelled(e.message)) return null;
      rethrow;
    }
    final idToken = apple.identityToken;
    if (idToken == null || idToken.isEmpty) {
      throw StateError('Apple gave no identity token');
    }
    // Apple gives the name only the first time this Apple ID signs in to
    // the app.
    final name = [
      apple.givenName,
      apple.familyName,
    ].whereType<String>().map((s) => s.trim()).where((s) => s.isNotEmpty);
    return AppleCredential(
      user: AuthUser(
        email: apple.email,
        name: name.isEmpty ? null : name.join(' '),
      ),
      idToken: idToken,
      nonce: nonce,
      authorizationCode: apple.authorizationCode,
    );
  }
}

/// Whether Apple's web error ([SignInWithAppleCredentialsException]'s
/// message, which ends with Apple JS's error code) means the person closed
/// or cancelled the popup.
@visibleForTesting
bool webCancelled(String message) =>
    message.endsWith('popup_closed_by_user') ||
    message.endsWith('user_cancelled_authorize');
