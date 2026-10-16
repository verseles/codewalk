import 'dart:async';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/foundation.dart';

import '../../shared/sessions/command_ids.dart';
import '../../shared/sessions/prompt_outbox.dart';
import '../../shared/sessions/session_live_source.dart';
import 'session_live_controller.dart';

/// What the last composer action showed; each maps to finite copy, never a
/// raw reason or server text.
enum ComposerNotice {
  none,
  unconfirmed,
  notSaved,
  full,
  unreadable,
  unavailable,
  conflict,
  identityOccupied,
  authRequired,
  rateLimited,
  sessionGone,
  rejected,
  cancelled,
  deliveredFirst,
  cancelPending,
  switched,
  switchNotApplied,
  changeFailed,
  versionChanged,
}

/// One pending inbox row; [entry] is set when this device sent it.
final class ComposerChip {
  const ComposerChip(this.pending, this.entry);
  final PendingInput pending;
  final OutboxEntry? entry;
}

bool openFence(CancellationFence fence) => const {
  CancellationFence.requested,
  CancellationFence.submitting,
  CancellationFence.uncertain,
  CancellationFence.unknown,
}.contains(fence);

bool canCancel(OutboxEntry entry) =>
    entry.state == SubmissionKind.admitted &&
    entry.fence == CancellationFence.none;

bool canSwitch(OutboxEntry entry) => canCancel(entry);

/// Sends through the live lease's outbox: steer unless the user picks queue
/// for that send, a fresh command per deliberate send, and only the outbox's
/// own bounded same-id replay ever posts a prompt again.
class SessionComposerController extends ChangeNotifier {
  SessionComposerController({
    required this.live,
    CommandId Function()? commandIds,
  }) : _commandIds = commandIds ?? mintCommandId {
    live.addListener(_liveChanged);
    _liveChanged();
  }

  final SessionLiveController live;
  final CommandId Function() _commandIds;
  PromptOutbox? _outbox;
  bool _disposed = false;

  List<OutboxEntry> entries = const [];
  bool unreadable = false;
  bool sending = false;
  Delivery delivery = Delivery.steer;
  ComposerNotice notice = ComposerNotice.none;
  final busy = <CommandId>{};

  SessionRef get session => live.session;
  bool get available => _outbox != null;

  bool get canSend =>
      _outbox != null &&
      !unreadable &&
      !sending &&
      !live.stopping &&
      live.view?.phase == SessionLivePhase.live &&
      !(live.view?.stale ?? true);

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _liveChanged() {
    final outbox = live.outbox;
    if (identical(outbox, _outbox)) {
      _notify();
      return;
    }
    _outbox = outbox;
    entries = const [];
    unreadable = false;
    busy.clear();
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    final outbox = _outbox;
    if (outbox == null) return _notify();
    try {
      final next = await outbox.entries(session);
      if (_disposed || !identical(outbox, _outbox)) return;
      entries = next;
      if (unreadable) {
        unreadable = false;
        if (notice == ComposerNotice.unreadable) notice = ComposerNotice.none;
      }
    } on StateError {
      if (_disposed || !identical(outbox, _outbox)) return;
      unreadable = true;
      // The outcome of the action just taken stays; the re-read action
      // says the rest.
      if (notice == ComposerNotice.none) notice = ComposerNotice.unreadable;
    }
    _notify();
  }

  void setDelivery(Delivery next) {
    if (next != Delivery.steer && next != Delivery.queue) return;
    delivery = next;
    _notify();
  }

  OutboxEntry? _entry(CommandId id) {
    for (final entry in entries) {
      if (entry.commandId == id) return entry;
    }
    return null;
  }

  /// The pending inbox rows, each with this device's entry when it sent it.
  List<ComposerChip> chips(SessionState? state) {
    final byMessage = {for (final e in entries) e.messageId: e};
    return [
      for (final pending in state?.pending ?? const <PendingInput>[])
        ComposerChip(pending, byMessage[live.nativeMessageOf(pending.id)]),
    ];
  }

  /// This device's entries that still need the user and have no inbox row.
  List<OutboxEntry> rows(
    SessionState? state, [
    List<ComposerChip>? shownChips,
  ]) {
    final shown = {
      for (final chip in shownChips ?? chips(state))
        if (chip.entry case final entry?) entry.commandId,
    };
    return [
      for (final entry in entries)
        if (!shown.contains(entry.commandId) &&
            (entry.state == SubmissionKind.uncertain ||
                entry.state == SubmissionKind.rejected ||
                entry.state == SubmissionKind.sending ||
                (entry.state == SubmissionKind.admitted &&
                    openFence(entry.fence))))
          entry,
    ];
  }

  /// Returns whether the field may be cleared: only once the prompt belongs
  /// to a recorded admitted or uncertain entry.
  Future<bool> send(String text) async {
    final outbox = _outbox;
    if (!canSend || outbox == null || text.trim().isEmpty) return false;
    return _submit(outbox, text, delivery, fromChoice: true);
  }

  /// Sending lasts until the automatic check of an uncertain send ends, so
  /// the text still in the field cannot be sent twice meanwhile.
  Future<bool> _submit(
    PromptOutbox outbox,
    String text,
    Delivery as, {
    bool fromChoice = false,
  }) async {
    sending = true;
    notice = ComposerNotice.none;
    _notify();
    try {
      final result = await outbox.submit(
        session: session,
        commandId: _commandIds(),
        draft: PromptDraft(text: text),
        delivery: as,
      );
      if (_disposed) return false;
      final entry = result.entry;
      // A lease reopened meanwhile shares the ledger: a recorded prompt was
      // still sent, so its text must leave the field.
      final current = identical(outbox, _outbox);
      if (entry == null) {
        notice = submitRefusal(result.refusal);
        // Offers the re-read the open-time failure offers.
        if (current && result.refusal == 'unreadable') unreadable = true;
        return false;
      }
      if (entry.state == SubmissionKind.rejected) {
        notice = rejection(entry.reason);
        // The field keeps the text, so the ledger need not.
        await outbox.dismiss(session, entry.commandId);
        if (current) await _refresh();
        return false;
      }
      if (!current) return _sent(fromChoice, as);
      if (entry.state == SubmissionKind.uncertain) {
        notice = ComposerNotice.unconfirmed;
        await _refresh();
        // One check of a fresh uncertain send; later ones are the user's.
        // Decided by the check's own result, not a ledger read that may fail.
        final checked = await _check(entry.commandId);
        if (checked?.state == SubmissionKind.rejected) {
          await outbox.dismiss(session, entry.commandId);
          await _refresh();
          return false;
        }
        return _sent(fromChoice, as);
      }
      await _refresh();
      return _sent(fromChoice, as);
    } finally {
      sending = false;
      _notify();
    }
  }

  /// A choice changed while this send was in flight is the next one's; a
  /// send that did not go keeps it for the retry.
  bool _sent(bool fromChoice, Delivery as) {
    // A screen closed meanwhile has disposed the draft this would clear.
    if (_disposed) return false;
    if (fromChoice && delivery == as) delivery = Delivery.steer;
    return true;
  }

  /// Reads the ledger again, after it could not be read.
  Future<void> reload() => _refresh();

  Future<void> _run(
    CommandId id,
    Future<void> Function(PromptOutbox) op,
  ) async {
    final outbox = _outbox;
    if (outbox == null || live.stopping || !busy.add(id)) return;
    _notify();
    try {
      await op(outbox);
    } finally {
      busy.remove(id);
    }
    if (_disposed || !identical(outbox, _outbox)) return;
    await _refresh();
  }

  /// Reads the server for this entry; an unconfirmed send may be posted
  /// again under its own id, an unsettled cancel never is.
  Future<void> checkAgain(CommandId id) => _check(id);

  Future<OutboxEntry?> _check(CommandId id) async {
    OutboxEntry? checked;
    await _run(id, (outbox) async {
      final result = await outbox.reconcile(session, id);
      checked = result.entry;
      _noteCheck(result);
    });
    return checked;
  }

  void _noteCheck(OutboxReconciliation result) {
    final entry = result.entry;
    notice = switch (entry?.state) {
      null => mutationRefusal(result.refusal),
      SubmissionKind.uncertain => ComposerNotice.unconfirmed,
      SubmissionKind.rejected => rejection(entry!.reason),
      SubmissionKind.cancelled => ComposerNotice.cancelled,
      SubmissionKind.delivered when entry!.fence == CancellationFence.settled =>
        ComposerNotice.deliveredFirst,
      _ when openFence(entry!.fence) => ComposerNotice.cancelPending,
      _ => ComposerNotice.none,
    };
  }

  Future<void> cancel(CommandId id) => _run(id, (outbox) async {
    final result = await outbox.cancel(session, id);
    final entry = result.entry;
    notice = switch (entry?.state) {
      null => mutationRefusal(result.refusal),
      SubmissionKind.cancelled => ComposerNotice.cancelled,
      SubmissionKind.delivered => ComposerNotice.deliveredFirst,
      _ when openFence(entry!.fence) => ComposerNotice.cancelPending,
      _ => ComposerNotice.changeFailed,
    };
  });

  Future<void> switchDelivery(CommandId id, Delivery target) =>
      _run(id, (outbox) async {
        final result = await outbox.switchDelivery(session, id, target);
        final entry = result.entry;
        notice = switch (entry?.state) {
          null => mutationRefusal(result.refusal),
          SubmissionKind.delivered => ComposerNotice.switchNotApplied,
          SubmissionKind.cancelled => ComposerNotice.cancelled,
          SubmissionKind.admitted
              when entry!.delivery == target && entry.reason == null =>
            ComposerNotice.switched,
          _
              when entry!.reason == 'switchNotApplied' ||
                  entry.reason == 'ConflictError' =>
            ComposerNotice.switchNotApplied,
          _ => ComposerNotice.changeFailed,
        };
      });

  /// A new command with the recorded text: the old one is forgotten first,
  /// so it is never posted again, and this may duplicate the prompt. Returns
  /// the text when the new send did not take it, for the empty field.
  Future<String?> sendAgain(CommandId id) async {
    final outbox = _outbox;
    final old = _entry(id);
    if (!canSend || outbox == null || old == null || !busy.add(id)) {
      return null;
    }
    // Sending from the start: the field stays untouched until the text is
    // either taken or handed back.
    sending = true;
    _notify();
    try {
      final forgotten = await outbox.dismiss(session, id);
      if (_disposed) return null;
      if (!forgotten) {
        notice = ComposerNotice.notSaved;
        await _refresh();
        return null;
      }
      // Forgotten from a lease that was reopened meanwhile: never sent.
      if (!identical(outbox, _outbox)) return old.text;
      final sent = await _submit(outbox, old.text, old.delivery);
      return sent || _disposed ? null : old.text;
    } finally {
      busy.remove(id);
      sending = false;
      _notify();
    }
  }

  Future<void> discard(CommandId id) => _run(id, (outbox) async {
    if (!await outbox.dismiss(session, id)) notice = ComposerNotice.notSaved;
  });

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    live.removeListener(_liveChanged);
    super.dispose();
  }
}

ComposerNotice submitRefusal(String? reason) => switch (reason) {
  'unreadable' => ComposerNotice.unreadable,
  'notPersisted' => ComposerNotice.notSaved,
  'full' => ComposerNotice.full,
  'versionChanged' || 'unverifiedVersion' => ComposerNotice.versionChanged,
  _ => ComposerNotice.unavailable,
};

ComposerNotice rejection(String? reason) => switch (reason) {
  'ConflictError' => ComposerNotice.conflict,
  'PromptIdentityOccupied' ||
  'identityOccupied' => ComposerNotice.identityOccupied,
  'UnauthorizedError' => ComposerNotice.authRequired,
  'RateLimited' => ComposerNotice.rateLimited,
  'NotFoundError' || 'SessionNotFoundError' => ComposerNotice.sessionGone,
  _ => ComposerNotice.rejected,
};

ComposerNotice mutationRefusal(String? reason) => switch (reason) {
  'versionChanged' => ComposerNotice.versionChanged,
  'identityOccupied' => ComposerNotice.identityOccupied,
  'notPersisted' => ComposerNotice.notSaved,
  'unreadable' => ComposerNotice.unreadable,
  'cancellationFence' => ComposerNotice.cancelPending,
  _ => ComposerNotice.changeFailed,
};
