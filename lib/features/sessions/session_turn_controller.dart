import 'dart:async';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';

import '../../shared/l10n/l10n_context.dart';
import '../../shared/sessions/command_ids.dart';
import '../../shared/sessions/session_turn_actions.dart' as shared;
import 'session_builtin_commands.dart' as builtin;
import 'session_live_controller.dart';

/// Shows the confirmation dialog before replacing unsent draft text with an undone turn.
Future<bool> confirmReplaceDraftDialog(BuildContext context) async {
  final l = context.v2L10n;
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l.turnReplaceDraftTitle),
      content: Text(l.turnReplaceDraftMessage),
      actions: [
        TextButton(
          key: const ValueKey('turn-replace-draft-cancel'),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l.commonCancel),
        ),
        TextButton(
          key: const ValueKey('turn-replace-draft-confirm'),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l.turnReplaceDraftConfirm),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Tracks draft revisions and provenance, coordinating undo/redo/compact actions.
class SessionTurnController extends ChangeNotifier
    implements builtin.SessionTurnActions {
  SessionTurnController({
    required this.live,
    CommandId Function()? commandIds,
  }) : _commandIds = commandIds ?? mintCommandId {
    _lastDraftText = live.draft.text;
    live.draft.addListener(_onDraftChanged);
  }

  final SessionLiveController live;
  final CommandId Function() _commandIds;

  String _lastDraftText = '';
  int _revision = 0;
  String? _restoredText;
  int? _restoredRevision;
  bool _disposed = false;

  /// Optional confirmation callback for testing or programmatic overrides.
  Future<bool> Function()? confirmReplaceDraft;

  bool get disposed => _disposed;
  int get revision => _revision;
  String? get restoredText => _restoredText;
  int? get restoredRevision => _restoredRevision;

  shared.SessionTurnActionPort? get port => live.turnActions;
  SessionRef get session => live.session;

  bool get hasUntouchedRestoredText =>
      _restoredText != null &&
      live.draft.text == _restoredText &&
      _revision == _restoredRevision;

  bool get canUndo =>
      !_disposed && port?.unavailable(shared.SessionTurnAction.undo) == null;

  bool get canRedoNext =>
      !_disposed &&
      port?.unavailable(shared.SessionTurnAction.redoNext) == null;

  bool get canRedoAll =>
      !_disposed &&
      port?.unavailable(shared.SessionTurnAction.redoAll) == null;

  bool get canCompact =>
      !_disposed &&
      port?.unavailable(shared.SessionTurnAction.compact) == null;

  void _onDraftChanged() {
    if (_disposed) return;
    final text = live.draft.text;
    if (text == _lastDraftText) return;
    _lastDraftText = text;
    _revision++;
    notifyListeners();
  }

  void _setRestoredDraft(String text) {
    if (_disposed) return;
    _restoredText = text;
    _lastDraftText = text;
    _revision++;
    _restoredRevision = _revision;
    live.draft.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    notifyListeners();
  }

  void _clearRestoredDraft() {
    if (_disposed) return;
    _restoredText = null;
    _restoredRevision = null;
    _lastDraftText = '';
    _revision++;
    live.draft.clear();
    notifyListeners();
  }

  /// The confirmed user turns visible before any staged cut.
  List<UserInput> visibleConfirmedTurns() {
    final allTurns = shared.confirmedSessionTurns(live.state);
    final cut = port?.state.staged == true ? port?.state.revert?.anchor : null;
    if (cut == null) return allTurns;
    return allTurns
        .where(
          (turn) =>
              turn.meta.anchor != null && turn.meta.anchor!.compareTo(cut) < 0,
        )
        .toList();
  }

  /// Stages an undo/rewind to [target].
  Future<shared.SessionTurnResult> stageUndo({
    required UserInput target,
    BuildContext? context,
    Future<bool> Function()? confirm,
  }) async {
    if (_disposed) {
      return const shared.SessionTurnResult(
        unavailable: shared.SessionTurnUnavailable.offline,
      );
    }
    final port = this.port;
    if (port == null) {
      return const shared.SessionTurnResult(
        unavailable: shared.SessionTurnUnavailable.offline,
      );
    }
    final refusal = port.unavailable(shared.SessionTurnAction.undo);
    if (refusal != null) {
      return shared.SessionTurnResult(unavailable: refusal);
    }

    final initialRevision = _revision;
    final currentDraft = live.draft.text;
    final isUntouched = hasUntouchedRestoredText;
    final needsConfirm =
        currentDraft.trim().isNotEmpty &&
        !isUntouched &&
        currentDraft != target.text;

    if (needsConfirm) {
      final confirmFn = confirm ?? confirmReplaceDraft;
      final bool confirmed;
      if (confirmFn != null) {
        confirmed = await confirmFn();
      } else if (context != null && context.mounted) {
        confirmed = await confirmReplaceDraftDialog(context);
      } else {
        return const shared.SessionTurnResult();
      }
      if (!confirmed || _disposed) {
        return const shared.SessionTurnResult();
      }
    }

    final result = await port.stage(target.id, id: _commandIds());
    if (result.applied && !_disposed) {
      if (_revision == initialRevision) {
        _setRestoredDraft(target.text);
      }
    }
    return result;
  }

  /// Undoes the latest visible confirmed user turn.
  Future<shared.SessionTurnResult> undoLast({
    BuildContext? context,
    Future<bool> Function()? confirm,
  }) async {
    final turns = visibleConfirmedTurns();
    if (turns.isEmpty) {
      return const shared.SessionTurnResult(
        unavailable: shared.SessionTurnUnavailable.targetUnknown,
      );
    }
    return stageUndo(
      target: turns.last,
      context: context,
      confirm: confirm,
    );
  }

  /// Redoes the next cut turn.
  Future<shared.SessionTurnResult> redoNext() async {
    if (_disposed) {
      return const shared.SessionTurnResult(
        unavailable: shared.SessionTurnUnavailable.offline,
      );
    }
    final port = this.port;
    if (port == null) {
      return const shared.SessionTurnResult(
        unavailable: shared.SessionTurnUnavailable.offline,
      );
    }
    final result = await port.redoNext(id: _commandIds());
    if (result.applied && result.cleared && !_disposed) {
      if (hasUntouchedRestoredText) {
        _clearRestoredDraft();
      }
    }
    return result;
  }

  /// Clears all staged cuts. If draft holds untouched restored text, it is cleared.
  Future<shared.SessionTurnResult> redoAll() async {
    if (_disposed) {
      return const shared.SessionTurnResult(
        unavailable: shared.SessionTurnUnavailable.offline,
      );
    }
    final port = this.port;
    if (port == null) {
      return const shared.SessionTurnResult(
        unavailable: shared.SessionTurnUnavailable.offline,
      );
    }
    final result = await port.redoAll(id: _commandIds());
    if ((result.applied || result.cleared) && !_disposed) {
      if (hasUntouchedRestoredText) {
        _clearRestoredDraft();
      }
    }
    return result;
  }

  /// Compacts context in the active session.
  Future<shared.SessionTurnResult> compact() async {
    if (_disposed) {
      return const shared.SessionTurnResult(
        unavailable: shared.SessionTurnUnavailable.offline,
      );
    }
    final port = this.port;
    if (port == null) {
      return const shared.SessionTurnResult(
        unavailable: shared.SessionTurnUnavailable.offline,
      );
    }
    return port.compact(id: _commandIds());
  }

  @override
  builtin.SessionTurnActionUnavailable? unavailable(
    builtin.SessionTurnAction action,
  ) {
    if (_disposed) return builtin.SessionTurnActionUnavailable.unavailable;
    final port = this.port;
    if (port == null) return builtin.SessionTurnActionUnavailable.unavailable;
    final sharedAction = switch (action) {
      builtin.SessionTurnAction.undo => shared.SessionTurnAction.undo,
      builtin.SessionTurnAction.redo => shared.SessionTurnAction.redoNext,
      builtin.SessionTurnAction.compact => shared.SessionTurnAction.compact,
    };
    final reason = port.unavailable(sharedAction);
    if (reason == null) return null;
    return switch (reason) {
      shared.SessionTurnUnavailable.busy => port.state.compacting
          ? builtin.SessionTurnActionUnavailable.compacting
          : builtin.SessionTurnActionUnavailable.busy,
      shared.SessionTurnUnavailable.revertStaged =>
        builtin.SessionTurnActionUnavailable.revertStaged,
      shared.SessionTurnUnavailable.targetUnknown =>
        action == builtin.SessionTurnAction.undo
            ? builtin.SessionTurnActionUnavailable.nothingToUndo
            : builtin.SessionTurnActionUnavailable.nothingToRedo,
      shared.SessionTurnUnavailable.noRevert ||
      shared.SessionTurnUnavailable.historyIncomplete =>
        builtin.SessionTurnActionUnavailable.nothingToRedo,
      _ => builtin.SessionTurnActionUnavailable.busy,
    };
  }

  @override
  Future<void> run(builtin.SessionTurnAction action) async {
    switch (action) {
      case builtin.SessionTurnAction.undo:
        await undoLast();
      case builtin.SessionTurnAction.redo:
        await redoNext();
      case builtin.SessionTurnAction.compact:
        await compact();
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    live.draft.removeListener(_onDraftChanged);
    super.dispose();
  }
}
