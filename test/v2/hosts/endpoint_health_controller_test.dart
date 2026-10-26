import 'dart:async';

import 'package:codewalk/features/hosts/endpoint_health_controller.dart';
import 'package:codewalk/features/hosts/hosts_controller.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

EndpointProfile _profile(String id) => EndpointProfile(
  id: 'profile_$id',
  label: 'Server $id',
  endpoint: Uri.parse('http://$id.example.test:4096/proxy/'),
);

final class _Probe implements EndpointProbeTask {
  _Probe(this.endpoint, this.secret);
  final Uri endpoint;
  final String secret;
  final completion = Completer<EndpointAssessment>();
  bool cancelled = false;
  @override
  Future<EndpointAssessment> get result => completion.future;
  @override
  void cancel() => cancelled = true;
  void complete(
    EndpointStatus status, {
    DateTime? retryAt,
    bool defer = false,
  }) => completion.complete(
    EndpointAssessment(status, retryAt: retryAt, retryDeferred: defer),
  );
}

final class _Prober implements EndpointProber {
  final calls = <_Probe>[];
  @override
  EndpointProbeTask start(Uri endpoint, String secret) {
    final task = _Probe(endpoint, secret);
    calls.add(task);
    return task;
  }
}

final class _GatedProfiles extends MemoryProfiles {
  final gate = Completer<EndpointCredential?>();
  @override
  Future<EndpointCredential?> readCredential(EndpointProfile profile) =>
      profile.id == 'profile_a' ? gate.future : super.readCredential(profile);
}

final class _UnreadableProfiles extends MemoryProfiles {
  @override
  Future<EndpointCredential?> readCredential(EndpointProfile profile) async =>
      throw StateError('controlled credential read failure');
}

final class _Rig {
  _Rig(WidgetTester tester, {MemoryProfiles? repository})
    : profiles = repository ?? MemoryProfiles() {
    DateTime now() => tester.binding.clock.now().toUtc();
    hosts = HostsController(repository: profiles, prober: prober, now: now);
    health = EndpointHealthController(hosts: hosts, now: now);
  }
  final MemoryProfiles profiles;
  final prober = _Prober();
  late final HostsController hosts;
  late final EndpointHealthController health;

  EndpointProfile save(String id, {String? secret = 'password'}) {
    final profile = _profile(id);
    profiles.profiles.add(profile);
    if (secret != null) profiles.secrets[profile.id] = secret;
    return profile;
  }

  Future<void> start(WidgetTester tester) async {
    health.start(foreground: true);
    await tester.pump();
  }

  void dispose() {
    health.dispose();
    hosts.dispose();
  }
}

void main() {
  testWidgets('startup preserves an existing manual Retry-After fence', (
    tester,
  ) async {
    final rig = _Rig(tester);
    try {
      final profile = rig.save('a');
      await rig.hosts.load();
      final manual = rig.hosts.check(profile);
      await tester.pump();
      rig.prober.calls.single.complete(
        EndpointStatus.serviceStarting,
        retryAt: rig.health.now.add(const Duration(seconds: 30)),
      );
      await manual;
      await rig.start(tester);
      expect(rig.prober.calls, hasLength(1));
      expect(rig.health.view(profile).status, EndpointHealthStatus.offline);
      expect(rig.health.canRefresh(profile), isFalse);
      await tester.pump(const Duration(seconds: 30));
      expect(rig.prober.calls, hasLength(2));
    } finally {
      rig.dispose();
    }
  });

  testWidgets('a credential expiring in foreground blocks further probes', (
    tester,
  ) async {
    final rig = _Rig(tester);
    try {
      final profile = rig.save('a');
      rig.profiles.credentials[profile.id] = EndpointCredential(
        kind: EndpointAuthKind.paired,
        secret: 'temporary',
        expiresAt: rig.health.now.add(const Duration(seconds: 5)),
      );
      await rig.start(tester);
      rig.prober.calls.single.complete(EndpointStatus.compatible);
      await tester.pump();
      expect(rig.health.view(profile).status, EndpointHealthStatus.online);
      var expiredNotification = false;
      rig.health.addListener(() {
        if (rig.health.view(profile).credentialFailure ==
            EndpointCredentialFailure.expired) {
          expiredNotification = true;
        }
      });
      await tester.pump(const Duration(seconds: 5));
      expect(expiredNotification, isTrue);
      expect(rig.prober.calls, hasLength(1));
      expect(rig.health.view(profile).status, EndpointHealthStatus.offline);
      expect(
        rig.health.view(profile).credentialFailure,
        EndpointCredentialFailure.expired,
      );
    } finally {
      rig.dispose();
    }
  });

  testWidgets('all credentials finish loading before any endpoint is probed', (
    tester,
  ) async {
    final profiles = _GatedProfiles();
    final rig = _Rig(tester, repository: profiles);
    try {
      final a = rig.save('a', secret: 'first');
      final b = rig.save('b', secret: 'second');
      await rig.start(tester);
      expect(rig.hosts.loading, isTrue);
      expect(rig.prober.calls, isEmpty);
      profiles.gate.complete(
        EndpointCredential(kind: EndpointAuthKind.password, secret: 'first'),
      );
      await tester.pump();
      expect(rig.prober.calls.map((p) => p.endpoint), [a.endpoint, b.endpoint]);
      expect(rig.prober.calls.map((p) => p.secret), ['first', 'second']);
      expect(rig.health.view(a).status, EndpointHealthStatus.delayed);
      expect(rig.health.view(a).checking, isTrue);
    } finally {
      rig.dispose();
    }
  });

  testWidgets('every saved endpoint is checked at the ten-second cadence', (
    tester,
  ) async {
    final rig = _Rig(tester);
    try {
      final a = rig.save('a');
      rig.save('b');
      await rig.start(tester);
      for (final task in rig.prober.calls) {
        task.complete(EndpointStatus.compatible);
      }
      await tester.pump();
      expect(rig.health.view(a).status, EndpointHealthStatus.online);
      await tester.pump(const Duration(seconds: 9));
      expect(rig.prober.calls, hasLength(2));
      await tester.pump(const Duration(seconds: 1));
      expect(rig.prober.calls, hasLength(4));
      await tester.pump(const Duration(seconds: 30));
      expect(
        rig.prober.calls,
        hasLength(4),
        reason: 'pending probes never overlap',
      );
    } finally {
      rig.dispose();
    }
  });

  testWidgets('background cancels only this lane and late failure is ignored', (
    tester,
  ) async {
    final rig = _Rig(tester);
    try {
      final profile = rig.save('a');
      await rig.start(tester);
      rig.prober.calls.single.complete(EndpointStatus.compatible);
      await tester.pump();
      await tester.pump(const Duration(seconds: 10));
      final stale = rig.prober.calls.last;
      rig.health.setForeground(false);
      expect(stale.cancelled, isTrue);
      stale.complete(EndpointStatus.unreachable);
      await tester.pump(const Duration(seconds: 30));
      expect(rig.prober.calls, hasLength(2));
      expect(rig.health.view(profile).status, EndpointHealthStatus.online);
      rig.health.setForeground(true);
      await tester.pump();
      expect(rig.prober.calls, hasLength(3));
      expect(rig.health.resumedAt, rig.health.now);
    } finally {
      rig.dispose();
    }
  });

  testWidgets(
    'an untested or cancelled result never claims confirmed offline',
    (tester) async {
      final rig = _Rig(tester);
      try {
        final profile = rig.save('a');
        await rig.start(tester);
        rig.prober.calls.single.complete(EndpointStatus.untested);
        await tester.pump();
        expect(rig.health.view(profile).status, EndpointHealthStatus.delayed);
        final checking = rig.health.refresh(profile);
        rig.prober.calls.last.complete(EndpointStatus.cancelled);
        await checking;
        expect(rig.health.view(profile).status, EndpointHealthStatus.delayed);
        final confirmed = rig.health.refresh(profile);
        rig.prober.calls.last.complete(EndpointStatus.unreachable);
        await confirmed;
        expect(rig.health.view(profile).status, EndpointHealthStatus.offline);
      } finally {
        rig.dispose();
      }
    },
  );

  testWidgets('automatic results do not cancel or finish the manual check', (
    tester,
  ) async {
    final rig = _Rig(tester);
    try {
      final profile = rig.save('a');
      await rig.start(tester);
      final manual = rig.hosts.check(profile);
      await tester.pump();
      expect(rig.prober.calls, hasLength(2));
      expect(rig.prober.calls.first.cancelled, isFalse);
      rig.prober.calls.first.complete(EndpointStatus.compatible);
      await tester.pump();
      expect(rig.hosts.isChecking(profile), isTrue);
      expect(rig.prober.calls.last.cancelled, isFalse);
      rig.prober.calls.last.complete(EndpointStatus.unreachable);
      await manual;
      expect(rig.health.view(profile).status, EndpointHealthStatus.offline);
    } finally {
      rig.dispose();
    }
  });

  testWidgets(
    'an older automatic answer cannot replace a newer manual answer',
    (tester) async {
      final rig = _Rig(tester);
      try {
        final profile = rig.save('a');
        await rig.start(tester);
        final manual = rig.hosts.check(profile);
        await tester.pump();
        rig.prober.calls.last.complete(EndpointStatus.compatible);
        await manual;
        expect(rig.prober.calls.first.cancelled, isFalse);
        rig.prober.calls.first.complete(EndpointStatus.unreachable);
        await tester.pump();
        expect(rig.health.view(profile).status, EndpointHealthStatus.online);
        expect(
          rig.hosts.assessments[profile.id]?.status,
          EndpointStatus.compatible,
        );
      } finally {
        rig.dispose();
      }
    },
  );

  testWidgets('Retry-After blocks both automatic and explicit health refresh', (
    tester,
  ) async {
    final rig = _Rig(tester);
    try {
      final profile = rig.save('a');
      await rig.start(tester);
      rig.prober.calls.single.complete(
        EndpointStatus.serviceStarting,
        retryAt: rig.health.now.add(const Duration(seconds: 30)),
      );
      await tester.pump();
      expect(rig.health.canRefresh(profile), isFalse);
      expect(rig.hosts.canCheck(profile), isFalse);
      await rig.health.refresh(profile);
      await tester.pump(const Duration(seconds: 20));
      expect(rig.prober.calls, hasLength(1));
      await tester.pump(const Duration(seconds: 10));
      expect(rig.prober.calls, hasLength(2));
    } finally {
      rig.dispose();
    }
  });

  testWidgets('an unrepresentable retry delay never turns into a probe loop', (
    tester,
  ) async {
    final rig = _Rig(tester);
    try {
      final profile = rig.save('a');
      await rig.start(tester);
      rig.prober.calls.single.complete(
        EndpointStatus.serviceUnavailable,
        defer: true,
      );
      await tester.pump(const Duration(minutes: 2));
      expect(rig.prober.calls, hasLength(1));
      expect(rig.health.canRefresh(profile), isFalse);
      expect(rig.hosts.canCheck(profile), isFalse);
    } finally {
      rig.dispose();
    }
  });

  testWidgets('a credential reload cancels and rejects the old observation', (
    tester,
  ) async {
    final rig = _Rig(tester);
    try {
      final profile = rig.save('a', secret: 'before');
      await rig.start(tester);
      final stale = rig.prober.calls.single;
      rig.profiles.secrets[profile.id] = 'after';
      await rig.hosts.load();
      await tester.pump();
      expect(stale.cancelled, isTrue);
      expect(rig.prober.calls.last.secret, 'after');
      stale.complete(EndpointStatus.unreachable);
      await tester.pump();
      expect(rig.health.view(profile).status, EndpointHealthStatus.delayed);
      rig.prober.calls.last.complete(EndpointStatus.compatible);
      await tester.pump();
      expect(rig.health.view(profile).status, EndpointHealthStatus.online);
    } finally {
      rig.dispose();
    }
  });

  testWidgets('expired and missing credentials do not reach the network', (
    tester,
  ) async {
    final rig = _Rig(tester);
    try {
      final missing = rig.save('a', secret: null);
      final expired = rig.save('b');
      rig.profiles.credentials[expired.id] = EndpointCredential(
        kind: EndpointAuthKind.paired,
        secret: 'expired',
        expiresAt: rig.health.now.subtract(const Duration(seconds: 1)),
      );
      await rig.start(tester);
      expect(rig.prober.calls, isEmpty);
      expect(
        rig.health.view(missing).credentialFailure,
        EndpointCredentialFailure.missing,
      );
      expect(
        rig.health.view(expired).credentialFailure,
        EndpointCredentialFailure.expired,
      );
      expect(rig.health.view(expired).status, EndpointHealthStatus.offline);
    } finally {
      rig.dispose();
    }
  });

  testWidgets('unreadable credentials keep their finite local failure', (
    tester,
  ) async {
    final rig = _Rig(tester, repository: _UnreadableProfiles());
    try {
      final profile = rig.save('a');
      await rig.start(tester);
      expect(rig.prober.calls, isEmpty);
      expect(
        rig.health.view(profile).credentialFailure,
        EndpointCredentialFailure.unreadable,
      );
    } finally {
      rig.dispose();
    }
  });

  testWidgets('removing a profile cancels its read and rejects a late result', (
    tester,
  ) async {
    final rig = _Rig(tester);
    try {
      final profile = rig.save('a');
      await rig.start(tester);
      final stale = rig.prober.calls.single;
      await rig.hosts.remove(profile);
      expect(stale.cancelled, isTrue);
      stale.complete(EndpointStatus.compatible);
      await tester.pump(const Duration(seconds: 30));
      expect(rig.prober.calls, hasLength(1));
      expect(rig.health.view(profile).status, EndpointHealthStatus.delayed);
    } finally {
      rig.dispose();
    }
  });
}
