import 'dart:async';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/foundation.dart';

import '../../shared/sessions/command_ids.dart';
import '../../shared/sessions/prompt_outbox.dart';
import '../../shared/sessions/server_path.dart';
import '../../shared/sessions/session_live_source.dart';
import '../../shared/sessions/session_turn_actions.dart';
import '../../shared/sessions/session_visibility.dart';
import 'session_list_projection.dart';

/// What a message forwards (#542): the text of a sent prompt or of a whole
/// answer, as Copy all copies it; null when there is nothing whole to send.
String? forwardableText(TimelineItem item) => switch (item) {
  UserInput(:final text, :final confirmed)
      when confirmed && text.trim().isNotEmpty =>
    text,
  AssistantText(:final text, :final complete, :final prefixMissing)
      when complete && !prefixMissing && text.trim().isNotEmpty =>
    text,
  _ => null,
};

/// Where a forwarded message came from: `project / title`, or the title
/// alone outside a project.
String forwardOrigin(SessionSummary source, {required String untitled}) {
  final title = source.info.title.trim().isEmpty
      ? untitled
      : source.info.title.trim().replaceAll(RegExp(r'\s+'), ' ');
  final directory = source.info.project?.canonicalDirectory;
  return directory == null ? title : '${serverPathName(directory)} / $title';
}

/// The prompt a target receives: [provenance] on its own line, a blank
/// line, then the message as written.
String forwardedText({required String provenance, required String text}) =>
    '$provenance\n\n$text';

/// One open project's conversations a message can go to.
final class ForwardGroup {
  const ForwardGroup({required this.directory, required this.rows});
  final String directory;

  /// Null while the project's conversations are still being read.
  final List<SessionSummary>? rows;
}

/// Whether [row] can receive a forward from [source]: another top-level,
/// unarchived conversation of the same server.
bool forwardTargetAllowed(SessionSummary row, SessionRef source) =>
    row.info.ref != source &&
    row.info.ref.host == source.host &&
    row.archivedAt == null &&
    isPrimarySummary(row);

/// The targets of a forward from [source], one group per open project in
/// [directories] order: its [perProject] most recent conversations that
/// match [query] in their title or project name.
List<ForwardGroup> forwardTargetGroups({
  required List<String> directories,
  required List<SessionSummary>? Function(String directory) rowsOf,
  required SessionRef source,
  String query = '',
  int perProject = 20,
}) {
  final needle = query.trim().toLowerCase();
  return [
    for (final directory in directories)
      () {
        final rows = rowsOf(directory);
        if (rows == null) return ForwardGroup(directory: directory, rows: null);
        final project = serverPathName(directory).toLowerCase();
        return ForwardGroup(
          directory: directory,
          rows: sortSessionsByRecent([
            for (final row in rows)
              if (forwardTargetAllowed(row, source) &&
                  (needle.isEmpty ||
                      project.contains(needle) ||
                      row.info.title.toLowerCase().contains(needle)))
                row,
          ]).take(perProject).toList(),
        );
      }(),
  ];
}

/// Where one target of a forward stands.
enum ForwardStatus {
  pending,
  sending,
  queued,
  sent,
  unconfirmed,
  failed,
  stopped,
}

/// Why a target was not sent to.
enum ForwardMiss { offline, gone, busy, capacity, unavailable, refused }

final class ForwardTarget {
  ForwardTarget(this.row);
  final SessionSummary row;
  ForwardStatus status = ForwardStatus.pending;
  ForwardMiss? miss;
  SessionRef get ref => row.info.ref;

  /// Received, waiting in its queue or already delivered.
  bool get done =>
      status == ForwardStatus.queued || status == ForwardStatus.sent;
}

/// Sends one message to several conversations, one at a time (#542).
///
/// Each target gets a lease of its own for a moment, never its composer or
/// draft: once it is live and nothing holds its sends (a model change, a
/// stop, a staged undo, which a prompt would commit), the outbox records the
/// prompt and queues it, so a running turn is not steered. A target whose
/// delivery is not confirmed is never sent to again here; its conversation
/// checks it. Retry sends again only to targets that were never sent to.
class MessageForwardRun extends ChangeNotifier {
  MessageForwardRun({
    required this.text,
    required List<SessionSummary> targets,
    required this.open,
    required this.available,
    this.confirm,
    this.offline,
    this.readyTimeout = const Duration(seconds: 20),
  }) : targets = [for (final row in targets) ForwardTarget(row)];

  final String text;
  final List<ForwardTarget> targets;

  /// Opens a lease of the target session.
  final Future<SessionLiveHandle> Function(SessionRef session) open;

  /// Whether the target is still listed and not archived.
  final bool Function(SessionRef session) available;

  /// Reads the target again from its server right before the post: false
  /// when it was archived or deleted meanwhile; throws when it cannot tell.
  /// The read may end once [ended] completes: the run no longer waits.
  final Future<bool> Function(SessionRef session, Future<void> ended)? confirm;

  /// Whether the server is known to be offline now.
  final bool Function()? offline;
  final Duration readyTimeout;

  bool _running = false;
  bool _stopped = false;
  bool _detached = false;

  /// Completes on Stop, ending at once the wait for the target in progress.
  Completer<void> _halt = Completer<void>();

  bool get running => _running;
  bool get stopped => _stopped;
  int get done => targets.where((target) => target.done).length;
  bool get allDone => targets.every((target) => target.done);
  bool get anyFailed =>
      targets.any((target) => target.status == ForwardStatus.failed);

  /// Sends to every target not yet tried.
  Future<void> run() async {
    if (_running) return;
    _running = true;
    _stopped = false;
    _halt = Completer<void>();
    _notify();
    try {
      for (final target in targets) {
        if (target.status != ForwardStatus.pending) continue;
        if (_stopped) {
          target.status = ForwardStatus.stopped;
          continue;
        }
        await _deliver(target);
        _notify();
      }
    } finally {
      _running = false;
      _notify();
    }
  }

  /// Sends again to the targets that were never sent to.
  Future<void> retryFailed() {
    for (final target in targets) {
      if (target.status == ForwardStatus.failed ||
          target.status == ForwardStatus.stopped) {
        target
          ..status = ForwardStatus.pending
          ..miss = null;
      }
    }
    return run();
  }

  /// No target starts after this; one already posting ends as it does.
  void stop() {
    _stopped = true;
    if (!_halt.isCompleted) _halt.complete();
    _notify();
  }

  /// The dialog went: nothing more starts, and nothing is reported.
  void detach() {
    _detached = true;
    stop();
  }

  void _notify() {
    if (!_detached) notifyListeners();
  }

  void _fail(ForwardTarget target, ForwardMiss miss) {
    target
      ..status = ForwardStatus.failed
      ..miss = miss;
  }

  Future<void> _deliver(ForwardTarget target) async {
    if (offline?.call() ?? false) return _fail(target, ForwardMiss.offline);
    if (!available(target.ref)) return _fail(target, ForwardMiss.gone);
    target.status = ForwardStatus.sending;
    _notify();
    SessionLiveHandle? lease;
    try {
      final opening = open(target.ref);
      final halted = _halt.future;
      try {
        lease = await Future.any<SessionLiveHandle?>([
          opening,
          halted.then((_) => null),
        ]).timeout(readyTimeout);
      } on TimeoutException {
        // A lease that arrives late is closed at once.
        unawaited(opening.then((late) => late.close(), onError: (Object _) {}));
        rethrow;
      }
      if (lease == null) {
        // Stopped while it opened.
        unawaited(opening.then((late) => late.close(), onError: (Object _) {}));
        target.status = ForwardStatus.stopped;
        return;
      }
      if (_stopped) {
        target.status = ForwardStatus.stopped;
        return;
      }
      final miss = await _ready(lease);
      if (_stopped) {
        target.status = ForwardStatus.stopped;
        return;
      }
      if (miss != null) return _fail(target, miss);
      final confirm = this.confirm;
      if (confirm != null) {
        // The list learns of an archive a moment after the server.
        final bool? listed;
        final ended = Completer<void>();
        try {
          listed = await Future.any<bool?>([
            confirm(target.ref, ended.future),
            _halt.future.then((_) => null),
          ]).timeout(readyTimeout);
        } on Object {
          return _fail(target, ForwardMiss.unavailable);
        } finally {
          ended.complete();
        }
        if (_stopped || listed == null) {
          target.status = ForwardStatus.stopped;
          return;
        }
        if (!listed) return _fail(target, ForwardMiss.gone);
      }
      final opened = lease;
      final outbox = opened.outbox;
      if (outbox == null) return _fail(target, ForwardMiss.unavailable);
      final OutboxSubmission submission;
      try {
        submission = await outbox.submit(
          session: target.ref,
          commandId: mintCommandId(),
          draft: PromptDraft(text: text),
          delivery: Delivery.queue,
          // Checked again right before the post: a stop, a staged undo, a
          // hold (a model change, a stop of its turn) or an archive meanwhile
          // keeps the prompt from going.
          isCurrent: () =>
              !_stopped &&
              opened.current.phase == SessionLivePhase.live &&
              !opened.current.stale &&
              !(opened.turnActions?.state.staged ?? false) &&
              !_holds(opened) &&
              available(target.ref),
        );
      } on Object {
        // Thrown while the post was under way, whatever the error: it may
        // have gone, so it is never sent again from here.
        target.status = ForwardStatus.unconfirmed;
        return;
      }
      final entry = submission.entry;
      if (entry == null) {
        if (submission.refusal == 'cancelledBeforeSend') {
          if (_stopped) {
            target.status = ForwardStatus.stopped;
            return;
          }
          return _fail(target, ForwardMiss.busy);
        }
        return _fail(
          target,
          submission.refusal == 'full'
              ? ForwardMiss.capacity
              : ForwardMiss.refused,
        );
      }
      switch (entry.state) {
        case SubmissionKind.admitted:
          target.status = ForwardStatus.queued;
        case SubmissionKind.delivered || SubmissionKind.settled:
          target.status = ForwardStatus.sent;
        case SubmissionKind.rejected || SubmissionKind.cancelled:
          // Never posted: the conversation keeps no trace of it.
          await outbox.dismiss(target.ref, entry.commandId);
          if (_stopped && entry.reason == 'cancelledBeforeSend') {
            target.status = ForwardStatus.stopped;
          } else if (entry.reason == 'cancelledBeforeSend') {
            _fail(target, ForwardMiss.busy);
          } else {
            _fail(target, ForwardMiss.refused);
          }
        default:
          // Posted with no answer: its conversation checks it; it is never
          // sent again from here.
          target.status = ForwardStatus.unconfirmed;
      }
    } on SessionLiveException catch (error) {
      _fail(
        target,
        error.failure == SessionLiveFailure.capacity
            ? ForwardMiss.capacity
            : error.failure == SessionLiveFailure.notFound
            ? ForwardMiss.gone
            : ForwardMiss.unavailable,
      );
    } on TimeoutException {
      if (_stopped) {
        target.status = ForwardStatus.stopped;
      } else {
        _fail(target, ForwardMiss.busy);
      }
    } on Object {
      // Anything else, before the post: never sent.
      _fail(target, ForwardMiss.unavailable);
    } finally {
      lease?.close();
    }
  }

  /// Whether something holds [lease]'s sends: a model or agent change, a
  /// stop of its turn, a turn action under way.
  static bool _holds(SessionLiveHandle lease) =>
      lease.stopState.busy ||
      lease.selectionState.holdsSend ||
      (lease.turnActions?.state.holdsSend ?? false);

  /// Waits until [lease] can take a prompt; the reason it cannot otherwise.
  Future<ForwardMiss?> _ready(SessionLiveHandle lease) async {
    ForwardMiss? check(SessionLiveView view) {
      switch (view.phase) {
        case SessionLivePhase.evicted || SessionLivePhase.closed:
          return ForwardMiss.gone;
        case SessionLivePhase.authRequired || SessionLivePhase.incompatible:
          return ForwardMiss.unavailable;
        default:
          break;
      }
      if (view.phase != SessionLivePhase.live || view.stale) return null;
      if (lease.outbox == null) return ForwardMiss.unavailable;
      final turn = lease.turnActions?.state;
      // A staged undo would be made permanent by a prompt.
      if (turn?.staged ?? false) return ForwardMiss.busy;
      return null;
    }

    bool ready(SessionLiveView view) =>
        view.phase == SessionLivePhase.live &&
        !view.stale &&
        lease.outbox != null &&
        !_holds(lease);

    final first = lease.current;
    final missNow = check(first);
    if (missNow != null) return missNow;
    if (ready(first)) return null;
    final result = Completer<ForwardMiss?>();
    // A stop ends the wait; the caller tells it apart.
    unawaited(
      _halt.future.then((_) {
        if (!result.isCompleted) result.complete(ForwardMiss.busy);
      }),
    );
    final subscription = lease.updates.listen((view) {
      if (result.isCompleted) return;
      final miss = check(view);
      if (miss != null) {
        result.complete(miss);
      } else if (ready(view)) {
        result.complete(null);
      }
    });
    try {
      return await result.future.timeout(
        readyTimeout,
        onTimeout: () => ForwardMiss.busy,
      );
    } finally {
      await subscription.cancel();
    }
  }

  @override
  void dispose() {
    _detached = true;
    _stopped = true;
    super.dispose();
  }
}
