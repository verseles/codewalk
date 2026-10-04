import 'package:codewalk_core/codewalk_core.dart';
import 'package:test/test.dart';

import 'support/scripted_harness_adapter.dart';
import 'support/scripted_harness_scenarios.dart';

ScriptedHarnessAdapter keep(ScriptedHarnessAdapter adapter) {
  addTearDown(adapter.dispose);
  return adapter;
}

void expectUnavailable(CommandReceipt receipt, {String? reason}) {
  expect(receipt.state.known, ReceiptState.unavailable);
  expect(receipt.admissionKnown, isFalse);
  expect(receipt.unavailable, isA<CapabilityUnavailable>());
  if (reason != null) expect(receipt.reason, reason);
}

ScriptedOutcome _knownCreate(CreateSession request, SessionRef created) {
  final owner = ProjectOwner(request.project, harness: request.harness);
  return ScriptedOutcome(
    command: scriptedCommand(
      request.id,
      owner,
      MutationOperation.create,
      createIntent(request),
    ),
    receipt: CommandReceipt.accepted(
      id: request.id,
      owner: owner,
      nativeRef: created.nativeId,
    ),
    created: created,
  );
}

ScriptedHarnessAdapter _createAdapter(
  List<ScriptedOutcome> outcomes, {
  bool attach = true,
}) {
  final prototype = keep(scriptedAdapter());
  final projectOwner = ProjectOwner(project, harness: scriptedHarness);
  return keep(
    ScriptedHarnessAdapter(
      descriptor: prototype.descriptor,
      clock: ScriptedClock(scriptedNow),
      access: {
        projectOwner: scriptedAccess(projectOwner),
        for (final ref in [ownedRef, childRef])
          SessionOwner(ref): scriptedAccess(
            SessionOwner(ref),
            capabilities: scriptedCapabilities(
              SessionOwner(ref),
              overrides: {
                if (!attach)
                  'history.liveAttach': Capability(
                    support: const OpenValue.known(Support.unavailable),
                    reason: 'attachUnavailable',
                  ),
              },
            ),
          ),
      },
      sessions: [scriptedInfo(ownedRef), scriptedInfo(childRef)],
      outcomes: outcomes,
    ),
  );
}

void main() {
  group('synthetic adapter port contract', () {
    test(
      'overlapping known creates retain invocation-specific handles',
      () async {
        final first = scriptedCreate();
        final second = CreateSession(
          id: const CommandId('second-create'),
          harness: scriptedHarness,
          project: project,
          title: 'second',
        );
        final adapter = _createAdapter([
          _knownCreate(first, ownedRef),
          _knownCreate(second, childRef),
        ]);
        final firstFuture = adapter.create(first);
        final secondFuture = adapter.create(second);
        final results = await Future.wait([firstFuture, secondFuture]);
        expect(results.map((result) => result.receipt.id), [
          first.id,
          second.id,
        ]);
        expect(results.map((result) => result.handle!.ref), [
          ownedRef,
          childRef,
        ]);
        expect(results.map((result) => result.receipt.nativeRef), [
          ownedRef.nativeId,
          childRef.nativeId,
        ]);
        expect(adapter.observerCount, 2);
        expect(adapter.commands, hasLength(2));
      },
    );

    test(
      'known create overlapping prompt retains its authored handle',
      () async {
        final request = scriptedCreate();
        final draft = PromptDraft(text: 'overlapping prompt');
        final adapter = _createAdapter([
          _knownCreate(request, childRef),
          acceptedOutcome(
            sendId,
            const SessionOwner(ownedRef),
            MutationOperation.prompt,
            promptIntent(draft),
          ),
        ]);
        final handle = await adapter.open(ownedRef, OpenIntent.attachLive);
        final create = adapter.create(request);
        final send = handle.send(draft, id: sendId);
        expect((await create).handle!.ref, childRef);
        expect((await send).id, sendId);
        expect(adapter.observerCount, 2);
      },
    );

    test(
      'optional attachment denial preserves known create admission',
      () async {
        final request = scriptedCreate();
        final adapter = _createAdapter([
          _knownCreate(request, ownedRef),
        ], attach: false);
        final result = await adapter.create(request);
        expect(result.receipt.admissionKnown, isTrue);
        expect(result.receipt.id, createId);
        expect(result.receipt.nativeRef, ownedRef.nativeId);
        expect(result.handle, isNull);
        expect(adapter.commands, hasLength(1));
        expect(adapter.observerCount, 0);
      },
    );

    test(
      'pending interaction port ignores stale, duplicate and unadopted-epoch observations',
      () async {
        final current = scriptedPermission(choice: 'current-choice');
        final stale = scriptedPermission(choice: 'stale-choice');
        InteractionResolved resolution(
          int seq, {
          String epoch = 'epoch',
          String? eventId,
        }) => InteractionResolved(
          meta: scriptedMeta(seq, epoch: epoch, eventId: eventId),
          resolution: InteractionResolution(
            id: interactionId,
            owner: current.owner,
            kind: const OpenValue.known(InteractionResolutionKind.elsewhere),
          ),
        );
        final adapter = keep(
          scriptedAdapter(
            steps: [
              EmitEvent(
                ownedRef,
                InteractionOpened(
                  meta: scriptedMeta(10, eventId: 'current-opening'),
                  request: current,
                ),
              ),
              EmitEvent(
                ownedRef,
                InteractionOpened(meta: scriptedMeta(8), request: stale),
              ),
              EmitEvent(ownedRef, resolution(11, epoch: 'unadopted')),
              EmitEvent(ownedRef, resolution(9)),
              EmitEvent(
                ownedRef,
                InteractionOpened(
                  meta: scriptedMeta(12, eventId: 'current-opening'),
                  request: stale,
                ),
              ),
              EmitEvent(
                ownedRef,
                InteractionOpened(
                  meta: scriptedMeta(12, eventId: 'observation-8'),
                  request: stale,
                ),
              ),
              EmitEvent(ownedRef, resolution(13)),
              EmitEvent(
                ownedRef,
                InteractionOpened(
                  meta: scriptedMeta(12, eventId: 'late-opening'),
                  request: stale,
                ),
              ),
              EmitEvent(
                ownedRef,
                InteractionOpened(meta: scriptedMeta(14), request: current),
              ),
              EmitEvent(ownedRef, resolution(16, eventId: 'observation-9')),
            ],
          ),
        );
        final handle = await adapter.open(ownedRef, OpenIntent.attachLive);
        final store = SessionStore(maxSessions: 1)..open(ownedRef);
        final subscription = handle.events.listen(
          (event) => store.apply(ownedRef, event),
        );
        addTearDown(subscription.cancel);
        for (var i = 0; i < 6; i++) {
          await adapter.step();
          final pending = await adapter.interactions!.pending(current.owner);
          expect(pending.items.single.choices.first.id, 'current-choice');
          expect(
            store.peek(ownedRef)!.interactions.single.choices.first.id,
            'current-choice',
          );
        }
        await adapter.step();
        await adapter.step();
        expect(
          (await adapter.interactions!.pending(current.owner)).items,
          isEmpty,
        );
        expect(store.peek(ownedRef)!.interactions, isEmpty);
        expectUnavailable(
          await adapter.interactions!.respond(
            current.owner,
            interactionId,
            ApprovalResponse('stale-choice'),
            id: respondId,
          ),
          reason: 'interactionNotPending',
        );
        expect(adapter.commands, isEmpty);
        await adapter.step();
        await adapter.step();
        expect(
          (await adapter.interactions!.pending(
            current.owner,
          )).items.single.choices.first.id,
          'current-choice',
        );
        expect(
          store.peek(ownedRef)!.interactions.single.choices.first.id,
          'current-choice',
        );
      },
    );

    test(
      'unrelated delivery cannot supply or poison a native interaction',
      () async {
        final request = scriptedPermission(owner: const SessionOwner(childRef));
        final adapter = keep(
          scriptedAdapter(
            steps: [
              EmitEvent(
                ownedRef,
                InteractionOpened(meta: scriptedMeta(1), request: request),
              ),
              EmitEvent(
                childRef,
                InteractionOpened(
                  meta: scriptedMeta(1, owner: const SessionOwner(childRef)),
                  request: request,
                ),
              ),
            ],
          ),
        );
        final handle = await adapter.open(ownedRef, OpenIntent.attachLive);
        final store = SessionStore(maxSessions: 2)
          ..open(ownedRef)
          ..open(childRef);
        final subscription = handle.events.listen(
          (event) => store.apply(ownedRef, event),
        );
        addTearDown(subscription.cancel);
        final childHandle = await adapter.open(childRef, OpenIntent.attachLive);
        final childSubscription = childHandle.events.listen(
          (event) => store.apply(childRef, event),
        );
        addTearDown(childSubscription.cancel);
        await adapter.step();
        expect(store.peek(ownedRef)!.interactions, isEmpty);
        expect(
          (await adapter.interactions!.pending(request.owner)).items,
          isEmpty,
        );
        expectUnavailable(
          await adapter.interactions!.respond(
            request.owner,
            request.id,
            ApprovalResponse(request.choices.first.id),
            id: respondId,
          ),
          reason: 'interactionNotPending',
        );
        expect(adapter.commands, isEmpty);
        await adapter.step();
        expect(store.peek(childRef)!.interactions.single.id, request.id);
        expect(
          (await adapter.interactions!.pending(request.owner)).items.single.id,
          request.id,
        );
      },
    );

    test('parent and child fanout uses independent observer clocks', () async {
      final request = scriptedPermission();
      InteractionResolved resolved(SessionRef observer, int seq) =>
          InteractionResolved(
            meta: scriptedMeta(
              seq,
              owner: SessionOwner(observer),
              eventId: 'shared-resolution',
            ),
            resolution: InteractionResolution(
              id: request.id,
              owner: request.owner,
              kind: const OpenValue.known(InteractionResolutionKind.elsewhere),
            ),
          );
      final adapter = keep(
        scriptedAdapter(
          steps: [
            EmitEvent(
              ownedRef,
              InteractionOpened(
                meta: scriptedMeta(10, eventId: 'shared-opening'),
                request: request,
              ),
            ),
            EmitEvent(
              childRef,
              InteractionOpened(
                meta: scriptedMeta(
                  1,
                  owner: const SessionOwner(childRef),
                  eventId: 'shared-opening',
                ),
                request: request,
              ),
            ),
            EmitEvent(childRef, resolved(childRef, 2)),
            EmitEvent(ownedRef, resolved(ownedRef, 11)),
          ],
        ),
      );
      final store = SessionStore(maxSessions: 2);
      for (final ref in [ownedRef, childRef]) {
        store.open(ref);
        final handle = await adapter.open(ref, OpenIntent.attachLive);
        final subscription = handle.events.listen(
          (event) => store.apply(ref, event),
        );
        addTearDown(subscription.cancel);
      }
      await adapter.step();
      await adapter.step();
      expect(store.peek(ownedRef)!.interactions, hasLength(1));
      expect(store.peek(childRef)!.interactions, hasLength(1));
      expect(
        (await adapter.interactions!.pending(request.owner)).items,
        hasLength(1),
      );
      await adapter.step();
      expect(store.peek(childRef)!.interactions, isEmpty);
      expect(
        (await adapter.interactions!.pending(request.owner)).items,
        isEmpty,
      );
      await adapter.step();
      expect(store.peek(ownedRef)!.interactions, isEmpty);
      expect(
        (await adapter.interactions!.pending(request.owner)).items,
        isEmpty,
      );
      expect(adapter.commands, isEmpty);
    });

    for (final firstObserver in [ownedRef, childRef]) {
      test(
        'delayed native fanout cannot reopen resolved interaction ($firstObserver)',
        () async {
          final secondObserver = firstObserver == ownedRef
              ? childRef
              : ownedRef;
          final firstSeq = firstObserver == ownedRef ? 10 : 1;
          final secondSeq = secondObserver == ownedRef ? 10 : 1;
          final request = scriptedPermission();
          final next = scriptedPermission(choice: 'new-choice');
          final adapter = keep(
            scriptedAdapter(
              steps: [
                EmitEvent(
                  firstObserver,
                  InteractionOpened(
                    meta: scriptedMeta(
                      firstSeq,
                      owner: SessionOwner(firstObserver),
                      eventId: 'shared-opening',
                    ),
                    request: request,
                  ),
                ),
                EmitEvent(
                  firstObserver,
                  InteractionResolved(
                    meta: scriptedMeta(
                      firstSeq + 1,
                      owner: SessionOwner(firstObserver),
                      eventId: 'shared-resolution',
                    ),
                    resolution: InteractionResolution(
                      id: request.id,
                      owner: request.owner,
                      kind: const OpenValue.known(
                        InteractionResolutionKind.elsewhere,
                      ),
                    ),
                  ),
                ),
                EmitEvent(
                  secondObserver,
                  InteractionOpened(
                    meta: scriptedMeta(
                      secondSeq,
                      owner: SessionOwner(secondObserver),
                      eventId: 'shared-opening',
                    ),
                    request: request,
                  ),
                ),
                EmitEvent(
                  secondObserver,
                  InteractionOpened(
                    meta: scriptedMeta(
                      secondSeq + 1,
                      owner: SessionOwner(secondObserver),
                      eventId: 'new-opening',
                    ),
                    request: next,
                  ),
                ),
              ],
            ),
          );
          final store = SessionStore(maxSessions: 2);
          for (final ref in [ownedRef, childRef]) {
            store.open(ref);
            final handle = await adapter.open(ref, OpenIntent.attachLive);
            final subscription = handle.events.listen(
              (event) => store.apply(ref, event),
            );
            addTearDown(subscription.cancel);
          }
          await adapter.step();
          await adapter.step();
          await adapter.step();
          expect(
            (await adapter.interactions!.pending(request.owner)).items,
            isEmpty,
          );
          expect(store.peek(firstObserver)!.interactions, isEmpty);
          // Fanout remains visible to its own consumer; it cannot change the
          // shared port's already-observed native resolution.
          expect(
            store.peek(secondObserver)!.interactions.single.id,
            request.id,
          );
          expectUnavailable(
            await adapter.interactions!.respond(
              request.owner,
              request.id,
              ApprovalResponse(request.choices.first.id),
              id: respondId,
            ),
            reason: 'interactionNotPending',
          );
          expect(adapter.commands, isEmpty);
          await adapter.step();
          expect(
            (await adapter.interactions!.pending(
              next.owner,
            )).items.single.choices.first.id,
            'new-choice',
          );
          expect(
            store.peek(secondObserver)!.interactions.single.choices.first.id,
            'new-choice',
          );
        },
      );
    }

    for (final firstIsInteraction in [true, false]) {
      test(
        'position-only dedup covers every event kind (interaction=$firstIsInteraction)',
        () async {
          final first = scriptedPermission(owner: const SessionOwner(ownedRef));
          final second = InteractionRequest(
            id: const InteractionId('different-request'),
            owner: first.owner,
            kind: first.kind,
            title: 'Different request at the same position',
            choices: first.choices,
          );
          final meta = EventMeta(
            owner: const SessionOwner(ownedRef),
            position: scriptedPosition(7),
            receivedAt: scriptedNow,
            source: scriptedSource('synthetic.no-native-id'),
          );
          final adapter = keep(
            scriptedAdapter(
              steps: [
                EmitEvent(
                  ownedRef,
                  firstIsInteraction
                      ? InteractionOpened(meta: meta, request: first)
                      : ExecutionChanged(
                          meta: meta,
                          state: const ExecutionState(
                            kind: OpenValue.known(ExecutionKind.running),
                          ),
                        ),
                ),
                EmitEvent(
                  ownedRef,
                  InteractionOpened(meta: meta, request: second),
                ),
              ],
            ),
          );
          final handle = await adapter.open(ownedRef, OpenIntent.attachLive);
          final store = SessionStore(maxSessions: 1)..open(ownedRef);
          final subscription = handle.events.listen(
            (event) => store.apply(ownedRef, event),
          );
          addTearDown(subscription.cancel);
          await adapter.step();
          await adapter.step();
          final expected = firstIsInteraction ? [first.id] : <InteractionId>[];
          expect(
            store.peek(ownedRef)!.interactions.map((request) => request.id),
            expected,
          );
          expect(
            (await adapter.interactions!.pending(
              first.owner,
            )).items.map((request) => request.id),
            expected,
          );
          expect(adapter.commands, isEmpty);
        },
      );
    }

    test(
      'deferred read start denial completes and removes its Future',
      () async {
        final adapter = keep(
          scriptedAdapter(
            reads: [
              ScriptedRead(
                id: 'expired-read',
                ref: ownedRef,
                generation: 'expired-hydration',
                deferred: true,
                collections: [SessionCollection.timeline],
                build: (boundaries) => SessionSnapshot(
                  ref: ownedRef,
                  hydrationGeneration: 'expired-hydration',
                  timeline: SnapshotCollection(
                    values: const [],
                    boundary: boundaries[SessionCollection.timeline]!,
                  ),
                ),
              ),
            ],
            steps: const [
              AdvanceClock(Duration(minutes: 6)),
              StartCollectionRead('expired-read', SessionCollection.timeline),
            ],
          ),
        );
        final handle = await adapter.open(ownedRef, OpenIntent.viewHistory);
        final denied = isA<CapabilityUnavailable>().having(
          (error) => error.reason,
          'reason',
          'ownershipUnavailable',
        );
        final failure = expectLater(handle.snapshot(), throwsA(denied));
        expect(adapter.pendingReadCount, 1);
        await adapter.step();
        await expectLater(adapter.step(), throwsA(denied));
        await failure;
        expect(adapter.pendingReadCount, 0);
        expect(adapter.commands, isEmpty);
      },
    );

    for (final deferred in [false, true]) {
      for (final invalidBoundary in [false, true]) {
        test(
          'failed read resolves its Future (deferred=$deferred, invalidBoundary=$invalidBoundary)',
          () async {
            final adapter = keep(
              scriptedAdapter(
                reads: [
                  ScriptedRead(
                    id: 'failed-read',
                    ref: ownedRef,
                    generation: 'failure-hydration',
                    deferred: deferred,
                    collections: [SessionCollection.timeline],
                    build: (boundaries) {
                      if (!invalidBoundary) {
                        throw StateError('authored builder failed');
                      }
                      return SessionSnapshot(
                        ref: ownedRef,
                        hydrationGeneration: 'failure-hydration',
                        timeline: SnapshotCollection(
                          values: const [],
                          boundary: SnapshotBoundary(
                            owner: const SessionOwner(ownedRef),
                            hydrationGeneration: 'failure-hydration',
                            readStart: scriptedPosition(99),
                            readStartedAt: scriptedNow,
                          ),
                        ),
                      );
                    },
                  ),
                ],
                steps: deferred
                    ? [
                        const StartCollectionRead(
                          'failed-read',
                          SessionCollection.timeline,
                        ),
                        const FinishRead('failed-read'),
                      ]
                    : const [],
              ),
            );
            final handle = await adapter.open(ownedRef, OpenIntent.viewHistory);
            final failure = expectLater(handle.snapshot(), throwsStateError);
            if (deferred) {
              await adapter.step();
              await expectLater(adapter.step(), throwsStateError);
            }
            await failure;
            expect(adapter.pendingReadCount, 0);
          },
        );
      }
    }
    test(
      'owned read/send/select/interrupt preserve original intent and correlation',
      () async {
        final adapter = keep(ownedStream().adapter);
        final HarnessAdapter port = adapter;
        final summaries = await port.listSessions(
          SessionQuery(project: project),
        );
        expect(summaries.items.map((summary) => summary.info.ref), [
          ownedRef,
          childRef,
        ]);
        final SessionHandle handle = await port.open(
          ownedRef,
          OpenIntent.attachLive,
        );
        final snapshot = await handle.snapshot();
        expect(snapshot.info!.value.ref, ownedRef);
        expect(snapshot.timeline!.values, isEmpty);
        expect(snapshot.timeline!.boundary.readStart, scriptedPosition(0));
        expect(adapter.commands, isEmpty);
        final sent = await handle.send(scriptedDraft(), id: sendId);
        final selected = await handle.select(scriptedSelection, id: selectId);
        final interrupted = await handle.interrupt(
          scriptedInterrupt,
          id: interruptId,
        );
        expect(
          [sent.id, selected.id, interrupted.id],
          [sendId, selectId, interruptId],
        );
        expect(
          [
            sent,
            selected,
            interrupted,
          ].every((receipt) => receipt.admissionKnown),
          isTrue,
        );
        expect(adapter.commands.map((command) => command.operation.known), [
          MutationOperation.prompt,
          MutationOperation.selection,
          MutationOperation.interrupt,
        ]);
        expect(adapter.commands.first.intent, promptIntent(scriptedDraft()));
        expect(
          adapter.commands.first.owner.hasSameScope(
            const SessionOwner(ownedRef),
          ),
          isTrue,
        );
        expect(adapter.commands.first.connectedVersion, scriptedVersion);
        expect(adapter.remainingOutcomes, 0);
        expect(() => adapter.commands.clear(), throwsUnsupportedError);
        expect(port.workspace, isNull);
        expect([
          handle.queue,
          handle.undo,
          handle.work,
          handle.lifecycle,
        ], everyElement(isNull));
        await handle.detach();
        expect(adapter.commands, hasLength(3));
      },
    );

    final owner = const SessionOwner(ownedRef);
    final denials = <String, ScriptedAccess>{
      'stale ownership': scriptedAccess(
        owner,
        ownership: scriptedOwnership(
          OwnershipKind.hostOwned,
          observedAt: scriptedNow.subtract(const Duration(hours: 1)),
        ),
      ),
      'future ownership': scriptedAccess(
        owner,
        ownership: scriptedOwnership(
          OwnershipKind.hostOwned,
          observedAt: scriptedNow.add(const Duration(seconds: 1)),
        ),
      ),
      'expired ownership': scriptedAccess(
        owner,
        ownership: scriptedOwnership(
          OwnershipKind.hostOwned,
          expiresAt: scriptedNow,
        ),
      ),
      'unknown ownership': scriptedAccess(
        owner,
        ownership: const OwnershipInfo.unknown(
          reason: 'unverified',
          rawKind: 'future-owner-v9',
        ),
      ),
      'external ownership despite supported capability': scriptedAccess(
        owner,
        ownership: scriptedOwnership(OwnershipKind.savedHistory),
        capabilities: scriptedCapabilities(owner),
      ),
      'running elsewhere': scriptedAccess(
        owner,
        ownership: scriptedOwnership(OwnershipKind.runningElsewhere),
      ),
      'evidence owner collision': scriptedAccess(
        owner,
        evidenceOwner: const SessionOwner(childRef),
      ),
      'evidence version mismatch': scriptedAccess(
        owner,
        connectedVersion: 'synthetic-2',
      ),
      'capability scope mismatch': scriptedAccess(
        owner,
        capabilities: scriptedCapabilities(const SessionOwner(childRef)),
      ),
      'unknown support': scriptedAccess(
        owner,
        capabilities: scriptedCapabilities(
          owner,
          overrides: {
            'scripted.prompt': Capability(
              support: OpenValue.unknown('future-support-v9'),
              verified: true,
            ),
          },
        ),
      ),
      'unverified support': scriptedAccess(
        owner,
        capabilities: scriptedCapabilities(
          owner,
          overrides: {
            'scripted.prompt': Capability(
              support: const OpenValue.known(Support.host),
            ),
          },
        ),
      ),
      'unknown negotiation': scriptedAccess(owner, negotiated: null),
      'unknown model restriction': scriptedAccess(owner, modelAllowed: null),
      'denied policy': scriptedAccess(owner, policyAllowed: false),
      'unknown platform': scriptedAccess(owner, platformAllowed: null),
      'denied session state': scriptedAccess(owner, stateAllowed: false),
    };
    for (final entry in denials.entries) {
      test(
        '${entry.key} denies every mutation before outcome consumption',
        () async {
          final adapter = keep(ownedStream().adapter);
          final handle = await adapter.open(ownedRef, OpenIntent.attachLive);
          adapter.setAccess(owner, entry.value);
          expectUnavailable(await handle.send(scriptedDraft(), id: sendId));
          expect(adapter.commands, isEmpty);
          expect(adapter.remainingOutcomes, 3);
          // Fresh evidence is consulted at the next call, not cached at open.
          adapter.setAccess(owner, scriptedAccess(owner));
          expect(
            (await handle.send(scriptedDraft(), id: sendId)).admissionKnown,
            isTrue,
          );
          expect(adapter.commands, hasLength(1));
        },
      );
    }

    test(
      'manual time advancement invalidates a previously opened handle',
      () async {
        final adapter = keep(ownedStream().adapter);
        final handle = await adapter.open(ownedRef, OpenIntent.attachLive);
        adapter.clock.advance(const Duration(minutes: 6));
        expectUnavailable(
          await handle.send(scriptedDraft(), id: sendId),
          reason: 'ownershipUnavailable',
        );
        await expectLater(
          handle.snapshot(),
          throwsA(isA<CapabilityUnavailable>()),
        );
        expect(adapter.commands, isEmpty);
      },
    );

    test(
      'composite host/installation/project identity cannot borrow authority',
      () async {
        final adapter = keep(ownedStream().adapter);
        for (final ref in [
          const SessionRef(
            HostId('other-host'),
            HarnessInstanceId('scripted-installation'),
            'owned',
          ),
          const SessionRef(
            HostId('scripted-host'),
            HarnessInstanceId('other-installation'),
            'owned',
          ),
          const SessionRef(
            HostId('scripted-host'),
            HarnessInstanceId('scripted-installation'),
            'missing',
          ),
        ]) {
          await expectLater(
            adapter.open(ref, OpenIntent.viewHistory),
            throwsA(isA<CapabilityUnavailable>()),
          );
          expectUnavailable(
            await adapter.interactions!.respond(
              SessionOwner(ref),
              interactionId,
              scriptedResponse(),
              id: respondId,
            ),
          );
        }
        final external = await adapter.listSessions(
          SessionQuery(project: otherProject),
        );
        expect(external.items.single.info.ref, externalRef);
        final unknownProject = const ProjectRef(
          HostId('scripted-host'),
          '/synthetic/not-registered',
          upstreamProjectId: 'same-upstream',
        );
        await expectLater(
          adapter.listSessions(SessionQuery(project: unknownProject)),
          throwsA(isA<CapabilityUnavailable>()),
        );
        expectUnavailable(
          (await adapter.create(
            CreateSession(
              id: createId,
              harness: scriptedHarness,
              project: unknownProject,
            ),
          )).receipt,
        );
        expectUnavailable(
          await adapter.interactions!.respond(
            UnknownOwner(reason: 'unknown'),
            interactionId,
            scriptedResponse(),
            id: respondId,
          ),
        );
        expect(adapter.commands, isEmpty);
        expect(adapter.observerCount, 0);
      },
    );

    test(
      'unsupported deliveries, modalities and selections do not consume outcomes',
      () async {
        final adapter = keep(ownedStream().adapter);
        final handle = await adapter.open(ownedRef, OpenIntent.attachLive);
        final models = await adapter.catalog.models();
        expect(models.first.inputModalities['application/pdf'], isNull);
        expect(models.first.metadata!.value, {
          'unknownModality': 'future-media-v9',
        });
        final capabilities = await adapter.capabilities(owner: owner);
        expect(
          capabilities['future.support']!.support.value,
          'future-support-v9',
        );
        expect(capabilities['future.support']!.isAvailable, isFalse);
        for (final delivery in [
          const OpenValue.known(Delivery.queue),
          const OpenValue.known(Delivery.steer),
          OpenValue<Delivery>.unknown('future-delivery'),
        ]) {
          expectUnavailable(
            await handle.send(scriptedDraft(), id: sendId, delivery: delivery),
            reason: 'deliveryUnavailable',
          );
        }
        for (final mime in [
          'application/pdf',
          'image/avif',
          'application/unknown',
        ]) {
          final draft = PromptDraft(
            text: 'attachment',
            attachments: [
              AttachmentRef(
                id: 'opaque',
                mimeType: mime,
                content: OutputRef(id: 'content'),
              ),
            ],
          );
          expectUnavailable(
            await handle.send(draft, id: sendId),
            reason: 'modalityUnverified',
          );
        }
        expectUnavailable(
          await handle.select(
            const SelectionChange(selection: Selection(modelId: 'not-offered')),
            id: selectId,
          ),
          reason: 'selectionNotOffered',
        );
        expectUnavailable(
          await handle.select(
            const SelectionChange(
              selection: Selection(permissionMode: 'persistent'),
            ),
            id: selectId,
          ),
        );
        expectUnavailable(
          await handle.interrupt(
            const InterruptTarget(
              kind: OpenValue.known(InterruptKind.child),
              child: childRef,
            ),
            id: interruptId,
          ),
        );
        expect(adapter.commands, isEmpty);
        expect(adapter.remainingOutcomes, 3);
        expect(
          (await handle.send(scriptedDraft(), id: sendId)).admissionKnown,
          isTrue,
        );
      },
    );

    test(
      'child permissions use offered choice, owning scope, command and note',
      () async {
        final adapter = keep(offeredPermission().adapter);
        final parent = await adapter.open(ownedRef, OpenIntent.attachLive);
        final observed = <SessionEvent>[];
        final subscription = parent.events.listen(observed.add);
        addTearDown(subscription.cancel);
        for (var i = 0; i < 3; i++) {
          await adapter.step();
        }
        expect(
          adapter.commands,
          isEmpty,
        ); // No automatic responder in the fake.
        final pending = await adapter.interactions!.pending(
          const SessionOwner(childRef),
        );
        expect(
          pending.items.single.owner,
          const SessionOwner(childRef, origin: ownedRef),
        );
        expect(
          pending.items.single.choices.first.label,
          'Proceed for this request',
        );
        expectUnavailable(
          await parent.respond(
            interactionId,
            scriptedResponse(),
            id: respondId,
          ),
          reason: 'choiceNotOffered',
        );
        expectUnavailable(
          await adapter.interactions!.respond(
            ProjectOwner(otherProject, harness: scriptedHarness),
            interactionId,
            scriptedResponse(),
            id: respondId,
          ),
          reason: 'choiceNotOffered',
        );
        expectUnavailable(
          await adapter.interactions!.respond(
            const SessionOwner(childRef),
            interactionId,
            ApprovalResponse('persistent-not-offered'),
            id: respondId,
          ),
        );
        expect(adapter.remainingOutcomes, 1);
        final receipt = await adapter.interactions!.respond(
          const SessionOwner(childRef, origin: ownedRef),
          interactionId,
          scriptedResponse(),
          id: respondId,
        );
        expect(receipt.id, respondId);
        expect(
          receipt.owner.hasSameScope(const SessionOwner(childRef)),
          isTrue,
        );
        expect(
          adapter.commands.single.intent,
          responseIntent(interactionId, scriptedResponse()),
        );
        await adapter.step();
        final resolution = (observed.last as InteractionResolved).resolution;
        expect(resolution.kind.known, InteractionResolutionKind.self);
        expect(
          (resolution.response! as ApprovalResponse).note,
          'synthetic note',
        );
        expect(resolution.source!.value, {'syntheticResponder': 'this-client'});
        expectUnavailable(
          await adapter.interactions!.respond(
            const SessionOwner(childRef),
            interactionId,
            scriptedResponse(),
            id: const CommandId('late-reply'),
          ),
          reason: 'interactionNotPending',
        );
        await adapter.step();
        expect(
          (observed.last as InteractionResolved).resolution.kind.known,
          InteractionResolutionKind.elsewhere,
        );
        await adapter.step();
        final unknown = (observed.last as InteractionOpened).request;
        expect(unknown.automaticChoice, isNull);
        expect(unknown.choices.single.scope.value, 'future-scope-v9');
        expectUnavailable(
          await adapter.interactions!.respond(
            unknown.owner,
            unknown.id,
            ApprovalResponse('future-choice'),
            id: const CommandId('future-reply'),
          ),
          reason: 'unknownKind',
        );
        expect(adapter.commands, hasLength(1));
      },
    );

    test(
      'uncertain admission has no invented handle and cannot auto-replay',
      () async {
        final adapter = keep(errorAndUncertainAdmission().adapter);
        final created = await adapter.create(scriptedCreate());
        expect(created.receipt.state.known, ReceiptState.uncertain);
        expect(created.receipt.nativeRef, isNull);
        expect(created.handle, isNull);
        expect(adapter.observerCount, 0);
        final handle = await adapter.open(ownedRef, OpenIntent.attachLive);
        final sent = await handle.send(scriptedDraft(), id: sendId);
        expect(sent.state.known, ReceiptState.uncertain);
        expect(sent.error!.retryable, isTrue);
        expect(sent.error!.action!.known, ErrorAction.retryRecovery);
        expectUnavailable(
          await handle.send(scriptedDraft(), id: sendId),
          reason: 'reconciliationRequired',
        );
        expectUnavailable(
          (await adapter.create(scriptedCreate())).receipt,
          reason: 'reconciliationRequired',
        );
        final interrupted = await handle.interrupt(
          scriptedInterrupt,
          id: interruptId,
        );
        expect(interrupted.state.known, ReceiptState.rejected);
        expect(interrupted.error!.kind.known, ErrorKind.permissionRejected);
        final unknown = await handle.send(
          scriptedDraft(),
          id: const CommandId('unknown-receipt'),
        );
        expect(unknown.state.value, 'future-admission-v9');
        expect(unknown.admissionKnown, isFalse);
        while (adapter.remainingSteps > 0) {
          await adapter.step();
        }
        expect(adapter.commands, hasLength(4));
        expect(adapter.remainingOutcomes, 0);
      },
    );

    test(
      'saved history observes only and every optional facet is absent',
      () async {
        final adapter = keep(historyOnlyExternal().adapter);
        final handle = await adapter.open(externalRef, OpenIntent.viewHistory);
        final snapshot = await handle.snapshot();
        expect(snapshot.info!.value.ownership.kind, OwnershipKind.savedHistory);
        expect(snapshot.execution!.value.kind.known, ExecutionKind.unknown);
        await expectLater(
          adapter.open(externalRef, OpenIntent.attachLive),
          throwsA(isA<CapabilityUnavailable>()),
        );
        expectUnavailable(await handle.send(scriptedDraft(), id: sendId));
        expectUnavailable(
          await handle.interrupt(scriptedInterrupt, id: interruptId),
        );
        expectUnavailable(await handle.select(scriptedSelection, id: selectId));
        expectUnavailable(
          await handle.respond(
            interactionId,
            scriptedResponse(),
            id: respondId,
          ),
        );
        expect([
          adapter.workspace,
          adapter.interactions,
          handle.queue,
          handle.undo,
          handle.work,
          handle.lifecycle,
        ], everyElement(isNull));
        await handle.detach();
        expectUnavailable(
          await handle.send(scriptedDraft(), id: sendId),
          reason: 'detached',
        );
        expect(adapter.commands, isEmpty);
        expect(adapter.observerCount, 0);
      },
    );

    test(
      'non-atomic reads capture separate starts and finish in reverse order',
      () async {
        final adapter = keep(disconnectHydrate().adapter);
        final handle = await adapter.open(ownedRef, OpenIntent.attachLive);
        final old = handle.snapshot();
        final newer = handle.snapshot();
        expect(adapter.pendingReadCount, 2);
        for (var i = 0; i < 13; i++) {
          await adapter.step();
        }
        final snapshot = await newer;
        expect(snapshot.hydrationGeneration, 'new-hydration');
        expect(snapshot.timeline!.boundary.readStart, scriptedPosition(2));
        expect(snapshot.execution!.boundary.readStart, scriptedPosition(3));
        expect(
          snapshot.timeline!.boundary.readStartedAt,
          scriptedNow.add(const Duration(seconds: 1)),
        );
        expect(
          snapshot.execution!.boundary.readStartedAt,
          scriptedNow.add(const Duration(seconds: 2)),
        );
        expect(
          snapshot.timeline!.boundary.readCompletedAt,
          scriptedNow.add(const Duration(seconds: 2)),
        );
        expect(adapter.pendingReadCount, 1);
        await adapter.step();
        expect((await old).execution!.boundary.readStart, scriptedPosition(4));
        expect(adapter.pendingReadCount, 0);
      },
    );

    test(
      'detach isolates observers, cancels its read and does not mutate',
      () async {
        final adapter = keep(disconnectHydrate().adapter);
        final first = await adapter.open(ownedRef, OpenIntent.attachLive);
        final second = await adapter.open(ownedRef, OpenIntent.attachLive);
        final events = <SessionEvent>[];
        final firstSubscription = first.events.listen(
          (_) => fail('Detached observer received an event'),
        )..pause();
        final secondSubscription = second.events.listen(events.add);
        addTearDown(firstSubscription.cancel);
        addTearDown(secondSubscription.cancel);
        final failedRead = expectLater(
          first.snapshot(),
          throwsA(isA<CapabilityUnavailable>()),
        );
        await first.detach();
        await failedRead;
        firstSubscription.resume();
        await adapter.step();
        expect(events, hasLength(1));
        expect(adapter.observerCount, 1);
        expect(adapter.pendingReadCount, 0);
        expect(adapter.commands, isEmpty);
        await adapter.dispose();
        await adapter.dispose();
        expect(adapter.observerCount, 0);
        expectUnavailable(
          await second.interrupt(scriptedInterrupt, id: interruptId),
        );
      },
    );

    test(
      'dispose cancels outstanding reads and is not blocked by paused listeners',
      () async {
        final adapter = keep(disconnectHydrate().adapter);
        final handle = await adapter.open(ownedRef, OpenIntent.attachLive);
        final subscription = handle.events.listen(
          (_) => fail('Disposed observer received data'),
        )..pause();
        addTearDown(subscription.cancel);
        final completion = expectLater(
          handle.snapshot(),
          throwsA(isA<CapabilityUnavailable>()),
        );
        await adapter.step();
        await adapter.dispose();
        await completion;
        subscription.resume();
        expect(adapter.pendingReadCount, 0);
        await expectLater(
          adapter.capabilities(),
          throwsA(isA<CapabilityUnavailable>()),
        );
      },
    );

    test(
      'finite scripts reject overflow, exhaustion, unsupported queries and wrong intents',
      () async {
        final adapter = keep(ownedStream().adapter);
        final handle = await adapter.open(ownedRef, OpenIntent.viewHistory);
        await expectLater(
          handle.snapshot(limit: 0),
          throwsA(isA<CapabilityUnavailable>()),
        );
        await expectLater(
          handle.snapshot(before: HistoryCursor('unscripted')),
          throwsA(isA<CapabilityUnavailable>()),
        );
        await expectLater(
          handle.send(PromptDraft(text: 'not the original intent'), id: sendId),
          throwsStateError,
        );
        expect(adapter.commands, isEmpty);
        expect(adapter.remainingOutcomes, 3);
        await handle.snapshot();
        await expectLater(
          handle.snapshot(),
          throwsA(isA<CapabilityUnavailable>()),
        );
        while (adapter.remainingSteps > 0) {
          await adapter.step();
        }
        await expectLater(adapter.step(), throwsStateError);
        expect(
          () => adapter.clock.advance(const Duration(seconds: -1)),
          throwsArgumentError,
        );
        expect(
          () => ScriptedHarnessAdapter(
            descriptor: adapter.descriptor,
            clock: ScriptedClock(scriptedNow),
            access: const {},
            sessions: const [],
            steps: List.filled(257, const AdvanceClock(Duration.zero)),
          ),
          throwsArgumentError,
        );
      },
    );
  });
}
