import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:codewalk_net/codewalk_net.dart';
import 'package:harness_opencode/harness_opencode.dart';
import 'package:test/test.dart';

import 'support/fixture_replay.dart';

const _harness = HarnessRef(HostId('host'), HarnessInstanceId('instance'));

/// One request at most: a second send fails the test.
final class _Transport implements EndpointHttpTransport {
  _Transport(this.handle);
  final FutureOr<TransportResponse> Function(TransportRequest) handle;
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
    return handle(request);
  }

  @override
  void close() => isClosed = true;
}

/// A response whose body must never be read.
TransportResponse _status(int status) => TransportResponse(
  statusCode: status,
  headers: {
    'content-type': ['application/json'],
  },
  body: Stream.error(StateError('the body is never read')),
  cancel: () {},
);

Map<String, Object?> _call(String file, String name) {
  final json =
      jsonDecode(
            File('${OpenCodeFixtures().root.path}/b/$file').readAsStringSync(),
          )
          as Map<String, Object?>;
  return (json['calls']! as List).cast<Map<String, Object?>>().firstWhere(
    (c) => c['name'] == name,
  );
}

OpenCodePromptClient _client(
  _Transport transport, {
  String version = '2.0.22',
}) => OpenCodePromptClient(
  transport,
  harness: _harness,
  connectedVersion: version,
  deadline: const Duration(milliseconds: 200),
);

SessionRef _ref(String id) => SessionRef(_harness.host, _harness.harness, id);

void main() {
  test(
    'cancel and switch send the captured requests and map their 204',
    () async {
      for (final (file, name) in [
        ('cancel-matrix.json', 'cancelPending'),
        ('queue-steer-space-bunny.json', 'changePendingQueueToSteer'),
      ]) {
        final call = _call(file, name);
        final path = Uri.parse(call['path']! as String);
        final transport = _Transport((_) => _status(call['status']! as int));
        final client = _client(transport);
        final session = _ref(path.pathSegments[2]);
        final id = path.pathSegments[4];
        final result = call['method'] == 'DELETE'
            ? await client.cancelInbox(session: session, messageId: id)
            : await client.switchInboxDelivery(
                session: session,
                messageId: id,
                delivery: Delivery.steer,
              );
        expect(result, isA<OpenCodeInboxCompleted>());
        final request = transport.requests.single;
        expect(request.method, call['method']);
        expect('/${request.path}', path.path);
        final body = request.body;
        expect(
          body == null ? null : jsonDecode(utf8.decode(body)),
          call['request'],
        );
      }
    },
  );

  test('a conflict is refused from the status alone, body unread', () async {
    final call = _call(
      'queue-steer-space-bunny.json',
      'changeDeliveredConflict',
    );
    expect(call['status'], 409);
    final path = Uri.parse(call['path']! as String);
    final result = await _client(_Transport((_) => _status(409)))
        .switchInboxDelivery(
          session: _ref(path.pathSegments[2]),
          messageId: path.pathSegments[4],
          delivery: Delivery.queue,
        );
    expect(
      result,
      isA<OpenCodeInboxRefused>()
          .having((r) => r.error.rawType, 'rawType', 'ConflictError')
          .having((r) => r.error.rawMessage, 'rawMessage', ''),
    );
  });

  test('statuses and transport failures map to finite results', () async {
    const id = 'msg_1a1053e7ad3000a8b22017a68214';
    final session = _ref('ses_1a1053e76490008743dfb6f9d536');
    for (final (status, type) in [
      (400, 'InvalidRequestError'),
      (401, 'UnauthorizedError'),
      (403, 'UnauthorizedError'),
      (404, 'SessionNotFoundError'),
      (409, 'ConflictError'),
      (429, 'RateLimited'),
    ]) {
      final result = await _client(
        _Transport((_) => _status(status)),
      ).cancelInbox(session: session, messageId: id);
      expect(
        result,
        isA<OpenCodeInboxRefused>().having(
          (r) => r.error.rawType,
          'rawType',
          type,
        ),
      );
    }
    expect(
      await _client(
        _Transport((_) => _status(500)),
      ).cancelInbox(session: session, messageId: id),
      isA<OpenCodeInboxUncertain>().having((r) => r.reason, 'r', 'status500'),
    );
    expect(
      await _client(
        _Transport(
          (_) => throw const TransportException(TransportFailure.connection),
        ),
      ).cancelInbox(session: session, messageId: id),
      isA<OpenCodeInboxUncertain>().having((r) => r.reason, 'r', 'connection'),
    );
    expect(
      await _client(
        _Transport(
          (_) => throw const TransportException(TransportFailure.invalidTarget),
        ),
      ).cancelInbox(session: session, messageId: id),
      isA<OpenCodeInboxNotSent>(),
    );
    // Headers that never arrive are bounded by the deadline.
    expect(
      await _client(
        _Transport((_) => Completer<TransportResponse>().future),
      ).cancelInbox(session: session, messageId: id),
      isA<OpenCodeInboxUncertain>().having((r) => r.reason, 'r', 'timeout'),
    );
  });

  test('nothing is sent for an unverified version or invalid input', () async {
    const id = 'msg_1a1053e7ad3000a8b22017a68214';
    final session = _ref('ses_1a1053e76490008743dfb6f9d536');
    final transport = _Transport((_) => fail('no request expected'));
    expect(
      await _client(
        transport,
        version: '3.0.0',
      ).cancelInbox(session: session, messageId: id),
      isA<OpenCodeInboxNotSent>(),
    );
    final client = _client(transport);
    expect(
      await client.cancelInbox(session: session, messageId: 'evt_1'),
      isA<OpenCodeInboxNotSent>(),
    );
    expect(
      await client.switchInboxDelivery(
        session: session,
        messageId: id,
        delivery: Delivery.immediate,
      ),
      isA<OpenCodeInboxNotSent>(),
    );
    transport.isClosed = true;
    expect(
      await client.cancelInbox(session: session, messageId: id),
      isA<OpenCodeInboxNotSent>(),
    );
    expect(transport.requests, isEmpty);
    expect(
      () => client.cancelInbox(
        session: const SessionRef(
          HostId('other'),
          HarnessInstanceId('instance'),
          'ses_1a1053e76490008743dfb6f9d536',
        ),
        messageId: id,
      ),
      throwsArgumentError,
    );
  });
}
