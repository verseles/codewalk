import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:codewalk_net/codewalk_net.dart';
import 'package:harness_opencode/harness_opencode.dart';
import 'package:test/test.dart';

import 'support/fixture_replay.dart';

const _harness = HarnessRef(HostId('host-a'), HarnessInstanceId('native-a'));

/// Answers by path; every request is recorded.
final class _Transport implements EndpointHttpTransport {
  _Transport(this.handle);
  final FutureOr<TransportResponse> Function(Uri uri) handle;
  final requests = <Uri>[];
  @override
  Uri endpoint = Uri.parse('http://127.0.0.1/');
  @override
  bool isClosed = false;
  @override
  Future<TransportResponse> send(
    TransportRequest request, {
    RequestCancellation? cancellation,
  }) async {
    expect(request.method, 'GET');
    final uri = Uri.parse(request.path);
    requests.add(uri);
    return handle(uri);
  }

  @override
  void close() => isClosed = true;
}

TransportResponse _json(Object? body, {int status = 200}) => TransportResponse(
  statusCode: status,
  headers: {
    'content-type': ['application/json'],
  },
  body: Stream.value(utf8.encode(jsonEncode(body))),
  cancel: () {},
);

Map<String, Object?> _call(String file, String name) {
  final json =
      jsonDecode(
            File('${OpenCodeFixtures().root.path}/b/$file').readAsStringSync(),
          )
          as Map<String, Object?>;
  return (json['calls']! as List).cast<Map<String, Object?>>().singleWhere(
    (c) => c['name'] == name,
  );
}

Map<String, Object?> _history(
  List<Map<String, Object?>> rows, {
  String? next,
}) => {
  'data': rows,
  'cursor': {'previous': null, 'next': next},
};

Map<String, Object?> _assistant(int i) => {
  'id': 'msg_1054619840${i.toString().padLeft(2, '0')}R7ekyD9fEiYqiP',
  'time': {'created': 1},
  'type': 'assistant',
};

SessionRef _ref(String id) => SessionRef(_harness.host, _harness.harness, id);

Future<OpenCodePromptLocation> _locate(
  _Transport transport,
  String session,
  String id, {
  int pages = 5,
  String version = '2.0.22',
}) => OpenCodeSessionReader(transport, harness: _harness).locatePrompt(
  _ref(session),
  id,
  sourceVersion: version,
  maxHistoryPages: pages,
);

void main() {
  test(
    'timeout after admission: the id is pending in the captured inbox',
    () async {
      final inbox = _call('prompt-matrix.json', 'afterPromptBeforeRetryinbox');
      final session = Uri.parse(inbox['path']! as String).pathSegments[2];
      final transport = _Transport((uri) => _json(inbox['response']));
      final location = await _locate(
        transport,
        session,
        'msg_1a1053e7e51000a02fa23b246fe3',
      );
      expect(
        location,
        isA<OpenCodePromptPending>()
            .having((p) => p.text, 'text', 'After timeout prompt.')
            .having((p) => p.delivery, 'delivery', 'queue'),
      );
      // Found in the inbox: history is not read.
      expect(transport.requests.map((u) => u.path), [
        'api/session/$session/inbox',
      ]);
    },
  );

  test(
    'timeout before forwarding: absent from the inbox and a complete history',
    () async {
      final inbox = _call('prompt-matrix.json', 'beforePromptBeforeRetryinbox');
      final history = _call(
        'prompt-matrix.json',
        'beforePromptBeforeRetryhistory',
      );
      final session = Uri.parse(inbox['path']! as String).pathSegments[2];
      final transport = _Transport(
        (uri) => _json(
          uri.path.endsWith('/inbox') ? inbox['response'] : history['response'],
        ),
      );
      expect(
        await _locate(transport, session, 'msg_1a1053e7c3e0004b1e2a90760387'),
        isA<OpenCodePromptAbsent>(),
      );
      final read = transport.requests.last;
      expect(read.path, 'api/session/$session/message');
      expect(read.queryParameters, {'limit': '200', 'order': 'desc'});
    },
  );

  test('a promoted id is found in history, even with a next cursor', () async {
    final inbox = _call(
      'promoted-delivery-replay.json',
      'afterPromotedDeliveryReplayinbox',
    );
    final history = _call(
      'promoted-delivery-replay.json',
      'afterPromotedDeliveryReplayhistory',
    );
    final session = Uri.parse(inbox['path']! as String).pathSegments[2];
    final transport = _Transport((uri) {
      if (uri.path.endsWith('/inbox')) return _json(inbox['response']);
      final body = history['response']! as Map<String, Object?>;
      // The captured page is ascending; descending lists the same rows.
      return _json({
        ...body,
        'data': (body['data']! as List).reversed.toList(),
      });
    });
    expect(
      await _locate(transport, session, 'msg_1a10546196f000432f69db883568'),
      isA<OpenCodePromptPromoted>(),
    );
    // The captured last page still carries `next`: a short page ends history.
    expect(
      (history['response']! as Map)['cursor'],
      containsPair('next', isNotNull),
    );
    expect(
      await _locate(transport, session, 'msg_1a10546196f000432f69db883569'),
      isA<OpenCodePromptAbsent>(),
    );
  });

  test('an item promoted between the reads is found in history', () async {
    const id = 'msg_1a10546196f000432f69db883568';
    final transport = _Transport(
      (uri) => _json(
        uri.path.endsWith('/inbox')
            ? {'data': <Object?>[]}
            : _history([
                {
                  'id': id,
                  'time': {'created': 1},
                  'text': 'hi',
                  'type': 'user',
                },
              ]),
      ),
    );
    expect(
      await _locate(transport, 'ses_one', id),
      isA<OpenCodePromptPromoted>(),
    );
  });

  test(
    'full pages follow the native cursor and stop at the page bound',
    () async {
      const id = 'msg_1a10546196f000432f69db883568';
      var page = 0;
      final transport = _Transport((uri) {
        if (uri.path.endsWith('/inbox')) return _json({'data': <Object?>[]});
        page++;
        return _json(
          _history(
            [
              for (var i = 0; i < 200; i++) _assistant(i),
            ].map((r) => {...r, 'id': '${r['id']}$page'}).toList(),
            next: 'older$page',
          ),
        );
      });
      expect(
        await _locate(transport, 'ses_one', id, pages: 2),
        isA<OpenCodePromptIncomplete>(),
      );
      final reads = transport.requests.skip(1).toList();
      expect(reads.first.queryParameters, {'limit': '200', 'order': 'desc'});
      // The cursor already encodes its direction.
      expect(reads.last.queryParameters, {'limit': '200', 'cursor': 'older1'});
      expect(reads, hasLength(2));
    },
  );

  test('a row of another kind under the id is occupied, not ours', () async {
    const id = 'msg_1a10546196f000432f69db883568';
    final inboxSynthetic = _Transport(
      (uri) => _json({
        'data': [
          {
            'id': id,
            'sessionID': 'ses_one',
            'type': 'synthetic',
            'delivery': 'steer',
          },
        ],
      }),
    );
    expect(
      await _locate(inboxSynthetic, 'ses_one', id),
      isA<OpenCodePromptOccupied>(),
    );
    for (final row in [
      {
        'id': id,
        'sessionID': 'ses_two',
        'type': 'user',
        'payload': {'text': 'hi'},
        'delivery': 'steer',
      },
      {'id': id, 'sessionID': 'ses_one', 'type': 'user', 'delivery': 'steer'},
    ]) {
      final transport = _Transport(
        (uri) => _json({
          'data': [row],
        }),
      );
      expect(
        await _locate(transport, 'ses_one', id),
        isA<OpenCodePromptOccupied>(),
      );
      expect(transport.requests, hasLength(1));
    }
    final historyAssistant = _Transport(
      (uri) => _json(
        uri.path.endsWith('/inbox')
            ? {'data': <Object?>[]}
            : _history([
                {
                  'id': id,
                  'time': {'created': 1},
                  'type': 'assistant',
                },
              ]),
      ),
    );
    expect(
      await _locate(historyAssistant, 'ses_one', id),
      isA<OpenCodePromptOccupied>(),
    );
  });

  test('failed or malformed reads never read as absence', () async {
    const id = 'msg_1a10546196f000432f69db883568';
    for (final (status, failure) in [
      (401, OpenCodeSessionReadFailure.authenticationRequired),
      (404, OpenCodeSessionReadFailure.notFound),
      (429, OpenCodeSessionReadFailure.rateLimited),
    ]) {
      final transport = _Transport((uri) => _json({}, status: status));
      await expectLater(
        _locate(transport, 'ses_one', id),
        throwsA(
          isA<OpenCodeSessionReadException>().having(
            (e) => e.failure,
            'failure',
            failure,
          ),
        ),
      );
    }
    for (final body in [
      {'data': 'x'},
      {
        'data': [
          {'id': 'msg_a'},
          {'id': 'msg_a'},
        ],
      },
    ]) {
      await expectLater(
        _locate(_Transport((uri) => _json(body)), 'ses_one', id),
        throwsA(isA<OpenCodeSessionReadException>()),
      );
    }
    // A history page without its cursor object is malformed.
    await expectLater(
      _locate(
        _Transport(
          (uri) => _json(
            uri.path.endsWith('/inbox') ? {'data': <Object?>[]} : {'data': []},
          ),
        ),
        'ses_one',
        id,
      ),
      throwsA(isA<OpenCodeSessionReadException>()),
    );
  });

  test('an unverified version or invalid id sends nothing', () async {
    final transport = _Transport((uri) => fail('no request expected'));
    for (final (id, version) in [
      ('msg_1a10546196f000432f69db883568', '3.0.0'),
      ('evt_1a10546196f000432f69db883568', '2.0.22'),
    ]) {
      await expectLater(
        _locate(transport, 'ses_one', id, version: version),
        throwsA(
          isA<OpenCodeSessionReadException>().having(
            (e) => e.failure,
            'failure',
            OpenCodeSessionReadFailure.invalidRequest,
          ),
        ),
      );
    }
    expect(transport.requests, isEmpty);
  });
}
