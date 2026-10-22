import 'dart:convert';
import 'dart:io';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:harness_opencode/harness_opencode.dart';
import 'package:test/test.dart';

import 'execution_replay_test.dart' show eventLists, refOf;
import 'history_test_data.dart';
import 'execution_test_data.dart' show executionFrame, retryFrame;
import 'session_reader_test.dart' show TestTransport, response, failure;
import 'support/fixture_replay.dart';
import 'text_reasoning_test_data.dart' show observedPosition;

// Source-shaped inputs, distinct from the immutable observed captures.
Map<String, Object?> inboxRow(
  String id,
  String type, {
  String delivery = 'steer',
  Map<String, Object?>? payload,
}) => {
  'id': id,
  'sessionID': 'ses_a',
  'time': {'created': 1000},
  'type': type,
  'payload':
      payload ??
      switch (type) {
        'move' => {
          'projectID': 'prj',
          'location': {'directory': '/fake-private-move'},
        },
        'compaction' => <String, Object?>{},
        _ => {
          'text': 'text of $id',
          'metadata': {'secret': 'fake-private-metadata'},
        },
      },
  'delivery': delivery,
};

Map<String, Object?> permissionRow({String session = 'ses_a'}) => {
  'id': 'per_a',
  'sessionID': session,
  'action': 'read',
  'resources': ['src/file.txt'],
  'save': ['read:*'],
  'message': 'fake-private-message',
};

Map<String, Object?> formRow({String session = 'ses_a'}) => {
  'id': 'frm_a',
  'sessionID': session,
  'title': 'Pick one',
  'fields': [
    {'key': 'choice', 'type': 'boolean'},
  ],
};

/// Native rows newest first, as `order=desc` returns them.
List<Map<String, Object?>> newestFirst() => [
  message('h3', 'idle', {'outcome': 'succeeded'}),
  message('h2', 'user', {'text': 'second'}),
  message('h1', 'user', {'text': 'first'}),
];

final class Server {
  Server({
    this.active = const {
      'data': {
        'ses_a': {'type': 'running'},
        'ses_other': {'type': 'running'},
      },
    },
    List<Object?>? inbox,
    List<Object?>? history,
    this.next,
    List<Object?>? permissions,
    List<Object?>? forms,
    this.failPath,
    this.revert,
  }) : inbox =
           inbox ??
           [
             inboxRow('msg_h2', 'user'),
             inboxRow('msg_q1', 'user', delivery: 'queue'),
             inboxRow('msg_s1', 'synthetic', delivery: 'queue'),
             inboxRow('msg_k1', 'compaction'),
             inboxRow('msg_m1', 'move'),
             inboxRow(
               'msg_z1',
               'user',
               payload: {
                 'text': 'with context',
                 'files': [
                   {
                     'data': 'fake-private-data',
                     'mime': 'text/plain',
                     'source': {'type': 'inline'},
                   },
                 ],
               },
             ),
           ],
       history = history ?? newestFirst(),
       permissions = permissions ?? [permissionRow()],
       forms = forms ?? [formRow()];

  final Object? active;
  final List<Object?> inbox;
  final List<Object?> history;
  final String? next;
  final List<Object?> permissions;
  final List<Object?> forms;
  final String? failPath;
  final Object? revert;
  final paths = <String>[];

  late final transport = TestTransport((request, _) {
    paths.add(request.path);
    final uri = Uri.parse(request.path);
    final tail = uri.pathSegments.last;
    if (failPath != null && tail == failPath) {
      return response({'error': 'fake-private-error'}, status: 404);
    }
    return response(switch (tail) {
      'active' => active,
      'inbox' => {'data': inbox},
      'message' => {
        'data': history,
        'cursor': {
          'previous': null,
          'next': uri.queryParameters.containsKey('cursor') ? null : next,
        },
      },
      'permission' => {'data': permissions},
      'form' => {'data': forms},
      _ => {
        'data': {
          'id': 'ses_a',
          'title': 'Session',
          'projectID': 'prj_a',
          'location': {'directory': '/workspace'},
          'time': {'created': 1, 'updated': 2},
          'revert': ?revert,
        },
      },
    });
  });
}

Future<SessionSnapshot> hydrate(
  Server server, {
  String version = '2.0.22',
  int limit = 50,
  String generation = 'gen-1',
  int readStart = 10,
  Iterable<SessionRef> children = const [],
}) {
  final reader = OpenCodeSessionReader(
    server.transport,
    harness: historyHarness,
  );
  var tick = 0;
  return reader.hydrateSession(
    historyRef,
    hydrationGeneration: generation,
    readStart: observedPosition(readStart),
    sourceVersion: version,
    historyLimit: limit,
    now: () => DateTime.utc(2026, 10, 14, 0, 0, tick++),
    children: children,
  );
}

String? messageOf(ItemId id) => (jsonDecode(id.value) as List)[1] as String?;

void main() {
  test('reads in order and projects one consistent snapshot', () async {
    final server = Server(next: 'native-older');
    final snapshot = await hydrate(server);
    expect(
      [for (final p in server.paths) p.split('?').first],
      [
        'api/session/active',
        'api/session/ses_a',
        'api/session/ses_a/inbox',
        'api/session/ses_a/message',
        'api/session/ses_a/permission',
        'api/session/ses_a/form',
      ],
    );
    expect(Uri.parse(server.paths[3]).queryParameters, {
      'limit': '50',
      'order': 'desc',
    });

    expect(snapshot.info!.value.title, 'Session');
    final execution = snapshot.execution!.value;
    expect(execution.kind.known, ExecutionKind.running);
    expect(execution.lastOutcome!.kind.known, ExecutionOutcomeKind.succeeded);

    // History is chronological; the delivered steer prompt stays only there.
    final timeline = snapshot.timeline!;
    expect(
      [for (final i in timeline.values) messageOf(i.id)],
      ['msg_h1', 'msg_h2', 'msg_h3', 'msg_z1', 'msg_z1'],
    );
    expect(timeline.values.whereType<TurnOutcome>(), hasLength(1));
    final admitted = timeline.values.whereType<UserInput>().last;
    expect(admitted.delivery.known, DeliveryState.accepted);
    expect(admitted.status.known, ItemStatus.pending);
    expect(timeline.values.last, isA<UnknownItem>());
    expect(timeline.complete, isFalse);
    expect(snapshot.hasMoreHistory, isTrue);
    expect(snapshot.nextHistoryCursor, isNotNull);

    final pending = snapshot.pending!.values;
    expect(
      [for (final p in pending) messageOf(p.id)],
      ['msg_q1', 'msg_s1', 'msg_z1'],
    );
    expect(
      [for (final p in pending) p.delivery.known],
      [Delivery.queue, Delivery.queue, Delivery.steer],
    );

    final interactions = snapshot.interactions!.values;
    expect([for (final r in interactions) r.id.value], ['per_a', 'frm_a']);
    expect(interactions.first.choices.map((c) => c.id), [
      'once',
      'always',
      'reject',
    ]);
    expect(interactions.last.form, isNotNull);
    expect(interactions.every((r) => r.owner is SessionOwner), isTrue);

    final boundaries = [
      snapshot.info!.boundary,
      snapshot.execution!.boundary,
      timeline.boundary,
      snapshot.pending!.boundary,
      snapshot.interactions!.boundary,
    ];
    for (final boundary in boundaries) {
      expect(boundary.hydrationGeneration, 'gen-1');
      expect(boundary.readStart, observedPosition(10));
      expect(boundary.authority.known, SnapshotAuthority.authoritative);
      expect(boundary.readCompletedAt!.isAfter(boundary.readStartedAt), isTrue);
    }
    expect(
      [for (final b in boundaries) b.source!.nativeType],
      [
        'session.get',
        'session.active',
        'session.message.list',
        'session.inbox.list',
        'session.permission.list+session.form.list',
      ],
    );
    expect(
      snapshot.interactions!.boundary.readStartedAt,
      DateTime.utc(2026, 10, 14, 0, 0, 8),
    );
    expect(
      snapshot.interactions!.boundary.readCompletedAt,
      DateTime.utc(2026, 10, 14, 0, 0, 11),
    );

    final encoded = jsonEncode([
      for (final item in timeline.values) item.source.extra?.value,
      for (final p in pending) p.text,
      for (final r in interactions) r.subject?.value,
    ]);
    expect(encoded, isNot(contains('fake-private')));
  });

  test(
    'the session record carries the staged revert; absent is none',
    () async {
      final none = await hydrate(Server());
      expect(none.revert!.value.kind.known, RevertKind.none);
      expect(none.revert!.boundary.source!.nativeType, 'session.get');
      final staged = await hydrate(
        Server(
          revert: {
            'messageID': 'msg_h2',
            'snapshot': 'fake-private-snapshot',
            'files': [
              {
                'file': 'a.txt',
                'patch': 'fake-private-patch',
                'additions': 1,
                'deletions': 0,
                'status': 'modified',
              },
            ],
          },
        ),
      );
      final state = staged.revert!.value;
      expect(state.kind.known, RevertKind.staged);
      expect(messageOf(state.boundary!), 'msg_h2');
      expect(jsonEncode(state.details!.value), isNot(contains('fake-private')));
      await expectLater(
        hydrate(Server(revert: {'messageID': 'x'})),
        throwsA(failure(OpenCodeSessionReadFailure.incompatibleResponse)),
      );
    },
  );

  test('the continuation reads older descending pages', () async {
    final server = Server(next: 'native-older');
    final reader = OpenCodeSessionReader(
      server.transport,
      harness: historyHarness,
    );
    final snapshot = await reader.hydrateSession(
      historyRef,
      hydrationGeneration: 'gen-1',
      readStart: observedPosition(1),
      sourceVersion: '2.0.22',
    );
    final older = await reader.readHistory(
      historyRef,
      sourceVersion: '2.0.22',
      cursor: snapshot.nextHistoryCursor!.value,
    );
    expect(Uri.parse(server.paths.last).queryParameters, {
      'limit': '50',
      'cursor': 'native-older',
    });
    expect(
      [for (final i in older.items) messageOf(i.id)],
      ['msg_h1', 'msg_h2', 'msg_h3'],
    );
  });

  test(
    'an idle session with empty lists is authoritative and complete',
    () async {
      final snapshot = await hydrate(
        Server(
          active: {'data': <String, Object?>{}},
          inbox: const [],
          history: const [],
          permissions: const [],
          forms: const [],
        ),
      );
      expect(snapshot.execution!.value.kind.known, ExecutionKind.idle);
      expect(snapshot.execution!.value.lastOutcome, isNull);
      expect(snapshot.timeline!.values, isEmpty);
      expect(snapshot.timeline!.complete, isTrue);
      expect(snapshot.hasMoreHistory, isFalse);
      expect(snapshot.nextHistoryCursor, isNull);
      expect(snapshot.pending!.values, isEmpty);
      expect(snapshot.interactions!.values, isEmpty);
    },
  );

  test('any failed or rejected read fails the whole snapshot', () async {
    for (final (server, kind) in [
      (Server(failPath: 'inbox'), OpenCodeSessionReadFailure.notFound),
      (Server(failPath: 'form'), OpenCodeSessionReadFailure.notFound),
      (
        Server(
          active: {
            'data': {
              'ses_a': {'type': 'idle'},
            },
          },
        ),
        OpenCodeSessionReadFailure.incompatibleResponse,
      ),
      (
        Server(permissions: [permissionRow(session: 'ses_b')]),
        OpenCodeSessionReadFailure.incompatibleResponse,
      ),
      (
        Server(forms: [formRow(session: 'global')]),
        OpenCodeSessionReadFailure.incompatibleResponse,
      ),
      (
        Server(inbox: [inboxRow('msg_a', 'user'), inboxRow('msg_a', 'user')]),
        OpenCodeSessionReadFailure.incompatibleResponse,
      ),
      (
        Server(inbox: [inboxRow('msg_a', 'mystery')]),
        OpenCodeSessionReadFailure.incompatibleResponse,
      ),
      (
        Server(permissions: [permissionRow(), permissionRow()]),
        OpenCodeSessionReadFailure.incompatibleResponse,
      ),
    ]) {
      await expectLater(hydrate(server), throwsA(failure(kind)));
    }
    await expectLater(
      hydrate(Server(), limit: 2),
      throwsA(failure(OpenCodeSessionReadFailure.incompatibleResponse)),
    );
    final server = Server();
    await expectLater(
      hydrate(server, version: '2.0.21'),
      throwsA(failure(OpenCodeSessionReadFailure.invalidRequest)),
    );
    expect(server.paths, isEmpty);
  });

  test('hydration then live events never duplicate an identity', () async {
    final snapshot = await hydrate(Server());
    final store = SessionStore(maxSessions: 4)..open(historyRef);
    store.startHydration(
      historyRef,
      generation: 'gen-1',
      readStart: observedPosition(10),
    );
    final hydrated = store.applySnapshot(historyRef, snapshot);
    expect(hydrated.effects.whereType<Rehydrate>(), isEmpty);
    var state = hydrated.state;
    Map<String, Object?> inboxEvent(String phase, String inbox, int seq) => {
      'id': 'evt_$phase$inbox',
      'created': 1000,
      'type': 'session.inbox.$phase',
      'data': {'sessionID': 'ses_a', 'inboxID': inbox},
      'durable': {'aggregateID': 'ses_a', 'seq': seq, 'version': 1},
    };
    for (final (i, frame) in [
      inboxEvent('delivered', 'msg_z1', 20),
      inboxEvent('delivered', 'msg_q1', 21),
      inboxEvent('delivered', 'msg_h2', 22),
    ].indexed) {
      for (final event in projectOpenCodeEvent(
        frame,
        state,
        sourceVersion: '2.0.22',
        position: observedPosition(11 + i),
        receivedAt: DateTime.utc(2026, 10, 14),
      )) {
        state = store.apply(historyRef, event).state;
      }
    }
    final ids = [for (final item in state.timeline) item.id.value];
    expect(ids.toSet(), hasLength(ids.length));
    expect([for (final p in state.pending) messageOf(p.id)], ['msg_s1']);
    expect(
      state.timeline
          .whereType<UserInput>()
          .where((u) => u.delivery.known == DeliveryState.delivered)
          .map((u) => messageOf(u.id)),
      ['msg_z1', 'msg_q1'],
    );
  });

  test('the active map counts running children on an idle parent', () async {
    SessionRef child(String id) =>
        SessionRef(historyRef.host, historyRef.harness, id);
    final snapshot = await hydrate(
      Server(
        active: {
          'data': {
            'ses_child': {'type': 'running'},
            'ses_stranger': {'type': 'running'},
          },
        },
      ),
      children: [child('ses_child'), child('ses_done')],
    );
    expect(snapshot.execution!.value.kind.known, ExecutionKind.idle);
    final work = snapshot.work!;
    expect(work.complete, isTrue);
    expect(work.boundary.source!.nativeType, 'session.active');
    final item = work.values.single;
    expect(item.child, child('ses_child'));
    expect(item.parent, historyRef);
    expect(item.status.known, WorkStatus.running);
    expect(item.completionScope.known, CompletionScope.child);
    // Applied, the record survives the reducer's scope check.
    final store = SessionStore(maxSessions: 4)..open(historyRef);
    store.startHydration(
      historyRef,
      generation: 'gen-1',
      readStart: observedPosition(10),
    );
    final state = store.applySnapshot(historyRef, snapshot).state;
    expect(state.work.single.child, child('ses_child'));
    expect(state.execution!.kind.known, ExecutionKind.idle);
    // Without children, the work is an authoritative empty list.
    expect((await hydrate(Server())).work!.values, isEmpty);
  });

  test(
    'a rehydration replaces a live retry or pending resume with the active map',
    () async {
      const absent = {'data': <String, Object?>{}};
      for (final (frame, active, kind) in [
        (retryFrame(), null, ExecutionKind.running),
        (retryFrame(), absent, ExecutionKind.idle),
        (
          executionFrame('interrupted', reason: 'shutdown'),
          null,
          ExecutionKind.running,
        ),
        (
          executionFrame('interrupted', reason: 'shutdown'),
          absent,
          ExecutionKind.idle,
        ),
        // A missed end never leaves the session stuck running.
        (executionFrame('started'), absent, ExecutionKind.idle),
      ]) {
        final store = SessionStore(maxSessions: 4)..open(historyRef);
        store.startHydration(
          historyRef,
          generation: 'gen-1',
          readStart: observedPosition(10),
        );
        var state = store
            .applySnapshot(historyRef, await hydrate(Server()))
            .state;
        for (final event in projectOpenCodeEvent(
          frame,
          state,
          sourceVersion: '2.0.22',
          position: observedPosition(11),
          receivedAt: DateTime.utc(2026, 10, 14),
        )) {
          state = store.apply(historyRef, event).state;
        }
        expect(state.execution!.kind.known, isNot(kind));
        store.startHydration(
          historyRef,
          generation: 'gen-2',
          readStart: observedPosition(20),
        );
        final snapshot = await hydrate(
          active == null ? Server() : Server(active: active),
          generation: 'gen-2',
          readStart: 20,
        );
        final reduction = store.applySnapshot(historyRef, snapshot);
        expect(reduction.effects.whereType<Rehydrate>(), isEmpty);
        final execution = reduction.state.execution!;
        expect(execution.kind.known, kind, reason: '${frame['type']}');
        expect(execution.retryAt, isNull);
        expect(execution.error, isNull);
        // The newest history outcome survives either way.
        expect(
          execution.lastOutcome!.kind.known,
          ExecutionOutcomeKind.succeeded,
        );
      }
    },
  );

  test(
    'observed B: recorded reads hydrate, then the stream adds no duplicates',
    () async {
      final fixtures = OpenCodeFixtures();
      final capture =
          jsonDecode(
                File(
                  '${fixtures.root.path}/b/queue-steer-space-bunny.json',
                ).readAsStringSync(),
              )
              as Map<String, Object?>;
      final calls = (capture['calls']! as List).cast<Map<String, Object?>>();
      Object? body(int index) => calls[index]['response'];
      final session = (body(10)! as Map)['data']['id'] as String;
      final ref = refOf(session);
      // Captured reads: active (2), session (10), inbox (11) and the ascending
      // history (12), served newest first as the production query asks.
      final history = body(12)! as Map<String, Object?>;
      final transport = TestTransport((request, _) {
        final tail = Uri.parse(request.path).pathSegments.last;
        return response(switch (tail) {
          'active' => body(2),
          'inbox' => body(11),
          'message' => {
            ...history,
            'data': (history['data']! as List).reversed.toList(),
          },
          'permission' || 'form' => {'data': const <Object?>[]},
          _ => body(10),
        });
      });
      final reader = OpenCodeSessionReader(transport, harness: historyHarness);
      final snapshot = await reader.hydrateSession(
        ref,
        hydrationGeneration: 'gen-b',
        readStart: observedPosition(0),
        sourceVersion: '2.0.22',
        historyLimit: 200,
      );
      expect(snapshot.execution!.value.kind.known, ExecutionKind.running);
      final store = SessionStore(maxSessions: 2)..open(ref);
      store.startHydration(
        ref,
        generation: 'gen-b',
        readStart: observedPosition(0),
      );
      var state = store.applySnapshot(ref, snapshot).state;
      final frames = eventLists(capture['stream']).expand((e) => e).toList();
      for (var i = 0; i < frames.length; i++) {
        for (final event in projectOpenCodeEvent(
          frames[i],
          state,
          sourceVersion: '2.0.22',
          position: observedPosition(i + 1),
          receivedAt: DateTime.utc(2026, 10, 14),
        )) {
          state = store.apply(ref, event).state;
        }
      }
      final ids = [for (final item in state.timeline) item.id.value];
      expect(ids.toSet(), hasLength(ids.length));
      expect(state.pending, isEmpty);
      // 38 recorded frames over a four-item snapshot end with eight items.
      expect(
        (frames.length, snapshot.timeline!.values.length, ids.length),
        (38, 4, 8),
      );
    },
  );
}
