import 'dart:typed_data';

import 'http_transport.dart';

sealed class WebSocketMessage {
  const WebSocketMessage();
}

final class WebSocketText extends WebSocketMessage {
  const WebSocketText(this.text);
  final String text;
}

final class WebSocketBinary extends WebSocketMessage {
  WebSocketBinary(List<int> bytes)
    : bytes = Uint8List.fromList(bytes).asUnmodifiableView();
  final Uint8List bytes;
}

abstract interface class EndpointWebSocket {
  Stream<WebSocketMessage> get messages;
  bool get isClosed;
  int? get closeCode;

  /// Completion means local flushing, not peer admission. Never auto-replayed.
  Future<void> sendText(String text);
  Future<void> sendBytes(List<int> bytes);
  Future<void> close({int code = 1000, String reason = ''});
}

abstract interface class EndpointWebSocketTransport {
  Uri get endpoint;
  bool get isClosed;
  Future<EndpointWebSocket> connect(
    String path, {
    Map<String, String> headers = const {},
    RequestCancellation? cancellation,
  });
  void close();
}
