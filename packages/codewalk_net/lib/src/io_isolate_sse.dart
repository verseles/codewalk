import 'dart:async';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'http_transport.dart';
import 'sse_decoder.dart';

enum _Input { chunk, eof, ack, cancel }

enum _Output { ready, batch, consumed, done, error }

/// One input chunk and one output batch at a time, with explicit ACKs in both
/// directions. Pausing/cancelling this stream propagates to HTTP and the worker.
Stream<List<SseFrame>> parseSseInIsolate(
  Stream<List<int>> input, {
  int maxFrameBytes = defaultTransportByteLimit,
  int maxLineBytes = defaultTransportByteLimit,
  int maxChunkBytes = 64 * 1024,
  int maxBatchFrames = 64,
  int maxBatchBytes = defaultTransportByteLimit,
}) => _SseBridge(
  input,
  maxFrameBytes,
  maxLineBytes,
  maxChunkBytes,
  maxBatchFrames,
  maxBatchBytes,
).stream;

/// Delivery ACKs and the pause gate are explicit even for input that yields no
/// frames. An async* yield alone cannot suspend a heartbeat-only input pump.
final class _SseBridge {
  _SseBridge(
    this.input,
    this.maxFrameBytes,
    this.maxLineBytes,
    this.maxChunkBytes,
    this.maxBatchFrames,
    this.maxBatchBytes,
  ) {
    if ([
      maxFrameBytes,
      maxLineBytes,
      maxChunkBytes,
      maxBatchFrames,
      maxBatchBytes,
    ].any((limit) => limit <= 0)) {
      throw ArgumentError('Isolate limits must be positive.');
    }
    _controller = StreamController<List<SseFrame>>(
      onListen: () => unawaited(_run()),
      onPause: () {
        _paused = true;
      },
      onResume: _resume,
      onCancel: _cancel,
    );
    stream = _controller.stream.map((frames) {
      if (!(_delivered?.isCompleted ?? true)) _delivered!.complete();
      return frames;
    });
    unawaited(_finished.future.catchError((Object _) {}));
  }

  final Stream<List<int>> input;
  final int maxFrameBytes,
      maxLineBytes,
      maxChunkBytes,
      maxBatchFrames,
      maxBatchBytes;
  late final StreamController<List<SseFrame>> _controller;
  late final Stream<List<SseFrame>> stream;
  final _finished = Completer<void>();
  final _exitSignal = Completer<void>();
  ReceivePort? _output;
  ReceivePort? _exit;
  StreamIterator<dynamic>? _messages;
  StreamIterator<List<int>>? _chunks;
  StreamSubscription<dynamic>? _exitSubscription;
  Isolate? _isolate;
  SendPort? _commands;
  Completer<void>? _consumed;
  Completer<void>? _delivered;
  Completer<void>? _resumed;
  Future<void>? _pumping;
  bool _paused = false;
  bool _closed = false;
  bool _userCancelled = false;

  Future<void> _ready() async {
    while (_paused && !_closed) {
      final signal = _resumed ??= Completer<void>();
      await signal.future;
    }
  }

  void _resume() {
    _paused = false;
    if (!(_resumed?.isCompleted ?? true)) _resumed!.complete();
    _resumed = null;
  }

  Future<void> _cancel() {
    _userCancelled = true;
    _closed = true;
    _resume();
    if (!(_consumed?.isCompleted ?? true)) _consumed!.complete();
    if (!(_delivered?.isCompleted ?? true)) _delivered!.complete();
    _commands?.send([_Input.cancel.index]);
    // Wake an idle control-port wait even if the input emits no data frames.
    _output?.sendPort.send([_Output.done.index]);
    return _finished.future;
  }

  Future<void> _pump() async {
    try {
      while (!_closed) {
        await _ready();
        if (_closed || !await _chunks!.moveNext()) break;
        await _ready();
        if (_closed) return;
        final chunk = _chunks!.current;
        for (var offset = 0; !_closed && offset < chunk.length;) {
          await _ready();
          if (_closed) return;
          final end = min(offset + maxChunkBytes, chunk.length);
          final credit = _consumed = Completer<void>();
          _commands!.send([
            _Input.chunk.index,
            TransferableTypedData.fromList([
              Uint8List.fromList(chunk.sublist(offset, end)),
            ]),
          ]);
          await credit.future;
          offset = end;
        }
      }
      if (!_closed) _commands!.send([_Input.eof.index]);
    } on Object {
      if (!_closed)
        _output!.sendPort.send([
          _Output.error.index,
          'transport',
          TransportFailure.connection.index,
        ]);
    }
  }

  Future<void> _run() async {
    try {
      _output = ReceivePort();
      _exit = ReceivePort();
      _exitSubscription = _exit!.listen((_) {
        if (!_exitSignal.isCompleted) _exitSignal.complete();
      });
      _messages = StreamIterator<dynamic>(_output!);
      _chunks = StreamIterator(input);
      _isolate = await Isolate.spawn(
        _worker,
        [
          _output!.sendPort,
          maxFrameBytes,
          maxLineBytes,
          maxBatchFrames,
          maxBatchBytes,
        ],
        onError: _output!.sendPort,
        onExit: _exit!.sendPort,
      );
      unawaited(
        _exitSignal.future.then((_) {
          if (!_closed)
            _output!.sendPort.send([
              _Output.error.index,
              'transport',
              TransportFailure.connection.index,
            ]);
        }),
      );
      while (!_closed && await _messages!.moveNext()) {
        final message = _messages!.current;
        if (message is! List || message.isEmpty || message.first is! int) {
          throw const TransportException(TransportFailure.connection);
        }
        switch (_Output.values[message.first as int]) {
          case _Output.ready:
            _commands = message[1] as SendPort;
            _pumping = _pump();
          case _Output.batch:
            await _ready();
            if (_closed) return;
            _delivered = Completer<void>();
            _controller.add(
              List<SseFrame>.unmodifiable(message[1] as List<SseFrame>),
            );
            await _delivered!.future;
            await _ready();
            if (_closed) return;
            _commands!.send([_Input.ack.index]);
          case _Output.consumed:
            await _ready();
            if (!(_consumed?.isCompleted ?? true)) _consumed!.complete();
          case _Output.done:
            return;
          case _Output.error:
            if (message[1] == 'sse') {
              throw SseException(SseFailure.values[message[2] as int]);
            }
            throw TransportException(
              TransportFailure.values[message[2] as int],
            );
        }
      }
    } on Object catch (error) {
      if (!_closed) _controller.addError(_safe(error));
    } finally {
      _closed = true;
      _resume();
      _commands?.send([_Input.cancel.index]);
      if (!(_consumed?.isCompleted ?? true)) _consumed!.complete();
      try {
        await _chunks?.cancel();
        if (_pumping != null) await _pumping;
        if (_isolate != null) {
          try {
            await _exitSignal.future.timeout(const Duration(seconds: 1));
          } on TimeoutException {
            _isolate!.kill(priority: Isolate.immediate);
            await _exitSignal.future.timeout(const Duration(seconds: 1));
          }
        }
      } on Object {
        const error = TransportException(TransportFailure.connection);
        if (!_userCancelled) _controller.addError(error);
        if (!_finished.isCompleted) _finished.completeError(error);
      } finally {
        if (!_exitSignal.isCompleted)
          _isolate?.kill(priority: Isolate.immediate);
        await _messages?.cancel();
        await _exitSubscription?.cancel();
        _output?.close();
        _exit?.close();
        unawaited(_controller.close());
        if (!_finished.isCompleted) _finished.complete();
      }
    }
  }
}

Object _safe(Object error) =>
    error is SseException || error is TransportException
    ? error
    : const TransportException(TransportFailure.connection);

void _worker(List<Object> initialization) {
  final output = initialization[0] as SendPort;
  final parser = SseFrameParser(
    maxFrameBytes: initialization[1] as int,
    maxLineBytes: initialization[2] as int,
  );
  final maxCount = initialization[3] as int;
  final maxBytes = initialization[4] as int;
  final commands = ReceivePort();
  Completer<void>? credit;
  var closed = false;

  Future<void> publish(List<SseFrame> frames) async {
    if (closed || frames.isEmpty) return;
    credit = Completer<void>();
    output.send([_Output.batch.index, List<SseFrame>.of(frames)]);
    await credit!.future;
  }

  Future<void> process(Iterable<SseFrame> frames, {required bool eof}) async {
    try {
      var batch = <SseFrame>[];
      var bytes = 0;
      for (final frame in frames) {
        if (closed) return;
        final length = sseFrameBytes(frame);
        if (length > maxBytes) {
          throw const TransportException(TransportFailure.bodyTooLarge);
        }
        if (batch.length == maxCount || length > maxBytes - bytes) {
          await publish(batch);
          if (closed) return;
          batch = [];
          bytes = 0;
        }
        batch.add(frame);
        bytes += length;
      }
      await publish(batch);
      if (closed) return;
      output.send([eof ? _Output.done.index : _Output.consumed.index]);
    } on Object catch (error) {
      if (closed) return;
      output.send([
        _Output.error.index,
        error is SseException ? 'sse' : 'transport',
        error is SseException
            ? error.failure.index
            : (error is TransportException
                  ? error.failure.index
                  : TransportFailure.connection.index),
      ]);
    }
  }

  commands.listen((dynamic message) {
    switch (_Input.values[(message as List).first as int]) {
      case _Input.chunk:
        final bytes = (message[1] as TransferableTypedData)
            .materialize()
            .asUint8List();
        unawaited(process(parser.add(bytes), eof: false));
      case _Input.eof:
        unawaited(
          process(() sync* {
            final finalFrame = parser.finish();
            if (finalFrame != null) yield finalFrame;
          }(), eof: true),
        );
      case _Input.ack:
        if (!(credit?.isCompleted ?? true)) credit!.complete();
      case _Input.cancel:
        closed = true;
        if (!(credit?.isCompleted ?? true)) credit!.complete();
        commands.close();
    }
  });
  output.send([_Output.ready.index, commands.sendPort]);
}
