import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:codewalk_net/codewalk_net.dart';
import 'package:harness_opencode/harness_opencode.dart';
import 'package:test/test.dart';

import 'history_test_data.dart';
import 'session_lifecycle_test_data.dart';
import 'text_reasoning_test_data.dart' show observedPosition;

// Source-shaped inputs derived from the pinned 2.0.22 schemas and the
// reference reducer; no live switch or selected frame was captured.
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
    return handle(request);
  }

  @override
  void close() => isClosed = true;
}

TransportResponse _response(Object? body, {int status = 200}) =>
    TransportResponse(
      statusCode: status,
      headers: const {
        'content-type': ['application/json'],
      },
      body: status == 204
          ? const Stream.empty()
          : Stream.value(utf8.encode(jsonEncode(body))),
      cancel: () {},
    );

Map<String, Object?> _bodyOf(TransportRequest request) =>
    jsonDecode(utf8.decode(request.body!)) as Map<String, Object?>;

Map<String, Object?> _modelFixture() =>
    jsonDecode(
          File(
            '../../test/contract/fixtures/opencode/2.0.22/model.json',
          ).readAsStringSync(),
        )
        as Map<String, Object?>;

/// The model list an observed 2.0.22 server answered for one location.
({String directory, Map<String, Object?> body}) _observedModelList() {
  final capture =
      jsonDecode(
            File(
              '../../test/contract/fixtures/opencode/2.0.22/c/provider-once.json',
            ).readAsStringSync(),
          )
          as Map<String, Object?>;
  for (final call in capture['calls']! as List) {
    final exchange = call as Map<String, Object?>;
    final path = Uri.parse(exchange['path']! as String);
    if (exchange['method'] == 'GET' && path.path == '/api/model') {
      return (
        directory: path.queryParameters['location[directory]']!,
        body: exchange['response']! as Map<String, Object?>,
      );
    }
  }
  throw StateError('No observed model list');
}

Map<String, Object?> _catalog(List<Object?> rows, {String? directory}) => {
  'location': {'directory': directory ?? '/work/app'},
  'data': rows,
};

Map<String, Object?> _agent(
  String id, {
  String mode = 'primary',
  bool hidden = false,
}) => {
  'id': id,
  'name': 'Agent $id',
  'description': 'Does $id',
  'model': {'id': 'fake-private-model', 'providerID': 'fake-private'},
  'mode': mode,
  'hidden': hidden,
  'permissions': [],
};

OpenCodeSessionReader _reader(_Transport transport) =>
    OpenCodeSessionReader(transport, harness: historyHarness);

Matcher _readFailure(OpenCodeSessionReadFailure kind) => throwsA(
  isA<OpenCodeSessionReadException>().having((e) => e.failure, 'failure', kind),
);

SessionState _withSelection(Selection selection) => reduce(
  SessionState(historyRef),
  SelectionChanged(
    meta: EventMeta(
      owner: SessionOwner(historyRef),
      position: observedPosition(0),
      receivedAt: DateTime.utc(2026, 10, 22),
      source: SourceProvenance(
        harness: historyRef.harnessRef,
        version: '2.0.22',
        nativeType: 'seed',
      ),
    ),
    selection: selection,
  ),
).state;

Selection _selectionOf(List<SessionEvent> events) =>
    (events.single as SelectionChanged).selection;

void main() {
  group('the selected events', () {
    const resident = Selection(
      modelId: 'model-a',
      modelProviderId: 'provider-a',
      modelVariant: 'low',
      agentId: 'build',
    );

    test('a model switch replaces the whole reference and keeps the agent', () {
      final events = projectLifecycle(
        lifecycleFrame(
          'model.selected',
          data: {
            'model': {'id': 'model-b', 'providerID': 'provider-b'},
            'previous': {
              'id': 'model-a',
              'providerID': 'provider-a',
              'variant': 'low',
            },
          },
        ),
        current: _withSelection(resident),
      );
      final selection = _selectionOf(events);
      expect(selection.modelId, 'model-b');
      expect(selection.modelProviderId, 'provider-b');
      // A reference without a variant clears the old one.
      expect(selection.modelVariant, isNull);
      expect(selection.agentId, 'build');
      final source = events.single.meta.source;
      expect(source.nativeType, 'session.model.selected');
      expect(source.durability.known, Durability.durable);
    });

    test('an agent switch keeps the model reference', () {
      final selection = _selectionOf(
        projectLifecycle(
          lifecycleFrame(
            'agent.selected',
            data: {'agent': 'plan', 'previous': 'build'},
          ),
          current: _withSelection(resident),
        ),
      );
      expect(selection.agentId, 'plan');
      expect(selection.modelId, 'model-a');
      expect(selection.modelProviderId, 'provider-a');
      expect(selection.modelVariant, 'low');
    });

    test('without a resident selection only the switched half is known', () {
      final selection = _selectionOf(
        projectLifecycle(
          lifecycleFrame(
            'model.selected',
            data: {
              'model': {'id': 'model-b', 'providerID': 'p', 'variant': 'max'},
            },
          ),
        ),
      );
      expect(selection.modelVariant, 'max');
      expect(selection.agentId, isNull);
    });

    test('a switch of another session projects nothing', () {
      expect(
        projectLifecycle(
          lifecycleFrame(
            'agent.selected',
            session: 'ses_other',
            data: {'agent': 'plan'},
          ),
          current: _withSelection(resident),
        ),
        isEmpty,
      );
    });

    test('the reducer applies the projected selection', () {
      final current = _withSelection(resident);
      final next = reduce(
        current,
        projectLifecycle(
          lifecycleFrame('agent.selected', data: {'agent': 'plan'}),
          current: current,
        ).single,
      ).state;
      expect(next.selection!.agentId, 'plan');
      expect(next.selection!.modelVariant, 'low');
    });

    test('malformed switches fail with finite categories', () {
      for (final (data, failure) in [
        (
          <String, Object?>{'agent': ''},
          OpenCodeSessionLifecycleProjectionFailure.malformed,
        ),
        (
          <String, Object?>{
            'model': {'id': 'model-b'},
          },
          OpenCodeSessionLifecycleProjectionFailure.malformed,
        ),
        (
          <String, Object?>{
            'model': {'id': 'model-b', 'providerID': 'p'},
            'previous': 'model-a',
          },
          OpenCodeSessionLifecycleProjectionFailure.malformed,
        ),
      ]) {
        final phase = data.containsKey('agent')
            ? 'agent.selected'
            : 'model.selected';
        expect(
          () => projectLifecycle(lifecycleFrame(phase, data: data)),
          throwsA(
            isA<OpenCodeSessionLifecycleProjectionException>().having(
              (e) => e.failure,
              'failure',
              failure,
            ),
          ),
        );
      }
      expect(
        () => projectLifecycle(
          lifecycleFrame('agent.selected', data: {'agent': 'plan'}, version: 2),
        ),
        throwsA(isA<OpenCodeSessionLifecycleProjectionException>()),
      );
    });

    test('the event entry point routes both switches', () {
      for (final (phase, data) in [
        ('agent.selected', <String, Object?>{'agent': 'plan'}),
        (
          'model.selected',
          <String, Object?>{
            'model': {'id': 'model-b', 'providerID': 'p'},
          },
        ),
      ]) {
        final events = projectOpenCodeEvent(
          lifecycleFrame(phase, data: data),
          SessionState(historyRef),
          sourceVersion: '2.0.22',
          position: observedPosition(1),
          receivedAt: DateTime.utc(2026, 10, 22),
        );
        expect(events.single, isA<SelectionChanged>(), reason: phase);
      }
    });
  });

  group('the catalog', () {
    test('a model keeps only its variant ids, never their settings', () async {
      final transport = _Transport(
        (_) => _response(_catalog([_modelFixture()])),
      );
      final models = await _reader(transport).readModels('/work/app');
      final request = transport.requests.single;
      expect(request.method, 'GET');
      expect(
        Uri.parse(request.path).queryParameters['location[directory]'],
        '/work/app',
      );
      expect(Uri.parse(request.path).path, endsWith('api/model'));
      final model = models.single;
      expect(model.id, 'fledge-alpha-free');
      expect(model.providerId, 'opencode');
      expect(model.label, 'Fledge Alpha Free');
      expect(model.variants, ['low', 'high', 'max']);
      expect(model.metadata, isNull);
      expect(model.inputModalities, isEmpty);
    });

    test('an observed list of every provider model is read whole', () async {
      final (:directory, :body) = _observedModelList();
      final rows = body['data']! as List;
      final encoded = utf8.encode(jsonEncode(body)).length;
      expect(rows, hasLength(185));
      final transport = _Transport((_) => _response(body));
      // The catalog bound is its own: a smaller session bound does not apply.
      final models = await OpenCodeSessionReader(
        transport,
        harness: historyHarness,
        maxBodyBytes: encoded ~/ 4,
      ).readModels(directory);
      expect(
        models,
        hasLength(rows.where((row) => (row as Map)['enabled'] == true).length),
      );
      expect(
        models.map((model) => '${model.providerId}/${model.id}').toSet(),
        hasLength(models.length),
      );
      await expectLater(
        OpenCodeSessionReader(
          _Transport((_) => _response(body)),
          harness: historyHarness,
          maxCatalogBytes: encoded ~/ 4,
        ).readModels(directory),
        _readFailure(OpenCodeSessionReadFailure.bodyTooLarge),
      );
    });

    test('a variant without a nameable id is not offered', () async {
      final transport = _Transport(
        (_) => _response(
          _catalog([
            {
              ..._modelFixture(),
              'variants': [
                {'id': ''},
                {'id': 'high', 'settings': {}},
              ],
            },
          ]),
        ),
      );
      final models = await _reader(transport).readModels('/work/app');
      expect(models.single.variants, ['high']);
    });

    test('a model keeps its stated prices; only an untiered zero is free', () {
      Future<ModelEntry> read(Object? cost, {bool omit = false}) async {
        final row = {..._modelFixture()};
        if (omit) {
          row.remove('cost');
        } else {
          row['cost'] = cost;
        }
        final transport = _Transport((_) => _response(_catalog([row])));
        return (await _reader(transport).readModels('/work/app')).single;
      }

      Map<String, Object?> price(num value, {Object? tier}) => {
        'tier': ?tier,
        'input': value,
        'output': value,
        'cache': {'read': value, 'write': value},
      };
      return Future.wait([
        // The observed 2.0.22 free model states one zero price.
        read(null, omit: true).then((m) => expect(m.cost, isNull)),
        read(_modelFixture()['cost']).then((m) {
          expect(m.cost!.single.zero, isTrue);
          expect(m.free, isTrue);
        }),
        read([price(0.5)]).then((m) {
          expect(m.cost!.single.input, 0.5);
          expect(m.free, isFalse);
        }),
        read([
          price(0),
          price(0, tier: {'type': 'context', 'size': 200000}),
        ]).then((m) {
          expect(m.cost!.last.contextTier, 200000);
          expect(m.free, isFalse);
        }),
        read(<Object?>[]).then((m) {
          expect(m.cost, isEmpty);
          expect(m.free, isFalse);
        }),
        // An unreadable price is unknown; the model is still offered.
        for (final unreadable in <Object?>[
          'free',
          [price(-1)],
          [
            {...price(0), 'cache': null},
          ],
          [
            price(0, tier: {'type': 'request', 'size': 1}),
          ],
          [for (var i = 0; i < 17; i++) price(0)],
        ])
          read(unreadable).then((m) {
            expect(m.cost, isNull);
            expect(m.free, isFalse);
          }),
      ]);
    });

    test('a disabled model is not offered', () async {
      final transport = _Transport(
        (_) => _response(
          _catalog([
            {..._modelFixture(), 'enabled': false},
          ]),
        ),
      );
      expect(await _reader(transport).readModels('/work/app'), isEmpty);
    });

    test('only primary agents that are not hidden are offered', () async {
      final transport = _Transport(
        (_) => _response(
          _catalog([
            _agent('build'),
            _agent('general', mode: 'all'),
            _agent('explore', mode: 'subagent'),
            _agent('title', hidden: true),
            _agent('future', mode: 'futureMode'),
          ]),
        ),
      );
      final agents = await _reader(transport).readAgents('/work/app');
      expect(agents.map((agent) => agent.id), ['build', 'general']);
      expect(agents.first.label, 'Agent build');
      expect(agents.first.description, 'Does build');
      expect(agents.first.kind.known, CatalogKind.agent);
      expect(agents.first.metadata, isNull);
    });

    test('an agent that is not offered is never projected', () async {
      final transport = _Transport(
        (_) => _response(
          _catalog([
            _agent('build'),
            {..._agent('title', hidden: true), 'id': ''},
            {..._agent('explore', mode: 'subagent'), 'name': 'x' * 5000},
          ]),
        ),
      );
      final agents = await _reader(transport).readAgents('/work/app');
      expect(agents.map((agent) => agent.id), ['build']);
    });

    test('an empty location answers an empty list', () async {
      final transport = _Transport((_) => _response(_catalog([])));
      expect(await _reader(transport).readAgents('/work/app'), isEmpty);
    });

    test('an answer for another location or a malformed row fails', () async {
      for (final body in [
        _catalog([_agent('build')], directory: '/elsewhere'),
        _catalog([_agent('build'), _agent('build')]),
        _catalog([
          {..._agent('build'), 'hidden': 'no'},
        ]),
        {'data': <Object?>[]},
      ]) {
        final transport = _Transport((_) => _response(body));
        await expectLater(
          _reader(transport).readAgents('/work/app'),
          _readFailure(OpenCodeSessionReadFailure.incompatibleResponse),
        );
      }
    });

    test('the status decides a missing or refused catalog', () async {
      for (final (status, failure) in [
        (404, OpenCodeSessionReadFailure.notFound),
        (401, OpenCodeSessionReadFailure.authenticationRequired),
        (503, OpenCodeSessionReadFailure.unavailable),
      ]) {
        final transport = _Transport((_) => _response({}, status: status));
        await expectLater(
          _reader(transport).readModels('/work/app'),
          _readFailure(failure),
        );
      }
    });

    test('a catalog is never read without a location', () async {
      final transport = _Transport((_) => _response(_catalog([])));
      await expectLater(
        _reader(transport).readModels(''),
        _readFailure(OpenCodeSessionReadFailure.invalidRequest),
      );
      expect(transport.requests, isEmpty);
    });
  });

  group('the record', () {
    test('the session record answers the current selection', () async {
      final record =
          jsonDecode(
                File(
                  '../../test/contract/fixtures/opencode/2.0.22/'
                  'session-created.json',
                ).readAsStringSync(),
              )
              as Map<String, Object?>;
      final data = record['data']! as Map<String, Object?>;
      final ref = SessionRef(
        historyHarness.host,
        historyHarness.harness,
        data['id']! as String,
      );
      final transport = _Transport((_) => _response(record));
      final selection = await _reader(transport).readSelection(ref);
      expect(
        Uri.parse(transport.requests.single.path).path,
        endsWith(ref.nativeId),
      );
      expect(selection.modelId, 'fledge-alpha-free');
      expect(selection.modelProviderId, 'opencode');
      expect(selection.modelVariant, 'low');
      expect(selection.agentId, isNull);
    });
  });

  group('the switch', () {
    const session = historyRef;
    const id = CommandId('cmd_select');
    OpenCodeSessionLifecycleClient client(
      _Transport transport, {
      String version = '2.0.22',
    }) => OpenCodeSessionLifecycleClient(
      transport,
      harness: historyHarness,
      connectedVersion: version,
    );

    test('a model switch sends the whole reference once', () async {
      final transport = _Transport((_) => _response(null, status: 204));
      final attempt = await client(transport).selectModel(
        session: session,
        id: id,
        modelId: 'model-b',
        providerId: 'provider-b',
        variant: 'high',
      );
      final request = transport.requests.single;
      expect(request.method, 'POST');
      expect(request.path, endsWith('api/session/${session.nativeId}/model'));
      expect(_bodyOf(request), {
        'model': {
          'id': 'model-b',
          'providerID': 'provider-b',
          'variant': 'high',
        },
      });
      expect(attempt.receipt.state.known, ReceiptState.accepted);
      expect(attempt.command.operation.known, MutationOperation.selection);
    });

    test('a reference without a variant omits it', () async {
      final transport = _Transport((_) => _response(null, status: 204));
      await client(transport).selectModel(
        session: session,
        id: id,
        modelId: 'model-b',
        providerId: 'provider-b',
      );
      expect(_bodyOf(transport.requests.single), {
        'model': {'id': 'model-b', 'providerID': 'provider-b'},
      });
    });

    test('an agent switch sends only the agent', () async {
      final transport = _Transport((_) => _response(null, status: 204));
      final attempt = await client(
        transport,
      ).selectAgent(session: session, id: id, agentId: 'plan');
      final request = transport.requests.single;
      expect(request.path, endsWith('api/session/${session.nativeId}/agent'));
      expect(_bodyOf(request), {'agent': 'plan'});
      expect(attempt.receipt.state.known, ReceiptState.accepted);
    });

    test('an uncertain answer is never repeated', () async {
      for (final status in [500, 503]) {
        final transport = _Transport((_) => _response({}, status: status));
        final attempt = await client(
          transport,
        ).selectAgent(session: session, id: id, agentId: 'plan');
        expect(transport.requests, hasLength(1));
        expect(attempt.receipt.state.known, ReceiptState.uncertain);
      }
    });

    test('a refusal is known from the status alone', () async {
      for (final status in [400, 401, 404, 429]) {
        final transport = _Transport((_) => _response({}, status: status));
        final attempt = await client(
          transport,
        ).selectAgent(session: session, id: id, agentId: 'plan');
        expect(attempt.receipt.state.known, ReceiptState.rejected);
        expect(attempt.receipt.error?.rawMessage, isEmpty);
      }
    });

    test(
      'nothing is sent to an unverified version or another harness',
      () async {
        final transport = _Transport((_) => _response(null, status: 204));
        final attempt = await client(
          transport,
          version: '2.0.21',
        ).selectAgent(session: session, id: id, agentId: 'plan');
        expect(attempt.receipt.state.known, ReceiptState.unavailable);
        expect(attempt.receipt.reason, 'unverifiedVersion');
        final foreign = SessionRef(
          historyHarness.host,
          const HarnessInstanceId('other'),
          session.nativeId,
        );
        await expectLater(
          client(transport).selectAgent(session: foreign, id: id, agentId: 'p'),
          throwsArgumentError,
        );
        await expectLater(
          client(transport).selectModel(
            session: session,
            id: id,
            modelId: '',
            providerId: 'provider-b',
          ),
          throwsArgumentError,
        );
        expect(transport.requests, isEmpty);
      },
    );
  });
}
