import 'package:flutter/widgets.dart';
import 'package:google_sign_in_web/web_only.dart' as web;

/// Google's button, in the dark theme to suit the app's.
Widget googleWebButton() => web.renderButton(
  configuration: web.GSIButtonConfiguration(
    theme: web.GSIButtonTheme.filledBlack,
    size: web.GSIButtonSize.large,
    shape: web.GSIButtonShape.pill,
    text: web.GSIButtonText.signinWith,
  ),
);
