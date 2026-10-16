import 'package:url_launcher/url_launcher.dart';

/// Opens a link outside the app; false when nothing could open it.
typedef OpenLink = Future<bool> Function(Uri url);

/// The browser (or the app that handles the link): Stripe's pages for
/// Premium (specs/premium.md), and ads' links (specs/ads.md).
Future<bool> openInBrowser(Uri url) async {
  try {
    return await launchUrl(url, mode: LaunchMode.externalApplication);
  } on Object {
    return false;
  }
}
