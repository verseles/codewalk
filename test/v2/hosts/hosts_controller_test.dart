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
  EndpointProbeTask start(Uri endpoint, String secret) {
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
  final endpoint = Uri.parse('http://127.0.0.1:4096/');
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
