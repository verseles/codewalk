import 'endpoints.dart';

enum EndpointAuthKind { password, paired }

/// Secret-bearing values never stringify their credential material.
final class EndpointCredential {
  EndpointCredential({
    required this.kind,
    required this.secret,
    DateTime? expiresAt,
  }) : expiresAt = expiresAt?.toUtc() {
    if (secret.isEmpty ||
        secret.length > 16384 ||
        secret.runes.any((c) => c < 32 || c == 127) ||
        (kind == EndpointAuthKind.password && expiresAt != null)) {
      throw const FormatException('Invalid endpoint credential.');
    }
  }
  final EndpointAuthKind kind;
  final String secret;
  final DateTime? expiresAt;
  bool matches(EndpointCredential? other) =>
      other != null &&
      kind == other.kind &&
      secret == other.secret &&
      expiresAt == other.expiresAt;
  @override
  String toString() => 'EndpointCredential(${kind.name}, redacted)';
}

/// The challenge is opaque here; its wire syntax belongs to the adapter.
final class PairingCandidate {
  PairingCandidate({required Uri endpoint, required this.challenge})
    : endpoint = EndpointProfile.validateEndpoint(endpoint) {
    if (challenge.isEmpty || challenge.length > 128) {
      throw const FormatException('Invalid pairing challenge.');
    }
  }
  final Uri endpoint;
  final String challenge;
  @override
  String toString() => 'PairingCandidate(redacted)';
}

enum PairingStatus {
  ready,
  rejected,
  invalidInput,
  verificationFailed,
  renewalUnavailable,
  unreachable,
  uncertain,
  cancelled,
  unsupportedPlatform,
}

final class PairingResult {
  const PairingResult(this.status, {this.credential, this.assessment});
  final PairingStatus status;
  // A received credential can be rechecked without consuming a challenge twice.
  final EndpointCredential? credential;
  final EndpointAssessment? assessment;
  bool get canSave =>
      status == PairingStatus.ready &&
      credential != null &&
      assessment?.canUse == true;
  @override
  String toString() => 'PairingResult(${status.name})';
}

abstract interface class PairingTask {
  Future<PairingResult> get result;
  void cancel();
}

abstract interface class EndpointPairing {
  PairingCandidate? parse(String input);
  PairingTask redeem(PairingCandidate candidate);
  PairingTask renew(Uri endpoint, EndpointCredential credential);
}

enum QrInputFailure { unavailable, unreadable, tooLarge, noCode, timedOut }

final class QrInputException implements Exception {
  const QrInputException(this.failure);
  final QrInputFailure failure;
  @override
  String toString() => 'QrInputException(${failure.name})';
}

abstract interface class QrInputTask {
  Future<String?> get result;
  void cancel();
}

abstract interface class QrInput {
  bool get cameraAvailable;
  QrInputTask image();
  QrInputTask camera();
}
