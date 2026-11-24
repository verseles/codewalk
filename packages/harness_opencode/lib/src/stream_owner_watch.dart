import 'dart:async';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:codewalk_net/codewalk_net.dart';

import 'bounded_structure.dart';
import 'stream_owner.dart';

/// How long a clean, non-dirty hydration must remain healthy before a later
/// error repair resets the per-generation repair strike counter (`#424`).
const openCodeRepairCooldown = Duration(seconds: 30);

/// Per-session mutable watch state for one connection generation.
final class OpenCodeWatch {
  bool ready = false;
  bool stalled = false;
  bool hydrating = false;
  bool dirty = false;

  /// Whether the coalesced follow-up hydration was triggered by an error repair
  /// rather than a routine child/manual refresh.
  bool dirtyIsRepair = false;
  int repairs = 0;

  /// When this watch last completed a clean hydration with no repair follow-up.
  DateTime? lastHealthyHydrationAt;
  RequestCancellation? cancellation;

  /// The older-history read in flight; one per watched session.
  RequestCancellation? olderCancellation;

  /// The oldest row a read put in the window. Once the window's first row is
  /// another one, the window was trimmed in front and the cursor now skips
  /// rows that are no longer resident, so older paging stops.
  ItemId? oldestCovered;

  /// Once the window lost rows in front, it stays known until a fresh
  /// hydration covers it again, even if later removals empty the window.
  bool trimmed = false;

  /// Frames kept until the first snapshot; a child frame names its child.
  final held = <(int, Map<String, Object?>, SessionRef?)>[];

  /// Bounded side buffer for shell exit/delete frames arriving before the
  /// first snapshot, isolated from [held] so foreign shell traffic can never
  /// exhaust [OpenCodeStreamOwner.maxHeldFrames] or degrade the session.
  final heldShellTerminals = <(int, Map<String, Object?>, String)>[];
  final mutatedShellIdsWhileRefreshing = <String>{};
  bool shellsRetried = false;
  bool shellsRefreshing = false;
  bool shellsRefreshInvalidated = false;
  RequestCancellation? shellsCancellation;
  Timer? shellsRetryTimer;
}

/// Whether [effects] request another error repair of the session.
bool openCodeEffectsRequestRepair(List<ReducerEffect> effects) {
  for (final effect in effects) {
    switch (effect) {
      case Rehydrate(:final reason):
        if (reason == 'sessionNotOpen' ||
            reason == 'streamGenerationMismatch' ||
            reason == 'snapshotGenerationMismatch') {
          continue;
        }
        return true;
      case Refetch():
        return true;
      case Notify():
        break;
    }
  }
  return false;
}

/// Whether [value] is a valid raw tool-input streaming frame whose projection
/// is a pure no-op (`inputNotProjected`), so holding it while hydrating would
/// only waste [OpenCodeStreamOwner.maxHeldFrames]. Malformed or oversized
/// frames return false so they remain held and take the fail-closed repair path.
bool openCodeIsNoOpToolInputFrame(Map<String, Object?> value) {
  final type = value['type'];
  final data = value['data'];
  if (data is! Map<String, Object?>) return false;
  final Object? raw;
  if (type == 'session.tool.input.delta') {
    if (value.containsKey('durable')) return false;
    raw = data['delta'];
  } else if (type == 'session.tool.input.ended') {
    if (value['durable'] is! Map<String, Object?>) return false;
    raw = data['text'];
  } else {
    return false;
  }
  try {
    validateOpenCodeDiscardedText(
      raw,
      maxBytes: openCodeLiveDiscardedInputLimit,
    );
    return true;
  } on FormatException {
    return false;
  } on RangeError {
    return false;
  }
}

/// Adapts a fresh tail [snapshot] against the resident [prior] timeline before
/// `store.applySnapshot`:
/// - When [prior] holds contiguous older rows in front of an overlapping
///   partial tail (`complete == false`), preserves [prior]'s older
///   `nextHistoryCursor` and front-coverage state so a re-hydration never
///   rewinds pagination or falsely flags the window as trimmed.
/// - When [prior] has non-empty pre-hydration rows that do not overlap the new
///   tail at all (e.g., >20 messages arrived while disconnected) and no pending
///   inputs require admission checks, marks the tail `complete: true` so the
///   reducer replaces the stale disjoint window cleanly while keeping the new
///   `nextHistoryCursor` and `hasMoreHistory`.
({SessionSnapshot snapshot, bool preservedPrefix})
openCodeReconcileTailSnapshot(SessionState? prior, SessionSnapshot snapshot) {
  final timeline = snapshot.timeline;
  if (prior == null ||
      prior.timeline.isEmpty ||
      timeline == null ||
      timeline.complete ||
      timeline.values.isEmpty) {
    return (snapshot: snapshot, preservedPrefix: false);
  }
  final pendingIds = {
    for (final entry in snapshot.pending?.values ?? const <PendingInput>[])
      entry.id,
  };
  final incomingIds = {
    for (final item in timeline.values)
      if (!pendingIds.contains(item.id)) item.id,
  };
  if (incomingIds.isEmpty) {
    return (snapshot: snapshot, preservedPrefix: false);
  }
  final firstOverlap = prior.timeline.indexWhere(
    (item) => incomingIds.contains(item.id),
  );
  if (firstOverlap > 0) {
    return (
      snapshot: SessionSnapshot(
        ref: snapshot.ref,
        hydrationGeneration: snapshot.hydrationGeneration,
        info: snapshot.info,
        selection: snapshot.selection,
        execution: snapshot.execution,
        work: snapshot.work,
        shells: snapshot.shells,
        plan: snapshot.plan,
        timeline: timeline,
        pending: snapshot.pending,
        interactions: snapshot.interactions,
        revert: snapshot.revert,
        usage: snapshot.usage,
        nextHistoryCursor: prior.nextHistoryCursor,
        hasMoreHistory: prior.nextHistoryCursor != null || prior.hasMoreHistory,
      ),
      preservedPrefix: true,
    );
  }
  if (firstOverlap < 0 && prior.pending.isEmpty) {
    return (
      snapshot: SessionSnapshot(
        ref: snapshot.ref,
        hydrationGeneration: snapshot.hydrationGeneration,
        info: snapshot.info,
        selection: snapshot.selection,
        execution: snapshot.execution,
        work: snapshot.work,
        shells: snapshot.shells,
        plan: snapshot.plan,
        timeline: SnapshotCollection(
          values: timeline.values,
          boundary: timeline.boundary,
          complete: true,
        ),
        pending: snapshot.pending,
        interactions: snapshot.interactions,
        revert: snapshot.revert,
        usage: snapshot.usage,
        nextHistoryCursor: snapshot.nextHistoryCursor,
        hasMoreHistory: snapshot.hasMoreHistory,
      ),
      preservedPrefix: false,
    );
  }
  return (snapshot: snapshot, preservedPrefix: false);
}

/// Whether [value] is a terminal execution frame that settles a turn (excluding
/// server shutdown interruptions).
bool openCodeIsTurnSettlementFrame(Map<String, Object?> value) {
  final type = value['type'];
  if (type == 'session.execution.succeeded' ||
      type == 'session.execution.failed') {
    return true;
  }
  if (type == 'session.execution.interrupted') {
    final data = value['data'];
    return data is Map<String, Object?> && data['reason'] != 'shutdown';
  }
  return false;
}

/// The lifecycle change a frame carries, or null for every other frame.
OpenCodeCatalogChange? openCodeCatalogChangeOf(Object? type) {
  if (type is! String) return null;
  switch (type) {
    case 'project.updated':
    case 'worktree.updated':
    case 'worktree.resolved':
      return OpenCodeCatalogChange.project;
    case 'session.created':
      return OpenCodeCatalogChange.created;
    case 'session.forked':
      return OpenCodeCatalogChange.forked;
    case 'session.renamed':
      return OpenCodeCatalogChange.renamed;
    case 'session.deleted':
      return OpenCodeCatalogChange.deleted;
    case 'session.archived':
    case 'session.unarchived':
      return OpenCodeCatalogChange.archived;
    case 'session.moved':
      // A move changes the session's location, so the group it belongs to
      // changes with it.
      return OpenCodeCatalogChange.moved;
    case 'session.viewed':
      // A view updates the unread watermark, so the marker changes with it.
      return OpenCodeCatalogChange.viewed;
    case 'session.execution.succeeded':
    case 'session.execution.failed':
    case 'session.execution.interrupted':
      // The session went idle: the endpoint's unread marker advances with
      // it, so the list re-reads.
      return OpenCodeCatalogChange.idled;
    case 'session.execution.started':
      return OpenCodeCatalogChange.started;
    case 'permission.asked':
    case 'permission.replied':
    case 'form.created':
    case 'form.replied':
    case 'form.cancelled':
      // What waits for the user changed: the pending lists are re-read.
      return OpenCodeCatalogChange.waiting;
    default:
      return null;
  }
}
