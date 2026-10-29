import 'package:codewalk_core/codewalk_core.dart';

import 'session_live_source.dart';

enum SessionTurnAction { undo, redoNext, redoAll, compact }

enum SessionTurnPhase { idle, pending, unconfirmed }

enum SessionTurnUnavailable {
  offline,
  busy,
  pending,
  unconfirmed,
  selectionPending,
  promptPending,
  storage,
  targetUnknown,
  historyIncomplete,
  noRevert,
  revertStaged,
}

/// Local command state, shared by the session's leases. A staged revert is a
/// visibility boundary, not deletion of the resident canonical history.
final class SessionTurnState {
  const SessionTurnState({
    this.phase = SessionTurnPhase.idle,
    this.revert,
    this.receipt,
    this.unavailable,
    this.compacting = false,
    this.sendUnavailable,
  });
  final SessionTurnPhase phase;
  final RevertState? revert;
  final CommandReceipt? receipt;
  final SessionTurnUnavailable? unavailable;
  final bool compacting;

  /// A staged replacement would commit the cut before sending. Ordinary
  /// non-staged prompts can still use their harness's normal queue.
  final SessionTurnUnavailable? sendUnavailable;
  bool get holdsSend =>
      phase != SessionTurnPhase.idle || sendUnavailable != null;
  bool get staged => revert?.kind.known == RevertKind.staged;
}

final class SessionTurnResult {
  const SessionTurnResult({
    this.receipt,
    this.unavailable,
    this.restored,
    this.cleared = false,
    this.applied = false,
  });
  final CommandReceipt? receipt;
  final SessionTurnUnavailable? unavailable;
  final UserInput? restored;
  final bool cleared;
  final bool applied;
}

/// Bound to one live lease. Mutations are deliberate, never repeated after an
/// uncertain answer. Refresh only reads authoritative state.
abstract interface class SessionTurnActionPort {
  SessionTurnState get state;
  SessionTurnUnavailable? unavailable(SessionTurnAction action);
  Future<SessionTurnResult> stage(ItemId boundary, {required CommandId id});
  Future<SessionTurnResult> redoNext({required CommandId id});
  Future<SessionTurnResult> redoAll({required CommandId id});
  Future<SessionTurnResult> compact({required CommandId id});
  Future<void> refresh();
}

/// Optional capability: read-only and other harness handles need not expose
/// turn mutations or invent an implementation for them.
abstract interface class SessionTurnActionSource {
  SessionTurnActionPort? get turnActions;
}

extension SessionLiveTurnActions on SessionLiveHandle {
  SessionTurnActionPort? get turnActions {
    final handle = this;
    return handle is SessionTurnActionSource
        ? (handle as SessionTurnActionSource).turnActions
        : null;
  }
}

/// A persisted user turn with adapter-supplied ordering, never an optimistic
/// local echo or a native-looking id used as a confirmation heuristic.
List<UserInput> confirmedSessionTurns(SessionState? state) {
  final messages = <MessageRef>{};
  final turns = <UserInput>[];
  for (final item in state?.timeline ?? const <TimelineItem>[]) {
    if (item is UserInput &&
        item.confirmed &&
        item.meta.source.harness == state!.ref.harnessRef &&
        item.meta.anchor != null &&
        messages.add(item.meta.anchor!.message)) {
      turns.add(item);
    }
  }
  turns.sort((a, b) => a.meta.anchor!.compareTo(b.meta.anchor!));
  return List.unmodifiable(turns);
}
