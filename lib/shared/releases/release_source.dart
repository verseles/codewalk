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
  ReleaseSourceTask start();
  void close();
}
