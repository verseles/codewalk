import 'package:codewalk_core/codewalk_core.dart';

/// What one read observed about the sessions' activity on an endpoint.
///
/// Each part is null when it was not observed: the read failed, the platform
/// has no read, or nothing was asked. A null part is unknown, never "none".
final class SessionActivity {
  const SessionActivity({this.running, this.directory, this.waiting});

  /// The sessions the endpoint runs now.
  final Set<SessionRef>? running;

  /// The location whose pending permission requests and forms were read.
  final String? directory;

  /// The sessions of [directory] that wait for the user.
  final Set<SessionRef>? waiting;
}

/// A mark of one session row, each from its own observed source.
enum SessionActivityMark {
  /// A permission request or form of the session waits for the user.
  needsYou,

  /// The endpoint runs the session now.
  running,

  /// The session went idle and the endpoint did not see that viewed yet.
  unread,
}
