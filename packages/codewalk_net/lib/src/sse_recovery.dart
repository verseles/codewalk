import 'dart:math';

import 'http_transport.dart';
import 'sse_decoder.dart';

final class SseRecoveryPolicy {
  const SseRecoveryPolicy({
    this.watchdog = const Duration(seconds: 45),
    this.initialBackoff = const Duration(seconds: 1),
    this.maxBackoff = const Duration(seconds: 30),
    this.batchInterval = const Duration(milliseconds: 100),
    this.maxFrameBytes = defaultTransportByteLimit,
    this.maxLineBytes = defaultTransportByteLimit,
    this.maxBufferedBytes = 32 * 1024 * 1024,
    this.maxBufferedFrames = 4096,
    this.maxBatchFrames = 64,
    this.maxQueuedUpdates = 256,
  });

  final Duration watchdog;
  final Duration initialBackoff;
  final Duration maxBackoff;
  final Duration batchInterval;
  final int maxFrameBytes;
  final int maxLineBytes;
  final int maxBufferedBytes;
  final int maxBufferedFrames;
  final int maxBatchFrames;
  final int maxQueuedUpdates;

  void validate() {
    if ([
          watchdog,
          initialBackoff,
          maxBackoff,
          batchInterval,
        ].any((d) => d <= Duration.zero) ||
        maxBackoff < initialBackoff ||
        [
          maxFrameBytes,
          maxLineBytes,
          maxBufferedBytes,
          maxBufferedFrames,
          maxBatchFrames,
          maxQueuedUpdates,
        ].any((n) => n <= 0)) {
      throw ArgumentError('Recovery limits must be positive and ordered.');
    }
  }

  /// Nominal exponential delay with bounded jitter, never outside either cap.
  Duration delay(int attempt, double random) {
    final exponent = min(max(attempt, 0), 30);
    final nominal = min(
      maxBackoff.inMicroseconds,
      initialBackoff.inMicroseconds * (1 << exponent),
    );
    final jitter = .8 + .4 * random.clamp(0.0, 1.0);
    return Duration(
      microseconds: (nominal * jitter).round().clamp(
        initialBackoff.inMicroseconds,
        maxBackoff.inMicroseconds,
      ),
    );
  }
}

sealed class SseRecoveryUpdate {
  const SseRecoveryUpdate(this.generation);
  final int generation;
}

final class SseConnected extends SseRecoveryUpdate {
  const SseConnected(super.generation, {this.firstFrame});
  final SseFrame? firstFrame;
}

final class SseBatch extends SseRecoveryUpdate {
  SseBatch(super.generation, Iterable<SseFrame> frames)
    : frames = List.unmodifiable(frames),
      byteLength = frames.fold(0, (sum, frame) => sum + sseFrameBytes(frame));
  final List<SseFrame> frames;
  final int byteLength;
}

final class SseDisconnected extends SseRecoveryUpdate {
  const SseDisconnected(
    super.generation,
    this.failure, {
    required this.terminal,
  });
  final TransportException failure;
  final bool terminal;
}

abstract interface class RecoveringSseConnection {
  Stream<SseRecoveryUpdate> get updates;
  int get generation;
  void releaseGeneration(int generation);
  void wake();
  Future<void> close();
}
