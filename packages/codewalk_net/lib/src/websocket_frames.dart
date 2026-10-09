import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'http_transport.dart';

/// Complete data messages and interleaved control frames, without compression.
final class WebSocketPacket {
  const WebSocketPacket(this.opcode, this.payload);
  final int opcode;
  final Uint8List payload;
}

/// Incremental server-frame parser. Declared lengths are checked before payload
/// accumulation, including the total across fragmented messages.
final class ServerWebSocketDecoder {
  ServerWebSocketDecoder({required this.maxMessageBytes}) {
    if (maxMessageBytes <= 0) throw ArgumentError('Invalid message limit.');
  }

  final int maxMessageBytes;
  final _header = Uint8List(10);
  int _headerLength = 0;
  int _headerNeed = 2;
  int _remaining = 0;
  int _opcode = 0;
  bool _fin = false;
  bool _readingPayload = false;
  int? _messageOpcode;
  int _messageBytes = 0;
  final _frame = BytesBuilder();
  final _message = BytesBuilder();

  Iterable<WebSocketPacket> add(List<int> chunk) sync* {
    var offset = 0;
    while (offset < chunk.length) {
      if (!_readingPayload) {
        _header[_headerLength++] = chunk[offset++];
        if (_headerLength == 2) {
          final marker = _header[1] & 127;
          _headerNeed = marker == 126 ? 4 : (marker == 127 ? 10 : 2);
        }
        if (_headerLength != _headerNeed) continue;
        _readHeader();
        _readingPayload = true;
      }
      if (_remaining > 0) {
        final length = min(_remaining, chunk.length - offset);
        if (length == 0) continue;
        _frame.add(chunk.sublist(offset, offset + length));
        offset += length;
        _remaining -= length;
      }
      if (_remaining == 0) {
        final packet = _finishFrame();
        _headerLength = 0;
        _headerNeed = 2;
        _readingPayload = false;
        if (packet != null) yield packet;
      }
    }
  }

  void _readHeader() {
    _fin = (_header[0] & 128) != 0;
    _opcode = _header[0] & 15;
    if ((_header[0] & 112) != 0 ||
        (_header[1] & 128) != 0 ||
        !{0, 1, 2, 8, 9, 10}.contains(_opcode)) {
      _invalid();
    }
    final marker = _header[1] & 127;
    var length = marker;
    if (marker >= 126) {
      if (marker == 127 && (_header[2] & 128) != 0) _invalid();
      length = 0;
      for (var i = 2; i < _headerNeed; i++) {
        // Reject a declared huge length before shift overflow or allocation.
        if (length > maxMessageBytes) {
          throw const TransportException(TransportFailure.bodyTooLarge);
        }
        length = (length << 8) | _header[i];
      }
      if ((marker == 126 && length < 126) ||
          (marker == 127 && length < 65536)) {
        _invalid();
      }
    }
    if (_opcode >= 8) {
      if (!_fin || length > 125) _invalid();
    } else {
      if (_opcode == 0) {
        if (_messageOpcode == null) _invalid();
      } else {
        if (_messageOpcode != null) _invalid();
        _messageOpcode = _opcode;
      }
      if (length > maxMessageBytes - _messageBytes) {
        throw const TransportException(TransportFailure.bodyTooLarge);
      }
      _messageBytes += length;
    }
    _remaining = length;
  }

  WebSocketPacket? _finishFrame() {
    final payload = _frame.takeBytes();
    if (_opcode >= 8) {
      if (_opcode == 8) validateClosePayload(payload, fromServer: true);
      return WebSocketPacket(_opcode, payload);
    }
    _message.add(payload);
    if (!_fin) return null;
    final bytes = _message.takeBytes();
    final opcode = _messageOpcode!;
    _messageOpcode = null;
    _messageBytes = 0;
    if (opcode == 1) {
      try {
        utf8.decode(bytes);
      } on FormatException {
        _invalid();
      }
    }
    return WebSocketPacket(opcode, bytes);
  }

  void finish() {
    if (_headerLength != 0 || _readingPayload || _messageOpcode != null) {
      _invalid();
    }
  }
}

Never _invalid() =>
    throw const TransportException(TransportFailure.invalidResponse);

bool validWebSocketCloseCode(int code, {bool fromServer = false}) =>
    (code >= 3000 && code <= 4999) ||
    {
      1000,
      1001,
      1002,
      1003,
      1007,
      1008,
      1009,
      1011,
      1012,
      1013,
      1014,
    }.contains(code) ||
    (!fromServer && code == 1010);

void validateClosePayload(List<int> bytes, {bool fromServer = false}) {
  if (bytes.isEmpty) return;
  if (bytes.length == 1 || bytes.length > 125) _invalid();
  final code = (bytes[0] << 8) | bytes[1];
  if (!validWebSocketCloseCode(code, fromServer: fromServer)) _invalid();
  try {
    utf8.decode(bytes.sublist(2));
  } on FormatException {
    _invalid();
  }
}

Uint8List webSocketTextBytes(String text, int limit) {
  var length = 0;
  for (final rune in text.runes) {
    length += rune < 128 ? 1 : (rune < 2048 ? 2 : (rune < 65536 ? 3 : 4));
    if (length > limit) {
      throw const TransportException(TransportFailure.bodyTooLarge);
    }
  }
  return Uint8List.fromList(utf8.encode(text));
}

/// Every client frame, including pong and close, is unpredictably masked.
Uint8List encodeClientWebSocketFrame(int opcode, List<int> payload) {
  if (payload.any((byte) => byte < 0 || byte > 255)) {
    throw const TransportException(TransportFailure.invalidRequest);
  }
  final length = payload.length;
  final size = length < 126 ? 2 : (length < 65536 ? 4 : 10);
  final bytes = Uint8List(size + 4 + length);
  bytes[0] = 128 | opcode;
  bytes[1] = 128 | (size == 2 ? length : (size == 4 ? 126 : 127));
  for (var i = size - 1, n = length; i >= 2; i--, n >>= 8) {
    bytes[i] = n & 255;
  }
  final random = Random.secure();
  for (var i = 0; i < 4; i++) {
    bytes[size + i] = random.nextInt(256);
  }
  for (var i = 0; i < length; i++) {
    bytes[size + 4 + i] = payload[i] ^ bytes[size + i % 4];
  }
  return bytes;
}
