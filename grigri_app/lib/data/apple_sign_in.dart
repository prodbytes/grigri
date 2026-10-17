import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'auth.dart';

/// Sign in with Apple on iOS (sign_in_with_apple; specs/sign-in.md):
/// Apple's sheet, asking for the name and email (which Apple lets the
/// person hide behind a relay address). Each sign-in has a fresh random
/// nonce: Apple signs its SHA-256 into the identity token, and the API
/// checks it against the nonce the app sends. Only iOS: Android and the
/// web would need a Services ID and a redirect page, and Apple's guideline
/// 4.8 is about the iPhone app.
class NativeAppleSignIn implements AppleSignIn {
  const NativeAppleSignIn();

  @override
  bool get available => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

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
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return null;
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
