enum ReleaseSourceFailure {
  unavailable,
  cancelled,
  timeout,
  invalidResponse,
  rateLimited,
}

final class ReleaseSourceResult {
  const ReleaseSourceResult.success(String value)
    : body = value,
      failure = null,
      retryAt = null;
  const ReleaseSourceResult.failure(ReleaseSourceFailure value, {this.retryAt})
    : body = null,
      failure = value;

  final String? body;
  final ReleaseSourceFailure? failure;
  final DateTime? retryAt;
}

abstract interface class ReleaseSourceTask {
  Future<ReleaseSourceResult> get result;
  void cancel();
}

abstract interface class ReleaseSource {
  static const maxBodyBytes = 256 * 1024;
  static const url =
      'https://raw.githubusercontent.com/verseles/codewalk/main/CHANGELOG.md';
  static const updatePageSize = 20;
  // About 1,000 releases created since CodeWalk 2 began. The stop rule
  // usually ends the listing on the first page.
  static const updatePageLimit = 50;

  /// When `v2.0.0-beta.1`, the first CodeWalk 2 release, was created. GitHub
  /// lists releases newest first by creation, so no CodeWalk 2 release follows
  /// one created before this.
  static final v2FirstReleaseCreated = DateTime.utc(2026, 11, 4, 2, 36, 3);
  static const updatesPath =
      '/repos/verseles/codewalk/releases?per_page=$updatePageSize';
  static const maxUpdatePageBytes = 2 * 1024 * 1024;
  static const maxUpdatesBytes = 8 * 1024 * 1024;
  static const maxRetryDelay = Duration(days: 30);

  /// Starts a read. A paginated listing also stops at the page that holds
  /// the release tagged [until], when the caller already knows every older
  /// release. This relies on releases being created in version order, as the
  /// beta cut does: a newer version listed below [until], such as an older
  /// release recreated later, is not read.
  ReleaseSourceTask start({String? until});
  void close();
}
