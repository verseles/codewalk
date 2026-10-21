import 'dart:convert';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:harness_opencode/harness_opencode.dart';
import 'package:harness_opencode/src/history_projection.dart';
import 'package:test/test.dart';

import 'history_test_data.dart';
import 'tool_test_data.dart';

void main() {
  Matcher fails(OpenCodeToolProjectionFailure failure) => throwsA(
    isA<OpenCodeToolProjectionException>().having(
      (e) => e.failure,
      'failure',
      failure,
    ),
  );

  test(
    'source-shaped lifecycle: structured input and terminal authority only',
    () {
      var state = startedTool();
      final start = state.timeline.single as ToolCall;
      expect(
        start.id.value,
        jsonEncode([
          historyRef.storageKey,
          'msg_a',
          'tool',
          'functions.read:0',
        ]),
      );
      expect(
        start.generation,
        jsonEncode([
          'live',
          historyRef.storageKey,
          'msg_a',
          'observer-a',
          'epoch-a',
        ]),
      );
      expect(start.kind.known, ToolKind.read);
      expect(start.status.known, ItemStatus.streaming);
      expect(start.input, isNull);
      expect(start.meta.ordinal, isNull);
      expect(start.turnId, isNull);
      for (final phase in ['input.delta', 'input.ended', 'progress']) {
        expect(projectTool(toolFrame(phase), current: state), isNull);
      }
      state = applyTool(toolFrame('called', id: 'evt_call'), state, 2);
      final called = state.timeline.single as ToolCall;
      expect(called.input!.value, {'path': 'file.txt'});
      expect(called.status.known, ItemStatus.streaming);
      expect(called.source.extra!.value, containsPair('executed', false));
      state = applyTool(toolFrame('success', id: 'evt_success'), state, 3);
      final terminal = state.timeline.single as ToolCall;
      expect(terminal.status.known, ItemStatus.completed);
      expect(terminal.input, called.input);
      expect(terminal.output!.value, [
        {'type': 'text', 'text': 'result'},
      ]);
      expect(terminal.source.aggregateSeq, BigInt.zero);
      expect(
        terminal.source.extra!.value,
        containsPair('nativeDurableVersion', 2),
      );
      expect(state.execution, isNull);
      expect(state.interactions, isEmpty);
    },
  );

  test(
    'plain schema strings: empty name/call, colon ID, unknown tool kind',
    () {
      for (final call in ['', 'functions.read:0', 'no-prefix']) {
        final event =
            projectTool(toolFrame('input.started', call: call, name: ''))!
                as ItemUpserted;
        final item = event.item as ToolCall;
        expect(item.rawName, '');
        expect(item.kind.known, ToolKind.other);
        expect(
          item.id.value,
          jsonEncode([historyRef.storageKey, 'msg_a', 'tool', call]),
        );
      }
      final frame = toolFrame('input.started')..['created'] = -0.5;
      final event = projectTool(frame, version: '2.0.22+build.1')!;
      expect(
        event.meta.source.extra!.value,
        containsPair('nativeCreated', -0.5),
      );
      expect(event.meta.source.version, '2.0.22+build.1');
    },
  );

  test(
    'repeated/late starts preserve prefix; observed name conflicts recover',
    () {
      final state = applyTool(
        toolFrame('called', id: 'evt_call'),
        startedTool(),
        2,
      );
      expect(
        projectTool(
          toolFrame('input.started', id: 'evt_again'),
          current: state,
        ),
        isNull,
      );
      final changed =
          projectTool(
                toolFrame('input.started', name: 'shell'),
                current: state,
              )!
              as ResyncRequired;
      expect(changed.reason, 'toolNameMismatch');
      expect(
        reduce(state, changed).state.timeline.single,
        same(state.timeline.single),
      );
      final settled = applyTool(
        toolFrame('success', id: 'evt_success'),
        state,
        3,
      );
      expect(
        projectTool(
          toolFrame('input.started', id: 'evt_late'),
          current: settled,
        ),
        isNull,
      );
      expect(
        projectTool(toolFrame('called', id: 'evt_late_call'), current: settled),
        isNull,
      );
    },
  );

  test(
    'missing observed name, history and different caller epochs request recovery',
    () {
      for (final phase in ['called', 'success', 'failed']) {
        final event = projectTool(toolFrame(phase))! as ResyncRequired;
        expect(event.reason, 'toolStartMissing');
        final result = reduce(SessionState(historyRef), event);
        expect(result.state.timeline, isEmpty);
        expect(
          result.effects.whereType<Rehydrate>().single.reason,
          'toolStartMissing',
        );
        expect(toolManifest(event), isNot(contains('file.txt')));
      }
      final history = projectOpenCodeHistory(
        [
          assistant('a', [toolBlock('functions.read:0', 'completed')]),
        ],
        historyRef,
        sourceVersion: '2.0.22',
      );
      final historyState = residentState(history.single);
      expect(
        (projectTool(toolFrame('success'), current: historyState)!
                as ResyncRequired)
            .reason,
        'toolResidentIncompatible',
      );
      final live = startedTool();
      final changedEpoch = projectTool(
        toolFrame('success'),
        current: live,
        epoch: 'epoch-b',
      )!;
      final result = reduce(live, changedEpoch);
      expect(result.state, same(live));
      expect(
        result.effects.whereType<Rehydrate>().single.reason,
        'streamGenerationMismatch',
      );
    },
  );

  test('resident kind/provenance collisions cannot carry unrelated state', () {
    final live = startedTool();
    final old = live.timeline.single as ToolCall;
    final collision = residentState(
      AssistantText(meta: old.meta, text: 'prefix', complete: false),
    );
    expect(
      () => projectTool(toolFrame('success'), current: collision),
      fails(OpenCodeToolProjectionFailure.itemKindMismatch),
    );
    for (final source in [
      SourceProvenance(
        harness: historyHarness,
        version: '2.0.21',
        nativeType: 'session.tool.called',
      ),
      SourceProvenance(
        harness: historyHarness,
        version: '2.0.22',
        nativeType: 'session.tool.progress',
        nativeEventId: 'evt_fake',
        extra: CanonicalValue({
          'nativeMessageId': 'msg_a',
          'nativeToolCallId': 'functions.read:0',
        }),
      ),
    ]) {
      final bad = ToolCall(
        meta: ItemMeta(
          id: old.id,
          generation: old.generation,
          status: old.status,
          source: source,
        ),
        kind: old.kind,
        rawName: old.rawName,
        input: CanonicalValue({'token': 'fake-private'}),
      );
      expect(
        projectTool(toolFrame('success'), current: residentState(bad)),
        isA<ResyncRequired>(),
      );
    }
  });

  test(
    'missing or foreign resident aggregate provenance requests recovery',
    () {
      final original = startedTool().timeline.single as ToolCall;
      for (final (aggregateId, aggregateSeq) in <(String?, BigInt?)>[
        (null, original.source.aggregateSeq),
        ('ses_other', original.source.aggregateSeq),
        (original.source.aggregateId, null),
      ]) {
        final resident = ToolCall(
          meta: ItemMeta(
            id: original.id,
            generation: original.generation,
            status: original.status,
            source: SourceProvenance(
              harness: original.source.harness,
              version: original.source.version,
              nativeType: original.source.nativeType,
              nativeEventId: original.source.nativeEventId,
              aggregateId: aggregateId,
              aggregateSeq: aggregateSeq,
              durability: original.source.durability,
              extra: original.source.extra,
            ),
          ),
          kind: original.kind,
          rawName: original.rawName,
          input: CanonicalValue({'path': 'resident-private'}),
        );
        final state = residentState(resident);
        final event = projectTool(toolFrame('success'), current: state)!;
        expect(event, isA<ResyncRequired>());
        expect((event as ResyncRequired).reason, 'toolResidentIncompatible');
        expect(toolManifest(event), isNot(contains('resident-private')));
        final result = reduce(state, event);
        expect(result.state.timeline.single, same(resident));
        expect(
          result.effects.whereType<Rehydrate>().single.reason,
          'toolResidentIncompatible',
        );
      }
    },
  );

  test(
    'redaction matches history for all normalized nested credential keys',
    () {
      const input = <String, Object?>{
        'path': 'visible',
        'password': 'fake-private',
        'passwd': 'fake-private',
        'secret': 'fake-private',
        'api_key': 'fake-private',
        'X-Api-Key': 'fake-private',
        'token': 'fake-private',
        'access_token': 'fake-private',
        'refresh_token': 'fake-private',
        'api_token': 'fake-private',
        'private_key': 'fake-private',
        'client_secret': 'fake-private',
        'provider_state': 'fake-private',
        'list': [
          {
            'Authorization': 'fake-private',
            'provider_result_state': {'token': 'fake-private'},
          },
        ],
      };
      final event =
          projectTool(
                toolFrame('called', input: input),
                current: startedTool(),
              )!
              as ItemUpserted;
      final item = event.item as ToolCall;
      final history =
          projectOpenCodeHistory(
                [
                  assistant('a', [
                    toolBlock('functions.read:0', 'running', input: input),
                  ]),
                ],
                historyRef,
                sourceVersion: '2.0.22',
              ).single
              as ToolCall;
      expect(item.input, history.input);
      expect((item.input!.value as Map)['path'], 'visible');
      expect(item.source.extra!.value, containsPair('inputRedacted', true));
      expect(toolManifest(event), isNot(contains('fake-private')));
      final carried =
          projectTool(toolFrame('success'), current: residentState(item))!
              as ItemUpserted;
      expect((carried.item as ToolCall).input, item.input);
      expect(
        carried.item.source.extra!.value,
        containsPair('inputRedacted', true),
      );
    },
  );

  test('keys are measured as kept, not as redacted', () {
    // Keys keep their text: one that reads like a credential assignment must
    // still count at its full size.
    final input = <String, Object?>{
      'token=${'a' * 40000}': 1,
      'token=${'b' * 40000}': 2,
    };
    expect(
      () => projectTool(
        toolFrame('called', input: input),
        current: startedTool(),
      ),
      fails(OpenCodeToolProjectionFailure.limitExceeded),
    );
  });

  test('redaction expansion is bounded before canonical copy', () {
    final state = startedTool();
    final dense = <String, Object?>{
      'entries': List.generate(3000, (_) => <String, Object?>{'token': 0}),
    };
    expect(utf8.encode(jsonEncode(dense)).length, lessThan(65536));
    expect(
      () => projectTool(toolFrame('called', input: dense), current: state),
      fails(OpenCodeToolProjectionFailure.limitExceeded),
    );
    expect((state.timeline.single as ToolCall).input, isNull);
    final bounded = <String, Object?>{
      'entries': List.generate(1000, (_) => <String, Object?>{'token': 0}),
    };
    final event =
        projectTool(toolFrame('called', input: bounded), current: state)!
            as ItemUpserted;
    final input = (event.item as ToolCall).input!.value;
    expect(utf8.encode(jsonEncode(input)).length, lessThanOrEqualTo(65536));
    expect((input as Map)['entries'], everyElement({'token': '[redacted]'}));
  });

  test(
    'carried input is re-sanitized/re-bounded without copying resident extras',
    () {
      final original = startedTool().timeline.single as ToolCall;
      final source = SourceProvenance(
        harness: original.source.harness,
        version: original.source.version,
        nativeType: original.source.nativeType,
        nativeEventId: original.source.nativeEventId,
        aggregateId: original.source.aggregateId,
        aggregateSeq: original.source.aggregateSeq,
        durability: original.source.durability,
        extra: CanonicalValue({
          ...original.source.extra!.value as Map<String, Object?>,
          'privateProviderData': 'fake-private-provider',
        }),
      );
      ToolCall withInput(Object? input) => ToolCall(
        meta: ItemMeta(
          id: original.id,
          generation: original.generation,
          status: original.status,
          source: source,
        ),
        kind: original.kind,
        rawName: original.rawName,
        input: CanonicalValue(input),
      );
      final resident = withInput({'Authorization': 'fake-private-token'});
      final event =
          projectTool(toolFrame('success'), current: residentState(resident))!
              as ItemUpserted;
      expect((event.item as ToolCall).input!.value, {
        'Authorization': '[redacted]',
      });
      expect(toolManifest(event), isNot(contains('fake-private')));
      final over = residentState(withInput({'value': 'a' * 65536}));
      expect(
        () => projectTool(toolFrame('success'), current: over),
        fails(OpenCodeToolProjectionFailure.limitExceeded),
      );
      expect(over.timeline.single.status.known, ItemStatus.streaming);
      final wrongInput = residentState(withInput('raw private arguments'));
      expect(
        () => projectTool(toolFrame('success'), current: wrongInput),
        fails(OpenCodeToolProjectionFailure.malformed),
      );
    },
  );

  test(
    'terminal failure is self-contained and may replace an older terminal',
    () {
      var state = applyTool(
        toolFrame('success', id: 'evt_success'),
        startedTool(),
        2,
      );
      final failed =
          projectTool(
                toolFrame('failed', id: 'evt_fail'),
                current: state,
                seq: 3,
              )!
              as ItemUpserted;
      final item = failed.item as ToolCall;
      expect(item.status.known, ItemStatus.interrupted);
      expect(item.output, isNull);
      // The message is shown, redacted and bounded (V2-044D).
      expect(item.error!.rawMessage, 'Tool execution interrupted');
      expect(item.error!.rawType, 'aborted');
      expect(item.error!.retryable, isFalse);
      expect(item.error!.action, isNull);
      state = reduce(state, failed).state;
      final success = projectTool(
        toolFrame('success', id: 'evt_new'),
        current: state,
        seq: 4,
      )!;
      state = reduce(state, success).state;
      expect(state.timeline.single.status.known, ItemStatus.completed);
      expect((state.timeline.single as ToolCall).error, isNull);
      expect(reduce(state, success).state, same(state));
      final late = projectTool(
        toolFrame('failed', id: 'evt_late'),
        current: state,
        seq: 2,
      )!;
      expect(
        (reduce(state, late).state.timeline.single as ToolCall).output,
        (state.timeline.single as ToolCall).output,
      );
      final partial = toolFrame('failed', id: 'evt_partial');
      toolData(partial)['content'] = [
        {'type': 'text', 'text': 'partial'},
      ];
      toolData(partial)['error'] = {'type': 'tool-error'};
      final projected =
          (projectTool(partial, current: state, seq: 5)! as ItemUpserted).item
              as ToolCall;
      expect(projected.status.known, ItemStatus.failed);
      expect(projected.output!.value, [
        {'type': 'text', 'text': 'partial'},
      ]);
      toolData(partial)['error'] = {'type': ''};
      expect(
        () => projectTool(partial, current: state),
        fails(OpenCodeToolProjectionFailure.unsupportedValue),
      );
    },
  );

  test(
    'unselected fields are never read; terminal whitelist and file markers',
    () {
      final frame = toolFrame('failed');
      final data = toolData(frame);
      data['error'] = PrivateToolFields(
        {
          'type': 'aborted',
          'message': 'failed with token=fake-private-secret',
          'status': 500,
          'response': 'fake-private',
        },
        {'status', 'response'},
      );
      data['content'] = [
        PrivateToolFields(
          {
            'type': 'file',
            'mime': 'text/plain',
            'uri': 'fake-private',
            'name': 'fake-private',
          },
          {'uri', 'name'},
        ),
      ];
      data['metadata'] = PrivateToolFields(
        {
          'truncated': false,
          'shellID': 'fake-private',
          'status': 'fake-private',
          'exit': 1,
        },
        {'shellID', 'status', 'exit'},
      );
      data['resultState'] = 'fake-private';
      frame['data'] = PrivateToolFields(data, {'resultState'});
      frame['location'] = 'fake-private';
      frame['metadata'] = 'fake-private';
      final event =
          projectTool(
                PrivateToolFields(frame, {'location', 'metadata'}),
                current: startedTool(),
              )!
              as ItemUpserted;
      final item = event.item as ToolCall;
      expect(item.output!.value, [
        {'type': 'file', 'mime': 'text/plain', 'available': false},
      ]);
      expect(
        item.source.extra!.value,
        containsPair('outputContentOmitted', true),
      );
      expect(item.source.extra!.value, containsPair('truncated', false));
      // The selected error message is shown only after redaction.
      expect(item.error!.rawMessage, 'failed with token=[redacted]');
      expect(item.source.extra!.value, containsPair('errorRedacted', true));
      expect(toolManifest(event), isNot(contains('fake-private')));
      expect(event.meta.rawRef, isNull);
      expect(event.meta.source.nativeCursor, isNull);
      final called = toolFrame('called');
      toolData(called)['state'] = 'fake-private';
      called['data'] = PrivateToolFields(toolData(called), {'state'});
      expect(projectTool(called, current: startedTool()), isA<ItemUpserted>());
      final progress = toolFrame('progress');
      toolData(progress)['metadata'] = PrivateToolFields(
        {'shellID': 'fake-private'},
        {'shellID'},
      );
      expect(projectTool(progress, current: startedTool()), isNull);
    },
  );

  test(
    'selected malformed shapes have finite failures without native content',
    () {
      final mutations = <void Function(Map<String, Object?>)>[
        (f) => f.remove('type'),
        (f) => f['type'] = 7,
        (f) => f.remove('id'),
        (f) => f['id'] = 'fake-private',
        (f) => f.remove('data'),
        (f) => f['data'] = [],
        (f) => f.remove('created'),
        (f) => f['created'] = double.infinity,
        (f) => toolData(f)['sessionID'] = 'bad',
        (f) => toolData(f)['assistantMessageID'] = 'bad',
        (f) => toolData(f)['id'] = null,
        (f) => toolData(f)['name'] = null,
        (f) => f.remove('durable'),
        (f) => (f['durable']! as Map)['aggregateID'] = 'ses_other',
        (f) => (f['durable']! as Map)['seq'] = -1,
        (f) => (f['durable']! as Map)['seq'] = 0.5,
        (f) => (f['durable']! as Map)['seq'] = 9007199254740992,
      ];
      for (final mutate in mutations) {
        final frame = toolFrame('input.started');
        mutate(frame);
        expect(
          () => projectTool(frame),
          fails(OpenCodeToolProjectionFailure.malformed),
        );
      }
      for (final phase in ['input.delta', 'progress']) {
        final frame = toolFrame(phase)..['durable'] = {'version': 1};
        expect(
          () => projectTool(frame),
          fails(OpenCodeToolProjectionFailure.malformed),
        );
      }
      for (final phase in [
        'input.delta',
        'input.ended',
        'progress',
        'called',
        'success',
        'failed',
      ]) {
        final frame = toolFrame(phase);
        final key = {
          'input.delta': 'delta',
          'input.ended': 'text',
          'progress': 'metadata',
          'called': 'input',
          'success': 'content',
          'failed': 'error',
        }[phase]!;
        toolData(frame)[key] = null;
        expect(
          () => projectTool(frame, current: startedTool()),
          fails(OpenCodeToolProjectionFailure.malformed),
        );
      }
      for (final version in [
        '2.0.21',
        '2.0.23',
        '2.0.22-rc.1',
        'fake-private',
      ]) {
        expect(
          () => projectTool(toolFrame('input.started'), version: version),
          fails(OpenCodeToolProjectionFailure.unsupportedVersion),
        );
      }
      for (final phase in ['input.started', 'success', 'failed']) {
        final frame = toolFrame(phase);
        (frame['durable']! as Map)['version'] = phase == 'input.started'
            ? 2
            : 1;
        expect(
          () => projectTool(frame),
          fails(OpenCodeToolProjectionFailure.unsupportedVersion),
        );
      }
      expect(
        const OpenCodeToolProjectionException(
          OpenCodeToolProjectionFailure.malformed,
        ).toString(),
        'OpenCodeToolProjectionException(malformed)',
      );
      expect(projectTool({'type': 'server.connected'}), isNull);
      expect(projectTool({'type': 'session.tool.future'}), isNull);
      expect(
        projectTool(
          toolFrame('success', session: 'ses_foreign'),
          version: 'invalid',
        ),
        isNull,
      );
    },
  );

  test(
    'selected content rejects limits, escapes, invalid Unicode and JSON atomically',
    () {
      final state = startedTool();
      for (final text in ['a' * 4097, 'é' * 2049]) {
        expect(
          () => projectTool(toolFrame('input.started', name: text)),
          fails(OpenCodeToolProjectionFailure.limitExceeded),
        );
      }
      for (final text in ['\ud800', '\udc00', '\ud800x']) {
        expect(
          () => projectTool(toolFrame('input.started', name: text)),
          fails(OpenCodeToolProjectionFailure.malformed),
        );
      }
      expect(
        projectTool(toolFrame('input.started', name: '😀' * 1024)),
        isA<ItemUpserted>(),
      );
      for (final phase in ['input.delta', 'input.ended']) {
        final frame = toolFrame(phase);
        toolData(frame)[phase == 'input.delta' ? 'delta' : 'text'] =
            'a' * 65537;
        expect(
          () => projectTool(frame, current: state),
          fails(OpenCodeToolProjectionFailure.limitExceeded),
        );
      }
      Object? deep = 0;
      for (var i = 0; i < 17; i++) {
        deep = [deep];
      }
      for (final input in [
        {'value': 'a' * 65536},
        {'value': '\u0001' * 11000},
        {'value': deep},
        {'value': List.filled(16384, 0)},
      ]) {
        expect(
          () => projectTool(toolFrame('called', input: input), current: state),
          fails(OpenCodeToolProjectionFailure.limitExceeded),
        );
      }
      expect(
        () => projectTool(
          toolFrame('called', input: {'value': double.nan}),
          current: state,
        ),
        fails(OpenCodeToolProjectionFailure.malformed),
      );
      expect(
        () => projectTool(
          toolFrame('called', input: {'value': Object()}),
          current: state,
        ),
        fails(OpenCodeToolProjectionFailure.unsupportedValue),
      );
      for (final content in [
        <Object?>[],
        [
          {'type': 'future'},
        ],
      ]) {
        expect(
          () => projectTool(
            toolFrame('success', content: content),
            current: state,
          ),
          fails(OpenCodeToolProjectionFailure.malformed),
        );
      }
      final part = {'type': 'text', 'text': ''};
      expect(
        projectTool(
          toolFrame('success', content: List.filled(128, part)),
          current: state,
        ),
        isA<ItemUpserted>(),
      );
      expect(
        () => projectTool(
          toolFrame('success', content: List.filled(129, part)),
          current: state,
        ),
        fails(OpenCodeToolProjectionFailure.limitExceeded),
      );
      expect(
        () => projectTool(
          toolFrame(
            'success',
            content: [
              {'type': 'text', 'text': 'a' * 65536},
            ],
          ),
          current: state,
        ),
        fails(OpenCodeToolProjectionFailure.limitExceeded),
      );
      expect((state.timeline.single as ToolCall).input, isNull);
      expect(state.timeline.single.status.known, ItemStatus.streaming);
    },
  );
}
