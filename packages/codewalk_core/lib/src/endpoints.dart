enum EndpointStatus {
  compatible,
  untested,
  belowMinimum,
  legacyServer,
  authenticationRequired,
  serviceStarting,
  serviceStopping,
  serviceFailed,
  serviceUnavailable,
  unrecognized,
  unreachable,
  cancelled,
  unsupportedPlatform,
}

final class EndpointAssessment {
  const EndpointAssessment(
    this.status, {
    this.version,
    this.retryAt,
    this.retryDeferred = false,
  });
  final EndpointStatus status;
  final String? version;
  final DateTime? retryAt;
  final bool retryDeferred;
  bool get canUse =>
      status == EndpointStatus.compatible || status == EndpointStatus.untested;
}

/// No credential, native DTO, server-published URL, or port rewrite is stored.
final class EndpointProfile {
  EndpointProfile({
    required this.id,
    required this.label,
    required Uri endpoint,
  }) : endpoint = validateEndpoint(endpoint) {
    if (!RegExp(r'^[A-Za-z0-9_-]{8,64}$').hasMatch(id) ||
        label.trim().isEmpty ||
        label.length > 160 ||
        label.runes.any((c) => c < 32 || c == 127)) {
      throw const FormatException('Invalid profile identity or label.');
    }
  }
  final String id;
  final String label;
  final Uri endpoint;

  static Uri validateEndpoint(Uri uri) {
    if (!{'http', 'https'}.contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.port <= 0 ||
        uri.port > 65535 ||
        uri.toString().length > 2048) {
      throw const FormatException('Invalid endpoint.');
    }
    for (final part in uri.pathSegments) {
      var value = part;
      for (var depth = 0; depth < 16; depth++) {
        if (value.split(RegExp(r'[/\\]')).any((p) => p == '.' || p == '..')) {
          throw const FormatException('Invalid endpoint path.');
        }
        if (!RegExp(r'%[0-9a-fA-F]{2}').hasMatch(value)) break;
        value = Uri.decodeComponent(value);
        if (depth == 15) throw const FormatException('Invalid endpoint path.');
      }
    }
    return uri.replace(
      path: uri.path.endsWith('/') ? uri.path : '${uri.path}/',
    );
  }
}

abstract interface class EndpointProbeTask {
  Future<EndpointAssessment> get result;
  void cancel();
}

abstract interface class EndpointProber {
  EndpointProbeTask start(Uri endpoint, String secret);
}

abstract interface class EndpointProfileRepository {
  Future<List<EndpointProfile>> load();
  Future<void> save(EndpointProfile profile, String secret);
  Future<String?> readSecret(EndpointProfile profile);
  Future<void> remove(EndpointProfile profile);
}
