import 'dart:async';

import 'package:codewalk/features/hosts/hosts_controller.dart';
import 'package:codewalk/features/pairing/pairing_controller.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter_test/flutter_test.dart';

import '../hosts/fakes.dart';
import '../hosts/hosts_controller_test.dart' show GatedProber;
import 'fakes.dart';

class _DelayedReplacement extends MemoryProfiles {
  final started = Completer<void>();
  final release = Completer<void>();
  @override
  Future<void> replaceCredential(
    EndpointProfile profile,
    EndpointCredential credential, {
    required EndpointCredential? expected,
  }) async {
    if (!started.isCompleted) started.complete();
    await release.future;
    await super.replaceCredential(profile, credential, expected: expected);
  }
}

void main() {
  late MemoryProfiles repo;
  late HostsController hosts;
  late FakePairing adapter;
  late PairingController controller;
  setUp(() {
    repo = MemoryProfiles();
    hosts = HostsController(repository: repo, prober: FakeProber());
    adapter = FakePairing();
    controller = PairingController(
      pairing: adapter,
      hosts: hosts,
      qr: FakeQrInput(),
    );
  });
  tearDown(() {
    controller.dispose();
    hosts.dispose();
  });

  test(
    'new confirmed link survives the completion of an already-started write',
    () async {
      final delayed = _DelayedReplacement();
      final profile = EndpointProfile(
        id: 'endpoint_one',
        label: 'Existing',
        endpoint: Uri.parse('http://127.0.0.1:4096/'),
      );
      await delayed.save(profile, 'fake-old');
      final localHosts = HostsController(
        repository: delayed,
        prober: FakeProber(),
      );
      final localAdapter = FakePairing();
      final local = PairingController(
        pairing: localAdapter,
        hosts: localHosts,
        qr: FakeQrInput(),
      );
      addTearDown(() {
        local.dispose();
        localHosts.dispose();
      });
      local.input('fake-test-link', profile: profile);
      await local.confirm();
      final oldSave = local.save('ignored');
      await delayed.started.future;
      localAdapter.reply = PairingResult(
        PairingStatus.ready,
        credential: EndpointCredential(
          kind: EndpointAuthKind.paired,
          secret: 'fake-new-b',
        ),
        assessment: const EndpointAssessment(
          EndpointStatus.compatible,
          version: '2.0.22',
        ),
      );
      local.input('fake-test-link-b', profile: profile);
      await local.confirm();
      final currentReceipt = local.receipt;
      delayed.release.complete();
      expect(await oldSave, isFalse);
      expect(local.receipt, same(currentReceipt));
      expect(local.candidate!.challenge, 'fake-test-code-b');
      expect(local.storageError, isFalse);
      expect(await local.save('ignored'), isTrue);
      expect(await delayed.readSecret(profile), 'fake-new-b');
      expect(delayed.profiles, hasLength(1));
    },
  );

  test(
    'a superseded repair verification cannot begin credential replacement',
    () async {
      final profile = EndpointProfile(
        id: 'endpoint_one',
        label: 'Existing',
        endpoint: Uri.parse('http://127.0.0.1:4096/'),
      );
      await repo.save(profile, 'fake-old');
      final prober = GatedProber();
      final localHosts = HostsController(repository: repo, prober: prober);
      final local = PairingController(
        pairing: adapter,
        hosts: localHosts,
        qr: FakeQrInput(),
      );
      addTearDown(() {
        local.dispose();
        localHosts.dispose();
      });
      local.input('fake-test-link', profile: profile);
      await local.confirm();
      final pending = local.save('ignored');
      await Future<void>.delayed(Duration.zero);
      expect(prober.replies, hasLength(1));
      local.input('fake-test-link-b', profile: profile);
      await local.confirm();
      final currentReceipt = local.receipt;
      prober.replies.single.complete(
        const EndpointAssessment(EndpointStatus.compatible, version: '2.0.22'),
      );
      expect(await pending, isFalse);
      expect(await repo.readSecret(profile), 'fake-old');
      expect(local.receipt, same(currentReceipt));
      expect(local.candidate!.challenge, 'fake-test-code-b');
    },
  );
  test('capture and input never redeem before explicit confirmation', () async {
    await controller.capture(camera: false);
    expect(controller.candidate, isNotNull);
    expect(adapter.calls, 0);
    expect(repo.profiles, isEmpty);
    await controller.confirm();
    await controller.confirm();
    expect(adapter.calls, 1);
    expect(await controller.save('Server'), isTrue);
    expect(repo.profiles, hasLength(1));
    expect(
      (await repo.readCredential(repo.profiles.single))!.kind,
      EndpointAuthKind.paired,
    );
  });
  test('uncertain redemption cannot consume the same code again', () async {
    adapter.reply = const PairingResult(PairingStatus.uncertain);
    controller.input('fake-test-link');
    await controller.confirm();
    await controller.confirm();
    expect(adapter.calls, 1);
    expect(repo.profiles, isEmpty);
  });
  test(
    'new input discards stale credentials and wrong-target repair stays private',
    () async {
      final reply = Completer<PairingResult>();
      adapter.pending = reply.future;
      controller.input('fake-test-link');
      final pending = controller.confirm();
      controller.input('invalid');
      reply.complete(adapter.reply);
      await pending;
      expect(controller.receipt!.status, PairingStatus.invalidInput);
      expect(controller.receipt!.credential, isNull);
      controller.input(
        'fake-test-link',
        profile: EndpointProfile(
          id: 'endpoint_one',
          label: 'Other',
          endpoint: Uri.parse('http://127.0.0.1:49374/'),
        ),
      );
      expect(controller.candidate, isNull);
    },
  );
  test(
    'repair preserves identity and failed or expired authentication never clears data',
    () async {
      final profile = EndpointProfile(
        id: 'endpoint_one',
        label: 'Existing',
        endpoint: Uri.parse('http://127.0.0.1:4096/'),
      );
      await repo.save(profile, 'fake-old');
      await hosts.load();
      adapter.reply = const PairingResult(PairingStatus.rejected);
      controller.input('fake-test-link', profile: profile);
      await controller.confirm();
      expect(await repo.readSecret(profile), 'fake-old');
      expect(repo.profiles.single, same(profile));
      adapter.reply = PairingResult(
        PairingStatus.ready,
        credential: EndpointCredential(
          kind: EndpointAuthKind.paired,
          secret: 'fake-new',
          expiresAt: DateTime.utc(2026),
        ),
        assessment: const EndpointAssessment(
          EndpointStatus.compatible,
          version: '2.0.22',
        ),
      );
      controller.input('fake-test-link', profile: profile);
      await controller.confirm();
      expect(await controller.save('Ignored label'), isTrue);
      expect(repo.profiles.single, same(profile));
      expect(await repo.readSecret(profile), 'fake-new');
      final failedProbe = FakeProber()
        ..assessment = const EndpointAssessment(
          EndpointStatus.authenticationRequired,
        );
      final expired = HostsController(repository: repo, prober: failedProbe);
      addTearDown(expired.dispose);
      await expired.load();
      await expired.check(profile);
      expect(
        expired.assessments[profile.id]!.status,
        EndpointStatus.authenticationRequired,
      );
      expect(await repo.readSecret(profile), 'fake-new');
      expect(repo.profiles.single, same(profile));
    },
  );
}
