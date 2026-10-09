import 'package:codewalk_core/codewalk_core.dart';

class FakePairing implements EndpointPairing {
  int calls = 0;
  PairingResult reply = PairingResult(
    PairingStatus.ready,
    credential: EndpointCredential(
      kind: EndpointAuthKind.paired,
      secret: 'fake-test-paired',
    ),
    assessment: const EndpointAssessment(
      EndpointStatus.compatible,
      version: '2.0.22',
    ),
  );
  Future<PairingResult>? pending;
  @override
  PairingCandidate? parse(String input) =>
      {'fake-test-link', 'fake-test-link-b'}.contains(input)
      ? PairingCandidate(
          endpoint: Uri.parse('http://127.0.0.1:4096/'),
          challenge: input == 'fake-test-link'
              ? 'fake-test-code'
              : 'fake-test-code-b',
        )
      : null;
  @override
  PairingTask redeem(PairingCandidate candidate) {
    calls++;
    return _Task(pending ?? Future.value(reply));
  }

  @override
  PairingTask renew(Uri endpoint, EndpointCredential credential) {
    calls++;
    return _Task(pending ?? Future.value(reply));
  }
}

class _Task implements PairingTask {
  _Task(this.result);
  @override
  final Future<PairingResult> result;
  @override
  void cancel() {}
}

class FakeQrInput implements QrInput {
  @override
  bool get cameraAvailable => false;
  @override
  QrInputTask image() => _QrTask();
  @override
  QrInputTask camera() => _QrTask();
}

class _QrTask implements QrInputTask {
  @override
  Future<String?> get result => Future.value('fake-test-link');
  @override
  void cancel() {}
}
