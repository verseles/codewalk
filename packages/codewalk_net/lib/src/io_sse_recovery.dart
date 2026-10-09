import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'http_transport.dart';
import 'io_isolate_sse.dart';
import 'sse_decoder.dart';
import 'sse_recovery.dart';

/// Owns only its GET response/worker, not the borrowed endpoint HTTP client.
/// Every generation waits for consumer hydration before releasing data frames.
final class IoSseRecovery implements RecoveringSseConnection {
  IoSseRecovery(
    this.transport,
    this.path, {
    Map<String, String> headers = const {},
    this.policy = const SseRecoveryPolicy(),
    this.connectedWhen,
    double Function()? random,
  }) : headers = Map.unmodifiable(headers),
       _random = random ?? Random().nextDouble {
    policy.validate();
    _controller = StreamController<SseRecoveryUpdate>(
      onListen: () => unawaited(_connect()),
      onPause: () {
        _paused = true;
        _parser?.pause();
        _watchdog?.cancel();
        _readyTimer?.cancel();
        _retry?.cancel();
        _retry = null;
        _batchTimer?.cancel();
        _batchTimer = null;
      },
      onResume: () {
        _paused = false;
        _parser?.resume();
        if (_response != null) {
          _feedWatchdog(_generation);
          if (!_ready && connectedWhen != null) _armReadyDeadline(_generation);
        } else if (!_terminal) {
          unawaited(_connect());
        }
        _scheduleBatch();
      },
      onCancel: close,
    );
    _updates = _controller.stream.where((update) {
      _queuedUpdates--;
      if (update is SseBatch) {
        _pendingBytes -= update.byteLength;
        _pendingFrames -= update.frames.length;
        return update.generation == _generation;
      }
      if (update is SseConnected) {
        if (update.firstFrame != null) {
          _pendingBytes -= sseFrameBytes(update.firstFrame!);
          _pendingFrames--;
        }
        return update.generation == _generation;
      }
      return true;
    });
  }

  final EndpointHttpTransport transport;
  final String path;
  final Map<String, String> headers;
  final SseRecoveryPolicy policy;

  /// Optional protocol readiness predicate, supplied by the harness adapter.
  /// Its matching control frame is exposed in SseConnected, not interpreted here.
  final bool Function(SseFrame)? connectedWhen;
  final double Function() _random;
  late final StreamController<SseRecoveryUpdate> _controller;
  late final Stream<SseRecoveryUpdate> _updates;
  final _buffer = Queue<SseFrame>();
  RequestCancellation? _cancellation;
  TransportResponse? _response;
  StreamSubscription<List<SseFrame>>? _parser;
  Timer? _watchdog;
  Timer? _retry;
  Timer? _batchTimer;
  Timer? _stableTimer;
  Timer? _readyTimer;
  Future<void> _cleanup = Future.value();
  Future<void>? _closing;
  int _generation = 0;
  int _attempt = 0;
  int _bufferBytes = 0;
  int _pendingBytes = 0;
  int _pendingFrames = 0;
  int _queuedUpdates = 0;
  bool _released = false;
  bool _ready = false;
  bool _paused = false;
  bool _closed = false;
  bool _terminal = false;

  @override
  Stream<SseRecoveryUpdate> get updates => _updates;
  @override
  int get generation => _generation;

  Future<void> _connect() async {
    if (_closed || _terminal || _cancellation != null) return;
    await _cleanup;
    if (_closed || _terminal || _cancellation != null) return;
    final token = _cancellation = RequestCancellation();
    final generation = ++_generation;
    _released = false;
    _ready = false;
    try {
      final response = await transport.send(
        TransportRequest(
          method: 'GET',
          path: path,
          headers: {...headers, 'Accept': 'text/event-stream'},
        ),
        cancellation: token,
      );
      if (_closed || generation != _generation) {
        response.cancel();
        return;
      }
      _response = response;
      if (response.statusCode != 200) {
        throw TransportException(
          TransportFailure.unexpectedStatus,
          statusCode: response.statusCode,
        );
      }
      if (response
              .header('content-type')
              ?.split(';')
              .first
              .trim()
              .toLowerCase() !=
          'text/event-stream') {
        throw const TransportException(TransportFailure.unsupportedContentType);
      }
      _feedWatchdog(generation);
      if (connectedWhen == null) {
        _ready = true;
        if (!_emit(SseConnected(generation))) return;
      } else {
        _armReadyDeadline(generation);
      }
      final raw = response.body.map((bytes) {
        if (bytes.isNotEmpty && generation == _generation) {
          _feedWatchdog(generation);
          _stableTimer ??= Timer(policy.initialBackoff, () {
            if (generation == _generation) _attempt = 0;
          });
        }
        return bytes;
      });
      _parser =
          parseSseInIsolate(
            raw,
            maxFrameBytes: policy.maxFrameBytes,
            maxLineBytes: policy.maxLineBytes,
            maxBatchFrames: policy.maxBatchFrames,
            maxBatchBytes: policy.maxFrameBytes,
          ).listen(
            (frames) {
              if (_closed || generation != _generation) return;
              try {
                for (final frame in frames) {
                  if (!_ready) {
                    if (connectedWhen!(frame)) {
                      _ready = true;
                      _readyTimer?.cancel();
                      if (!_emit(SseConnected(generation, firstFrame: frame))) {
                        return;
                      }
                    }
                    // Only events subsequent to readiness are hydrated/applied.
                    continue;
                  }
                  final length = sseFrameBytes(frame);
                  if (_buffer.length + _pendingFrames >=
                          policy.maxBufferedFrames ||
                      length >
                          policy.maxBufferedBytes -
                              _bufferBytes -
                              _pendingBytes) {
                    _abandon(
                      const TransportException(TransportFailure.bufferOverflow),
                    );
                    return;
                  }
                  _buffer.add(frame);
                  _bufferBytes += length;
                }
                _scheduleBatch();
              } on Object {
                _abandon(
                  const TransportException(TransportFailure.invalidResponse),
                );
              }
            },
            onError: (Object error) {
              if (generation != _generation) return;
              _abandon(
                error is TransportException
                    ? error
                    : const TransportException(
                        TransportFailure.invalidResponse,
                      ),
              );
            },
            onDone: () {
              if (generation == _generation) {
                _abandon(const TransportException(TransportFailure.connection));
              }
            },
          );
      if (_paused) _parser?.pause();
    } on Object catch (error) {
      if (generation != _generation) return;
      _abandon(
        error is TransportException
            ? error
            : const TransportException(TransportFailure.connection),
      );
    }
  }

  void _feedWatchdog(int generation) {
    _watchdog?.cancel();
    if (_paused || _closed) return;
    _watchdog = Timer(policy.watchdog, () {
      if (generation == _generation) {
        _abandon(const TransportException(TransportFailure.timeout));
      }
    });
  }

  void _armReadyDeadline(int generation) {
    _readyTimer?.cancel();
    if (_paused || _closed) return;
    _readyTimer = Timer(policy.watchdog, () {
      if (generation == _generation && !_ready) {
        _abandon(const TransportException(TransportFailure.timeout));
      }
    });
  }

  void _abandon(TransportException error, {bool immediate = false}) {
    if (_closed || _cancellation == null) return;
    final abandoned = _generation++;
    _released = false;
    _ready = false;
    _clearTimers();
    _stopAttempt();
    _buffer.clear();
    _bufferBytes = 0;
    final status = error.statusCode;
    _terminal =
        {
          TransportFailure.invalidTarget,
          TransportFailure.invalidRequest,
          TransportFailure.invalidResponse,
          TransportFailure.unsupportedContentType,
          TransportFailure.closed,
        }.contains(error.failure) ||
        (status != null && status >= 200 && status < 300) ||
        (status != null &&
            status >= 300 &&
            status < 500 &&
            status != 408 &&
            status != 429);
    _emit(SseDisconnected(abandoned, error, terminal: _terminal));
    if (_closed || _terminal || _paused) return;
    final delay = immediate
        ? Duration.zero
        : policy.delay(_attempt++, _random());
    _retry = Timer(delay, () {
      _retry = null;
      unawaited(_connect());
    });
  }

  void _stopAttempt() {
    _cancellation?.cancel();
    _cancellation = null;
    _response?.cancel();
    _response = null;
    final parser = _parser;
    _parser = null;
    _cleanup = _cleanup
        .then<void>(
          (_) async {
            await parser?.cancel();
          },
          onError: (Object _, StackTrace _) async {
            await parser?.cancel();
          },
        )
        .catchError((Object _) {
          // A failed cancellation must be visible, without poisoning later cleanup.
          _emit(
            SseDisconnected(
              _generation,
              const TransportException(TransportFailure.connection),
              terminal: false,
            ),
          );
        });
  }

  @override
  void releaseGeneration(int generation) {
    if (_closed || generation != _generation || !_ready) return;
    _released = true;
    _scheduleBatch();
  }

  void _scheduleBatch() {
    if (_closed ||
        _paused ||
        !_released ||
        _buffer.isEmpty ||
        _batchTimer != null) {
      return;
    }
    _batchTimer = Timer(policy.batchInterval, () {
      _batchTimer = null;
      if (_closed || _paused || !_released) return;
      final frames = <SseFrame>[];
      while (_buffer.isNotEmpty && frames.length < policy.maxBatchFrames) {
        final frame = _buffer.removeFirst();
        _bufferBytes -= sseFrameBytes(frame);
        frames.add(frame);
      }
      _emit(SseBatch(_generation, frames));
      _scheduleBatch();
    });
  }

  bool _emit(SseRecoveryUpdate update) {
    if (_closed) return false;
    if (_queuedUpdates >= policy.maxQueuedUpdates) {
      _controller.addError(
        const TransportException(TransportFailure.bufferOverflow),
      );
      unawaited(close());
      return false;
    }
    final bytes = update is SseBatch
        ? update.byteLength
        : (update is SseConnected && update.firstFrame != null
              ? sseFrameBytes(update.firstFrame!)
              : 0);
    final frames = update is SseBatch
        ? update.frames.length
        : (update is SseConnected && update.firstFrame != null ? 1 : 0);
    if (bytes > policy.maxBufferedBytes - _bufferBytes - _pendingBytes ||
        frames > policy.maxBufferedFrames - _buffer.length - _pendingFrames) {
      _abandon(const TransportException(TransportFailure.bufferOverflow));
      return false;
    }
    _queuedUpdates++;
    _pendingBytes += bytes;
    _pendingFrames += frames;
    _controller.add(update);
    return true;
  }

  @override
  void wake() {
    if (_closed) return;
    _terminal = false;
    if (_cancellation != null) {
      _abandon(
        const TransportException(TransportFailure.connection),
        immediate: true,
      );
    } else {
      _retry?.cancel();
      _retry = null;
      unawaited(_connect());
    }
  }

  void _clearTimers() {
    for (final timer in [
      _watchdog,
      _retry,
      _batchTimer,
      _stableTimer,
      _readyTimer,
    ]) {
      timer?.cancel();
    }
    _watchdog = _retry = _batchTimer = _stableTimer = _readyTimer = null;
  }

  @override
  Future<void> close() {
    if (_closing != null) return _closing!;
    _closed = true;
    _generation++;
    _clearTimers();
    _stopAttempt();
    _buffer.clear();
    _bufferBytes = 0;
    unawaited(_controller.close());
    return _closing = _cleanup;
  }
}
