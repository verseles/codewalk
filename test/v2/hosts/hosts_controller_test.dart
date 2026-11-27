import 'dart:async';

import 'package:codewalk/features/hosts/hosts_controller.dart';
import 'package:codewalk/platform/profiles/endpoint_profile_store.dart';
import 'package:codewalk/platform/storage/endpoint_credentials.dart';
import 'package:codewalk/platform/storage/metadata_store.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';
import 'profile_store_test.dart' show Metadata, Secrets;

class GatedProber implements EndpointProber {
  final tasks = <FakeProbeTask>[];
  final replies = <Completer<EndpointAssessment>>[];
  @override
  EndpointProbeTask start(
    Uri endpoint,
    String secret, {
    Duration? connectionTimeout,
  }) {
    final reply = Completer<EndpointAssessment>();
    replies.add(reply);
    final task = FakeProbeTask(reply.future);
    tasks.add(task);
    return task;
  }
}

class GatedSecretsProfiles extends MemoryProfiles {
  final reads = <Completer<String?>>[];
  @override
  Future<String?> readSecret(EndpointProfile profile) {
    final gate = Completer<String?>();
    reads.add(gate);
    return gate.future;
  }
}

class GatedSaveProfiles extends MemoryProfiles {
  final gate = Completer<void>();
  @override
  Future<void> save(EndpointProfile profile, String secret) async {
    await gate.future;
    await super.save(profile, secret);
  }
}

class GatedEditProfiles extends MemoryProfiles {
  final entered = Completer<void>();
  final gate = Completer<void>();

  @override
  Future<EndpointProfile> updateProfile(
    EndpointProfile expected, {
    required String label,
    required Uri endpoint,
  }) async {
    entered.complete();
    await gate.future;
    return super.updateProfile(expected, label: label, endpoint: endpoint);
  }
}

class UnknownCommitProfiles extends MemoryProfiles {
  int saves = 0;
  int secretReads = 0;
  int? failSecretReadNumber;
  bool nullInsteadOfThrow = false;
  @override
  Future<String?> readSecret(EndpointProfile profile) async {
    secretReads++;
    if (secretReads == failSecretReadNumber) {
      if (nullInsteadOfThrow) return null;
      throw StateError('controlled reconciliation credential read failure');
    }
    return super.readSecret(profile);
  }

  @override
  Future<void> save(EndpointProfile profile, String secret) async {
    saves++;
    await super.save(profile, secret);
    failLoad = true;
    throw StateError('controlled unknown commit outcome');
  }
}

void main() {
  final harnessOptions = HarnessOptions(const [
    HarnessOption(
      kind: 'alpha',
      displayName: 'Alpha',
      availability: HarnessAvailability.available,
      methods: {HarnessConnectMethod.manualPassword},
    ),
    HarnessOption(
      kind: 'beta',
      displayName: 'Beta',
      availability: HarnessAvailability.comingSoon,
    ),
  ], defaultKind: 'alpha');

  test(
    'a new server keeps its harness and a coming-soon one is refused',
    () async {
      final repository = MemoryProfiles();
      final prober = FakeProber()
        ..assessment = const EndpointAssessment(EndpointStatus.compatible);
      final hosts = HostsController(
        repository: repository,
        prober: prober,
        harnesses: harnessOptions,
      );
      addTearDown(hosts.dispose);
      await hosts.load();
      final url = Uri.parse('http://127.0.0.1:4096/');
      var assessment = (await hosts.probe(url, 'secret'))!;
      expect(
        await hosts.add(url, 'Beta', 'secret', assessment, harnessKind: 'beta'),
        isFalse,
      );
      expect(repository.profiles, isEmpty);
      assessment = (await hosts.probe(url, 'secret'))!;
      expect(await hosts.add(url, 'Alpha', 'secret', assessment), isTrue);
      expect(repository.profiles.single.harnessKind, 'alpha');
    },
  );

  test('save anyway needs the failed check of that same input', () async {
    final repository = MemoryProfiles();
    final prober = FakeProber()
      ..assessment = const EndpointAssessment(EndpointStatus.unreachable);
    final hosts = HostsController(repository: repository, prober: prober);
    addTearDown(hosts.dispose);
    await hosts.load();
    final url = Uri.parse('http://127.0.0.1:4096/');
    final failed = (await hosts.probe(url, 'secret'))!;
    expect(await hosts.add(url, 'X', 'secret', failed), isFalse);
    expect(
      await hosts.add(url, 'X', 'other', failed, acceptFailure: true),
      isFalse,
    );
    expect(
      await hosts.add(
        url,
        'X',
        'secret',
        // An equal result from another check is not that check.
        // ignore: prefer_const_constructors
        EndpointAssessment(EndpointStatus.unreachable),
        acceptFailure: true,
      ),
      isFalse,
    );
    expect(repository.profiles, isEmpty);
    final again = (await hosts.probe(url, 'secret'))!;
    expect(
      await hosts.add(url, 'X', 'secret', again, acceptFailure: true),
      isTrue,
    );
    expect(repository.profiles, hasLength(1));
    expect(hosts.assessments[repository.profiles.single.id], same(again));
    prober.assessment = const EndpointAssessment(EndpointStatus.legacyServer);
    final legacy = (await hosts.probe(url, 'secret'))!;
    expect(
      await hosts.add(url, 'Y', 'secret', legacy, acceptFailure: true),
      isFalse,
    );
    expect(repository.profiles, hasLength(1));
  });

  test(
    'an indefinitely deferred failure saves and keeps its deferral',
    () async {
      final repository = MemoryProfiles();
      final hosts = HostsController(
        repository: repository,
        prober: FakeProber()
          ..assessment = const EndpointAssessment(
            EndpointStatus.serviceUnavailable,
            retryDeferred: true,
          ),
      );
      addTearDown(hosts.dispose);
      await hosts.load();
      final url = Uri.parse('http://127.0.0.1:4096/');
      final deferred = (await hosts.probe(url, 'secret'))!;
      expect(HostsController.canSaveDespite(deferred), isTrue);
      expect(
        await hosts.add(url, 'X', 'secret', deferred, acceptFailure: true),
        isTrue,
      );
      // No check is made earlier than the server asked.
      expect(hosts.assessments[repository.profiles.single.id], same(deferred));
    },
  );

  test('forgetting a check withdraws only its own authorization', () async {
    final repository = MemoryProfiles();
    final hosts = HostsController(
      repository: repository,
      prober: FakeProber()
        ..assessment = const EndpointAssessment(
          EndpointStatus.authenticationRequired,
        ),
    );
    addTearDown(hosts.dispose);
    await hosts.load();
    final url = Uri.parse('http://127.0.0.1:4096/');
    final failed = (await hosts.probe(url, 'secret'))!;
    final first = hosts.checkGeneration;
    hosts.forgetVerification(first);
    expect(
      await hosts.add(url, 'X', 'secret', failed, acceptFailure: true),
      isFalse,
    );
    expect(repository.profiles, isEmpty);
    // The next check returns the very same constant result.
    final again = (await hosts.probe(url, 'secret'))!;
    expect(again, same(failed));
    hosts.forgetVerification(first);
    expect(
      await hosts.add(url, 'X', 'secret', again, acceptFailure: true),
      isTrue,
    );
  });

  test('a reconciled uncertain save keeps its credential', () async {
    final repository = _CommitThenThrowProfiles();
    final hosts = HostsController(
      repository: repository,
      prober: FakeProber()
        ..assessment = const EndpointAssessment(EndpointStatus.unreachable),
    );
    addTearDown(hosts.dispose);
    await hosts.load();
    final url = Uri.parse('http://127.0.0.1:4096/');
    var failed = (await hosts.probe(url, 'secret'))!;
    expect(
      await hosts.add(url, 'X', 'secret', failed, acceptFailure: true),
      isFalse,
    );
    expect(repository.profiles, hasLength(1));
    failed = (await hosts.probe(url, 'secret'))!;
    expect(
      await hosts.add(url, 'X', 'secret', failed, acceptFailure: true),
      isTrue,
    );
    expect(repository.profiles, hasLength(1));
    expect(hosts.credentialFor(hosts.profiles.single)?.secret, 'secret');
  });

  test('without harness options no kind is recorded', () async {
    final repository = MemoryProfiles();
    final hosts = HostsController(
      repository: repository,
      prober: FakeProber()
        ..assessment = const EndpointAssessment(EndpointStatus.compatible),
    );
    addTearDown(hosts.dispose);
    await hosts.load();
    final url = Uri.parse('http://127.0.0.1:4096/');
    final assessment = (await hosts.probe(url, 'secret'))!;
    expect(
      await hosts.add(url, 'X', 'secret', assessment, harnessKind: 'alpha'),
      isTrue,
    );
    expect(repository.profiles.single.harnessKind, isNull);
  });

  final endpoint = Uri.parse('http://127.0.0.1:4096/');
  test(
    'local rename tolerates unreadable credentials and URL edit drops the old scope',
    () async {
      final backend = Metadata();
      final secrets = Secrets();
      final metadata = V2MetadataStore(backend: backend);
      final repository = EndpointProfileStore(
        metadata: metadata,
        credentials: EndpointCredentialVault(
          backend: secrets,
          beforeMutation: metadata.ensureSchema,
        ),
      );
      final original = EndpointProfile(
        id: 'endpoint_one',
        label: 'Original',
        endpoint: endpoint,
      );
      await repository.save(original, 'origin-a-secret');
      final vaultBefore = Map.of(secrets.values);
      final prober = FakeProber();
      final hosts = HostsController(repository: repository, prober: prober);
      addTearDown(hosts.dispose);
      secrets.failRead = true;
      await hosts.load();
      expect(hosts.credentialUnreadable(original), isTrue);
      expect(
        await hosts.updateProfile(
          original,
          label: 'Renamed',
          endpoint: endpoint,
          expectedRevision: hosts.catalogRevision,
        ),
        isTrue,
      );
      final renamed = hosts.profiles.single;
      expect(renamed.sameBinding(original), isTrue);
      expect(hosts.credentialUnreadable(renamed), isTrue);
      final staleRevision = hosts.catalogRevision;
      secrets.failRead = false;
      await hosts.load();
      expect(
        await hosts.updateProfile(
          renamed,
          label: 'Stale',
          endpoint: endpoint,
          expectedRevision: staleRevision,
        ),
        isFalse,
      );
      var sawPending = false;
      hosts.addListener(() {
        if (hosts.pendingBindingChange == original.id) sawPending = true;
      });
      expect(
        await hosts.updateProfile(
          renamed,
          label: 'Destination',
          endpoint: Uri.parse('https://destination.example/'),
          expectedRevision: hosts.catalogRevision,
        ),
        isTrue,
      );
      final moved = hosts.profiles.single;
      expect(sawPending, isTrue);
      expect(hosts.pendingBindingChange, isNull);
      expect(moved.bindingRevision, 1);
      expect(hosts.credentialFor(original), isNull);
      expect(hosts.credentialFor(moved), isNull);
      expect(secrets.values, vaultBefore);
      expect(prober.tasks, isEmpty);
    },
  );

  test(
    'pending binding edit is single-flight and visible before persistence',
    () async {
      final original = EndpointProfile(
        id: 'endpoint_one',
        label: 'Original',
        endpoint: endpoint,
      );
      final repository = GatedEditProfiles()
        ..profiles.add(original)
        ..secrets[original.id] = 'fake-secret';
      final hosts = HostsController(
        repository: repository,
        prober: FakeProber(),
      );
      addTearDown(hosts.dispose);
      await hosts.load();
      final editing = hosts.updateProfile(
        original,
        label: 'Moved',
        endpoint: endpoint.resolve('/other/'),
        expectedRevision: hosts.catalogRevision,
      );
      await repository.entered.future;
      expect(hosts.pendingBindingChange, original.id);
      expect(hosts.loading, isTrue);
      expect(hosts.savingProfile, isTrue);
      expect(hosts.profiles.single, same(original));
      expect(
        await hosts.updateProfile(
          original,
          label: 'Duplicate',
          endpoint: endpoint,
          expectedRevision: hosts.catalogRevision,
        ),
        isFalse,
      );
      repository.gate.complete();
      expect(await editing, isTrue);
      expect(hosts.profiles.single.bindingRevision, 1);
      expect(hosts.loading, isFalse);
      expect(hosts.savingProfile, isFalse);
    },
  );

  test(
    'rename preserves the pending health check and its observation',
    () async {
      final original = EndpointProfile(
        id: 'endpoint_one',
        label: 'Original',
        endpoint: endpoint,
      );
      final repository = MemoryProfiles()
        ..profiles.add(original)
        ..secrets[original.id] = 'fake-secret';
      final prober = GatedProber();
      final hosts = HostsController(repository: repository, prober: prober);
      addTearDown(hosts.dispose);
      await hosts.load();
      final checking = hosts.check(original);
      await pumpEventQueue();
      expect(prober.tasks, hasLength(1));
      expect(
        await hosts.updateProfile(
          original,
          label: 'Renamed',
          endpoint: endpoint,
          expectedRevision: hosts.catalogRevision,
        ),
        isTrue,
      );
      expect(prober.tasks.single.cancelled, isFalse);
      prober.replies.single.complete(
        const EndpointAssessment(EndpointStatus.compatible),
      );
      await checking;
      expect(hosts.assessments[original.id]?.status, EndpointStatus.compatible);
    },
  );

  test(
    'reloading an ABA binding rejects old manual and observed health results',
    () async {
      final original = EndpointProfile(
        id: 'endpoint_one',
        label: 'Original',
        endpoint: endpoint,
      );
      final repository = MemoryProfiles()
        ..profiles.add(original)
        ..secrets[original.id] = 'fake-secret';
      final prober = GatedProber();
      final hosts = HostsController(repository: repository, prober: prober);
      addTearDown(hosts.dispose);
      await hosts.load();
      final credential = hosts.credentialFor(original)!;
      hosts.observeAssessment(
        original,
        credential,
        const EndpointAssessment(EndpointStatus.compatible),
      );
      final checking = hosts.check(original);
      await pumpEventQueue();
      repository.profiles[0] = EndpointProfile(
        id: original.id,
        label: original.label,
        endpoint: endpoint,
        bindingRevision: 2,
      );
      await hosts.load();
      expect(hosts.assessments, isEmpty);
      hosts.observeAssessment(
        original,
        credential,
        const EndpointAssessment(EndpointStatus.compatible),
      );
      prober.replies.single.complete(
        const EndpointAssessment(EndpointStatus.compatible),
      );
      await checking;
      expect(hosts.assessments, isEmpty);
      expect(hosts.canCheck(original), isFalse);
      expect(hosts.credentialFor(original), isNull);
    },
  );
  test(
    'one unreadable active credential does not hide healthy profile metadata',
    () async {
      final backend = Metadata();
      final secrets = Secrets();
      final metadata = V2MetadataStore(backend: backend);
      final repository = EndpointProfileStore(
        metadata: metadata,
        credentials: EndpointCredentialVault(
          backend: secrets,
          beforeMutation: metadata.ensureSchema,
        ),
      );
      final broken = EndpointProfile(
        id: 'endpoint_bad',
        label: 'Broken',
        endpoint: endpoint,
      );
      final healthy = EndpointProfile(
        id: 'endpoint_good',
        label: 'Healthy',
        endpoint: endpoint,
      );
      await repository.save(broken, 'fake-old');
      await repository.save(healthy, 'fake-good');
      final key = EndpointCredentialScope(
        endpoint: endpoint,
        profileId: broken.id,
      ).key(EndpointCredentialKind.activeCredential);
      secrets.values[key] =
          '{"version":99,"kind":"paired","secret":"fake-future"}';
      final controller = HostsController(
        repository: repository,
        prober: FakeProber(),
      );
      addTearDown(controller.dispose);
      await controller.load();
      expect(controller.profiles.map((p) => p.id), [broken.id, healthy.id]);
      expect(controller.credentialUnreadable(broken), isTrue);
      expect(controller.credentialFor(healthy)!.secret, 'fake-good');
      expect(secrets.values[key], contains('fake-future'));
      await expectLater(repository.readSecret(broken), throwsFormatException);
      await controller.remove(broken);
      expect(controller.profiles.single.id, healthy.id);
      expect(await repository.readSecret(healthy), 'fake-good');
    },
  );
  test(
    'superseded probe cannot save or update a changed credential/target',
    () async {
      final repo = MemoryProfiles();
      final prober = GatedProber();
      final controller = HostsController(
        repository: repo,
        prober: prober,
        createId: () => 'endpoint_one',
      );
      addTearDown(controller.dispose);
      final first = controller.probe(endpoint, 'old-secret');
      final second = controller.probe(endpoint, 'new-secret');
      prober.replies[0].complete(
        const EndpointAssessment(EndpointStatus.compatible),
      );
      expect(await first, isNull);
      expect(prober.tasks.first.cancelled, isTrue);
      const fresh = EndpointAssessment(
        EndpointStatus.compatible,
        version: '2.0.22',
      );
      prober.replies[1].complete(fresh);
      expect(await second, same(fresh));
      expect(
        await controller.add(endpoint, 'Server', 'old-secret', fresh),
        isFalse,
      );
      expect(
        await controller.add(
          Uri.parse('http://127.0.0.1:49374/'),
          'Server',
          'new-secret',
          fresh,
        ),
        isFalse,
      );
      expect(repo.profiles, isEmpty);
      expect(
        await controller.add(endpoint, 'Server', 'new-secret', fresh),
        isTrue,
      );
      expect(repo.secrets.values, ['new-secret']);
    },
  );

  test(
    'manual saved-profile check respects retry deadline without automatic requests',
    () async {
      var now = DateTime.now().toUtc();
      final profile = EndpointProfile(
        id: 'endpoint_one',
        label: 'Server',
        endpoint: endpoint,
      );
      final repo = MemoryProfiles()
        ..profiles.add(profile)
        ..secrets[profile.id] = 'fake-secret';
      final probe = FakeProber()
        ..assessment = EndpointAssessment(
          EndpointStatus.serviceUnavailable,
          retryAt: now.add(const Duration(seconds: 2)),
        );
      final controller = HostsController(
        repository: repo,
        prober: probe,
        now: () => now,
      );
      addTearDown(controller.dispose);
      await controller.load();
      await controller.check(profile);
      expect(controller.canCheck(profile), isFalse);
      await controller.check(profile);
      expect(probe.tasks.length, 1);
      now = now.add(const Duration(seconds: 3));
      expect(controller.canCheck(profile), isTrue);
      await controller.check(profile);
      expect(probe.tasks.length, 2);
    },
  );

  test(
    'disposing a graph invalidates an outstanding probe without notification',
    () async {
      final prober = GatedProber();
      final controller = HostsController(
        repository: MemoryProfiles(),
        prober: prober,
      );
      final future = controller.probe(endpoint, 'fake-secret');
      controller.dispose();
      prober.replies.single.complete(
        const EndpointAssessment(EndpointStatus.compatible),
      );
      expect(await future, isNull);
      expect(prober.tasks.single.cancelled, isTrue);
    },
  );

  test(
    'committed save consumes its verification even when refresh fails',
    () async {
      final repo = MemoryProfiles()..failLoad = true;
      final controller = HostsController(
        repository: repo,
        prober: FakeProber(),
      );
      addTearDown(controller.dispose);
      final assessment = (await controller.probe(endpoint, 'fake-secret'))!;
      expect(
        await controller.add(endpoint, 'Server', 'fake-secret', assessment),
        isTrue,
      );
      expect(controller.storageError, isTrue);
      expect(
        await controller.add(endpoint, 'Server', 'fake-secret', assessment),
        isFalse,
      );
      expect(repo.profiles, hasLength(1));
      repo.failLoad = false;
      await controller.load();
      expect(controller.profiles, hasLength(1));
      expect(controller.storageError, isFalse);
    },
  );

  test(
    'concurrent save attempts cannot create two identities from one probe',
    () async {
      final repo = GatedSaveProfiles();
      final controller = HostsController(
        repository: repo,
        prober: FakeProber(),
      );
      addTearDown(controller.dispose);
      final assessment = (await controller.probe(endpoint, 'fake-secret'))!;
      final first = controller.add(
        endpoint,
        'Server',
        'fake-secret',
        assessment,
      );
      expect(
        await controller.add(endpoint, 'Server', 'fake-secret', assessment),
        isFalse,
      );
      repo.gate.complete();
      expect(await first, isTrue);
      expect(repo.profiles, hasLength(1));
    },
  );

  test(
    'saved-profile check is busy until completion and ignores duplicate taps',
    () async {
      final profile = EndpointProfile(
        id: 'endpoint_one',
        label: 'Server',
        endpoint: endpoint,
      );
      final repo = MemoryProfiles()
        ..profiles.add(profile)
        ..secrets[profile.id] = 'fake-secret';
      final prober = GatedProber();
      final controller = HostsController(repository: repo, prober: prober);
      addTearDown(controller.dispose);
      await controller.load();
      final check = controller.check(profile);
      expect(controller.isChecking(profile), isTrue);
      expect(controller.canCheck(profile), isFalse);
      await controller.check(profile);
      await Future<void>.delayed(Duration.zero);
      expect(prober.tasks, hasLength(1));
      prober.replies.single.complete(
        const EndpointAssessment(EndpointStatus.compatible),
      );
      await check;
      expect(controller.isChecking(profile), isFalse);
      expect(controller.canCheck(profile), isTrue);
    },
  );

  test(
    'stale secret lookup cannot clear a newer check of the same profile',
    () async {
      final profile = EndpointProfile(
        id: 'endpoint_one',
        label: 'Server',
        endpoint: endpoint,
      );
      final repo = GatedSecretsProfiles()..profiles.add(profile);
      final controller = HostsController(
        repository: repo,
        prober: FakeProber(),
      );
      addTearDown(controller.dispose);
      await controller.load();
      final first = controller.check(profile);
      controller.cancelProbe();
      final second = controller.check(profile);
      repo.reads.first.complete('old-secret');
      await first;
      expect(controller.isChecking(profile), isTrue);
      repo.reads.last.complete('new-secret');
      await second;
      expect(controller.isChecking(profile), isFalse);
      expect(controller.assessments[profile.id]?.canUse, isTrue);
    },
  );

  test(
    'unknown committed save requires reconciliation before another identity',
    () async {
      final repo = UnknownCommitProfiles();
      var identities = 0;
      final controller = HostsController(
        repository: repo,
        prober: FakeProber(),
        createId: () => 'endpoint_${++identities}',
      );
      addTearDown(controller.dispose);
      var assessment = (await controller.probe(endpoint, 'fake-secret'))!;
      expect(
        await controller.add(endpoint, 'Server', 'fake-secret', assessment),
        isFalse,
      );
      expect(
        await controller.add(endpoint, 'Server', 'fake-secret', assessment),
        isFalse,
      );
      assessment = (await controller.probe(endpoint, 'fake-secret'))!;
      expect(
        await controller.add(endpoint, 'Server', 'fake-secret', assessment),
        isFalse,
      );
      expect(identities, 1);
      expect(repo.saves, 1);
      repo.failLoad = false;
      assessment = (await controller.probe(endpoint, 'fake-secret'))!;
      expect(
        await controller.add(endpoint, 'Server', 'fake-secret', assessment),
        isTrue,
      );
      expect(controller.profiles, hasLength(1));
      expect(repo.profiles, hasLength(1));
      expect(repo.secrets.values, ['fake-secret']);
      expect(identities, 1);
      expect(repo.saves, 1);
    },
  );

  test(
    'definitely failed save can be reprobed and retried after catalog reconciliation',
    () async {
      final repo = MemoryProfiles()..failSave = true;
      final controller = HostsController(
        repository: repo,
        prober: FakeProber(),
      );
      addTearDown(controller.dispose);
      var assessment = (await controller.probe(endpoint, 'fake-secret'))!;
      expect(
        await controller.add(endpoint, 'Server', 'fake-secret', assessment),
        isFalse,
      );
      expect(
        await controller.add(endpoint, 'Server', 'fake-secret', assessment),
        isFalse,
      );
      repo.failSave = false;
      assessment = (await controller.probe(endpoint, 'fake-secret'))!;
      expect(
        await controller.add(endpoint, 'Server', 'fake-secret', assessment),
        isTrue,
      );
      expect(repo.profiles, hasLength(1));
    },
  );

  test(
    'credential read failure retains pending identity for the next reconciliation',
    () async {
      final repo = UnknownCommitProfiles()..failSecretReadNumber = 1;
      var identities = 0;
      final controller = HostsController(
        repository: repo,
        prober: FakeProber(),
        createId: () => 'endpoint_${++identities}',
      );
      addTearDown(controller.dispose);
      var assessment = (await controller.probe(endpoint, 'fake-secret'))!;
      expect(
        await controller.add(endpoint, 'Server', 'fake-secret', assessment),
        isFalse,
      );
      repo.failLoad = false;
      assessment = (await controller.probe(endpoint, 'fake-secret'))!;
      expect(
        await controller.add(endpoint, 'Server', 'fake-secret', assessment),
        isFalse,
      );
      assessment = (await controller.probe(endpoint, 'fake-secret'))!;
      expect(
        await controller.add(endpoint, 'Server', 'fake-secret', assessment),
        isTrue,
      );
      expect(controller.profiles, hasLength(1));
      expect(repo.profiles, hasLength(1));
      expect(identities, 1);
      expect(repo.saves, 1);
    },
  );

  for (final returnsNull in [false, true]) {
    test(
      'reconciliation reuses one credential snapshot; second read would ${returnsNull ? 'return null' : 'throw'}',
      () async {
        final repo = UnknownCommitProfiles()
          ..failSecretReadNumber = 2
          ..nullInsteadOfThrow = returnsNull;
        var identities = 0;
        final controller = HostsController(
          repository: repo,
          prober: FakeProber(),
          createId: () => 'endpoint_${++identities}',
        );
        addTearDown(controller.dispose);
        var assessment = (await controller.probe(endpoint, 'fake-secret'))!;
        expect(
          await controller.add(endpoint, 'Server', 'fake-secret', assessment),
          isFalse,
        );
        repo.failLoad = false;
        assessment = (await controller.probe(endpoint, 'fake-secret'))!;
        expect(
          await controller.add(endpoint, 'Server', 'fake-secret', assessment),
          isTrue,
        );
        expect(repo.secretReads, 1);
        expect(controller.profiles, hasLength(1));
        expect(repo.profiles, hasLength(1));
        expect(identities, 1);
        expect(repo.saves, 1);
      },
    );
  }
}

/// Commits the first save and then reports a failure, like a backend whose
/// write landed before the error.
final class _CommitThenThrowProfiles extends MemoryProfiles {
  var _thrown = false;
  @override
  Future<void> save(EndpointProfile profile, String secret) async {
    await super.save(profile, secret);
    if (!_thrown) {
      _thrown = true;
      throw StateError('controlled uncertain save');
    }
  }
}
