import 'dart:async';
import 'dart:convert';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:codewalk_net/codewalk_net.dart';
import 'package:harness_opencode/harness_opencode.dart';
import 'package:test/test.dart';

import 'session_reader_test.dart' as reader_support;

const harness = HarnessRef(HostId('host-a'), HarnessInstanceId('native-a'));
SessionRef ref(String id) => SessionRef(harness.host, harness.harness, id);
const _id = CommandId('cmd_rules');

Map<String, String> rule(String action, String resource, String effect) => {
  'action': action,
  'resource': resource,
  'effect': effect,
};

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
    expect(requests, hasLength(1), reason: 'a rules write never replays');
    return handle(request, cancellation);
  }

  @override
  void close() => isClosed = true;
}

TransportResponse _status(int status) => TransportResponse(
  statusCode: status,
  headers: const {},
  body: const Stream.empty(),
  cancel: () {},
);

OpenCodeSessionRulesClient _client(
  EndpointHttpTransport transport, {
  String version = '2.0.22',
  Duration deadline = const Duration(seconds: 20),
}) => OpenCodeSessionRulesClient(
  transport,
  harness: harness,
  connectedVersion: version,
  deadline: deadline,
);

Future<OpenCodeSessionRulesAttempt> _replace(
  OpenCodeSessionRulesClient client, {
  OpenCodeSessionRules? rules,
  String session = 'ses_one',
  RequestCancellation? cancellation,
}) => client.replace(
  session: ref(session),
  rules: rules ?? OpenCodeSessionRules.empty.withWildcardAllow(),
  change: 'enable',
  id: _id,
  cancellation: cancellation,
);

void main() {
  group('parse', () {
    test('absent and empty both mean no session rules', () {
      for (final value in [null, <Object?>[]]) {
        final rules = OpenCodeSessionRules.parse(value);
        expect(rules.recognized, isTrue);
        expect(rules.rules, isEmpty);
        expect(rules.endsWithWildcardAllow, isFalse);
        expect(rules.canonical, '[]');
      }
    });

    test('keeps native order and recognizes only a trailing wildcard', () {
      final rules = OpenCodeSessionRules.parse([
        rule('*', '*', 'allow'),
        rule('bash', 'rm *', 'deny'),
      ]);
      expect(rules.recognized, isTrue);
      expect(rules.containsWildcardAllow, isTrue);
      expect(rules.endsWithWildcardAllow, isFalse);
      final appended = rules.withWildcardAllow();
      expect(appended.endsWithWildcardAllow, isTrue);
      expect(appended.rules, hasLength(3));
      expect(
        appended.withoutTrailingWildcardAllow().canonical,
        rules.canonical,
      );
      expect(
        rules.canonical,
        jsonEncode([rule('*', '*', 'allow'), rule('bash', 'rm *', 'deny')]),
      );
    });

    test('unexpected shapes are unrecognized and never writable', () {
      final cases = <Object?>[
        'nope',
        {'action': '*'},
        [
          {'action': '*', 'resource': '*'},
        ],
        [
          {...rule('*', '*', 'allow'), 'extra': true},
        ],
        [rule('*', '*', 'maybe')],
        [
          {'action': 1, 'resource': '*', 'effect': 'allow'},
        ],
        [rule('x' * 4097, '*', 'allow')],
        List.filled(1025, rule('a', 'b', 'ask')),
        [rule('\ud800', '*', 'allow')],
      ];
      for (final value in cases) {
        final rules = OpenCodeSessionRules.parse(value);
        expect(rules.recognized, isFalse, reason: '$value');
        expect(rules.endsWithWildcardAllow, isFalse);
        expect(rules.withWildcardAllow, throwsStateError);
      }
    });

    test('removing needs a trailing wildcard', () {
      expect(
        OpenCodeSessionRules.empty.withoutTrailingWildcardAllow,
        throwsStateError,
      );
    });
  });

  group('replace', () {
    test('sends one PATCH with only the permissions array', () async {
      final transport = _Transport((request, _) {
        expect(request.method, 'PATCH');
        expect(Uri.parse(request.path).pathSegments, [
          'api',
          'session',
          'ses_one',
        ]);
        expect(jsonDecode(utf8.decode(request.body!)), {
          'permissions': [rule('bash', '*', 'ask'), rule('*', '*', 'allow')],
        });
        return _status(204);
      });
      final attempt = await _replace(
        _client(transport),
        rules: OpenCodeSessionRules.parse([
          rule('bash', '*', 'ask'),
        ]).withWildcardAllow(),
      );
      expect(attempt.receipt.state.known, ReceiptState.accepted);
      expect(attempt.command.operation.value, 'sessionPermissions');
      expect(attempt.command.operation.isKnown, isFalse);
      expect(transport.requests, hasLength(1));
    });

    test('maps native statuses without reading a body', () async {
      final expected = {
        400: ReceiptState.rejected,
        401: ReceiptState.rejected,
        403: ReceiptState.rejected,
        404: ReceiptState.rejected,
        429: ReceiptState.rejected,
        500: ReceiptState.uncertain,
        200: ReceiptState.uncertain,
      };
      for (final MapEntry(key: status, value: state) in expected.entries) {
        final attempt = await _replace(
          _client(_Transport((_, _) => _status(status))),
        );
        expect(attempt.receipt.state.known, state, reason: 'status $status');
      }
    });

    test('preflight failures never reach the wire', () async {
      final transport = _Transport((_, _) => fail('must not send'));
      final cancelled = RequestCancellation()..cancel();
      final cases = <Future<OpenCodeSessionRulesAttempt>>[
        _replace(_client(transport, version: '2.0.21')),
        _replace(_client(transport), session: 'bad id'),
        _replace(_client(transport), rules: OpenCodeSessionRules.unrecognized),
        _replace(_client(transport), cancellation: cancelled),
      ];
      for (final attempt in await Future.wait(cases)) {
        expect(attempt.receipt.state.known, ReceiptState.unavailable);
      }
      transport.isClosed = true;
      expect(
        (await _replace(_client(transport))).receipt.state.known,
        ReceiptState.unavailable,
      );
      expect(transport.requests, isEmpty);
    });

    test('a deadline after send stays uncertain', () async {
      final never = Completer<TransportResponse>();
      final attempt = await _replace(
        _client(
          _Transport((_, _) => never.future),
          deadline: const Duration(milliseconds: 20),
        ),
      );
      expect(attempt.receipt.state.known, ReceiptState.uncertain);
    });
  });

  group('read', () {
    test('reads the rules of the same session only', () async {
      final transport = reader_support.TestTransport(
        (request, _) => reader_support.response({
          'data': {
            ...reader_support.row('ses_one'),
            'permissions': [rule('*', '*', 'allow')],
          },
        }),
      );
      final reader = OpenCodeSessionReader(transport, harness: harness);
      final rules = await reader.readSessionRules(ref('ses_one'));
      expect(rules.endsWithWildcardAllow, isTrue);
      await expectLater(
        reader.readSessionRules(ref('ses_two')),
        throwsA(isA<OpenCodeSessionReadException>()),
      );
      reader.dispose();
    });

    test('absent rules read as empty; a bad shape stays readable', () async {
      final bodies = [
        reader_support.row('ses_one'),
        {...reader_support.row('ses_one'), 'permissions': 'odd'},
      ];
      var call = 0;
      final transport = reader_support.TestTransport(
        (_, _) => reader_support.response({'data': bodies[call++]}),
      );
      final reader = OpenCodeSessionReader(transport, harness: harness);
      final absent = await reader.readSessionRules(ref('ses_one'));
      expect(absent.recognized, isTrue);
      expect(absent.rules, isEmpty);
      final odd = await reader.readSessionRules(ref('ses_one'));
      expect(odd.recognized, isFalse);
      reader.dispose();
    });
  });
}
