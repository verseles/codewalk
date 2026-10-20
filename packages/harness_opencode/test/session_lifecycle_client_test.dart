import 'dart:async';
import 'dart:convert';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:codewalk_net/codewalk_net.dart';
import 'package:harness_opencode/harness_opencode.dart';
import 'package:test/test.dart';

const harness = HarnessRef(HostId('host'), HarnessInstanceId('instance'));
const session = SessionRef(
  HostId('host'),
  HarnessInstanceId('instance'),
  'ses_one',
);
const id = CommandId('cmd_lifecycle');

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
    return handle(request, cancellation);
  }

  @override
  void close() => isClosed = true;
}

TransportResponse response(
  Object? body, {
  int status = 200,
  bool empty = false,
}) => TransportResponse(
  statusCode: status,
  headers: const {
    'content-type': ['application/json'],
  },
  body: empty
      ? const Stream.empty()
      : Stream.value(utf8.encode(jsonEncode(body))),
  cancel: () {},
);

Map<String, Object?> sessionRecord({
  String nativeId = 'ses_new',
  String? title,
  String? directory,
}) {
  final record = <String, Object?>{
    'id': nativeId,
    'time': {'created': 1791087839951, 'updated': 1791087839951},
  };
  if (title != null) record['title'] = title;
  if (directory != null) record['location'] = {'directory': directory};
  return record;
}

OpenCodeSessionLifecycleClient client(
  EndpointHttpTransport t, {
  String version = '2.0.22',
  Duration deadline = const Duration(seconds: 20),
}) => OpenCodeSessionLifecycleClient(
  t,
  harness: harness,
  connectedVersion: version,
  deadline: deadline,
);

Map<String, Object?> bodyOf(TransportRequest request) =>
    jsonDecode(utf8.decode(request.body!)) as Map<String, Object?>;

void main() {
  group('the encodings', () {
    test('create sends the directory in the body and nothing else', () async {
      final transport = _Transport(
        (_, _) => response({'data': sessionRecord(title: 'New')}),
      );
      final attempt = await client(transport).create(
        id: id,
        directory: '/work/project',
      );
      expect(transport.requests, hasLength(1));
      final request = transport.requests.single;
      expect(request.method, 'POST');
      expect(request.path, endsWith('api/session'));
      expect(request.headers['Content-Type'], 'application/json');
      expect(bodyOf(request), {
        'location': {'directory': '/work/project'},
      });
      expect(attempt.receipt.state.known, ReceiptState.accepted);
      expect(attempt.session?.info.ref.nativeId, 'ses_new');
      expect(attempt.session?.info.title, 'New');
      expect(attempt.command.operation.known, MutationOperation.create);
    });

    test('create carries the caller identifier and the title', () async {
      final transport = _Transport(
        (_, _) => response({
          'data': sessionRecord(
            nativeId: 'ses_minted',
            title: 'T',
            directory: '/work/project',
          ),
        }),
      );
      await client(transport).create(
        id: id,
        directory: '/work/project',
        nativeSessionId: 'ses_minted',
        title: 'T',
      );
      expect(bodyOf(transport.requests.single), {
        'location': {'directory': '/work/project'},
        'id': 'ses_minted',
        'title': 'T',
      });
    });

    test('rename sends the title and answers 204', () async {
      final transport = _Transport((_, _) => response(null, status: 204, empty: true));
      final attempt = await client(transport).rename(
        session: session,
        id: id,
        title: 'New title',
      );
      final request = transport.requests.single;
      expect(request.method, 'PATCH');
      expect(request.path, endsWith('api/session/ses_one'));
      expect(bodyOf(request), {'title': 'New title'});
      expect(attempt.receipt.state.known, ReceiptState.accepted);
      expect(attempt.receipt.nativeRef, 'ses_one');
      expect(attempt.command.operation.known, MutationOperation.rename);
    });

    test('delete sends no body', () async {
      final transport = _Transport((_, _) => response(null, status: 204, empty: true));
      final attempt = await client(transport).delete(session: session, id: id);
      final request = transport.requests.single;
      expect(request.method, 'DELETE');
      expect(request.path, endsWith('api/session/ses_one'));
      expect(request.body, isNull);
      expect(request.headers.containsKey('Content-Type'), isFalse);
      expect(attempt.receipt.state.known, ReceiptState.accepted);
      expect(attempt.command.operation.known, MutationOperation.delete);
    });

    test('fork sends the optional boundary and answers with the session', () async {
      final transport = _Transport(
        (_, _) => response({'data': sessionRecord(nativeId: 'ses_fork')}),
      );
      final attempt = await client(transport).fork(
        session: session,
        id: id,
        before: 'msg_one',
      );
      final request = transport.requests.single;
      expect(request.method, 'POST');
      expect(request.path, endsWith('api/session/ses_one/fork'));
      expect(bodyOf(request), {'before': 'msg_one'});
      expect(attempt.session?.info.ref.nativeId, 'ses_fork');
      expect(attempt.command.operation.known, MutationOperation.fork);
    });

    test('fork without a boundary copies the whole history', () async {
      final transport = _Transport(
        (_, _) => response({'data': sessionRecord(nativeId: 'ses_fork')}),
      );
      await client(transport).fork(session: session, id: id);
      expect(bodyOf(transport.requests.single), <String, Object?>{});
    });

    test('mark viewed sends the observed idle', () async {
      final transport = _Transport((_, _) => response(null, status: 204, empty: true));
      final attempt = await client(transport).markViewed(
        session: session,
        id: id,
        idle: 1791087839951,
      );
      final request = transport.requests.single;
      expect(request.method, 'POST');
      expect(request.path, endsWith('api/session/ses_one/view'));
      expect(bodyOf(request), {'idle': 1791087839951});
      expect(attempt.command.operation.known, MutationOperation.markViewed);
    });
  });

  group('the refusals', () {
    test('an unverified version sends nothing', () async {
      final transport = _Transport((_, _) => response(null, status: 204, empty: true));
      final attempt = await client(
        transport,
        version: '2.0.21',
      ).rename(session: session, id: id, title: 'T');
      expect(transport.requests, isEmpty);
      expect(attempt.receipt.state.known, ReceiptState.unavailable);
      expect(attempt.receipt.reason, 'unverifiedVersion');
    });

    test('the status alone decides the refusal', () async {
      final cases = {
        400: (ErrorKind.protocol, 'InvalidRequestError'),
        401: (ErrorKind.auth, 'UnauthorizedError'),
        403: (ErrorKind.auth, 'UnauthorizedError'),
        404: (ErrorKind.protocol, 'SessionNotFoundError'),
        429: (ErrorKind.rateLimit, 'RateLimited'),
      };
      for (final entry in cases.entries) {
        final transport = _Transport(
          (_, _) => response(null, status: entry.key, empty: true),
        );
        final attempt = await client(transport).rename(
          session: session,
          id: id,
          title: 'T',
        );
        expect(
          attempt.receipt.state.known,
          ReceiptState.rejected,
          reason: 'status ${entry.key}',
        );
        expect(attempt.receipt.error?.kind.known, entry.value.$1);
        expect(attempt.receipt.error?.rawType, entry.value.$2);
        expect(attempt.receipt.error?.rawMessage, isEmpty);
      }
    });

    test('an unknown status is uncertain', () async {
      final transport = _Transport(
        (_, _) => response(null, status: 500, empty: true),
      );
      final attempt = await client(transport).rename(
        session: session,
        id: id,
        title: 'T',
      );
      expect(attempt.receipt.state.known, ReceiptState.uncertain);
      expect(attempt.receipt.reason, 'status500');
    });

    test('a create that returns another session is refused', () async {
      // The endpoint answers a same-identifier create with the session that
      // identifier already owns, ignoring the changed fields.
      final transport = _Transport(
        (_, _) => response({
          'data': sessionRecord(
            nativeId: 'ses_minted',
            title: 'The original title',
            directory: '/work/other',
          ),
        }),
      );
      final attempt = await client(transport).create(
        id: id,
        directory: '/work/project',
        nativeSessionId: 'ses_minted',
        title: 'The new title',
      );
      expect(attempt.receipt.state.known, ReceiptState.rejected);
      expect(attempt.receipt.error?.rawType, 'SessionIdentityOccupied');
      expect(attempt.session, isNull);
    });

    test('a malformed body is uncertain', () async {
      final transport = _Transport((_, _) => response({'data': 'not a session'}));
      final attempt = await client(transport).create(
        id: id,
        directory: '/work/project',
      );
      expect(attempt.receipt.state.known, ReceiptState.uncertain);
      expect(attempt.receipt.reason, 'malformedSession');
    });

    test('an invalid session identifier is refused before the send', () async {
      final transport = _Transport((_, _) => response(null, status: 204, empty: true));
      final attempt = await client(transport).rename(
        session: const SessionRef(
          HostId('host'),
          HarnessInstanceId('instance'),
          'not-a-session',
        ),
        id: id,
        title: 'T',
      );
      expect(transport.requests, isEmpty);
      expect(attempt.receipt.state.known, ReceiptState.unavailable);
      expect(attempt.receipt.reason, 'invalidSession');
    });

    test('a cancelled request sends nothing', () async {
      final transport = _Transport((_, _) => response(null, status: 204, empty: true));
      final cancellation = RequestCancellation()..cancel();
      final attempt = await client(transport).rename(
        session: session,
        id: id,
        title: 'T',
        cancellation: cancellation,
      );
      expect(transport.requests, isEmpty);
      expect(attempt.receipt.state.known, ReceiptState.unavailable);
      expect(attempt.receipt.reason, 'cancelledBeforeSend');
    });

    test('a closed transport sends nothing', () async {
      final transport = _Transport((_, _) => response(null, status: 204, empty: true))
        ..isClosed = true;
      final attempt = await client(transport).rename(
        session: session,
        id: id,
        title: 'T',
      );
      expect(transport.requests, isEmpty);
      expect(attempt.receipt.state.known, ReceiptState.unavailable);
      expect(attempt.receipt.reason, 'closed');
    });
  });

  group('the receipts', () {
    test('the reasons never carry the session or the directory', () async {
      final transport = _Transport(
        (_, _) => response(null, status: 400, empty: true),
      );
      final attempt = await client(transport).rename(
        session: session,
        id: id,
        title: 'A secret title',
      );
      final reason = attempt.receipt.reason ?? '';
      expect(reason, isNot(contains('ses_one')));
      expect(reason, isNot(contains('secret')));
      expect(attempt.receipt.error?.rawMessage, isEmpty);
    });

    test('the payload is the exact body that was sent', () async {
      final transport = _Transport((_, _) => response(null, status: 204, empty: true));
      final attempt = await client(transport).rename(
        session: session,
        id: id,
        title: 'New title',
      );
      expect(attempt.payload, '{"title":"New title"}');
      expect(attempt.session, isNull);
    });

    test('the attempt never replays', () async {
      final transport = _Transport((_, _) => response(null, status: 204, empty: true));
      await client(transport).rename(session: session, id: id, title: 'T');
      expect(transport.requests, hasLength(1));
    });
  });
}
