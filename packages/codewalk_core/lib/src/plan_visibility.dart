import 'lifecycle.dart';
import 'reducer/session_reducer.dart';
import 'timeline.dart';
import 'work.dart';

/// Harness-neutral progress counts over a list of [PlanEntry] items.
///
/// Only entries with recognized statuses (`pending`, `inProgress`, `completed`,
/// `cancelled`) contribute to [total]. Entries with [PlanStatus.unknown] or an
/// unrecognized open status are still rendered in the list, without inflating
/// or distorting progress. [cancelled] stays in [total] and never increments
/// [completed], so `fraction == 1.0` strictly means every counted task was
/// completed.
final class PlanProgress {
  const PlanProgress({
    required this.total,
    required this.completed,
    required this.inProgress,
    required this.pending,
    required this.cancelled,
  });

  final int total;
  final int completed;
  final int inProgress;
  final int pending;
  final int cancelled;

  /// Completion fraction in `0.0..1.0`.
  double get fraction => total == 0 ? 0.0 : (completed / total).clamp(0.0, 1.0);

  /// Extra tasks running in parallel alongside the primary active task.
  int get extraInProgress => inProgress > 1 ? inProgress - 1 : 0;

  /// True when every counted entry is completed (at least one entry counted).
  bool get allCompleted => total > 0 && completed == total;

  /// True when every counted entry is cancelled (at least one entry counted).
  bool get allCancelled => total > 0 && cancelled == total;

  /// True when at least one counted entry exists and none are pending or active.
  bool get allFinished =>
      total > 0 &&
      pending == 0 &&
      inProgress == 0 &&
      (completed + cancelled) == total;

  @override
  bool operator ==(Object other) =>
      other is PlanProgress &&
      total == other.total &&
      completed == other.completed &&
      inProgress == other.inProgress &&
      pending == other.pending &&
      cancelled == other.cancelled;

  @override
  int get hashCode =>
      Object.hash(total, completed, inProgress, pending, cancelled);
}

/// Computes [PlanProgress] from canonical [entries].
PlanProgress planProgress(List<PlanEntry> entries) {
  var completed = 0;
  var inProgress = 0;
  var pending = 0;
  var cancelled = 0;
  for (final entry in entries) {
    switch (entry.status.known) {
      case PlanStatus.completed:
        completed++;
      case PlanStatus.inProgress:
        inProgress++;
      case PlanStatus.pending:
        pending++;
      case PlanStatus.cancelled:
        cancelled++;
      case PlanStatus.unknown || null:
        break;
    }
  }
  return PlanProgress(
    total: completed + inProgress + pending + cancelled,
    completed: completed,
    inProgress: inProgress,
    pending: pending,
    cancelled: cancelled,
  );
}

/// Index of the focal entry for compact summaries and auto-scroll, matching
/// the upstream official client priority:
/// 1. first [PlanStatus.inProgress]
/// 2. else first [PlanStatus.pending]
/// 3. else last [PlanStatus.completed]
/// 4. else `0` (or `-1` when [entries] is empty).
int planCurrentIndex(List<PlanEntry> entries) {
  if (entries.isEmpty) return -1;
  for (var i = 0; i < entries.length; i++) {
    if (entries[i].status.known == PlanStatus.inProgress) return i;
  }
  for (var i = 0; i < entries.length; i++) {
    if (entries[i].status.known == PlanStatus.pending) return i;
  }
  for (var i = entries.length - 1; i >= 0; i--) {
    if (entries[i].status.known == PlanStatus.completed) return i;
  }
  return 0;
}

/// Resolves the currently visible [PlanSnapshot] for [state] under the
/// current-turn visibility rule:
/// - Returns `null` when [state] has no plan or an empty entry list.
/// - Applies a staged revert cut ([stagedCut], or [SessionState.revert] when
///   [useStateRevert] is true and `RevertKind.staged`): hides an anchorless
///   plan or any plan with `plan.anchor >= cut`, and ignores user prompts
///   inside the cut. `RevertKind.committed` is never treated as a visual cut.
/// - When `plan.anchor` is set, returns `null` as soon as an active timeline
///   [UserInput] (either ordered after `plan.anchor` or appearing after the
///   plan's message in timeline delivery order, as with promoted queued
///   prompts) or a [PendingInput] orders strictly after `plan.anchor`,
///   clearing the prior turn's task list when the user sends a new message.
/// - When `plan.anchor` is null (a harness that emits unanchored `PlanChanged`
///   snapshots), stays visible until the next `PlanChanged` (unless hidden by
///   a staged revert cut).
PlanSnapshot? visiblePlan(
  SessionState? state, {
  MessageAnchor? stagedCut,
  bool useStateRevert = true,
}) {
  if (state == null) return null;
  final plan = state.plan;
  if (plan == null || plan.entries.isEmpty) return null;
  final cut =
      stagedCut ??
      (useStateRevert && state.revert?.kind.known == RevertKind.staged
          ? state.revert?.anchor
          : null);
  final anchor = plan.anchor;
  if (cut != null) {
    if (anchor == null || anchor.compareTo(cut) >= 0) return null;
  }
  if (anchor != null) {
    if (planSupersedingUserInput(state.timeline, anchor, stagedCut: cut) !=
        null) {
      return null;
    }
    for (final pending in state.pending) {
      final pendingAnchor = pending.anchor;
      if (pendingAnchor == null) continue;
      if (cut != null && pendingAnchor.compareTo(cut) >= 0) continue;
      if (pendingAnchor.compareTo(anchor) > 0) return null;
    }
  }
  return plan;
}
