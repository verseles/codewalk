import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:codewalk_net/codewalk_net.dart';
import 'package:harness_opencode/harness_opencode.dart';
import 'package:test/test.dart';

import 'support/fixture_replay.dart';

const _harness = HarnessRef(HostId('host'), HarnessInstanceId('instance'));

/// One POST at most: a second send fails the test.
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
    expect(requests, hasLength(1), reason: 'the client never retries');
    return handle(request, cancellation);
  }

  @override
  void close() => isClosed = true;
}

TransportResponse _response(Object? body, {int status = 200}) =>
    TransportResponse(
      statusCode: status,
      headers: {
        'content-type': ['application/json'],
      },
      body: Stream.value(utf8.encode(jsonEncode(body))),
      cancel: () {},
    );

Map<String, Map<String, Object?>> _matrix() {
  final file = File(
    '${OpenCodeFixtures().root.path}/b/prompt-matrix.json',
  ).readAsStringSync();
  return {
    for (final call in ((jsonDecode(file) as Map)['calls'] as List))
      (call as Map)['name'] as String: call.cast<String, Object?>(),
  };
}

SessionRef _session(String path) => SessionRef(
  _harness.host,
  _harness.harness,
  Uri.parse(path).pathSegments[2],
);

Future<(OpenCodePromptAttempt, _Transport)> _replay(
  Map<String, Object?> call, {
  String version = '2.0.22',
}) async {
  final request = call['request']! as Map<String, Object?>;
  final transport = _Transport(
    (_, _) => _response(call['response'], status: call['status']! as int),
  );
  final client = OpenCodePromptClient(
    transport,
    harness: _harness,
    connectedVersion: version,
  );
  final attempt = await client.send(
    session: _session(call['path']! as String),
    commandId: const CommandId('cmd'),
    messageId: request['id']! as String,
    draft: PromptDraft(text: request['text']! as String),
    delivery: Delivery.values.byName(request['delivery']! as String),
    resume: request['resume']! as bool,
  );
  return (attempt, transport);
}

void main() {
  final matrix = _matrix();
  final prompts = matrix.values.where(
    (c) => c['method'] == 'POST' && (c['path']! as String).endsWith('/prompt'),
  );

  test('every recorded prompt request is encoded exactly', () async {
    expect(prompts.length, greaterThanOrEqualTo(8));
    for (final call in prompts) {
      final (attempt, transport) = await _replay(call);
      final sent = transport.requests.single;
      expect(sent.method, 'POST');
      expect('/${sent.path}', call['path']);
      expect(sent.headers, {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      });
      expect(jsonDecode(utf8.decode(sent.body!)), call['request']);
      expect(attempt.payload, utf8.decode(sent.body!));
      expect(attempt.messageId, (call['request']! as Map)['id']);
    }
  });

  test('prepare touches no network; post sends exactly its payload', () async {
    final call = matrix['promptOriginal']!;
    final request = call['request']! as Map<String, Object?>;
    final transport = _Transport(
      (_, _) => _response(call['response'], status: 200),
    );
    final client = OpenCodePromptClient(
      transport,
      harness: _harness,
      connectedVersion: '2.0.22',
    );
    final ready =
        client.prepare(
              session: _session(call['path']! as String),
              commandId: const CommandId('cmd'),
              messageId: request['id']! as String,
              draft: PromptDraft(text: request['text']! as String),
              delivery: Delivery.queue,
              resume: false,
            )
            as OpenCodePromptReady;
    expect(transport.requests, isEmpty);
    expect(jsonDecode(ready.payload), request);
    final attempt = await client.post(ready);
    expect(utf8.decode(transport.requests.single.body!), ready.payload);
    expect(attempt.payload, ready.payload);
    final other = OpenCodePromptClient(
      transport,
      harness: _harness,
      connectedVersion: '2.0.21',
    );
    await expectLater(other.post(ready), throwsArgumentError);
  });

  test('a 200 for this intent is admitted, not delivered', () async {
    final (attempt, _) = await _replay(matrix['promptOriginal']!);
    expect(attempt.receipt.state.known, ReceiptState.accepted);
    expect(attempt.receipt.nativeRef, 'msg_1a1053e7ad3000a8b22017a68214');
    expect(attempt.submission!.kind.known, SubmissionKind.admitted);
    expect(attempt.submission!.delivery!.known, Delivery.queue);
    expect(attempt.pending!.text, 'Reply exactly B_PARKED_ORIGINAL.');
    expect(attempt.pending!.delivery.known, Delivery.queue);
    // A queued prompt is pending only; it is not yet a timeline item.
    expect(attempt.items, isEmpty);
    expect(attempt.command.operation.known, MutationOperation.prompt);
  });

  test('identical text under a new id is a second admission', () async {
    final (first, _) = await _replay(matrix['promptOriginal']!);
    final (second, _) = await _replay(matrix['sameTextNewId']!);
    expect(second.receipt.state.known, ReceiptState.accepted);
    expect(second.pending!.id, isNot(first.pending!.id));
    expect(second.pending!.text, first.pending!.text);
  });

  test('a same-id replay with the same intent returns the admission', () async {
    final (attempt, _) = await _replay(matrix['promptIdenticalReplay']!);
    expect(attempt.receipt.state.known, ReceiptState.accepted);
  });

  test('changed text or delivery on an occupied id is not admitted', () async {
    for (final name in [
      'promptChangedTextReplay',
      'promptChangedDeliveryReplay',
    ]) {
      final (attempt, _) = await _replay(matrix[name]!);
      expect(attempt.receipt.state.known, ReceiptState.rejected, reason: name);
      expect(attempt.receipt.error!.rawType, 'PromptIdentityOccupied');
      expect(attempt.submission!.kind.known, SubmissionKind.rejected);
      expect(attempt.pending, isNull);
    }
  });

  test('a cross-session id conflict is a rejected 409', () async {
    final (attempt, _) = await _replay(matrix['promptCrossSessionConflict']!);
    expect(attempt.receipt.state.known, ReceiptState.rejected);
    expect(attempt.receipt.error!.rawType, 'ConflictError');
    expect(attempt.receipt.error!.action!.known, ErrorAction.refresh);
    // Native messages echo ids; they are not carried for display.
    expect(attempt.receipt.error!.rawMessage, isEmpty);
  });

  test('a steer admission is also a pending user input', () async {
    final call = matrix['promptOriginal']!;
    final steer = <String, Object?>{
      ...call,
      'request': <String, Object?>{
        ...call['request']! as Map<String, Object?>,
        'delivery': 'steer',
      },
      'response': {
        'data': {
          ...((call['response']! as Map)['data'] as Map),
          'delivery': 'steer',
        },
      },
    };
    final (attempt, _) = await _replay(steer);
    expect(attempt.receipt.state.known, ReceiptState.accepted);
    final input = attempt.items.whereType<UserInput>().single;
    expect(input.meta.id, attempt.pending!.id);
    expect(input.delivery.known, DeliveryState.accepted);
  });

  group('uncertain outcomes keep the id for reconciliation', () {
    final call = matrix['promptOriginal']!;
    Future<OpenCodePromptAttempt> attempt(
      FutureOr<TransportResponse> Function() respond, {
      Duration deadline = const Duration(seconds: 5),
    }) {
      final request = call['request']! as Map<String, Object?>;
      return OpenCodePromptClient(
        _Transport((_, _) => respond()),
        harness: _harness,
        connectedVersion: '2.0.22',
        deadline: deadline,
      ).send(
        session: _session(call['path']! as String),
        commandId: const CommandId('cmd'),
        messageId: request['id']! as String,
        draft: PromptDraft(text: request['text']! as String),
        delivery: Delivery.queue,
      );
    }

    void uncertain(OpenCodePromptAttempt a, String reason) {
      expect(a.receipt.state.known, ReceiptState.uncertain);
      expect(a.receipt.reason, reason);
      expect(a.submission!.kind.known, SubmissionKind.uncertain);
      expect(a.messageId, 'msg_1a1053e7ad3000a8b22017a68214');
      expect(a.posted, isTrue);
    }

    test('a response withheld past the deadline', () async {
      uncertain(
        await attempt(
          () => Completer<TransportResponse>().future,
          deadline: const Duration(milliseconds: 20),
        ),
        'timeout',
      );
    });
    test('a lost connection', () async {
      uncertain(
        await attempt(
          () => throw const TransportException(TransportFailure.connection),
        ),
        'connection',
      );
    });
    test('a server error or unavailable service', () async {
      for (final status in [500, 502, 503, 504, 408]) {
        uncertain(
          await attempt(() => _response({}, status: status)),
          'status$status',
        );
      }
    });
    test('a cancel while sending, or an out-of-contract error', () async {
      uncertain(
        await attempt(
          () => throw const TransportException(TransportFailure.cancelled),
        ),
        'cancelled',
      );
      uncertain(
        await attempt(() => throw StateError('custom transport')),
        'unexpectedTransportFailure',
      );
    });
    test('a close while the request may already be on the wire', () async {
      uncertain(
        await attempt(
          () => throw const TransportException(TransportFailure.closed),
        ),
        'closed',
      );
    });
    test('a 200 whose body outlives the deadline', () async {
      uncertain(
        await attempt(
          () => TransportResponse(
            statusCode: 200,
            headers: {
              'content-type': ['application/json'],
            },
            // Never ends, and ignores cancellation.
            body: StreamController<List<int>>().stream,
            cancel: () {},
          ),
          deadline: const Duration(milliseconds: 20),
        ),
        'timeout',
      );
    });
    test('a definite refusal does not wait for its body', () async {
      final a = await attempt(
        () => TransportResponse(
          statusCode: 409,
          headers: {
            'content-type': ['application/json'],
          },
          body: StreamController<List<int>>().stream,
          cancel: () {},
        ),
        deadline: const Duration(milliseconds: 20),
      );
      expect(a.receipt.state.known, ReceiptState.rejected);
      expect(a.receipt.error!.rawType, 'ConflictError');
    });
    test('a 200 that does not prove this admission', () async {
      for (final body in [
        {'data': null},
        {
          'data': {'id': 'msg_other', 'type': 'user'},
        },
        'not an object',
      ]) {
        uncertain(await attempt(() => _response(body)), 'malformedAdmission');
      }
    });
  });

  group('nothing is sent', () {
    final call = matrix['promptOriginal']!;
    Future<(OpenCodePromptAttempt, _Transport)> refuse({
      String version = '2.0.22',
      PromptDraft? draft,
      Delivery delivery = Delivery.queue,
      String messageId = 'msg_1a1053e7ad3000a8b22017a68214',
      SessionRef? session,
      RequestCancellation? cancellation,
    }) async {
      final transport = _Transport((_, _) => fail('must not send'));
      final result =
          await OpenCodePromptClient(
            transport,
            harness: _harness,
            connectedVersion: version,
          ).send(
            session: session ?? _session(call['path']! as String),
            commandId: const CommandId('cmd'),
            messageId: messageId,
            draft: draft ?? PromptDraft(text: 'text'),
            delivery: delivery,
            cancellation: cancellation,
          );
      return (result, transport);
    }

    test('for unverified versions and unsupported drafts', () async {
      final cancelled = RequestCancellation()..cancel();
      final cases = {
        'unverifiedVersion': await refuse(version: '2.0.21'),
        'emptyText': await refuse(draft: PromptDraft(text: '  ')),
        'unsupportedDraft': await refuse(
          draft: PromptDraft(text: 'x', metadata: CanonicalValue({'k': 'v'})),
        ),
        'unsupportedDelivery': await refuse(delivery: Delivery.immediate),
        'invalidMessageId': await refuse(messageId: 'evt_x'),
        'invalidSession': await refuse(
          session: SessionRef(_harness.host, _harness.harness, 'bad'),
        ),
        'cancelledBeforeSend': await refuse(cancellation: cancelled),
      };
      for (final MapEntry(key: reason, value: (attempt, transport))
          in cases.entries) {
        expect(attempt.receipt.state.known, ReceiptState.unavailable);
        expect(attempt.receipt.reason, reason);
        expect(attempt.posted, isFalse);
        expect(attempt.submission, isNull);
        expect(transport.requests, isEmpty);
      }
      final closed = _Transport((_, _) => fail('must not send'))
        ..isClosed = true;
      final shut =
          await OpenCodePromptClient(
            closed,
            harness: _harness,
            connectedVersion: '2.0.22',
          ).send(
            session: _session(call['path']! as String),
            commandId: const CommandId('cmd'),
            messageId: 'msg_1a1053e7ad3000a8b22017a68214',
            draft: PromptDraft(text: 'text'),
            delivery: Delivery.queue,
          );
      expect(shut.receipt.reason, 'closed');
      expect(shut.posted, isFalse);
      final local =
          await OpenCodePromptClient(
            _Transport(
              (_, _) => throw const TransportException(
                TransportFailure.invalidTarget,
              ),
            ),
            harness: _harness,
            connectedVersion: '2.0.22',
          ).send(
            session: _session(call['path']! as String),
            commandId: const CommandId('cmd'),
            messageId: 'msg_1a1053e7ad3000a8b22017a68214',
            draft: PromptDraft(text: 'text'),
            delivery: Delivery.queue,
          );
      expect(local.receipt.state.known, ReceiptState.unavailable);
      expect(local.receipt.reason, 'invalidTarget');
      for (final (deadline, bytes) in [
        (Duration.zero, 1),
        (const Duration(seconds: 1), 0),
      ]) {
        expect(
          () => OpenCodePromptClient(
            closed,
            harness: _harness,
            connectedVersion: '2.0.22',
            deadline: deadline,
            maxBodyBytes: bytes,
          ),
          throwsArgumentError,
        );
      }
      await expectLater(
        refuse(
          session: const SessionRef(
            HostId('other'),
            HarnessInstanceId('other'),
            'ses_a',
          ),
        ),
        throwsArgumentError,
      );
    });
  });
}
