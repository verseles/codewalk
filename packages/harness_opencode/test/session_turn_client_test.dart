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
  'ses_a',
);
const command = CommandId('turn-command');

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
    expect(requests, hasLength(1), reason: 'turn mutations never replay');
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

OpenCodeSessionTurnClient client(
  EndpointHttpTransport transport, {
  String version = '2.0.22',
  Duration deadline = const Duration(seconds: 20),
  int maxBodyBytes = 1024 * 1024,
}) => OpenCodeSessionTurnClient(
  transport,
  harness: harness,
  connectedVersion: version,
  deadline: deadline,
  maxBodyBytes: maxBodyBytes,
);

RevertRequest target(SessionRef ref, String message, {bool files = true}) =>
    RevertRequest(
      boundary: ItemId(jsonEncode([ref.storageKey, message, 'user', 0])),
      includeFiles: files,
    );

Map<String, Object?> compactBody() => {
  'data': {
    'id': 'msg_compact',
    'sessionID': 'ses_a',
    'time': {'created': 1000},
    'type': 'compaction',
    'payload': <String, Object?>{},
    'delivery': 'steer',
  },
};

void main() {
  test(
    'native captures prove exact routes, bodies and finite receipts',
    () async {
      final capture =
          jsonDecode(
                File(
                  '${OpenCodeFixtures().root.path}/turn-actions-071g/capture-r2.json',
                ).readAsStringSync(),
              )
              as Map;
      var checked = 0;
      for (final raw in capture['calls'] as List) {
        final call = raw as Map;
        final path = call['path'] as String;
        if (!path.contains('/revert') && !path.endsWith('/compact')) continue;
        checked++;
        final t = _Transport(
          (_, _) => response(call['response'], status: call['status'] as int),
        );
        final c = client(t);
        final ref = SessionRef(
          harness.host,
          harness.harness,
          Uri.parse(path).pathSegments[2],
        );
        final request = call['request'] as Map?;
        late OpenCodeTurnAttempt attempt;
        late MutationOperation operation;
        Map<String, Object?>? expected;
        if (path.endsWith('/stage')) {
          operation = MutationOperation.revertStage;
          expected = {'messageID': request!['messageID'], 'files': true};
          attempt = await c.stage(
            session: ref,
            request: target(ref, request['messageID'] as String),
            id: command,
          );
          if (call['status'] == 200) {
            expect(attempt.revert!.kind.known, RevertKind.staged);
            expect(attempt.revert!.anchor!.message.value, request['messageID']);
            expect(
              attempt.revert!.boundary,
              isNull,
              reason: 'native target survives a nonresident window',
            );
          }
        } else if (path.endsWith('/compact')) {
          operation = MutationOperation.compact;
          final nativeId =
              ((call['response'] as Map)['data'] as Map)['id'] as String;
          expected = {'id': nativeId, 'delivery': 'steer'};
          attempt = await c.compact(
            session: ref,
            input: MessageRef(nativeId),
            id: command,
          );
          expect(attempt.receipt.nativeRef, nativeId);
          expect(attempt.revert, isNull);
        } else if (path.endsWith('/commit')) {
          operation = MutationOperation.revertCommit;
          attempt = await c.commit(session: ref, id: command);
        } else {
          operation = MutationOperation.revertClear;
          attempt = await c.clear(session: ref, id: command);
        }
        expect(
          attempt.receipt.state.known,
          call['status'] == 409 ? ReceiptState.rejected : ReceiptState.accepted,
        );
        expect(attempt.command.operation.known, operation);
        expect(attempt.command.owner.hasSameScope(SessionOwner(ref)), isTrue);
        final sent = t.requests.single;
        expect('/${sent.path}', path);
        expect(sent.method, call['method']);
        expect(Uri.parse(sent.path).hasQuery, isFalse);
        expect(sent.headers['Accept'], 'application/json');
        expect(
          sent.body == null ? null : jsonDecode(utf8.decode(sent.body!)),
          expected,
        );
        expect(
          attempt.payload,
          sent.body == null ? null : utf8.decode(sent.body!),
        );
      }
      expect(checked, 10);
    },
  );

  test(
    'staged response drops file patches and keeps bounded typed identity',
    () async {
      final t = _Transport(
        (_, _) => response({
          'data': {
            'messageID': 'msg_old',
            'snapshot': 'snapshot',
            'files': [
              {
                'file': 'a.txt',
                'status': 'modified',
                'additions': 1,
                'deletions': 1,
                'patch': 'private-workspace-content',
              },
            ],
          },
        }),
      );
      final attempt = await client(t).stage(
        session: session,
        request: target(session, 'msg_old'),
        id: command,
      );
      expect(attempt.receipt.state.known, ReceiptState.accepted);
      expect(attempt.revert!.anchor!.message, MessageRef('msg_old'));
      expect(
        jsonEncode(attempt.revert!.details!.value),
        isNot(contains('private-workspace')),
      );
      expect(
        (attempt.revert!.details!.value as Map)['patchNotProjected'],
        isTrue,
      );
    },
  );

  for (final body in [
    null,
    {},
    {'data': {}},
    {
      'data': {'messageID': 'msg_other'},
    },
    {
      'data': {
        'messageID': 'msg_old',
        'files': [
          {'patch': 1},
        ],
      },
    },
  ]) {
    test('invalid or mismatched stage result stays uncertain: $body', () async {
      final t = _Transport((_, _) => response(body));
      final result = await client(t).stage(
        session: session,
        request: target(session, 'msg_old', files: false),
        id: command,
      );
      expect(result.receipt.state.known, ReceiptState.uncertain);
      expect(result.revert, isNull);
      expect(t.requests, hasLength(1));
    });
  }

  for (final entry in <String, Object?>{
    'id': 'msg_other',
    'sessionID': 'ses_child',
    'type': 'user',
    'delivery': 'queue',
    'payload': [],
    'time': {'created': -1},
  }.entries) {
    test('compact admission validates ${entry.key}', () async {
      final body = compactBody();
      (body['data'] as Map)[entry.key] = entry.value;
      final t = _Transport((_, _) => response(body));
      final result = await client(t).compact(
        session: session,
        input: MessageRef('msg_compact'),
        id: command,
      );
      expect(result.receipt.state.known, ReceiptState.uncertain);
      expect(result.receipt.nativeRef, isNull);
    });
  }

  for (final status in [204, 400, 401, 403, 404, 409, 429, 500]) {
    test('clear status $status never reads a native error body', () async {
      var read = false;
      final t = _Transport(
        (_, _) => TransportResponse(
          statusCode: status,
          headers: const {},
          body: Stream.multi((sink) {
            read = true;
            sink.add(utf8.encode('secret'));
            sink.close();
          }),
          cancel: () {},
        ),
      );
      final result = await client(t).clear(session: session, id: command);
      expect(
        result.receipt.state.known,
        status == 204
            ? ReceiptState.accepted
            : status == 500
            ? ReceiptState.uncertain
            : ReceiptState.rejected,
      );
      expect(read, isFalse);
      expect(result.receipt.error?.rawMessage ?? '', isEmpty);
      if (status == 409) {
        expect(result.receipt.error!.rawType, 'SessionBusyError');
      }
    });
  }

  test(
    'compact 409 is Conflict, not proof of a busy-session refusal',
    () async {
      final t = _Transport((_, _) => response(null, status: 409));
      final result = await client(t).compact(
        session: session,
        input: MessageRef('msg_compact'),
        id: command,
      );
      expect(result.receipt.state.known, ReceiptState.rejected);
      expect(result.receipt.error!.rawType, 'ConflictError');
    },
  );

  test('deadline cancels a late response without replay', () async {
    final gate = Completer<TransportResponse>();
    final t = _Transport((_, _) => gate.future);
    final result = await client(
      t,
      deadline: const Duration(milliseconds: 20),
    ).commit(session: session, id: command);
    expect(result.receipt.state.known, ReceiptState.uncertain);
    expect(result.receipt.reason, 'timeout');
    var cancelled = false;
    gate.complete(
      TransportResponse(
        statusCode: 204,
        headers: const {},
        body: const Stream.empty(),
        cancel: () => cancelled = true,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(cancelled, isTrue);
    expect(t.requests, hasLength(1));
  });

  test('response body and body limit stay bounded and uncertain', () async {
    for (final stalled in [true, false]) {
      final stream = stalled ? StreamController<List<int>>() : null;
      final t = _Transport(
        (_, _) => stalled
            ? TransportResponse(
                statusCode: 200,
                headers: const {},
                body: stream!.stream,
                cancel: () {},
              )
            : response(compactBody()),
      );
      final result =
          await client(
            t,
            deadline: const Duration(milliseconds: 20),
            maxBodyBytes: 8,
          ).compact(
            session: session,
            input: MessageRef('msg_compact'),
            id: command,
          );
      expect(result.receipt.state.known, ReceiptState.uncertain);
      await stream?.close();
    }
  });

  test(
    'unverified version, invalid identity and closed/cancelled calls do not send',
    () async {
      for (final why in [
        'version',
        'message',
        'session',
        'closed',
        'cancelled',
      ]) {
        final t = _Transport((_, _) => throw StateError('must not send'));
        final token = RequestCancellation();
        if (why == 'closed') t.close();
        if (why == 'cancelled') token.cancel();
        final result =
            await client(
              t,
              version: why == 'version' ? '2.0.23' : '2.0.22',
            ).stage(
              session: why == 'session'
                  ? SessionRef(harness.host, harness.harness, 'other')
                  : session,
              request: target(
                session,
                why == 'message' ? 'local_echo' : 'msg_old',
              ),
              id: command,
              cancellation: token,
            );
        expect(result.receipt.state.known, ReceiptState.unavailable);
        expect(t.requests, isEmpty);
        expect(result.payload, isNull);
      }
    },
  );

  for (final failure in [
    TransportFailure.invalidTarget,
    TransportFailure.invalidRequest,
    TransportFailure.connection,
  ]) {
    test(
      'transport $failure keeps one attempt and truthful certainty',
      () async {
        final t = _Transport((_, _) => throw TransportException(failure));
        final result = await client(t).commit(session: session, id: command);
        expect(
          result.receipt.state.known,
          failure == TransportFailure.connection
              ? ReceiptState.uncertain
              : ReceiptState.unavailable,
        );
        expect(t.requests, hasLength(1));
        expect(result.payload, isNull);
      },
    );
  }

  test(
    'cancellation after send is uncertain and cancels a late response',
    () async {
      final gate = Completer<TransportResponse>();
      final t = _Transport((_, _) => gate.future);
      final token = RequestCancellation();
      final pending = client(t).stage(
        session: session,
        request: target(session, 'msg_old'),
        id: command,
        cancellation: token,
      );
      await Future<void>.delayed(Duration.zero);
      token.cancel();
      final result = await pending;
      expect(result.receipt.state.known, ReceiptState.uncertain);
      expect(result.receipt.reason, 'cancelled');
      var cancelled = false;
      gate.complete(
        TransportResponse(
          statusCode: 200,
          headers: const {},
          body: const Stream.empty(),
          cancel: () => cancelled = true,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(cancelled, isTrue);
      expect(t.requests, hasLength(1));
    },
  );

  test('a canonical boundary from another session never sends', () async {
    final t = _Transport((_, _) => throw StateError('must not send'));
    final result = await client(t).stage(
      session: const SessionRef(
        HostId('host'),
        HarnessInstanceId('instance'),
        'ses_child',
      ),
      request: target(session, 'msg_old'),
      id: command,
    );
    expect(result.receipt.state.known, ReceiptState.unavailable);
    expect(t.requests, isEmpty);
  });

  test(
    'foreign session and nonpositive bounds fail before transport',
    () async {
      final t = _Transport((_, _) => throw StateError('must not send'));
      expect(() => client(t, deadline: Duration.zero), throwsArgumentError);
      expect(() => client(t, maxBodyBytes: 0), throwsArgumentError);
      await expectLater(
        client(t).clear(
          session: const SessionRef(
            HostId('other'),
            HarnessInstanceId('instance'),
            'ses_a',
          ),
          id: command,
        ),
        throwsArgumentError,
      );
      expect(t.requests, isEmpty);
    },
  );
}
