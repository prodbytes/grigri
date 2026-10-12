import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

/// Android, iOS and desktop: dart:io's WebSocket.
MqttClient mqttWebSocketClient(Uri url, String clientId) {
  final client = MqttServerClient.withPort(
    url.toString(),
    clientId,
    // The library puts this port in the URL (443 when it names none).
    url.port,
  );
  client
    ..useWebSocket = true
    ..websocketProtocols = MqttClientConstants.protocolsSingleDefault;
  return client;
}
