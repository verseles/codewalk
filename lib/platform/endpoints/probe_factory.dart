import 'package:codewalk_core/codewalk_core.dart';

import 'probe_factory_stub.dart'
    if (dart.library.io) 'probe_factory_io.dart'
    as implementation;

EndpointProber createEndpointProber() => implementation.createEndpointProber();
