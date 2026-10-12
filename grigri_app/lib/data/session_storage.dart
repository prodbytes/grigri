import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Where the app keeps the API's session token between runs. Reads that
/// fail come back empty (signed out); nothing here logs the token.
abstract interface class SessionStorage {
  Future<String?> read();

  Future<void> write(String token);

  Future<void> delete();

  /// The device's: secure storage (the Keychain on iOS, the Keystore on
  /// Android); browser storage on the web.
  factory SessionStorage.device() =>
      kIsWeb ? BrowserSessionStorage() : SecureSessionStorage();
}

const _key = 'grigri.session';

/// Android and iOS: flutter_secure_storage. On iOS the item is readable
/// after the first unlock, on this device only (never synced or restored
/// to another one); on Android it's encrypted with a Keystore key.
class SecureSessionStorage implements SessionStorage {
  final _storage = const FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  @override
  Future<String?> read() async {
    try {
      return await _storage.read(key: _key);
    } on Object {
      return null;
    }
  }

  @override
  Future<void> write(String token) => _storage.write(key: _key, value: token);

  @override
  Future<void> delete() async {
    try {
      await _storage.delete(key: _key);
    } on Object {
      // Nothing to forget.
    }
  }
}

/// The web: the site's local storage (shared_preferences). Script on the
/// page could read it, so the site's strict CSP is what keeps it safe.
class BrowserSessionStorage implements SessionStorage {
  final _prefs = SharedPreferencesAsync();

  @override
  Future<String?> read() async {
    try {
      return await _prefs.getString(_key);
    } on Object {
      return null;
    }
  }

  @override
  Future<void> write(String token) => _prefs.setString(_key, token);

  @override
  Future<void> delete() async {
    try {
      await _prefs.remove(_key);
    } on Object {
      // Nothing to forget.
    }
  }
}

/// Keeps the token in memory only (tests).
class MemorySessionStorage implements SessionStorage {
  MemorySessionStorage([this.token]);

  String? token;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String token) async => this.token = token;

  @override
  Future<void> delete() async => token = null;
}
