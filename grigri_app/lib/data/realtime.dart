import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'api.dart';

/// Where live updates come from (`GET /api/realtime`): MQTT over WebSocket
/// at [url], naming the IoT custom [authorizer] (empty locally), with a
/// client id starting with [clientIdPrefix], subscribed to [topic] (my own
/// topics only). See specs/live-updates.md.
class RealtimeInfo {
  const RealtimeInfo({
    required this.url,
    required this.authorizer,
    required this.topic,
    required this.clientIdPrefix,
  });

  final Uri url;
  final String authorizer;
  final String topic;
  final String clientIdPrefix;

  /// Null when live updates are off (`{"url": null}`).
  static RealtimeInfo? fromJson(Map<String, Object?> json) {
    final url = json['url'];
    if (url is! String || url.isEmpty) return null;
    return RealtimeInfo(
      url: Uri.parse(url),
      authorizer: json['authorizer'] as String? ?? '',
      topic: json['topic'] as String? ?? '',
      clientIdPrefix: json['clientIdPrefix'] as String? ?? '',
    );
  }

  /// The URL to open: the authorizer's name and my session token in the
  /// query (browsers can't set headers on a WebSocket). It carries a
  /// secret: never log it.
  Uri connectUrl(String token) => url.replace(
    queryParameters: {
      if (authorizer.isNotEmpty) 'x-amz-customauthorizer-name': authorizer,
      'token': token,
    },
  );
}

/// What a hint names: the app refetches just that, through the API.
enum HintKind { message, request, notice, plan, match, pics, unknown }

/// A live update: "something about [kind] changed" (and on which plan),
/// never the data itself.
class Hint {
  const Hint(this.kind, [this.planId]);

  final HintKind kind;
  final String? planId;

  /// Null for a payload that isn't a hint.
  static Hint? parse(String payload) {
    try {
      final json = jsonDecode(payload);
      if (json is! Map || json['kind'] is! String) return null;
      final kind = HintKind.values.firstWhere(
        (k) => k.name == json['kind'],
        orElse: () => HintKind.unknown,
      );
      final planId = json['planId'];
      return Hint(kind, planId is String && planId.isNotEmpty ? planId : null);
    } on FormatException {
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is Hint && other.kind == kind && other.planId == planId;

  @override
  int get hashCode => Object.hash(kind, planId);

  @override
  String toString() => 'Hint(${kind.name}, $planId)';
}

/// One live connection: the messages on the subscribed topic, until it
/// closes.
abstract interface class RealtimeChannel {
  /// Payloads, as text.
  Stream<String> get messages;

  /// Completes when the connection drops (or is closed).
  Future<void> get closed;

  void close();
}

/// Opens connections: MQTT over WebSocket ([MqttRealtimeTransport]); a
/// fake in tests.
abstract interface class RealtimeTransport {
  /// Connects to [url] as [clientId] and subscribes to [topic]; throws when
  /// it can't (refused, unreachable).
  Future<RealtimeChannel> connect({
    required Uri url,
    required String clientId,
    required String topic,
  });
}

/// Starts a timer: [Timer.new], or a fake in tests.
typedef Schedule = Timer Function(Duration delay, void Function() callback);

/// Keeps one live connection while [start]ed: fetches where to connect,
/// connects with the session token, hands each hint to [onHint], and
/// reconnects with backoff when it drops. [stop] (the app went to the
/// background, or signed out) closes it.
class Realtime extends ChangeNotifier {
  Realtime({
    required this.transport,
    required this.info,
    required this.token,
    required this.onHint,
    this.onReconnected,
    Schedule? schedule,
    Random? random,
  }) : _schedule = schedule ?? Timer.new,
       _random = random ?? Random.secure();

  final RealtimeTransport transport;

  /// `GET /api/realtime`.
  final Future<RealtimeInfo?> Function() info;

  /// The API session token (null when signed out).
  final Future<String?> Function() token;

  final void Function(Hint hint) onHint;

  /// Connected again after a drop: hints may have been missed meanwhile.
  final VoidCallback? onReconnected;

  final Schedule _schedule;
  final Random _random;

  bool _running = false;
  bool _connected = false;
  int _attempt = 0;
  int _connects = 0;

  /// Bumped by [start] and [stop]: late answers of an older run are dropped.
  int _generation = 0;
  RealtimeChannel? _channel;
  StreamSubscription<String>? _messages;
  Timer? _retry;

  /// Whether a live connection is up (then polling slows down).
  bool get connected => _connected;

  /// The delay before reconnect attempt [attempt] (0 first): 1 s, 2 s,
  /// 4 s, ... up to a minute, times [jitter] (0.5–1, so clients that
  /// dropped together don't all come back at once).
  static Duration backoff(int attempt, double jitter) {
    final seconds = min(60, 1 << min(attempt, 6));
    return Duration(milliseconds: (seconds * 1000 * jitter).round());
  }

  void start() {
    if (_running) return;
    _running = true;
    _attempt = 0;
    _connect(++_generation);
  }

  void stop() {
    if (!_running) return;
    _running = false;
    _generation++;
    _retry?.cancel();
    _retry = null;
    _drop();
  }

  void _drop() {
    _messages?.cancel();
    _messages = null;
    _channel?.close();
    _channel = null;
    if (_connected) {
      _connected = false;
      notifyListeners();
    }
  }

  bool _current(int generation) => _running && generation == _generation;

  Future<void> _connect(int generation) async {
    try {
      final where = await info();
      if (!_current(generation)) return;
      // Live updates are off here: polling only, until the next start.
      if (where == null) return;
      final session = await token();
      if (!_current(generation) || session == null) return;
      final channel = await transport.connect(
        url: where.connectUrl(session),
        clientId: '${where.clientIdPrefix}${_suffix()}',
        topic: where.topic,
      );
      if (!_current(generation)) {
        channel.close();
        return;
      }
      _channel = channel;
      _attempt = 0;
      _messages = channel.messages.listen((payload) {
        if (Hint.parse(payload) case final hint?) onHint(hint);
      });
      _connected = true;
      notifyListeners();
      if (_connects++ > 0) onReconnected?.call();
      unawaited(
        channel.closed.then((_) {
          if (!_current(generation) || _channel != channel) return;
          _drop();
          _later(generation);
        }),
      );
    } on ApiException catch (e) {
      // Signed out: the app goes back to the sign-in screen.
      if (e.status == 401) return;
      if (_current(generation)) _later(generation);
    } catch (_) {
      // Never logged: the error may quote the URL, which has the token.
      if (_current(generation)) _later(generation);
    }
  }

  void _later(int generation) {
    final delay = backoff(_attempt++, 0.5 + _random.nextDouble() / 2);
    _retry = _schedule(delay, () {
      if (_current(generation)) _connect(generation);
    });
  }

  String _suffix() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return String.fromCharCodes([
      for (var i = 0; i < 10; i++)
        chars.codeUnitAt(_random.nextInt(chars.length)),
    ]);
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}

/// How often a timer's work runs: on every tick while there's no live
/// connection, and only every [liveEvery]th tick while there is (polling
/// as a safety net). Counted in ticks, not clock time.
class Cadence {
  Cadence({required this.liveEvery});

  /// Ticks between runs while connected.
  final int liveEvery;
  int _skipped = 0;

  /// Whether this tick should run.
  bool tick({required bool live}) {
    if (!live || ++_skipped >= liveEvery) {
      _skipped = 0;
      return true;
    }
    return false;
  }

  /// A run happened anyway (say, on a hint): the next one can wait.
  void reset() => _skipped = 0;
}
