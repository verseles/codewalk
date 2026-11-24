import 'dart:convert';

import 'package:codewalk_core/codewalk_core.dart';

import 'bounded_structure.dart';
import 'error_projection.dart';
import 'item_ids.dart';
import 'message_context.dart';
import 'plan_projection.dart';
import 'subagent_child.dart';
import 'tool_metadata.dart';
import 'version_policy.dart';

enum OpenCodeToolProjectionFailure {
  malformed,
  unsupportedVersion,
  limitExceeded,
  itemKindMismatch,
  unsupportedValue,
}

/// Contains a finite category, never native content or identifiers.
final class OpenCodeToolProjectionException implements Exception {
  const OpenCodeToolProjectionException(this.failure);

  final OpenCodeToolProjectionFailure failure;

  @override
  String toString() => 'OpenCodeToolProjectionException(${failure.name})';
}

const _idLimit = 4096;
const _safeInteger = 9007199254740991;
const _types = {
  'session.tool.input.started',
  'session.tool.input.delta',
  'session.tool.input.ended',
  'session.tool.called',
  'session.tool.progress',
  'session.tool.success',
  'session.tool.failed',
};

/// Projects the selected 2.0.22 tool phases without owning a stream or clock.
///
/// Project and reduce each observation against the latest [current] state.
/// Raw argument fragments/boundaries are validated up to the 16 MiB SSE frame
/// ceiling and omitted: the finite credential-key policy is safe only on
/// structured `called.input`. Arbitrary progress metadata is omitted. These
/// three recognized phases return null. Missing observed names or incompatible
/// resident provenance request recovery; this function never adopts a
/// history/prior-epoch row or invents a tool name.
///
/// Selected identifiers have a 4 KiB cap. Structured input/output each keep a
/// redacted prefix within 64 KiB JSON-escaped bytes and 4096 nodes (at most
/// 128 output parts), and failed tool error messages keep a redacted 8 KiB
/// prefix; depth > 16, bad types, non-finite numbers, and unpaired UTF-16
/// surrogates in kept prefixes fail closed.
/// These guards do not bound upstream decoding or total process memory.
SessionEvent? projectOpenCodeToolEvent(
  Object? value,
  SessionState current, {
  required String sourceVersion,
  required StreamPosition position,
  required DateTime receivedAt,
}) {
  final frame = _object(value);
  final type = frame['type'];
  if (type is! String) _fail(OpenCodeToolProjectionFailure.malformed);
  if (!_types.contains(type)) return null;
  final data = _object(frame['data']);
  final sessionId = _id(data['sessionID'], 'ses');
  if (sessionId != current.ref.nativeId) return null;
  if (!OpenCodeCompatibility.supportsV2(sourceVersion)) {
    _fail(OpenCodeToolProjectionFailure.unsupportedVersion);
  }
  for (final part in [
    current.ref.host.value,
    current.ref.harness.value,
    current.ref.nativeId,
    position.id,
    position.epoch,
  ]) {
    _text(part, cap: _idLimit, nonempty: true);
  }
  final nativeId = _id(frame['id'], 'evt_');
  final messageId = _id(data['assistantMessageID'], 'msg_');
  // Unlike event/message IDs, call IDs and names are plain schema strings.
  final callId = _text(data['id'], cap: _idLimit);
  final created = frame['created'];
  if (created is! num || !created.isFinite) {
    _fail(OpenCodeToolProjectionFailure.malformed);
  }
  final ephemeral =
      type == 'session.tool.input.delta' || type == 'session.tool.progress';
  final started = type == 'session.tool.input.started';
  final called = type == 'session.tool.called';
  final success = type == 'session.tool.success';
  final failed = type == 'session.tool.failed';
  final terminal = success || failed;
  String? aggregateId;
  BigInt? aggregateSeq;
  int? durableVersion;
  if (ephemeral) {
    if (frame.containsKey('durable')) {
      _fail(OpenCodeToolProjectionFailure.malformed);
    }
  } else {
    final durable = _object(frame['durable']);
    aggregateId = _id(durable['aggregateID'], 'ses');
    if (aggregateId != sessionId) {
      _fail(OpenCodeToolProjectionFailure.malformed);
    }
    durableVersion = _integer(durable['version']);
    if (durableVersion != (terminal ? 2 : 1)) {
      _fail(OpenCodeToolProjectionFailure.unsupportedVersion);
    }
    aggregateSeq = BigInt.from(_integer(durable['seq']));
  }
  if (type == 'session.tool.input.delta') {
    _validateDiscardedInput(data['delta']);
    return null;
  }
  if (type == 'session.tool.input.ended') {
    _validateDiscardedInput(data['text']);
    return null;
  }
  final progress = type == 'session.tool.progress';
  // Progress replaces live metadata; only a subagent's child is kept.
  final progressMetadata = progress ? _object(data['metadata']) : null;

  var inputRedacted = false;
  var inputTruncated = false;
  CanonicalValue selectedInput(Object? value) {
    final bounded = _boundStructure(
      _object(value),
      redact: true,
      priorityKeys: openCodeToolInputPriorityKeys,
    );
    if (bounded.redacted) inputRedacted = true;
    if (bounded.truncated) inputTruncated = true;
    return bounded.value;
  }

  var name = started ? _text(data['name'], cap: _idLimit) : '';
  CanonicalValue? input;
  CanonicalValue? output;
  OutputRef? outputRef;
  ErrorInfo? error;
  bool? executed;
  bool? truncated;
  var outputOmitted = false;
  var outputRedacted = false;
  var outputTruncated = false;
  var errorRedacted = false;
  var errorTruncated = false;
  var status = ItemStatus.streaming;
  if (called || terminal) {
    executed = _boolean(data['executed']);
  }
  final id = ItemId(
    jsonEncode([current.ref.storageKey, messageId, 'tool', callId]),
  );
  TimelineItem? resident;
  for (final item in current.timeline) {
    if (item.id == id) {
      resident = item;
      break;
    }
  }
  final isShellTool =
      (resident is ToolCall ? resident.kind.known : _kind(name)) ==
      ToolKind.shell;
  if (called) input = selectedInput(data['input']);
  if (success || (failed && data.containsKey('content'))) {
    final bounded = _boundContent(data['content'], shellTool: isShellTool);
    output = bounded.value;
    outputOmitted = bounded.omitted;
    outputRedacted = bounded.redacted;
    outputTruncated = bounded.truncated;
    if (outputTruncated) outputRef = OutputRef(id: callId, truncated: true);
  }
  Map<String, Object?>? terminalMetadata;
  if (terminal && data.containsKey('metadata')) {
    final metadata = terminalMetadata = _object(data['metadata']);
    if (metadata.containsKey('truncated')) {
      truncated = _boolean(metadata['truncated']);
    }
  }
  if (success) status = ItemStatus.completed;
  if (failed) {
    final rawError = _object(data['error']);
    final errorType = _text(rawError['type'], cap: _idLimit);
    // Schema.String allows empty; Core ErrorInfo requires a nonempty rawType.
    if (errorType.isEmpty) {
      _fail(OpenCodeToolProjectionFailure.unsupportedValue);
    }
    String? rawMessage;
    if (rawError.containsKey('message')) {
      final raw = rawError['message'];
      if (raw is! String) _fail(OpenCodeToolProjectionFailure.malformed);
      rawMessage = raw;
    }
    final ({ErrorInfo error, bool redacted, bool truncated}) projectedError;
    try {
      projectedError = openCodeToolErrorInfo(errorType, rawMessage);
    } on FormatException {
      _fail(OpenCodeToolProjectionFailure.malformed);
    }
    errorRedacted = projectedError.redacted;
    errorTruncated = projectedError.truncated;
    final message = projectedError.error.rawMessage;
    final shellStopped =
        isShellTool &&
        (message == 'Command cancelled' ||
            terminalMetadata?['interrupted'] == true);
    status = errorType == 'aborted' || shellStopped
        ? ItemStatus.interrupted
        : ItemStatus.failed;
    error = projectedError.error;
  }

  final generation = jsonEncode([
    'live',
    current.ref.storageKey,
    messageId,
    position.id,
    position.epoch,
  ]);
  EventMeta meta() => EventMeta(
    owner: SessionOwner(current.ref),
    position: position,
    receivedAt: receivedAt,
    source: SourceProvenance(
      harness: current.ref.harnessRef,
      version: sourceVersion,
      nativeType: type,
      nativeEventId: nativeId,
      aggregateId: aggregateId,
      aggregateSeq: aggregateSeq,
      durability: const OpenValue.known(Durability.durable),
      extra: CanonicalValue({
        'nativeCreated': created,
        'nativeMessageId': messageId,
        'nativeToolCallId': callId,
        'nativeDurableVersion': durableVersion,
        'rawInputNotProjected': true,
        if (input == null) 'inputNotProjected': true,
        if (inputRedacted) 'inputRedacted': true,
        if (inputTruncated) 'inputTruncated': true,
        if (outputRedacted) 'outputRedacted': true,
        if (outputTruncated) 'outputTruncated': true,
        if (errorRedacted) 'errorRedacted': true,
        if (errorTruncated) 'errorTruncated': true,
        if (outputOmitted) 'outputContentOmitted': true,
        'executed': ?executed,
        'truncated': ?truncated,
      }),
    ),
  );
  if (resident != null && resident is! ToolCall) {
    _fail(OpenCodeToolProjectionFailure.itemKindMismatch);
  }
  bool compatible(ToolCall resident) {
    final extra = resident.source.extra?.value;
    return resident.generation == generation &&
        resident.source.harness == current.ref.harnessRef &&
        resident.source.version == sourceVersion &&
        const {
          'session.tool.input.started',
          'session.tool.called',
          'session.tool.success',
          'session.tool.failed',
        }.contains(resident.source.nativeType) &&
        resident.source.nativeEventId?.startsWith('evt_') == true &&
        resident.source.durability.known == Durability.durable &&
        resident.source.aggregateId == sessionId &&
        resident.source.aggregateSeq != null &&
        extra is Map<String, Object?> &&
        extra['nativeMessageId'] == messageId &&
        extra['nativeToolCallId'] == callId;
  }

  if (progressMetadata != null) {
    // Only the live call of this generation learns progress observations; an
    // unknown, stale or settled call is left to its durable events.
    if (resident is! ToolCall || !compatible(resident) || _settled(resident)) {
      return null;
    }
    final kind = resident.kind.known;
    if (kind == ToolKind.shell) {
      final facts = _shellFacts(progressMetadata, prior: resident.runFacts);
      if (facts == resident.runFacts) return null;
      final origin = SourceProvenance(
        harness: current.ref.harnessRef,
        version: sourceVersion,
        nativeType: type,
        nativeEventId: nativeId,
        durability: const OpenValue.known(Durability.ephemeral),
        extra: CanonicalValue({
          'nativeCreated': created,
          'nativeMessageId': messageId,
          'nativeToolCallId': callId,
        }),
      );
      return ItemUpserted(
        meta: EventMeta(
          owner: SessionOwner(current.ref),
          position: position,
          receivedAt: receivedAt,
          source: origin,
        ),
        item: ToolCall(
          meta: resident.meta,
          kind: resident.kind,
          rawName: resident.rawName,
          input: resident.input == null
              ? null
              : selectedInput(resident.input!.value),
          output: resident.output,
          outputRef: resident.outputRef,
          child: resident.child,
          childEvidence: resident.childEvidence,
          error: resident.error,
          runFacts: facts,
        ),
      );
    }
    if (kind != ToolKind.subagent) {
      return null;
    }
    final (:present, child: named) = openCodeSubagentChild(
      progressMetadata,
      current.ref,
    );
    if (!present) return null;
    final origin = SourceProvenance(
      harness: current.ref.harnessRef,
      version: sourceVersion,
      nativeType: type,
      nativeEventId: nativeId,
      durability: const OpenValue.known(Durability.ephemeral),
      extra: CanonicalValue({
        'nativeCreated': created,
        'nativeMessageId': messageId,
        'nativeToolCallId': callId,
      }),
    );
    final (:child, :evidence) = openCodeChildEvidence(
      named: named,
      prior: resident,
      origin: origin,
      generation: generation,
    );
    // Nothing new: the same child already observed, or a refusal already
    // recorded.
    if (child == resident.child &&
        evidence.kind == resident.childEvidence?.kind) {
      return null;
    }
    // The row keeps its own revalidated durable source and fields; only the
    // child carries the progress observation.
    return ItemUpserted(
      meta: EventMeta(
        owner: SessionOwner(current.ref),
        position: position,
        receivedAt: receivedAt,
        source: origin,
      ),
      item: ToolCall(
        meta: resident.meta,
        kind: resident.kind,
        rawName: resident.rawName,
        input: resident.input == null
            ? null
            : selectedInput(resident.input!.value),
        output: resident.output,
        outputRef: resident.outputRef,
        child: child,
        childEvidence: evidence,
        error: resident.error,
        runFacts: resident.runFacts,
      ),
    );
  }
  if (resident is ToolCall) {
    if (!compatible(resident)) {
      return ResyncRequired(meta: meta(), reason: 'toolResidentIncompatible');
    }
    final residentName = _text(resident.rawName, cap: _idLimit);
    if (resident.kind.known != _kind(residentName) ||
        resident.status.known == null) {
      return ResyncRequired(meta: meta(), reason: 'toolResidentIncompatible');
    }
    if (started) {
      return name == residentName
          ? null
          : ResyncRequired(meta: meta(), reason: 'toolNameMismatch');
    }
    if (!terminal && _settled(resident)) return null;
    name = residentName;
    // Carry only revalidated selected input, never arbitrary source/other fields.
    if (!called && resident.input != null) {
      input = selectedInput(resident.input!.value);
      final priorExtra = resident.source.extra?.value;
      if (priorExtra is Map<Object?, Object?>) {
        if (priorExtra['inputTruncated'] == true) inputTruncated = true;
        if (priorExtra['inputRedacted'] == true) inputRedacted = true;
      }
    }
  } else if (!started) {
    return ResyncRequired(meta: meta(), reason: 'toolStartMissing');
  }
  final eventMeta = meta();
  final prior = resident is ToolCall ? resident : null;
  // A terminal that names the child is its own observation; one that does
  // not keeps what this generation already observed.
  var child = prior?.child;
  var evidence = prior?.childEvidence;
  final toolKind = _kind(name);
  if (terminal && toolKind == ToolKind.subagent && terminalMetadata != null) {
    final (:present, child: named) = openCodeSubagentChild(
      terminalMetadata,
      current.ref,
    );
    if (present) {
      (child: child, evidence: evidence) = openCodeChildEvidence(
        named: named,
        prior: prior,
        origin: eventMeta.source,
        generation: generation,
      );
    }
  }
  var runFacts = prior?.runFacts;
  if (terminal && toolKind == ToolKind.shell && terminalMetadata != null) {
    runFacts = _shellFacts(terminalMetadata, prior: runFacts);
  }
  return ItemUpserted(
    meta: eventMeta,
    item: ToolCall(
      meta: ItemMeta(
        id: id,
        anchor: openCodeMessageAnchor(messageId),
        generation: generation,
        status: OpenValue.known(status),
        source: eventMeta.source,
        message: liveMessageContext(current, id, messageId),
      ),
      kind: OpenValue.known(toolKind),
      rawName: name,
      input: input,
      output: output,
      outputRef: outputRef ?? (terminal ? null : prior?.outputRef),
      child: child,
      childEvidence: evidence,
      error: error,
      runFacts: runFacts,
    ),
  );
}

/// Projects an OpenCode v2 tool event into one or more canonical events.
///
/// Always includes the result of [projectOpenCodeToolEvent] and, on a
/// completed `todowrite` call with a valid `todos` list, appends the matching
/// [PlanChanged] event.
List<SessionEvent> projectOpenCodeToolEvents(
  Object? value,
  SessionState current, {
  required String sourceVersion,
  required StreamPosition position,
  required DateTime receivedAt,
}) {
  final event = projectOpenCodeToolEvent(
    value,
    current,
    sourceVersion: sourceVersion,
    position: position,
    receivedAt: receivedAt,
  );
  if (event == null) return const [];
  if (event is ItemUpserted &&
      event.item is ToolCall &&
      (event.item as ToolCall).rawName == openCodePlanWriteTool &&
      event.item.status.known == ItemStatus.completed) {
    final call = event.item as ToolCall;
    Map<String, Object?>? metadata;
    if (value is Map<String, Object?>) {
      final data = value['data'];
      if (data is Map<String, Object?> &&
          data['metadata'] is Map<String, Object?>) {
        metadata = data['metadata']! as Map<String, Object?>;
      }
    }
    final plan = openCodePlanFromToolCall(
      call,
      ref: current.ref,
      source: event.meta.source,
      metadata: metadata,
    );
    var toolEvent = event;
    if (plan != null) {
      final inputValue = call.input?.value;
      final hasInputTodos =
          inputValue is Map && inputValue.containsKey('todos');
      if (!hasInputTodos) {
        final mergedInput = <String, Object?>{
          if (inputValue is Map<String, Object?>) ...inputValue,
          'todos': openCodeSerializedPlanTodos(plan.entries),
        };
        toolEvent = ItemUpserted(
          meta: event.meta,
          item: ToolCall(
            meta: call.meta,
            kind: call.kind,
            rawName: call.rawName,
            input: CanonicalValue(mergedInput),
            output: call.output,
            outputRef: call.outputRef,
            child: call.child,
            childEvidence: call.childEvidence,
            error: call.error,
            runFacts: call.runFacts,
          ),
        );
      }
    }
    final stagedCut = current.revert?.kind.known == RevertKind.staged
        ? current.revert?.anchor
        : null;
    final blockedByStagedCut =
        stagedCut != null &&
        (plan?.anchor == null || plan!.anchor!.compareTo(stagedCut) >= 0);
    if (plan != null && !blockedByStagedCut) {
      return List.unmodifiable([
        toolEvent,
        PlanChanged(meta: event.meta, plan: plan),
      ]);
    }
    return List.unmodifiable([toolEvent]);
  }
  return List.unmodifiable([event]);
}

ToolKind _kind(String name) => openCodeToolKind(name);

ToolRunFacts? _shellFacts(
  Map<String, Object?> metadata, {
  ToolRunFacts? prior,
}) {
  try {
    return openCodeShellToolRunFacts(metadata, prior: prior);
  } on RangeError {
    _fail(OpenCodeToolProjectionFailure.limitExceeded);
  } on FormatException {
    _fail(OpenCodeToolProjectionFailure.malformed);
  }
}

bool _settled(ToolCall item) => const {
  ItemStatus.completed,
  ItemStatus.failed,
  ItemStatus.interrupted,
}.contains(item.status.known);

void _validateDiscardedInput(Object? value) {
  try {
    validateOpenCodeDiscardedText(
      value,
      maxBytes: openCodeLiveDiscardedInputLimit,
    );
  } on RangeError {
    _fail(OpenCodeToolProjectionFailure.limitExceeded);
  } on FormatException {
    _fail(OpenCodeToolProjectionFailure.malformed);
  }
}

({CanonicalValue value, int bytes, int nodes, bool truncated, bool redacted})
_boundStructure(
  Object? value, {
  required bool redact,
  List<String> priorityKeys = const [],
}) {
  try {
    return boundOpenCodeStructure(
      value,
      redact: redact,
      priorityKeys: priorityKeys,
    );
  } on OpenCodeBoundedStructureException catch (error) {
    _fail(switch (error.failure) {
      OpenCodeBoundedStructureFailure.malformed =>
        OpenCodeToolProjectionFailure.malformed,
      OpenCodeBoundedStructureFailure.depthExceeded ||
      OpenCodeBoundedStructureFailure.limitExceeded =>
        OpenCodeToolProjectionFailure.limitExceeded,
      OpenCodeBoundedStructureFailure.unsupportedValue =>
        OpenCodeToolProjectionFailure.unsupportedValue,
    });
  }
}

({
  CanonicalValue value,
  int bytes,
  int nodes,
  bool truncated,
  bool omitted,
  bool redacted,
})
_boundContent(Object? value, {bool shellTool = false}) {
  try {
    return boundOpenCodeToolContent(value, shellTool: shellTool);
  } on OpenCodeBoundedStructureException catch (error) {
    _fail(switch (error.failure) {
      OpenCodeBoundedStructureFailure.malformed =>
        OpenCodeToolProjectionFailure.malformed,
      OpenCodeBoundedStructureFailure.depthExceeded ||
      OpenCodeBoundedStructureFailure.limitExceeded =>
        OpenCodeToolProjectionFailure.limitExceeded,
      OpenCodeBoundedStructureFailure.unsupportedValue =>
        OpenCodeToolProjectionFailure.unsupportedValue,
    });
  }
}

Map<String, Object?> _object(Object? value) {
  if (value is! Map<String, Object?>) {
    _fail(OpenCodeToolProjectionFailure.malformed);
  }
  return value;
}

bool _boolean(Object? value) {
  if (value is! bool) _fail(OpenCodeToolProjectionFailure.malformed);
  return value;
}

int _integer(Object? value) {
  if (value is! num ||
      !value.isFinite ||
      value < 0 ||
      value > _safeInteger ||
      value != value.truncate()) {
    _fail(OpenCodeToolProjectionFailure.malformed);
  }
  return value.toInt();
}

String _id(Object? value, String prefix) {
  final result = _text(value, cap: _idLimit, nonempty: true);
  if (!result.startsWith(prefix)) {
    _fail(OpenCodeToolProjectionFailure.malformed);
  }
  return result;
}

String _text(Object? value, {required int cap, bool nonempty = false}) {
  if (value is! String || (nonempty && value.isEmpty)) {
    _fail(OpenCodeToolProjectionFailure.malformed);
  }
  _bytes(value, cap);
  return value;
}

int _bytes(String value, int cap) {
  if (value.length > cap) _fail(OpenCodeToolProjectionFailure.limitExceeded);
  var bytes = 0;
  for (var i = 0; i < value.length; i++) {
    final unit = value.codeUnitAt(i);
    if (unit >= 0xd800 && unit <= 0xdbff) {
      if (++i >= value.length) _fail(OpenCodeToolProjectionFailure.malformed);
      final low = value.codeUnitAt(i);
      if (low < 0xdc00 || low > 0xdfff) {
        _fail(OpenCodeToolProjectionFailure.malformed);
      }
      bytes += 4;
    } else if (unit >= 0xdc00 && unit <= 0xdfff) {
      _fail(OpenCodeToolProjectionFailure.malformed);
    } else {
      bytes += unit < 0x80 ? 1 : (unit < 0x800 ? 2 : 3);
    }
    if (bytes > cap) _fail(OpenCodeToolProjectionFailure.limitExceeded);
  }
  return bytes;
}

Never _fail(OpenCodeToolProjectionFailure failure) =>
    throw OpenCodeToolProjectionException(failure);
