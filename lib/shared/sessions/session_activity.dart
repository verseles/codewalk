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

  /// Whether the read pending lists of [row]'s own location list it.
  bool waits(SessionSummary row) {
    final location = row.info.project?.canonicalDirectory;
    return location != null &&
        location == directory &&
        (waiting?.contains(row.info.ref) ?? false);
  }

  /// Whether the endpoint runs [row] now.
  bool runs(SessionSummary row) => running?.contains(row.info.ref) ?? false;

  /// Whether [row] runs or waits for the user, or null while a part that
  /// would say so was not observed: an unknown activity is not idle.
  bool? busy(SessionSummary row) {
    final waitingKnown =
        row.info.project?.canonicalDirectory == directory && waiting != null;
    if (runs(row) || (waitingKnown && waiting!.contains(row.info.ref))) {
      return true;
    }
    return running != null && waitingKnown ? false : null;
  }
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
