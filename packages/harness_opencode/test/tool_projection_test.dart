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

  test('an AWS secret access key under its own key is redacted', () {
    final event =
        projectTool(
              toolFrame(
                'called',
                input: {
                  'AWS_SECRET_ACCESS_KEY': 'wJalrXUtnFEMIK7MDENG',
                  'Proxy-Authorization': 'Negotiate abc',
                  'HTTP_AUTHORIZATION': 'Basic dTpw',
                },
              ),
              current: startedTool(),
            )!
            as ItemUpserted;
    final item = event.item as ToolCall;
    expect(item.input!.value, {
      'AWS_SECRET_ACCESS_KEY': '[redacted]',
      'Proxy-Authorization': '[redacted]',
      'HTTP_AUTHORIZATION': '[redacted]',
    });
    expect(item.source.extra!.value, containsPair('inputRedacted', true));
  });

  test('keys are measured as kept, not as redacted, and bounded at 64 KiB', () {
    // Keys keep their text: one that reads like a credential assignment still
    // counts at its full size, so the second 40 KiB key is truncated out.
    final keyA = 'token=${'a' * 40000}';
    final keyB = 'token=${'b' * 40000}';
    final input = <String, Object?>{keyA: 1, keyB: 2};
    final event =
        projectTool(
              toolFrame('called', input: input),
              current: startedTool(),
            )!
            as ItemUpserted;
    final item = event.item as ToolCall;
    final kept = item.input!.value as Map<String, Object?>;
    expect(kept.keys, [keyA]);
    expect(utf8.encode(jsonEncode(kept)).length, lessThanOrEqualTo(65536));
    expect(item.source.extra!.value, containsPair('inputTruncated', true));
  });

  test('redaction expansion is bounded before canonical copy', () {
    final state = startedTool();
    final dense = <String, Object?>{
      'entries': List.generate(3000, (_) => <String, Object?>{'token': 0}),
    };
    expect(utf8.encode(jsonEncode(dense)).length, lessThan(65536));
    final truncatedEvent =
        projectTool(toolFrame('called', input: dense), current: state)!
            as ItemUpserted;
    final truncatedCall = truncatedEvent.item as ToolCall;
    final truncatedInput = truncatedCall.input!.value as Map<String, Object?>;
    expect(
      utf8.encode(jsonEncode(truncatedInput)).length,
      lessThanOrEqualTo(65536),
    );
    expect(
      truncatedInput['entries'],
      everyElement({'token': '[redacted]'}),
    );
    expect(
      (truncatedInput['entries'] as List).length,
      lessThan(3000),
    );
    expect(
      truncatedCall.source.extra!.value,
      containsPair('inputTruncated', true),
    );
    expect(
      truncatedCall.source.extra!.value,
      containsPair('inputRedacted', true),
    );
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
      final boundedOver =
          projectTool(toolFrame('success'), current: over)! as ItemUpserted;
      final boundedItem = boundedOver.item as ToolCall;
      expect(
        utf8.encode(jsonEncode(boundedItem.input!.value)).length,
        lessThanOrEqualTo(65536),
      );
      expect(
        boundedItem.source.extra!.value,
        containsPair('inputTruncated', true),
      );
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
        '3.0.0',
        '2.0.19',
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
      // Discarded raw streaming argument frames allow >64 KiB (up to 16 MiB)
      // while still rejecting lone surrogates.
      for (final phase in ['input.delta', 'input.ended']) {
        final frame = toolFrame(phase);
        final key = phase == 'input.delta' ? 'delta' : 'text';
        toolData(frame)[key] = 'a' * (128 * 1024);
        expect(projectTool(frame, current: state), isNull);
        toolData(frame)[key] = 'bad${String.fromCharCode(0xd800)}';
        expect(
          () => projectTool(frame, current: state),
          fails(OpenCodeToolProjectionFailure.malformed),
        );
      }
      Object? deep = 0;
      for (var i = 0; i < 17; i++) {
        deep = [deep];
      }
      expect(
        () => projectTool(
          toolFrame('called', input: {'value': deep}),
          current: state,
        ),
        fails(OpenCodeToolProjectionFailure.limitExceeded),
      );
      // Oversized tool inputs keep a bounded prefix <= 64 KiB and preserve
      // priority compact-target keys first.
      for (final input in [
        {'value': 'a' * 65536, 'filePath': 'lib/main.dart'},
        {'value': '\u0001' * 11000},
        {'value': List.filled(16384, 0)},
      ]) {
        final event =
            projectTool(toolFrame('called', input: input), current: state)!
                as ItemUpserted;
        final call = event.item as ToolCall;
        expect(
          utf8.encode(jsonEncode(call.input!.value)).length,
          lessThanOrEqualTo(65536),
        );
        expect(call.source.extra!.value, containsPair('inputTruncated', true));
        if (input.containsKey('filePath')) {
          expect(
            (call.input!.value as Map<String, Object?>)['filePath'],
            'lib/main.dart',
          );
          // Subsequent terminal events preserve inputTruncated from called.
          final calledSeq2 =
              projectTool(
                    toolFrame('called', id: 'evt_called_trunc', input: input),
                    current: state,
                    seq: 2,
                  )!
                  as ItemUpserted;
          final afterCalled = reduce(state, calledSeq2).state;
          final done =
              projectTool(
                    toolFrame('success', id: 'evt_done_trunc'),
                    current: afterCalled,
                    seq: 3,
                  )!
                  as ItemUpserted;
          expect(
            (done.item as ToolCall).source.extra!.value,
            containsPair('inputTruncated', true),
          );
        }
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
      // >128 parts and >64 KiB output truncate cleanly with outputRef.
      final manyParts =
          projectTool(
                toolFrame('success', content: List.filled(129, part)),
                current: state,
              )!
              as ItemUpserted;
      final manyCall = manyParts.item as ToolCall;
      expect(manyCall.output!.value as List, hasLength(128));
      expect(manyCall.outputRef?.id, 'functions.read:0');
      expect(manyCall.outputRef?.truncated, isTrue);
      expect(
        manyCall.source.extra!.value,
        containsPair('outputTruncated', true),
      );

      final bigOutput =
          projectTool(
                toolFrame(
                  'success',
                  content: [
                    {'type': 'text', 'text': 'a' * 80000},
                  ],
                ),
                current: state,
              )!
              as ItemUpserted;
      final bigCall = bigOutput.item as ToolCall;
      expect(
        utf8.encode(jsonEncode(bigCall.output!.value)).length,
        lessThanOrEqualTo(65536),
      );
      expect(bigCall.outputRef?.id, 'functions.read:0');
      expect(bigCall.outputRef?.truncated, isTrue);
      expect(
        bigCall.source.extra!.value,
        containsPair('outputTruncated', true),
      );

      // Oversized tool error (>256 KiB) bounds to 8 KiB redacted prefix (#432).
      final failedFrame = toolFrame('failed');
      toolData(failedFrame)['error'] = {
        'type': 'tool.execution',
        'message': '${'e' * 8180} token=topsecret999 ${'x' * 300000}',
      };
      final failedEvent =
          projectTool(failedFrame, current: state)! as ItemUpserted;
      final failedCall = failedEvent.item as ToolCall;
      expect(
        utf8.encode(failedCall.error!.rawMessage).length,
        lessThanOrEqualTo(8 * 1024),
      );
      expect(failedCall.error!.rawMessage, isNot(contains('topsecret999')));
      expect(
        failedCall.error!.details!.value,
        containsPair('messageTruncated', true),
      );
      expect(
        failedCall.error!.details!.value,
        containsPair('messageRedacted', true),
      );
      expect(
        failedCall.source.extra!.value,
        containsPair('errorTruncated', true),
      );
      expect((state.timeline.single as ToolCall).input, isNull);
      expect(state.timeline.single.status.known, ItemStatus.streaming);
    },
  );

  test(
    'built-in OpenCode v2 tool names map to canonical ToolKind without guessing MCP',
    () {
      const expected = {
        'read': ToolKind.read,
        'edit': ToolKind.edit,
        'patch': ToolKind.edit,
        'write': ToolKind.write,
        'grep': ToolKind.search,
        'glob': ToolKind.search,
        'webfetch': ToolKind.fetch,
        'websearch': ToolKind.webSearch,
        'shell': ToolKind.shell,
        'skill': ToolKind.skill,
        'question': ToolKind.question,
        'subagent': ToolKind.subagent,
        'execute': ToolKind.other,
        'session_rename': ToolKind.other,
        'github_create_issue': ToolKind.other,
      };
      for (final entry in expected.entries) {
        final event =
            projectTool(toolFrame('input.started', name: entry.key))!
                as ItemUpserted;
        final item = event.item as ToolCall;
        expect(item.kind.known, entry.value, reason: entry.key);
      }
    },
  );

  test(
    'shell tool projects progress shellID and terminal ToolRunFacts without reading host paths or PIDs',
    () {
      var state = SessionState(historyRef);
      state = reduce(
        state,
        projectTool(
          toolFrame('input.started', id: 'evt_sh_1', name: 'shell'),
          current: state,
        )!,
      ).state;
      state = reduce(
        state,
        projectTool(
          toolFrame('called', id: 'evt_sh_2', input: {'command': 'make test'}),
          current: state,
          seq: 2,
        )!,
      ).state;
      final progress = toolFrame('progress', id: 'evt_sh_3');
      toolData(progress)['metadata'] = PrivateToolFields(
        {
          'shellID': 'sh_abc123',
          'file': '/tmp/private',
          'cwd': '/home/private',
          'pid': 4242,
        },
        {'file', 'cwd', 'pid'},
      );
      final progEvent =
          projectTool(progress, current: state, seq: 3)! as ItemUpserted;
      state = reduce(state, progEvent).state;
      expect(
        (state.timeline.single as ToolCall).runFacts?.shellId,
        'sh_abc123',
      );
      // Identical progress metadata is a no-op.
      final progressDup = toolFrame('progress', id: 'evt_sh_3b');
      toolData(progressDup)['metadata'] = {'shellID': 'sh_abc123'};
      expect(projectTool(progressDup, current: state, seq: 4), isNull);

      final success = toolFrame(
        'success',
        id: 'evt_sh_4',
        content: [
          {'type': 'text', 'text': 'ok'},
        ],
      );
      toolData(success)['metadata'] = PrivateToolFields(
        {
          'status': 'running',
          'background': true,
          'truncated': false,
          'file': '/tmp/private',
          'cwd': '/home/private',
          'pid': 4242,
        },
        {'file', 'cwd', 'pid'},
      );
      final doneEvent =
          projectTool(success, current: state, seq: 5)! as ItemUpserted;
      state = reduce(state, doneEvent).state;
      final tool = state.timeline.single as ToolCall;
      expect(tool.runFacts?.shellId, 'sh_abc123');
      expect(tool.runFacts?.background, isTrue);
      expect(tool.runFacts?.shellStatus?.known, ShellStatus.running);
      expect(tool.runFacts?.exitCode, isNull);
    },
  );

  test(
    'shell tool metadata enforces UTF-8 byte cap and valid UTF-16 surrogates',
    () {
      var state = SessionState(historyRef);
      state = reduce(
        state,
        projectTool(
          toolFrame('input.started', id: 'evt_sh_utf1', name: 'shell'),
          current: state,
        )!,
      ).state;

      // 2000 3-byte chars = 2000 UTF-16 units (<4096) but 6000 UTF-8 bytes (>4096).
      final overUtf8 = toolFrame('progress', id: 'evt_sh_utf2');
      toolData(overUtf8)['metadata'] = {'shellID': '€' * 2000};
      expect(
        () => projectTool(overUtf8, current: state, seq: 2),
        fails(OpenCodeToolProjectionFailure.limitExceeded),
      );

      final unpairedHigh = toolFrame('progress', id: 'evt_sh_utf3');
      toolData(unpairedHigh)['metadata'] = {
        'shellID': 'sh_${String.fromCharCode(0xd800)}',
      };
      expect(
        () => projectTool(unpairedHigh, current: state, seq: 3),
        fails(OpenCodeToolProjectionFailure.malformed),
      );

      final unpairedStatus = toolFrame(
        'success',
        id: 'evt_sh_utf4',
        content: const [],
      );
      toolData(unpairedStatus)['metadata'] = {
        'status': 'bad_${String.fromCharCode(0xdc00)}',
      };
      expect(
        () => projectTool(unpairedStatus, current: state, seq: 4),
        fails(OpenCodeToolProjectionFailure.malformed),
      );
    },
  );

  test(
    'shell tool cancellation and metadata.interrupted project as interrupted',
    () {
      var state = SessionState(historyRef);
      state = reduce(
        state,
        projectTool(
          toolFrame('input.started', id: 'evt_sh_c1', name: 'shell'),
          current: state,
        )!,
      ).state;
      final cancelled = toolFrame('failed', id: 'evt_sh_c2');
      toolData(cancelled)['error'] = {
        'type': 'tool.execution',
        'message': 'Command cancelled',
      };
      final done =
          projectTool(cancelled, current: state, seq: 2)! as ItemUpserted;
      expect(done.item.status.known, ItemStatus.interrupted);

      final interruptedByMeta = toolFrame('failed', id: 'evt_sh_c3');
      toolData(interruptedByMeta)['error'] = {
        'type': 'tool.execution',
        'message': 'Signal received',
      };
      toolData(interruptedByMeta)['metadata'] = {'interrupted': true};
      final doneMeta =
          projectTool(interruptedByMeta, current: state, seq: 3)!
              as ItemUpserted;
      expect(doneMeta.item.status.known, ItemStatus.interrupted);
    },
  );
}
