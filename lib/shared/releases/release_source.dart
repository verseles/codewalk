enum ReleaseSourceFailure { unavailable, cancelled, timeout, invalidResponse }

final class ReleaseSourceResult {
  const ReleaseSourceResult.success(String value)
    : body = value,
      failure = null;
  const ReleaseSourceResult.failure(ReleaseSourceFailure value)
    : body = null,
      failure = value;

  final String? body;
  final ReleaseSourceFailure? failure;
}

abstract interface class ReleaseSourceTask {
  Future<ReleaseSourceResult> get result;
  void cancel();
}

abstract interface class ReleaseSource {
  static const maxBodyBytes = 256 * 1024;
  static const url =
      'https://raw.githubusercontent.com/verseles/codewalk/main/CHANGELOG.md';
  static const updatePageSize = 100;
  static const updatePageLimit = 10;
  static const updatesPath =
      '/repos/verseles/codewalk/releases?per_page=$updatePageSize';
  static const maxUpdatePageBytes = 2 * 1024 * 1024;
  static const maxUpdatesBytes = 8 * 1024 * 1024;
  ReleaseSourceTask start();
  void close();
}
