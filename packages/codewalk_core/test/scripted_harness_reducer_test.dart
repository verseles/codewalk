import 'dart:async';
import 'dart:convert';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:test/test.dart';

import 'support/scripted_harness_adapter.dart';
import 'support/scripted_harness_scenarios.dart';

/// Test consumer of the real ports/store. It does not implement projection or
/// automatically execute recovery effects/mutations returned by the reducer.
final class _Consumer {
  _Consumer(this.adapter, this.handle) {
    store.open(handle.ref);
    eventSubscription = handle.events.listen(
      (event) => reductions.add(store.apply(handle.ref, event)),
    );
    connectionSubscription = adapter.connection.listen((state) {
      if (state.kind.known == ConnectionKind.reconnecting) {
        store.disconnected(handle.ref);
      }
    });
  }
  final ScriptedHarnessAdapter adapter;
  final SessionHandle handle;
  final store = SessionStore(maxSessions: 4);
  final reductions = <Reduction>[];
  late final StreamSubscription<SessionEvent> eventSubscription;
  late final StreamSubscription<ConnectionState> connectionSubscription;
  SessionState get state => store.peek(handle.ref)!;

  void start(String generation) => store.startHydration(
    handle.ref,
    generation: generation,
    readStart: adapter.position(handle.ref),
  );
  Future<Reduction> hydrate(Future<SessionSnapshot> read) async =>
      store.applySnapshot(handle.ref, await read);
  Future<void> close() async {
    await eventSubscription.cancel();
    await connectionSubscription.cancel();
    await handle.detach();
  }
}

Future<_Consumer> _consume(
  ScriptedScenario scenario, {
  OpenIntent intent = OpenIntent.attachLive,
}) async {
  addTearDown(scenario.adapter.dispose);
  final consumer = _Consumer(
    scenario.adapter,
    await scenario.adapter.open(scenario.ref, intent),
  );
  addTearDown(consumer.close);
  return consumer;
}

Future<void> steps(ScriptedHarnessAdapter adapter, int count) async {
  for (var i = 0; i < count; i++) {
    await adapter.step();
  }
}

void main() {
  group('six synthetic scenarios through the accepted reducer', () {
    test(
      'owned_stream: duplicate fragment, completion replacement and safe unknowns',
      () async {
        final scenario = ownedStream();
        final consumer = await _consume(scenario);
        final adapter = scenario.adapter;
        await consumer.handle.send(scriptedDraft(), id: sendId);
        expect(
          consumer.state.timeline,
          isEmpty,
        ); // Receipt is not a projected item.
        await steps(adapter, 3);
        expect(
          (consumer.state.item(assistantId)! as AssistantText).text,
          'prefix-fragment',
        );
        expect(consumer.state.execution!.kind.known, ExecutionKind.running);
        expect(consumer.reductions.last.effects.single, isA<Notify>());
        final beforeDuplicate = consumer.state;
        await adapter.step();
        expect(consumer.state, same(beforeDuplicate));
        expect(consumer.reductions.last.effects, isEmpty);
        await steps(adapter, 3);
        final completed = consumer.state.item(assistantId)! as AssistantText;
        expect(completed.text, 'complete answer');
        expect(completed.complete, isTrue);
        expect(
          consumer.state.execution!.lastOutcome!.kind.known,
          ExecutionOutcomeKind.succeeded,
        );
        await steps(adapter, 2);
        expect(
          consumer.state.timeline.whereType<AssistantText>(),
          hasLength(1),
        );
        expect(
          consumer.state.timeline.whereType<UnknownItem>().single.rawType,
          'future.item.v9',
        );
        expect(consumer.state.diagnostics.single.raw.value, {'flag': true});
        await adapter.step();
        final missing = consumer.reductions.last.effects
            .whereType<Refetch>()
            .single;
        expect(missing.ref, ownedRef);
        expect(missing.collection, SessionCollection.timeline);
        expect(missing.reason, 'deltaTargetMissing');
        expect(consumer.state.item(const ItemId('missing')), isNull);
        final beforeForeign = consumer.state;
        await adapter.step();
        expect(consumer.state, same(beforeForeign));
        expect(
          (consumer.reductions.last.effects.single as Rehydrate).reason,
          'eventScopeMismatch',
        );
        await adapter.step();
        expect(consumer.state, same(beforeForeign));
        expect(
          (consumer.reductions.last.effects.single as Rehydrate).reason,
          'streamGenerationMismatch',
        );
        expect(adapter.commands, hasLength(1));
        expect(adapter.remainingSteps, 0);
      },
    );

    test(
      'offered_permission: child ownership and coincident IDs remain independent',
      () async {
        final scenario = offeredPermission();
        final consumer = await _consume(scenario);
        await steps(scenario.adapter, 3);
        expect(consumer.state.interactions, hasLength(3));
        expect(
          consumer.state.interactions
              .map((request) => request.identityKey)
              .toSet(),
          hasLength(3),
        );
        final child = consumer.state.interactions.first;
        expect(child.owner, const SessionOwner(childRef, origin: ownedRef));
        expect(child.automaticChoice!.id, 'proceed-x7');
        expect(scenario.adapter.commands, isEmpty);
        final receipt = await scenario.adapter.interactions!.respond(
          child.owner,
          child.id,
          scriptedResponse(),
          id: respondId,
        );
        expect(receipt.admissionKnown, isTrue);
        expect(
          consumer.state.interactions,
          hasLength(3),
        ); // Admission alone does not resolve.
        await scenario.adapter.step();
        expect(consumer.state.interactions, hasLength(2));
        expect(
          consumer.state.interactions.any(
            (request) => request.owner.hasSameScope(child.owner),
          ),
          isFalse,
        );
        expect(
          consumer.state.interactions.any(
            (request) =>
                request.owner.hasSameScope(const SessionOwner(ownedRef)),
          ),
          isTrue,
        );
        await scenario.adapter.step();
        expect(
          consumer.state.interactions.single.owner,
          ProjectOwner(otherProject, harness: scriptedHarness),
        );
        await scenario.adapter.step();
        final unknown = consumer.state.interactions.last;
        expect(unknown.kind.value, 'future.permission.v9');
        expect(unknown.automaticChoice, isNull);
        expect(unknown.choices.single.scope.value, 'future-scope-v9');
        expect(
          consumer.reductions.every(
            (result) => result.effects.whereType<Rehydrate>().isEmpty,
          ),
          isTrue,
        );
        expect(consumer.reductions.last.effects.single, isA<Notify>());
        expect(scenario.adapter.commands.single.id, respondId);
      },
    );

    test(
      'structured_usage: nullable, estimated, overlapping and cumulative data stay distinct',
      () async {
        final scenario = structuredUsage();
        final consumer = await _consume(scenario);
        await steps(scenario.adapter, 2);
        final beforeDuplicate = consumer.state;
        await scenario.adapter.step();
        expect(consumer.state, same(beforeDuplicate));
        expect(consumer.reductions.last.effects, isEmpty);
        await steps(scenario.adapter, 4);
        expect(consumer.state.usage, hasLength(5));
        final partial = consumer.state.usage.first;
        expect(partial.scope.known, UsageScope.turn);
        expect(partial.tokens!.input, 10);
        expect(partial.tokens!.output, isNull);
        expect(partial.tokens!.cacheRead, isNull);
        expect(partial.cost!.currency, isNull);
        expect(partial.cost!.estimated, isTrue);
        final cumulative = consumer.state.usage.singleWhere(
          (usage) => usage.cumulative && !usage.partial,
        );
        expect(cumulative.id, 'cumulative-2');
        expect(cumulative.tokens!.input, 125); // Replacement, not 100 + 125.
        expect(cumulative.tokens!.output, isNull);
        expect(cumulative.cost!.amount, 0.75);
        expect(cumulative.cost!.cumulative, isTrue);
        expect(cumulative.partial, isFalse);
        final partialSeries = consumer.state.usage.singleWhere(
          (usage) => usage.id == 'partial-series',
        );
        expect(partialSeries.tokens!.input, 3);
        expect(partialSeries.partial, isTrue);
        expect(partialSeries.cumulative, isTrue);
        expect(
          partialSeries.aggregationIdentity,
          cumulative.aggregationIdentity,
        );
        final quota = consumer.state.usage.singleWhere(
          (usage) => usage.id == 'quota',
        );
        expect(quota.quotas.single.usedPercent, 123.4);
        expect(quota.quotas.single.resetsAt, isNull);
        expect(quota.tokens, isNull);
        expect(quota.context, isNull);
        expect(
          quota.isFreshAt(
            scriptedNow.add(const Duration(hours: 1)),
            maxAge: const Duration(minutes: 5),
          ),
          isFalse,
        );
        final unknown = consumer.state.usage.last;
        expect(unknown.scope.value, 'future-scope-v9');
        expect(unknown.source.value, 'future-source-v9');
        expect(unknown.aggregationIdentity, isNull);
        expect(unknown.cost!.amount, isNull);
        await scenario.adapter.step();
        expect(consumer.state.usage, hasLength(5));
        final recovery = consumer.reductions.last.effects
            .whereType<Refetch>()
            .single;
        expect(recovery.collection, SessionCollection.usage);
        expect(recovery.reason, 'usageScopeMismatch');
        expect(scenario.adapter.commands, isEmpty);
      },
    );

    test(
      'error_and_uncertain_admission: recovery hints and disconnect do not replay',
      () async {
        final scenario = errorAndUncertainAdmission();
        final consumer = await _consume(scenario);
        final create = await scenario.adapter.create(scriptedCreate());
        expect(create.handle, isNull);
        final sent = await consumer.handle.send(scriptedDraft(), id: sendId);
        expect(sent.state.known, ReceiptState.uncertain);
        expect(consumer.state.timeline, isEmpty);
        await scenario.adapter.step();
        expect(consumer.state.execution!.kind.known, ExecutionKind.retrying);
        expect(
          consumer.state.execution!.error!.rawType,
          'synthetic.transport.lost',
        );
        expect(
          consumer.state.execution!.retryAt,
          scriptedNow.add(const Duration(seconds: 30)),
        );
        await scenario.adapter.step();
        expect(
          consumer.state.connection.kind.known,
          ConnectionKind.reconnecting,
        );
        expect(consumer.state.execution!.kind.known, ExecutionKind.retrying);
        expect(consumer.state.execution!.lastOutcome, isNull);
        expect(scenario.adapter.commands, hasLength(2));
        await scenario.adapter.step();
        expect(
          consumer.state.execution!.lastOutcome!.kind.known,
          ExecutionOutcomeKind.failed,
        );
        expect(scenario.adapter.commands, hasLength(2));
        expect(
          sent.admissionKnown,
          isFalse,
        ); // Observed outcome does not resolve this receipt.
        final original = scenario.adapter.commands.last;
        final payload = jsonEncode(original.intent.toJson());
        for (final phase in [
          OperationPhase.promoted,
          OperationPhase.cancelled,
          OperationPhase.settled,
        ]) {
          final contract = OperationContract(
            harness: scriptedHarness,
            operation: original.operation,
            connectedVersion: scriptedVersion,
            phase: OpenValue.known(phase),
            replay: ReplayPolicy.verifiedUnresolvedAdmission,
            evidence: 'synthetic-negative-control',
          );
          final decision = contract.evaluate(
            original: original,
            candidate: original,
            persistedOriginalPayload: payload,
            candidatePayload: payload,
            admission: AdmissionKnowledge.unresolved,
            currentPhase: OpenValue.known(phase),
            cancellation: const OpenValue.known(CancellationFence.none),
            reconciled: true,
          );
          expect(decision.allowed, isFalse);
          expect(decision.reason, 'unknownOrTerminalContract');
        }
        final conservative = OperationContract(
          harness: scriptedHarness,
          operation: original.operation,
          connectedVersion: scriptedVersion,
          phase: const OpenValue.known(OperationPhase.pending),
        );
        expect(
          conservative
              .evaluate(
                original: original,
                candidate: original,
                persistedOriginalPayload: payload,
                candidatePayload: payload,
                admission: AdmissionKnowledge.unresolved,
                currentPhase: const OpenValue.known(OperationPhase.pending),
                cancellation: const OpenValue.known(CancellationFence.none),
                reconciled: true,
              )
              .reason,
          'reconcileOnly',
        );
      },
    );

    test(
      'disconnect_hydrate: read-start overlays and stale generations survive reverse completion',
      () async {
        final scenario = disconnectHydrate();
        final consumer = await _consume(scenario);
        await steps(scenario.adapter, 3);
        expect(
          consumer.state.connection.kind.known,
          ConnectionKind.reconnecting,
        );
        expect(consumer.state.execution!.kind.known, ExecutionKind.running);
        expect(consumer.state.execution!.lastOutcome, isNull);
        expect(
          (consumer.state.item(assistantId)! as AssistantText).prefixMissing,
          isTrue,
        );
        consumer.start('old-hydration');
        final old = consumer.handle.snapshot();
        consumer.start('new-hydration');
        final newer = consumer.handle.snapshot();
        await steps(scenario.adapter, 9);
        expect(
          (consumer.state.item(assistantId)! as AssistantText).text,
          'authoritative finished',
        );
        await scenario.adapter.step();
        final hydrated = await consumer.hydrate(newer);
        expect(
          (consumer.state.item(assistantId)! as AssistantText).text,
          'authoritative finished',
        );
        expect(
          (consumer.state.item(assistantId)! as AssistantText).complete,
          isTrue,
        );
        expect(
          (consumer.state.item(assistantId)! as AssistantText).prefixMissing,
          isFalse,
        );
        expect(consumer.state.execution!.kind.known, ExecutionKind.running);
        expect(consumer.state.execution!.lastOutcome, isNull);
        expect(hydrated.effects.whereType<Rehydrate>(), isEmpty);
        expect(consumer.state.connection.kind.known, ConnectionKind.live);
        await scenario.adapter.step();
        final beforeOld = consumer.state;
        final obsolete = await consumer.hydrate(old);
        expect(consumer.state, same(beforeOld));
        expect(
          (obsolete.effects.single as Rehydrate).reason,
          'snapshotGenerationMismatch',
        );
        await steps(scenario.adapter, 2);
        expect(consumer.state.execution!.kind.known, ExecutionKind.running);
        expect(
          (consumer.state.item(assistantId)! as AssistantText).text,
          'authoritative finished',
        );
        expect(consumer.reductions.last.effects, isEmpty);
        expect(scenario.adapter.commands, isEmpty);
      },
    );

    test(
      'history_only_external: observing/detaching never activates execution',
      () async {
        final scenario = historyOnlyExternal();
        final consumer = await _consume(
          scenario,
          intent: OpenIntent.viewHistory,
        );
        consumer.start('external-hydration');
        final hydrated = await consumer.hydrate(consumer.handle.snapshot());
        expect(hydrated.effects.single, isA<Notify>());
        expect(consumer.state.info!.ownership.kind, OwnershipKind.savedHistory);
        expect(consumer.state.execution!.kind.known, ExecutionKind.unknown);
        expect(consumer.state.execution!.lastOutcome, isNull);
        expect(
          (consumer.state.timeline.single as AssistantText).text,
          'historical only',
        );
        final denied = await consumer.handle.send(scriptedDraft(), id: sendId);
        expect(denied.state.known, ReceiptState.unavailable);
        await steps(scenario.adapter, 2);
        expect(consumer.state.execution!.kind.known, ExecutionKind.unknown);
        expect(consumer.state.diagnostics.single.rawType, 'future.external.v9');
        final beforeDetach = consumer.state;
        await consumer.handle.detach();
        expect(consumer.state, same(beforeDetach));
        expect(scenario.adapter.commands, isEmpty);
        expect(scenario.adapter.observerCount, 0);
        expect(consumer.store.length, 1);
      },
    );
  });
}
