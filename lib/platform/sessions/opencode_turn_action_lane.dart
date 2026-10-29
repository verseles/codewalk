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
          entry.compact = record?.admittedInput?.value;
          final admission = _admissionReason(await promptRefusal(ref));
          if (!_current(ref, entry)) return;
          entry
            ..admission = admission
            ..admissionView = view(ref).state
            ..phase = record == null || record.admittedInput != null
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

  RevertState? _revert(SessionRef ref) =>
      _entries[ref]?.overlay ?? view(ref).state?.revert;

  bool _staged(SessionRef ref) => _revert(ref)?.kind.known == RevertKind.staged;

  bool _compacting(SessionRef ref) =>
      _entries[ref]?.compact != null ||
      (view(ref).state?.timeline.any(
            (item) =>
                item is Notice &&
                item.kind.known == NoticeKind.compaction &&
                item.status.known == ItemStatus.streaming,
          ) ??
          false);

  SessionTurnState state(SessionRef ref) {
    final entry = _entries[ref];
    return SessionTurnState(
      phase: entry?.phase ?? SessionTurnPhase.pending,
      revert: entry?.overlay ?? view(ref).state?.revert,
      receipt: entry?.receipt,
      unavailable: entry?.failure ?? entry?.admission,
      compacting: _compacting(ref),
      sendUnavailable: _staged(ref)
          ? unavailable(ref, SessionTurnAction.redoAll)
          : null,
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
    if (canonical == null ||
        canonical.execution?.kind.known != ExecutionKind.idle ||
        _compacting(ref)) {
      return SessionTurnUnavailable.busy;
    }
    if (canonical.pending.isNotEmpty) {
      return SessionTurnUnavailable.promptPending;
    }
    final staged = _staged(ref);
    final revert = _revert(ref);
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
      if (_revert(ref)?.anchor == null) {
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
    final cut = _revert(ref)?.anchor;
    return confirmedSessionTurns(
      view(ref).state,
    ).where((turn) => turn.meta.anchor == cut).firstOrNull;
  }

  bool _sameSuccessor(SessionRef ref, UserInput? expected) {
    final cut = _cutTurn(ref);
    if (cut == null) return false;
    final next = confirmedSessionTurns(view(ref).state)
        .where((turn) => turn.meta.anchor!.compareTo(cut.meta.anchor!) > 0)
        .firstOrNull;
    return next?.id == expected?.id &&
        next?.meta.anchor == expected?.meta.anchor;
  }

  SessionTurnUnavailable? _whilePending(
    SessionRef ref,
    _TurnEntry entry,
    SessionTurnAction action,
  ) {
    final previous = entry.phase;
    entry.phase = SessionTurnPhase.idle;
    try {
      return unavailable(ref, action);
    } finally {
      entry.phase = previous;
    }
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
    final cut = _staged(ref) ? _revert(ref)?.anchor : null;
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
    final initialCut = _staged(ref) ? _revert(ref)?.anchor : null;
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
      final nowCut = _staged(ref) ? _revert(ref)?.anchor : null;
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
      final afterCut = _staged(ref) ? _revert(ref)?.anchor : null;
      if (afterCut != initialCut) {
        return _refuse(ref, entry, SessionTurnUnavailable.targetUnknown);
      }
      if (action == SessionTurnAction.redoNext &&
          !_sameSuccessor(ref, target)) {
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
        action: action,
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

  Future<SessionTurnResult> _retireUnsent(
    SessionRef ref,
    _TurnEntry entry,
    SessionTurnUnavailable reason,
  ) async {
    if (await journal.clear(ref)) {
      if (_current(ref, entry)) entry.record = null;
      return _refuse(ref, entry, reason);
    }
    if (_current(ref, entry)) {
      entry
        ..phase = SessionTurnPhase.unconfirmed
        ..failure = SessionTurnUnavailable.storage;
      publish(ref);
    }
    return const SessionTurnResult(unavailable: SessionTurnUnavailable.storage);
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
    SessionTurnAction? action,
    required bool Function() callerCurrent,
  }) async {
    final canonical = view(ref).state!;
    final wasStaged = _staged(ref);
    final initialCut = wasStaged ? _revert(ref)?.anchor : null;
    final anchor = target?.meta.anchor ?? _revert(ref)?.anchor;
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
    if (!_current(ref, entry) || !callerCurrent()) {
      return _retireUnsent(ref, entry, SessionTurnUnavailable.offline);
    }
    final refusal = _whilePending(
      ref,
      entry,
      action ?? SessionTurnAction.redoAll,
    );
    if (refusal != null) return _retireUnsent(ref, entry, refusal);
    final cut = _staged(ref) ? _revert(ref)?.anchor : null;
    if (_staged(ref) != wasStaged ||
        cut != initialCut ||
        (action == SessionTurnAction.redoNext &&
            !_sameSuccessor(ref, target)) ||
        (target != null &&
            !confirmedSessionTurns(view(ref).state).any(
              (turn) =>
                  turn.id == target.id &&
                  turn.meta.anchor == target.meta.anchor,
            ))) {
      return _retireUnsent(ref, entry, SessionTurnUnavailable.targetUnknown);
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
    final accepted = attempt.receipt.state.known == ReceiptState.accepted;
    final definite =
        accepted ||
        attempt.receipt.state.known == ReceiptState.rejected ||
        attempt.receipt.state.known == ReceiptState.unavailable;
    if (!_current(ref, entry)) {
      // Closing a view suppresses UI effects, not a known durable outcome.
      if (accepted && operation == MutationOperation.compact) {
        await journal.write(
          ref,
          record.withAdmission(
            MessageRef(attempt.receipt.nativeRef ?? record.input!.value),
          ),
        );
      } else if (definite) {
        await journal.clear(ref);
      }
      return const SessionTurnResult(
        unavailable: SessionTurnUnavailable.offline,
      );
    }
    entry.receipt = attempt.receipt;
    if (!definite) {
      entry.phase = SessionTurnPhase.unconfirmed;
      publish(ref);
      final verified = await _verifyWithinQueue(ref, entry);
      final proven =
          verified &&
          entry.phase == SessionTurnPhase.idle &&
          !entry.superseded &&
          (operation == MutationOperation.compact ||
              (operation == MutationOperation.revertStage
                  ? _revert(ref)?.anchor == target?.meta.anchor
                  : operation == MutationOperation.revertClear &&
                        !_staged(ref)));
      return SessionTurnResult(
        receipt: attempt.receipt,
        applied: proven,
        restored: proven ? target : null,
        cleared: proven && operation == MutationOperation.revertClear,
      );
    }
    if (accepted && operation == MutationOperation.compact) {
      await _admitCompact(
        ref,
        entry,
        record,
        MessageRef(attempt.receipt.nativeRef ?? record.input!.value),
      );
      return SessionTurnResult(
        receipt: attempt.receipt,
        applied: true,
        unavailable: entry.failure,
      );
    }
    if (accepted && !entry.superseded) {
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
    final revert = _revert(ref);
    if (revert?.kind.known == null ||
        revert?.kind.known == RevertKind.unknown) {
      return 'turnTargetUnknown';
    }
    // Ordinary prompts keep their verified steer/queue behavior. A staged
    // replacement additionally needs the destructive commit preflight.
    if (!_staged(ref)) return null;
    final refusal = _whilePending(ref, entry, SessionTurnAction.redoAll);
    if (refusal != null) return 'turnBusy';
    final cut = revert!.anchor;
    entry.phase = SessionTurnPhase.pending;
    publish(ref);
    final admission = _admissionReason(await promptRefusal(ref));
    if (!_current(ref, entry) || !callerCurrent()) {
      _refuse(ref, entry, SessionTurnUnavailable.offline);
      return 'turnOffline';
    }
    if (admission != null) {
      entry
        ..admission = admission
        ..admissionView = view(ref).state;
      _refuse(ref, entry, admission);
      return 'turnUnconfirmed';
    }
    final changed = _whilePending(ref, entry, SessionTurnAction.redoAll);
    if (changed != null || _revert(ref)?.anchor != cut) {
      _refuse(ref, entry, changed ?? SessionTurnUnavailable.targetUnknown);
      return 'turnBusy';
    }
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
    final revert = _revert(ref);
    return entry.phase != SessionTurnPhase.idle ||
            _staged(ref) ||
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
    if (record != null &&
        record.operation != MutationOperation.compact &&
        !identical(canonical.revert, entry.base)) {
      if (_matches(record, canonical.revert)) {
        entry.echoed = true;
        entry.superseded = false;
      } else {
        entry.superseded = true;
      }
    }
    if (entry.overlay != null && !identical(canonical.revert, entry.base)) {
      entry.overlay = null;
    }
    final compactNotice = record?.operation == MutationOperation.compact
        ? _compactNotice(canonical.timeline, _compactIdentity(entry, record!))
        : null;
    if (compactNotice != null) entry.echoed = true;
    if (entry.record != null &&
        !entry.verifying &&
        entry.phase != SessionTurnPhase.pending &&
        (entry.phase == SessionTurnPhase.unconfirmed ||
            (compactNotice != null &&
                (record!.admittedInput == null || _terminal(compactNotice))))) {
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
            if (entry.record == null) {
              entry.phase = SessionTurnPhase.idle;
              entry.compact = null;
            } else if (entry.record!.admittedInput != null) {
              entry.phase = SessionTurnPhase.idle;
              entry.compact = entry.record!.admittedInput!.value;
            }
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

  MessageRef _compactIdentity(_TurnEntry entry, TurnActionRecord record) =>
      record.admittedInput ??
      (entry.compact == null ? record.input! : MessageRef(entry.compact!));

  Notice? _compactNotice(Iterable<TimelineItem> items, MessageRef identity) =>
      items
          .whereType<Notice>()
          .where(
            (item) =>
                item.kind.known == NoticeKind.compaction &&
                item.meta.anchor?.message == identity,
          )
          .firstOrNull;

  bool _terminal(Notice notice) =>
      notice.status.known == ItemStatus.completed ||
      notice.status.known == ItemStatus.failed;

  Future<bool> _admitCompact(
    SessionRef ref,
    _TurnEntry entry,
    TurnActionRecord record,
    MessageRef identity,
  ) async {
    final admitted = record.admittedInput == identity
        ? record
        : record.withAdmission(identity);
    final changed =
        entry.compact != identity.value ||
        entry.phase != SessionTurnPhase.idle ||
        entry.failure != null;
    final stored =
        (record.admittedInput == identity &&
            entry.failure != SessionTurnUnavailable.storage) ||
        await journal.write(ref, admitted);
    // Keep the admitted identity even when a status write fails. A later
    // read/terminal can retry storage; it must not fall back to the input ID.
    entry
      ..record = admitted
      ..compact = identity.value;
    if (!_current(ref, entry)) return stored;
    entry
      ..phase = stored ? SessionTurnPhase.idle : SessionTurnPhase.unconfirmed
      ..failure = stored ? null : SessionTurnUnavailable.storage;
    if (changed || !stored) {
      publish(ref);
      refreshView(ref);
    }
    return stored;
  }

  Future<bool> _verifyWithinQueue(SessionRef ref, _TurnEntry entry) async {
    final record = entry.record;
    if (record == null || !_current(ref, entry)) return false;
    final current = view(ref);
    if (current.phase != SessionLivePhase.live || current.stale) return false;
    final canonical = current.state;
    if (record.operation == MutationOperation.compact) {
      final identity = _compactIdentity(entry, record);
      final notice = _compactNotice(canonical?.timeline ?? const [], identity);
      if (notice != null) {
        if (_terminal(notice)) {
          return _settleWithinQueue(ref, entry, record, canonical?.revert);
        }
        if (notice.status.known == ItemStatus.streaming) {
          return _admitCompact(ref, entry, record, identity);
        }
      }
      if (record.admittedInput == null &&
          entry.receipt?.id == record.id &&
          entry.receipt?.state.known == ReceiptState.accepted) {
        return _admitCompact(ref, entry, record, identity);
      }
    } else if (entry.receipt?.id == record.id &&
        const {
          ReceiptState.accepted,
          ReceiptState.rejected,
          ReceiptState.unavailable,
        }.contains(entry.receipt?.state.known)) {
      // A known HTTP outcome need not become uncertain just because local
      // journal cleanup failed. Retrying cleanup never repeats the mutation.
      return _settleWithinQueue(
        ref,
        entry,
        record,
        entry.overlay ?? canonical?.revert,
      );
    }
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
          _ => false,
        };
    if (observed) {
      return _settleWithinQueue(ref, entry, record, canonical.revert);
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
      return false;
    }
    if (!_current(ref, entry) || !identical(entry.record, record)) return false;
    // A direct read has no server watermark. Do not overlay a different,
    // newer canonical boundary that arrived while this read was in flight.
    if (record.operation != MutationOperation.compact &&
        !identical(view(ref).state?.revert, current.state?.revert) &&
        !_matches(record, view(ref).state?.revert)) {
      return false;
    }
    final revert = snapshot.revert?.value;
    final timeline = snapshot.timeline;
    if (record.operation == MutationOperation.compact) {
      final identity = _compactIdentity(entry, record);
      final notice = _compactNotice(timeline?.values ?? const [], identity);
      if (notice == null) return false;
      if (_terminal(notice)) {
        return _settleWithinQueue(ref, entry, record, revert);
      }
      return notice.status.known == ItemStatus.streaming &&
          await _admitCompact(ref, entry, record, identity);
    }
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
      _ => false,
    };
    if (!positive) return false;
    return _settleWithinQueue(ref, entry, record, revert);
  }

  Future<bool> _settleWithinQueue(
    SessionRef ref,
    _TurnEntry entry,
    TurnActionRecord record,
    RevertState? revert,
  ) async {
    if (!await journal.clear(ref)) {
      if (_current(ref, entry)) {
        entry
          ..phase = SessionTurnPhase.unconfirmed
          ..failure = SessionTurnUnavailable.storage;
        publish(ref);
      }
      return false;
    }
    if (!_current(ref, entry)) return false;
    entry
      ..record = null
      ..phase = SessionTurnPhase.idle
      ..failure = null;
    if (record.operation == MutationOperation.compact) entry.compact = null;
    // The stream owner remains the only canonical writer. Until its repair
    // arrives, expose this positively proven revert without changing rows.
    if (record.operation != MutationOperation.compact) {
      entry.overlay = entry.superseded ? null : revert;
    }
    entry.base = view(ref).state?.revert;
    publish(ref);
    refreshView(ref);
    return true;
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
