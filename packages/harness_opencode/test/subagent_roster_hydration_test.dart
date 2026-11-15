import 'dart:async';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:codewalk_net/codewalk_net.dart';
import 'package:harness_opencode/harness_opencode.dart';
import 'package:test/test.dart';

import 'history_test_data.dart';
import 'session_hydration_test.dart' show formRow;
import 'session_reader_test.dart' show TestTransport, failure, response;
import 'text_reasoning_test_data.dart' show observedPosition;

Map<String, Object?> _record(
  String id, {
  String? parent,
  String? outcome,
  bool archived = false,
}) => {
  'id': id,
  'parentID': ?parent,
  'title': 'Title $id',
  'projectID': 'prj_a',
  'outcome': ?outcome,
  'time': {'created': 1, 'updated': 2, if (archived) 'archived': 3},
};

class _Roster {
  final rows = <Map<String, Object?>>[
    _record('ses_done', parent: 'ses_a', outcome: 'succeeded', archived: true),
    _record('ses_failed', parent: 'ses_a', outcome: 'failed'),
    _record('ses_cancelled', parent: 'ses_a', outcome: 'interrupted'),
    _record('ses_unknown', parent: 'ses_a'),
  ];
  final paths = <String>[];
  Set<String> active = {};
  bool formFails = false;
  final failures = <(String, String), int>{};
  final pending = <(String, String), List<Object?>>{};
  Completer<void>? childGate;
  final fourStarted = Completer<void>();
  int inFlight = 0;
  int peak = 0;

  late final reader = OpenCodeSessionReader(
    TestTransport((request, _) async {
      paths.add(request.path);
      final uri = Uri.parse(request.path);
      final segments = uri.pathSegments;
      final tail = segments.last;
      if ((tail == 'permission' || tail == 'form') && segments[2] != 'ses_a') {
        if (childGate case final gate?) {
          inFlight++;
          if (inFlight > peak) peak = inFlight;
          if (inFlight == 4 && !fourStarted.isCompleted) fourStarted.complete();
          await gate.future;
          inFlight--;
        }
      }
      final key = (segments.length > 2 ? segments[2] : '', tail);
      if (failures[key] case final status?) {
        return response({'error': 'unavailable'}, status: status);
      }
      if (pending[key] case final rows?) return response({'data': rows});
      if (uri.queryParameters.containsKey('parentID')) {
        return response({'data': rows});
      }
      if (tail == 'active') {
        return response({
          'data': {
            for (final id in active) id: {'type': 'running'},
          },
        });
      }
      if (segments.length == 3 && segments[1] == 'session') {
        final row = tail == 'ses_a'
            ? _record('ses_a')
            : rows.where((r) => r['id'] == tail).firstOrNull;
        return row == null
            ? response({'error': 'not found'}, status: 404)
            : response({'data': row});
      }
      if (tail == 'message') {
        return response({
          'data': <Object?>[],
          'cursor': {'previous': null, 'next': null},
        });
      }
      if (tail == 'form' && segments[2] == 'ses_done') {
        return formFails
            ? response({'error': 'unavailable'}, status: 500)
            : response({
                'data': [formRow(session: 'ses_done')],
              });
      }
      return response({'data': <Object?>[]});
    }),
    harness: historyHarness,
  );

  Future<SessionSnapshot> hydrate({
    List<SessionRef> extra = const [],
    List<InteractionRequest> resident = const [],
    RequestCancellation? cancellation,
  }) async {
    final children = await reader.listChildSummaries(historyRef);
    var tick = 0;
    return reader.hydrateSession(
      historyRef,
      hydrationGeneration: 'roster',
      readStart: observedPosition(1),
      sourceVersion: '2.0.22',
      children: [...children.map((s) => s.info.ref), ...extra],
      childSummaries: children,
      residentInteractions: resident,
      cancellation: cancellation,
      now: () => DateTime.utc(2026, 11, 14, 0, 0, tick++),
    );
  }
}

void main() {
  test(
    'history keeps titles and honest outcomes, including archived children',
    () async {
      final rig = _Roster();
      final snapshot = await rig.hydrate();
      final work = snapshot.work!.values;
      expect(work.map((w) => w.status.known), [
        WorkStatus.completed,
        WorkStatus.failed,
        WorkStatus.cancelled,
        WorkStatus.unknown,
      ]);
      expect(work.first.title, 'Title ses_done');
      expect(work.every((w) => w.parent == historyRef), isTrue);
      final query = Uri.parse(rig.paths.first).queryParameters;
      expect(query['parentID'], 'ses_a');
      expect(query.containsKey('archived'), isFalse);
      final request = snapshot.interactions!.values.single;
      expect(
        request.owner,
        SessionOwner(
          SessionRef(historyRef.host, historyRef.harness, 'ses_done'),
          origin: historyRef,
        ),
      );
      expect(request.kind.known, InteractionKind.form);
      expect(request.requiresInput, isTrue);
      expect(request.automaticChoice, isNull);
    },
  );

  test('new active evidence overrides an older failure', () async {
    final rig = _Roster()..active = {'ses_failed'};
    final work = (await rig.hydrate()).work!.values;
    expect(
      work.singleWhere((w) => w.child!.nativeId == 'ses_failed').status.known,
      WorkStatus.running,
    );
  });

  test(
    'a child read failure preserves resident interactions; deleted child is absent',
    () async {
      final rig = _Roster()..formFails = true;
      final missing = SessionRef(
        historyRef.host,
        historyRef.harness,
        'ses_deleted',
      );
      final snapshot = await rig.hydrate(extra: [missing]);
      expect(snapshot.interactions!.complete, isTrue);
      expect(snapshot.work!.values.any((w) => w.child == missing), isFalse);
      expect(snapshot.work!.values, hasLength(4));
    },
  );

  for (final kind in [InteractionKind.permission, InteractionKind.form]) {
    test('partial $kind failure retains only that child endpoint', () async {
      final rig = _Roster();
      final child = SessionRef(historyRef.host, historyRef.harness, 'ses_done');
      final sibling = SessionRef(
        historyRef.host,
        historyRef.harness,
        'ses_failed',
      );
      final gone = SessionRef(
        historyRef.host,
        historyRef.harness,
        'ses_deleted',
      );
      final endpoint = kind == InteractionKind.form ? 'form' : 'permission';
      rig.failures[('ses_done', endpoint)] = 500;
      rig.pending[('ses_done', 'form')] = [];
      InteractionRequest request(SessionRef owner, InteractionKind kind) =>
          InteractionRequest(
            id: InteractionId('${owner.nativeId}-${kind.name}'),
            owner: SessionOwner(
              owner,
              origin: owner == historyRef ? null : historyRef,
            ),
            kind: OpenValue.known(kind),
            title: 'Pending',
            requiresInput: true,
          );
      final keep = request(child, kind);
      final resident = [
        request(historyRef, kind),
        request(sibling, kind),
        request(gone, kind),
        request(
          child,
          kind == InteractionKind.form
              ? InteractionKind.permission
              : InteractionKind.form,
        ),
        keep,
      ];
      final snapshot = await rig.hydrate(extra: [gone], resident: resident);
      expect(snapshot.interactions!.complete, isTrue);
      expect(snapshot.interactions!.values, [keep]);
      final store = SessionStore(maxSessions: 2)..open(historyRef);
      EventMeta meta(int seq) => EventMeta(
        owner: SessionOwner(historyRef),
        position: observedPosition(seq),
        receivedAt: DateTime.utc(2026, 11, 14),
        source: SourceProvenance(
          harness: historyHarness,
          version: '2.0.22',
          nativeType: 'test',
        ),
      );
      for (final old in resident) {
        store.apply(historyRef, InteractionOpened(meta: meta(0), request: old));
      }
      store.startHydration(
        historyRef,
        generation: 'roster',
        readStart: observedPosition(1),
      );
      expect(store.applySnapshot(historyRef, snapshot).state.interactions, [
        keep,
      ]);
      store.apply(
        historyRef,
        InteractionResolved(
          meta: meta(2),
          resolution: InteractionResolution(
            id: keep.id,
            owner: keep.owner,
            kind: const OpenValue.known(InteractionResolutionKind.elsewhere),
          ),
        ),
      );
      expect(
        store.applySnapshot(historyRef, snapshot).state.interactions,
        isEmpty,
        reason: 'a cached failed read cannot resurrect a newer resolution',
      );
    });
  }

  test('child reads run with four workers and stable output order', () async {
    final rig = _Roster()..childGate = Completer<void>();
    for (final row in rig.rows) {
      final id = row['id']! as String;
      rig.pending[(id, 'form')] = [formRow(session: id)];
    }
    final read = rig.hydrate();
    await rig.fourStarted.future.timeout(const Duration(seconds: 2));
    expect(rig.peak, 4);
    rig.childGate!.complete();
    final snapshot = await read;
    expect(rig.peak, 4);
    expect(
      snapshot.interactions!.values.map(
        (request) => (request.owner as SessionOwner).session.nativeId,
      ),
      rig.rows.map((row) => row['id']),
    );
  });

  test(
    'cancelling concurrent child reads aborts the entire hydration',
    () async {
      final rig = _Roster()..childGate = Completer<void>();
      final cancellation = RequestCancellation();
      final read = rig.hydrate(cancellation: cancellation);
      final result = expectLater(
        read,
        throwsA(failure(OpenCodeSessionReadFailure.cancelled)),
      );
      await rig.fourStarted.future.timeout(const Duration(seconds: 2));
      cancellation.cancel();
      await result;
      rig.childGate!.complete();
    },
  );
}
