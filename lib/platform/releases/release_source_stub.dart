import '../../shared/releases/release_source.dart';
import '../../shared/releases/update_selector.dart';

ReleaseSource createReleaseSource() => _UnsupportedSource();

ReleaseSource createUpdateSource() => _UnsupportedSource();

UpdateTarget? currentUpdateTarget() => null;

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
