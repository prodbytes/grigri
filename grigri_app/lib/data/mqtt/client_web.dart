import 'package:mqtt_client/mqtt_browser_client.dart';
import 'package:mqtt_client/mqtt_client.dart';

/// The browser's WebSocket.
MqttClient mqttWebSocketClient(Uri url, String clientId) {
  final client = MqttBrowserClient.withPort(
    url.toString(),
    clientId,
    // The library puts this port in the URL (443 when it names none).
    url.port,
  );
  client.websocketProtocols = MqttClientConstants.protocolsSingleDefault;
  return client;
}
