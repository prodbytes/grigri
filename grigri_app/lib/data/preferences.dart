import 'package:shared_preferences/shared_preferences.dart';

import '../model/climbing.dart';

/// The one thing the app keeps on the device: how I like grades written
/// (a display choice, like Celsius or Fahrenheit, not data). Everything
/// else comes from the API.
class Preferences {
  Preferences._(this._prefs);

  static const _gradeSystem = 'grigri.gradeSystem';

  final SharedPreferencesWithCache? _prefs;

  /// The device's preferences (local storage on the web).
  static Future<Preferences> open() async {
    try {
      return Preferences._(
        await SharedPreferencesWithCache.create(
          cacheOptions: const SharedPreferencesWithCacheOptions(
            allowList: {_gradeSystem},
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
}
