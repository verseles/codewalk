import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../core/tailscale/tailscale_tcp_connection.dart';
import 'codewalk_terminal_socket.dart';

Future<CodewalkTerminalSocketConnection> openCodewalkTerminalSocketImpl({
  required Uri url,
  Map<String, String>? headers,
}) async {
  final socket = await WebSocket.connect(url.toString(), headers: headers);
  return _IoCodewalkTerminalSocketConnection(socket);
}

class _IoCodewalkTerminalSocketConnection
    implements CodewalkTerminalSocketConnection {
  _IoCodewalkTerminalSocketConnection(this._socket);

  final WebSocket _socket;

  @override
  Stream<List<int>> get messages => _socket.map((event) {
    if (event is String) {
      return utf8.encode(event);
    }
    if (event is List<int>) {
      return List<int>.from(event);
    }
    throw UnsupportedError('Unsupported terminal websocket frame type');
  });

  @override
  Future<void> get done => _socket.done;

  @override
  void send(List<int> data) {
    _socket.add(data);
  }

  @override
  Future<void> close() async {
    await _socket.close();
  }
}

/// WebSocket GUID mixed into the handshake accept key (RFC 6455 §4.1).
const _webSocketGuid = '258EAFA5-E914-47DA-95CA-C5AB0DC85B11';

/// Bounds the HTTP Upgrade response head; terminal servers answer in bytes.
const _maxHandshakeHeadBytes = 32 * 1024;

/// Grace period for the server close echo before forcing TCP teardown.
const _closeGrace = Duration(seconds: 5);

/// Upper bound for one incoming frame payload and for buffered unparsed
/// bytes; guards against a misbehaving peer exhausting memory.
const _maxIncomingFrameBytes = 64 * 1024 * 1024;

final Random _secureRandom = Random.secure();

/// Opens the terminal WebSocket over a TCP connection dialed through the
/// embedded Tailscale node.
///
/// `dart:io`'s [WebSocket] always uses the platform network stack, which
/// cannot reach tailnet-only destinations (MagicDNS names, `100.x` IPs)
/// when no system VPN is active. This transport performs the same RFC 6455
/// client handshake and framing over `dial`, so the wire bytes and URL are
/// identical to [openCodewalkTerminalSocketImpl] — only the route changes
/// (ADR-023: transport-only, no server contract change).
///
/// Only `ws` (plain HTTP) URLs are supported: tailnet profiles use
/// `http://<peer>:4096`, and the tailnet itself already encrypts traffic.
Future<CodewalkTerminalSocketConnection>
openCodewalkTerminalSocketViaTailscaleImpl({
  required Uri url,
  Map<String, String>? headers,
  required TailscaleTcpDial dial,
  required Duration timeout,
  int? maxIncomingFrameBytes,
}) async {
  if (url.scheme != 'ws') {
    throw UnsupportedError(
      'Terminal over Tailscale supports ws (http) profiles only; '
      'got scheme "${url.scheme}".',
    );
  }
  final host = url.host;
  if (host.isEmpty) {
    throw ArgumentError.value(
      url.toString(),
      'url',
      'Terminal WebSocket URL has no host.',
    );
  }
  final port = url.hasPort ? url.port : 80;
  final connection = await dial(host, port, timeout: timeout);
  _TailscaleTerminalSocketConnection? socket;
  try {
    socket = _TailscaleTerminalSocketConnection(
      connection,
      maxIncomingFrameBytes: maxIncomingFrameBytes,
    );
    await socket.handshake(url: url, headers: headers, timeout: timeout);
  } catch (_) {
    await socket?._abort();
    try {
      await connection.close();
    } catch (_) {
      // Teardown is best effort.
    }
    rethrow;
  }
  return socket;
}

class _TailscaleTerminalSocketConnection
    implements CodewalkTerminalSocketConnection {
  _TailscaleTerminalSocketConnection(
    this._connection, {
    int? maxIncomingFrameBytes,
  }) : _maxBytes = maxIncomingFrameBytes ?? _maxIncomingFrameBytes {
    _subscription = _connection.input.listen(
      _onData,
      onError: _onTransportError,
      onDone: _onTransportDone,
      cancelOnError: false,
    );
  }

  final TailscaleTcpConnection _connection;

  /// Inbound size guard; injectable for tests, 64 MiB in production.
  final int _maxBytes;
  late final StreamSubscription<Uint8List> _subscription;

  // Single-subscription: the controller listens exactly once.
  final StreamController<List<int>> _incoming = StreamController<List<int>>();
  final Completer<void> _done = Completer<void>();

  // Handshake phase: non-null until the 101 response is validated.
  Completer<void>? _handshake = Completer<void>();
  String _expectedAccept = '';
  final BytesBuilder _head = BytesBuilder(copy: false);

  // Frame phase.
  final BytesBuilder _frames = BytesBuilder(copy: false);
  int? _fragmentOpcode;
  final BytesBuilder _fragment = BytesBuilder(copy: false);
  bool _closeSent = false;
  bool _tcpClosed = false;

  /// Set synchronously when teardown begins so buffered frames are dropped
  /// immediately instead of racing the async teardown below. `_tcpClosed`
  /// stays owned by `_closeTcp` (physical close, exactly once).
  bool _teardownStarted = false;

  @override
  Stream<List<int>> get messages => _incoming.stream;

  @override
  Future<void> get done => _done.future;

  @override
  void send(List<int> data) {
    if (_tcpClosed || _closeSent || _teardownStarted) return;
    unawaited(
      _connection.write(_encodeFrame(0x2, data)).then<void>(
        (_) {},
        onError: (_) => _abort(),
      ),
    );
  }

  @override
  Future<void> close() async {
    if (_done.isCompleted) return;
    try {
      // Bound the whole close attempt: a stalled close-frame write must
      // not hang stop/reconnect while the server is gone.
      await _sendClose().timeout(_closeGrace);
    } catch (_) {
      // Close write stalled or transport broken; teardown below drives `done`.
    }
    if (_done.isCompleted) return;
    try {
      await _done.future.timeout(_closeGrace);
    } on TimeoutException {
      await _abort();
    }
  }

  Future<void> _sendClose() async {
    if (!_closeSent && !_tcpClosed) {
      _closeSent = true;
      await _connection.write(_encodeFrame(0x8, _closePayload(1000, '')));
    }
  }

  Future<void> handshake({
    required Uri url,
    Map<String, String>? headers,
    required Duration timeout,
  }) async {
    final pending = _handshake;
    if (pending == null) {
      throw StateError('Terminal WebSocket handshake already ran.');
    }
    final keyBytes = List<int>.generate(16, (_) => _secureRandom.nextInt(256));
    final key = base64Encode(keyBytes);
    _expectedAccept = base64Encode(
      sha1.convert(utf8.encode('$key$_webSocketGuid')).bytes,
    );
    final request = _handshakeRequest(url, headers, key);
    try {
      await _connection.write(request).timeout(timeout);
      await pending.future.timeout(
        timeout,
        onTimeout: () =>
            throw TimeoutException('Terminal WebSocket handshake timed out.'),
      );
    } finally {
      if (!_handshakeCompleted) _handshake = null;
    }
  }

  bool get _handshakeCompleted => _handshake == null;

  void _onData(Uint8List chunk) {
    final pending = _handshake;
    if (pending != null) {
      // A timed-out handshake is already tearing down; ignore late bytes.
      if (pending.isCompleted) return;
      _head.add(chunk);
      _tryFinishHandshake(pending);
      return;
    }
    // Fail closed: frames buffered with (or after) a protocol error must
    // not be processed while async teardown is still awaiting.
    if (_teardownStarted) return;
    _frames.add(chunk);
    _pumpFrames();
  }

  void _tryFinishHandshake(Completer<void> pending) {    final bytes = _head.toBytes();
    final end = _indexOfHeadEnd(bytes);
    if (end < 0) {
      if (_head.length > _maxHandshakeHeadBytes) {
        pending.completeError(
          StateError('Terminal WebSocket handshake response too large.'),
        );
      }
      return;
    }
    // Bound only the response head: frame bytes coalesced past the
    // terminator belong to the frame pump, not to this limit.
    if (end > _maxHandshakeHeadBytes) {
      pending.completeError(
        StateError('Terminal WebSocket handshake response too large.'),
      );
      return;
    }
    try {
      _validateHandshake(
        ascii.decode(bytes.sublist(0, end), allowInvalid: true),
        _expectedAccept,
      );
    } catch (error, stackTrace) {
      pending.completeError(error, stackTrace);
      return;
    }
    if (end < bytes.length) {
      _frames.add(Uint8List.sublistView(bytes, end));
    }
    _head.clear();
    _handshake = null;
    pending.complete();
    // The server may coalesce the first frame with the 101 response and
    // then wait for input; pump trailing bytes now instead of stalling
    // until the next TCP chunk.
    if (_frames.isNotEmpty) _pumpFrames();
  }

  void _pumpFrames() {
    while (!_tcpClosed && !_teardownStarted) {
      if (_frames.length > _maxBytes + 16) {
        _protocolError('incoming frame buffer overflow');
        return;
      }
      final bytes = _frames.toBytes();
      if (bytes.length < 2) return;
      final fin = bytes[0] & 0x80 != 0;
      final opcode = bytes[0] & 0x0F;
      final masked = bytes[1] & 0x80 != 0;
      var length = bytes[1] & 0x7F;
      var offset = 2;
      if (length == 126) {
        if (bytes.length < 4) return;
        length = (bytes[2] << 8) | bytes[3];
        offset = 4;
      } else if (length == 127) {
        if (bytes.length < 10) return;
        length = 0;
        for (var i = 0; i < 8; i++) {
          length = (length << 8) | bytes[2 + i];
        }
        offset = 10;
      }
      if (length < 0 || length > _maxBytes) {
        _protocolError('oversize frame payload');
        return;
      }
      final maskBytes = masked ? 4 : 0;
      if (bytes.length < offset + maskBytes + length) return;
      var payload = Uint8List.sublistView(
        bytes,
        offset + maskBytes,
        offset + maskBytes + length,
      );
      if (masked) {
        payload = _applyMask(payload, bytes.sublist(offset, offset + 4));
      }
      _frames.clear();
      if (offset + maskBytes + length < bytes.length) {
        _frames.add(
          Uint8List.sublistView(bytes, offset + maskBytes + length),
        );
      }
      _handleFrame(fin: fin, opcode: opcode, payload: payload);
    }
  }

  void _handleFrame({
    required bool fin,
    required int opcode,
    required Uint8List payload,
  }) {
    if (opcode >= 0x8 && (!fin || payload.length > 125)) {
      _protocolError('malformed control frame');
      return;
    }
    switch (opcode) {
      case 0x8: // Close.
        _onCloseFrame(payload);
      case 0x9: // Ping: answer with a pong carrying the same payload.
        if (!_closeSent && !_tcpClosed) {
          unawaited(
            _connection.write(_encodeFrame(0xA, payload)).then<void>(
              (_) {},
              onError: (_) => _abort(),
            ),
          );
        }
      case 0xA: // Pong: drop it; never terminal output.
        break;
      case 0x0: // Continuation.
      case 0x1: // Text.
      case 0x2: // Binary.
        _onDataFrame(fin: fin, opcode: opcode, payload: payload);
      default:
        _protocolError('unsupported opcode $opcode');
    }
  }

  void _onDataFrame({
    required bool fin,
    required int opcode,
    required Uint8List payload,
  }) {
    if (opcode != 0x0 && _fragmentOpcode != null) {
      _protocolError('new data frame before fragmented message completed');
      return;
    }
    if (opcode == 0x0 && _fragmentOpcode == null) {
      _protocolError('unexpected continuation frame');
      return;
    }
    if (!fin) {
      _fragmentOpcode ??= opcode;
      if (_fragment.length + payload.length > _maxBytes) {
        _protocolError('fragmented message exceeds size limit');
        return;
      }
      _fragment.add(payload);
      return;
    }
    if (_fragmentOpcode != null) {
      if (_fragment.length + payload.length > _maxBytes) {
        _protocolError('fragmented message exceeds size limit');
        return;
      }
      _fragment.add(payload);
      _incoming.add(_fragment.toBytes());
      _fragment.clear();
      _fragmentOpcode = null;
      return;
    }
    _incoming.add(payload);
  }

  void _onCloseFrame(Uint8List payload) {
    // Fail fast like _abort: once either side closes, later frames (even
    // ones buffered in the same chunk) are teardown noise, not output.
    // _closeTcp stays the sole owner of the physical close below.
    _teardownStarted = true;
    if (!_closeSent) {
      _closeSent = true;
      // Bound the echo: a stalled write must not leave `done` pending
      // forever when the peer initiated the close.
      unawaited(
        _connection
            .write(_encodeFrame(0x8, payload))
            .timeout(_closeGrace)
            .then<void>(
              (_) => _finishClose(),
              onError: (_) => _abort(),
            ),
      );
      return;
    }
    unawaited(_finishClose());
  }

  void _onTransportError(Object error, StackTrace stackTrace) {
    final pending = _handshake;
    if (pending != null && !pending.isCompleted) {
      pending.completeError(error, stackTrace);
      return;
    }
    if (!_incoming.isClosed) _incoming.addError(error, stackTrace);
    unawaited(_abort());
  }

  void _onTransportDone() {
    final pending = _handshake;
    if (pending != null && !pending.isCompleted) {
      pending.completeError(
        StateError(
          'Tailscale connection closed before WebSocket handshake completed.',
        ),
      );
      return;
    }
    // Matches direct-WebSocket behavior: the transport ending surfaces as
    // `done` (the controller reports `exited`), not as a stream error.
    unawaited(_finishClose());
  }

  void _protocolError(String message) {
    final error = StateError('Terminal WebSocket error: $message');
    final pending = _handshake;
    if (pending != null && !pending.isCompleted) {
      pending.completeError(error);
      return;
    }
    if (!_incoming.isClosed) _incoming.addError(error);
    unawaited(_abort());
  }

  Future<void> _finishClose() async {
    await _closeTcp();
    _closeIncoming();
    if (!_done.isCompleted) _done.complete();
  }

  /// Initiates (but never awaits) the incoming stream close.
  ///
  /// Awaiting [StreamController.close] on a single-subscription controller
  /// that never had a listener never completes; teardown must not depend
  /// on listener attachment.
  void _closeIncoming() {
    if (_incoming.isClosed) return;
    try {
      unawaited(_incoming.close());
    } catch (_) {
      // Teardown is best effort.
    }
  }

  Future<void> _abort() async {
    // Fail fast and synchronously: buffered frames must not be processed
    // after a protocol/transport error while teardown is still awaiting.
    _teardownStarted = true;
    try {
      await _subscription.cancel();
    } catch (_) {
      // Teardown is best effort.
    }
    // _closeTcp owns _tcpClosed and closes the native connection exactly
    // once via _finishClose; pre-setting the flag here would leak it.
    await _finishClose();
  }

  Future<void> _closeTcp() async {
    if (_tcpClosed) return;
    _tcpClosed = true;
    try {
      await _connection.close();
    } catch (_) {
      // Teardown is best effort.
    }
  }
}

Uint8List _handshakeRequest(
  Uri url,
  Map<String, String>? headers,
  String key,
) {
  _rejectCrlf('Sec-WebSocket-Key', key);
  final path = url.path.isEmpty ? '/' : url.path;
  final requestLine = url.hasQuery ? 'GET $path?${url.query}' : 'GET $path';
  // Uri.host strips IPv6 brackets; re-add them so the Host header stays a
  // valid authority (TailscalePeer.defaultUrl brackets them the same way).
  final bareHost = url.host.contains(':') ? '[${url.host}]' : url.host;
  final hostHeader = url.hasPort ? '$bareHost:${url.port}' : bareHost;
  final buffer = StringBuffer()
    ..write(requestLine)
    ..write(' HTTP/1.1\r\nHost: ')
    ..write(hostHeader)
    ..write(
      '\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: ',
    )
    ..write(key)
    ..write('\r\nSec-WebSocket-Version: 13\r\n');
  headers?.forEach((name, value) {
    _rejectCrlf(name, value);
    buffer
      ..write(name)
      ..write(': ')
      ..write(value)
      ..write('\r\n');
  });
  buffer.write('\r\n');
  return Uint8List.fromList(ascii.encode(buffer.toString()));
}

void _rejectCrlf(String name, String value) {
  if (name.contains(RegExp(r'[\r\n:]')) || value.contains(RegExp(r'[\r\n]'))) {
    throw ArgumentError.value(
      name,
      'header',
      'Terminal WebSocket header must not contain CR, LF, or colon.',
    );
  }
}

void _validateHandshake(String head, String expectedAccept) {
  final lines = head.split('\r\n');
  final status = lines.first.split(' ');
  if (status.length < 2 || status[1] != '101') {
    throw StateError(
      'Terminal WebSocket handshake rejected (${lines.first.trim()}).',
    );
  }
  final responseHeaders = <String, String>{};
  for (final line in lines.skip(1)) {
    final separator = line.indexOf(':');
    if (separator <= 0) continue;
    responseHeaders[line.substring(0, separator).trim().toLowerCase()] =
        line.substring(separator + 1).trim();
  }
  if (!_hasToken(responseHeaders['upgrade'], 'websocket')) {
    throw StateError(
      'Terminal WebSocket handshake missing Upgrade: websocket.',
    );
  }
  if (!_hasToken(responseHeaders['connection'], 'upgrade')) {
    throw StateError(
      'Terminal WebSocket handshake missing Connection: Upgrade.',
    );
  }
  if (responseHeaders['sec-websocket-accept'] != expectedAccept) {
    throw StateError('Terminal WebSocket handshake accept mismatch.');
  }
}

/// Case-insensitive comma-token match for HTTP header values (RFC 6455 §4.2.1
/// sends `Upgrade: websocket` but proxies vary the casing).
bool _hasToken(String? headerValue, String token) {
  if (headerValue == null) return false;
  return headerValue
      .split(',')
      .map((value) => value.trim().toLowerCase())
      .contains(token);
}

/// Byte offset just past the first `\r\n\r\n`, or -1 when incomplete.
int _indexOfHeadEnd(Uint8List bytes) {
  for (var i = 0; i + 3 < bytes.length; i++) {
    if (bytes[i] == 13 &&
        bytes[i + 1] == 10 &&
        bytes[i + 2] == 13 &&
        bytes[i + 3] == 10) {
      return i + 4;
    }
  }
  return -1;
}

Uint8List _encodeFrame(int opcode, List<int> payload) {
  final length = payload.length;
  final extended = length < 126 ? 0 : length <= 0xFFFF ? 2 : 8;
  final out = Uint8List(2 + extended + 4 + length);
  out[0] = 0x80 | opcode;
  var offset = 1;
  if (length < 126) {
    out[1] = 0x80 | length;
    offset = 2;
  } else if (length <= 0xFFFF) {
    out[1] = 0x80 | 126;
    out[2] = (length >> 8) & 0xFF;
    out[3] = length & 0xFF;
    offset = 4;
  } else {
    out[1] = 0x80 | 127;
    for (var i = 0; i < 8; i++) {
      out[2 + i] = (length >> (56 - 8 * i)) & 0xFF;
    }
    offset = 10;
  }
  final mask = List<int>.generate(4, (_) => _secureRandom.nextInt(256));
  out.setRange(offset, offset + 4, mask);
  for (var i = 0; i < length; i++) {
    out[offset + 4 + i] = payload[i] ^ mask[i % 4];
  }
  return out;
}

Uint8List _applyMask(Uint8List payload, List<int> mask) {
  final out = Uint8List(payload.length);
  for (var i = 0; i < payload.length; i++) {
    out[i] = payload[i] ^ mask[i % 4];
  }
  return out;
}

Uint8List _closePayload(int code, String reason) {
  final reasonBytes = utf8.encode(reason);
  final out = Uint8List(2 + reasonBytes.length);
  out[0] = (code >> 8) & 0xFF;
  out[1] = code & 0xFF;
  out.setRange(2, out.length, reasonBytes);
  return out;
}
