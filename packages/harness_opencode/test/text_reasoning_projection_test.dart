import 'dart:collection';
import 'dart:convert';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:harness_opencode/harness_opencode.dart';
import 'package:test/test.dart';

import 'history_test_data.dart';
import 'text_reasoning_test_data.dart';

Matcher failsWith(OpenCodeTextProjectionFailure failure) => throwsA(
  isA<OpenCodeTextProjectionException>().having(
    (e) => e.failure,
    'failure',
    failure,
  ),
);

void main() {
  group('source-shaped: text/reasoning mapping', () {
    for (final kind in ['text', 'reasoning']) {
      test('$kind start, deltas and authoritative end', () {
        var state = SessionState(historyRef);
        final start = projectText(textFrame('session.$kind.started'))!;
        expect(start, isA<ItemUpserted>());
        final item = (start as ItemUpserted).item;
        expect(item.status.known, ItemStatus.streaming);
        expect(item.turnId, isNull);
        expect(item.meta.ordinal, 0);
        expect(
          item.id.value,
          jsonEncode([historyRef.storageKey, 'msg_a', kind, 0]),
        );
        state = reduce(state, start).state;
        final delta =
            projectText(
                  textFrame(
                    'session.$kind.delta',
                    id: 'evt_b',
                    content: 'prefix',
                  ),
                  current: state,
                  seq: 2,
                )!
                as ItemDelta;
        expect(
          delta.field.known,
          kind == 'text' ? DeltaField.text : DeltaField.reasoning,
        );
        expect(delta.generation, item.generation);
        state = reduce(state, delta).state;
        final end =
            projectText(
                  textFrame(
                    'session.$kind.ended',
                    id: 'evt_c',
                    content: 'final',
                  ),
                  current: state,
                  seq: 3,
                )!
                as ItemUpserted;
        state = reduce(state, end).state;
        expect(semanticItem(state.timeline.single)['text'], 'final');
        expect(state.timeline.single.status.known, ItemStatus.completed);
        expect(semanticItem(state.timeline.single)['complete'], isTrue);
        expect(switch (state.timeline.single) {
          AssistantText v => v.prefixMissing,
          Reasoning v => v.prefixMissing,
          _ => throw StateError('Expected a text or reasoning item.'),
        }, isFalse);
        final late = projectText(
          textFrame('session.$kind.delta', id: 'evt_d', content: 'late'),
          current: state,
          seq: 4,
        )!;
        expect(
          semanticItem(reduce(state, late).state.timeline.single)['text'],
          'final',
        );
      });

      test('$kind rejects a resident item-kind collision', () {
        final start =
            projectText(textFrame('session.$kind.started'))! as ItemUpserted;
        final unrelated = Notice(
          meta: start.item.meta,
          kind: const OpenValue.known(NoticeKind.system),
          text: 'another canonical producer',
        );
        final current = reduce(
          SessionState(historyRef),
          ItemUpserted(meta: start.meta, item: unrelated),
        ).state;
        expect(
          () => projectText(
            textFrame('session.$kind.delta', id: 'evt_b'),
            current: current,
            seq: 2,
          ),
          failsWith(OpenCodeTextProjectionFailure.itemKindMismatch),
        );
        expect(identical(current.timeline.single, unrelated), isTrue);
      });

      test('$kind repeated distinct start preserves prefix', () {
        var state = applyText(
          textFrame('session.$kind.started'),
          SessionState(historyRef),
          1,
        );
        state = applyText(
          textFrame('session.$kind.delta', id: 'evt_b', content: 'keep'),
          state,
          2,
        );
        final before = state.timeline.single;
        expect(
          projectText(
            textFrame('session.$kind.started', id: 'evt_other_start'),
            current: state,
            seq: 3,
          ),
          isNull,
        );
        expect(identical(state.timeline.single, before), isTrue);
        expect(semanticItem(before)['text'], 'keep');
      });

      test('$kind missing start and ended before start', () {
        final state = SessionState(historyRef);
        final orphan = projectText(textFrame('session.$kind.delta'))!;
        final result = reduce(state, orphan);
        expect(result.state.timeline, isEmpty);
        expect(
          result.effects.whereType<Refetch>().any(
            (e) => e.reason == 'deltaTargetMissing',
          ),
          isTrue,
        );
        final full = projectText(
          textFrame('session.$kind.ended', content: ''),
        )!;
        final complete = reduce(state, full).state;
        expect(semanticItem(complete.timeline.single)['text'], '');
        expect(semanticItem(complete.timeline.single)['complete'], isTrue);
        expect(
          projectText(
            textFrame('session.$kind.started', id: 'evt_late_start'),
            current: complete,
            seq: 2,
          ),
          isNull,
        );
      });

      test('$kind cumulative limit rejects without truncating', () {
        var state = applyText(
          textFrame('session.$kind.started'),
          SessionState(historyRef),
          1,
        );
        for (var index = 0; index < 4; index++) {
          state = applyText(
            textFrame(
              'session.$kind.delta',
              id: 'evt_chunk_$index',
              content: 'x' * 65536,
            ),
            state,
            index + 2,
          );
        }
        final before = state.timeline.single;
        expect((semanticItem(before)['text']! as String).length, 262144);
        expect(
          () => projectText(
            textFrame('session.$kind.delta', id: 'evt_over', content: '😀'),
            current: state,
            seq: 6,
          ),
          failsWith(OpenCodeTextProjectionFailure.limitExceeded),
        );
        expect(identical(state.timeline.single, before), isTrue);
        state = applyText(
          textFrame('session.$kind.ended', id: 'evt_repair', content: 'fixed'),
          state,
          7,
        );
        expect(semanticItem(state.timeline.single)['text'], 'fixed');
      });
    }

    test('same ordinal has separate kind/message/full-session identity', () {
      final a = projectText(textFrame('session.text.started'))! as ItemUpserted;
      final b =
          projectText(textFrame('session.reasoning.started'))! as ItemUpserted;
      final c =
          projectText(textFrame('session.text.started', message: 'msg_other'))!
              as ItemUpserted;
      const another = SessionRef(
        HostId('another-host'),
        HarnessInstanceId('another-harness'),
        'ses_a',
      );
      final d =
          projectText(
                textFrame('session.text.started'),
                current: SessionState(another),
              )!
              as ItemUpserted;
      expect({a.item.id, b.item.id, c.item.id, d.item.id}.length, 4);
      expect(a.item.generation, b.item.generation);
      expect(a.item.generation, isNot(contains('history')));
    });

    test('native provenance and receipt position remain separate', () {
      final frame = textFrame('session.text.ended');
      frame['created'] = -1.25;
      final event = projectText(frame, seq: 99)!;
      expect(event.meta.position.seq, BigInt.from(99));
      expect(event.meta.receivedAt, DateTime.utc(2026, 10, 13));
      expect(event.meta.source.aggregateSeq, BigInt.from(7));
      expect(event.meta.source.nativeEventId, 'evt_a');
      expect(event.meta.source.nativeCursor, isNull);
      expect(event.meta.rawRef, isNull);
      expect(event.meta.source.durability.known, Durability.durable);
      expect((event.meta.source.extra!.value as Map)['nativeCreated'], -1.25);
      final delta = projectText(textFrame('session.text.delta'))!;
      expect(delta.meta.source.durability.known, Durability.ephemeral);
      expect(delta.meta.source.aggregateId, isNull);
      expect(delta.meta.source.aggregateSeq, isNull);
    });

    test('duplicates and incompatible epochs keep reducer guards', () {
      var state = applyText(
        textFrame('session.text.started'),
        SessionState(historyRef),
        1,
      );
      final frame = textFrame(
        'session.text.delta',
        id: 'evt_b',
        content: 'one',
      );
      state = applyText(frame, state, 2);
      final duplicate = projectText(frame, current: state, seq: 3)!;
      expect(identical(reduce(state, duplicate).state, state), isTrue);
      final differentEpoch = projectText(
        textFrame('session.text.delta', id: 'evt_c'),
        current: state,
        seq: 4,
        epoch: 'another-epoch',
      )!;
      final result = reduce(state, differentEpoch);
      expect(identical(result.state, state), isTrue);
      expect(
        result.effects.whereType<Rehydrate>().single.reason,
        'streamGenerationMismatch',
      );
    });

    test(
      'unrelated and valid foreign frames create no canonical observation',
      () {
        expect(projectText({'type': 'server.connected'}), isNull);
        final foreign = textFrame(
          'session.text.started',
          session: 'ses_foreign',
        );
        foreign.remove('id');
        expect(projectText(foreign), isNull);
      },
    );

    test('unselected private fields are neither read nor serialized', () {
      final frame = textFrame('session.reasoning.ended');
      frame['data'] = PrivateFields(frameData(frame), {'state'});
      final protected = PrivateFields(frame, {'metadata', 'location'});
      final event = projectText(protected)!;
      expect(projectedManifest(event), isNot(contains('fake-private-secret')));
      expect(projectedManifest(event), isNot(contains('providerState')));
    });

    test('integral JSON doubles and source build metadata are accepted', () {
      final frame = textFrame('session.text.ended', ordinal: 0.0);
      final durable = frame['durable']! as Map<String, Object?>;
      durable['seq'] = 0.0;
      durable['version'] = 1.0;
      final event = projectText(frame, version: '2.0.22+build.1')!;
      expect((event as ItemUpserted).item.meta.ordinal, 0);
      expect(event.meta.source.aggregateSeq, BigInt.zero);
      expect(event.meta.source.version, '2.0.22+build.1');
    });

    for (final version in ['3.0.0', '2.0.19', '2.0.22-rc.1', 'secret']) {
      test('unverified source $version fails without echoing values', () {
        expect(
          () =>
              projectText(textFrame('session.text.started'), version: version),
          failsWith(OpenCodeTextProjectionFailure.unsupportedVersion),
        );
      });
    }

    test('multibyte exact content limit passes and excess fails', () {
      final content = '😀' * 65536;
      expect(
        projectText(textFrame('session.text.ended', content: content)),
        isA<ItemUpserted>(),
      );
      expect(
        () => projectText(
          textFrame('session.text.ended', content: '${content}x'),
        ),
        failsWith(OpenCodeTextProjectionFailure.limitExceeded),
      );
    });

    for (final invalid in ['\ud800', '\udc00', '\ud800x']) {
      test('unpaired surrogate ${invalid.codeUnits} is rejected', () {
        expect(
          () => projectText(textFrame('session.text.delta', content: invalid)),
          failsWith(OpenCodeTextProjectionFailure.malformed),
        );
      });
    }

    test('ID and observer context byte limits are enforced', () {
      expect(
        projectText(
          textFrame('session.text.ended', message: 'msg_${'a' * 4092}'),
        ),
        isA<ItemUpserted>(),
      );
      expect(
        () => projectText(
          textFrame('session.text.ended', message: 'msg_${'a' * 4093}'),
        ),
        failsWith(OpenCodeTextProjectionFailure.limitExceeded),
      );
      final ref = SessionRef(
        HostId('a' * 4097),
        historyRef.harness,
        historyRef.nativeId,
      );
      expect(
        () => projectText(
          textFrame('session.text.started'),
          current: SessionState(ref),
        ),
        failsWith(OpenCodeTextProjectionFailure.limitExceeded),
      );
    });

    test('malformed fields have only finite sanitized failure text', () {
      final mutations = <void Function(Map<String, Object?>)>[
        (f) => f.remove('type'),
        (f) => f['type'] = 123,
        (f) => f.remove('id'),
        (f) => f['id'] = 'fake-private-secret',
        (f) => f['created'] = double.infinity,
        (f) => f['created'] = 'fake-private-secret',
        (f) => f['data'] = null,
        (f) => frameData(f)['assistantMessageID'] = 'bad',
        (f) => frameData(f)['sessionID'] = 'bad',
        (f) => frameData(f)['ordinal'] = -1,
        (f) => frameData(f)['ordinal'] = 1.5,
        (f) => frameData(f)['ordinal'] = 9007199254740992,
        (f) => frameData(f)['text'] = {'secret': 'fake-private-secret'},
        (f) => f.remove('durable'),
        (f) => (f['durable']! as Map)['aggregateID'] = 'ses_other',
        (f) => (f['durable']! as Map)['seq'] = '7',
      ];
      for (final mutation in mutations) {
        final frame = textFrame('session.text.ended');
        mutation(frame);
        expect(
          () => projectText(frame),
          throwsA(
            isA<OpenCodeTextProjectionException>()
                .having(
                  (e) => e.failure,
                  'failure category',
                  OpenCodeTextProjectionFailure.malformed,
                )
                .having(
                  (e) => e.toString(),
                  'sanitized error',
                  isNot(contains('fake-private-secret')),
                ),
          ),
        );
      }
      final delta = textFrame('session.text.delta');
      delta['durable'] = {'version': 1};
      expect(
        () => projectText(delta),
        failsWith(OpenCodeTextProjectionFailure.malformed),
      );
      final future = textFrame('session.text.ended');
      (future['durable']! as Map)['version'] = 2;
      expect(
        () => projectText(future),
        failsWith(OpenCodeTextProjectionFailure.unsupportedVersion),
      );
    });
  });
}

final class PrivateFields extends MapBase<String, Object?> {
  PrivateFields(this._fields, this.privateKeys);
  final Map<String, Object?> _fields;
  final Set<String> privateKeys;

  @override
  Object? operator [](Object? key) {
    if (privateKeys.contains(key)) {
      throw StateError('fake-private-secret field was inspected');
    }
    return _fields[key];
  }

  @override
  void operator []=(String key, Object? value) => _fields[key] = value;
  @override
  void clear() => _fields.clear();
  @override
  Iterable<String> get keys => {..._fields.keys, ...privateKeys};
  @override
  Object? remove(Object? key) => _fields.remove(key);
}
