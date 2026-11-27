import 'authentication.dart';

enum EndpointStatus {
  compatible,
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
  bool get canUse => status == EndpointStatus.compatible;
}

/// No credential, native DTO, server-published URL, or port rewrite is stored.
final class EndpointProfile {
  EndpointProfile({
    required this.id,
    required this.label,
    required Uri endpoint,
    this.bindingRevision = 0,
    this.harnessKind,
  }) : endpoint = validateEndpoint(endpoint) {
    if (!RegExp(r'^[A-Za-z0-9_-]{8,64}$').hasMatch(id) ||
        label.trim().isEmpty ||
        label.length > 160 ||
        label.runes.any((c) => c < 32 || c == 127) ||
        bindingRevision < 0 ||
        bindingRevision > maxBindingRevision ||
        (harnessKind != null && !isHarnessKind(harnessKind!))) {
      throw const FormatException('Invalid profile identity or label.');
    }
  }

  /// A stable harness key such as the adapter id; never a display name.
  static bool isHarnessKind(String value) =>
      RegExp(r'^[a-z][a-z0-9_-]{0,31}$').hasMatch(value);
  final String id;
  final String label;
  final Uri endpoint;
  static const maxBindingRevision = 0x7fffffff;

  /// Changes only when the saved endpoint URL changes, including A–B–A.
  final int bindingRevision;

  /// The harness chosen when the server was added, fixed for its lifetime
  /// and so not part of [sameBinding]. Null marks a profile saved before that
  /// choice existed; the app's
  /// `HarnessOptions.defaultKind` resolves it (#504).
  final String? harnessKind;

  bool sameBinding(EndpointProfile other) =>
      id == other.id &&
      endpoint == other.endpoint &&
      bindingRevision == other.bindingRevision;

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
  EndpointProbeTask start(
    Uri endpoint,
    String secret, {
    Duration? connectionTimeout,
  });
}

abstract interface class EndpointProfileRepository {
  Future<List<EndpointProfile>> load();
  Future<EndpointProfile> updateProfile(
    EndpointProfile expected, {
    required String label,
    required Uri endpoint,
  });
  Future<void> save(EndpointProfile profile, String secret);
  Future<String?> readSecret(EndpointProfile profile);
  Future<EndpointCredential?> readCredential(EndpointProfile profile);
  Future<void> saveCredential(
    EndpointProfile profile,
    EndpointCredential credential,
  );
  Future<void> replaceCredential(
    EndpointProfile profile,
    EndpointCredential credential, {
    required EndpointCredential? expected,
  });
  Future<void> remove(EndpointProfile profile);
}
