import 'package:flutter/foundation.dart';

import 'app_version.dart';

/// Where the app finds its backend, and how people sign in: compiled in
/// with --dart-define (the public names allowed by scripts/dart-defines.sh).
/// See specs/sign-in.md.
abstract final class AppConfig {
  /// The API's site, e.g. https://grigri.nu01.com (the app calls
  /// `<site>/api/...` and loads photos from `<site>/photos/...`). Optional:
  /// see [origin].
  static const String apiUrl = String.fromEnvironment('GRIGRI_API_URL');

  /// The Google OAuth **web** client ID: the audience of the ID tokens the
  /// API accepts, on every platform. Public, not a secret.
  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
  );

  /// The Google OAuth iOS client ID (iOS only). Public, not a secret.
  static const String googleIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
  );

  static const _prod = 'https://grigri.nu01.com';
  static const _rc = 'https://rc.grigri.nu01.com';

  /// The site the app talks to: [apiUrl] when given; otherwise, on the web,
  /// the page's own origin (the API and photos are served by the same
  /// CloudFront distribution as the app), and on Android and iOS the
  /// stage's site: production's for `prod`, the RC site for anything else.
  static Uri get origin => resolveOrigin(
    apiUrl: apiUrl,
    stage: AppVersion.stage,
    web: kIsWeb,
    page: kIsWeb ? Uri.base : null,
  );

  @visibleForTesting
  static Uri resolveOrigin({
    required String apiUrl,
    required String stage,
    required bool web,
    Uri? page,
  }) {
    if (apiUrl.isNotEmpty) return _originOf(Uri.parse(apiUrl));
    if (web && page != null) return _originOf(page);
    return Uri.parse(stage == 'prod' ? _prod : _rc);
  }

  static Uri _originOf(Uri uri) => Uri(
    scheme: uri.scheme,
    host: uri.host,
    port: uri.hasPort ? uri.port : null,
  );

  /// Whether this build signs in with the local API's dev mode (an email in
  /// an X-Grigri-Dev-User header, no Google): only a local build (no
  /// stage, or `local`) without a Google client ID, never one that talks to
  /// the deployed sites. The deployed APIs ignore the header anyway.
  static bool get devSignIn => isDevSignIn(
    stage: AppVersion.stage,
    webClientId: googleWebClientId,
    origin: origin,
  );

  @visibleForTesting
  static bool isDevSignIn({
    required String stage,
    required String webClientId,
    required Uri origin,
  }) =>
      (stage.isEmpty || stage == 'local') &&
      webClientId.isEmpty &&
      origin.host != Uri.parse(_prod).host &&
      origin.host != Uri.parse(_rc).host;
}
