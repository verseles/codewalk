import 'package:codewalk_core/codewalk_core.dart';
import 'package:codewalk_net/codewalk_net_io.dart';
import 'package:harness_opencode/harness_opencode.dart';

EndpointProber createEndpointProber() => _NativeProber();

final class _NativeProber implements EndpointProber {
  @override
  EndpointProbeTask start(Uri endpoint, String secret) =>
      _NativeTask(endpoint, secret);
}

final class _NativeTask implements EndpointProbeTask {
  _NativeTask(Uri endpoint, String secret) {
    _transport = IoEndpointHttpTransport(
      endpoint: endpoint,
      headers: basicEndpointHeaders(
        endpoint: endpoint,
        username: 'opencode',
        secret: () => secret,
      ),
    );
    result = _detect();
  }
  late final IoEndpointHttpTransport _transport;
  final _cancellation = RequestCancellation();
  @override
  late final Future<EndpointAssessment> result;
  Future<EndpointAssessment> _detect() async {
    try {
      return await OpenCodeEndpointProbe(
        _transport,
      ).detect(cancellation: _cancellation);
    } finally {
      _transport.close();
    }
  }

  @override
  void cancel() => _cancellation.cancel();
}
