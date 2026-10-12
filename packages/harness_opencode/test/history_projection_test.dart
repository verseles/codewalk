import 'dart:convert';
import 'dart:io';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:harness_opencode/src/history_projection.dart';
import 'package:test/test.dart';

import 'history_test_data.dart';
import 'support/fixture_replay.dart';

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
      expect(tool.error!.rawMessage, isEmpty);
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
    'assistant empty/error/retry and unsupported native kinds preserve explicit markers, never invented outcomes',
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
      expect(items.whereType<UnknownItem>(), hasLength(5));
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
      expect((items[2] as UnknownItem).raw.value, containsPair('attempt', 1));
    },
  );

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
