import 'package:shared_preferences/shared_preferences.dart';

/// Where the app keeps its state between runs: one JSON string, on the
/// device (shared_preferences: local storage on the web).
class Storage {
  Storage._(this._prefs);

  static const _key = 'grigri.state.v1';

  final SharedPreferencesWithCache? _prefs;

  /// The device's storage.
  static Future<Storage> open() async => Storage._(
    await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(allowList: {_key}),
    ),
  );

  /// Keeps nothing (tests).
  factory Storage.none() => Storage._(null);

  String? read() => _prefs?.getString(_key);

  Future<void> write(String json) async => _prefs?.setString(_key, json);
}
