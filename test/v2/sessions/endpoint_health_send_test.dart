import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:codewalk/features/hosts/endpoint_health_controller.dart';
import 'package:codewalk/features/sessions/session_composer_status.dart';
import 'package:codewalk/features/sessions/session_live_controller.dart';
import 'package:codewalk/platform/sessions/prompt_outbox_store.dart';
import 'package:codewalk/platform/storage/payload_store.dart';
import 'package:codewalk/shared/l10n/generated/v2_localizations.dart';
import 'package:codewalk/shared/sessions/session_live_source.dart';
import 'package:codewalk/shared/sessions/session_selection.dart';
import 'package:codewalk/shared/sessions/session_turn_actions.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/widgets.dart';
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

/// A turn lane whose revert state is [revert] (null: not hydrated yet).
final class _Turns implements SessionTurnActionPort {
  _Turns(RevertState? revert) : state = SessionTurnState(revert: revert);

  @override
  SessionTurnState state;

  @override
  SessionTurnUnavailable? unavailable(SessionTurnAction action) => null;

  @override
  Future<SessionTurnResult> compact({required CommandId id}) async =>
      const SessionTurnResult(applied: false);

  @override
  Future<SessionTurnResult> redoAll({required CommandId id}) async =>
      const SessionTurnResult(applied: false);

  @override
  Future<SessionTurnResult> redoNext({required CommandId id}) async =>
      const SessionTurnResult(applied: false);

  @override
  Future<SessionTurnResult> stage(
    ItemId boundary, {
    required CommandId id,
  }) async => const SessionTurnResult(applied: false);

  @override
  Future<void> refresh() async {}
}

void main() {
  late CatalogRig rig;
  late EndpointHealthController health;
  late SessionLiveController live;
  late OutboxServer server;
  late _GateStore store;
  late LiveHandle handle;
  var clock = DateTime.utc(2026, 11, 25, 12);

  setUp(() async {
    rig = CatalogRig();
    await rig.save('a');
    await rig.sessions.initialize();
    clock = DateTime.utc(2026, 11, 25, 12);
    health = EndpointHealthController(hosts: rig.hosts, now: () => clock);
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
      now: () => clock,
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
    handle = directory.grant(live.session, outbox: outbox);
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

  /// The live view of [live] as [phase], keeping its state.
  void show(SessionLivePhase phase) => handle.emit(
    SessionLiveView(
      session: live.session,
      phase: phase,
      lastSyncedAt: DateTime.utc(2026, 10, 25),
      state: live.state ?? liveState(live.session),
    ),
  );

  group('the resume grace (#503)', () {
    test('a view live before the background looks live while it '
        'reconnects, then tells the truth', () async {
      // A cold reconnect is not masked.
      show(SessionLivePhase.reconnecting);
      await pumpEventQueue();
      expect(live.resumeGrace, isFalse);
      expect(live.composer.canSend, isFalse);
      show(SessionLivePhase.live);
      await pumpEventQueue();
      health.setForeground(false);
      health.setForeground(true);
      show(SessionLivePhase.reconnecting);
      await pumpEventQueue();
      expect(live.resumeGrace, isTrue);
      expect(live.composer.canSend, isTrue);
      // The status bar does not report the reconnect meanwhile.
      final l10n = lookupV2Localizations(const Locale('en'));
      expect(liveStatus(live, l10n), isNull);
      // Live again: nothing left to mask.
      show(SessionLivePhase.live);
      await pumpEventQueue();
      expect(live.resumeGrace, isFalse);
      // A drop within the window is masked again, until it runs out.
      show(SessionLivePhase.hydrating);
      await pumpEventQueue();
      clock = clock.add(liveResumeGrace - const Duration(milliseconds: 1));
      expect(live.resumeGrace, isTrue);
      clock = clock.add(const Duration(milliseconds: 1));
      expect(live.resumeGrace, isFalse);
      expect(live.composer.canSend, isFalse);
      expect(liveStatus(live, l10n)?.label, l10n.liveHydrating);
    });

    test('a pick is taken and switched once the stream is back', () async {
      final model = ModelEntry(id: 'alpha', providerId: 'prov', label: 'A');
      handle
        ..selectionAvailable = true
        ..selectionState = SessionSelectionState(models: [model]);
      show(SessionLivePhase.live);
      await pumpEventQueue();
      health.setForeground(false);
      health.setForeground(true);
      show(SessionLivePhase.reconnecting);
      await pumpEventQueue();
      // The picker stays open to the user while the stream comes back.
      expect(live.canChangeSelection, isTrue);
      await live.selectModel(model, variant: 'high');
      expect(handle.selectionCalls, isEmpty);
      // Like any switch, it settles before the next prompt or pick.
      expect(live.selectionDeferred, isTrue);
      expect(live.composer.canSend, isFalse);
      expect(live.canChangeSelection, isFalse);
      show(SessionLivePhase.live);
      await pumpEventQueue();
      expect(handle.selectionCalls, ['model:prov/alpha:high']);
      expect(live.selectionDeferred, isFalse);
    });

    test('a pick still waiting when the grace runs out is not lost', () async {
      final model = ModelEntry(id: 'alpha', providerId: 'prov', label: 'A');
      handle
        ..selectionAvailable = true
        ..selectionState = SessionSelectionState(models: [model]);
      show(SessionLivePhase.live);
      await pumpEventQueue();
      health.setForeground(false);
      health.setForeground(true);
      show(SessionLivePhase.reconnecting);
      await pumpEventQueue();
      await live.selectModel(model);
      clock = clock.add(liveResumeGrace);
      // The truth shows, and no new pick is taken meanwhile.
      expect(live.canChangeSelection, isFalse);
      show(SessionLivePhase.live);
      await pumpEventQueue();
      expect(handle.selectionCalls, ['model:prov/alpha']);
    });

    test('a second pause preserves the deferred pick deadline', () async {
      final model = ModelEntry(id: 'alpha', providerId: 'prov', label: 'A');
      handle
        ..selectionAvailable = true
        ..selectionState = SessionSelectionState(models: [model]);
      show(SessionLivePhase.live);
      await pumpEventQueue();
      health.setForeground(false);
      health.setForeground(true);
      show(SessionLivePhase.reconnecting);
      await pumpEventQueue();
      await live.selectModel(model);
      health.setForeground(false);
      clock = clock.add(liveResumeGrace * 2);
      health.setForeground(true);
      handle.selectionAvailable = false;
      show(SessionLivePhase.live);
      await pumpEventQueue();
      expect(live.selectionDeferred, isFalse);
      expect(live.composer.canSend, isTrue);
      expect(handle.selectionCalls, isEmpty);
    });

    test('a grace send waits until the revert state is known', () async {
      final turns = _Turns(null);
      handle.turnActions = turns;
      health.setForeground(false);
      health.setForeground(true);
      show(SessionLivePhase.reconnecting);
      await pumpEventQueue();
      expect(live.resumeGrace, isTrue);
      // A lease reopened without state could commit a staged revert.
      expect(live.composer.canSend, isFalse);
      turns.state = const SessionTurnState(
        revert: RevertState(kind: OpenValue.known(RevertKind.none)),
      );
      expect(live.composer.canSend, isTrue);
    });

    test('a newly staged revert requires a second tap', () async {
      final turns = _Turns(
        const RevertState(kind: OpenValue.known(RevertKind.none)),
      );
      handle.turnActions = turns;
      health.setForeground(false);
      health.setForeground(true);
      show(SessionLivePhase.reconnecting);
      await pumpEventQueue();
      live.draft.text = 'keep my draft';
      final sending = live.composer.send(live.draft.text);
      turns.state = const SessionTurnState(
        revert: RevertState(kind: OpenValue.known(RevertKind.staged)),
      );
      show(SessionLivePhase.live);
      expect(await sending, isFalse);
      expect(server.transport.bodies, isEmpty);
      expect(live.draft.text, 'keep my draft');
      expect(await live.composer.send(live.draft.text), isTrue);
    });

    test('a server confirmed Offline ends it at once', () async {
      health.setForeground(false);
      health.setForeground(true);
      show(SessionLivePhase.reconnecting);
      await pumpEventQueue();
      expect(live.resumeGrace, isTrue);
      observe(EndpointStatus.unreachable);
      expect(live.resumeGrace, isFalse);
      expect(live.composer.canSend, isFalse);
    });

    test('a view not live when the app left gets no grace', () async {
      show(SessionLivePhase.reconnecting);
      await pumpEventQueue();
      health.setForeground(false);
      health.setForeground(true);
      expect(live.resumeGrace, isFalse);
    });

    test(
      'a send goes out and waits pinned until the session shows it',
      () async {
        health.setForeground(false);
        health.setForeground(true);
        show(SessionLivePhase.reconnecting);
        await pumpEventQueue();
        final sending = live.composer.send('quick one');
        await pumpEventQueue();
        expect(server.transport.bodies, isEmpty);
        show(SessionLivePhase.live);
        expect(await sending, isTrue);
        expect(server.transport.bodies, hasLength(1));
        final waiting = live.composer.unseenPrompts(live.state);
        expect(waiting.single.text, 'quick one');
        expect(waiting.single.delivery.known, DeliveryState.accepted);
        // Once the session reports it, the pin gives way to its own row.
        final entry = live.composer.entries.single;
        final reportedId = ItemId(
          jsonEncode([live.session.storageKey, entry.messageId, 'user', 0]),
        );
        final reported = UserInput(
          meta: ItemMeta(
            id: reportedId,
            generation: 'live',
            status: const OpenValue.known(ItemStatus.pending),
            source: SourceProvenance(
              harness: live.session.harnessRef,
              version: '2.0.22',
              nativeType: 'live',
            ),
          ),
          text: 'quick one',
          delivery: const OpenValue.known(DeliveryState.accepted),
        );
        handle.emit(
          SessionLiveView(
            session: live.session,
            phase: SessionLivePhase.live,
            lastSyncedAt: DateTime.utc(2026, 10, 25),
            state: liveState(live.session, items: [reported]),
          ),
        );
        await pumpEventQueue();
        expect(live.composer.unseenPrompts(live.state), isEmpty);
      },
    );
  });

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
