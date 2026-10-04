import 'package:codewalk_core/codewalk_core.dart';
import 'package:test/test.dart';

import 'support/observed_a.dart';

void main() {
  final fixture = ObservedA.load();

  SessionState replay(Iterable<SessionEvent> events) {
    var state = SessionState(fixture.ref, streamPosition: fixture.position(0));
    for (final event in events) {
      state = reduce(state, event).state;
    }
    return state;
  }

  SessionState reconcile(SessionState state, String generation) {
    final readStart = StreamPosition(
      id: ObservedA.streamId,
      epoch: 'fixture-a-reconnect:$generation',
      seq: BigInt.zero,
    );
    final hydrating = beginHydration(
      state,
      generation: generation,
      readStart: readStart,
    );
    return hydrate(
      hydrating,
      fixture.snapshot(hydrationGeneration: generation, readStart: readStart),
    ).state;
  }

  group('observed V2-005A source fidelity', () {
    test('27 native frames retain independent durable and local positions', () {
      expect(fixture.nativeEvents, hasLength(27));
      expect(fixture.eventsByNativeIndex, hasLength(27));
      expect(fixture.events, hasLength(30));
      final nativeIds = <String>{};
      final durableSeq = <BigInt>[];
      final ephemeralTypes = <String>[];
      var localSeq = BigInt.zero;
      for (var index = 0; index < fixture.nativeEvents.length; index++) {
        final native = fixture.nativeEvents[index];
        final nativeId = native['id']! as String;
        expect(nativeIds.add(nativeId), isTrue);
        final durable = native['durable'] as Map<String, Object?>?;
        if (durable != null) {
          durableSeq.add(BigInt.from(durable['seq']! as int));
        } else {
          ephemeralTypes.add(native['type']! as String);
        }
        for (final event in fixture.eventsByNativeIndex[index]) {
          final source = event.meta.source;
          expect(event.meta.owner, SessionOwner(fixture.ref));
          expect(source.harness, fixture.ref.harnessRef);
          expect(source.version, '2.0.22');
          expect(source.nativeType, native['type']);
          expect(source.nativeEventId, nativeId);
          expect(source.nativeCursor, isNull);
          expect(
            source.aggregateSeq,
            durable == null ? null : BigInt.from(durable['seq']! as int),
          );
          expect(
            source.durability.known,
            durable == null ? Durability.ephemeral : Durability.durable,
          );
          final extra = source.extra!.value as Map<String, Object?>;
          expect(extra['file'], 'events.json');
          expect(extra['index'], index);
          expect(extra['nativeCreated'], native['created']);
          if (durable != null) {
            expect(extra['nativeDurableVersion'], durable['version']);
          }
          expect(event.meta.rawRef!.id, contains('#$index:$nativeId'));
          localSeq += BigInt.one;
          expect(event.meta.position.seq, localSeq);
          expect(event.meta.position.epoch, ObservedA.streamEpoch);
        }
      }
      expect(durableSeq, [for (var n = 1; n <= 21; n++) BigInt.from(n)]);
      expect(ephemeralTypes, [
        'session.reasoning.delta',
        'session.reasoning.delta',
        'session.usage.updated',
        'session.reasoning.delta',
        'session.text.delta',
        'session.usage.updated',
      ]);
      expect(
        fixture.nativeEvents.where(
          (event) => event['type'] == 'session.tool.input.delta',
        ),
        isEmpty,
      );
      expect(() => fixture.nativeEvents.clear(), throwsUnsupportedError);
      expect(
        () => fixture.nativeEvents.first['type'] = 'changed',
        throwsUnsupportedError,
      );
    });

    test(
      'native message grouping, per-kind ordinal zero, and ended values',
      () {
        final history = fixture.historyItems;
        expect(history, hasLength(6));
        expect(history.map((item) => item.turnId).toSet(), {fixture.turnId});
        expect(history.map((item) => item.runtimeType), [
          UserInput,
          Reasoning,
          ToolCall,
          Reasoning,
          AssistantText,
          TurnOutcome,
        ]);
        final delivered = history.first as UserInput;
        final admission =
            fixture.admission['response']! as Map<String, Object?>;
        final admitted = admission['data']! as Map<String, Object?>;
        expect(fixture.turnId.value, contains(admitted['id']! as String));
        expect(delivered.id, fixture.itemId(admitted['id']! as String, 'user'));
        final request = fixture.admission['request']! as Map<String, Object?>;
        expect(delivered.text, request['text']);
        expect(delivered.delivery.known, DeliveryState.delivered);
        final deliveredExtra =
            delivered.source.extra!.value as Map<String, Object?>;
        expect(
          deliveredExtra['nativeMessageTime'],
          fixture.messages.first['time'],
        );

        final reasoning = history[3] as Reasoning;
        final text = history[4] as AssistantText;
        expect(reasoning.meta.ordinal, 0);
        expect(text.meta.ordinal, 0);
        expect(reasoning.id, isNot(text.id));
        expect(reasoning.turnId, text.turnId);
        expect(
          (reasoning.source.extra!.value as Map)['nativeMessageId'],
          (text.source.extra!.value as Map)['nativeMessageId'],
        );
        expect(reasoning.generation, text.generation);
        expect(text.text, 'SP01_NATIVE_V2_FREE_MODEL_OK');
        for (final item in history.whereType<Reasoning>()) {
          final extra = item.source.extra!.value as Map<String, Object?>;
          final messageId = extra['nativeMessageId']! as String;
          final ended = fixture.nativeEvents.singleWhere((frame) {
            final data = frame['data']! as Map<String, Object?>;
            return frame['type'] == 'session.reasoning.ended' &&
                data['assistantMessageID'] == messageId;
          });
          final data = ended['data']! as Map<String, Object?>;
          expect(item.text, data['text']);
          expect(item.complete, isTrue);
          expect(extra['nativeMessageId'], messageId);
          expect(extra['file'], 'messages.json');
          expect(extra['nativePartTime'], isA<Map<String, Object?>>());
        }
        final textEnded =
            fixture.nativeEvents[22]['data']! as Map<String, Object?>;
        expect(text.text, textEnded['text']);
        final completedOutcome = fixture.completed['outcome'];
        expect((history.last as TurnOutcome).kind.value, completedOutcome);
        final successId = fixture.nativeEvents.last['id']! as String;
        expect(
          fixture.messages.last['id'],
          successId.replaceFirst('evt_', 'msg_'),
        );
        final successBatch = fixture.eventsByNativeIndex.last;
        expect(successBatch.first, isA<ExecutionChanged>());
        expect((successBatch.last as ItemUpserted).item.id, history.last.id);
      },
    );

    test(
      'successful read retains native executed false, structured input/output',
      () {
        final tool = fixture.historyItems.whereType<ToolCall>().single;
        final nativePart =
            (fixture.messages[1]['content']! as List)[1]
                as Map<String, Object?>;
        final nativeState = nativePart['state']! as Map<String, Object?>;
        expect(tool.kind.known, ToolKind.read);
        expect(tool.rawName, 'read');
        expect(tool.status.known, ItemStatus.completed);
        expect(tool.input!.toJson(), nativeState['input']);
        expect(tool.output!.toJson(), {
          'content': nativeState['content'],
          'metadata': nativeState['metadata'],
          'executed': false,
        });
        final extra = tool.source.extra!.value as Map<String, Object?>;
        expect(extra['nativeCallId'], 'functions.read:0');
        expect(extra['executed'], isFalse);
        final called = fixture.eventsByNativeIndex[11].single as ItemUpserted;
        final success = fixture.eventsByNativeIndex[13].single as ItemUpserted;
        expect(called.item.id, tool.id);
        expect(success.item.id, tool.id);
        for (final item in [called.item, success.item]) {
          expect((item.source.extra!.value as Map)['executed'], isFalse);
        }
        expect((success.item as ToolCall).output, tool.output);
        expect(
          (fixture.eventsByNativeIndex[10].single as ItemUpserted).item
              as ToolCall,
          isA<ToolCall>().having(
            (item) => item.input!.toJson(),
            'observed complete raw input',
            (fixture.nativeEvents[10]['data']! as Map)['text'],
          ),
        );
      },
    );

    test(
      'session totals remain a level-set distinct from the two step costs',
      () {
        expect(fixture.historyUsage, hasLength(3));
        final session = fixture.historyUsage.last;
        expect(session.scope.known, UsageScope.session);
        expect(session.cumulative, isTrue);
        expect(session.tokens!.input, 6116);
        expect(session.tokens!.output, 99);
        expect(session.tokens!.cacheRead, 5760);
        expect(session.cost!.amount, 0);
        expect(session.cost!.cumulative, isTrue);
        final nativeTokens =
            fixture.completed['tokens']! as Map<String, Object?>;
        expect(session.tokens!.input, nativeTokens['input']);
        expect(session.tokens!.output, nativeTokens['output']);
        final steps = fixture.historyUsage.take(2).toList();
        expect(steps.map((usage) => usage.tokens!.input), [5879, 237]);
        expect(steps.map((usage) => usage.tokens!.output), [69, 30]);
        expect(steps.every((usage) => !usage.cumulative), isTrue);
        expect(steps.every((usage) => usage.partial), isTrue);
        expect(steps.every((usage) => usage.cost!.partial), isTrue);
        expect(
          steps
              .map(
                (usage) =>
                    (usage.provenance!.extra!.value as Map)['canonicalTurnId'],
              )
              .toSet(),
          {fixture.turnId.value},
        );
        expect(
          steps
              .map(
                (usage) =>
                    (usage.provenance!.extra!.value as Map)['nativeStepId'],
              )
              .toSet(),
          {fixture.messages[1]['id'], fixture.messages[2]['id']},
        );
        expect(
          steps.map((usage) => usage.aggregationKey).toSet(),
          hasLength(2),
        );

        final snapshot = fixture.snapshot(
          hydrationGeneration: 'fidelity',
          readStart: fixture.position(0),
        );
        expect(snapshot.pending!.values, isEmpty);
        expect(
          snapshot.pending!.boundary.authority.known,
          SnapshotAuthority.derived,
        );
        expect(
          (snapshot.pending!.boundary.source!.extra!.value
              as Map)['derivation'],
          ObservedA.pendingDerivation,
        );
        expect(
          snapshot.timeline!.boundary.authority.known,
          SnapshotAuthority.authoritative,
        );
        expect(snapshot.execution!.value.kind.known, ExecutionKind.idle);
        expect(
          snapshot.execution!.value.lastOutcome!.kind.known,
          ExecutionOutcomeKind.succeeded,
        );
      },
    );
  });

  group('observed A replay and authoritative reconciliation', () {
    test(
      'native fanout admits, promotes, and completes the same stable rows',
      () {
        final admitted = replay(fixture.prefix(1));
        expect(admitted.timeline.whereType<UserInput>(), hasLength(1));
        expect(admitted.pending, hasLength(1));
        final userId = admitted.timeline.single.id;
        final promoted = replay(fixture.prefix(4));
        expect(promoted.pending, isEmpty);
        expect(promoted.timeline.single.id, userId);
        expect(
          (promoted.timeline.single as UserInput).delivery.known,
          DeliveryState.delivered,
        );
        final completed = replay(fixture.events);
        expect(completed.timeline, hasLength(6));
        expect(completed.timeline.whereType<TurnOutcome>(), hasLength(1));
        expect(completed.execution!.kind.known, ExecutionKind.idle);
        expect(
          completed.execution!.lastOutcome!.kind.known,
          ExecutionOutcomeKind.succeeded,
        );
        expect(completed.timeline.whereType<UnknownItem>(), isEmpty);
        expect(
          completed.timeline.whereType<AssistantText>().single.text,
          'SP01_NATIVE_V2_FREE_MODEL_OK',
        );
      },
    );

    test(
      'duplicate observed deltas do not append twice before any ended value',
      () {
        var state = replay(fixture.prefix(6));
        final delta = fixture.eventsByNativeIndex[6].single;
        state = reduce(state, delta).state;
        final afterFirst = state.timeline.whereType<Reasoning>().single.text;
        final duplicate = reduce(state, delta).state;
        expect(afterFirst, 'We need answer. Need read file');
        expect(
          duplicate.timeline.whereType<Reasoning>().single.text,
          afterFirst,
        );
        expect(state.timeline.whereType<Reasoning>().single.complete, isFalse);
        expect(
          duplicate.timeline.whereType<Reasoning>().single.complete,
          isFalse,
        );
      },
    );

    test(
      'duplicating every observed projection preserves completed live state',
      () {
        final replayed = replay(fixture.events);
        final duplicated = replay([
          for (final event in fixture.events) ...[event, event],
        ]);
        expect(_semanticProjection(duplicated), _semanticProjection(replayed));
      },
    );

    final expected = reconcile(replay(fixture.events), 'full-authoritative');
    for (var cut = 0; cut <= 27; cut++) {
      test(
        'cut $cut/27 disconnect then hydrate equals reconciled full replay',
        () {
          final before = replay(fixture.prefix(cut));
          final lost = disconnect(before);
          // A transport loss cannot manufacture an execution terminal outcome.
          expect(_execution(lost.execution), _execution(before.execution));
          expect(
            lost.timeline.whereType<TurnOutcome>().length,
            before.timeline.whereType<TurnOutcome>().length,
          );
          expect(lost.connection.kind.known, isNot(ConnectionKind.live));
          final actual = reconcile(lost, 'prefix:$cut');
          expect(_semanticProjection(actual), _semanticProjection(expected));
          expect(actual.timeline, hasLength(6));
          expect(actual.pending, isEmpty);
          expect(
            actual.timeline.every(
              (item) => item.status.known == ItemStatus.completed,
            ),
            isTrue,
          );
          final total = actual.usage.singleWhere(
            (usage) => usage.scope.known == UsageScope.session,
          );
          expect(total.tokens!.input, 6116);
          expect(total.tokens!.output, 99);
          expect(total.cost!.amount, 0);
        },
      );
    }
  });
}

/// Compare semantic canonical values, including final native provenance.
/// Receive clocks, stream/read barriers, connection confidence, effects and
/// cache recency are local bookkeeping and intentionally absent here.
Map<String, Object?> _semanticProjection(SessionState state) => {
  'ref': state.ref.toJson(),
  'timeline': [for (final item in state.timeline) _item(item)],
  'execution': _execution(state.execution),
  'pending': [
    for (final input in state.pending)
      {
        'id': input.id.value,
        'text': input.text,
        'delivery': input.delivery.value,
        'commandId': input.commandId?.value,
      },
  ],
  'usage': [for (final usage in state.usage) _usage(usage)],
  'info': state.info == null
      ? null
      : {
          'ref': state.info!.ref.toJson(),
          'title': state.info!.title,
          'project': state.info!.project?.toJson(),
          'ownership': state.info!.ownership.toJson(),
          'metadata': state.info!.metadata?.toJson(),
        },
  'selection': state.selection == null
      ? null
      : {
          'model': state.selection!.modelId,
          'agent': state.selection!.agentId,
          'effort': state.selection!.effort,
          'permission': state.selection!.permissionMode,
          'metadata': state.selection!.metadata?.toJson(),
        },
};

Map<String, Object?> _item(TimelineItem item) => {
  'id': item.id.value,
  'turn': item.turnId?.value,
  'generation': item.generation,
  'ordinal': item.meta.ordinal,
  'status': item.status.value,
  'source': _source(item.source),
  ...switch (item) {
    UserInput() => {
      'kind': 'user',
      'text': item.text,
      'delivery': item.delivery.value,
      'commandId': item.commandId?.value,
    },
    Reasoning() => {
      'kind': 'reasoning',
      'text': item.text,
      'complete': item.complete,
      'prefixMissing': item.prefixMissing,
    },
    AssistantText() => {
      'kind': 'text',
      'text': item.text,
      'complete': item.complete,
      'prefixMissing': item.prefixMissing,
    },
    ToolCall() => {
      'kind': 'tool',
      'toolKind': item.kind.value,
      'rawName': item.rawName,
      'input': item.input?.toJson(),
      'output': item.output?.toJson(),
      'outputRef': item.outputRef?.id,
      'child': item.child?.toJson(),
      'error': item.error?.rawType,
    },
    TurnOutcome() => {
      'kind': 'outcome',
      'outcome': item.kind.value,
      'reason': item.reason,
      'error': item.error?.rawType,
    },
    _ => {'kind': item.runtimeType.toString()},
  },
};

Map<String, Object?> _source(SourceProvenance source) => {
  'harness': source.harness.toJson(),
  'version': source.version,
  'nativeType': source.nativeType,
  'nativeEventId': source.nativeEventId,
  'nativeCursor': source.nativeCursor,
  'aggregate': source.aggregateId,
  'aggregateSeq': source.aggregateSeq?.toString(),
  'durability': source.durability.value,
  'extra': source.extra?.toJson(),
};

Map<String, Object?>? _execution(ExecutionState? execution) => execution == null
    ? null
    : {
        'kind': execution.kind.value,
        'retryAt': execution.retryAt?.toIso8601String(),
        'error': execution.error?.rawType,
        'outcome': execution.lastOutcome?.kind.value,
        'outcomeReason': execution.lastOutcome?.reason,
        'outcomeError': execution.lastOutcome?.error?.rawType,
      };

Map<String, Object?> _usage(UsageObservation usage) => {
  'id': usage.id,
  'owner': usage.owner.scopeKey,
  'scope': usage.scope.value,
  'source': usage.source.value,
  'observedAt': usage.observedAt.toIso8601String(),
  'partial': usage.partial,
  'cumulative': usage.cumulative,
  'aggregationKey': usage.aggregationKey,
  'tokens': usage.tokens == null
      ? null
      : {
          'input': usage.tokens!.input,
          'output': usage.tokens!.output,
          'reasoning': usage.tokens!.reasoning,
          'cacheRead': usage.tokens!.cacheRead,
          'cacheWrite': usage.tokens!.cacheWrite,
        },
  'cost': usage.cost == null
      ? null
      : {
          'amount': usage.cost!.amount,
          'currency': usage.cost!.currency,
          'estimated': usage.cost!.estimated,
          'partial': usage.cost!.partial,
          'cumulative': usage.cost!.cumulative,
        },
  'provenance': usage.provenance == null ? null : _source(usage.provenance!),
};
