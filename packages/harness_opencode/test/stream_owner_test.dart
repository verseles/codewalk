import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:codewalk_net/codewalk_net.dart';
import 'package:harness_opencode/harness_opencode.dart';
import 'package:test/test.dart';

import 'execution_replay_test.dart' show refOf;
import 'history_test_data.dart';
import 'session_reader_test.dart' show TestTransport, response;
import 'support/fixture_replay.dart';

/// A scripted transport generation stream: the test decides what arrives.
final class ScriptedConnection implements RecoveringSseConnection {
  final _controller = StreamController<SseRecoveryUpdate>();
  final released = <int>[];
  var wakes = 0;
  @override
  int generation = 0;
  @override
  Stream<SseRecoveryUpdate> get updates => _controller.stream;
  @override
  void releaseGeneration(int generation) => released.add(generation);
  @override
  void wake() => wakes++;
  @override
  Future<void> close() => _controller.close();

  void connect(int next, {Object? first = const {'type': 'server.connected'}}) {
    generation = next;
    _controller.add(
      SseConnected(
        next,
        firstFrame: first == null ? null : SseFrame(data: jsonEncode(first)),
      ),
    );
  }

  void send(Iterable<Object?> frames) => _controller.add(
    SseBatch(generation, [
      for (final f in frames) SseFrame(data: f is String ? f : jsonEncode(f)),
    ]),
  );

  void drop({TransportFailure failure = TransportFailure.connection}) =>
      _controller.add(
        SseDisconnected(
          generation,
          TransportException(failure),
          terminal: false,
        ),
      );
}

/// Path-keyed reads; the test swaps bodies between generations.
final class Reads {
  Reads(this.session);
  final String session;
  Object? active = const {'data': <String, Object?>{}};
  Object? record;
  Object? inbox = const {'data': <Object?>[]};
  List<Object?> history = const [];
  Object? permissions = const {'data': <Object?>[]};
  Object? forms = const {'data': <Object?>[]};
  int? sessionStatus;
  final paths = <String>[];
  Completer<void>? gate;

  late final transport = TestTransport((request, _) async {
    paths.add(request.path);
    if (gate != null) await gate!.future;
    final tail = Uri.parse(request.path).pathSegments.last;
    if (tail == session && sessionStatus != null) {
      return response({'error': 'x'}, status: sessionStatus!);
    }
    return response(switch (tail) {
      'active' => active,
      'inbox' => inbox,
      'message' => {
        'data': history,
        'cursor': {'previous': null, 'next': null},
      },
      'permission' => permissions,
      'form' => forms,
      _ =>
        record ??
            {
              'data': {
                'id': session,
                'title': 'Session',
                'projectID': 'global',
                'time': {'created': 1, 'updated': 1},
              },
            },
    });
  });
}

final class Harness {
  Harness(String session) : ref = refOf(session), reads = Reads(session) {
    owner = OpenCodeStreamOwner(
      connection: connection,
      reader: OpenCodeSessionReader(reads.transport, harness: historyHarness),
      store: store,
      harness: historyHarness,
      sourceVersion: '2.0.22',
      now: () => DateTime.utc(2026, 10, 14),
      delay: (_) async {},
    )..start();
    owner.updates.listen(updates.add);
  }

  final SessionRef ref;
  final Reads reads;
  final connection = ScriptedConnection();
  final store = SessionStore(maxSessions: 8);
  late final OpenCodeStreamOwner owner;
  final updates = <OpenCodeStreamUpdate>[];

  SessionState get state => store.read(ref)!;

  Future<void> settle() async {
    for (var i = 0; i < 40; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<void> connect(int generation) async {
    connection.connect(generation);
    await settle();
  }

  Future<void> send(Iterable<Object?> frames) async {
    connection.send(frames);
    await settle();
  }

  List<String> get ids => [for (final i in state.timeline) i.id.value];

  void expectConsistent() {
    expect(ids.toSet(), hasLength(ids.length), reason: 'duplicate identity');
    expect(state.execution?.kind.known, isNot(ExecutionKind.running));
  }
}

Map<String, Object?> capture(String path) =>
    jsonDecode(File('${OpenCodeFixtures().root.path}/$path').readAsStringSync())
        as Map<String, Object?>;

List<Map<String, Object?>> events(Map<String, Object?> node, String key) =>
    ((node[key]! as Map)['events'] as List).cast<Map<String, Object?>>();

void main() {
  group('generation gate', () {
    test('hydrates before release, then applies frames in order', () async {
      final h = Harness('ses_a');
      h.owner.watch(h.ref);
      await h.connect(1);
      expect(h.reads.paths.map((p) => p.split('?').first), [
        'api/session/active',
        'api/session/ses_a',
        'api/session/ses_a/inbox',
        'api/session/ses_a/message',
        'api/session/ses_a/permission',
        'api/session/ses_a/form',
      ]);
      expect(h.connection.released, [1]);
      expect(h.state.connection.kind.known, ConnectionKind.live);
      await h.send([
        {
          'id': 'evt_s',
          'created': 1,
          'type': 'session.execution.started',
          'data': {'sessionID': 'ses_a'},
          'durable': {'aggregateID': 'ses_a', 'seq': 1, 'version': 1},
        },
      ]);
      expect(h.state.execution!.kind.known, ExecutionKind.running);
      final updated = h.updates.whereType<OpenCodeConnectionUpdated>();
      expect(updated.map((u) => u.kind), [
        ConnectionKind.hydrating,
        ConnectionKind.live,
      ]);
    });

    test('a connection frame other than server.connected is refused', () async {
      final h = Harness('ses_a');
      h.owner.watch(h.ref);
      h.connection.connect(1, first: {'type': 'session.renamed'});
      await h.settle();
      expect(h.connection.released, isEmpty);
      expect(h.reads.paths, isEmpty);
      final update = h.updates.whereType<OpenCodeConnectionUpdated>().single;
      expect(update.failure, OpenCodeStreamFailure.malformedControl);
    });

    test('a newer generation discards the older hydration', () async {
      final h = Harness('ses_a');
      h.owner.watch(h.ref);
      h.reads.gate = Completer();
      h.connection.connect(1);
      await h.settle();
      h.connection.connect(2);
      await h.settle();
      h.reads.gate!.complete();
      h.reads.gate = null;
      await h.settle();
      expect(h.connection.released, [2]);
      expect(h.state.hydrationGeneration, '2');
    });

    test(
      'a missing session is evicted; frames for others are ignored',
      () async {
        final h = Harness('ses_a');
        h.owner.watch(h.ref);
        h.reads.sessionStatus = 404;
        await h.connect(1);
        expect(h.updates.whereType<OpenCodeSessionEvicted>().single.ref, h.ref);
        expect(h.store.read(h.ref), isNull);
        expect(h.connection.released, [1]);
        await h.send([
          'not json',
          {
            'type': 'session.text.started',
            'data': {'sessionID': 'ses_b'},
          },
        ]);
        expect(h.store.length, 0);
      },
    );

    test(
      'a rejected frame triggers one bounded re-read, never a guess',
      () async {
        final h = Harness('ses_a');
        h.owner.watch(h.ref);
        await h.connect(1);
        final before = h.reads.paths.length;
        await h.send([
          {
            'type': 'session.text.started',
            'data': {'sessionID': 'ses_a'},
          },
        ]);
        expect(h.reads.paths.length - before, 6);
        for (var i = 0; i < 5; i++) {
          await h.send([
            {
              'type': 'session.text.started',
              'data': {'sessionID': 'ses_a'},
            },
          ]);
        }
        // Three repairs per generation, then the session is set aside.
        expect(h.reads.paths.length - before, 18);
        final aside = h.updates.whereType<OpenCodeConnectionUpdated>().last;
        expect(aside.failure, OpenCodeStreamFailure.hydrationExhausted);
        expect(aside.session, h.ref);
      },
    );

    test(
      'a session watched after release keeps its frames until hydrated',
      () async {
        final h = Harness('ses_a');
        await h.connect(1);
        h.reads.gate = Completer();
        h.owner.watch(h.ref);
        await h.settle();
        final enqueued = {
          'id': 'evt_q',
          'created': 1,
          'type': 'session.inbox.enqueued',
          'data': {
            'sessionID': 'ses_a',
            'inboxID': 'msg_q',
            'item': {
              'type': 'user',
              'payload': {'text': 'hello'},
              'delivery': 'steer',
            },
          },
          'durable': {'aggregateID': 'ses_a', 'seq': 1, 'version': 1},
        };
        await h.send([enqueued]);
        expect(h.state.timeline, isEmpty);
        h.reads.gate!.complete();
        h.reads.gate = null;
        await h.settle();
        expect(h.state.timeline.whereType<UserInput>(), hasLength(1));
        expect(h.state.pending, hasLength(1));
      },
    );
  });

  group('races', () {
    test(
      'a drop while hydrating releases nothing and never claims live',
      () async {
        final h = Harness('ses_a');
        h.owner.watch(h.ref);
        h.reads.gate = Completer();
        h.connection.connect(1);
        await h.settle();
        h.connection.drop();
        await h.settle();
        h.reads.gate!.complete();
        h.reads.gate = null;
        await h.settle();
        expect(h.connection.released, isEmpty);
        final kinds = [
          for (final u in h.updates.whereType<OpenCodeConnectionUpdated>())
            u.kind,
        ];
        expect(kinds, [ConnectionKind.hydrating, ConnectionKind.reconnecting]);
        expect(
          h.updates.whereType<OpenCodeConnectionUpdated>().where(
            (u) => u.failure != null,
          ),
          isEmpty,
        );
        await h.connect(2);
        expect(h.connection.released, [2]);
        expect(h.state.connection.kind.known, ConnectionKind.live);
      },
    );

    test('a session set aside for held-frame overflow stays aside', () async {
      final h = Harness('ses_a');
      await h.connect(1);
      h.reads.gate = Completer();
      // The default cap is 256 held frames; overflow it while hydrating.
      h.owner.watch(h.ref);
      await h.settle();
      await h.send([
        for (var i = 0; i < 257; i++)
          {
            'type': 'session.future.fact',
            'data': {'sessionID': 'ses_a'},
          },
      ]);
      final aside = h.updates.whereType<OpenCodeConnectionUpdated>().last;
      expect(aside.failure, OpenCodeStreamFailure.hydrationExhausted);
      h.reads.gate!.complete();
      h.reads.gate = null;
      await h.settle();
      expect(h.state.connection.kind.known, isNot(ConnectionKind.live));
      expect(h.state.diagnostics, isEmpty);
    });

    test('watching beyond the store capacity is refused', () async {
      final h = Harness('ses_a');
      for (var i = 0; i < 8; i++) {
        expect(h.owner.watch(refOf('ses_$i')), isTrue);
      }
      expect(h.owner.watch(refOf('ses_overflow')), isFalse);
      expect(h.owner.watch(refOf('ses_0')), isTrue);
      expect(h.store.length, 8);
      await h.connect(1);
      expect(h.connection.released, [1]);
    });

    test(
      'a session evicted from a shared store is re-read, not dropped',
      () async {
        final h = Harness('ses_a');
        h.owner.watch(h.ref);
        await h.connect(1);
        for (var i = 0; i < 8; i++) {
          h.store.open(refOf('ses_other_$i'));
        }
        expect(h.store.peek(h.ref), isNull);
        final before = h.reads.paths.length;
        await h.send([
          {
            'type': 'session.future.fact',
            'data': {'sessionID': 'ses_a'},
          },
        ]);
        expect(h.reads.paths.length - before, 6);
        expect(h.store.peek(h.ref), isNotNull);
        expect(h.state.connection.kind.known, ConnectionKind.live);
      },
    );

    test('a frame with an empty session is skipped', () async {
      final h = Harness('ses_a');
      h.owner.watch(h.ref);
      await h.connect(1);
      await h.send([
        {
          'type': 'session.future.fact',
          'data': {'sessionID': ''},
        },
        {
          'type': 'session.future.fact',
          'data': {'sessionID': 'ses_a'},
        },
      ]);
      expect(h.state.diagnostics, hasLength(1));
    });
  });

  group('done-when fixtures', () {
    test(
      'drop mid-text (capture B) recovers the completed turn once',
      () async {
        final b = capture('b/disconnect-reconnect.json');
        final calls = (b['calls']! as List).cast<Map<String, Object?>>();
        Object? body(int i) => calls[i]['response'];
        final session = ((body(0)! as Map)['data'] as Map)['id'] as String;
        final h = Harness(session);
        h.reads.record = body(2);
        h.owner.watch(h.ref);
        await h.connect(1);
        final partial = events(b, 'partialStream').skip(1).toList();
        expect(partial.last['type'], 'session.text.delta');
        await h.send(partial);
        expect(h.state.execution!.kind.known, ExecutionKind.running);
        expect(h.state.timeline.whereType<AssistantText>(), hasLength(1));

        h.connection.drop();
        await h.settle();
        expect(h.state.connection.kind.known, ConnectionKind.reconnecting);
        // Reads after completion: session, inbox and history (served newest
        // first, as hydration asks), plus an active map without the session.
        h.reads
          ..record = body(5)
          ..inbox = body(6)
          ..history = (((body(7)! as Map)['data'] as List).reversed.toList())
          ..active = body(12);
        await h.connect(2);
        await h.send(events(b, 'reconnectedStream').skip(1));

        h.expectConsistent();
        expect(h.state.execution!.kind.known, ExecutionKind.idle);
        expect(
          h.state.execution!.lastOutcome!.kind.known,
          ExecutionOutcomeKind.succeeded,
        );
        final text = h.state.timeline.whereType<AssistantText>().single;
        expect(text.text, isNotEmpty);
        expect(
          h.state.info!.title,
          (events(b, 'reconnectedStream').last['data']! as Map)['title'],
        );
        expect(h.connection.released, [1, 2]);
      },
    );

    test('drop mid-tool (capture B) leaves one tool and no running', () async {
      final b = capture('b/disconnect-reconnect.json');
      final calls = (b['calls']! as List).cast<Map<String, Object?>>();
      Object? body(int i) => calls[i]['response'];
      final session = ((body(0)! as Map)['data'] as Map)['id'] as String;
      final h = Harness(session);
      h.reads.record = body(2);
      h.owner.watch(h.ref);
      await h.connect(1);
      final partial = events(b, 'partialStream').skip(1).toList();
      final called = partial.indexWhere(
        (e) => e['type'] == 'session.tool.called',
      );
      await h.send(partial.take(called + 1));
      expect(h.state.timeline.whereType<ToolCall>(), hasLength(1));
      h.connection.drop();
      await h.settle();
      h.reads
        ..record = body(5)
        ..history = (((body(7)! as Map)['data'] as List).reversed.toList())
        ..active = body(12);
      await h.connect(2);
      h.expectConsistent();
      expect(h.state.timeline.whereType<ToolCall>(), hasLength(1));
    });

    test('drop during a pending approval keeps or settles it once', () async {
      final c = capture('c/native-interactions.json');
      final frames = (c['events'] as List).cast<Map<String, Object?>>();
      final asked = frames.firstWhere((e) => e['type'] == 'permission.asked');
      final data = asked['data']! as Map<String, Object?>;
      final session = data['sessionID']! as String;
      final h = Harness(session);
      h.owner.watch(h.ref);
      await h.connect(1);
      await h.send([asked]);
      expect(h.state.interactions, hasLength(1));
      h.connection.drop();
      await h.settle();
      // Still pending on the server: one request, same identity.
      h.reads.permissions = {
        'data': [data],
      };
      await h.connect(2);
      expect(h.state.interactions.single.id.value, data['id']);
      h.connection.drop();
      await h.settle();
      // Answered while disconnected: the authoritative list is empty.
      h.reads.permissions = const {'data': <Object?>[]};
      await h.connect(3);
      expect(h.state.interactions, isEmpty);
      h.expectConsistent();
    });

    test('drop during revert (capture D) converges on the server', () async {
      final d = capture('d/revert-file-effects.json');
      final frames = (d['events'] as List).cast<Map<String, Object?>>();
      final calls = (d['calls']! as List).cast<Map<String, Object?>>();
      final session = (d['summary']! as Map)['rootSessionID'] as String;
      Object? last(String suffix) => calls.lastWhere(
        (c) =>
            c['method'] == 'GET' &&
            (c['path']! as String).split('?').first.endsWith(suffix),
      )['response'];
      final h = Harness(session);
      h.owner.watch(h.ref);
      await h.connect(1);
      final staged = frames.indexWhere(
        (e) => e['type'] == 'session.revert.staged',
      );
      await h.send(frames.skip(1).take(staged));
      expect(h.state.revert!.kind.known, RevertKind.staged);
      final before = h.ids.length;
      expect(before, greaterThan(0));
      h.connection.drop();
      await h.settle();
      // Committed while disconnected: the final reads have no revert,
      // no history and no inbox.
      h.reads
        ..record = last(session)
        ..inbox = last('/inbox')
        ..history = ((last('/message')! as Map)['data'] as List).reversed
            .toList();
      await h.connect(2);
      h.expectConsistent();
      expect(h.state.revert!.kind.known, RevertKind.none);
      expect(h.state.timeline, isEmpty);
      expect(h.state.pending, isEmpty);
    });

    test('an overflow disconnect reconnects without stale running', () async {
      final h = Harness('ses_a');
      h.reads.active = {
        'data': {
          'ses_a': {'type': 'running'},
        },
      };
      h.owner.watch(h.ref);
      await h.connect(1);
      expect(h.state.execution!.kind.known, ExecutionKind.running);
      h.connection.drop(failure: TransportFailure.bufferOverflow);
      await h.settle();
      expect(
        h.updates.whereType<OpenCodeConnectionUpdated>().last.kind,
        ConnectionKind.reconnecting,
      );
      h.reads.active = const {'data': <String, Object?>{}};
      await h.connect(2);
      h.expectConsistent();
      expect(h.connection.released, [1, 2]);
      expect(h.state.connection.kind.known, ConnectionKind.live);
    });

    test('a restart with shutdown resumes idle, not running', () async {
      final c = capture('c/provider-form-dismiss.json');
      final frames = (c['events'] as List).cast<Map<String, Object?>>();
      final shutdown = frames.firstWhere(
        (e) =>
            e['type'] == 'session.execution.interrupted' &&
            (e['data']! as Map)['reason'] == 'shutdown',
      );
      final session = (shutdown['data']! as Map)['sessionID'] as String;
      final started = frames.lastWhere(
        (e) =>
            e['type'] == 'session.execution.started' &&
            (e['data']! as Map)['sessionID'] == session,
      );
      final h = Harness(session);
      h.owner.watch(h.ref);
      await h.connect(1);
      await h.send([started, shutdown]);
      expect(
        h.state.execution!.kind.known,
        ExecutionKind.interruptedPendingResume,
      );
      h.connection.drop();
      await h.settle();
      await h.connect(2);
      h.expectConsistent();
      expect(h.state.execution!.kind.known, ExecutionKind.idle);
    });
  });
}
