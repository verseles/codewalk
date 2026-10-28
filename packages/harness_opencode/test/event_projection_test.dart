import 'dart:convert';
import 'dart:io';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:harness_opencode/harness_opencode.dart';
import 'package:test/test.dart';

import 'execution_replay_test.dart' show eventLists, refOf;
import 'history_test_data.dart';
import 'support/fixture_replay.dart';
import 'text_reasoning_test_data.dart' show observedPosition;

typedef Producer =
    Object? Function(
      Object? value,
      SessionState current, {
      required String sourceVersion,
      required StreamPosition position,
      required DateTime receivedAt,
    });

const producers = <String, Producer>{
  'text': projectOpenCodeTextReasoningEvent,
  'tool': projectOpenCodeToolEvent,
  'execution': projectOpenCodeExecutionEvent,
  'retry': projectOpenCodeRetryEvent,
  'inbox': projectOpenCodeInboxEvent,
  'step': projectOpenCodeStepUsageEvent,
  'interaction': projectOpenCodeInteractionEvent,
  'revert': projectOpenCodeRevertEvent,
  'lifecycle': projectOpenCodeSessionLifecycleEvent,
  'notice': projectOpenCodeNoticeEvent,
  'compaction': projectOpenCodeCompactionEvent,
};

const owned = {
  'session.text.started': 'text',
  'session.text.delta': 'text',
  'session.text.ended': 'text',
  'session.reasoning.started': 'text',
  'session.reasoning.delta': 'text',
  'session.reasoning.ended': 'text',
  'session.tool.input.started': 'tool',
  'session.tool.input.delta': 'tool',
  'session.tool.input.ended': 'tool',
  'session.tool.called': 'tool',
  'session.tool.progress': 'tool',
  'session.tool.success': 'tool',
  'session.tool.failed': 'tool',
  'session.execution.started': 'execution',
  'session.execution.succeeded': 'execution',
  'session.execution.failed': 'execution',
  'session.execution.interrupted': 'execution',
  'session.retry.scheduled': 'retry',
  'session.inbox.enqueued': 'inbox',
  'session.inbox.delivered': 'inbox',
  'session.inbox.cancelled': 'inbox',
  'session.inbox.delivery.changed': 'inbox',
  'session.step.started': 'step',
  'session.step.streamed': 'step',
  'session.step.ended': 'step',
  'session.step.failed': 'step',
  'session.usage.updated': 'step',
  'permission.asked': 'interaction',
  'permission.replied': 'interaction',
  'form.created': 'interaction',
  'form.replied': 'interaction',
  'form.cancelled': 'interaction',
  'session.revert.staged': 'revert',
  'session.revert.cleared': 'revert',
  'session.revert.committed': 'revert',
  'session.created': 'lifecycle',
  'session.renamed': 'lifecycle',
  'session.deleted': 'lifecycle',
  'session.instructions.updated': 'notice',
  'session.synthetic': 'notice',
  'session.compaction.started': 'compaction',
  'session.compaction.ended': 'compaction',
  'session.compaction.failed': 'compaction',
};

List<SessionEvent> project(
  Object? frame, {
  SessionState? current,
  int seq = 1,
  String version = '2.0.22',
}) => projectOpenCodeEvent(
  frame,
  current ?? SessionState(historyRef),
  sourceVersion: version,
  position: observedPosition(seq),
  receivedAt: DateTime.utc(2026, 10, 14),
);

Map<String, Object?> frame(
  String type, {
  String session = 'ses_a',
  Map<String, Object?> data = const {},
}) => {
  'id': 'evt_unknown',
  'created': 1000,
  'type': type,
  'location': {'directory': '/fake-private-location'},
  'data': {'sessionID': session, ...data},
  'durable': {'aggregateID': session, 'seq': 1, 'version': 1},
};

Matcher failsWith(OpenCodeEventProjectionFailure failure) => throwsA(
  isA<OpenCodeEventProjectionException>()
      .having((e) => e.failure, 'failure', failure)
      .having(
        (e) => e.toString(),
        'toString',
        'OpenCodeEventProjectionException(${failure.name})',
      ),
);

void main() {
  test('every owned type is routed to exactly its producer', () {
    final state = SessionState(historyRef);
    for (final MapEntry(key: type, value: owner) in owned.entries) {
      // A frame without data makes only the owning producer fail.
      final probe = {'id': 'evt_x', 'type': type};
      final failing = [
        for (final MapEntry(:key, value: producer) in producers.entries)
          if (_throws(
            () => producer(
              probe,
              state,
              sourceVersion: '2.0.22',
              position: observedPosition(1),
              receivedAt: DateTime.utc(2026, 10, 14),
            ),
          ))
            key,
      ];
      expect(failing, [owner], reason: type);
      expect(
        () => project(probe),
        throwsA(isNot(isA<OpenCodeEventProjectionException>())),
        reason: type,
      );
    }
  });

  test('unowned frames of other sessions or without one are no-ops', () {
    for (final input in [
      {'id': 'evt_c', 'type': 'server.connected', 'data': <String, Object?>{}},
      {
        'id': 'evt_p',
        'type': 'project.updated',
        'data': {'id': 'prj'},
      },
      frame('session.retry.scheduled', session: 'ses_b'),
      frame('session.future.fact', session: 'ses_b'),
      {'type': 'session.moved'},
    ]) {
      expect(project(input, version: 'x'), isEmpty, reason: '$input');
    }
  });

  test('plugin, UI and content-delta frames never become diagnostics', () {
    for (final type in [
      'rpc.plugin.call',
      'tui.prompt.append',
      'tui.session.select',
      'session.compaction.delta',
      'session.future.delta',
    ]) {
      expect(
        project(frame(type, data: {'text': 'fake-private-text'})),
        isEmpty,
        reason: type,
      );
    }
  });

  test('unprojected and unrecognized session frames are explicit unknowns', () {
    for (final (type, disposition) in [
      // Execution truth never comes from the legacy status pair.
      ('session.status', 'unprojected'),
      ('session.idle', 'unprojected'),
      ('session.moved', 'unprojected'),
      ('session.skill.activated', 'unprojected'),
      ('session.future.fact', 'unrecognized'),
    ]) {
      final events = project(
        frame(
          type,
          data: {
            'agent': 'fake-private-agent',
            'error': {'message': 'fake-private-error'},
            'path': '/fake-private-path',
          },
        ),
      );
      final event = events.single as UnknownEvent;
      expect(event.rawType, type);
      expect(event.raw.value, {'disposition': disposition});
      expect(event.meta.owner, isA<SessionOwner>());
      expect(event.meta.source.nativeType, type);
      expect(event.meta.source.nativeEventId, 'evt_unknown');
      expect(
        jsonEncode({
          'raw': event.raw.value,
          'extra': event.meta.source.extra?.value,
        }),
        isNot(contains('fake-private')),
      );
      final reduced = reduce(SessionState(historyRef), event);
      expect(reduced.effects.every((e) => e is Notify), isTrue);
      expect(reduced.state.diagnostics.single.rawType, type);
    }
    final noId = project({...frame('session.future.fact'), 'id': 7});
    expect(noId.single.meta.source.nativeEventId, isNull);
  });

  test('diagnostics stay bounded under a burst of unknowns', () {
    var state = SessionState(historyRef);
    for (var i = 0; i < 33; i++) {
      final event = project(
        {...frame('session.future.fact'), 'id': 'evt_$i'},
        current: state,
        seq: i + 1,
      ).single;
      state = reduce(state, event).state;
    }
    expect(state.diagnostics, hasLength(32));
    expect(state.diagnostics.first.meta.source.nativeEventId, 'evt_1');
  });

  test('envelope failures are finite', () {
    const m = OpenCodeEventProjectionFailure.malformed;
    for (final input in [
      null,
      'x',
      <String, Object?>{},
      {'type': 7},
      {'type': ''},
    ]) {
      expect(() => project(input), failsWith(m), reason: '$input');
    }
    expect(
      () => project(frame('s' * 4097)),
      failsWith(OpenCodeEventProjectionFailure.limitExceeded),
    );
    expect(
      () => project(frame('session.future.fact'), version: '2.0.21'),
      failsWith(OpenCodeEventProjectionFailure.unsupportedVersion),
    );
    expect(
      project(frame('session.future.fact'), version: '2.0.22+build.1'),
      hasLength(1),
    );
  });

  test('observed captures: every frame is routed or a documented no-op', () {
    final fixtures = OpenCodeFixtures();
    final files =
        fixtures.root
            .listSync(recursive: true)
            .whereType<File>()
            .where(
              (f) =>
                  f.path.endsWith('.json') &&
                  !f.path.contains('/web-configured-origin/'),
            )
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    final categories = <String, int>{};
    for (final file in files) {
      for (final events in eventLists(jsonDecode(file.readAsStringSync()))) {
        final states = <String, SessionState>{};
        for (var i = 0; i < events.length; i++) {
          final input = events[i];
          final type = input['type']! as String;
          final data = input['data'];
          final sessionField = data is Map<String, Object?>
              ? (data['sessionID'] ??
                    (data['form'] as Map<String, Object?>?)?['sessionID'])
              : null;
          final session = sessionField is String && sessionField != 'global'
              ? sessionField
              : 'ses_unscoped';
          final state = states[session] ?? SessionState(refOf(session));
          final position = observedPosition(i + 1);
          final routed = projectOpenCodeEvent(
            input,
            state,
            sourceVersion: '2.0.22',
            position: position,
            receivedAt: DateTime.utc(2026, 10, 14),
          );
          final owner = owned[type];
          final String category;
          if (owner == null) {
            expect(routed, isEmpty, reason: type);
            category = 'noop:$type';
          } else {
            final direct = producers[owner]!(
              input,
              state,
              sourceVersion: '2.0.22',
              position: position,
              receivedAt: DateTime.utc(2026, 10, 14),
            );
            final expected = switch (direct) {
              null => const <SessionEvent>[],
              final SessionEvent event => [event],
              final List<SessionEvent> list => list,
              _ => fail('Unexpected producer result.'),
            };
            expect(
              routed.map((e) => e.runtimeType),
              expected.map((e) => e.runtimeType),
              reason: type,
            );
            category = routed.isEmpty ? 'routed-empty' : 'routed-events';
          }
          categories[category] = (categories[category] ?? 0) + 1;
          var next = state;
          for (final event in routed) {
            next = reduce(next, event).state;
          }
          states[session] = next;
        }
      }
    }
    // 1233 observed frames include both V2-071G success captures and the negative.
    // Unowned types are session-free catalog updates and intentionally
    // unrendered compaction deltas; no tracked frame becomes a diagnostic.
    // Every step start names the running
    // step and every step end clears it, so failed steps without usage still
    // emit; their error reaches the turn's outcome. The three D subagent
    // progress frames that name their child session now upsert it.
    expect(categories, {
      'routed-events': 935,
      'routed-empty': 142,
      'noop:server.connected': 28,
      'noop:worktree.resolved': 2,
      'noop:project.updated': 2,
      'noop:integration.updated': 2,
      'noop:provider.updated': 2,
      'noop:model.updated': 2,
      'noop:vcs.branch.updated': 2,
      'noop:agent.updated': 2,
      'noop:command.updated': 2,
      'noop:skill.updated': 2,
      'noop:websearch.updated': 2,
      'noop:reference.updated': 2,
      'noop:plugin.updated': 2,
      'noop:session.compaction.delta': 104,
    });
  });

  group('projectOpenCodeSessionPermissions (V2-047B3b)', () {
    final ref = SessionRef(
      const HostId('h'),
      const HarnessInstanceId('h'),
      'ses_target',
    );

    test(
      'projects valid session.permissions frame into OpenCodeSessionRules',
      () {
        final frame = {
          'id': 'evt_perm',
          'type': 'session.permissions',
          'data': {
            'sessionID': 'ses_target',
            'permissions': [
              {'action': 'read', 'resource': 'src/a.txt', 'effect': 'allow'},
              {'action': '*', 'resource': '*', 'effect': 'allow'},
            ],
          },
        };
        final rules = projectOpenCodeSessionPermissions(
          frame,
          ref,
          sourceVersion: '2.0.22',
        );
        expect(rules.recognized, isTrue);
        expect(rules.rules, hasLength(2));
        expect(rules.endsWithWildcardAllow, isTrue);
      },
    );

    test('projects empty permissions list or null into empty rules', () {
      final frame = {
        'id': 'evt_perm',
        'type': 'session.permissions',
        'data': {'sessionID': 'ses_target', 'permissions': null},
      };
      final rules = projectOpenCodeSessionPermissions(
        frame,
        ref,
        sourceVersion: '2.0.22',
      );
      expect(rules.recognized, isTrue);
      expect(rules.rules, isEmpty);
    });

    test('throws on malformed or invalid session.permissions frame', () {
      for (final bad in [
        'not a map',
        {'type': 'wrong.type'},
        {'type': 'session.permissions', 'data': 'not a map'},
        {
          'type': 'session.permissions',
          'data': {'sessionID': 'ses_other', 'permissions': []},
        },
        {
          'type': 'session.permissions',
          'data': {'sessionID': 'not_valid_id', 'permissions': []},
        },
        {
          'type': 'session.permissions',
          'data': {'sessionID': 'ses_target', 'permissions': 'not a list'},
        },
      ]) {
        expect(
          () => projectOpenCodeSessionPermissions(
            bad,
            ref,
            sourceVersion: '2.0.22',
          ),
          throwsA(isA<OpenCodeEventProjectionException>()),
        );
      }
    });

    test('returns unrecognized rules when list has unmodeled rules', () {
      final frame = {
        'id': 'evt_perm',
        'type': 'session.permissions',
        'data': {
          'sessionID': 'ses_target',
          'permissions': [
            {'action': 'read'}, // missing resource & effect
          ],
        },
      };
      final rules = projectOpenCodeSessionPermissions(
        frame,
        ref,
        sourceVersion: '2.0.22',
      );
      expect(rules.recognized, isFalse);
      expect(rules.rules, isEmpty);
    });
  });
}

bool _throws(Object? Function() call) {
  try {
    call();
    return false;
  } on Exception {
    return true;
  }
}
