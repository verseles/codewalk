import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'http_transport.dart';
import 'websocket_frames.dart';
import 'websocket_transport.dart';

final class IoWebSocketSession implements EndpointWebSocket {
  IoWebSocketSession(
    this._socket, {
    required this.maxMessageBytes,
    required this.maxQueuedBytes,
    required this.maxQueuedMessages,
    required this.writeTimeout,
    required this.closeTimeout,
    required this.onClosed,
  }) : _decoder = ServerWebSocketDecoder(maxMessageBytes: maxMessageBytes) {
    _controller = StreamController<({WebSocketMessage value, int bytes})>(
      onPause: () => _subscription?.pause(),
      onResume: () => _subscription?.resume(),
      onCancel: close,
    );
    _subscription = _socket.listen(
      _receive,
      onError: (Object _) => fail(TransportFailure.connection),
      onDone: () {
        if (_closed) return;
        if (_closing) {
          _destroy();
          return;
        }
        try {
          _decoder.finish();
        } on TransportException catch (error) {
          fail(error.failure);
          return;
        }
        fail(TransportFailure.connection);
      },
    );
    _messages = _controller.stream.map((message) {
      _queuedMessages--;
      _queuedBytes -= message.bytes;
      return message.value;
    });
  }

  final io.Socket _socket;
  final ServerWebSocketDecoder _decoder;
  final int maxMessageBytes;
  final int maxQueuedBytes;
  final int maxQueuedMessages;
  final Duration writeTimeout;
  final Duration closeTimeout;
  final void Function() onClosed;
  late final StreamController<({WebSocketMessage value, int bytes})>
  _controller;
  late final Stream<WebSocketMessage> _messages;
  StreamSubscription<List<int>>? _subscription;
  StreamSubscription<void>? _cancellation;
  Future<void> _writeTail = Future.value();
  Future<void>? _closeFuture;
  Completer<void>? _closeCompletion;
  Timer? _closeTimer;
  int _queuedBytes = 0;
  int _queuedMessages = 0;
  int _writeBytes = 0;
  int _writeMessages = 0;
  int? _closeCode;
  bool _closed = false;
  bool _closing = false;
  bool _receivedClose = false;

  void attachCancellation(RequestCancellation? cancellation) {
    if (cancellation == null) return;
    if (cancellation.isCancelled) {
      fail(TransportFailure.cancelled);
    } else {
      _cancellation = cancellation.onCancel.listen(
        (_) => fail(TransportFailure.cancelled),
      );
    }
  }

  @override
  Stream<WebSocketMessage> get messages => _messages;
  @override
  bool get isClosed => _closed;
  @override
  int? get closeCode => _closeCode;

  void _receive(List<int> bytes) {
    if (_closed) return;
    try {
      for (final packet in _decoder.add(bytes)) {
        if (_closed) return;
        switch (packet.opcode) {
          case 8:
            _receivedClose = true;
            _closeCode = packet.payload.isEmpty
                ? null
                : (packet.payload[0] << 8) | packet.payload[1];
            unawaited(_beginClose(packet.payload));
            return;
          case 9:
            if (!_receivedClose) {
              unawaited(
                _write(10, packet.payload).catchError((Object error) {
                  fail(
                    error is TransportException
                        ? error.failure
                        : TransportFailure.connection,
                  );
                }),
              );
            }
          case 10:
            break;
          default:
            if (_closing) continue;
            if (_queuedMessages >= maxQueuedMessages ||
                packet.payload.length > maxQueuedBytes - _queuedBytes) {
              fail(TransportFailure.bufferOverflow);
              return;
            }
            final message = packet.opcode == 1
                ? WebSocketText(utf8.decode(packet.payload))
                : WebSocketBinary(packet.payload);
            _queuedMessages++;
            _queuedBytes += packet.payload.length;
            _controller.add((value: message, bytes: packet.payload.length));
        }
      }
    } on TransportException catch (error) {
      fail(error.failure);
    } on Object {
      fail(TransportFailure.invalidResponse);
    }
  }

  @override
  Future<void> sendText(String text) {
    if (_closing) {
      return Future.error(const TransportException(TransportFailure.closed));
    }
    try {
      return _write(1, webSocketTextBytes(text, maxMessageBytes));
    } on TransportException catch (error) {
      return Future.error(error);
    }
  }

  @override
  Future<void> sendBytes(List<int> bytes) => _closing
      ? Future.error(const TransportException(TransportFailure.closed))
      : _write(2, bytes);

  Future<void> _write(int opcode, List<int> payload) {
    if (_closed) {
      return Future.error(const TransportException(TransportFailure.closed));
    }
    final limit = opcode >= 8 ? 125 : maxMessageBytes;
    if (payload.length > limit) {
      return Future.error(
        const TransportException(TransportFailure.bodyTooLarge),
      );
    }
    final retained = payload.length + 14;
    if (_writeMessages >= maxQueuedMessages ||
        retained > maxQueuedBytes - _writeBytes) {
      return Future.error(
        const TransportException(TransportFailure.bufferOverflow),
      );
    }
    List<int> bytes;
    try {
      bytes = encodeClientWebSocketFrame(opcode, payload);
    } on TransportException catch (error) {
      return Future.error(error);
    }
    _writeBytes += retained;
    _writeMessages++;
    final operation = _writeTail.then((_) async {
      try {
        if (_closed) {
          throw const TransportException(TransportFailure.closed);
        }
        _socket.add(bytes);
        await _socket.flush().timeout(writeTimeout);
      } on TimeoutException {
        fail(TransportFailure.timeout);
        throw const TransportException(TransportFailure.timeout);
      } on TransportException {
        rethrow;
      } on Object {
        fail(TransportFailure.connection);
        throw const TransportException(TransportFailure.connection);
      } finally {
        _writeBytes -= retained;
        _writeMessages--;
      }
    });
    _writeTail = operation.catchError((Object _) {});
    return operation;
  }

  void fail(TransportFailure failure) {
    if (_closed) return;
    _controller.addError(TransportException(failure));
    _destroy();
  }

  Future<void> _beginClose(List<int> payload) {
    if (_closeFuture != null) return _closeFuture!;
    if (_closed) return Future.value();
    _closing = true;
    _closeCompletion = Completer<void>();
    _closeFuture = _closeCompletion!.future;
    // Keep reading control frames until the peer closes TCP or bounded expiry.
    _subscription?.resume();
    _closeTimer = Timer(closeTimeout, _destroy);
    unawaited(
      _write(8, payload).catchError((Object error) {
        fail(
          error is TransportException
              ? error.failure
              : TransportFailure.connection,
        );
      }),
    );
    return _closeFuture!;
  }

  @override
  Future<void> close({int code = 1000, String reason = ''}) {
    if (_closeFuture != null) return _closeFuture!;
    if (_closed) return Future.value();
    if (!validWebSocketCloseCode(code)) {
      return Future.error(ArgumentError('Invalid close code.'));
    }
    List<int> reasonBytes;
    try {
      reasonBytes = webSocketTextBytes(reason, 123);
    } on TransportException catch (error) {
      return Future.error(error);
    }
    _closeCode = code;
    return _beginClose([code >> 8, code & 255, ...reasonBytes]);
  }

  void _destroy() {
    if (_closed) return;
    _closed = true;
    _closeTimer?.cancel();
    _socket.destroy();
    final subscription = _subscription;
    if (subscription != null) unawaited(subscription.cancel());
    final cancellation = _cancellation;
    if (cancellation != null) unawaited(cancellation.cancel());
    unawaited(_controller.close());
    onClosed();
    if (!(_closeCompletion?.isCompleted ?? true)) _closeCompletion!.complete();
  }
}
