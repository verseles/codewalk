import 'dart:convert';

import 'package:codewalk_core/codewalk_core.dart';

/// Native OpenCode v2 tool names for structured session plans.
const openCodePlanWriteTool = 'todowrite';
const openCodePlanReadTool = 'todoread';

const _maxPlanEntries = 256;
const _maxRawPlanEntries = 512;
const _maxPlanContentBytes = 4096;
const _maxRawContentUnits = _maxPlanContentBytes * 4;

/// Parses an OpenCode v2 `todos` list (`[{content, status}]`) into canonical
/// [PlanEntry] items.
///
/// Returns `null` when [rawTodos] is not a list (so missing or non-list
/// payloads never clear a prior valid plan). Returns an empty list when
/// [rawTodos] is explicitly `[]` (clearing the active plan). Malformed entries
/// are skipped individually without failing tool projection. Entries beyond
/// [_maxPlanEntries] (or raw lists beyond [_maxRawPlanEntries]) are omitted
/// and trigger [onTruncated].
List<PlanEntry>? parseOpenCodeTodos(
  Object? rawTodos, {
  void Function()? onTruncated,
}) {
  if (rawTodos is! List) return null;
  final entries = <PlanEntry>[];
  var truncated = false;
  var scanned = 0;
  for (final raw in rawTodos) {
    if (entries.length >= _maxPlanEntries || scanned >= _maxRawPlanEntries) {
      truncated = true;
      break;
    }
    scanned++;
    if (raw is! Map) continue;
    final rawContent = raw['content'];
    if (rawContent is! String) continue;
    final clean = _sanitizeContent(rawContent);
    if (clean == null || clean.isEmpty) continue;
    final status = _parseStatus(raw['status']);
    entries.add(
      PlanEntry(id: '${entries.length}', title: clean, status: status),
    );
  }
  if (truncated) onTruncated?.call();
  return List<PlanEntry>.unmodifiable(entries);
}

OpenValue<PlanStatus> _parseStatus(Object? raw) {
  if (raw is! String || raw.isEmpty) {
    return const OpenValue.known(PlanStatus.unknown);
  }
  return switch (raw) {
    'pending' => const OpenValue.known(PlanStatus.pending),
    'in_progress' => const OpenValue.known(PlanStatus.inProgress),
    'completed' => const OpenValue.known(PlanStatus.completed),
    'cancelled' => const OpenValue.known(PlanStatus.cancelled),
    _ => OpenValue<PlanStatus>.unknown(raw),
  };
}

/// Validates UTF-16 surrogates, redacts credentials, trims, and bounds to
/// [_maxPlanContentBytes] UTF-8 bytes without throwing on malformed input.
///
/// Pre-slices untrusted strings at [_maxRawContentUnits] UTF-16 code units
/// (preserving surrogate pairs at the boundary) so neither redaction nor UTF-8
/// encoding scans arbitrarily large payloads.
String? _sanitizeContent(String value) {
  var boundedRaw = value;
  if (boundedRaw.length > _maxRawContentUnits) {
    var cut = _maxRawContentUnits;
    final lastUnit = boundedRaw.codeUnitAt(cut - 1);
    if (lastUnit >= 0xd800 && lastUnit <= 0xdbff) {
      final nextUnit = boundedRaw.codeUnitAt(cut);
      if (nextUnit >= 0xdc00 && nextUnit <= 0xdfff) {
        cut--;
      }
    }
    boundedRaw = boundedRaw.substring(0, cut);
  }
  for (var i = 0; i < boundedRaw.length; i++) {
    final unit = boundedRaw.codeUnitAt(i);
    if (unit >= 0xd800 && unit <= 0xdbff) {
      if (++i >= boundedRaw.length) return null;
      final low = boundedRaw.codeUnitAt(i);
      if (low < 0xdc00 || low > 0xdfff) return null;
    } else if (unit >= 0xdc00 && unit <= 0xdfff) {
      return null;
    }
  }
  final clean = redactCredentialText(boundedRaw).trim();
  if (clean.isEmpty) return null;
  if (utf8.encode(clean).length <= _maxPlanContentBytes) return clean;
  final buffer = StringBuffer();
  var bytes = 0;
  for (final rune in clean.runes) {
    final charBytes = rune < 0x80
        ? 1
        : (rune < 0x800 ? 2 : (rune < 0x10000 ? 3 : 4));
    if (bytes + charBytes > _maxPlanContentBytes) break;
    buffer.writeCharCode(rune);
    bytes += charBytes;
  }
  final bounded = buffer.toString().trim();
  return bounded.isEmpty ? null : bounded;
}

/// Serializes canonical bounded [entries] back into OpenCode's `{content, status}`
/// list shape so metadata-only `todowrite` completions stay replayable across
/// staged/cleared revert scans without retaining raw untrusted metadata.
List<Map<String, Object?>> openCodeSerializedPlanTodos(
  List<PlanEntry> entries,
) => [
  for (final entry in entries)
    {
      'content': entry.title,
      'status': switch (entry.status.known) {
        PlanStatus.pending => 'pending',
        PlanStatus.inProgress => 'in_progress',
        PlanStatus.completed => 'completed',
        PlanStatus.cancelled => 'cancelled',
        PlanStatus.unknown => '',
        null => entry.status.value,
      },
    },
];

/// Projects a completed `todowrite` [ToolCall] into a canonical [PlanSnapshot].
///
/// Prefers `call.input['todos']` (matching upstream OpenCode v2 `todos.ts`),
/// falling back to `metadata?['todos']` only when `input` carries no `'todos'`
/// field. Returns `null` for `todoread`, incomplete/failed calls, or when
/// neither source carries a list.
PlanSnapshot? openCodePlanFromToolCall(
  ToolCall call, {
  required SessionRef ref,
  required SourceProvenance source,
  Map<String, Object?>? metadata,
}) {
  if (call.rawName != openCodePlanWriteTool ||
      call.status.known != ItemStatus.completed) {
    return null;
  }
  Object? rawTodos;
  var hasInputTodos = false;
  final inputValue = call.input?.value;
  if (inputValue is Map && inputValue.containsKey('todos')) {
    rawTodos = inputValue['todos'];
    hasInputTodos = true;
  }
  if (!hasInputTodos && metadata != null && metadata.containsKey('todos')) {
    rawTodos = metadata['todos'];
  }
  var truncated = false;
  final entries = parseOpenCodeTodos(
    rawTodos,
    onTruncated: () => truncated = true,
  );
  if (entries == null) return null;
  final planSource = truncated ? _withPlanTruncated(source) : source;
  return PlanSnapshot(
    owner: SessionOwner(ref),
    entries: entries,
    source: planSource,
    anchor: call.meta.anchor,
  );
}

SourceProvenance _withPlanTruncated(SourceProvenance source) {
  final existing = source.extra?.value;
  final extra = <String, Object?>{
    if (existing is Map<String, Object?>) ...existing,
    'planEntriesTruncated': true,
  };
  return SourceProvenance(
    harness: source.harness,
    version: source.version,
    nativeType: source.nativeType,
    nativeEventId: source.nativeEventId,
    nativeCursor: source.nativeCursor,
    aggregateId: source.aggregateId,
    aggregateSeq: source.aggregateSeq,
    durability: source.durability,
    extra: CanonicalValue(extra),
  );
}

/// Scans chronological [items] backwards to derive the latest current-turn plan.
///
/// - When a completed `todowrite` with a valid `todos` list is found before
///   reaching an active [UserInput], returns `(snapshot, authoritative: true)`.
/// - When an active [UserInput] is reached first, proves the current turn has
///   no plan and returns an empty authoritative [PlanSnapshot] (clearing any
///   stale resident plan on rehydration).
/// - When neither is present and [hasMoreHistory] is true, returns
///   `(snapshot: null, authoritative: false)` so an older page can still fill
///   the plan without wiping an existing one.
({PlanSnapshot? snapshot, bool authoritative}) openCodeLatestPlan(
  List<TimelineItem> items, {
  required SessionRef ref,
  required String sourceVersion,
  bool hasMoreHistory = false,
}) {
  for (var i = items.length - 1; i >= 0; i--) {
    final item = items[i];
    if (item is ToolCall &&
        item.rawName == openCodePlanWriteTool &&
        item.status.known == ItemStatus.completed) {
      final plan = openCodePlanFromToolCall(
        item,
        ref: ref,
        source: item.source,
      );
      if (plan != null) return (snapshot: plan, authoritative: true);
    } else if (item is UserInput && isActivePlanUserInput(item)) {
      return (
        snapshot: PlanSnapshot(
          owner: SessionOwner(ref),
          entries: const [],
          source: SourceProvenance(
            harness: ref.harnessRef,
            version: sourceVersion,
            nativeType: 'session.message.list',
          ),
          anchor: item.meta.anchor,
        ),
        authoritative: true,
      );
    }
  }
  if (!hasMoreHistory) {
    return (
      snapshot: PlanSnapshot(
        owner: SessionOwner(ref),
        entries: const [],
        source: SourceProvenance(
          harness: ref.harnessRef,
          version: sourceVersion,
          nativeType: 'session.message.list',
        ),
      ),
      authoritative: true,
    );
  }
  return (snapshot: null, authoritative: false);
}

List<TimelineItem> _itemsBeforeStagedCut(
  List<TimelineItem> items,
  MessageAnchor? stagedCut,
) {
  if (stagedCut == null) return items;
  return [
    for (final item in items)
      if (item.meta.anchor == null ||
          item.meta.anchor!.compareTo(stagedCut) < 0)
        item,
  ];
}

/// Hydrated [SnapshotValue<PlanSnapshot>] for `hydrateSession`.
///
/// When [revert] is staged, derives the plan from items strictly before
/// `revert.anchor` so an active undo preview immediately displays the surviving
/// turn's plan while full uncut history stays resident for Redo.
SnapshotValue<PlanSnapshot>? openCodeHydratedPlan(
  List<TimelineItem> items, {
  required SessionRef ref,
  required String sourceVersion,
  required SnapshotBoundary boundary,
  required bool hasMoreHistory,
  RevertState? revert,
}) {
  final stagedCut = revert?.kind.known == RevertKind.staged
      ? revert?.anchor
      : null;
  final derived = openCodeLatestPlan(
    _itemsBeforeStagedCut(items, stagedCut),
    ref: ref,
    sourceVersion: sourceVersion,
    hasMoreHistory: hasMoreHistory,
  );
  if (!derived.authoritative || derived.snapshot == null) return null;
  return SnapshotValue(value: derived.snapshot!, boundary: boundary);
}

/// Recomputes the canonical [PlanSnapshot] for a staged, cleared, or committed
/// revert boundary.
///
/// When [hasMoreHistory] is true and no plan or user prompt exists in the
/// visible resident window, returns an anchorless empty [PlanSnapshot] so
/// active UI clears immediately while `loadOlderHistory` can still recover an
/// earlier surviving plan.
PlanSnapshot openCodePlanForRevertBoundary(
  List<TimelineItem> items, {
  required SessionRef ref,
  required String sourceVersion,
  required SourceProvenance source,
  MessageAnchor? stagedCut,
  bool hasMoreHistory = false,
}) {
  final derived = openCodeLatestPlan(
    _itemsBeforeStagedCut(items, stagedCut),
    ref: ref,
    sourceVersion: sourceVersion,
    hasMoreHistory: hasMoreHistory,
  );
  final found = derived.snapshot;
  if (found != null) return found;
  return PlanSnapshot(
    owner: SessionOwner(ref),
    entries: const [],
    source: source,
  );
}

/// Recomputes the canonical [PlanSnapshot] from [surviving] items after a
/// proven `session.revert.committed` cut.
PlanSnapshot openCodePlanAfterCommittedRevert(
  List<TimelineItem> surviving, {
  required SessionRef ref,
  required String sourceVersion,
  required SourceProvenance source,
  bool hasMoreHistory = false,
}) => openCodePlanForRevertBoundary(
  surviving,
  ref: ref,
  sourceVersion: sourceVersion,
  source: source,
  hasMoreHistory: hasMoreHistory,
);
