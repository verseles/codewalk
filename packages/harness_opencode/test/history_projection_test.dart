import 'dart:convert';
import 'dart:io';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:harness_opencode/src/error_projection.dart';
import 'package:harness_opencode/src/history_projection.dart';
import 'package:test/test.dart';

import 'execution_test_data.dart' show errorJson;
import 'history_test_data.dart';
import 'support/fixture_replay.dart';
import 'tool_test_data.dart' show PrivateToolFields;

List<TimelineItem> project(
  List<Object?> rows, {
  SessionRef ref = historyRef,
  int maxItems = 2000,
}) => projectOpenCodeHistory(
  rows,
  ref,
  sourceVersion: '2.0.22',
  maxItems: maxItems,
);

void main() {
  test('a model or agent switch becomes its note (#426)', () {
    final items = project([
      message('s1', 'agent-switched', {'agent': 'plan', 'previous': 'build'}),
      message('s2', 'model-switched', {
        'model': {'id': 'model-b', 'providerID': 'p', 'variant': 'high'},
        'previous': {'id': 'model-a', 'providerID': 'p'},
      }),
      message('s3', 'model-switched', {
        'model': {'id': 'model-c', 'providerID': 'q', 'variant': ''},
      }),
    ]);
    final notes = items.cast<Notice>();
    expect(notes.map((note) => note.kind.known), [
      for (var i = 0; i < 3; i++) NoticeKind.selectionChanged,
    ]);
    expect(notes[0].selection!.agentId, 'plan');
    expect(notes[0].selection!.modelId, isNull);
    expect(
      [
        notes[1].selection!.modelId,
        notes[1].selection!.modelProviderId,
        notes[1].selection!.modelVariant,
        notes[1].selection!.agentId,
      ],
      ['model-b', 'p', 'high', null],
    );
    expect(notes[2].selection!.modelVariant, isNull);
    // The same id the live event gives the same message.
    expect(
      notes[0].id.value,
      jsonEncode([historyRef.storageKey, 'msg_s1', 'notice', 0]),
    );
    for (final malformed in [
      message('x', 'agent-switched', {'agent': ''}),
      message('x', 'model-switched', {
        'model': {'id': 'm'},
      }),
      message('x', 'agent-switched', {'agent': 'plan', 'previous': 7}),
      message('x', 'model-switched', {
        'model': {'id': 'm', 'providerID': 'p'},
        'previous': 'model-a',
      }),
      message('x', 'model-switched', {
        'model': {'id': 'm', 'providerID': 'p'},
        'previous': {'id': 'model-a', 'providerID': 'p', 'variant': 3},
      }),
    ]) {
      expect(() => project([malformed]), throwsFormatException);
    }
  });

  test('display labels never turn a readable near-cap page into a failure', () {
    final label = 'x' * 250;
    final items = project([
      assistant(
        'a',
        // Four parts under the per-field cap that fill the page budget.
        [for (var i = 0; i < 4; i++) textBlock('y' * (256 * 1024 - 150))],
        completed: true,
        fields: {
          'agent': label,
          'model': {'id': label, 'providerID': label, 'variant': label},
          'finish': label,
        },
      ),
    ]);
    final context = items.first.meta.message!;
    expect(
      [context.modelId, context.agentId, context.finish],
      [label, label, label],
    );
  });

  test('optional report details do not consume the history node budget', () {
    final items = project([
      for (var i = 0; i < 100; i++)
        message('report_$i', 'synthetic', {
          'text': 'OK',
          'description': 'Review',
          'metadata': {
            'source': 'subagent',
            'childID': 'ses_child',
            'agent': 'Reviewer',
          },
        }),
      for (var i = 0; i < 10; i++)
        assistant('answer_$i', List.generate(106, (_) => textBlock('hello'))),
    ]);
    expect(items, hasLength(1160));
    final last = items.whereType<Notice>().last;
    expect(last.report?.agent, 'Reviewer');
    expect(last.relatedSession?.nativeId, 'ses_child');
  });

  test(
    'exhausting the display label budget keeps later replies and child links',
    () {
      final name = 'a' * 256;
      final rows = List.generate(
        140,
        (i) => message('report_$i', 'synthetic', {
          'text': 'OK',
          'description': name,
          'metadata': {
            'source': 'subagent',
            'childID': 'ses_child',
            'agent': name,
          },
        }),
      );
      final notices = project(rows).cast<Notice>();
      expect(notices.first.report?.agent, name);
      expect(notices, hasLength(140));
      expect(notices.last.report, isNotNull);
      expect(notices.last.report!.agent, isNull);
      expect(notices.last.report!.description, isNull);
      expect(notices.last.text, 'OK');
      expect(notices.last.relatedSession?.nativeId, 'ses_child');
    },
  );

  test('assistant parts carry what their message reports', () {
    final items = project([
      message('u', 'user', {'text': 'hi'}),
      assistant(
        'a',
        [textBlock('one'), textBlock('two')],
        completed: true,
        fields: {
          'agent': 'build',
          'model': {'id': 'model', 'providerID': 'provider', 'variant': 'high'},
          'cost': 0.5,
          'tokens': {
            'input': 10,
            'output': 2,
            'reasoning': 1,
            'cache': {'read': 3, 'write': 0},
          },
          'finish': 'stop',
        },
      ),
      assistant(
        'b',
        [textBlock('odd')],
        fields: {
          'model': 'not-a-map',
          'cost': -1,
          'agent': 'x' * 257,
          'finish': '\ud800',
        },
      ),
    ]);
    final user = items.first;
    expect(user.meta.message, isNull);
    final parts = items.whereType<AssistantText>().toList();
    final first = parts[0].meta.message!;
    expect(first.message, MessageRef('msg_a'));
    expect(parts[1].meta.message!.message, first.message);
    expect(
      first.created,
      DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true),
    );
    expect(
      first.completed,
      DateTime.fromMillisecondsSinceEpoch(2000, isUtc: true),
    );
    expect(
      [first.modelId, first.modelProviderId, first.modelVariant, first.agentId],
      ['model', 'provider', 'high', 'build'],
    );
    expect([first.cost?.amount, first.cost?.currency], [0.5, 'USD']);
    expect([first.tokens?.input, first.tokens?.cacheRead], [10, 3]);
    expect(first.finish, 'stop');
    // A display-only value the record gets wrong is unknown, not an error.
    final odd = parts[2].meta.message!;
    expect(
      [odd.modelId, odd.cost, odd.completed, odd.agentId, odd.finish],
      [null, null, null, null, null],
    );
  });

  test(
    'review regression: streaming fragments do not retain credential-bearing JSON',
    () {
      final item =
          project([
                assistant('streamed', [
                  toolBlock(
                    'partial',
                    'streaming',
                    input: '{"apiKey":"fake-stream-secret","path":',
                  ),
                ]),
              ]).single
              as ToolCall;
      expect(item.input, isNull);
      expect((item.source.extra!.value as Map)['inputNotProjected'], isTrue);
      expect(
        jsonEncode(semanticItem(item)),
        isNot(contains('fake-stream-secret')),
      );
      expect(item.status.known, ItemStatus.streaming);
    },
  );

  test(
    'review regression: x-api-key header alias is redacted in nested tool arguments',
    () {
      final item =
          project([
                assistant('header', [
                  toolBlock(
                    'one',
                    'running',
                    input: {
                      'headers': {
                        'X-Api-Key': 'fake-header-secret',
                        'Content-Type': 'application/json',
                      },
                    },
                  ),
                ]),
              ]).single
              as ToolCall;
      final headers = (item.input!.value as Map)['headers'] as Map;
      expect(headers['X-Api-Key'], '[redacted]');
      expect(headers['Content-Type'], 'application/json');
      expect((item.source.extra!.value as Map)['inputRedacted'], isTrue);
      expect(
        jsonEncode(semanticItem(item)),
        isNot(contains('fake-header-secret')),
      );
    },
  );

  test(
    'review regression: valid 640KiB tool output page is not charged twice',
    () {
      final rows = List.generate(
        20,
        (i) => assistant('$i', [
          toolBlock(
            'call_$i',
            'completed',
            content: [
              {'type': 'text', 'text': 'x' * 32768},
            ],
          ),
        ]),
      );
      expect(
        utf8.encode(jsonEncode(historyPage(rows))).length,
        lessThan(1024 * 1024),
      );
      final items = project(rows);
      expect(items, hasLength(20));
      expect(
        items.every((i) => i.status.known == ItemStatus.completed),
        isTrue,
      );
    },
  );

  test(
    'selected-content aggregate remains bounded after byte-accounting correction',
    () {
      final rows = List.generate(
        6,
        (i) => message('large_$i', 'user', {'text': 'x' * (200 * 1024)}),
      );
      expect(() => project(rows), throwsA(isA<OpenCodeHistoryBudgetException>()));
    },
  );

  test(
    'native A semantic golden: four messages, six items, source fields and no invented turn',
    () {
      final fixture = OpenCodeFixtures().observedAHistory;
      final items = project(fixture['data'] as List<Object?>);
      expect(items.map((i) => i.runtimeType.toString()), [
        'UserInput',
        'Reasoning',
        'ToolCall',
        'Reasoning',
        'AssistantText',
        'TurnOutcome',
      ]);
      final user = items[0] as UserInput;
      expect(
        user.text,
        startsWith('Use your read tool to read capture-marker.txt'),
      );
      expect(user.delivery.isKnown, isFalse);
      expect(items[1].meta.ordinal, 0);
      expect(items[3].meta.ordinal, 0);
      expect(items[4].meta.ordinal, 0);
      final tool = items[2] as ToolCall;
      expect(tool.kind.known, ToolKind.read);
      expect(tool.rawName, 'read');
      expect(tool.status.known, ItemStatus.completed);
      expect((tool.source.extra!.value as Map)['executed'], isFalse);
      expect(
        (tool.input!.value as Map)['path'],
        endsWith('/capture-marker.txt'),
      );
      expect((tool.output!.value as List).single, {
        'type': 'text',
        'text':
            'Read file /workspace/.cloud-runtime/opencode-v2/workspace/capture-marker.txt, lines 1-1\n1: SP01_NATIVE_V2_FREE_MODEL_OK',
      });
      expect((items[4] as AssistantText).text, 'SP01_NATIVE_V2_FREE_MODEL_OK');
      expect((items.last as TurnOutcome).kind.known, OutcomeKind.succeeded);
      expect(items.map((i) => i.id.value).toSet(), hasLength(6));
      expect(jsonDecode(items[1].id.value), [
        historyRef.storageKey,
        'msg_10527e37b001IGLLnE8CpxHBE9',
        'reasoning',
        0,
      ]);
      for (final item in items) {
        expect(item.turnId, isNull);
        expect(item.source.version, '2.0.22');
        expect(item.source.harness, historyHarness);
        expect(item.source.nativeEventId, isNull);
        expect(item.source.nativeCursor, isNull);
        expect(item.source.aggregateSeq, isNull);
        expect(item.source.durability.known, Durability.unknown);
      }
      final encoded = jsonEncode(items.map(semanticItem).toList());
      expect(encoded, isNot(contains('providerState')));
      expect(encoded, isNot(contains('_redacted')));
      expect(encoded, isNot(contains('fledge-alpha-free')));
      expect(encoded, isNot(contains('tokens')));
      expect(() => items.add(items.first), throwsUnsupportedError);
    },
  );

  test(
    'native D abort and native E file context remain explicit partial observations',
    () {
      final root = OpenCodeFixtures().root;
      Map<String, Object?> capture(String path) =>
          jsonDecode(File('${root.path}/$path').readAsStringSync())
              as Map<String, Object?>;
      List<Object?> lastHistory(String path, {bool aborted = false}) {
        final calls = capture(path)['calls'] as List;
        final pages = calls.where(
          (c) =>
              c['method'] == 'GET' &&
              Uri.parse(c['path'] as String).path.endsWith('/message'),
        );
        final selected = aborted
            ? pages.firstWhere(
                (c) => jsonEncode(c['response']).contains('"type":"aborted"'),
              )
            : pages.last;
        return selected['response']['data'] as List<Object?>;
      }

      final interrupted = project(
        lastHistory('d/background-interrupt.json', aborted: true),
      );
      final tool = interrupted.whereType<ToolCall>().firstWhere(
        (t) => t.error?.rawType == 'aborted',
      );
      expect(tool.status.known, ItemStatus.interrupted);
      expect(tool.error!.rawMessage, 'Tool execution interrupted');
      expect(
        interrupted.whereType<TurnOutcome>().any(
          (i) => i.kind.known == OutcomeKind.interrupted,
        ),
        isTrue,
      );
      final attached = project(lastHistory('e/attachment-png.json'));
      final userWithPng = attached.whereType<UserInput>().single;
      expect(userWithPng.attachments, hasLength(1));
      expect(userWithPng.attachments.single.mimeType, 'image/png');
      expect(userWithPng.attachments.single.kind.known, AttachmentKind.image);
      expect(userWithPng.attachments.single.name, 'capture.png');
      expect(
        userWithPng.attachments.single.content.id,
        startsWith('inline:'),
      );
      expect(
        attached.whereType<UnknownItem>().where(
          (i) => i.rawType == 'user-context-manifest',
        ),
        isEmpty,
      );
      final encoded = jsonEncode(attached.map(semanticItem).toList());
      expect(encoded, isNot(contains('iVBORw0')));
    },
  );

  test(
    'source-shaped ordinal identities stay stable across pages and composite sessions',
    () {
      final row = assistant('one', [
        textBlock('first'),
        {'type': 'reasoning', 'text': 'reason'},
        textBlock('second'),
        {'type': 'reasoning', 'text': 'more'},
        toolBlock('call:0', 'running'),
      ]);
      final items = project([row]);
      expect(items.take(4).map((i) => i.meta.ordinal), [0, 0, 1, 1]);
      expect(items.map((i) => i.id.value).toSet(), hasLength(5));
      expect(
        project([
          message('prior', 'user', {'text': ''}),
          row,
        ]).skip(1).map((i) => i.id.value),
        items.map((i) => i.id.value),
      );
      final other = project(
        [row],
        ref: const SessionRef(
          HostId('host-b'),
          HarnessInstanceId('native-a'),
          'ses_a',
        ),
      );
      expect(
        other
            .map((i) => i.id.value)
            .toSet()
            .intersection(items.map((i) => i.id.value).toSet()),
        isEmpty,
      );
    },
  );

  test(
    'finish/history presence leave completion unknown; streamed text does not finish tool or turn',
    () {
      final unverified =
          project([
                assistant(
                  'a',
                  [textBlock('prefix')],
                  fields: {'finish': 'stop'},
                ),
              ]).single
              as AssistantText;
      expect(unverified.complete, isFalse);
      expect(unverified.status.isKnown, isFalse);
      expect(unverified.prefixMissing, isFalse);
      final items = project([
        assistant('b', [
          textBlock('final text'),
          toolBlock('tool', 'running'),
        ], streamed: true),
      ]);
      expect((items[0] as AssistantText).complete, isTrue);
      expect(items[0].status.known, ItemStatus.completed);
      expect(items[1].status.known, ItemStatus.streaming);
      expect(items.whereType<TurnOutcome>(), isEmpty);
      final reasoning =
          project([
                assistant('c', [
                  {
                    'type': 'reasoning',
                    'text': '',
                    'time': {'created': 1000, 'completed': 1001},
                  },
                ]),
              ]).single
              as Reasoning;
      expect(reasoning.complete, isTrue);
    },
  );

  test(
    'tool state controls status, empty IDs/names remain legal, unknown states do not disappear',
    () {
      final items = project([
        assistant('a', [
          toolBlock('', 'completed', name: ''),
          toolBlock('partial', 'streaming'),
          toolBlock('future', 'future-state'),
        ], completed: true),
      ]);
      expect((items[0] as ToolCall).kind.known, ToolKind.other);
      expect((items[0] as ToolCall).rawName, isEmpty);
      expect(items[0].status.known, ItemStatus.completed);
      expect((items[1] as ToolCall).input, isNull);
      expect(
        (items[1].source.extra!.value as Map)['inputNotProjected'],
        isTrue,
      );
      expect(items[1].status.known, ItemStatus.streaming);
      expect((items[2] as UnknownItem).rawType, 'future-state');
    },
  );

  test(
    'tool input redacts credential keys but preserves bounded application content and immutable snapshots',
    () {
      final input = <String, Object?>{
        'path': 'file.txt',
        'nested': {
          'api_key': 'fake-key',
          'Authorization': 'fake-header',
          'count': 3,
          'token': {'very': 'fake-token'},
          'providerState': 'fake-provider',
        },
      };
      final block = toolBlock(
        'one',
        'completed',
        input: input,
        content: [
          {'type': 'text', 'text': 'Application output stays visible'},
          {
            'type': 'file',
            'uri': 'https://private.invalid/fake-token',
            'mime': 'image/png',
            'name': 'private-name',
          },
        ],
      );
      (block['state'] as Map)['metadata'] = {
        'apiKey': 'ignored',
        'truncated': true,
      };
      block['providerState'] = {'deep': 'ignored-provider'};
      final tool =
          project([
                assistant('a', [block]),
              ]).single
              as ToolCall;
      input['path'] = 'mutated';
      expect((tool.input!.value as Map)['path'], 'file.txt');
      final nested = (tool.input!.value as Map)['nested'] as Map;
      expect(nested['count'], 3);
      expect(nested['api_key'], '[redacted]');
      expect((tool.source.extra!.value as Map)['inputRedacted'], isTrue);
      expect((tool.output!.value as List).last, {
        'type': 'file',
        'mime': 'image/png',
        'available': false,
      });
      final encoded = jsonEncode(semanticItem(tool));
      for (final secret in [
        'fake-key',
        'fake-header',
        'fake-token',
        'fake-provider',
        'ignored-provider',
        'private.invalid',
        'private-name',
      ]) {
        expect(encoded, isNot(contains(secret)));
      }
      expect(encoded, contains('Application output stays visible'));
      expect(tool.outputRef, isNull);
      expect(tool.child, isNull);
      expect(
        () => (tool.input!.value as Map)['new'] = true,
        throwsUnsupportedError,
      );
    },
  );

  test(
    'assistant retry and unsupported native kinds preserve explicit markers, never invented outcomes',
    () {
      final items = project([
        assistant(
          'a',
          [],
          fields: {
            'error': {'type': 'provider.quota', 'message': 'private body'},
            'retry': {
              'attempt': 1,
              'at': 2000,
              'error': {
                'type': 'provider.rate-limit',
                'response': 'private response',
              },
            },
          },
        ),
        message('b', 'future-native', {
          'payload': {'apiKey': 'private-key'},
        }),
        message('c', 'compaction', {
          'status': 'future-status',
          'summary': 'private context',
          'tokens': {'input': 'future-shape'},
        }),
        message('d', 'synthetic', {
          'text': 'native notice',
          'metadata': {'childID': 'ses_other'},
        }),
        message('e', 'system', {'text': 'native system'}),
      ]);
      // The failed message is shown by its turn's outcome, not by empty or
      // error markers; without an idle row no outcome is invented.
      expect(items.whereType<UnknownItem>(), hasLength(3));
      expect(items.whereType<TurnOutcome>(), isEmpty);
      expect(items.whereType<Notice>().map((i) => i.kind.known), [
        NoticeKind.continuation,
        NoticeKind.system,
      ]);
      expect(
        items.whereType<Notice>().every((i) => i.relatedSession == null),
        isTrue,
      );
      final encoded = jsonEncode(items.map(semanticItem).toList());
      expect(encoded, isNot(contains('private')));
      expect((items[0] as UnknownItem).raw.value, containsPair('attempt', 1));
      expect(
        project([assistant('a', [])]).whereType<UnknownItem>().single.raw.value,
        containsPair('reason', 'emptyAssistantContent'),
      );
    },
  );

  test(
    'compaction history messages preserve optional reason, tokens, and unknown reason',
    () {
      final items = project([
        message('c1', 'compaction', {
          'status': 'completed',
          'summary': 'Kept architecture decisions',
          'reason': 'manual',
          'tokens': {
            'input': 4200,
            'output': 600,
            'reasoning': 100,
            'cache': {'read': 300, 'write': 0},
          },
        }),
        message('c2', 'compaction', {
          'status': 'completed',
          'summary': 'Future trigger',
          'reason': 'scheduled',
        }),
        message('c3', 'compaction', {
          'status': 'completed',
          'summary': 'No metadata',
        }),
      ]);
      final notices = items.whereType<Notice>().toList();
      expect(notices, hasLength(3));
      expect(
        notices[0].compaction?.trigger?.known,
        CompactionTrigger.requested,
      );
      expect(notices[0].compaction?.usage?.input, 4200);
      expect(notices[0].compaction?.usage?.output, 600);
      expect(notices[0].compaction?.usage?.reasoning, 100);
      expect(notices[0].compaction?.usage?.cacheRead, 300);
      expect(notices[1].compaction?.trigger?.known, isNull);
      expect(notices[1].compaction?.trigger?.value, 'scheduled');
      expect(notices[2].compaction, isNull);
    },
  );

  group('turn errors (V2-055A)', () {
    Map<String, Object?> failed(Object? error, {List<Object?>? blocks}) =>
        assistant('a', blocks ?? const [], fields: {'error': error});
    final idle = message('i', 'idle', {'outcome': 'failed'});

    test('a failed idle row carries the last assistant error, typed', () {
      final items = project([
        message('u', 'user', {'text': 'hi'}),
        failed(
          PrivateToolFields(
            {
              'type': 'provider.auth',
              'message': 'Denied. Authorization: Bearer abc.def.ghi',
              'status': 403,
              'response': {'body': 'fake-private-body'},
            },
            {'status', 'response'},
          ),
          blocks: [textBlock('partial answer')],
        ),
        idle,
      ]);
      expect(items.map((i) => i.runtimeType), [
        UserInput,
        AssistantText,
        TurnOutcome,
      ]);
      final outcome = items.last as TurnOutcome;
      expect(outcome.kind.known, OutcomeKind.failed);
      expect(errorJson(outcome.error), {
        'kind': 'auth',
        'rawType': 'provider.auth',
        'rawMessage': 'Denied. Authorization: Bearer [redacted]',
        'retryable': false,
        'retryAt': null,
        'action': 'changeModel',
        'details': {'messageRedacted': true},
      });
    });

    test('the message is bounded and an unknown type stays unknown', () {
      final long =
          project([
                failed({
                  'type': 'provider.invalid-output',
                  'message': 'é' * 5000,
                }),
                idle,
              ]).single
              as TurnOutcome;
      expect(long.error!.kind.known, ErrorKind.provider);
      expect(utf8.encode(long.error!.rawMessage), hasLength(8 * 1024));
      expect(long.error!.details!.value, {'messageTruncated': true});
      // Larger than one text field: bounded like the live failure, never a
      // rejected page.
      final huge = 'x' * (300 * 1024);
      final bounded =
          project([
                failed({'type': 'provider.error', 'message': huge}),
                idle,
              ]).single
              as TurnOutcome;
      expect(
        errorJson(bounded.error),
        errorJson(openCodeErrorInfo('provider.error', huge)),
      );
      final future =
          project([
                failed({'type': 'future.kind', 'message': 'Something new'}),
                idle,
              ]).single
              as TurnOutcome;
      expect(future.error!.kind.known, ErrorKind.unknown);
      expect(future.error!.rawType, 'future.kind');
      expect(future.error!.rawMessage, 'Something new');
      final silent =
          project([
                failed({'type': 'provider.timeout'}),
                idle,
              ]).single
              as TurnOutcome;
      expect(silent.error!.kind.known, ErrorKind.network);
      expect(silent.error!.rawMessage, '');
    });

    test('only a failed outcome of the same turn carries the error', () {
      const auth = {'type': 'provider.auth', 'message': 'denied'};
      TurnOutcome outcome(List<Map<String, Object?>> rows) =>
          project(rows).whereType<TurnOutcome>().last;
      // A later outcome other than failed, a user row or a later assistant
      // message without an error clears it.
      for (final rows in [
        [
          failed(auth),
          message('i', 'idle', {'outcome': 'succeeded'}),
        ],
        [
          failed(auth),
          message('i', 'idle', {'outcome': 'interrupted'}),
        ],
        [
          failed(auth),
          message('u', 'user', {'text': 'again'}),
          idle,
        ],
        [
          failed(auth),
          assistant('b', [textBlock('ok')]),
          idle,
        ],
        [
          failed(auth),
          message('s', 'idle', {'outcome': 'succeeded'}),
          idle,
        ],
      ]) {
        expect(outcome(rows).error, isNull);
      }
      // An interruption is not an error.
      expect(
        outcome([
          failed({'type': 'aborted', 'message': 'Step interrupted'}),
          idle,
        ]).error,
        isNull,
      );
      // A notice between the message and the idle row keeps it.
      expect(
        outcome([
          failed(auth),
          message('n', 'system', {'text': 'note'}),
          idle,
        ]).error!.kind.known,
        ErrorKind.auth,
      );
    });

    test('a message that is not text fails the page', () {
      expect(
        () => project([
          failed({'type': 'provider.auth', 'message': 42}),
          idle,
        ]),
        throwsFormatException,
      );
    });
  });

  test(
    'future idle outcome stays unknown and no history row creates a turn identity',
    () {
      final item =
          project([
                message('a', 'idle', {'outcome': 'shutdown'}),
              ]).single
              as TurnOutcome;
      expect(item.kind.isKnown, isFalse);
      expect(item.kind.value, 'shutdown');
      expect(item.turnId, isNull);
    },
  );

  for (final malformed in [
    message('a', 'user', {'text': null}),
    assistant('a', [
      {'type': 'text', 'text': 42},
    ]),
    assistant('a', [toolBlock('id', 'completed', content: [])]),
    assistant('a', [toolBlock('id', 'running', input: 'not an object')]),
    assistant('a', [
      toolBlock('same', 'running'),
      toolBlock('same', 'completed'),
    ]),
    assistant(
      'a',
      [],
      fields: {
        'time': {'created': double.nan},
      },
    ),
    assistant('a', [textBlock(String.fromCharCode(0xd800))]),
    assistant('a', List.generate(129, (_) => textBlock('x'))),
    message('a', 'user', {'text': 'x' * (256 * 1024 + 1)}),
  ]) {
    test(
      'known malformed or oversize row fails atomically (${malformed.hashCode})',
      () {
        expect(
          () => project([
            message('valid', 'user', {'text': 'keep only on success'}),
            malformed,
          ]),
          throwsFormatException,
        );
      },
    );
  }

  test(
    'depth/page-budget limits reject cleanly while oversized tool inputs, outputs, and errors project bounded redacted prefixes',
    () {
      Object nested = 'leaf';
      for (var i = 0; i < 18; i++) {
        nested = {'child': nested};
      }
      expect(
        () => project([
          assistant('a', [
            toolBlock('id', 'running', input: {'deep': nested}),
          ]),
        ]),
        throwsFormatException,
      );
      // Oversized tool input (#416): keeps priority keys first and a redacted
      // prefix within 64 KiB JSON-escaped bytes instead of failing the page,
      // including credentials completing more than 4 KiB past the cut boundary.
      final longSecret = 's' * 10000;
      final oversizedInputTool =
          project([
                assistant('a', [
                  toolBlock(
                    'id',
                    'running',
                    input: {
                      'content':
                          '${'x' * 65450} https://user:$longSecret@example.com/api',
                      'filePath': 'lib/app.dart',
                    },
                  ),
                ]),
              ]).single
              as ToolCall;
      final inputMap = oversizedInputTool.input!.value as Map<String, Object?>;
      expect(inputMap['filePath'], 'lib/app.dart');
      expect(
        utf8.encode(jsonEncode(inputMap)).length,
        lessThanOrEqualTo(65536),
      );
      expect(jsonEncode(inputMap), isNot(contains('user:ssss')));
      expect(
        (oversizedInputTool.source.extra!.value as Map)['inputTruncated'],
        isTrue,
      );
      expect(
        (oversizedInputTool.source.extra!.value as Map)['inputRedacted'],
        isTrue,
      );

      // Oversized tool output (#416) sets OutputRef(truncated: true) and redacts
      // credentials completing past the 4 KiB lookahead.
      final oversizedOutputTool =
          project([
                assistant('b', [
                  toolBlock(
                    'out_1',
                    'completed',
                    content: [
                      {
                        'type': 'text',
                        'text':
                            '${'y' * 65450} https://user:$longSecret@example.com/out',
                      },
                    ],
                  ),
                ]),
              ]).single
              as ToolCall;
      expect(
        utf8.encode(jsonEncode(oversizedOutputTool.output!.value)).length,
        lessThanOrEqualTo(65536),
      );
      expect(
        jsonEncode(oversizedOutputTool.output!.value),
        isNot(contains('user:ssss')),
      );
      expect(
        oversizedOutputTool.outputRef,
        OutputRef(id: 'out_1', truncated: true),
      );
      expect(
        (oversizedOutputTool.source.extra!.value as Map)['outputTruncated'],
        isTrue,
      );
      expect(
        (oversizedOutputTool.source.extra!.value as Map)['outputRedacted'],
        isTrue,
      );

      // Oversized tool error (#432): >256 KiB error message with a credential
      // completing >4 KiB past the 8 KiB cut projects cleanly redacted.
      final oversizedErrorTool =
          project([
                assistant('c', [
                  toolBlock(
                    'err_1',
                    'error',
                    error: {
                      'type': 'tool.execution',
                      'message':
                          '${'e' * 8160} https://user:$longSecret@example.com ${'q' * 300000}',
                    },
                  ),
                ]),
              ]).single
              as ToolCall;
      expect(
        utf8.encode(oversizedErrorTool.error!.rawMessage).length,
        lessThanOrEqualTo(8 * 1024),
      );
      expect(
        oversizedErrorTool.error!.rawMessage,
        isNot(contains('user:ssss')),
      );
      expect(
        (oversizedErrorTool.error!.details!.value as Map)['messageTruncated'],
        isTrue,
      );
      expect(
        (oversizedErrorTool.error!.details!.value as Map)['messageRedacted'],
        isTrue,
      );
      expect(
        (oversizedErrorTool.source.extra!.value as Map)['errorTruncated'],
        isTrue,
      );

      // Discarded streaming tool input above 256 KiB succeeds (up to 32 MiB),
      // while a lone surrogate still fails closed.
      final streamingBig =
          project([
                assistant('d', [
                  toolBlock('stream_1', 'streaming', input: 'a' * (300 * 1024)),
                ]),
              ]).single
              as ToolCall;
      expect(streamingBig.input, isNull);
      expect(
        (streamingBig.source.extra!.value as Map)['inputNotProjected'],
        isTrue,
      );
      expect(
        () => project([
          assistant('d2', [
            toolBlock(
              'stream_bad',
              'streaming',
              input: 'ok${String.fromCharCode(0xd800)}',
            ),
          ]),
        ]),
        throwsFormatException,
      );

      // Page-level item/node/byte budgets throw OpenCodeHistoryBudgetException
      // (distinct from FormatException so the reader can adaptively halve).
      expect(
        () => project(
          List.generate(
            40,
            (i) => assistant('$i', List.generate(128, (_) => textBlock(''))),
          ),
        ),
        throwsA(isA<OpenCodeHistoryBudgetException>()),
      );
      expect(
        () => project([
          message('a', 'user', {'text': ''}),
          message('b', 'user', {'text': ''}),
        ], maxItems: 1),
        throwsA(isA<OpenCodeHistoryBudgetException>()),
      );
      expect(
        () => project([
          for (var i = 0; i < 6; i++)
            message('big_$i', 'user', {'text': 'z' * (200 * 1024)}),
        ]),
        throwsA(isA<OpenCodeHistoryBudgetException>()),
      );
      expect(
        () => project([
          message('a', 'user', {'text': ''}),
          message('a', 'user', {'text': ''}),
        ]),
        throwsFormatException,
      );
    },
  );

  test(
    'history classifies built-in tools, projects shell ToolRunFacts, and copies reasoning part times',
    () {
      final items = project([
        assistant('a', [
          {
            'type': 'reasoning',
            'text': 'Checking files',
            'time': {'created': 1000, 'completed': 3500},
          },
          {'type': 'reasoning', 'text': 'No time block'},
          {
            ...toolBlock(
              's1',
              'completed',
              name: 'shell',
              input: {'command': 'ls'},
            ),
            'state': {
              'status': 'completed',
              'input': {'command': 'ls'},
              'content': [
                {'type': 'text', 'text': 'a.dart'},
              ],
              'metadata': PrivateToolFields(
                {
                  'shellID': 'sh_hist1',
                  'exit': 124,
                  'status': 'timeout',
                  'timeout': true,
                  'interrupted': false,
                  'background': false,
                  'truncated': false,
                  'file': '/tmp/nope',
                  'cwd': '/home/nope',
                  'pid': 99,
                },
                {'file', 'cwd', 'pid'},
              ),
            },
          },
          toolBlock('e1', 'completed', name: 'patch'),
          toolBlock('g1', 'completed', name: 'grep'),
          toolBlock('w1', 'completed', name: 'webfetch'),
          toolBlock('ws1', 'completed', name: 'websearch'),
          toolBlock('sk1', 'completed', name: 'skill'),
          toolBlock('q1', 'completed', name: 'question'),
          toolBlock('ex1', 'completed', name: 'execute'),
        ], completed: true),
      ]);
      final r1 = items[0] as Reasoning;
      expect(
        r1.started,
        DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true),
      );
      expect(
        r1.completed,
        DateTime.fromMillisecondsSinceEpoch(3500, isUtc: true),
      );
      expect(r1.duration, const Duration(milliseconds: 2500));
      final r2 = items[1] as Reasoning;
      expect(r2.started, isNull);
      expect(r2.completed, isNull);
      expect(r2.duration, isNull);

      final shell = items[2] as ToolCall;
      expect(shell.kind.known, ToolKind.shell);
      expect(shell.runFacts?.shellId, 'sh_hist1');
      expect(shell.runFacts?.exitCode, 124);
      expect(shell.runFacts?.shellStatus?.known, ShellStatus.timeout);
      expect(shell.runFacts?.timedOut, isTrue);

      expect((items[3] as ToolCall).kind.known, ToolKind.edit);
      expect((items[4] as ToolCall).kind.known, ToolKind.search);
      expect((items[5] as ToolCall).kind.known, ToolKind.fetch);
      expect((items[6] as ToolCall).kind.known, ToolKind.webSearch);
      expect((items[7] as ToolCall).kind.known, ToolKind.skill);
      expect((items[8] as ToolCall).kind.known, ToolKind.question);
      expect((items[9] as ToolCall).kind.known, ToolKind.other);
    },
  );

  test(
    'history supports v2.3+ firstToken, skill, location-switched, idle direct error, and interrupted shell tool',
    () {
      final items = project([
        {
          'id': 'msg_asst',
          'type': 'assistant',
          'time': {'created': 1000, 'firstToken': 1100, 'completed': 2000},
          'content': [
            {
              'type': 'tool',
              'id': 'call_sh',
              'name': 'shell',
              'time': {'created': 1000},
              'state': {
                'status': 'error',
                'input': {'command': 'sleep 99'},
                'error': {
                  'type': 'tool.execution',
                  'message': 'Command cancelled',
                },
                'metadata': {'interrupted': true},
              },
            },
          ],
        },
        message('sk_h', 'skill', {'name': 'dart-lint'}),
        message('mv_same', 'location-switched', {
          'location': {'directory': '/a'},
          'previous': {
            'location': {'directory': '/a'},
          },
        }),
        message('mv_diff', 'location-switched', {
          'location': {'directory': '/b'},
          'previous': {
            'location': {'directory': '/a'},
          },
        }),
        message('idle_err', 'idle', {
          'outcome': 'failed',
          'error': {
            'type': 'provider.budget-limit',
            'message': 'Budget exhausted',
          },
        }),
      ]);
      expect(items, hasLength(4)); // mv_same omitted
      expect((items[0] as ToolCall).status.known, ItemStatus.interrupted);
      final skill = items[1] as Notice;
      expect(skill.kind.known, NoticeKind.skillActivated);
      expect(skill.text, 'dart-lint');
      final moved = items[2] as Notice;
      expect(moved.kind.known, NoticeKind.system);
      expect(moved.text, '/b');
      final outcome = items[3] as TurnOutcome;
      expect(outcome.kind.known, OutcomeKind.failed);
      expect(outcome.error?.kind.known, ErrorKind.quota);
      expect(outcome.error?.rawMessage, 'Budget exhausted');
    },
  );
}
