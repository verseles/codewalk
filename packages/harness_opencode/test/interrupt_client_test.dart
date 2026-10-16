import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:codewalk_net/codewalk_net.dart';
import 'package:harness_opencode/harness_opencode.dart';
import 'package:test/test.dart';
import 'support/fixture_replay.dart';

const harness = HarnessRef(HostId('host'), HarnessInstanceId('instance'));
const session = SessionRef(
  HostId('host'),
  HarnessInstanceId('instance'),
  'ses_one',
);
const id = CommandId('cmd_stop');

final class _Transport implements EndpointHttpTransport {
  _Transport(this.handle);
  final FutureOr<TransportResponse> Function(
    TransportRequest,
    RequestCancellation?,
  )
  handle;
  final requests = <TransportRequest>[];
  @override
  Uri endpoint = Uri.parse('http://127.0.0.1/proxy/');
  @override
  bool isClosed = false;
  @override
  Future<TransportResponse> send(
    TransportRequest request, {
    RequestCancellation? cancellation,
  }) async {
    requests.add(request);
    expect(requests, hasLength(1), reason: 'interrupt never replays');
    return handle(request, cancellation);
  }

  @override
  void close() => isClosed = true;
}

TransportResponse response(Object? body, {int status = 200}) =>
    TransportResponse(
      statusCode: status,
      headers: const {
        'content-type': ['application/json'],
      },
      body: Stream.value(utf8.encode(jsonEncode(body))),
      cancel: () {},
    );

OpenCodeInterruptClient client(
  EndpointHttpTransport t, {
  String version = '2.0.22',
  Duration deadline = const Duration(seconds: 20),
}) => OpenCodeInterruptClient(
  t,
  harness: harness,
  connectedVersion: version,
  deadline: deadline,
);

void main() {
  test(
    'recorded idle parent and active child: exact bare POST and result',
    () async {
      final file = File(
        '${OpenCodeFixtures().root.path}/d/background-interrupt.json',
      );
      final calls =
          (jsonDecode(file.readAsStringSync()) as Map)['calls'] as List;
      final interrupts = calls
          .cast<Map>()
          .where(
            (c) =>
                c['method'] == 'POST' &&
                (c['path'] as String).endsWith('/interrupt'),
          )
          .toList();
      expect(interrupts, hasLength(2));
      for (final call in interrupts) {
        final t = _Transport((_, _) => response(call['response']));
        final ref = SessionRef(
          harness.host,
          harness.harness,
          Uri.parse(call['path'] as String).pathSegments[2],
        );
        final result = await client(t).interrupt(session: ref, id: id);
        expect(result.receipt.state.known, ReceiptState.accepted);
        expect(result.interrupted, (call['response'] as Map)['interrupted']);
        expect(result.command.operation.known, MutationOperation.interrupt);
        expect(result.command.owner.hasSameScope(SessionOwner(ref)), isTrue);
        final sent = t.requests.single;
        expect('/${sent.path}', call['path']);
        expect(sent.method, 'POST');
        expect(Uri.parse(sent.path).hasQuery, isFalse);
        expect(sent.body, isNull);
        expect(sent.headers, {'Accept': 'application/json'});
      }
    },
  );

  for (final body in [
    null,
    {},
    {
      'data': {'interrupted': true},
    },
    {'interrupted': 'true'},
  ]) {
    test('non-contract success is uncertain: $body', () async {
      final t = _Transport((_, _) => response(body));
      final result = await client(t).interrupt(session: session, id: id);
      expect(result.receipt.state.known, ReceiptState.uncertain);
      expect(result.interrupted, isNull);
    });
  }

  for (final status in [400, 401, 403, 404, 429, 409, 500, 503]) {
    test('status $status never reads a native error body', () async {
      var read = false;
      final t = _Transport(
        (_, _) => TransportResponse(
          statusCode: status,
          headers: const {},
          body: Stream.multi((_) {
            read = true;
          }),
          cancel: () {},
        ),
      );
      final result = await client(t).interrupt(session: session, id: id);
      expect(read, isFalse);
      expect(
        result.receipt.state.known,
        [400, 401, 403, 404, 429].contains(status)
            ? ReceiptState.rejected
            : ReceiptState.uncertain,
      );
      expect(result.receipt.error?.rawMessage ?? '', isEmpty);
    });
  }

  test(
    'deadline bounds headers ignored cancellation and disposes late response',
    () async {
      final pending = Completer<TransportResponse>();
      var cancelled = false;
      final t = _Transport((_, _) => pending.future);
      final result = await client(
        t,
        deadline: const Duration(milliseconds: 20),
      ).interrupt(session: session, id: id);
      expect(result.receipt.state.known, ReceiptState.uncertain);
      expect(result.receipt.reason, 'timeout');
      pending.complete(
        TransportResponse(
          statusCode: 200,
          headers: const {},
          body: const Stream.empty(),
          cancel: () => cancelled = true,
        ),
      );
      await pumpEventQueue();
      expect(cancelled, isTrue);
    },
  );

  test(
    'deadline reason remains timeout when transport cancellation wins',
    () async {
      final pending = Completer<TransportResponse>();
      final t = _Transport((_, cancellation) {
        cancellation!.onCancel.listen((_) {
          if (!pending.isCompleted) {
            pending.completeError(
              const TransportException(TransportFailure.cancelled),
            );
          }
        });
        return pending.future;
      });
      final result = await client(
        t,
        deadline: const Duration(milliseconds: 20),
      ).interrupt(session: session, id: id);
      expect(result.receipt.state.known, ReceiptState.uncertain);
      expect(result.receipt.reason, 'timeout');
    },
  );

  test('deadline also bounds an unending success body', () async {
    var cancelled = false;
    final t = _Transport(
      (_, _) => TransportResponse(
        statusCode: 200,
        headers: const {},
        body: Stream.multi((_) {}),
        cancel: () => cancelled = true,
      ),
    );
    final result = await client(
      t,
      deadline: const Duration(milliseconds: 20),
    ).interrupt(session: session, id: id);
    expect(result.receipt.state.known, ReceiptState.uncertain);
    expect(cancelled, isTrue);
  });

  test(
    'oversized and invalid JSON success cannot claim interruption',
    () async {
      for (final bytes in [utf8.encode('x'), utf8.encode('x' * 5000)]) {
        final t = _Transport(
          (_, _) => TransportResponse(
            statusCode: 200,
            headers: const {},
            body: Stream.value(bytes),
            cancel: () {},
          ),
        );
        expect(
          (await client(
            t,
          ).interrupt(session: session, id: id)).receipt.state.known,
          ReceiptState.uncertain,
        );
      }
    },
  );

  test('preflight failures do not reach the wire', () async {
    for (final reason in ['version', 'closed', 'cancelled', 'session']) {
      final t = _Transport((_, _) => throw StateError('must not send'));
      final token = RequestCancellation();
      if (reason == 'closed') t.close();
      if (reason == 'cancelled') token.cancel();
      final result =
          await client(
            t,
            version: reason == 'version' ? '2.0.21' : '2.0.22',
          ).interrupt(
            session: reason == 'session'
                ? const SessionRef(
                    HostId('host'),
                    HarnessInstanceId('instance'),
                    'invalid',
                  )
                : session,
            id: id,
            cancellation: token,
          );
      expect(result.receipt.state.known, ReceiptState.unavailable);
      expect(t.requests, isEmpty);
    }
  });

  test('wrong harness is rejected before network', () async {
    final t = _Transport((_, _) => throw StateError('must not send'));
    await expectLater(
      client(t).interrupt(
        session: const SessionRef(
          HostId('other'),
          HarnessInstanceId('instance'),
          'ses_one',
        ),
        id: id,
      ),
      throwsArgumentError,
    );
    expect(t.requests, isEmpty);
  });

  test('cancelling after send stays uncertain and ends the wait', () async {
    final t = _Transport((_, _) => Completer<TransportResponse>().future);
    final token = RequestCancellation();
    final pending = client(
      t,
    ).interrupt(session: session, id: id, cancellation: token);
    await pumpEventQueue();
    token.cancel();
    final result = await pending;
    expect(result.receipt.state.known, ReceiptState.uncertain);
    expect(result.receipt.reason, 'cancelled');
  });
}
