import 'package:codewalk_core/codewalk_core.dart';
import 'package:codewalk_net/codewalk_net_io.dart';
import 'package:harness_opencode/harness_opencode.dart';

EndpointPairing createEndpointPairing() => OpenCodePairing(
  (endpoint, secret) => IoEndpointHttpTransport(
    endpoint: endpoint,
    headers: secret == null
        ? null
        : basicEndpointHeaders(
            endpoint: endpoint,
            username: 'opencode',
            secret: () => secret,
          ),
  ),
);
