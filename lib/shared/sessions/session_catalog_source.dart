import 'package:codewalk_core/codewalk_core.dart';

import 'session_activity.dart';

typedef SessionCatalogFactory =
    SessionCatalogSource Function(
      EndpointProfile profile,
      EndpointCredential credential,
    );

enum SessionCatalogFailure {
  authenticationRequired,
  unavailable,
  rateLimited,
  timeout,
  incompatibleResponse,
  invalidCursor,
  cancelled,
  unsupportedPlatform,
  connection,

  /// The server holds no session under the read identity.
  notFound,
}

final class SessionCatalogException implements Exception {
  const SessionCatalogException(this.failure);
  final SessionCatalogFailure failure;
  @override
  String toString() => failure.name;
}

abstract interface class SessionCatalogSource {
  HarnessRef get harness;
  SessionCatalogTask list(SessionQuery query);

  /// Reads one session of this server, for a link to a session outside the
  /// loaded rows.
  SessionReadTask read(SessionRef ref);

  /// Reads which sessions run now and, for [directory], which wait for the
  /// user. It never throws: a part that could not be read is unknown.
  Future<SessionActivity> activity({String? directory});

  /// The directories of the projects this server knows.
  SessionCatalogRead<List<ProjectRef>> projects();

  /// Resolves [directory], or the server's default location when it is null,
  /// to the directory the server keys it by.
  SessionCatalogRead<ProjectRef> location({String? directory});

  /// The entries of [path] in [directory]'s location; [path] is absolute or
  /// relative to [directory], and every entry path stays relative to it.
  SessionCatalogRead<List<FileEntry>> listDirectory(
    String directory, {
    String? path,
  });

  /// The directories in [directory]'s location that match [query].
  SessionCatalogRead<List<FileEntry>> findDirectories(
    String directory,
    String query,
  );

  /// The server's default agent and model for [directory]'s location, shown on
  /// a draft that has no session yet. Each part is null when the server has
  /// none or its read failed.
  Future<DraftDefaults> draftDefaults({required String directory});
  void close();
}

/// The server's defaults for a draft, and what can be picked before its
/// first send creates the session.
final class DraftDefaults {
  const DraftDefaults({
    this.agent,
    this.model,
    this.selection,
    this.agents = const [],
    this.models = const [],
    this.agentModels = const {},
    this.providers = const {},
  });

  /// The agent's display name, or its id when the location does not name it.
  final String? agent;

  /// The model's name, or its model id.
  final String? model;

  /// Verified identities to apply when the first send creates the session.
  final Selection? selection;

  /// The agents and models the location offers; empty when their read failed.
  final List<CatalogEntry> agents;
  final List<ModelEntry> models;

  /// Each offered agent's own model, by agent id, when it names one the
  /// location offers; its variant only when that model lists it.
  final Map<String, Selection> agentModels;

  /// Provider display names by provider id; empty when their read failed.
  final Map<String, String> providers;

  bool get isEmpty => agent == null && model == null;
}

/// One cancellable read of what the server offers to open.
abstract interface class SessionCatalogRead<T> {
  Future<T> get result;
  void cancel();
}

abstract interface class SessionCatalogTask {
  Future<Page<SessionSummary>> get result;
  void cancel();
}

abstract interface class SessionReadTask {
  Future<SessionSummary> get result;
  void cancel();
}
