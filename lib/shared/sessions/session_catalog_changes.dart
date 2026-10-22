import 'package:codewalk_core/codewalk_core.dart';

/// The session lifecycle feed of one OpenCode endpoint.
///
/// The endpoint keeps exactly one event stream open, and the feed is shared
/// with the live sessions of that endpoint: acquiring it never opens a second
/// subscription. The signal carries no session id, title, location or
/// payload, because the catalog re-reads the authoritative list instead of
/// patching a row.
abstract interface class SessionCatalogChanges {
  /// The observed lifecycle changes and the feed's transport state.
  Stream<SessionCatalogSignal> get signals;

  /// Releases the feed. The endpoint's stream stays open while a live session
  /// or another feed still needs it.
  void close();
}

/// What the feed reports.
sealed class SessionCatalogSignal {
  const SessionCatalogSignal();
}

/// A session lifecycle change: created, forked, renamed, deleted or moved. The
/// kind never travels with it.
final class SessionCatalogChanged extends SessionCatalogSignal {
  const SessionCatalogChanged();
}

/// A change of what the endpoint reports about the sessions' activity: a
/// session started running, or a permission request or form was asked or
/// answered. The list itself did not change, so only the activity is re-read.
final class SessionActivityChanged extends SessionCatalogSignal {
  const SessionActivityChanged();
}

/// The feed's transport state: the endpoint's stream is connected, or it is
/// not. A reconnect is not continuity: the catalog re-reads the list.
final class SessionCatalogConnection extends SessionCatalogSignal {
  const SessionCatalogConnection(this.connected);
  final bool connected;
}

/// Acquires the lifecycle feed of one selected profile.
typedef SessionCatalogChangesFactory =
    Future<SessionCatalogChanges> Function(
      EndpointProfile profile,
      EndpointCredential credential,
    );
