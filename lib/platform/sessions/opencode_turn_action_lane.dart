import 'dart:async';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:codewalk_net/codewalk_net.dart';
import 'package:harness_opencode/harness_opencode.dart';

import '../../shared/sessions/session_live_source.dart';
import '../../shared/sessions/session_turn_actions.dart';
import '../storage/storage_support.dart';
import 'prompt_outbox_store.dart';
import 'turn_action_journal.dart';

/// Turn mutations and prompt admission share the directory's session queue.
/// The durable journal fences uncertainty across lease/slot/app replacement;
/// reconciliation only reads, and never repeats a turn mutation.
final class OpenCodeTurnActionLane {
  OpenCodeTurnActionLane({
    required this.queue,
    required this.journal,
    required this.client,
    required this.reader,
    required this.ids,
    required this.commandIds,
    required this.view,
    required this.publish,
    required this.refreshView,
    required this.currentBinding,
    required this.selectionHoldsSend,
    required this.promptRefusal,
  });

  final KeySerialExecutor queue;
  final TurnActionJournal journal;
  final OpenCodeSessionTurnClient client;
  final OpenCodeSessionReader reader;
  final OpenCodeMessageIds ids;
  final CommandId Function() commandIds;
  final SessionLiveView Function(SessionRef) view;
  final void Function(SessionRef) publish;
  final void Function(SessionRef) refreshView;
  final bool Function() currentBinding;
  final bool Function(SessionRef) selectionHoldsSend;
  final Future<String?> Function(SessionRef) promptRefusal;
  final _entries = <SessionRef, _TurnEntry>{};
  bool _closed = false;

  void open(SessionRef ref) {
    if (_entries.containsKey(ref) || _closed) return;
    final entry = _TurnEntry();
    _entries[ref] = entry;
    unawaited(
      queue.run(OpenCodePromptOutbox.keyFor(ref), () async {
        try {
          final record = await journal.read(ref);
          if (!_current(ref, entry)) return;
          entry.record = record;
          entry.phase = record == null
              ? SessionTurnPhase.idle
              : SessionTurnPhase.unconfirmed;
        } on Object {
          if (!_current(ref, entry)) return;
          entry
            ..phase = SessionTurnPhase.unconfirmed
            ..failure = SessionTurnUnavailable.storage;
        }
        publish(ref);
        if (entry.record != null) await _verifyWithinQueue(ref, entry);
      }),
    );
  }

  SessionTurnActionPort port(SessionRef ref, bool Function() leaseCurrent) =>
      _TurnPort(this, ref, leaseCurrent);

  bool _current(SessionRef ref, _TurnEntry entry) =>
      !_closed && currentBinding() && identical(_entries[ref], entry);

  SessionTurnState state(SessionRef ref) {
    final entry = _entries[ref];
    return SessionTurnState(
      phase: entry?.phase ?? SessionTurnPhase.pending,
      revert: entry?.overlay ?? view(ref).state?.revert,
      receipt: entry?.receipt,
      unavailable: entry?.failure ?? entry?.admission,
      compacting: entry?.compact != null,
    );
  }

  SessionTurnUnavailable? unavailable(
    SessionRef ref,
    SessionTurnAction action,
  ) {
    final entry = _entries[ref];
    final current = view(ref);
    if (_closed ||
        !currentBinding() ||
        current.phase != SessionLivePhase.live ||
        current.stale) {
      return SessionTurnUnavailable.offline;
    }
    if (entry == null || entry.phase == SessionTurnPhase.pending) {
      return SessionTurnUnavailable.pending;
    }
    if (entry.phase == SessionTurnPhase.unconfirmed) {
      return entry.failure ?? SessionTurnUnavailable.unconfirmed;
    }
    if (entry.admission case final reason?) return reason;
    if (selectionHoldsSend(ref)) return SessionTurnUnavailable.selectionPending;
    final canonical = current.state;
    if (canonical?.execution?.kind.known != ExecutionKind.idle ||
        entry.compact != null ||
        canonical!.timeline.any(
          (item) =>
              item is Notice &&
              item.kind.known == NoticeKind.compaction &&
              item.status.known == ItemStatus.streaming,
        )) {
      return SessionTurnUnavailable.busy;
    }
    if (canonical.pending.isNotEmpty) {
      return SessionTurnUnavailable.promptPending;
    }
    final staged = state(ref).staged;
    final revert = state(ref).revert;
    if (revert?.kind.known == null ||
        revert?.kind.known == RevertKind.unknown ||
        (staged && revert?.anchor == null)) {
      return SessionTurnUnavailable.targetUnknown;
    }
    if (action == SessionTurnAction.compact && staged) {
      return SessionTurnUnavailable.revertStaged;
    }
    if (action == SessionTurnAction.redoNext ||
        action == SessionTurnAction.redoAll) {
      if (!staged) return SessionTurnUnavailable.noRevert;
      if (state(ref).revert?.anchor == null) {
        return SessionTurnUnavailable.targetUnknown;
      }
      if (action == SessionTurnAction.redoNext && _cutTurn(ref) == null) {
        return SessionTurnUnavailable.historyIncomplete;
      }
    }
    if (action == SessionTurnAction.undo &&
        confirmedSessionTurns(canonical).isEmpty) {
      return SessionTurnUnavailable.targetUnknown;
    }
    return null;
  }

  UserInput? _cutTurn(SessionRef ref) {
    final cut = state(ref).revert?.anchor;
    return confirmedSessionTurns(
      view(ref).state,
    ).where((turn) => turn.meta.anchor == cut).firstOrNull;
  }

  Future<SessionTurnResult> stage(
    SessionRef ref,
    ItemId boundary,
    CommandId id,
    bool Function() leaseCurrent,
  ) {
    final target = confirmedSessionTurns(
      view(ref).state,
    ).where((turn) => turn.id == boundary).firstOrNull;
    final cut = state(ref).staged ? state(ref).revert?.anchor : null;
    if (target == null ||
        (cut != null && target.meta.anchor!.compareTo(cut) >= 0)) {
      return Future.value(
        const SessionTurnResult(
          unavailable: SessionTurnUnavailable.targetUnknown,
        ),
      );
    }
    return _run(
      ref,
      SessionTurnAction.undo,
      id,
      leaseCurrent,
      target: target,
      operation: MutationOperation.revertStage,
    );
  }

  Future<SessionTurnResult> redoNext(
    SessionRef ref,
    CommandId id,
    bool Function() leaseCurrent,
  ) {
    final cut = _cutTurn(ref);
    if (cut == null) {
      return Future.value(
        const SessionTurnResult(
          unavailable: SessionTurnUnavailable.historyIncomplete,
        ),
      );
    }
    final next = confirmedSessionTurns(view(ref).state)
        .where((turn) => turn.meta.anchor!.compareTo(cut.meta.anchor!) > 0)
        .firstOrNull;
    return _run(
      ref,
      SessionTurnAction.redoNext,
      id,
      leaseCurrent,
      target: next,
      operation: next == null
          ? MutationOperation.revertClear
          : MutationOperation.revertStage,
    );
  }

  Future<SessionTurnResult> redoAll(
    SessionRef ref,
    CommandId id,
    bool Function() leaseCurrent,
  ) => _run(
    ref,
    SessionTurnAction.redoAll,
    id,
    leaseCurrent,
    operation: MutationOperation.revertClear,
  );

  Future<SessionTurnResult> compact(
    SessionRef ref,
    CommandId id,
    bool Function() leaseCurrent,
  ) => _run(
    ref,
    SessionTurnAction.compact,
    id,
    leaseCurrent,
    operation: MutationOperation.compact,
  );

  Future<SessionTurnResult> _run(
    SessionRef ref,
    SessionTurnAction action,
    CommandId id,
    bool Function() leaseCurrent, {
    required MutationOperation operation,
    UserInput? target,
  }) {
    final refusal = unavailable(ref, action);
    if (!leaseCurrent() || refusal != null) {
      return Future.value(
        SessionTurnResult(
          unavailable: refusal ?? SessionTurnUnavailable.offline,
        ),
      );
    }
    final entry = _entries[ref]!;
    final initialCut = state(ref).staged ? state(ref).revert?.anchor : null;
    // Set before queuing so two taps cannot both pass admission.
    entry
      ..phase = SessionTurnPhase.pending
      ..failure = null
      ..receipt = null;
    publish(ref);
    return queue.run(OpenCodePromptOutbox.keyFor(ref), () async {
      if (!_current(ref, entry) || !leaseCurrent()) {
        return _refuse(ref, entry, SessionTurnUnavailable.offline);
      }
      final nowCut = state(ref).staged ? state(ref).revert?.anchor : null;
      if (initialCut != nowCut) {
        return _refuse(ref, entry, SessionTurnUnavailable.targetUnknown);
      }
      // Temporarily test the current canonical state under the lock, rather
      // than relying on the UI's pre-queue view.
      entry.phase = SessionTurnPhase.idle;
      final changed = unavailable(ref, action);
      entry.phase = SessionTurnPhase.pending;
      if (changed != null) return _refuse(ref, entry, changed);
      final admission = _admissionReason(await promptRefusal(ref));
      if (admission != null) {
        entry
          ..admission = admission
          ..admissionView = view(ref).state;
        return _refuse(ref, entry, admission);
      }
      if (!_current(ref, entry) || !leaseCurrent()) {
        return _refuse(ref, entry, SessionTurnUnavailable.offline);
      }
      entry.phase = SessionTurnPhase.idle;
      final afterRead = unavailable(ref, action);
      entry.phase = SessionTurnPhase.pending;
      if (afterRead != null) return _refuse(ref, entry, afterRead);
      final afterCut = state(ref).staged ? state(ref).revert?.anchor : null;
      if (afterCut != initialCut) {
        return _refuse(ref, entry, SessionTurnUnavailable.targetUnknown);
      }
      // Revalidate a target after the awaited outbox read as well.
      if (target != null &&
          !confirmedSessionTurns(view(ref).state).any(
            (turn) =>
                turn.id == target.id && turn.meta.anchor == target.meta.anchor,
          )) {
        return _refuse(ref, entry, SessionTurnUnavailable.targetUnknown);
      }
      final result = await _mutateWithinQueue(
        ref,
        entry,
        operation,
        id,
        target: target,
        callerCurrent: leaseCurrent,
      );
      if (!_current(ref, entry) || !leaseCurrent()) {
        return const SessionTurnResult(
          unavailable: SessionTurnUnavailable.offline,
        );
      }
      return result;
    });
  }

  SessionTurnResult _refuse(
    SessionRef ref,
    _TurnEntry entry,
    SessionTurnUnavailable reason,
  ) {
    if (_current(ref, entry)) {
      entry
        ..phase = SessionTurnPhase.idle
        ..failure = reason;
      publish(ref);
    }
    return SessionTurnResult(unavailable: reason);
  }

  SessionTurnUnavailable? _admissionReason(String? reason) => switch (reason) {
    null => null,
    'unreadable' || 'notPersisted' => SessionTurnUnavailable.storage,
    'promptPending' => SessionTurnUnavailable.promptPending,
    _ => SessionTurnUnavailable.unconfirmed,
  };

  Future<void> _refreshAdmissionWithinQueue(
    SessionRef ref,
    _TurnEntry entry,
  ) async {
    final reason = _admissionReason(await promptRefusal(ref));
    if (!_current(ref, entry) || reason == entry.admission) return;
    entry
      ..admission = reason
      ..failure = null;
    publish(ref);
  }

  Future<SessionTurnResult> _mutateWithinQueue(
    SessionRef ref,
    _TurnEntry entry,
    MutationOperation operation,
    CommandId id, {
    UserInput? target,
    required bool Function() callerCurrent,
  }) async {
    final canonical = view(ref).state!;
    final anchor = target?.meta.anchor ?? state(ref).revert?.anchor;
    final record = TurnActionRecord(
      operation: operation,
      id: id,
      anchor: anchor,
      input: operation == MutationOperation.compact
          ? MessageRef(ids.mint())
          : null,
      tail: anchor == null
          ? const []
          : {
              for (final item in canonical.timeline)
                if (item.meta.anchor case final position?)
                  if (position.compareTo(anchor) >= 0) position.message,
            }.toList(),
      completeTail:
          !canonical.hasMoreHistory &&
          canonical.timeline.every((item) => item.meta.anchor != null),
    );
    entry
      ..record = record
      ..base = canonical.revert
      ..echoed = false
      ..superseded = false;
    if (!await journal.write(ref, record)) {
      entry
        ..phase = SessionTurnPhase.unconfirmed
        ..failure = SessionTurnUnavailable.storage;
      publish(ref);
      return const SessionTurnResult(
        unavailable: SessionTurnUnavailable.storage,
      );
    }
    if (!_current(ref, entry)) {
      return const SessionTurnResult(
        unavailable: SessionTurnUnavailable.offline,
      );
    }
    if (!callerCurrent()) {
      if (await journal.clear(ref)) {
        entry.record = null;
        return _refuse(ref, entry, SessionTurnUnavailable.offline);
      }
      entry
        ..phase = SessionTurnPhase.unconfirmed
        ..failure = SessionTurnUnavailable.storage;
      publish(ref);
      return const SessionTurnResult(
        unavailable: SessionTurnUnavailable.storage,
      );
    }
    final OpenCodeTurnAttempt attempt;
    try {
      attempt = await switch (operation) {
        MutationOperation.revertStage => client.stage(
          session: ref,
          request: RevertRequest(boundary: target!.id, includeFiles: true),
          id: id,
          cancellation: entry.cancellation,
        ),
        MutationOperation.revertClear => client.clear(
          session: ref,
          id: id,
          cancellation: entry.cancellation,
        ),
        MutationOperation.revertCommit => client.commit(
          session: ref,
          id: id,
          cancellation: entry.cancellation,
        ),
        _ => client.compact(
          session: ref,
          input: record.input!,
          id: id,
          cancellation: entry.cancellation,
        ),
      };
    } on Object {
      if (_current(ref, entry)) {
        entry.phase = SessionTurnPhase.unconfirmed;
        publish(ref);
      }
      rethrow;
    }
    if (!_current(ref, entry)) {
      return const SessionTurnResult(
        unavailable: SessionTurnUnavailable.offline,
      );
    }
    entry.receipt = attempt.receipt;
    final accepted = attempt.receipt.state.known == ReceiptState.accepted;
    final definite =
        accepted ||
        attempt.receipt.state.known == ReceiptState.rejected ||
        attempt.receipt.state.known == ReceiptState.unavailable;
    if (!definite) {
      entry.phase = SessionTurnPhase.unconfirmed;
      publish(ref);
      await _verifyWithinQueue(ref, entry);
      final proven =
          entry.phase == SessionTurnPhase.idle &&
          !entry.superseded &&
          (operation == MutationOperation.revertStage
              ? state(ref).revert?.anchor == target?.meta.anchor
              : operation == MutationOperation.revertClear &&
                    !state(ref).staged);
      return SessionTurnResult(
        receipt: attempt.receipt,
        applied: proven,
        restored: proven ? target : null,
        cleared: proven && operation == MutationOperation.revertClear,
      );
    }
    if (accepted && !entry.superseded) {
      if (operation == MutationOperation.compact) {
        entry.compact = attempt.receipt.nativeRef ?? record.input!.value;
      } else {
        entry.overlay =
            attempt.revert ??
            RevertState(
              anchor: record.anchor,
              kind: OpenValue.known(
                operation == MutationOperation.revertClear
                    ? RevertKind.cleared
                    : RevertKind.committed,
              ),
            );
        entry.base = view(ref).state?.revert;
        if (_matches(record, entry.base)) entry.overlay = null;
      }
    }
    if (await journal.clear(ref)) {
      entry
        ..record = null
        ..phase = SessionTurnPhase.idle;
    } else {
      entry
        ..phase = SessionTurnPhase.unconfirmed
        ..failure = SessionTurnUnavailable.storage;
    }
    publish(ref);
    refreshView(ref);
    final applied = accepted && !entry.superseded;
    return SessionTurnResult(
      receipt: attempt.receipt,
      applied: applied,
      restored: applied ? target : null,
      cleared: applied && operation == MutationOperation.revertClear,
    );
  }

  /// Runs inside outbox.submit's existing lock. This is the only automatic
  /// commit path, and is used only for a deliberate replacement send.
  Future<String?> beforeSubmit(
    SessionRef ref,
    bool Function() callerCurrent,
  ) async {
    final entry = _entries[ref];
    if (entry == null || !_current(ref, entry) || !callerCurrent()) {
      return 'turnOffline';
    }
    if (entry.phase != SessionTurnPhase.idle) return 'turnUnconfirmed';
    final current = view(ref);
    if (current.phase != SessionLivePhase.live || current.stale) {
      return 'turnOffline';
    }
    final revert = state(ref).revert;
    if (revert?.kind.known == null ||
        revert?.kind.known == RevertKind.unknown) {
      return 'turnTargetUnknown';
    }
    if (!state(ref).staged) return null;
    if (selectionHoldsSend(ref) ||
        current.state?.execution?.kind.known != ExecutionKind.idle) {
      return 'turnBusy';
    }
    if (state(ref).revert?.anchor == null) return 'turnTargetUnknown';
    entry.phase = SessionTurnPhase.pending;
    publish(ref);
    final result = await _mutateWithinQueue(
      ref,
      entry,
      MutationOperation.revertCommit,
      commandIds(),
      callerCurrent: callerCurrent,
    );
    return result.applied && entry.phase == SessionTurnPhase.idle
        ? null
        : 'turnUnconfirmed';
  }

  /// Reconciliation may settle an admission by reading, but cannot commit a
  /// revert or repost into a staged, pending or uncertain turn operation.
  Future<String?> beforeReplay(SessionRef ref) async {
    final entry = _entries[ref];
    if (entry == null || !_current(ref, entry)) return 'turnOffline';
    final revert = state(ref).revert;
    return entry.phase != SessionTurnPhase.idle ||
            state(ref).staged ||
            revert?.kind.known == null ||
            revert?.kind.known == RevertKind.unknown
        ? 'turnUnconfirmed'
        : null;
  }

  bool _matches(TurnActionRecord record, RevertState? revert) =>
      switch (record.operation) {
        MutationOperation.revertStage =>
          revert?.kind.known == RevertKind.staged &&
              revert?.anchor == record.anchor,
        MutationOperation.revertClear =>
          revert?.kind.known == RevertKind.cleared,
        MutationOperation.revertCommit =>
          revert?.kind.known == RevertKind.committed &&
              revert?.anchor == record.anchor,
        _ => false,
      };

  /// Called on canonical publications only. A later remote boundary wins
  /// over a late local HTTP reply. No publication replaces the local draft.
  void consider(SessionRef ref, SessionLiveView current) {
    final entry = _entries[ref];
    if (entry == null ||
        !_current(ref, entry) ||
        current.stale ||
        current.phase != SessionLivePhase.live) {
      return;
    }
    final canonical = current.state;
    if (canonical == null) return;
    if (entry.admission != null &&
        !identical(entry.admissionView, canonical) &&
        !entry.checkingAdmission) {
      entry
        ..admissionView = canonical
        ..checkingAdmission = true;
      unawaited(
        queue.run(OpenCodePromptOutbox.keyFor(ref), () async {
          try {
            if (_current(ref, entry)) {
              await _refreshAdmissionWithinQueue(ref, entry);
            }
          } finally {
            entry.checkingAdmission = false;
          }
        }),
      );
    }
    final record = entry.record;
    if (record != null && !identical(canonical.revert, entry.base)) {
      if (_matches(record, canonical.revert)) {
        entry.echoed = true;
      } else if (entry.echoed) {
        entry.superseded = true;
      }
    }
    if (entry.overlay != null && !identical(canonical.revert, entry.base)) {
      entry.overlay = null;
    }
    if (record?.operation == MutationOperation.compact &&
        canonical.timeline.any(
          (item) =>
              item is Notice &&
              item.kind.known == NoticeKind.compaction &&
              item.meta.anchor?.message == record!.input,
        )) {
      entry.echoed = true;
    }
    final compact = entry.compact;
    if (compact != null &&
        canonical.timeline.any(
          (item) =>
              item is Notice &&
              item.kind.known == NoticeKind.compaction &&
              item.meta.anchor?.message.value == compact &&
              (item.status.known == ItemStatus.completed ||
                  item.status.known == ItemStatus.failed),
        )) {
      entry.compact = null;
    }
    if (entry.phase == SessionTurnPhase.unconfirmed &&
        entry.record != null &&
        !entry.verifying) {
      entry.verifying = true;
      unawaited(
        queue.run(OpenCodePromptOutbox.keyFor(ref), () async {
          try {
            if (_current(ref, entry)) await _verifyWithinQueue(ref, entry);
          } finally {
            entry.verifying = false;
          }
        }),
      );
    }
  }

  Future<void> refresh(SessionRef ref) =>
      queue.run(OpenCodePromptOutbox.keyFor(ref), () async {
        final entry = _entries[ref];
        if (entry == null ||
            !_current(ref, entry) ||
            entry.phase == SessionTurnPhase.pending) {
          return;
        }
        // A failed pre-wire write may or may not have committed.
        if (entry.failure == SessionTurnUnavailable.storage) {
          try {
            entry.record = await journal.read(ref);
            entry.failure = null;
            if (entry.record == null) entry.phase = SessionTurnPhase.idle;
          } on Object {
            return;
          }
        }
        if (entry.admission != null) {
          await _refreshAdmissionWithinQueue(ref, entry);
        }
        await _verifyWithinQueue(ref, entry);
        refreshView(ref);
      });

  Future<void> _verifyWithinQueue(SessionRef ref, _TurnEntry entry) async {
    final record = entry.record;
    if (record == null || !_current(ref, entry)) return;
    final current = view(ref);
    if (current.phase != SessionLivePhase.live || current.stale) return;
    final canonical = current.state;
    final observed =
        entry.echoed &&
        canonical != null &&
        switch (record.operation) {
          MutationOperation.revertStage ||
          MutationOperation.revertClear => true,
          MutationOperation.revertCommit =>
            record.tail.isNotEmpty &&
                record.tail.every(
                  (message) => !canonical.timeline.any(
                    (item) => item.meta.anchor?.message == message,
                  ),
                ) &&
                canonical.pending.every(
                  (input) =>
                      input.anchor != null &&
                      input.anchor!.compareTo(record.anchor!) < 0,
                ),
          _ => true,
        };
    if (observed) {
      await _settleWithinQueue(ref, entry, record, canonical.revert);
      return;
    }
    final SessionSnapshot snapshot;
    try {
      snapshot = await reader.hydrateSession(
        ref,
        hydrationGeneration: 'turn-${record.id.value}',
        readStart:
            current.state?.lastPosition ??
            StreamPosition(id: 'turn', epoch: 'read', seq: BigInt.zero),
        sourceVersion: client.connectedVersion,
        historyLimit: 200,
        cancellation: entry.cancellation,
      );
    } on OpenCodeSessionReadException {
      return;
    }
    if (!_current(ref, entry) || !identical(entry.record, record)) return;
    // A direct read has no server watermark. Do not overlay a different,
    // newer canonical boundary that arrived while this read was in flight.
    if (record.operation != MutationOperation.compact &&
        !identical(view(ref).state?.revert, current.state?.revert) &&
        !_matches(record, view(ref).state?.revert)) {
      return;
    }
    final revert = snapshot.revert?.value;
    final timeline = snapshot.timeline;
    final complete = timeline?.complete == true && !snapshot.hasMoreHistory;
    final noRevert =
        revert?.kind.known == RevertKind.none ||
        revert?.kind.known == RevertKind.cleared ||
        revert?.kind.known == RevertKind.committed;
    final messages = {
      for (final item in timeline?.values ?? const <TimelineItem>[])
        if (item.meta.anchor case final anchor?) anchor.message,
    };
    final positive = switch (record.operation) {
      MutationOperation.revertStage => _matches(record, revert),
      MutationOperation.revertClear =>
        noRevert && complete && messages.contains(record.anchor!.message),
      MutationOperation.revertCommit =>
        noRevert &&
            complete &&
            record.completeTail &&
            record.tail.isNotEmpty &&
            record.tail.every((message) => !messages.contains(message)) &&
            snapshot.pending?.complete == true &&
            !snapshot.pending!.values.any(
              (input) => record.tail.contains(input.anchor?.message),
            ),
      _ =>
        timeline?.values.any(
              (item) =>
                  item is Notice &&
                  item.kind.known == NoticeKind.compaction &&
                  item.meta.anchor?.message == record.input,
            ) ==
            true,
    };
    if (!positive) return;
    await _settleWithinQueue(ref, entry, record, revert);
  }

  Future<void> _settleWithinQueue(
    SessionRef ref,
    _TurnEntry entry,
    TurnActionRecord record,
    RevertState? revert,
  ) async {
    if (!await journal.clear(ref) || !_current(ref, entry)) return;
    entry
      ..record = null
      ..phase = SessionTurnPhase.idle
      ..failure = null;
    // The stream owner remains the only canonical writer. Until its repair
    // arrives, expose this positively proven revert without changing rows.
    if (record.operation != MutationOperation.compact) {
      entry.overlay = entry.superseded ? null : revert;
    }
    entry.base = view(ref).state?.revert;
    publish(ref);
    refreshView(ref);
  }

  void release(SessionRef ref) => _entries.remove(ref)?.cancellation.cancel();
  void close() {
    _closed = true;
    for (final entry in _entries.values) {
      entry.cancellation.cancel();
    }
    _entries.clear();
  }
}

final class _TurnEntry {
  final cancellation = RequestCancellation();
  SessionTurnPhase phase = SessionTurnPhase.pending;
  SessionTurnUnavailable? failure;
  TurnActionRecord? record;
  CommandReceipt? receipt;
  RevertState? overlay;
  RevertState? base;
  String? compact;
  bool echoed = false;
  bool superseded = false;
  bool verifying = false;
  SessionTurnUnavailable? admission;
  SessionState? admissionView;
  bool checkingAdmission = false;
}

final class _TurnPort implements SessionTurnActionPort {
  _TurnPort(this.lane, this.ref, this.current);
  final OpenCodeTurnActionLane lane;
  final SessionRef ref;
  final bool Function() current;
  @override
  SessionTurnState get state =>
      current() ? lane.state(ref) : const SessionTurnState();
  @override
  SessionTurnUnavailable? unavailable(SessionTurnAction action) => current()
      ? lane.unavailable(ref, action)
      : SessionTurnUnavailable.offline;
  @override
  Future<SessionTurnResult> stage(ItemId boundary, {required CommandId id}) =>
      lane.stage(ref, boundary, id, current);
  @override
  Future<SessionTurnResult> redoNext({required CommandId id}) =>
      lane.redoNext(ref, id, current);
  @override
  Future<SessionTurnResult> redoAll({required CommandId id}) =>
      lane.redoAll(ref, id, current);
  @override
  Future<SessionTurnResult> compact({required CommandId id}) =>
      lane.compact(ref, id, current);
  @override
  Future<void> refresh() async {
    if (current()) await lane.refresh(ref);
  }
}
