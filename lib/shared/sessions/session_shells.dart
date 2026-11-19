import 'package:codewalk_core/codewalk_core.dart';

import 'session_live_source.dart';

/// Harness-neutral cancellation token for bounded shell output reads.
final class SessionShellCancellation {
  bool _cancelled = false;
  final _listeners = <void Function()>[];

  bool get isCancelled => _cancelled;

  void onCancel(void Function() listener) {
    if (_cancelled) {
      listener();
      return;
    }
    _listeners.add(listener);
  }

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    final snapshot = List<void Function()>.of(_listeners);
    _listeners.clear();
    for (final listener in snapshot) {
      listener();
    }
  }
}

/// Finite outcome of a deliberate user Stop on a harness-observed shell.
enum SessionShellStopOutcome {
  accepted,
  notFound,
  rejected,
  uncertain,
  unavailable,
}

/// Optional harness-neutral shell port bound to one live session lease.
///
/// Harnesses without `shell.observe` / `shell.stop` either omit this port or
/// expose `canObserve == false` / `canStop == false` so the UI never fabricates
/// live shell rows, elapsed timers, output paging, or Stop controls.
abstract interface class SessionShellPort {
  /// Whether this harness supports observing live shells and paging output.
  bool get canObserve;

  /// Whether this harness supports terminating a running shell.
  bool get canStop;

  /// Whether a Stop request is currently in flight for [shellId].
  bool isStopping(String shellId);

  /// Requests one coalesced refresh of the session's running shells.
  Future<void> refresh();

  /// Pages combined output for [shellId], returning `null` if the shell no
  /// longer exists (404) or observation is unavailable.
  Future<ShellOutputPage?> readOutput(
    String shellId, {
    int? cursor,
    int limit = 16 * 1024,
    SessionShellCancellation? cancellation,
  });

  /// Sends one deliberate Stop request for [shellId], fenced single-flight.
  Future<SessionShellStopOutcome> stop(String shellId, {CommandId? id});
}

/// Optional capability on a [SessionLiveHandle].
abstract interface class SessionShellSource {
  SessionShellPort? get shells;
}

extension SessionLiveShells on SessionLiveHandle {
  SessionShellPort? get shells {
    final handle = this;
    return handle is SessionShellSource
        ? (handle as SessionShellSource).shells
        : null;
  }
}
