import '../../shared/releases/release_source.dart';

ReleaseSource createReleaseSource() => _UnsupportedSource();

final class _UnsupportedSource implements ReleaseSource {
  @override
  ReleaseSourceTask start() => _UnsupportedTask();
  @override
  void close() {}
}

final class _UnsupportedTask implements ReleaseSourceTask {
  @override
  Future<ReleaseSourceResult> get result => Future.value(
    const ReleaseSourceResult.failure(ReleaseSourceFailure.unavailable),
  );
  @override
  void cancel() {}
}
