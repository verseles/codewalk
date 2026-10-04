import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'http_transport.dart';

enum SseEofPolicy {
  /// Require a complete blank-line boundary, including for the final event.
  discard,

  /// Explicit compatibility mode: dispatch valid unterminated final fields.
  /// The consumer must reconcile after disconnect; this does not validate JSON.
  dispatch,
}

enum SseFailure { malformedUtf8, frameTooLarge, lineTooLarge }

final class SseException implements Exception {
  const SseException(this.failure);
  final SseFailure failure;

  @override
  String toString() => 'SseException(${failure.name})';
}

/// Generic framing fields, without JSON decoding, replay or domain projection.
final class SseFrame {
  const SseFrame({
    required this.data,
    this.event,
    this.id,
    this.retryMilliseconds,
  });

  final String data;
  final String? event;

  /// The field in this frame only; the transport maintains no replay cursor.
  final String? id;
  final int? retryMilliseconds;
}

/// Strict UTF-8 SSE framing with byte limits independent of chunk length.
/// The frame cap counts all wire bytes through its delimiter; the line cap
/// counts line content bytes excluding CR/LF. No background isolate is implied.
final class SseDecoder extends StreamTransformerBase<List<int>, SseFrame> {
  SseDecoder({
    this.maxFrameBytes = defaultTransportByteLimit,
    this.maxLineBytes = defaultTransportByteLimit,
    this.eofPolicy = SseEofPolicy.discard,
  }) {
    if (maxFrameBytes <= 0 || maxLineBytes <= 0) {
      throw ArgumentError('SSE byte limits must be positive.');
    }
  }

  final int maxFrameBytes;
  final int maxLineBytes;
  final SseEofPolicy eofPolicy;

  @override
  Stream<SseFrame> bind(Stream<List<int>> stream) async* {
    final state = _SseState(maxFrameBytes, maxLineBytes, eofPolicy);
    await for (final chunk in stream) {
      for (final byte in chunk) {
        final frame = state.add(byte);
        if (frame != null) yield frame;
      }
    }
    final finalFrame = state.finish();
    if (finalFrame != null) yield finalFrame;
  }
}

final class _SseState {
  _SseState(this.maxFrameBytes, this.maxLineBytes, this.eofPolicy)
    : _line = Uint8List(maxLineBytes < 1024 ? maxLineBytes : 1024);

  final int maxFrameBytes;
  final int maxLineBytes;
  final SseEofPolicy eofPolicy;
  Uint8List _line;
  int _lineLength = 0;
  int _frameBytes = 0;
  bool _pendingCarriageReturn = false;
  bool _firstLine = true;
  final _data = <String>[];
  String? _event;
  String? _id;
  int? _retry;

  SseFrame? add(int byte) {
    if (byte < 0 || byte > 255) {
      throw const SseException(SseFailure.malformedUtf8);
    }
    SseFrame? emitted;
    if (_pendingCarriageReturn) {
      _pendingCarriageReturn = false;
      if (byte == 10) {
        _count();
        return _endLine();
      }
      emitted = _endLine();
    }
    _count();
    if (byte == 13) {
      _pendingCarriageReturn = true;
    } else if (byte == 10) {
      emitted = _endLine();
    } else {
      if (_lineLength == maxLineBytes) {
        throw const SseException(SseFailure.lineTooLarge);
      }
      if (_lineLength == _line.length) {
        final capacity = (_line.length * 2).clamp(1, maxLineBytes);
        final next = Uint8List(capacity);
        next.setRange(0, _lineLength, _line);
        _line = next;
      }
      _line[_lineLength++] = byte;
    }
    return emitted;
  }

  void _count() {
    if (_frameBytes == maxFrameBytes) {
      throw const SseException(SseFailure.frameTooLarge);
    }
    _frameBytes++;
  }

  SseFrame? _endLine() {
    String line;
    try {
      line = utf8.decode(Uint8List.sublistView(_line, 0, _lineLength));
    } on FormatException {
      throw const SseException(SseFailure.malformedUtf8);
    }
    _lineLength = 0;
    if (_firstLine) {
      _firstLine = false;
      if (line.startsWith('\ufeff')) line = line.substring(1);
    }
    if (line.isEmpty) return _dispatch();
    if (line.startsWith(':')) return null;
    final colon = line.indexOf(':');
    final field = colon < 0 ? line : line.substring(0, colon);
    var value = colon < 0 ? '' : line.substring(colon + 1);
    // SSE strips exactly one leading ASCII space, not all whitespace.
    if (value.startsWith(' ')) value = value.substring(1);
    switch (field) {
      case 'data':
        _data.add(value);
      case 'event':
        _event = value;
      case 'id':
        if (!value.contains('\u0000')) _id = value;
      case 'retry':
        if (RegExp(r'^[0-9]+$').hasMatch(value)) _retry = int.tryParse(value);
    }
    return null;
  }

  SseFrame? _dispatch() {
    final result = _data.isEmpty
        ? null
        : SseFrame(
            data: _data.join('\n'),
            event: _event,
            id: _id,
            retryMilliseconds: _retry,
          );
    _data.clear();
    _event = null;
    _id = null;
    _retry = null;
    _frameBytes = 0;
    return result;
  }

  SseFrame? finish() {
    if (_pendingCarriageReturn) {
      _pendingCarriageReturn = false;
      final completed = _endLine();
      if (completed != null) return completed;
    }
    // Even discard mode must reject truncated UTF-8 in the EOF fragment.
    if (_lineLength > 0) _endLine();
    return eofPolicy == SseEofPolicy.dispatch ? _dispatch() : null;
  }
}
