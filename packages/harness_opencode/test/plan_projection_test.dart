import 'package:codewalk_core/codewalk_core.dart';
import 'package:harness_opencode/harness_opencode.dart';
import 'package:harness_opencode/src/history_projection.dart';
import 'package:harness_opencode/src/tool_metadata.dart';
import 'package:test/test.dart';

import 'session_reader_test.dart' show TestTransport, response;
import 'stream_owner_test.dart' show ScriptedConnection;

const _host = HostId('host-a');
const _harnessId = HarnessInstanceId('inst-a');
const _harness = HarnessRef(_host, _harnessId);
const _session = SessionRef(_host, _harnessId, 'ses_1');
const _version = '2.3.2';

StreamPosition _pos(int seq) => StreamPosition(
  id: 'opencode:/api/event',
  epoch: '1',
  seq: BigInt.from(seq),
);

DateTime _ts(int second) => DateTime.utc(2026, 11, 23, 12, 0, second);

Map<String, Object?> _toolFrame(
  String type, {
  required String eventId,
  required int seq,
  required String msgId,
  required String callId,
  String? name,
  Map<String, Object?>? input,
  List<Object?>? content,
  Map<String, Object?>? metadata,
  Map<String, Object?>? error,
  bool executed = true,
}) {
  final terminal =
      type == 'session.tool.success' || type == 'session.tool.failed';
  return {
    'id': eventId,
    'type': type,
    'created': 1700000000000 + seq * 1000,
    'durable': {
      'aggregateID': _session.nativeId,
      'seq': seq,
      'version': terminal ? 2 : 1,
    },
    'data': {
      'sessionID': _session.nativeId,
      'assistantMessageID': msgId,
      'id': callId,
      'name': ?name,
      if (type == 'session.tool.called' || terminal) 'executed': executed,
      'input': ?input,
      'content': ?content,
      'metadata': ?metadata,
      'error': ?error,
    },
  };
}

void main() {
  group('openCodeToolKind & openCodePlanCapabilities', () {
    test('maps todowrite and todoread to ToolKind.plan', () {
      expect(openCodeToolKind('todowrite'), ToolKind.plan);
      expect(openCodeToolKind('todoread'), ToolKind.plan);
      expect(openCodeToolKind('custom_todo'), ToolKind.other);
    });

    test('advertises plan.observe on supported OpenCode v2 versions', () {
      final supported = openCodePlanCapabilities('2.3.2');
      expect(supported[PlanCapabilities.observe]?.isAvailable, isTrue);
      expect(
        supported[PlanCapabilities.observe]?.support.known,
        Support.native,
      );

      final unverified = openCodePlanCapabilities(null);
      expect(unverified[PlanCapabilities.observe]?.isAvailable, isFalse);
      expect(unverified[PlanCapabilities.observe]?.reason, 'unverifiedVersion');

      final legacy = openCodePlanCapabilities('1.2.0');
      expect(legacy[PlanCapabilities.observe]?.isAvailable, isFalse);
    });
  });

  group('parseOpenCodeTodos', () {
    test('parses known, unknown, malformed, redacted, empty and truncated', () {
      expect(parseOpenCodeTodos(null), isNull);
      expect(parseOpenCodeTodos({'not': 'a list'}), isNull);
      expect(parseOpenCodeTodos(const []), isEmpty);

      final entries = parseOpenCodeTodos([
        {'content': 'Step 1', 'status': 'completed'},
        {'content': 'Step 2', 'status': 'in_progress'},
        {'content': 'Step 3', 'status': 'pending'},
        {'content': 'Step 4', 'status': 'cancelled'},
        {'content': 'Step 5', 'status': 'blocked'},
        {'content': 'Step 6'},
        {'content': '   ', 'status': 'pending'},
        {'content': 123, 'status': 'pending'},
        'not-a-map',
        {
          'content': 'Bearer sk-1234567890abcdef1234567890',
          'status': 'pending',
        },
      ])!;
      expect(entries.length, 7);
      expect(entries[0].id, '0');
      expect(entries[0].status.known, PlanStatus.completed);
      expect(entries[1].status.known, PlanStatus.inProgress);
      expect(entries[2].status.known, PlanStatus.pending);
      expect(entries[3].status.known, PlanStatus.cancelled);
      expect(entries[4].status.isKnown, isFalse);
      expect(entries[4].status.value, 'blocked');
      expect(entries[5].status.known, PlanStatus.unknown);
      expect(entries[6].title, isNot(contains('sk-1234567890')));

      var truncated = false;
      final big = parseOpenCodeTodos(
        List.generate(300, (i) => {'content': 'Item $i', 'status': 'pending'}),
        onTruncated: () => truncated = true,
      )!;
      expect(big.length, 256);
      expect(truncated, isTrue);
    });
  });

  group('live tool event projection', () {
    SessionState reduceAll(SessionState state, List<SessionEvent> events) {
      var next = state;
      for (final event in events) {
        next = reduce(next, event).state;
      }
      return next;
    }

    test(
      'completed todowrite emits ItemUpserted + PlanChanged and handles empty clear',
      () {
        var state = SessionState(_session);
        final start = projectOpenCodeEvent(
          _toolFrame(
            'session.tool.input.started',
            eventId: 'evt_1',
            seq: 1,
            msgId: 'msg_002',
            callId: 'call_1',
            name: 'todowrite',
          ),
          state,
          sourceVersion: _version,
          position: _pos(1),
          receivedAt: _ts(1),
        );
        expect(start, hasLength(1));
        state = reduceAll(state, start);
        expect(state.plan, isNull);

        final called = projectOpenCodeEvent(
          _toolFrame(
            'session.tool.called',
            eventId: 'evt_2',
            seq: 2,
            msgId: 'msg_002',
            callId: 'call_1',
            input: {
              'todos': [
                {'content': 'Write parser', 'status': 'completed'},
                {'content': 'Build widget', 'status': 'in_progress'},
              ],
            },
          ),
          state,
          sourceVersion: _version,
          position: _pos(2),
          receivedAt: _ts(2),
        );
        expect(called, hasLength(1));
        state = reduceAll(state, called);
        expect(state.plan, isNull);

        final success = projectOpenCodeEvent(
          _toolFrame(
            'session.tool.success',
            eventId: 'evt_3',
            seq: 3,
            msgId: 'msg_002',
            callId: 'call_1',
            content: [
              {'type': 'text', 'text': 'Todos updated'},
            ],
            metadata: {
              'todos': [
                {'content': 'Write parser', 'status': 'completed'},
                {'content': 'Build widget', 'status': 'in_progress'},
              ],
            },
          ),
          state,
          sourceVersion: _version,
          position: _pos(3),
          receivedAt: _ts(3),
        );
        expect(success, hasLength(2));
        expect(success[0], isA<ItemUpserted>());
        expect(success[1], isA<PlanChanged>());
        state = reduceAll(state, success);
        expect(state.plan?.anchor?.message.value, 'msg_002');
        expect(state.plan?.entries.map((e) => e.title).toList(), [
          'Write parser',
          'Build widget',
        ]);

        // Empty `todos: []` clears the active plan.
        state = reduceAll(
          state,
          projectOpenCodeEvent(
            _toolFrame(
              'session.tool.input.started',
              eventId: 'evt_4',
              seq: 4,
              msgId: 'msg_003',
              callId: 'call_2',
              name: 'todowrite',
            ),
            state,
            sourceVersion: _version,
            position: _pos(4),
            receivedAt: _ts(4),
          ),
        );
        state = reduceAll(
          state,
          projectOpenCodeEvent(
            _toolFrame(
              'session.tool.called',
              eventId: 'evt_5',
              seq: 5,
              msgId: 'msg_003',
              callId: 'call_2',
              input: {'todos': const <Object?>[]},
            ),
            state,
            sourceVersion: _version,
            position: _pos(5),
            receivedAt: _ts(5),
          ),
        );
        state = reduceAll(
          state,
          projectOpenCodeEvent(
            _toolFrame(
              'session.tool.success',
              eventId: 'evt_6',
              seq: 6,
              msgId: 'msg_003',
              callId: 'call_2',
              content: [
                {'type': 'text', 'text': 'Todos cleared'},
              ],
            ),
            state,
            sourceVersion: _version,
            position: _pos(6),
            receivedAt: _ts(6),
          ),
        );
        expect(state.plan?.entries, isEmpty);
        expect(visiblePlan(state), isNull);
      },
    );

    test(
      'falls back to metadata.todos when input lacks todos, ignores todoread and failed calls',
      () {
        var state = SessionState(_session);
        state = reduceAll(
          state,
          projectOpenCodeEvent(
            _toolFrame(
              'session.tool.input.started',
              eventId: 'evt_1',
              seq: 1,
              msgId: 'msg_002',
              callId: 'call_1',
              name: 'todowrite',
            ),
            state,
            sourceVersion: _version,
            position: _pos(1),
            receivedAt: _ts(1),
          ),
        );
        // No `called` frame with input; success carries `metadata.todos`.
        final success = projectOpenCodeEvent(
          _toolFrame(
            'session.tool.success',
            eventId: 'evt_2',
            seq: 2,
            msgId: 'msg_002',
            callId: 'call_1',
            content: [
              {'type': 'text', 'text': 'Todos updated'},
            ],
            metadata: {
              'todos': [
                {'content': 'From metadata', 'status': 'pending'},
              ],
            },
          ),
          state,
          sourceVersion: _version,
          position: _pos(2),
          receivedAt: _ts(2),
        );
        state = reduceAll(state, success);
        expect(state.plan?.entries.single.title, 'From metadata');

        // Failed todowrite leaves the previous plan intact.
        state = reduceAll(
          state,
          projectOpenCodeEvent(
            _toolFrame(
              'session.tool.input.started',
              eventId: 'evt_3',
              seq: 3,
              msgId: 'msg_003',
              callId: 'call_2',
              name: 'todowrite',
            ),
            state,
            sourceVersion: _version,
            position: _pos(3),
            receivedAt: _ts(3),
          ),
        );
        final failed = projectOpenCodeEvent(
          _toolFrame(
            'session.tool.failed',
            eventId: 'evt_4',
            seq: 4,
            msgId: 'msg_003',
            callId: 'call_2',
            error: {'type': 'tool_error', 'message': 'denied'},
          ),
          state,
          sourceVersion: _version,
          position: _pos(4),
          receivedAt: _ts(4),
        );
        expect(failed, hasLength(1));
        state = reduceAll(state, failed);
        expect(state.plan?.entries.single.title, 'From metadata');

        // todoread emits only ItemUpserted and never touches state.plan.
        state = reduceAll(
          state,
          projectOpenCodeEvent(
            _toolFrame(
              'session.tool.input.started',
              eventId: 'evt_5',
              seq: 5,
              msgId: 'msg_004',
              callId: 'call_3',
              name: 'todoread',
            ),
            state,
            sourceVersion: _version,
            position: _pos(5),
            receivedAt: _ts(5),
          ),
        );
        final readSuccess = projectOpenCodeEvent(
          _toolFrame(
            'session.tool.success',
            eventId: 'evt_6',
            seq: 6,
            msgId: 'msg_004',
            callId: 'call_3',
            content: [
              {'type': 'text', 'text': '[]'},
            ],
            metadata: {'todos': const <Object?>[]},
          ),
          state,
          sourceVersion: _version,
          position: _pos(6),
          receivedAt: _ts(6),
        );
        expect(readSuccess, hasLength(1));
        state = reduceAll(state, readSuccess);
        expect(state.plan?.entries.single.title, 'From metadata');
      },
    );
  });

  group('committed revert recomputes plan', () {
    test(
      'restores surviving turn plan or clears when plan is reverted away',
      () {
        final items = projectOpenCodeHistory(
          [
            {
              'id': 'msg_001',
              'type': 'user',
              'text': 'Turn 1',
              'time': {'created': 1000},
            },
            {
              'id': 'msg_002',
              'type': 'assistant',
              'time': {'created': 2000, 'completed': 2500},
              'content': [
                {
                  'type': 'tool',
                  'id': 'call_1',
                  'name': 'todowrite',
                  'time': {'created': 2100, 'ran': 2200},
                  'state': {
                    'status': 'completed',
                    'input': {
                      'todos': [
                        {'content': 'Turn 1 task', 'status': 'completed'},
                      ],
                    },
                    'content': [
                      {'type': 'text', 'text': 'Todos updated'},
                    ],
                  },
                },
              ],
            },
            {
              'id': 'msg_003',
              'type': 'user',
              'text': 'Turn 2',
              'time': {'created': 3000},
            },
            {
              'id': 'msg_004',
              'type': 'assistant',
              'time': {'created': 4000, 'completed': 4500},
              'content': [
                {
                  'type': 'tool',
                  'id': 'call_2',
                  'name': 'todowrite',
                  'time': {'created': 4100, 'ran': 4200},
                  'state': {
                    'status': 'completed',
                    'input': {
                      'todos': [
                        {'content': 'Turn 2 task', 'status': 'in_progress'},
                      ],
                    },
                    'content': [
                      {'type': 'text', 'text': 'Todos updated'},
                    ],
                  },
                },
              ],
            },
          ],
          _session,
          sourceVersion: _version,
        );
        var state = SessionState(_session);
        var seq = 1;
        for (final item in items) {
          state = reduce(
            state,
            ItemUpserted(
              meta: EventMeta(
                owner: const SessionOwner(_session),
                position: _pos(seq++),
                receivedAt: _ts(seq),
                source: item.source,
              ),
              item: item,
            ),
          ).state;
        }
        state = reduce(
          state,
          PlanChanged(
            meta: EventMeta(
              owner: const SessionOwner(_session),
              position: _pos(seq++),
              receivedAt: _ts(seq),
              source: items.last.source,
            ),
            plan: PlanSnapshot(
              owner: const SessionOwner(_session),
              entries: [
                PlanEntry(
                  id: '0',
                  title: 'Turn 2 task',
                  status: const OpenValue.known(PlanStatus.inProgress),
                ),
              ],
              anchor: items.last.meta.anchor,
            ),
          ),
        ).state;

        // Commit revert at msg_003 -> restores Turn 1 task!
        final commitTurn2 = projectOpenCodeRevertEvent(
          {
            'id': 'evt_rev_1',
            'type': 'session.revert.committed',
            'created': 5000,
            'durable': {
              'aggregateID': _session.nativeId,
              'seq': 10,
              'version': 1,
            },
            'data': {'sessionID': _session.nativeId, 'to': 'msg_003'},
          },
          state,
          sourceVersion: _version,
          position: _pos(seq++),
          receivedAt: _ts(seq),
        );
        for (final e in commitTurn2) {
          state = reduce(state, e).state;
        }
        expect(state.plan?.entries.single.title, 'Turn 1 task');
        expect(visiblePlan(state)?.entries.single.title, 'Turn 1 task');

        // Commit revert at msg_001 -> clears plan completely!
        final commitTurn1 = projectOpenCodeRevertEvent(
          {
            'id': 'evt_rev_2',
            'type': 'session.revert.committed',
            'created': 6000,
            'durable': {
              'aggregateID': _session.nativeId,
              'seq': 11,
              'version': 1,
            },
            'data': {'sessionID': _session.nativeId, 'to': 'msg_001'},
          },
          state,
          sourceVersion: _version,
          position: _pos(seq++),
          receivedAt: _ts(seq),
        );
        for (final e in commitTurn1) {
          state = reduce(state, e).state;
        }
        expect(state.plan?.entries, isEmpty);
        expect(visiblePlan(state), isNull);
      },
    );
  });

  group('hydration and loadOlderHistory plan fill', () {
    test(
      'hydrates plan, omits when older history may hold it, and fills on loadOlderHistory',
      () async {
        // Page 1 (newest, desc): assistant text only, with older cursor.
        // Page 2 (older): user prompt + completed todowrite.
        final transport = TestTransport((request, _) async {
          final uri = Uri.parse(request.path);
          final tail = uri.pathSegments.last;
          if (tail == 'message') {
            final cursor = uri.queryParameters['cursor'];
            if (cursor == null) {
              return response({
                'data': [
                  {
                    'id': 'msg_003',
                    'type': 'assistant',
                    'time': {'created': 3000, 'completed': 3500},
                    'content': [
                      {'type': 'text', 'text': 'Still working on it.'},
                    ],
                  },
                ],
                'cursor': {'previous': null, 'next': 'page2'},
              });
            }
            return response({
              'data': [
                {
                  'id': 'msg_002',
                  'type': 'assistant',
                  'time': {'created': 2000, 'completed': 2500},
                  'content': [
                    {
                      'type': 'tool',
                      'id': 'call_1',
                      'name': 'todowrite',
                      'time': {'created': 2100, 'ran': 2200},
                      'state': {
                        'status': 'completed',
                        'input': {
                          'todos': [
                            {
                              'content': 'Older page task',
                              'status': 'in_progress',
                            },
                          ],
                        },
                        'content': [
                          {'type': 'text', 'text': 'Todos updated'},
                        ],
                      },
                    },
                  ],
                },
                {
                  'id': 'msg_001',
                  'type': 'user',
                  'text': 'Do the plan',
                  'time': {'created': 1000},
                },
              ],
              'cursor': {'previous': null, 'next': null},
            });
          }
          return response(switch (tail) {
            'active' => const {'data': <String, Object?>{}},
            'inbox' || 'permission' || 'form' => const {'data': <Object?>[]},
            _ => {
              'data': {
                'id': _session.nativeId,
                'title': 'Plan test',
                'location': {'directory': '/work'},
                'time': {'created': 1000, 'updated': 5000},
              },
            },
          });
        });

        final connection = ScriptedConnection();
        final store = SessionStore(maxSessions: 8);
        final owner = OpenCodeStreamOwner(
          connection: connection,
          reader: OpenCodeSessionReader(transport, harness: _harness),
          store: store,
          harness: _harness,
          sourceVersion: _version,
          now: () => DateTime.utc(2026, 11, 23, 12),
          delay: (_) async {},
        )..start();
        addTearDown(() async {
          await owner.close();
          await connection.close();
        });

        owner.watch(_session);
        connection.connect(1);
        for (var i = 0; i < 40; i++) {
          await Future<void>.delayed(Duration.zero);
        }

        // Newest page had neither UserInput nor todowrite with more history -> plan null.
        expect(store.read(_session)?.plan, isNull);

        // Load older page -> fills plan from older page!
        final loaded = await owner.loadOlderHistory(_session);
        expect(loaded, isTrue);
        expect(
          store.read(_session)?.plan?.entries.single.title,
          'Older page task',
        );
        expect(
          visiblePlan(store.read(_session))?.entries.single.title,
          'Older page task',
        );
      },
    );

    test(
      'staged revert restores surviving plan, blocks post-cut updates, cleared restores post-cut, and hydration filters staged cut',
      () {
        final items = projectOpenCodeHistory(
          [
            {
              'id': 'msg_001',
              'type': 'user',
              'text': 'Turn 1',
              'time': {'created': 1000},
            },
            {
              'id': 'msg_002',
              'type': 'assistant',
              'time': {'created': 2000, 'completed': 2500},
              'content': [
                {
                  'type': 'tool',
                  'id': 'call_1',
                  'name': 'todowrite',
                  'time': {'created': 2100, 'ran': 2200},
                  'state': {
                    'status': 'completed',
                    'input': {
                      'todos': [
                        {'content': 'Turn 1 task', 'status': 'completed'},
                      ],
                    },
                    'content': [
                      {'type': 'text', 'text': 'Todos updated'},
                    ],
                  },
                },
              ],
            },
            {
              'id': 'msg_003',
              'type': 'user',
              'text': 'Turn 2',
              'time': {'created': 3000},
            },
            {
              'id': 'msg_004',
              'type': 'assistant',
              'time': {'created': 4000, 'completed': 4500},
              'content': [
                {
                  'type': 'tool',
                  'id': 'call_2',
                  'name': 'todowrite',
                  'time': {'created': 4100, 'ran': 4200},
                  'state': {
                    'status': 'completed',
                    'input': {
                      'todos': [
                        {'content': 'Turn 2 task', 'status': 'in_progress'},
                      ],
                    },
                    'content': [
                      {'type': 'text', 'text': 'Todos updated'},
                    ],
                  },
                },
              ],
            },
          ],
          _session,
          sourceVersion: _version,
        );

        // Hydration with active staged revert at msg_003 derives Turn 1 task!
        final hydratedStaged = openCodeHydratedPlan(
          items,
          ref: _session,
          sourceVersion: _version,
          boundary: SnapshotBoundary(
            owner: const SessionOwner(_session),
            hydrationGeneration: 'g1',
            readStart: _pos(1),
            readStartedAt: _ts(1),
            authority: const OpenValue.known(SnapshotAuthority.authoritative),
          ),
          hasMoreHistory: false,
          revert: RevertState(
            kind: const OpenValue.known(RevertKind.staged),
            anchor: openCodeMessageAnchor('msg_003'),
          ),
        );
        expect(hydratedStaged?.value.entries.single.title, 'Turn 1 task');

        // Start live at Turn 2 plan.
        var state = SessionState(_session);
        var seq = 1;
        for (final item in items) {
          state = reduce(
            state,
            ItemUpserted(
              meta: EventMeta(
                owner: const SessionOwner(_session),
                position: _pos(seq++),
                receivedAt: _ts(seq),
                source: item.source,
              ),
              item: item,
            ),
          ).state;
        }
        state = reduce(
          state,
          PlanChanged(
            meta: EventMeta(
              owner: const SessionOwner(_session),
              position: _pos(seq++),
              receivedAt: _ts(seq),
              source: items.last.source,
            ),
            plan: PlanSnapshot(
              owner: const SessionOwner(_session),
              entries: [
                PlanEntry(
                  id: '0',
                  title: 'Turn 2 task',
                  status: const OpenValue.known(PlanStatus.inProgress),
                ),
              ],
              anchor: items.last.meta.anchor,
            ),
          ),
        ).state;

        // Stage revert at msg_003 -> restores Turn 1 task during preview!
        final stagedEvents = projectOpenCodeRevertEvent(
          {
            'id': 'evt_stage_1',
            'type': 'session.revert.staged',
            'created': 5000,
            'durable': {
              'aggregateID': _session.nativeId,
              'seq': 10,
              'version': 1,
            },
            'data': {
              'sessionID': _session.nativeId,
              'revert': {'messageID': 'msg_003'},
            },
          },
          state,
          sourceVersion: _version,
          position: _pos(seq++),
          receivedAt: _ts(seq),
        );
        for (final e in stagedEvents) {
          state = reduce(state, e).state;
        }
        expect(state.plan?.entries.single.title, 'Turn 1 task');
        expect(visiblePlan(state)?.entries.single.title, 'Turn 1 task');

        // Late post-cut todowrite while staged must NOT displace Turn 1 task.
        for (final e in projectOpenCodeToolEvents(
          _toolFrame(
            'session.tool.input.started',
            eventId: 'evt_late_0',
            seq: 11,
            msgId: 'msg_005',
            callId: 'call_late',
            name: 'todowrite',
          ),
          state,
          sourceVersion: _version,
          position: _pos(seq++),
          receivedAt: _ts(seq),
        )) {
          state = reduce(state, e).state;
        }
        final lateCall = projectOpenCodeToolEvents(
          _toolFrame(
            'session.tool.called',
            eventId: 'evt_late_1',
            seq: 12,
            msgId: 'msg_005',
            callId: 'call_late',
            name: 'todowrite',
            input: {
              'todos': [
                {'content': 'Post-cut task', 'status': 'in_progress'},
              ],
            },
          ),
          state,
          sourceVersion: _version,
          position: _pos(seq++),
          receivedAt: _ts(seq),
        );
        expect(lateCall.whereType<ItemUpserted>(), hasLength(1));
        for (final e in lateCall) {
          state = reduce(state, e).state;
        }
        final lateDone = projectOpenCodeToolEvents(
          _toolFrame(
            'session.tool.success',
            eventId: 'evt_late_2',
            seq: 13,
            msgId: 'msg_005',
            callId: 'call_late',
            content: [
              {'type': 'text', 'text': 'Todos updated'},
            ],
          ),
          state,
          sourceVersion: _version,
          position: _pos(seq++),
          receivedAt: _ts(seq),
        );
        expect(lateDone.whereType<ItemUpserted>(), hasLength(1));
        expect(lateDone.whereType<PlanChanged>(), isEmpty);
        for (final e in lateDone) {
          state = reduce(state, e).state;
        }
        expect(visiblePlan(state)?.entries.single.title, 'Turn 1 task');

        // Clear revert (Redo) -> restores latest post-cut plan from full timeline!
        final clearedEvents = projectOpenCodeRevertEvent(
          {
            'id': 'evt_clear_1',
            'type': 'session.revert.cleared',
            'created': 6000,
            'durable': {
              'aggregateID': _session.nativeId,
              'seq': 14,
              'version': 1,
            },
            'data': {'sessionID': _session.nativeId},
          },
          state,
          sourceVersion: _version,
          position: _pos(seq++),
          receivedAt: _ts(seq),
        );
        for (final e in clearedEvents) {
          state = reduce(state, e).state;
        }
        expect(state.plan?.entries.single.title, 'Post-cut task');
        expect(visiblePlan(state)?.entries.single.title, 'Post-cut task');

        // Metadata-only todowrite completing while staged is preserved for Redo.
        for (final e in projectOpenCodeRevertEvent(
          {
            'id': 'evt_stage_2',
            'type': 'session.revert.staged',
            'created': 7000,
            'durable': {
              'aggregateID': _session.nativeId,
              'seq': 15,
              'version': 1,
            },
            'data': {
              'sessionID': _session.nativeId,
              'revert': {'messageID': 'msg_003'},
            },
          },
          state,
          sourceVersion: _version,
          position: _pos(seq++),
          receivedAt: _ts(seq),
        )) {
          state = reduce(state, e).state;
        }
        for (final e in projectOpenCodeToolEvents(
          _toolFrame(
            'session.tool.input.started',
            eventId: 'evt_meta_0',
            seq: 16,
            msgId: 'msg_006',
            callId: 'call_meta',
            name: 'todowrite',
          ),
          state,
          sourceVersion: _version,
          position: _pos(seq++),
          receivedAt: _ts(seq),
        )) {
          state = reduce(state, e).state;
        }
        final metaDone = projectOpenCodeToolEvents(
          _toolFrame(
            'session.tool.success',
            eventId: 'evt_meta_2',
            seq: 17,
            msgId: 'msg_006',
            callId: 'call_meta',
            content: [
              {'type': 'text', 'text': 'Todos updated'},
            ],
            metadata: {
              'todos': [
                {'content': 'Metadata redo task', 'status': 'in_progress'},
              ],
            },
          ),
          state,
          sourceVersion: _version,
          position: _pos(seq++),
          receivedAt: _ts(seq),
        );
        expect(metaDone.whereType<ItemUpserted>(), hasLength(1));
        expect(metaDone.whereType<PlanChanged>(), isEmpty);
        for (final e in metaDone) {
          state = reduce(state, e).state;
        }
        expect(visiblePlan(state)?.entries.single.title, 'Turn 1 task');

        for (final e in projectOpenCodeRevertEvent(
          {
            'id': 'evt_clear_2',
            'type': 'session.revert.cleared',
            'created': 8000,
            'durable': {
              'aggregateID': _session.nativeId,
              'seq': 18,
              'version': 1,
            },
            'data': {'sessionID': _session.nativeId},
          },
          state,
          sourceVersion: _version,
          position: _pos(seq++),
          receivedAt: _ts(seq),
        )) {
          state = reduce(state, e).state;
        }
        expect(state.plan?.entries.single.title, 'Metadata redo task');
        expect(visiblePlan(state)?.entries.single.title, 'Metadata redo task');
      },
    );

    test(
      'parseOpenCodeTodos bounds raw invalid lists and huge content strings safely',
      () {
        var truncated = false;
        final garbageList = List<Object?>.filled(
          1000,
          'not-a-map',
          growable: true,
        )..add({'content': 'After raw cap', 'status': 'pending'});
        final parsed = parseOpenCodeTodos(
          garbageList,
          onTruncated: () => truncated = true,
        );
        expect(parsed, isEmpty);
        expect(truncated, isTrue);

        // Huge string with emoji surrogate pair right at the 16384 boundary.
        final huge = '${'a' * 16383}😀${'b' * 20000}';
        final bounded = parseOpenCodeTodos([
          {'content': huge, 'status': 'pending'},
        ]);
        expect(bounded, hasLength(1));
        expect(bounded!.single.title.length, 4096);
      },
    );
  });
}
