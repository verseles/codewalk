import 'package:codewalk_core/codewalk_core.dart';

EndpointProber createEndpointProber() => _UnsupportedProber();

final class _UnsupportedProber implements EndpointProber {
  @override
  EndpointProbeTask start(Uri endpoint, String secret) => _UnsupportedTask();
}

final class _UnsupportedTask implements EndpointProbeTask {
  @override
  Future<EndpointAssessment> get result => Future.value(
    const EndpointAssessment(EndpointStatus.unsupportedPlatform),
  );
  @override
  void cancel() {}
}
