import 'package:codewalk_core/codewalk_core.dart';

import 'scripted_harness_adapter.dart';

// Every value below is synthetic. No Codex/Claude/native recording, G2 fit or
// G3 shared-screen acceptance is implied by this domain-only support.
const scriptedHarness = HarnessRef(
  HostId('scripted-host'),
  HarnessInstanceId('scripted-installation'),
);
const scriptedVersion = 'synthetic-1';
const ownedRef = SessionRef(
  HostId('scripted-host'),
  HarnessInstanceId('scripted-installation'),
  'owned',
);
const childRef = SessionRef(
  HostId('scripted-host'),
  HarnessInstanceId('scripted-installation'),
  'child',
);
const externalRef = SessionRef(
  HostId('scripted-host'),
  HarnessInstanceId('scripted-installation'),
  'external',
);
const project = ProjectRef(
  HostId('scripted-host'),
  '/synthetic/project',
  upstreamProjectId: 'same-upstream',
);
const otherProject = ProjectRef(
  HostId('scripted-host'),
  '/synthetic/other',
  upstreamProjectId: 'same-upstream',
);
const sendId = CommandId('scripted-send');
const selectId = CommandId('scripted-select');
const interruptId = CommandId('scripted-interrupt');
const respondId = CommandId('scripted-respond');
const createId = CommandId('scripted-create');
const interactionId = InteractionId('coincident-request-id');
const assistantId = ItemId('assistant');
final scriptedNow = DateTime.utc(2026, 10, 4, 12);

final class ScriptedScenario {
  const ScriptedScenario(this.name, this.adapter, {this.ref = ownedRef});
  final String name;
  final ScriptedHarnessAdapter adapter;
  final SessionRef ref;
}

StreamPosition scriptedPosition(int seq, {String epoch = 'epoch'}) =>
    StreamPosition(
      id: 'scripted-observer',
      epoch: epoch,
      seq: BigInt.from(seq),
    );

SourceProvenance scriptedSource(
  String type, {
  HarnessRef harness = scriptedHarness,
  String? eventId,
}) => SourceProvenance(
  harness: harness,
  version: scriptedVersion,
  nativeType: type,
  nativeEventId: eventId,
);

EventMeta scriptedMeta(
  int seq, {
  DomainOwner owner = const SessionOwner(ownedRef),
  String? eventId,
  String epoch = 'epoch',
}) => EventMeta(
  owner: owner,
  position: scriptedPosition(seq, epoch: epoch),
  receivedAt: scriptedNow,
  source: scriptedSource(
    'synthetic.observation',
    harness: owner.harness ?? scriptedHarness,
    eventId: eventId ?? 'observation-$seq',
  ),
);

OwnershipInfo scriptedOwnership(
  OwnershipKind kind, {
  DateTime? observedAt,
  DateTime? expiresAt,
}) => OwnershipInfo.known(
  kind,
  proof: OwnershipProof(
    source: 'synthetic-script',
    observedAt: observedAt ?? scriptedNow,
    expiresAt: expiresAt,
  ),
);

CapabilitySet scriptedCapabilities(
  DomainOwner owner, {
  bool historyOnly = false,
  Map<String, Capability> overrides = const {},
}) => CapabilitySet(
  {
    for (final name in ['history.list', 'history.read', 'catalog.models'])
      name: Capability(
        support: const OpenValue.known(Support.host),
        verified: true,
      ),
    for (final name in [
      'history.liveAttach',
      'scripted.create',
      'scripted.prompt',
      'scripted.interrupt',
      'scripted.selection',
      'approval.interactive',
    ])
      name: Capability(
        support: OpenValue.known(
          historyOnly ? Support.unavailable : Support.host,
        ),
        verified: !historyOnly,
        reason: historyOnly ? 'historyOnly' : null,
      ),
    for (final name in [
      'queue',
      'undo',
      'workspace.terminal',
      'approval.forms',
      'prompt.steer',
    ])
      name: Capability(
        support: const OpenValue.known(Support.unavailable),
        reason: 'notInSyntheticProfile',
      ),
    'future.support': Capability(
      support: OpenValue.unknown('future-support-v9'),
      verified: true,
    ),
    ...overrides,
  },
  harness: scriptedHarness,
  connectedVersion: scriptedVersion,
  scope: owner,
);

/// Affirmative restrictions are authored fixture evidence, never adapter defaults.
ScriptedAccess scriptedAccess(
  DomainOwner owner, {
  OwnershipInfo? ownership,
  CapabilitySet? capabilities,
  DomainOwner? evidenceOwner,
  String connectedVersion = scriptedVersion,
  bool? negotiated = true,
  bool? modelAllowed = true,
  bool? policyAllowed = true,
  bool? platformAllowed = true,
  bool? stateAllowed = true,
  String? selectedModelId = 'model-alpha',
}) => ScriptedAccess(
  capabilities:
      capabilities ??
      scriptedCapabilities(
        owner,
        historyOnly: ownership?.kind == OwnershipKind.savedHistory,
      ),
  evidence: ScopedCapabilityEvidence(
    owner: evidenceOwner ?? owner,
    connectedVersion: connectedVersion,
    ownership: owner is SessionOwner
        ? ownership ?? scriptedOwnership(OwnershipKind.hostOwned)
        : null,
    authorityProof: owner is SessionOwner
        ? null
        : OwnershipProof(
            source: 'synthetic-authority',
            observedAt: scriptedNow,
          ),
  ),
  negotiated: negotiated,
  modelAllowed: modelAllowed,
  policyAllowed: policyAllowed,
  platformAllowed: platformAllowed,
  stateAllowed: stateAllowed,
  selectedModelId: selectedModelId,
);

PromptDraft scriptedDraft() => PromptDraft(
  text: 'synthetic prompt',
  selection: const Selection(modelId: 'model-alpha'),
  metadata: CanonicalValue({'synthetic': true}),
  attachments: [
    AttachmentRef(
      id: 'picture',
      mimeType: 'image/png',
      name: 'synthetic.png',
      content: OutputRef(
        id: 'opaque-picture',
        mimeType: 'image/png',
        sizeBytes: 3,
      ),
    ),
  ],
  mentions: [
    MentionRef(
      id: 'mention',
      kind: const OpenValue.known(MentionKind.file),
      label: 'synthetic file',
      target: 'opaque-file',
    ),
  ],
);

const scriptedSelection = SelectionChange(
  selection: Selection(modelId: 'model-beta'),
);
const scriptedInterrupt = InterruptTarget(
  kind: OpenValue.known(InterruptKind.turn),
  turn: TurnId('turn'),
);
CreateSession scriptedCreate() => CreateSession(
  id: createId,
  harness: scriptedHarness,
  project: project,
  title: 'synthetic create',
);
ApprovalResponse scriptedResponse() =>
    ApprovalResponse('proceed-x7', note: 'synthetic note');

OriginalCommand scriptedCommand(
  CommandId id,
  DomainOwner owner,
  MutationOperation operation,
  CanonicalValue intent,
) => OriginalCommand(
  id: id,
  harness: scriptedHarness,
  owner: owner,
  operation: OpenValue.known(operation),
  connectedVersion: scriptedVersion,
  intent: intent,
);

ScriptedOutcome acceptedOutcome(
  CommandId id,
  DomainOwner owner,
  MutationOperation operation,
  CanonicalValue intent,
) => ScriptedOutcome(
  command: scriptedCommand(id, owner, operation, intent),
  receipt: CommandReceipt.accepted(id: id, owner: owner),
);

ItemMeta scriptedItemMeta(
  String id, {
  bool complete = false,
  HarnessRef harness = scriptedHarness,
}) => ItemMeta(
  id: ItemId(id),
  generation: 'item-generation',
  turnId: const TurnId('turn'),
  ordinal: 0,
  status: OpenValue.known(
    complete ? ItemStatus.completed : ItemStatus.streaming,
  ),
  source: scriptedSource('synthetic.item', harness: harness),
);

AssistantText scriptedText(String text, {bool complete = false}) =>
    AssistantText(
      meta: scriptedItemMeta('assistant', complete: complete),
      text: text,
      complete: complete,
    );
ItemDelta scriptedDelta(
  int seq,
  String text, {
  String id = 'assistant',
  String? eventId,
}) => ItemDelta(
  meta: scriptedMeta(seq, eventId: eventId),
  itemId: ItemId(id),
  field: const OpenValue.known(DeltaField.text),
  text: text,
  generation: 'item-generation',
);

SessionInfo scriptedInfo(SessionRef ref) => SessionInfo(
  ref: ref,
  title: 'synthetic ${ref.nativeId}',
  project: ref == externalRef ? otherProject : project,
  ownership: scriptedOwnership(
    ref == externalRef ? OwnershipKind.savedHistory : OwnershipKind.hostOwned,
  ),
  lineage: ref == childRef
      ? const SessionLineage(parent: ownedRef)
      : const SessionLineage(),
);

ScriptedHarnessAdapter scriptedAdapter({
  Iterable<ScriptedStep> steps = const [],
  Iterable<ScriptedRead> reads = const [],
  Iterable<ScriptedOutcome> outcomes = const [],
  bool enableInteractions = true,
}) => ScriptedHarnessAdapter(
  descriptor: HarnessDescriptor(
    ref: scriptedHarness,
    kind: 'synthetic-script',
    version: scriptedVersion,
    stability: const OpenValue.known(Stability.experimental),
    compatibility: const OpenValue.known(Compatibility.untested),
    reason: 'test-only synthetic evidence',
  ),
  clock: ScriptedClock(scriptedNow),
  access: {
    const GlobalOwner(scriptedHarness): scriptedAccess(
      const GlobalOwner(scriptedHarness),
    ),
    ProjectOwner(project, harness: scriptedHarness): scriptedAccess(
      ProjectOwner(project, harness: scriptedHarness),
    ),
    ProjectOwner(otherProject, harness: scriptedHarness): scriptedAccess(
      ProjectOwner(otherProject, harness: scriptedHarness),
    ),
    for (final ref in [ownedRef, childRef, externalRef])
      SessionOwner(ref): scriptedAccess(
        SessionOwner(ref),
        ownership: scriptedInfo(ref).ownership,
      ),
  },
  sessions: [
    for (final ref in [ownedRef, childRef, externalRef]) scriptedInfo(ref),
  ],
  models: [
    ModelEntry(
      id: 'model-alpha',
      providerId: 'synthetic-provider',
      label: 'Synthetic Alpha',
      inputModalities: {
        'text/plain': true,
        'image/png': true,
        'application/pdf': null,
        'image/avif': null,
      },
      metadata: CanonicalValue({'unknownModality': 'future-media-v9'}),
    ),
    ModelEntry(
      id: 'model-beta',
      providerId: 'synthetic-provider',
      label: 'Synthetic Beta',
      inputModalities: {'text/plain': true},
    ),
  ],
  steps: steps,
  reads: reads,
  outcomes: outcomes,
  enableInteractions: enableInteractions,
);

ScriptedScenario ownedStream() {
  final fragment = scriptedDelta(3, '-fragment', eventId: 'fragment');
  const foreign = SessionRef(
    HostId('other-host'),
    HarnessInstanceId('scripted-installation'),
    'owned',
  );
  return ScriptedScenario(
    'owned_stream',
    scriptedAdapter(
      reads: [
        ScriptedRead(
          id: 'owned-read',
          ref: ownedRef,
          generation: 'owned-hydration',
          collections: [
            SessionCollection.info,
            SessionCollection.timeline,
            SessionCollection.execution,
          ],
          build: (b) => SessionSnapshot(
            ref: ownedRef,
            hydrationGeneration: 'owned-hydration',
            info: SnapshotValue(
              value: scriptedInfo(ownedRef),
              boundary: b[SessionCollection.info]!,
            ),
            timeline: SnapshotCollection(
              values: const [],
              boundary: b[SessionCollection.timeline]!,
            ),
            execution: SnapshotValue(
              value: const ExecutionState(
                kind: OpenValue.known(ExecutionKind.idle),
              ),
              boundary: b[SessionCollection.execution]!,
            ),
          ),
        ),
      ],
      outcomes: [
        acceptedOutcome(
          sendId,
          const SessionOwner(ownedRef),
          MutationOperation.prompt,
          promptIntent(scriptedDraft()),
        ),
        acceptedOutcome(
          selectId,
          const SessionOwner(ownedRef),
          MutationOperation.selection,
          CanonicalValue(selectionIntent(scriptedSelection.selection)),
        ),
        acceptedOutcome(
          interruptId,
          const SessionOwner(ownedRef),
          MutationOperation.interrupt,
          interruptIntent(scriptedInterrupt),
        ),
      ],
      steps: [
        EmitEvent(
          ownedRef,
          ExecutionChanged(
            meta: scriptedMeta(1),
            state: const ExecutionState(
              kind: OpenValue.known(ExecutionKind.running),
            ),
          ),
        ),
        EmitEvent(
          ownedRef,
          ItemUpserted(meta: scriptedMeta(2), item: scriptedText('prefix')),
        ),
        EmitEvent(ownedRef, fragment),
        EmitEvent(ownedRef, fragment),
        EmitEvent(
          ownedRef,
          ItemUpserted(
            meta: scriptedMeta(4),
            item: scriptedText('complete answer', complete: true),
          ),
        ),
        EmitEvent(ownedRef, scriptedDelta(5, '-late')),
        EmitEvent(
          ownedRef,
          ExecutionChanged(
            meta: scriptedMeta(6),
            state: const ExecutionState(
              kind: OpenValue.known(ExecutionKind.idle),
              lastOutcome: ExecutionOutcome(
                OpenValue.known(ExecutionOutcomeKind.succeeded),
              ),
            ),
          ),
        ),
        EmitEvent(
          ownedRef,
          ItemUpserted(
            meta: scriptedMeta(7),
            item: UnknownItem(
              meta: scriptedItemMeta('unknown', complete: true),
              rawType: 'future.item.v9',
              raw: CanonicalValue({'flag': true}),
            ),
          ),
        ),
        EmitEvent(
          ownedRef,
          UnknownEvent(
            meta: scriptedMeta(8),
            rawType: 'future.event.v9',
            raw: CanonicalValue({'flag': true}),
          ),
        ),
        EmitEvent(ownedRef, scriptedDelta(9, 'orphan fragment', id: 'missing')),
        EmitEvent(
          ownedRef,
          ExecutionChanged(
            meta: scriptedMeta(10, owner: const SessionOwner(foreign)),
            state: const ExecutionState(
              kind: OpenValue.known(ExecutionKind.running),
            ),
          ),
        ),
        EmitEvent(
          ownedRef,
          ExecutionChanged(
            meta: scriptedMeta(11, epoch: 'unadopted-epoch'),
            state: const ExecutionState(
              kind: OpenValue.known(ExecutionKind.running),
            ),
          ),
        ),
      ],
    ),
  );
}

InteractionRequest scriptedPermission({
  DomainOwner owner = const SessionOwner(childRef, origin: ownedRef),
  String choice = 'proceed-x7',
}) => InteractionRequest(
  id: interactionId,
  owner: owner,
  kind: const OpenValue.known(InteractionKind.permission),
  title: 'Synthetic permission',
  autoApprovable: true,
  choices: [
    ApprovalChoice(
      id: choice,
      label: 'Proceed for this request',
      allows: true,
      scope: const OpenValue.known(ApprovalScope.once),
      resolutionScope: const OpenValue.known(ResolutionScope.request),
      acceptsNote: true,
    ),
    ApprovalChoice(
      id: 'leave-x8',
      label: 'Leave unchanged',
      allows: false,
      scope: const OpenValue.known(ApprovalScope.once),
      resolutionScope: const OpenValue.known(ResolutionScope.request),
      acceptsNote: true,
    ),
  ],
);

ScriptedScenario offeredPermission() {
  final request = scriptedPermission();
  final parent = scriptedPermission(
    owner: const SessionOwner(ownedRef),
    choice: 'parent-only',
  );
  final projectRequest = scriptedPermission(
    owner: ProjectOwner(otherProject, harness: scriptedHarness),
    choice: 'project-only',
  );
  final unknown = InteractionRequest(
    id: const InteractionId('unknown-choice'),
    owner: const SessionOwner(childRef, origin: ownedRef),
    kind: OpenValue.unknown('future.permission.v9'),
    title: 'Unknown permission',
    autoApprovable: true,
    choices: [
      ApprovalChoice(
        id: 'future-choice',
        label: 'Future scope',
        allows: true,
        scope: OpenValue.unknown('future-scope-v9'),
        resolutionScope: const OpenValue.known(ResolutionScope.request),
      ),
    ],
  );
  return ScriptedScenario(
    'offered_permission',
    scriptedAdapter(
      outcomes: [
        acceptedOutcome(
          respondId,
          request.owner,
          MutationOperation.respond,
          responseIntent(interactionId, scriptedResponse()),
        ),
      ],
      steps: [
        EmitEvent(
          ownedRef,
          InteractionOpened(meta: scriptedMeta(1), request: request),
        ),
        EmitEvent(
          ownedRef,
          InteractionOpened(meta: scriptedMeta(2), request: parent),
        ),
        EmitEvent(
          ownedRef,
          InteractionOpened(meta: scriptedMeta(3), request: projectRequest),
        ),
        EmitEvent(
          ownedRef,
          InteractionResolved(
            meta: scriptedMeta(4),
            resolution: InteractionResolution(
              id: interactionId,
              owner: request.owner,
              kind: const OpenValue.known(InteractionResolutionKind.self),
              response: scriptedResponse(),
              resolvedAt: scriptedNow,
              source: CanonicalValue({'syntheticResponder': 'this-client'}),
            ),
          ),
        ),
        EmitEvent(
          ownedRef,
          InteractionResolved(
            meta: scriptedMeta(5),
            resolution: InteractionResolution(
              id: interactionId,
              owner: parent.owner,
              kind: const OpenValue.known(InteractionResolutionKind.elsewhere),
              resolvedAt: scriptedNow,
              source: CanonicalValue({'syntheticResponder': 'other-client'}),
            ),
          ),
        ),
        EmitEvent(
          ownedRef,
          InteractionOpened(meta: scriptedMeta(6), request: unknown),
        ),
      ],
    ),
  );
}

UsageObservation scriptedUsage(
  String id,
  num input, {
  num? output,
  num amount = 0.75,
  bool partial = false,
}) => UsageObservation(
  id: id,
  owner: const SessionOwner(ownedRef),
  scope: const OpenValue.known(UsageScope.session),
  source: const OpenValue.known(UsageSource.hostConnector),
  observedAt: scriptedNow,
  tokens: TokenBreakdown(input: input, output: output),
  cost: Cost(
    amount: amount,
    currency: 'USD',
    estimated: true,
    partial: partial,
    cumulative: true,
  ),
  partial: partial,
  cumulative: true,
  aggregationKey: 'synthetic-session-ledger',
  provenance: scriptedSource('synthetic.usage'),
);

UsageObservation scriptedQuota({SessionRef ref = ownedRef}) => UsageObservation(
  id: 'quota',
  owner: SessionOwner(ref),
  scope: const OpenValue.known(UsageScope.account),
  source: const OpenValue.known(UsageSource.hostConnector),
  observedAt: scriptedNow,
  quotas: [
    QuotaWindow(
      id: 'rolling',
      label: 'Synthetic rolling window',
      source: const OpenValue.known(UsageSource.hostConnector),
      usedPercent: 123.4,
    ),
  ],
  partial: true,
);

ScriptedScenario structuredUsage() {
  final first = UsageObserved(
    meta: scriptedMeta(2),
    observation: scriptedUsage('cumulative-1', 100, output: 40, amount: 0.5),
  );
  return ScriptedScenario(
    'structured_usage',
    scriptedAdapter(
      steps: [
        EmitEvent(
          ownedRef,
          UsageObserved(
            meta: scriptedMeta(1),
            observation: UsageObservation(
              id: 'partial-turn',
              owner: const SessionOwner(ownedRef),
              scope: const OpenValue.known(UsageScope.turn),
              source: const OpenValue.known(UsageSource.estimate),
              observedAt: scriptedNow,
              tokens: TokenBreakdown(input: 10),
              cost: Cost(amount: 0.12, estimated: true, partial: true),
              partial: true,
            ),
          ),
        ),
        EmitEvent(ownedRef, first),
        EmitEvent(ownedRef, first),
        EmitEvent(
          ownedRef,
          UsageObserved(
            meta: scriptedMeta(4),
            observation: scriptedUsage('cumulative-2', 125),
          ),
        ),
        EmitEvent(
          ownedRef,
          UsageObserved(
            meta: scriptedMeta(5),
            observation: scriptedUsage(
              'partial-series',
              3,
              amount: 0.03,
              partial: true,
            ),
          ),
        ),
        EmitEvent(
          ownedRef,
          UsageObserved(meta: scriptedMeta(6), observation: scriptedQuota()),
        ),
        EmitEvent(
          ownedRef,
          UsageObserved(
            meta: scriptedMeta(7),
            observation: UsageObservation(
              id: 'unknown-usage',
              owner: const SessionOwner(ownedRef),
              scope: OpenValue.unknown('future-scope-v9'),
              source: OpenValue.unknown('future-source-v9'),
              observedAt: scriptedNow,
              cost: Cost(partial: true),
              partial: true,
            ),
          ),
        ),
        EmitEvent(
          ownedRef,
          UsageObserved(
            meta: scriptedMeta(8),
            observation: UsageObservation(
              id: 'foreign-usage',
              owner: const SessionOwner(
                SessionRef(
                  HostId('other-host'),
                  HarnessInstanceId('scripted-installation'),
                  'owned',
                ),
              ),
              scope: const OpenValue.known(UsageScope.session),
              source: const OpenValue.known(UsageSource.native),
              observedAt: scriptedNow,
              tokens: TokenBreakdown(input: 999),
            ),
          ),
        ),
      ],
    ),
  );
}

ErrorInfo scriptedNetworkError() => ErrorInfo(
  kind: const OpenValue.known(ErrorKind.network),
  rawType: 'synthetic.transport.lost',
  rawMessage: 'Synthetic transport lost after submission',
  retryable: true,
  action: const OpenValue.known(ErrorAction.retryRecovery),
  details: CanonicalValue({'synthetic': true}),
);

ScriptedScenario errorAndUncertainAdmission() {
  final error = scriptedNetworkError();
  final create = scriptedCreate();
  final createOwner = ProjectOwner(project, harness: scriptedHarness);
  return ScriptedScenario(
    'error_and_uncertain_admission',
    scriptedAdapter(
      outcomes: [
        ScriptedOutcome(
          command: scriptedCommand(
            createId,
            createOwner,
            MutationOperation.create,
            createIntent(create),
          ),
          receipt: CommandReceipt.uncertain(
            id: createId,
            owner: createOwner,
            reason: 'noAdmissionEvidence',
            error: error,
          ),
        ),
        ScriptedOutcome(
          command: scriptedCommand(
            sendId,
            const SessionOwner(ownedRef),
            MutationOperation.prompt,
            promptIntent(scriptedDraft()),
          ),
          receipt: CommandReceipt.uncertain(
            id: sendId,
            owner: const SessionOwner(ownedRef),
            reason: 'noAdmissionEvidence',
            error: error,
          ),
        ),
        ScriptedOutcome(
          command: scriptedCommand(
            interruptId,
            const SessionOwner(ownedRef),
            MutationOperation.interrupt,
            interruptIntent(scriptedInterrupt),
          ),
          receipt: CommandReceipt.rejected(
            id: interruptId,
            owner: const SessionOwner(ownedRef),
            error: ErrorInfo(
              kind: const OpenValue.known(ErrorKind.permissionRejected),
              rawType: 'synthetic.turn.readOnly',
              rawMessage: 'Synthetic interruption rejected',
            ),
          ),
        ),
        ScriptedOutcome(
          command: scriptedCommand(
            const CommandId('unknown-receipt'),
            const SessionOwner(ownedRef),
            MutationOperation.prompt,
            promptIntent(scriptedDraft()),
          ),
          receipt: CommandReceipt.unknown(
            id: const CommandId('unknown-receipt'),
            owner: const SessionOwner(ownedRef),
            rawState: 'future-admission-v9',
            details: CanonicalValue({'synthetic': true}),
          ),
        ),
      ],
      steps: [
        EmitEvent(
          ownedRef,
          RetryScheduled(
            meta: scriptedMeta(1),
            attempt: 1,
            at: scriptedNow.add(const Duration(seconds: 30)),
            error: error,
          ),
        ),
        const EmitConnection(
          ConnectionState(kind: OpenValue.known(ConnectionKind.reconnecting)),
        ),
        EmitEvent(
          ownedRef,
          ExecutionChanged(
            meta: scriptedMeta(2),
            state: ExecutionState(
              kind: const OpenValue.known(ExecutionKind.idle),
              lastOutcome: ExecutionOutcome(
                const OpenValue.known(ExecutionOutcomeKind.failed),
                error: error,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

ScriptedScenario disconnectHydrate() {
  ScriptedRead read(String id, String generation, String text) => ScriptedRead(
    id: id,
    ref: ownedRef,
    generation: generation,
    deferred: true,
    collections: [SessionCollection.timeline, SessionCollection.execution],
    build: (b) => SessionSnapshot(
      ref: ownedRef,
      hydrationGeneration: generation,
      timeline: SnapshotCollection(
        values: [scriptedText(text)],
        boundary: b[SessionCollection.timeline]!,
      ),
      execution: SnapshotValue(
        value: const ExecutionState(kind: OpenValue.known(ExecutionKind.idle)),
        boundary: b[SessionCollection.execution]!,
      ),
    ),
  );
  return ScriptedScenario(
    'disconnect_hydrate',
    scriptedAdapter(
      reads: [
        read('old-read', 'old-hydration', 'obsolete prefix'),
        read('new-read', 'new-hydration', 'snapshot prefix'),
      ],
      steps: [
        EmitEvent(
          ownedRef,
          ExecutionChanged(
            meta: scriptedMeta(1),
            state: const ExecutionState(
              kind: OpenValue.known(ExecutionKind.running),
            ),
          ),
        ),
        EmitEvent(
          ownedRef,
          ItemUpserted(meta: scriptedMeta(2), item: scriptedText('prefix')),
        ),
        const EmitConnection(
          ConnectionState(kind: OpenValue.known(ConnectionKind.reconnecting)),
        ),
        const StartCollectionRead('old-read', SessionCollection.timeline),
        const AdvanceClock(Duration(seconds: 1)),
        const StartCollectionRead('new-read', SessionCollection.timeline),
        EmitEvent(ownedRef, scriptedDelta(3, '+live')),
        const AdvanceClock(Duration(seconds: 1)),
        const StartCollectionRead('new-read', SessionCollection.execution),
        EmitEvent(
          ownedRef,
          ExecutionChanged(
            meta: scriptedMeta(4),
            state: const ExecutionState(
              kind: OpenValue.known(ExecutionKind.running),
            ),
          ),
        ),
        const StartCollectionRead('old-read', SessionCollection.execution),
        EmitEvent(
          ownedRef,
          ItemUpserted(
            meta: scriptedMeta(5),
            item: scriptedText('authoritative finished', complete: true),
          ),
        ),
        const FinishRead('new-read'),
        const FinishRead('old-read'),
        EmitEvent(
          ownedRef,
          ExecutionChanged(
            meta: scriptedMeta(3, eventId: 'buffered-old-execution'),
            state: const ExecutionState(
              kind: OpenValue.known(ExecutionKind.idle),
            ),
          ),
        ),
        EmitEvent(ownedRef, scriptedDelta(6, '-late-after-hydration')),
      ],
    ),
  );
}

ScriptedScenario historyOnlyExternal() => ScriptedScenario(
  'history_only_external',
  scriptedAdapter(
    enableInteractions: false,
    reads: [
      ScriptedRead(
        id: 'external-read',
        ref: externalRef,
        generation: 'external-hydration',
        collections: [
          SessionCollection.info,
          SessionCollection.execution,
          SessionCollection.timeline,
          SessionCollection.usage,
        ],
        build: (b) => SessionSnapshot(
          ref: externalRef,
          hydrationGeneration: 'external-hydration',
          info: SnapshotValue(
            value: scriptedInfo(externalRef),
            boundary: b[SessionCollection.info]!,
          ),
          execution: SnapshotValue(
            value: const ExecutionState(
              kind: OpenValue.known(ExecutionKind.unknown),
            ),
            boundary: b[SessionCollection.execution]!,
          ),
          timeline: SnapshotCollection(
            values: [
              AssistantText(
                meta: scriptedItemMeta('history', complete: true),
                text: 'historical only',
                complete: true,
              ),
            ],
            boundary: b[SessionCollection.timeline]!,
          ),
          usage: SnapshotCollection(
            values: [scriptedQuota(ref: externalRef)],
            boundary: b[SessionCollection.usage]!,
          ),
        ),
      ),
    ],
    steps: [
      EmitEvent(
        externalRef,
        UnknownEvent(
          meta: scriptedMeta(1, owner: const SessionOwner(externalRef)),
          rawType: 'future.external.v9',
          raw: CanonicalValue({'synthetic': true}),
        ),
      ),
      EmitEvent(
        ownedRef,
        ExecutionChanged(
          meta: scriptedMeta(1),
          state: const ExecutionState(
            kind: OpenValue.known(ExecutionKind.running),
          ),
        ),
      ),
    ],
  ),
  ref: externalRef,
);
