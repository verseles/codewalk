import 'dart:convert';
import 'dart:io';

import 'package:codewalk_core/codewalk_core.dart';

/// Test-only translation of the committed native V2-005A capture.
///
/// Native frame indices are fixture cut points, never source sequence numbers.
/// Local canonical positions count projections, including multi-event fanout.
/// JSON and OpenCode field interpretation deliberately remain outside lib/.
final class ObservedA {
  ObservedA._(this.nativeEvents, this.messages, this.completed, this.admission)
    : ref = SessionRef(
        const HostId('fixture-a-host'),
        const HarnessInstanceId('fixture-a-opencode-2.0.22'),
        completed['id']! as String,
      ) {
    final admitted = _map(_map(admission['response'])['data']);
    // This capture contains one admitted execution turn with two assistant
    // steps. Native message ownership is retained independently in source.
    turnId = TurnId(jsonEncode([ref.storageKey, admitted['id'], 'turn']));
    eventsByNativeIndex = _translateEvents();
    events = List.unmodifiable(eventsByNativeIndex.expand((batch) => batch));
    historyItems = List.unmodifiable(_projectHistory());
    historyUsage = List.unmodifiable([
      for (var row = 0; row < messages.length; row++)
        if (messages[row]['type'] == 'assistant')
          _usage(
            messages[row],
            id: 'history-step:${messages[row]['id']}',
            stepId: messages[row]['id']! as String,
            observedAt: _instant(_map(messages[row]['time'])['completed']),
            provenance: _historySource(messages[row], row),
          ),
      _usage(
        completed,
        id: 'history-session:${ref.nativeId}',
        observedAt: _instant(_map(completed['time'])['idle']),
        provenance: _readSource('session-completed.json', 'session'),
      ),
    ]);
  }

  factory ObservedA.load() {
    // Walk from the test runner's working directory so package and repository
    // invocations read the same fixture without a hard-coded machine path.
    var root = Directory.current;
    while (!Directory(
      '${root.path}/test/contract/fixtures/opencode/2.0.22',
    ).existsSync()) {
      if (root.parent.path == root.path) {
        throw StateError(
          'V2-005A fixture unavailable from ${Directory.current}',
        );
      }
      root = root.parent;
    }
    final fixture = Directory(
      '${root.path}/test/contract/fixtures/opencode/2.0.22',
    );
    Object? read(String name) =>
        jsonDecode(File('${fixture.path}/$name').readAsStringSync());
    return ObservedA._(
      _maps(read('events.json')),
      _maps(_map(read('messages.json'))['data']),
      _map(_map(read('session-completed.json'))['data']),
      _map(read('prompt-admission.json')),
    );
  }

  static const streamId = 'fixture-a-local-observer';
  static const streamEpoch = 'fixture-a-live-1';
  static const pendingDerivation =
      'test-derived empty: recorded inbox delivered and no further admission; '
      'A has no final HTTP inbox capture';

  final SessionRef ref;
  late final TurnId turnId;
  final List<Map<String, Object?>> nativeEvents;
  final List<Map<String, Object?>> messages;
  final Map<String, Object?> completed;
  final Map<String, Object?> admission;
  late final List<List<SessionEvent>> eventsByNativeIndex;
  late final List<SessionEvent> events;
  late final List<TimelineItem> historyItems;
  late final List<UsageObservation> historyUsage;

  StreamPosition position(int seq) =>
      StreamPosition(id: streamId, epoch: streamEpoch, seq: BigInt.from(seq));

  List<SessionEvent> prefix(int nativeFrameCount) => List.unmodifiable(
    eventsByNativeIndex.take(nativeFrameCount).expand((batch) => batch),
  );

  ItemId itemId(String message, String kind, [Object? ordinal]) =>
      ItemId(jsonEncode([ref.storageKey, message, kind, ?ordinal]));

  SessionSnapshot snapshot({
    required String hydrationGeneration,
    required StreamPosition readStart,
  }) {
    final readAt = DateTime.utc(2026, 10, 4, 8, 25);
    SnapshotBoundary boundary(
      String file,
      String nativeType, {
      bool derived = false,
    }) => SnapshotBoundary(
      owner: SessionOwner(ref),
      hydrationGeneration: hydrationGeneration,
      readStart: readStart,
      readStartedAt: readAt,
      readCompletedAt: readAt.add(const Duration(milliseconds: 1)),
      source: _readSource(
        file,
        nativeType,
        extra: derived ? {'derivation': pendingDerivation} : const {},
      ),
      authority: OpenValue.known(
        derived ? SnapshotAuthority.derived : SnapshotAuthority.authoritative,
      ),
    );
    final lastAssistant = messages.lastWhere(
      (row) => row['type'] == 'assistant',
    );
    final model = _map(completed['model']);
    final location = _map(completed['location']);
    return SessionSnapshot(
      ref: ref,
      hydrationGeneration: hydrationGeneration,
      info: SnapshotValue(
        value: SessionInfo(
          ref: ref,
          title: completed['title']! as String,
          ownership: const OwnershipInfo.unknown(
            reason: 'A has no current ownership proof',
          ),
          project: ProjectRef(
            ref.host,
            location['directory']! as String,
            upstreamProjectId: completed['projectID']! as String,
          ),
          metadata: CanonicalValue({
            'fixture': 'A',
            'nativeTime': completed['time'],
            'nativeModel': model,
            'nativeLocation': location,
          }),
        ),
        boundary: boundary('session-completed.json', 'session'),
      ),
      timeline: SnapshotCollection(
        values: historyItems,
        boundary: boundary('messages.json', 'message'),
      ),
      execution: SnapshotValue(
        value: _succeededExecution,
        boundary: boundary('session-completed.json', 'session'),
      ),
      pending: SnapshotCollection<PendingInput>(
        values: const [],
        boundary: boundary(
          'events.json',
          'test-derived.pending',
          derived: true,
        ),
      ),
      usage: SnapshotCollection(
        values: historyUsage,
        boundary: boundary('session-completed.json', 'session'),
      ),
      selection: SnapshotValue(
        value: _selection(model, lastAssistant['agent']! as String),
        boundary: boundary('session-completed.json', 'session'),
      ),
    );
  }

  List<List<SessionEvent>> _translateEvents() {
    var seq = 0;
    final pending = <ItemId, PendingInput>{};
    final users = <String, UserInput>{};
    final tools = <ItemId, ToolCall>{};
    final result = <List<SessionEvent>>[];
    for (var index = 0; index < nativeEvents.length; index++) {
      final frame = nativeEvents[index];
      final data = _map(frame['data']);
      final type = frame['type']! as String;
      final nativeSource = _eventSource(frame, index);
      EventMeta meta() => EventMeta(
        owner: SessionOwner(ref),
        position: position(++seq),
        // This clock is test-local causal bookkeeping, not native created.
        receivedAt: DateTime.utc(
          2026,
          10,
          4,
          8,
          24,
        ).add(Duration(microseconds: seq)),
        source: nativeSource,
        rawRef: DiagnosticRef(
          id: 'fixture:A/events.json#$index:${frame['id']}',
          byteLength: utf8.encode(jsonEncode(frame)).length,
          redacted: true,
        ),
      );
      final batch = <SessionEvent>[];
      switch (type) {
        case 'session.inbox.enqueued':
          final nativeId = data['inboxID']! as String;
          final nativeItem = _map(data['item']);
          final text = _map(nativeItem['payload'])['text']! as String;
          final id = itemId(nativeId, 'user');
          final user = UserInput(
            meta: _itemMeta(id, nativeSource, ItemStatus.pending),
            text: text,
            delivery: const OpenValue.known(DeliveryState.accepted),
          );
          users[nativeId] = user;
          pending[id] = PendingInput(
            id: id,
            text: text,
            delivery: OpenValue.parse(
              nativeItem['delivery']! as String,
              Delivery.values,
            ),
          );
          batch.add(ItemUpserted(meta: meta(), item: user));
          batch.add(PendingInputChanged(meta: meta(), items: pending.values));
        case 'session.inbox.delivered':
          final nativeId = data['inboxID']! as String;
          final user = users[nativeId]!;
          final delivered = UserInput(
            meta: _itemMeta(user.id, nativeSource, ItemStatus.completed),
            text: user.text,
            delivery: const OpenValue.known(DeliveryState.delivered),
          );
          users[nativeId] = delivered;
          pending.remove(user.id);
          batch.add(ItemUpserted(meta: meta(), item: delivered));
          batch.add(PendingInputChanged(meta: meta(), items: pending.values));
        case 'session.execution.started':
          batch.add(
            ExecutionChanged(
              meta: meta(),
              state: const ExecutionState(
                kind: OpenValue.known(ExecutionKind.running),
              ),
            ),
          );
        case 'session.execution.succeeded':
          batch.add(ExecutionChanged(meta: meta(), state: _succeededExecution));
          // Native official projection changes only evt_ to msg_; correlate
          // that observed idle record rather than inventing an ended event.
          final messageId = (frame['id']! as String).replaceFirst(
            'evt_',
            'msg_',
          );
          batch.add(
            ItemUpserted(
              meta: meta(),
              item: TurnOutcome(
                meta: _itemMeta(
                  itemId(messageId, 'outcome'),
                  nativeSource,
                  ItemStatus.completed,
                ),
                kind: const OpenValue.known(OutcomeKind.succeeded),
              ),
            ),
          );
        case 'session.step.started':
          batch.add(
            SelectionChanged(
              meta: meta(),
              selection: _selection(
                _map(data['model']),
                data['agent']! as String,
              ),
            ),
          );
        case 'session.reasoning.started':
        case 'session.reasoning.ended':
        case 'session.text.started':
        case 'session.text.ended':
          final reasoning = type.startsWith('session.reasoning.');
          final complete = type.endsWith('.ended');
          final message = data['assistantMessageID']! as String;
          final ordinal = data['ordinal']! as int;
          final itemMeta = _itemMeta(
            itemId(message, reasoning ? 'reasoning' : 'text', ordinal),
            nativeSource,
            complete ? ItemStatus.completed : ItemStatus.streaming,
            message: message,
            ordinal: ordinal,
          );
          final text = complete ? data['text']! as String : '';
          batch.add(
            ItemUpserted(
              meta: meta(),
              item: reasoning
                  ? Reasoning(meta: itemMeta, text: text, complete: complete)
                  : AssistantText(
                      meta: itemMeta,
                      text: text,
                      complete: complete,
                    ),
            ),
          );
        case 'session.reasoning.delta':
        case 'session.text.delta':
          final reasoning = type == 'session.reasoning.delta';
          final message = data['assistantMessageID']! as String;
          batch.add(
            ItemDelta(
              meta: meta(),
              itemId: itemId(
                message,
                reasoning ? 'reasoning' : 'text',
                data['ordinal'],
              ),
              field: OpenValue.known(
                reasoning ? DeltaField.reasoning : DeltaField.text,
              ),
              text: data['delta']! as String,
              generation: _generation(message),
            ),
          );
        case 'session.tool.input.started':
        case 'session.tool.input.ended':
        case 'session.tool.called':
        case 'session.tool.success':
          final message = data['assistantMessageID']! as String;
          final id = itemId(message, 'tool', data['id']);
          final previous = tools[id];
          final successful = type == 'session.tool.success';
          final input = switch (type) {
            'session.tool.input.started' => CanonicalValue(''),
            'session.tool.input.ended' => CanonicalValue(data['text']),
            'session.tool.called' => CanonicalValue(data['input']),
            _ => previous!.input,
          };
          final tool = ToolCall(
            meta: _itemMeta(
              id,
              nativeSource,
              successful ? ItemStatus.completed : ItemStatus.streaming,
              message: message,
            ),
            kind: const OpenValue.known(ToolKind.read),
            rawName: data['name'] as String? ?? previous!.rawName,
            input: input,
            output: successful
                ? CanonicalValue({
                    'content': data['content'],
                    'metadata': data['metadata'],
                    'executed': data['executed'],
                  })
                : null,
          );
          tools[id] = tool;
          batch.add(ItemUpserted(meta: meta(), item: tool));
        case 'session.step.ended':
          batch.add(
            UsageObserved(
              meta: meta(),
              observation: _usage(
                data,
                id: frame['id']! as String,
                stepId: data['assistantMessageID']! as String,
                observedAt: _instant(frame['created']),
                provenance: nativeSource,
              ),
            ),
          );
        case 'session.usage.updated':
          batch.add(
            UsageObserved(
              meta: meta(),
              observation: _usage(
                data,
                id: frame['id']! as String,
                observedAt: _instant(frame['created']),
                provenance: nativeSource,
              ),
            ),
          );
        case 'session.instructions.updated':
        case 'session.step.streamed':
          // Accepted canonical types have no instruction/step-metadata event.
          // Retain a neutral diagnostic; never materialize assistant text.
          batch.add(
            UnknownEvent(
              meta: meta(),
              rawType: type,
              raw: CanonicalValue(data),
            ),
          );
        default:
          throw StateError('Unexpected event in observed fixture A: $type');
      }
      result.add(List.unmodifiable(batch));
    }
    return List.unmodifiable(result);
  }

  Iterable<TimelineItem> _projectHistory() sync* {
    for (var row = 0; row < messages.length; row++) {
      final message = messages[row];
      final messageId = message['id']! as String;
      switch (message['type']) {
        case 'user':
          yield UserInput(
            meta: _itemMeta(
              itemId(messageId, 'user'),
              _historySource(message, row),
              ItemStatus.completed,
            ),
            text: message['text']! as String,
            delivery: const OpenValue.known(DeliveryState.delivered),
          );
        case 'assistant':
          // Native ordinals enumerate each kind separately, not content index.
          final ordinals = <String, int>{'reasoning': 0, 'text': 0};
          final parts = _maps(message['content']);
          for (var partIndex = 0; partIndex < parts.length; partIndex++) {
            final part = parts[partIndex];
            final kind = part['type']! as String;
            final ordinal = ordinals[kind];
            if (ordinal != null) ordinals[kind] = ordinal + 1;
            final meta = _itemMeta(
              itemId(messageId, kind, ordinal ?? part['id']),
              _historySource(message, row, part: part, partIndex: partIndex),
              ItemStatus.completed,
              message: messageId,
              ordinal: ordinal,
            );
            switch (kind) {
              case 'reasoning':
                yield Reasoning(
                  meta: meta,
                  text: part['text']! as String,
                  complete: true,
                );
              case 'text':
                yield AssistantText(
                  meta: meta,
                  text: part['text']! as String,
                  complete: true,
                );
              case 'tool':
                final state = _map(part['state']);
                yield ToolCall(
                  meta: meta,
                  kind: const OpenValue.known(ToolKind.read),
                  rawName: part['name']! as String,
                  input: CanonicalValue(state['input']),
                  output: CanonicalValue({
                    'content': state['content'],
                    'metadata': state['metadata'],
                    'executed': part['executed'],
                  }),
                );
              default:
                throw StateError('Unexpected observed assistant part: $kind');
            }
          }
        case 'idle':
          yield TurnOutcome(
            meta: _itemMeta(
              itemId(messageId, 'outcome'),
              _historySource(message, row),
              ItemStatus.completed,
            ),
            kind: OpenValue.parse(
              message['outcome']! as String,
              OutcomeKind.values,
            ),
          );
        default:
          throw StateError('Unexpected observed message: ${message['type']}');
      }
    }
  }

  ItemMeta _itemMeta(
    ItemId id,
    SourceProvenance provenance,
    ItemStatus status, {
    String? message,
    int? ordinal,
  }) => ItemMeta(
    id: id,
    generation: _generation(message ?? id.value),
    turnId: turnId,
    ordinal: ordinal,
    status: OpenValue.known(status),
    source: provenance,
  );

  String _generation(String owner) => 'fixture-a-step:$owner:1';

  SourceProvenance _eventSource(Map<String, Object?> frame, int index) {
    final durable = frame['durable'] == null ? null : _map(frame['durable']);
    final data = _map(frame['data']);
    return SourceProvenance(
      harness: ref.harnessRef,
      version: '2.0.22',
      nativeType: frame['type']! as String,
      nativeEventId: frame['id']! as String,
      aggregateId: durable?['aggregateID'] as String?,
      aggregateSeq: durable == null
          ? null
          : BigInt.from(durable['seq']! as int),
      durability: OpenValue.known(
        durable == null ? Durability.ephemeral : Durability.durable,
      ),
      extra: CanonicalValue({
        'fixture': 'A',
        'file': 'events.json',
        'index': index,
        'nativeCreated': frame['created'],
        if (durable != null) 'nativeDurableVersion': durable['version'],
        if (data['assistantMessageID'] != null || data['inboxID'] != null)
          'nativeMessageId': data['assistantMessageID'] ?? data['inboxID'],
        if (data['id'] != null) 'nativeCallId': data['id'],
        if (data.containsKey('executed')) 'executed': data['executed'],
        if (data['started'] != null) 'nativeStarted': data['started'],
        if (data['agent'] != null) 'nativeAgent': data['agent'],
        if (data['model'] != null) 'nativeModel': data['model'],
        if (data['finish'] != null) 'nativeFinish': data['finish'],
        if (data['rawFinish'] != null) 'nativeRawFinish': data['rawFinish'],
      }),
    );
  }

  SourceProvenance _historySource(
    Map<String, Object?> message,
    int row, {
    Map<String, Object?>? part,
    int? partIndex,
  }) => _readSource(
    'messages.json',
    message['type']! as String,
    extra: {
      'pointer': '/data/$row${partIndex == null ? '' : '/content/$partIndex'}',
      'nativeMessageId': message['id'],
      'nativeMessageTime': message['time'],
      if (message['agent'] != null) 'nativeAgent': message['agent'],
      if (message['model'] != null) 'nativeModel': message['model'],
      if (part != null && part['time'] != null) 'nativePartTime': part['time'],
      if (part != null && part['id'] != null) 'nativeCallId': part['id'],
      if (part != null && part.containsKey('executed'))
        'executed': part['executed'],
    },
  );

  SourceProvenance _readSource(
    String file,
    String nativeType, {
    Map<String, Object?> extra = const {},
  }) => SourceProvenance(
    harness: ref.harnessRef,
    version: '2.0.22',
    nativeType: nativeType,
    // HTTP projected history has no native event cursor/sequence.
    durability: const OpenValue.known(Durability.unknown),
    extra: CanonicalValue({'fixture': 'A', 'file': file, ...extra}),
  );

  UsageObservation _usage(
    Map<String, Object?> value, {
    required String id,
    required DateTime observedAt,
    required SourceProvenance provenance,
    String? stepId,
  }) {
    final tokens = _map(value['tokens']);
    final cache = _map(tokens['cache']);
    final sourceExtra = provenance.extra?.value as Map<String, Object?>?;
    return UsageObservation(
      id: id,
      owner: SessionOwner(ref),
      scope: OpenValue.known(
        stepId == null ? UsageScope.session : UsageScope.turn,
      ),
      source: const OpenValue.known(UsageSource.native),
      observedAt: observedAt,
      // A step's native usage is a partial observation within the execution
      // turn, not an independent complete turn total or an additive budget.
      partial: stepId != null,
      cumulative: stepId == null,
      aggregationKey: stepId == null ? 'session-total' : 'step:$stepId',
      tokens: TokenBreakdown(
        input: tokens['input'] as num?,
        output: tokens['output'] as num?,
        reasoning: tokens['reasoning'] as num?,
        cacheRead: cache['read'] as num?,
        cacheWrite: cache['write'] as num?,
      ),
      cost: Cost(
        amount: value['cost'] as num?,
        partial: stepId != null,
        cumulative: stepId == null,
      ),
      provenance: SourceProvenance(
        harness: provenance.harness,
        version: provenance.version,
        nativeType: provenance.nativeType,
        nativeEventId: provenance.nativeEventId,
        nativeCursor: provenance.nativeCursor,
        aggregateId: provenance.aggregateId,
        aggregateSeq: provenance.aggregateSeq,
        durability: provenance.durability,
        extra: CanonicalValue({
          ...?sourceExtra,
          'nativeUsageScope': stepId == null ? 'session' : 'step',
          if (stepId != null) ...{
            'nativeStepId': stepId,
            'canonicalTurnId': turnId.value,
          },
        }),
      ),
    );
  }

  Selection _selection(Map<String, Object?> model, String agent) => Selection(
    modelId: model['id']! as String,
    agentId: agent,
    effort: model['variant'] as String?,
    metadata: CanonicalValue({'providerID': model['providerID']}),
  );
}

const _succeededExecution = ExecutionState(
  kind: OpenValue.known(ExecutionKind.idle),
  lastOutcome: ExecutionOutcome(
    OpenValue.known(ExecutionOutcomeKind.succeeded),
  ),
);

Map<String, Object?> _map(Object? value) =>
    CanonicalValue(Map<String, Object?>.from(value! as Map)).value
        as Map<String, Object?>;

List<Map<String, Object?>> _maps(Object? value) =>
    List.unmodifiable((value! as List).map(_map));

DateTime _instant(Object? value) =>
    DateTime.fromMillisecondsSinceEpoch(value! as int, isUtc: true);
