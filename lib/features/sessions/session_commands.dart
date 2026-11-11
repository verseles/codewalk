import 'package:codewalk_core/codewalk_core.dart';

import '../../shared/sessions/session_actions.dart';

/// The session commands of the list: the endpoint's own commands, the local
/// hide and what they leave behind for the list to show.
///
/// The list decides whether its rows are current, and is asked right before
/// each send. A row is never patched: the effect of a command is observed by
/// the list's authoritative re-read.
class SessionCommands {
  SessionCommands({required this.notify, required this.changed});

  /// Tells the list's listeners that the command state changed.
  final void Function() notify;

  /// Arms the list's authoritative re-read after a command that may have
  /// been applied.
  final void Function() changed;

  static const _unobserved = SessionActionSupport(
    SessionActionReason.versionUnverified,
  );

  /// The commands of the selected server's endpoint, or null.
  SessionActionSource? source;

  /// The endpoint's support for the session actions.
  SessionActionSupport support = _unobserved;

  /// The outcome of the last command that did not go through, so the list can
  /// say so instead of closing the interaction silently.
  SessionActionOutcome? failure;

  /// A command whose answer was lost is waiting for its reconciliation.
  bool uncertain = false;

  /// A create is in flight.
  bool creating = false;

  final _pending = <SessionRef>{};

  /// Whether a command for this row is in flight.
  bool pending(SessionRef ref) => _pending.contains(ref);

  /// Releases the endpoint's commands; the next endpoint is not observed yet.
  void close() {
    source?.close();
    source = null;
    support = _unobserved;
  }

  /// Forgets what the last commands left for the list to show.
  void clear() {
    failure = null;
    uncertain = false;
  }

  /// Creates a session at the given canonical directory once [current]
  /// confirms the list's rows.
  ///
  /// The receipt is an admission: the new session reaches the list with the
  /// next authoritative read, and an uncertain create is reconciled there and
  /// never resent.
  Future<SessionCreateResult> create({
    required String directory,
    String? title,
    Selection? initialSelection,
    required bool Function() current,
  }) async {
    final source = this.source;
    if (source == null || creating) {
      return const SessionCreateResult(SessionActionOutcome.unavailable);
    }
    if (!current() || support.reason != SessionActionReason.none) {
      // Nothing was sent, so the list keeps no failure notice: the dialog
      // says why the create was refused and the user retries.
      return const SessionCreateResult(SessionActionOutcome.unavailable);
    }
    creating = true;
    failure = null;
    notify();
    try {
      final result = await source.create(
        directory: directory,
        title: title,
        initialSelection: initialSelection,
      );
      final outcome = result.outcome;
      if (!identical(source, this.source)) {
        // The profile changed while the create was in flight.
        return result;
      }
      if (outcome == SessionActionOutcome.accepted ||
          outcome == SessionActionOutcome.uncertain) {
        // The effect is observed by the authoritative re-read. An uncertain
        // create is reconciled there and never sent again.
        changed();
        if (outcome == SessionActionOutcome.uncertain) uncertain = true;
      } else {
        failure = outcome;
      }
      return result;
    } finally {
      creating = false;
      notify();
    }
  }

  /// Hides the row in CodeWalk, or shows it again.
  Future<bool> setHidden(SessionSummary row, {required bool hidden}) async {
    final source = this.source;
    if (source == null) return false;
    final written = await source.setHidden(row, hidden: hidden);
    if (!identical(source, this.source)) {
      // The profile changed while the local hide was in flight.
      return written;
    }
    failure = written ? null : SessionActionOutcome.unavailable;
    notify();
    return written;
  }

  /// Runs one command on [row] once [current] confirms the row and the
  /// list's rows. A [quiet] command was not asked for by the user, so a
  /// refusal or a failure leaves no notice.
  ///
  /// The row is never patched: the effect is observed by the quiet
  /// authoritative re-read, and a refused or uncertain command leaves the
  /// rows exactly as the endpoint last answered.
  Future<SessionActionOutcome> run(
    SessionSummary row,
    Future<SessionActionOutcome> Function(SessionActionSource source) command, {
    required bool Function() current,
    bool quiet = false,
  }) async {
    final source = this.source;
    if (source == null) return SessionActionOutcome.unavailable;
    if (_pending.contains(row.info.ref)) {
      return SessionActionOutcome.unavailable;
    }
    // The intent is validated again right before the send: the profile, the
    // credential, the endpoint's support, the currency of the rows and the
    // row's own membership can all have changed while a dialog was open.
    if (!current() || support.reason != SessionActionReason.none) {
      // The intent is no longer authorized, and the user asked for it: the
      // list says so instead of closing the interaction silently.
      if (!quiet) {
        failure = SessionActionOutcome.unavailable;
        notify();
      }
      return SessionActionOutcome.unavailable;
    }
    _pending.add(row.info.ref);
    if (!quiet) failure = null;
    notify();
    try {
      final outcome = await command(source);
      if (!identical(source, this.source)) {
        // The profile changed while the command was in flight: the result
        // belongs to the old profile and must not touch the new one.
        return outcome;
      }
      if (outcome == SessionActionOutcome.accepted ||
          outcome == SessionActionOutcome.uncertain) {
        // The effect is observed by the authoritative re-read. An uncertain
        // command is reconciled there, never replayed.
        changed();
      }
      if (quiet) return outcome;
      if (outcome == SessionActionOutcome.rejected ||
          outcome == SessionActionOutcome.unavailable) {
        failure = outcome;
      } else if (outcome == SessionActionOutcome.uncertain) {
        // The command may already have been applied: the re-read reconciles
        // it, and the list waits instead of calling it a failure.
        uncertain = true;
      }
      return outcome;
    } on ArgumentError {
      // A local refusal, such as a title over the bound.
      if (!quiet) failure = SessionActionOutcome.unavailable;
      return SessionActionOutcome.unavailable;
    } finally {
      _pending.remove(row.info.ref);
      notify();
    }
  }
}
