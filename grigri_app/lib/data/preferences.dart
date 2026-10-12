import 'package:shared_preferences/shared_preferences.dart';

import '../model/climbing.dart';

/// What the app keeps on the device, display choices rather than data:
/// how I like grades written (like Celsius or Fahrenheit) and the app's
/// language. Everything else comes from the API.
class Preferences {
  Preferences._(this._prefs);

  static const _gradeSystem = 'grigri.gradeSystem';
  static const _language = 'grigri.language';

  final SharedPreferencesWithCache? _prefs;

  /// The device's preferences (local storage on the web).
  static Future<Preferences> open() async {
    try {
      return Preferences._(
        await SharedPreferencesWithCache.create(
          cacheOptions: const SharedPreferencesWithCacheOptions(
            allowList: {_gradeSystem, _language},
          ),
        ),
      );
    } on Object {
      return Preferences.none();
    }
  }

  /// Keeps nothing (tests).
  factory Preferences.none() => Preferences._(null);

  GradeSystem get gradeSystem =>
      GradeSystem.values.asNameMap()[_prefs?.getString(_gradeSystem)] ??
      GradeSystem.european;

  Future<void> setGradeSystem(GradeSystem system) async =>
      _prefs?.setString(_gradeSystem, system.name);

  /// The language code I picked for the app ("es"); null to follow the
  /// device's language.
  String? get language => _prefs?.getString(_language);

  Future<void> setLanguage(String? code) async => code == null
      ? _prefs?.remove(_language)
      : _prefs?.setString(_language, code);
}
