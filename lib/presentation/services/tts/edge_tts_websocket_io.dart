import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'edge_tts_protocol.dart';
import 'edge_tts_websocket.dart';

const Duration _kEdgeTtsIoConnectTimeout = Duration(seconds: 10);

EdgeTtsWebSocketConnection openEdgeTtsWebSocketImpl(Uri uri) {
  return _IoEdgeTtsWebSocketConnection(_connectEdgeTtsWebSocket(uri));
}

Future<WebSocket> _connectEdgeTtsWebSocket(Uri uri) async {
  final requestUri = uri.replace(
    scheme: uri.scheme == 'wss' ? 'https' : 'http',
  );
  final client = HttpClient()
    ..userAgent =
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/$kEdgeTtsChromiumMajorVersion.0.0.0 '
        'Safari/537.36 Edg/$kEdgeTtsChromiumMajorVersion.0.0.0';
  try {
    final request = await client
        .openUrl('GET', requestUri)
        .timeout(_kEdgeTtsIoConnectTimeout);
    request.headers.set(HttpHeaders.hostHeader, uri.host);
    request.headers.set(HttpHeaders.upgradeHeader, 'websocket');
    request.headers.set(HttpHeaders.connectionHeader, 'Upgrade');
    request.headers.set('Sec-WebSocket-Key', edgeTtsWebSocketKey());
    request.headers.set('Sec-WebSocket-Version', '13');
    request.headers.set(
      'Sec-WebSocket-Extensions',
      'permessage-deflate; client_max_window_bits',
    );
    for (final entry in edgeTtsBrowserHeaders(
      muid: edgeTtsRandomHex32(),
    ).entries) {
      request.headers.set(entry.key, entry.value);
    }

    final response = await request.close().timeout(_kEdgeTtsIoConnectTimeout);
    if (response.statusCode != HttpStatus.switchingProtocols) {
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(_kEdgeTtsIoConnectTimeout, onTimeout: () => '');
      throw EdgeTtsWebSocketUpgradeException(
        statusCode: response.statusCode,
        reasonPhrase: response.reasonPhrase,
        body: body,
        dateHeader: response.headers.value(HttpHeaders.dateHeader),
      );
    }

    // The detached socket is owned and closed by WebSocket.fromUpgradedSocket.
    // ignore: close_sinks
    final socket = await response.detachSocket().timeout(
      _kEdgeTtsIoConnectTimeout,
    );
    return WebSocket.fromUpgradedSocket(
      socket,
      serverSide: false,
      compression: CompressionOptions.compressionDefault,
    );
  } finally {
    client.close(force: true);
  }
}

class _IoEdgeTtsWebSocketConnection implements EdgeTtsWebSocketConnection {
  _IoEdgeTtsWebSocketConnection(this._socketFuture);

  final Future<WebSocket> _socketFuture;
  late final Stream<dynamic> _stream =
      Stream<WebSocket>.fromFuture(_socketFuture).asyncExpand((socket) {
        _socket = socket;
        return socket;
      });
  WebSocket? _socket;
  bool _closed = false;

  @override
  Future<void> get ready async {
    _socket = await _socketFuture;
  }

  @override
  Stream<dynamic> get stream => _stream;

  @override
  void sendText(String data) {
    final socket = _socket;
    if (socket == null) {
      throw StateError('Edge TTS websocket is not ready.');
    }
    socket.add(data);
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    final existing = _socket;
    if (existing != null) {
      await existing.close();
      return;
    }
    unawaited(
      _socketFuture
          .then((socket) {
            _socket = socket;
            return socket.close();
          })
          .catchError((_) {}),
    );
  }
}
