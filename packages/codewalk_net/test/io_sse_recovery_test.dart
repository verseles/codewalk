import 'dart:async';
import 'dart:convert';

import 'package:codewalk_net/codewalk_net_io.dart';
import 'package:test/test.dart';

final class ControlledTransport implements EndpointHttpTransport {
  @override
  final endpoint = Uri.parse('http://127.0.0.1/');
  @override
  bool isClosed = false;
  final requests = <TransportRequest>[];
  final bodies = <StreamController<List<int>>>[];
  int status = 200;
  int cancelled = 0;

  @override
  Future<TransportResponse> send(
    TransportRequest request, {
    RequestCancellation? cancellation,
  }) async {
    requests.add(request);
    final body = StreamController<List<int>>(
      onCancel: () {
        cancelled++;
      },
    );
    bodies.add(body);
    cancellation?.onCancel.listen((_) {
      unawaited(body.close());
    });
    return TransportResponse(
      statusCode: status,
      headers: {
        'content-type': ['text/event-stream'],
      },
      body: body.stream,
      cancel: () {
        unawaited(body.close());
      },
    );
  }

  @override
  void close() {
    isClosed = true;
    for (final body in bodies) {
      unawaited(body.close());
    }
  }
}

Future<void> waitFor(bool Function() condition) async {
  final end = DateTime.now().add(const Duration(seconds: 3));
  while (!condition()) {
    if (DateTime.now().isAfter(end)) {
      throw StateError('Condition did not settle.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

IoSseRecovery connection(
  ControlledTransport transport, {
  SseRecoveryPolicy policy = const SseRecoveryPolicy(),
  bool Function(SseFrame)? connectedWhen,
}) {
  final result = IoSseRecovery(
    transport,
    'events',
    policy: policy,
    connectedWhen: connectedWhen,
    random: () => .5,
  );
  addTearDown(result.close);
  addTearDown(transport.close);
  return result;
}

void main() {
  test('pre-readiness frames are not applied after hydration', () async {
    final transport = ControlledTransport();
    final recovery = connection(
      transport,
      connectedWhen: (f) => f.data == 'ready',
    );
    final updates = <SseRecoveryUpdate>[];
    final sub = recovery.updates.listen(updates.add);
    addTearDown(sub.cancel);
    await waitFor(() => transport.bodies.isNotEmpty);
    transport.bodies.single.add(
      utf8.encode('data: before\n\ndata: ready\n\ndata: after\n\n'),
    );
    await waitFor(() => updates.whereType<SseConnected>().isNotEmpty);
    recovery.releaseGeneration(recovery.generation);
    await waitFor(() => updates.whereType<SseBatch>().isNotEmpty);
    expect(
      updates.whereType<SseBatch>().expand((b) => b.frames).map((f) => f.data),
      ['after'],
    );
  });

  test(
    'readiness control payload is checked against retained byte budget',
    () async {
      final transport = ControlledTransport();
      final recovery = connection(
        transport,
        connectedWhen: (_) => true,
        policy: const SseRecoveryPolicy(maxBufferedBytes: 2),
      );
      final updates = <SseRecoveryUpdate>[];
      final sub = recovery.updates.listen(updates.add);
      addTearDown(sub.cancel);
      await waitFor(() => transport.bodies.isNotEmpty);
      transport.bodies.single.add(utf8.encode('data: readiness\n\n'));
      await waitFor(() => updates.whereType<SseDisconnected>().isNotEmpty);
      expect(updates.whereType<SseConnected>(), isEmpty);
      expect(
        updates.whereType<SseDisconnected>().first.failure.failure,
        TransportFailure.bufferOverflow,
      );
    },
  );

  test(
    'paused delivery applies upstream pressure without watchdog reconnects',
    () async {
      final transport = ControlledTransport();
      final recovery = connection(
        transport,
        policy: const SseRecoveryPolicy(
          watchdog: Duration(milliseconds: 150),
          batchInterval: Duration(milliseconds: 10),
          initialBackoff: Duration(milliseconds: 20),
        ),
      );
      final updates = <SseRecoveryUpdate>[];
      final sub = recovery.updates.listen(updates.add);
      addTearDown(sub.cancel);
      await waitFor(() => updates.whereType<SseConnected>().isNotEmpty);
      final generation = recovery.generation;
      recovery.releaseGeneration(generation);
      sub.pause();
      transport.bodies.single.add(utf8.encode('data: retained\n\n'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(transport.requests.length, 1);
      expect(recovery.generation, generation);
      sub.resume();
      await waitFor(() => updates.whereType<SseBatch>().isNotEmpty);
      expect(
        updates.whereType<SseBatch>().single.frames.single.data,
        'retained',
      );
    },
  );

  for (final status in [201, 206]) {
    test('unexpected $status is terminal until explicit wake', () async {
      final transport = ControlledTransport()..status = status;
      final recovery = connection(
        transport,
        policy: const SseRecoveryPolicy(
          initialBackoff: Duration(milliseconds: 20),
        ),
      );
      final updates = <SseRecoveryUpdate>[];
      final sub = recovery.updates.listen(updates.add);
      addTearDown(sub.cancel);
      await waitFor(() => updates.whereType<SseDisconnected>().isNotEmpty);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(transport.requests.length, 1);
      expect(updates.whereType<SseDisconnected>().single.terminal, isTrue);
    });
  }
  test('configured delay and jitter stay inside one-to-thirty second caps', () {
    const policy = SseRecoveryPolicy();
    expect(policy.watchdog, const Duration(seconds: 45));
    for (var attempt = 0; attempt < 100; attempt++) {
      for (final random in [-1.0, 0.0, .5, 1.0, 2.0]) {
        final delay = policy.delay(attempt, random);
        expect(delay >= const Duration(seconds: 1), isTrue);
        expect(delay <= const Duration(seconds: 30), isTrue);
      }
    }
    expect(policy.delay(1, .5), const Duration(seconds: 2));
  });

  test(
    'protocol readiness and release barrier precede ordered batches',
    () async {
      final transport = ControlledTransport();
      final recovery = connection(
        transport,
        connectedWhen: (frame) => frame.data == 'ready',
      );
      final updates = <SseRecoveryUpdate>[];
      final sub = recovery.updates.listen(updates.add);
      addTearDown(sub.cancel);
      await waitFor(() => transport.bodies.isNotEmpty);
      transport.bodies.single.add(
        utf8.encode('data: ready\n\ndata: first\n\ndata: second\n\n'),
      );
      await waitFor(() => updates.whereType<SseConnected>().isNotEmpty);
      expect(updates.whereType<SseBatch>(), isEmpty);
      expect(
        updates.whereType<SseConnected>().single.firstFrame!.data,
        'ready',
      );
      recovery.releaseGeneration(recovery.generation);
      await waitFor(() => updates.whereType<SseBatch>().isNotEmpty);
      expect(
        updates
            .whereType<SseBatch>()
            .expand((b) => b.frames)
            .map((f) => f.data),
        ['first', 'second'],
      );
      await recovery.close();
      expect(transport.isClosed, isFalse);
    },
  );

  test(
    'gap invalidates stale hydration and wake reconnects without replay',
    () async {
      final transport = ControlledTransport();
      final recovery = connection(transport);
      final updates = <SseRecoveryUpdate>[];
      final sub = recovery.updates.listen(updates.add);
      addTearDown(sub.cancel);
      await waitFor(() => updates.whereType<SseConnected>().isNotEmpty);
      final old = recovery.generation;
      transport.bodies.single.add(utf8.encode('data: old\n\n'));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      recovery.wake();
      await waitFor(() => updates.whereType<SseConnected>().length == 2);
      recovery.releaseGeneration(old);
      transport.bodies.last.add(utf8.encode('data: new\n\n'));
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(updates.whereType<SseBatch>(), isEmpty);
      recovery.releaseGeneration(recovery.generation);
      await waitFor(() => updates.whereType<SseBatch>().isNotEmpty);
      expect(
        updates
            .whereType<SseBatch>()
            .expand((b) => b.frames)
            .map((f) => f.data),
        ['new'],
      );
      expect(
        transport.requests.every(
          (r) => r.method == 'GET' && !r.headers.containsKey('Last-Event-ID'),
        ),
        isTrue,
      );
      expect(transport.cancelled, greaterThanOrEqualTo(1));
    },
  );

  test(
    'byte and frame overflow disconnect rather than release partial hydration',
    () async {
      for (final policy in [
        const SseRecoveryPolicy(maxBufferedFrames: 1),
        const SseRecoveryPolicy(maxBufferedBytes: 2),
      ]) {
        final transport = ControlledTransport();
        final recovery = connection(transport, policy: policy);
        final updates = <SseRecoveryUpdate>[];
        final sub = recovery.updates.listen(updates.add);
        addTearDown(sub.cancel);
        await waitFor(() => updates.whereType<SseConnected>().isNotEmpty);
        transport.bodies.single.add(utf8.encode('data: abc\n\ndata: def\n\n'));
        await waitFor(() => updates.whereType<SseDisconnected>().isNotEmpty);
        expect(
          updates.whereType<SseDisconnected>().first.failure.failure,
          TransportFailure.bufferOverflow,
        );
        expect(updates.whereType<SseBatch>(), isEmpty);
        await recovery.close();
      }
    },
  );

  test('auth failures stop automatic retry but can explicitly wake', () async {
    final transport = ControlledTransport()..status = 401;
    final recovery = connection(
      transport,
      policy: const SseRecoveryPolicy(
        initialBackoff: Duration(milliseconds: 20),
      ),
    );
    final updates = <SseRecoveryUpdate>[];
    final sub = recovery.updates.listen(updates.add);
    addTearDown(sub.cancel);
    await waitFor(() => updates.whereType<SseDisconnected>().isNotEmpty);
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(transport.requests.length, 1);
    expect(updates.whereType<SseDisconnected>().single.terminal, isTrue);
    transport.status = 200;
    recovery.wake();
    await waitFor(() => updates.whereType<SseConnected>().isNotEmpty);
    expect(transport.requests.length, 2);
  });

  test(
    'raw comment heartbeats keep watchdog alive then silence reconnects',
    () async {
      final transport = ControlledTransport();
      final recovery = connection(
        transport,
        policy: const SseRecoveryPolicy(
          watchdog: Duration(milliseconds: 300),
          initialBackoff: Duration(milliseconds: 20),
        ),
      );
      final updates = <SseRecoveryUpdate>[];
      final sub = recovery.updates.listen(updates.add);
      addTearDown(sub.cancel);
      await waitFor(() => transport.bodies.isNotEmpty);
      for (var i = 0; i < 8; i++) {
        transport.bodies.first.add(utf8.encode(': heartbeat\n\n'));
        await Future<void>.delayed(const Duration(milliseconds: 60));
      }
      expect(transport.requests.length, 1);
      await waitFor(() => transport.requests.length == 2);
      expect(
        updates.whereType<SseDisconnected>().first.failure.failure,
        TransportFailure.timeout,
      );
      expect(updates.whereType<SseBatch>(), isEmpty);
    },
  );
}
