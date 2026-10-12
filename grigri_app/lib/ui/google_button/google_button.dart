/// Google's own sign-in button, which google_sign_in renders on the web
/// (where it can't be started from a button of the app's). Elsewhere, a
/// stub that's never built.
library;

export 'stub.dart' if (dart.library.js_interop) 'web.dart';
