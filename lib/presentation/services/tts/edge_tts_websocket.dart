import 'edge_tts_websocket_stub.dart'
    if (dart.library.io) 'edge_tts_websocket_io.dart';

typedef EdgeTtsWebSocketConnector =
    EdgeTtsWebSocketConnection Function(Uri uri);

abstract class EdgeTtsWebSocketConnection {
  Future<void> get ready;
  Stream<dynamic> get stream;
  void sendText(String data);
  Future<void> close();
}

class EdgeTtsWebSocketUpgradeException implements Exception {
  const EdgeTtsWebSocketUpgradeException({
    required this.statusCode,
    this.reasonPhrase,
    this.body,
    this.dateHeader,
  });

  final int statusCode;
  final String? reasonPhrase;
  final String? body;
  final String? dateHeader;

  @override
  String toString() =>
      'EdgeTtsWebSocketUpgradeException(statusCode: $statusCode, '
      'reasonPhrase: $reasonPhrase)';
}

EdgeTtsWebSocketConnection openEdgeTtsWebSocket(Uri uri) {
  return openEdgeTtsWebSocketImpl(uri);
}
