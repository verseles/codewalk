import 'package:codewalk_core/codewalk_core.dart';

EndpointPairing createEndpointPairing() => _Unavailable();

final class _Unavailable implements EndpointPairing {
  @override
  PairingCandidate? parse(String input) => null;
  @override
  PairingTask redeem(PairingCandidate candidate) => _Task();
  @override
  PairingTask renew(Uri endpoint, EndpointCredential credential) => _Task();
}

final class _Task implements PairingTask {
  @override
  Future<PairingResult> get result =>
      Future.value(const PairingResult(PairingStatus.unsupportedPlatform));
  @override
  void cancel() {}
}
