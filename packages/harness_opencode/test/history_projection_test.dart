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
      expect(() => project(rows), throwsFormatException);
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
      expect(attached.whereType<UserInput>().single.attachments, isEmpty);
      final manifest = attached.whereType<UnknownItem>().firstWhere(
        (i) => i.rawType == 'user-context-manifest',
      );
      expect(((manifest.raw.value as Map)['files'] as List).single, {
        'mime': 'image/png',
        'sourceKind': 'inline',
      });
      final encoded = jsonEncode(attached.map(semanticItem).toList());
      expect(encoded, isNot(contains('iVBORw0')));
      expect(encoded, isNot(contains('capture.png')));
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
        message('c', 'compaction', {'summary': 'private context'}),
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
    'depth/node/structured byte/fanout budgets reject before publishing a partial result',
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
      expect(
        () => project([
          assistant('a', [
            toolBlock('id', 'running', input: {'value': 'x' * 65536}),
          ]),
        ]),
        throwsFormatException,
      );
      expect(
        () => project(
          List.generate(
            40,
            (i) => assistant('$i', List.generate(128, (_) => textBlock(''))),
          ),
        ),
        throwsFormatException,
      );
      expect(
        () => project([
          message('a', 'user', {'text': ''}),
          message('b', 'user', {'text': ''}),
        ], maxItems: 1),
        throwsFormatException,
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
}
