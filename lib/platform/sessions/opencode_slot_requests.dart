import 'dart:async';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:codewalk_net/codewalk_net_io.dart';

import '../../shared/sessions/session_permission_reply.dart';
import '../../shared/sessions/session_stop.dart';
import '../../shared/sessions/session_unrestricted.dart';

/// Internal per-session in-flight request records owned by
/// [OpenCodeProfileSlot].
final class OpenCodeStopRequest {
  final cancellation = RequestCancellation();
  bool inFlight = true;
  bool settled = false;
  Timer? timer;
  SessionStopState state = const SessionStopState(
    phase: SessionStopPhase.requesting,
  );

  void dispose() {
    timer?.cancel();
    cancellation.cancel();
  }
}

final class OpenCodeUnrestrictedEntry {
  final cancellation = RequestCancellation();
  bool needsRead = true;

  /// The slot's epoch when the operation in flight started.
  int epoch = 0;

  /// The current live period already retried a failed automatic read.
  bool retried = false;
  SessionUnrestrictedState state = const SessionUnrestrictedState();

  void dispose() => cancellation.cancel();
}

final class OpenCodeReplyRequest {
  OpenCodeReplyRequest(this.session);

  final SessionRef session;
  final cancellation = RequestCancellation();
  bool inFlight = true;
  Timer? timer;
  SessionPermissionReplyState state = const SessionPermissionReplyState(
    phase: SessionPermissionReplyPhase.requesting,
  );

  void dispose() {
    timer?.cancel();
    cancellation.cancel();
  }
}
