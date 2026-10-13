import 'package:flutter/material.dart';

/// The mountain palette: rock at night for the background, olive and moss
/// for the greens, sand and tan for warmth, granite for quiet text, and a
/// clear sky blue. Every text color here reads at WCAG AA (4.5:1) or
/// better on [night] and [surfaceHigh]; [moss] is only for icons and large
/// accents.
abstract final class Mountain {
  /// The background: dark rock with a hint of green.
  static const night = Color(0xFF161A16);

  /// Cards and sheets.
  static const surface = Color(0xFF1F241E);

  /// Raised surfaces: chips, inputs, the navigation bar's indicator.
  static const surfaceHigh = Color(0xFF2A3028);

  /// The primary green: olive.
  static const olive = Color(0xFF8F9B5D);

  /// The secondary green: moss.
  static const moss = Color(0xFF6F9468);

  /// A deep pine green for containers.
  static const pine = Color(0xFF3F5C45);

  /// Sandstone: headings and highlights.
  static const sand = Color(0xFFE2D3B3);

  /// Light brown, like a dry trail.
  static const tan = Color(0xFFB9936A);

  /// Granite gray: secondary text and outlines.
  static const granite = Color(0xFF9AA09A);

  /// The sky.
  static const sky = Color(0xFF86B8DC);

  /// Red clay, for errors and "pass".
  static const clay = Color(0xFFD9826B);

  /// Body text on the dark surfaces.
  static const snow = Color(0xFFECE6D6);
}

/// The app's theme: dark only, for now.
ThemeData mountainTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Mountain.olive,
    onPrimary: Mountain.night,
    primaryContainer: Mountain.pine,
    onPrimaryContainer: Mountain.snow,
    secondary: Mountain.sky,
    onSecondary: Mountain.night,
    secondaryContainer: Color(0xFF2B4152),
    onSecondaryContainer: Mountain.snow,
    tertiary: Mountain.tan,
    onTertiary: Mountain.night,
    tertiaryContainer: Color(0xFF4A3B2A),
    onTertiaryContainer: Mountain.sand,
    error: Mountain.clay,
    onError: Mountain.night,
    surface: Mountain.night,
    onSurface: Mountain.snow,
    onSurfaceVariant: Mountain.granite,
    surfaceContainerLowest: Color(0xFF111411),
    surfaceContainerLow: Color(0xFF1A1E19),
    surfaceContainer: Mountain.surface,
    surfaceContainerHigh: Mountain.surfaceHigh,
    surfaceContainerHighest: Color(0xFF343B32),
    outline: Color(0xFF5E655D),
    outlineVariant: Color(0xFF3A4138),
  );
  final base = ThemeData(colorScheme: scheme, useMaterial3: true);
  final text = base.textTheme.apply(
    bodyColor: Mountain.snow,
    displayColor: Mountain.sand,
  );
  return base.copyWith(
    scaffoldBackgroundColor: Mountain.night,
    textTheme: text,
    appBarTheme: const AppBarTheme(
      backgroundColor: Mountain.night,
      foregroundColor: Mountain.sand,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    cardTheme: CardThemeData(
      color: Mountain.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFF2F362D)),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: Mountain.surfaceHigh,
      selectedColor: Mountain.pine,
      labelStyle: const TextStyle(color: Mountain.snow),
      side: BorderSide.none,
      shape: const StadiumBorder(),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Mountain.surface,
      indicatorColor: Mountain.pine,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? Mountain.sand
              : Mountain.granite,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 11,
          color: states.contains(WidgetState.selected)
              ? Mountain.sand
              : Mountain.granite,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Mountain.surfaceHigh,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      labelStyle: const TextStyle(color: Mountain.granite),
    ),
    dividerTheme: const DividerThemeData(color: Color(0xFF2F362D)),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: Mountain.surfaceHigh,
      contentTextStyle: TextStyle(color: Mountain.snow),
    ),
  );
}
