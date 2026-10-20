import 'package:codewalk_core/codewalk_core.dart';
import 'package:harness_opencode/harness_opencode.dart';
import 'package:harness_opencode/src/session_projection.dart';
import 'package:test/test.dart';

import 'history_test_data.dart';
import 'session_lifecycle_test_data.dart';
import 'text_reasoning_test_data.dart' show observedPosition;

Matcher failsWith(OpenCodeSessionLifecycleProjectionFailure failure) => throwsA(
  isA<OpenCodeSessionLifecycleProjectionException>()
      .having((e) => e.failure, 'failure', failure)
      .having(
        (e) => e.toString(),
        'toString',
        'OpenCodeSessionLifecycleProjectionException(${failure.name})',
      ),
);

SessionInfo infoOf(SessionEvent event) => (event as SessionInfoChanged).info;

SessionState withInfo(SessionInfo info) => reduce(
  SessionState(historyRef),
  SessionInfoChanged(
    meta: EventMeta(
      owner: SessionOwner(historyRef),
      position: observedPosition(0),
      receivedAt: DateTime.utc(2026, 10, 14),
      source: SourceProvenance(
        harness: historyRef.harnessRef,
        version: '2.0.22',
        nativeType: 'seed',
      ),
    ),
    info: info,
  ),
).state;

void main() {
  test('the session carries the project the server reported', () {
    final info = projectOpenCodeSession({
      'id': 'ses_a',
      'title': 'First title',
      'projectID': 'prj_a',
      'location': {'directory': '/workspace/project'},
      'time': {'created': 1000, 'updated': 1000},
    }, historyHarness).info;
    // The canonical directory is the project identity; the upstream project
    // id stays an annotation.
    expect(info.project?.canonicalDirectory, '/workspace/project');
    expect(info.project?.upstreamProjectId, 'prj_a');
    expect(info.project?.host, historyHarness.host);
  });

  test('the summary carries the endpoint unread marker', () {
    final summary = projectOpenCodeSession({
      'id': 'ses_a',
      'title': 'First title',
      'time': {'created': 1000, 'updated': 2000, 'idle': 3000},
    }, historyHarness);
    // The marker is on the summary, not on the info: the session's identity
    // does not change when the unread marker does.
    expect(summary.view?.idleAt.millisecondsSinceEpoch, 3000);
    expect(summary.view?.viewedAt, isNull);
    expect(summary.view?.unread, isTrue);
    expect(summary.info.metadata?.toJson(), isNot(contains('nativeIdle')));
  });

  test('a seen idle transition is not unread', () {
    final summary = projectOpenCodeSession({
      'id': 'ses_a',
      'title': 'First title',
      'time': {'created': 1000, 'updated': 2000, 'idle': 3000, 'viewed': 3000},
    }, historyHarness);
    expect(summary.view?.unread, isFalse);
    // An older view does not cover a newer idle transition.
    final older = projectOpenCodeSession({
      'id': 'ses_a',
      'title': 'First title',
      'time': {'created': 1000, 'updated': 2000, 'idle': 3000, 'viewed': 2500},
    }, historyHarness);
    expect(older.view?.unread, isTrue);
  });

  test('a record without an idle carries no marker', () {
    final summary = projectOpenCodeSession({
      'id': 'ses_a',
      'title': 'First title',
      'time': {'created': 1000, 'updated': 2000},
    }, historyHarness);
    expect(summary.view, isNull);
  });

  test('a session the server did not attribute keeps no project', () {
    final info = projectOpenCodeSession({
      'id': 'ses_a',
      'title': 'First title',
      'projectID': 'global',
      'time': {'created': 1000, 'updated': 1000},
    }, historyHarness).info;
    expect(info.project, isNull);
  });

  test('created projects the info the HTTP session record yields', () {
    final events = projectLifecycle(
      lifecycleFrame(
        'created',
        data: createdData(fields: {'parentID': 'ses_parent'}),
      ),
    );
    expect(events, hasLength(1));
    final info = infoOf(events.single);
    final http = projectOpenCodeSession({
      'id': 'ses_a',
      'title': 'First title',
      'parentID': 'ses_parent',
      'projectID': 'prj_a',
      'location': {'directory': '/workspace/project'},
      'time': {'created': 1000, 'updated': 1000},
    }, historyHarness).info;
    expect(infoJson(info), infoJson(http));
    expect(infoJson(info), {
      'ref': historyRef.storageKey,
      'title': 'First title',
      'ownership': 'unknown',
      'ownershipReason': 'nativeSessionMetadataHasNoOwnershipProof',
      'project': ProjectRef(
        historyHarness.host,
        '/workspace/project',
        upstreamProjectId: 'prj_a',
      ).storageKey,
      'parent': SessionRef(
        historyRef.host,
        historyRef.harness,
        'ses_parent',
      ).storageKey,
      'fork': null,
      'metadata': {
        'nativeProjectId': 'prj_a',
        'nativeDirectory': '/workspace/project',
      },
    });
    final source = events.single.meta.source;
    expect(source.nativeType, 'session.created');
    expect(source.nativeEventId, 'evt_lifecycle');
    expect(source.aggregateId, 'ses_a');
    expect(source.aggregateSeq, BigInt.zero);
    expect(source.durability.known, Durability.durable);
    expect(source.extra!.value, {
      'nativeCreated': 1000,
      'nativeDurableVersion': 1,
    });
    final reduced = reduce(SessionState(historyRef), events.single);
    expect(reduced.effects.every((e) => e is Notify), isTrue);
    expect(reduced.state.info!.title, 'First title');
  });

  test('an absent title is empty, like the HTTP record', () {
    final info = infoOf(
      projectLifecycle(
        lifecycleFrame('created', data: createdData(withTitle: false)),
      ).single,
    );
    expect(info.title, '');
    expect(info.lineage.parent, isNull);
    final minimal = infoOf(
      projectLifecycle(
        lifecycleFrame(
          'created',
          data: {
            'projectID': 'global',
            'location': {'directory': '/w'},
            'slug': 's',
            'version': '2.0.22',
            'title': '',
          },
        ),
      ).single,
    );
    expect(minimal.title, '');
    expect(minimal.metadata!.value, {
      'nativeProjectId': 'global',
      'nativeDirectory': '/w',
    });
  });

  test('renamed replaces only the title of resident info', () {
    final resident = SessionInfo(
      ref: historyRef,
      title: 'Old',
      ownership: const OwnershipInfo.unknown(reason: 'seeded'),
      project: ProjectRef(historyRef.host, '/workspace/project'),
      lineage: SessionLineage(
        parent: SessionRef(historyRef.host, historyRef.harness, 'ses_p'),
        fork: ForkLineage(
          SessionRef(historyRef.host, historyRef.harness, 'ses_f'),
        ),
      ),
      metadata: CanonicalValue({'nativeProjectId': 'prj_a'}),
    );
    final state = withInfo(resident);
    final events = projectLifecycle(
      lifecycleFrame('renamed', data: {'title': 'V2-008 Olá 🚀'}, seq: 3),
      current: state,
    );
    expect(events, hasLength(1));
    final info = infoOf(events.single);
    expect(infoJson(info), {...infoJson(resident), 'title': 'V2-008 Olá 🚀'});
    expect(info.project, same(resident.project));
    expect(info.lineage, same(resident.lineage));
    expect(info.ownership, same(resident.ownership));
    final after = reduce(state, events.single).state;
    expect(after.info!.title, 'V2-008 Olá 🚀');
    expect(
      infoOf(
        projectLifecycle(
          lifecycleFrame('renamed', data: {'title': ''}),
          current: state,
        ).single,
      ).title,
      '',
    );
  });

  test('renamed without resident info asks for a fresh read', () {
    final events = projectLifecycle(lifecycleFrame('renamed'));
    expect(events, hasLength(1));
    expect((events.single as ResyncRequired).reason, 'sessionInfoUnproven');
    final reduced = reduce(SessionState(historyRef), events.single);
    expect(
      reduced.effects.whereType<Rehydrate>().single.reason,
      'sessionInfoUnproven',
    );
    expect(reduced.state.info, isNull);
  });

  test('deleted asks for a fresh read without touching resident state', () {
    final state = withInfo(
      infoOf(projectLifecycle(lifecycleFrame('created')).single),
    );
    final events = projectLifecycle(
      lifecycleFrame('deleted', seq: 9),
      current: state,
    );
    expect(events, hasLength(1));
    expect((events.single as ResyncRequired).reason, 'sessionDeleted');
    expect(events.single.meta.source.extra!.value, {
      'nativeCreated': 1000,
      'nativeDurableVersion': 2,
    });
    final reduced = reduce(state, events.single);
    expect(
      reduced.effects.whereType<Rehydrate>().single.reason,
      'sessionDeleted',
    );
    expect(reduced.state.info!.title, 'First title');
  });

  test('other sessions, children and unrelated types project nothing', () {
    expect(
      projectLifecycle(
        lifecycleFrame(
          'created',
          session: 'ses_child',
          data: createdData(fields: {'parentID': 'ses_a'}),
        ),
      ),
      isEmpty,
    );
    expect(
      projectLifecycle(lifecycleFrame('deleted', session: 'ses_b')),
      isEmpty,
    );
    expect(
      projectLifecycle(
        lifecycleFrame('renamed', session: 'ses_b'),
        version: 'x',
      ),
      isEmpty,
    );
    for (final type in [
      'session.forked',
      'session.instructions.updated',
      'session.revert.cleared',
      'server.connected',
    ]) {
      expect(
        projectLifecycle({...lifecycleFrame('deleted'), 'type': type}),
        isEmpty,
      );
    }
  });

  test('private fields are validated and never copied', () {
    for (final frame in [
      lifecycleFrame('created'),
      lifecycleFrame('renamed'),
      lifecycleFrame('deleted'),
    ]) {
      for (final event in projectLifecycle(
        frame,
        current: withInfo(
          infoOf(projectLifecycle(lifecycleFrame('created')).single),
        ),
      )) {
        final manifest = lifecycleManifest(event);
        expect(manifest, isNot(contains('fake-private')), reason: manifest);
      }
    }
  });

  test('malformed frames fail with finite categories', () {
    Map<String, Object?> edit(
      Map<String, Object?> frame,
      void Function(Map<String, Object?> data, Map<String, Object?> durable)
      change,
    ) {
      final data = Map<String, Object?>.of(
        frame['data']! as Map<String, Object?>,
      );
      final durable = Map<String, Object?>.of(
        frame['durable']! as Map<String, Object?>,
      );
      change(data, durable);
      return {...frame, 'data': data, 'durable': durable};
    }

    Map<String, Object?> created(Map<String, Object?> fields) =>
        lifecycleFrame('created', data: createdData(fields: fields));
    Map<String, Object?> without(String key) =>
        lifecycleFrame('created', data: createdData()..remove(key));
    const m = OpenCodeSessionLifecycleProjectionFailure.malformed;
    const v = OpenCodeSessionLifecycleProjectionFailure.unsupportedVersion;
    const l = OpenCodeSessionLifecycleProjectionFailure.limitExceeded;
    final deleted = lifecycleFrame('deleted');
    for (final (input, failure)
        in <(Object?, OpenCodeSessionLifecycleProjectionFailure)>[
          (null, m),
          ({'type': 7}, m),
          ({'type': 'session.deleted'}, m),
          ({...deleted, 'id': 'msg_x'}, m),
          ({...deleted, 'created': null}, m),
          ({...deleted, 'created': double.nan}, m),
          ({...deleted, 'created': -1}, m),
          (Map<String, Object?>.of(deleted)..remove('durable'), m),
          (edit(deleted, (d, du) => d['sessionID'] = 'x_a'), m),
          (edit(deleted, (d, du) => du['aggregateID'] = 'ses_b'), m),
          (edit(deleted, (d, du) => du['seq'] = -1), m),
          (edit(deleted, (d, du) => du['seq'] = 1.5), m),
          (edit(deleted, (d, du) => du['version'] = 1), v),
          (lifecycleFrame('created', version: 2), v),
          (lifecycleFrame('renamed', version: 2), v),
          (lifecycleFrame('renamed', data: const {}), m),
          (lifecycleFrame('renamed', data: {'title': null}), m),
          (created({'title': null}), m),
          (created({'title': 3}), m),
          (created({'parentID': 'x_p'}), m),
          (created({'projectID': ''}), m),
          (created({'location': '/w'}), m),
          (created({'location': <String, Object?>{}}), m),
          (created({'subpath': null}), m),
          (created({'agent': 3}), m),
          (
            created({
              'model': {'id': 'a'},
            }),
            m,
          ),
          (created({'metadata': 'x'}), m),
          (created({'permissions': 'x'}), m),
          (without('slug'), m),
          (without('version'), m),
          (without('projectID'), m),
          (created({'title': 'a\ud800'}), m),
          (created({'projectID': 'p' * 4097}), l),
          (created({'title': 't' * (256 * 1024 + 1)}), l),
        ]) {
      expect(
        () => projectLifecycle(input),
        failsWith(failure),
        reason: '$input'.substring(0, 80.clamp(0, '$input'.length)),
      );
    }
    expect(() => projectLifecycle(deleted, version: '2.0.21'), failsWith(v));
    expect(
      () => projectLifecycle(deleted, version: '2.1.0-beta.1'),
      failsWith(v),
    );
    expect(projectLifecycle(deleted, version: '2.0.22+build.1'), hasLength(1));
    expect(
      infoOf(
        projectLifecycle(created({'title': 't' * (256 * 1024)})).single,
      ).title,
      hasLength(256 * 1024),
    );
  });
}
