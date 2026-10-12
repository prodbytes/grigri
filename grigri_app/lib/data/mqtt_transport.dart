import 'dart:async';

import 'package:mqtt_client/mqtt_client.dart';

import 'mqtt/client_io.dart'
    if (dart.library.js_interop) 'mqtt/client_web.dart';
import 'realtime.dart';

/// Live updates over MQTT 3.1.1 on a WebSocket (AWS IoT Core; Floci's
/// broker locally), with mqtt_client: QoS 0, a clean session, no automatic
/// reconnects ([Realtime] does that, with backoff) and its logging off,
/// since the URL carries the session token.
class MqttRealtimeTransport implements RealtimeTransport {
  const MqttRealtimeTransport({this.keepAlive = 60});

  /// Seconds between pings while idle (IoT Core allows 30–1200).
  final int keepAlive;

  @override
  Future<RealtimeChannel> connect({
    required Uri url,
    required String clientId,
    required String topic,
  }) async {
    final client = mqttWebSocketClient(url, clientId)
      ..logging(on: false)
      ..setProtocolV311()
      ..autoReconnect = false
      ..keepAlivePeriod = keepAlive
      ..connectTimeoutPeriod = 10000
      ..connectionMessage = MqttConnectMessage()
          .withClientIdentifier(clientId)
          .startClean();
    final closed = Completer<void>();
    client.onDisconnected = () {
      if (!closed.isCompleted) closed.complete();
    };
    try {
      await client.connect();
    } catch (_) {
      client.disconnect();
      // Not rethrown as is: its message may quote the URL (the token).
      throw const RealtimeUnavailable();
    }
    if (client.connectionStatus?.state != MqttConnectionState.connected) {
      client.disconnect();
      throw const RealtimeUnavailable();
    }
    final messages = StreamController<String>();
    final updates = client.updates?.listen((batch) {
      for (final received in batch) {
        final message = received.payload;
        if (message is MqttPublishMessage) {
          messages.add(
            MqttPublishPayload.bytesToStringAsString(message.payload.message),
          );
        }
      }
    });
    client.subscribe(topic, MqttQos.atMostOnce);
    unawaited(
      closed.future.then((_) {
        updates?.cancel();
        messages.close();
      }),
    );
    return _MqttChannel(client, messages.stream, closed);
  }
}

/// The broker refused or couldn't be reached (deliberately vague).
class RealtimeUnavailable implements Exception {
  const RealtimeUnavailable();

  @override
  String toString() => 'Live updates are unavailable';
}

class _MqttChannel implements RealtimeChannel {
  _MqttChannel(this._client, this.messages, this._closed);

  final MqttClient _client;
  final Completer<void> _closed;

  @override
  final Stream<String> messages;

  @override
  Future<void> get closed => _closed.future;

  @override
  void close() {
    _client.disconnect();
    if (!_closed.isCompleted) _closed.complete();
  }
}
