import 'dart:collection';

import 'package:flutter/foundation.dart';

/// The app's log (specs/logging.md), for developers: never shown in the
/// app. Each line goes to the platform's log (the browser console on the
/// web, the device log on Android and iOS) and, on Android and iOS, to a
/// file in the app's storage ([attachFile]), kept across restarts, which
/// `scripts/ios-log.sh` copies off an iPhone. Nothing leaves the device.
///
/// Every line is scrubbed first: emails, JWTs (Google ID tokens) and bearer
/// tokens never reach a log, so errors can be logged with their messages.
class AppLog {
  AppLog({this.capacity = 200, this.sink});

  /// The app's one log.
  static final instance = AppLog();

  /// How many lines are kept in memory, for the file once it's attached.
  final int capacity;

  /// Where lines are printed; the platform log when null.
  final void Function(String line)? sink;

  final _lines = ListQueue<LogLine>();
  void Function(String line)? _file;

  /// Also writes every line to [write] (the log file), starting with the
  /// lines kept so far (those logged while the file was being opened).
  void attachFile(void Function(String line) write) {
    _file = write;
    for (final line in _lines) {
      write(line.toString());
    }
  }

  /// The last [capacity] lines, oldest first.
  List<LogLine> get lines => List.unmodifiable(_lines);

  void info(String tag, String message) => _add(LogLevel.info, tag, message);

  void warn(String tag, String message, [Object? error]) =>
      _add(LogLevel.warn, tag, _withError(message, error));

  void error(String tag, String message, [Object? error, StackTrace? stack]) =>
      _add(
        LogLevel.error,
        tag,
        _withError(message, error) + (stack == null ? '' : '\n$stack'),
      );

  static String _withError(String message, Object? error) =>
      error == null ? message : '$message: ${error.runtimeType}: $error';

  void _add(LogLevel level, String tag, String message) {
    final line = LogLine(DateTime.now(), level, tag, scrub(message));
    _lines.addLast(line);
    while (_lines.length > capacity) {
      _lines.removeFirst();
    }
    (sink ?? debugPrint)(line.toString());
    _file?.call(line.toString());
  }

  static final _email = RegExp(
    r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}',
  );
  static final _jwt = RegExp(
    r'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]*',
  );
  static final _bearer = RegExp(r'(Bearer\s+)\S+', caseSensitive: false);

  /// [text] without emails, JWTs or bearer tokens.
  @visibleForTesting
  static String scrub(String text) => text
      .replaceAll(_jwt, '<jwt>')
      .replaceAllMapped(_bearer, (m) => '${m[1]}<token>')
      .replaceAll(_email, '<email>');
}

enum LogLevel { info, warn, error }

class LogLine {
  const LogLine(this.time, this.level, this.tag, this.message);

  final DateTime time;
  final LogLevel level;
  final String tag;
  final String message;

  @override
  String toString() =>
      '${time.toIso8601String()} ${level.name.toUpperCase()} [$tag] $message';
}

/// Shorthand for [AppLog.instance].
AppLog get log => AppLog.instance;
