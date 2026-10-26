import 'dart:async';
import 'dart:math';

import 'package:codewalk/features/hosts/endpoint_health_controller.dart';
import 'package:codewalk/features/sessions/session_live_controller.dart';
import 'package:codewalk/platform/sessions/prompt_outbox_store.dart';
import 'package:codewalk/platform/storage/payload_store.dart';
import 'package:codewalk/shared/sessions/session_live_source.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harness_opencode/harness_opencode.dart';

import 'fakes.dart';
import 'live_fakes.dart';
import 'outbox_fakes.dart';

final class _GateStore extends OutboxStore {
  final entered = Completer<void>();
  final release = Completer<void>();
  bool armed = false;

  @override
  Future<PayloadWriteResult> write(String key, String value) async {
    final result = await super.write(key, value);
    if (armed) {
      armed = false;
      entered.complete();
      await release.future;
    }
    return result;
  }
}

void main() {
  late CatalogRig rig;
  late EndpointHealthController health;
  late SessionLiveController live;
  late OutboxServer server;
  late _GateStore store;

  setUp(() async {
    rig = CatalogRig();
    await rig.save('a');
    await rig.sessions.initialize();
    health = EndpointHealthController(hosts: rig.hosts);
    health.start(foreground: true);
    await pumpEventQueue();
    final directory = LiveDirectory();
    final summary = CatalogSource(profile('a')).row('one');
    live = SessionLiveController(
      hosts: rig.hosts,
      health: health,
      profile: profile('a'),
      summary: summary,
      directory: directory,
    );
    server = OutboxServer();
    server.transport.endpoint = live.profile.endpoint;
    store = _GateStore();
    final outbox = OpenCodePromptOutbox(
      profile: live.profile,
      store: store,
      client: OpenCodePromptClient(
        server.transport,
        harness: live.session.harnessRef,
        connectedVersion: '2.0.22',
        deadline: const Duration(milliseconds: 200),
      ),
      reader: OpenCodeSessionReader(
        server.transport,
        harness: live.session.harnessRef,
      ),
      ids: OpenCodeMessageIds(random: Random(1)),
      wait: (_) async {},
    );
    final opening = live.start();
    final handle = directory.grant(live.session, outbox: outbox);
    await opening;
    handle.emit(
      SessionLiveView(
        session: live.session,
        phase: SessionLivePhase.live,
        lastSyncedAt: DateTime.utc(2026, 10, 25),
        state: liveState(live.session),
      ),
    );
    await pumpEventQueue();
  });

  tearDown(() {
    live.dispose();
    health.dispose();
    rig.dispose();
  });

  void observe(EndpointStatus status) => rig.hosts.observeAssessment(
    live.profile,
    rig.hosts.credentialFor(live.profile)!,
    EndpointAssessment(status),
  );

  test(
    'confirmed offline blocks sends despite a current live stream',
    () async {
      expect(live.composer.canSend, isTrue);
      observe(EndpointStatus.unreachable);
      expect(live.endpointOffline, isTrue);
      expect(live.view?.phase, SessionLivePhase.live);
      expect(live.composer.canSend, isFalse);
      expect(await live.composer.send('keep this text'), isFalse);
      expect(server.transport.bodies, isEmpty);
      observe(EndpointStatus.compatible);
      expect(live.composer.canSend, isTrue);
      expect(await live.composer.send('one explicit retry'), isTrue);
      expect(server.transport.bodies, hasLength(1));
    },
  );

  test('offline while saving the outbox prevents the initial POST', () async {
    live.draft.text = 'retain the unsent prompt';
    store.armed = true;
    final sending = live.composer.send(live.draft.text);
    await store.entered.future;
    observe(EndpointStatus.unreachable);
    store.release.complete();
    expect(await sending, isFalse);
    expect(server.transport.bodies, isEmpty);
    expect(live.draft.text, 'retain the unsent prompt');
  });

  test(
    'reloading credentials cannot clear a confirmed offline send guard',
    () async {
      observe(EndpointStatus.unreachable);
      final credential = rig.hosts.credentialFor(live.profile)!;
      final gate = Completer<EndpointCredential?>();
      rig.repository.credentialGate = gate;
      final loading = rig.hosts.load();
      try {
        await pumpEventQueue();
        expect(rig.hosts.loading, isTrue);
        expect(live.view?.phase, SessionLivePhase.live);
        expect(await live.composer.send('keep this unsent'), isFalse);
        expect(server.transport.bodies, isEmpty);
        expect(live.endpointOffline, isTrue);
        expect(live.composer.canSend, isFalse);
      } finally {
        rig.repository.credentialGate = null;
        gate.complete(credential);
        await loading;
      }
    },
  );
}
