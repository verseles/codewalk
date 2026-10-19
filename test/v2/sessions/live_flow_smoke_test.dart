import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:codewalk/features/hosts/hosts_controller.dart';
import 'package:codewalk/features/sessions/session_live_controller.dart';
import 'package:codewalk/features/sessions/session_live_page.dart';
import 'package:codewalk/features/sessions/session_permission_card.dart'
    show permissionKeyOf;
import 'package:codewalk/platform/endpoints/pairing_factory_io.dart';
import 'package:codewalk/platform/endpoints/probe_factory_io.dart';
import 'package:codewalk/platform/profiles/endpoint_profile_store.dart';
import 'package:codewalk/platform/sessions/permission_mode_store.dart';
import 'package:codewalk/platform/sessions/session_live_factory_io.dart';
import 'package:codewalk/platform/storage/endpoint_credentials.dart';
import 'package:codewalk/platform/storage/metadata_store.dart';
import 'package:codewalk/shared/l10n/generated/v2_localizations.dart';
import 'package:codewalk/shared/sessions/command_ids.dart'
    show mintCommandId;
import 'package:codewalk/shared/sessions/permission_mode.dart';
import 'package:codewalk/shared/sessions/session_live_source.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:codewalk_net/codewalk_net_io.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../hosts/profile_store_test.dart' show Metadata, Secrets;
import 'live_smoke_support.dart';
import 'outbox_fakes.dart' show OutboxStore;

/// V2-060B Tier B: minimal live OpenCode flow on a disposable host.
///
/// Explicit opt-in: the launcher owns the isolated 2.0.22 server (foreground
/// `serve` on 127.0.0.1, isolated HOME/XDG, fresh password, loopback stub
/// provider with deny-all-but-stub). Default runs skip without contacting any
/// service. Zero inference spend: the only provider the server may use is the
/// launcher's deterministic loopback stub, and every native turn asserts
/// cost 0 on the wire.
void main() {
  final upstream = io.Platform.environment['CODEWALK_LIVE_SMOKE_UPSTREAM'];
  final password = io.Platform.environment['CODEWALK_LIVE_SMOKE_PASSWORD'];
  final projectDir =
      io.Platform.environment['CODEWALK_LIVE_SMOKE_PROJECT_DIR'];

  late io.HttpOverrides? previousOverrides;
  setUpAll(() {
    // The SDK exposes only the zone-aware `current` getter (`global` is
    // setter-only); the flutter_test mock is installed as the global, so
    // saving `current` captures it for a faithful restore.
    previousOverrides = io.HttpOverrides.current;
    io.HttpOverrides.global = null;
  });
  tearDownAll(() {
    io.HttpOverrides.global = previousOverrides;
  });

  /// Advances real async and fake frames until [predicate] holds.
  ///
  /// The cadence is a balance of two clocks: the fake clock serves the
  /// product's own timers (it must advance, or a timer-awaited future never
  /// completes), while the real slice gives the live socket time. A too-fast
  /// fake clock would trip the 45-second SSE watchdog on a healthy stream, so
  /// the fake step stays small relative to the real one.
  Future<void> pumpSpin(
    WidgetTester tester,
    FutureOr<bool> Function() condition, {
    String reason = 'condition',
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (!(await condition())) {
      if (DateTime.now().isAfter(deadline)) {
        fail('Timed out waiting for $reason');
      }
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 15)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump();
  }

  bool timelineHas(SessionLiveController live, String marker) =>
      (live.state?.timeline ?? const []).whereType<AssistantText>().any(
        (item) => item.complete && item.text.contains(marker),
      );

  InteractionRequest permissionRequest(SessionLiveController live) =>
      (live.state?.interactions ?? const [])
          .where((request) => request.kind.known == InteractionKind.permission)
          .single;

  testWidgets(
    'disposable 2.0.22 live smoke through the real screens: pairing, send, approval',
    (tester) async {
      /// Runs [action] on real async time. Mandatory for every direct await
      /// of real socket IO: widget tests run in a fake-async zone where a
      /// bare await on a live future never completes. UI taps need no
      /// wrapping: the gesture settles in the fake zone while [pumpSpin]
      /// keeps cycling.
      Future<T> real<T>(Future<T> Function() action) async =>
          (await tester.runAsync(action)) as T;

      /// Polls native permission state with pumps interleaved: background
      /// product machinery (stream projection, auto-approval) needs
      /// fake-timer pumps as well as real IO slices, so a bare real-time
      /// poll would starve it. Returns whether the list emptied in budget;
      /// the caller asserts outside `real` so failures stop the test.
      Future<bool> pollPermissionsEmpty(
        NativeProbe probe,
        String nativeId,
        Duration budget,
      ) async {
        final deadline = DateTime.now().add(budget);
        while (DateTime.now().isBefore(deadline)) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 15)),
          );
          await tester.pump(const Duration(milliseconds: 50));
          final empty = await real(
            () async => (await probe.listPermissions(nativeId)).isEmpty,
          );
          if (empty) return true;
        }
        return false;
      }

      // No relay here: every call goes straight at the disposable server.
      // Transport drops and recovery belong to the headless recovery test
      // below; widget tests run in a fake-async zone where a same-isolate
      // relay pipe never dispatches.
      final endpoint = Uri.parse(upstream!);

      Future<(int, String)> mintPairCode(String secret) async {
        final transport = IoEndpointHttpTransport(
          endpoint: endpoint,
          headers: basicEndpointHeaders(
            endpoint: endpoint,
            username: 'opencode',
            secret: () => secret,
          ),
        );
        try {
          final response = await transport.send(
            TransportRequest(
              method: 'POST',
              path: '/api/pair',
              headers: const {'Accept': 'application/json'},
            ),
          );
          try {
            final raw = utf8.decode(
              await response.readBytes(maxBytes: 65536),
            );
            final data = jsonDecode(raw);
            return (response.statusCode, (data as Map)['code'] as String);
          } finally {
            response.cancel();
          }
        } finally {
          transport.close();
        }
      }

      // P1 — pairing: single-use redemption yields a usable paired token.
      final pairing = createEndpointPairing();
      final (pairStatus, code) = await real(() => mintPairCode(password!));
      expect(pairStatus, 200);
      final receipt = await real(
        () =>
            pairing
                .redeem(
                  PairingCandidate(endpoint: endpoint, challenge: code),
                )
                .result,
      );
      expect(receipt.status, PairingStatus.ready);
      final token = receipt.credential!;
      expect(token.kind, EndpointAuthKind.paired);
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
      final hosts = HostsController(
        repository: repository,
        prober: createEndpointProber(),
      );
      addTearDown(hosts.dispose);
      final assessment = await real(() => hosts.probe(endpoint, token.secret));
      expect(assessment?.version, '2.0.22');
      expect(assessment?.canUse, isTrue);
      expect(
        await real(
          () => hosts.addCredential(endpoint, 'Native QA', token, assessment!),
        ),
        isTrue,
      );
      final profile = (await real(repository.load)).single;
      final second = await real(
        () =>
            pairing
                .redeem(PairingCandidate(endpoint: endpoint, challenge: code))
                .result,
      );
      expect(second.status, PairingStatus.rejected);
      qaMark('pairing', 'passed');

      final probe = NativeProbe(endpoint: endpoint, secret: password!);
      addTearDown(probe.close);
      final nativeId = await real(
        () => probe.createSession(
          title: 'cw060b smoke',
          directory: projectDir!,
        ),
      );
      await real(() => probe.selectModel(nativeId));
      await real(() => probe.selectAgent(nativeId, 'build'));

      final ref = SessionRef(
        HostId(profile.id),
        HarnessInstanceId(profile.id),
        nativeId,
      );
      final modes = PermissionModeStore(
        store: V2MetadataStore(backend: Metadata()),
      );
      await real(modes.initialize);
      expect(await real(() => modes.setSessionMode(ref, PermissionMode.ask)), isTrue);
      final directory =
          createSessionLiveDirectory(
            payloads: OutboxStore(),
            permissionModes: modes,
          )!;
      // The live lease is closed at the end of the test: the graceful path
      // cancels the SSE recovery (and with it the fake-zone watchdog timer)
      // and settles on real async. Leaving it to the teardown keeps a
      // pending timer behind, which the widget binding reports as a
      // failure.
      final live = SessionLiveController(
        hosts: hosts,
        profile: profile,
        summary: SessionSummary(
          info: SessionInfo(
            ref: ref,
            title: 'cw060b smoke',
            ownership: const OwnershipInfo.unknown(reason: 'live-smoke'),
          ),
          updatedAt: DateTime.now().toUtc(),
        ),
        directory: directory,
        permissionModes: modes,
      );
      addTearDown(live.dispose);
      addTearDown(() => tester.pumpWidget(const SizedBox()));
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: V2Localizations.localizationsDelegates,
          supportedLocales: V2Localizations.supportedLocales,
          home: SessionLivePage(controller: live),
        ),
      );
      await tester.pump();
      await pumpSpin(
        tester,
        () => live.phase == SessionLivePhase.live,
        reason: 'live lease',
        timeout: const Duration(seconds: 60),
      );

      Future<void> send(String marker) async {
        await tester.enterText(
          find.byKey(const ValueKey('live-composer-input')),
          marker,
        );
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('live-composer-send')));
        await tester.pump();
      }

      // P2 — send: a real stub turn streams through the real screens.
      await send('CW060B_SCENARIO_SEND');
      await pumpSpin(
        tester,
        () => timelineHas(live, 'CW060B_STUB_SEND_OK'),
        reason: 'stub streamed text',
        timeout: const Duration(seconds: 60),
      );
      final userRows =
          (live.state?.timeline ?? const [])
              .whereType<UserInput>()
              .where((item) => item.text.contains('CW060B_SCENARIO_SEND'))
              .toList();
      expect(userRows, hasLength(1));
      final wire = await real(() => probe.listMessages(nativeId));
      final assistant = wire.where((item) {
        final model = item['model'];
        return item['type'] == 'assistant' &&
            model is Map &&
            model['providerID'] == 'cw060b';
      }).single;
      // Native cost is a scalar zero on stub turns (tokens break it down).
      expect(assistant['cost'], 0);
      final tokens = assistant['tokens'] as Map;
      expect(tokens['input'], 0);
      expect(tokens['output'], 0);
      // Settle fully before the next send: a prompt admitted while the
      // previous turn is still running would queue instead of starting.
      await pumpSpin(
        tester,
        () => live.state?.execution?.kind.known != ExecutionKind.running,
        reason: 'execution idle after send',
      );
      qaMark('send', 'passed');

      // P3 — tool-originated approval: the stub emits a tool call, the real
      // agent loop pauses, one manual `once` tap settles it.
      await send('CW060B_SCENARIO_APPROVAL');
      await pumpSpin(
        tester,
        () =>
            (live.state?.interactions ?? const []).any(
              (request) => request.kind.known == InteractionKind.permission,
            ),
        reason: 'permission card',
        timeout: const Duration(seconds: 60),
      );
      final toolRequest = permissionRequest(live);
      expect(live.canReply(toolRequest), isTrue);
      await tester.tap(
        find.byKey(
          ValueKey('live-permission-allow-${permissionKeyOf(ref, toolRequest)}'),
        ),
      );
      await tester.pump();
      await pumpSpin(
        tester,
        () => timelineHas(live, 'CW060B_STUB_APPROVAL_OK'),
        reason: 'post-approval stub text',
        timeout: const Duration(seconds: 60),
      );
      await pumpSpin(
        tester,
        () => (live.state?.interactions ?? const []).isEmpty,
        reason: 'interaction settled',
      );
      expect(await real(() => probe.listPermissions(nativeId)), isEmpty);
      qaMark('approval', 'passed');

      // P4 — a manual API-created request needs the tap: the session is in
      // Ask mode, so nothing answers it by itself.
      await real(() => probe.createPermission(nativeId, 'manual-marker'));
      await pumpSpin(
        tester,
        () =>
            (live.state?.interactions ?? const []).any(
              (request) => request.kind.known == InteractionKind.permission,
            ),
        reason: 'manual permission card',
        timeout: const Duration(seconds: 30),
      );
      final manualRequest = permissionRequest(live);
      // The reply port enables only on a live, current view; a fresh native
      // request can leave a brief window where the card is mounted but the
      // action is not yet enabled (a tap there would be a silent no-op,
      // exactly as in the product). Wait for the enabled gate, then reply
      // through the same UI action a user taps.
      await pumpSpin(
        tester,
        () => live.canReply(manualRequest),
        reason: 'manual reply enabled',
        timeout: const Duration(seconds: 30),
      );
      await tester.tap(
        find.byKey(
          ValueKey('live-permission-allow-${permissionKeyOf(ref, manualRequest)}'),
        ),
      );
      await tester.pump();
      // Native settlement is authoritative here: a 204 is admission-only per
      // BEHAVIOR, and a turn-less API-created request emits no turn events,
      // so its card clears only on a later stream/hydration event (P3 showed
      // the turn-driven card removal). The wire proves the reply landed.
      expect(
        await pollPermissionsEmpty(
          probe,
          nativeId,
          const Duration(seconds: 30),
        ),
        isTrue,
        reason: 'manual reply did not settle natively',
      );
      // The manual reply was a one-off `once`: it wrote no persistent rule.
      expect(await real(probe.listSavedPermissions), isEmpty);
      qaMark('approval-manual', 'passed');

      await real(() => probe.deleteSession(nativeId));
      qaMark('final', 'passed');
      // Close the lease so the SSE recovery (and with it the fake-zone
      // watchdog timer) is gone before the fake zone ends. The graceful
      // chain cancels the stream subscription and the parser isolate, which
      // only settles on real async, so it runs in the background while real
      // slices and pumps let it finish.
      live.dispose();
      unawaited(directory.close());
      for (var i = 0; i < 12; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 200)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
    },
    // Skipped without the launcher-owned isolated runtime; the reason string
    // lives here because testWidgets only accepts a bool skip flag.
    skip: upstream == null,
    timeout: const Timeout(Duration(seconds: 540)),
  );

  /// P5–P6 at the directory level with real async: the stub holds a turn
  /// open, the relay drops the transport mid-turn, and Stop settles the
  /// still-running execution. A plain `test` runs outside the widget fake
  /// zone, where recovery timers and stream machinery dispatch normally;
  /// the same flow inside `testWidgets` stalls forever (verified live).
  test(
    'disposable 2.0.22 live recovery and stop at the directory level',
    () async {
      Future<SessionLiveView> waitView(
        SessionLiveHandle handle,
        bool Function(SessionLiveView) matches,
        Duration budget,
        String reason,
      ) async {
        if (matches(handle.current)) return handle.current;
        return handle.updates
            .firstWhere(matches)
            .timeout(
              budget,
              onTimeout: () => throw StateError('timed out waiting for $reason'),
            );
      }

      final relay = await IsolateRelay.bind(Uri.parse(upstream!));
      final endpoint = relay.endpoint;
      final probe = NativeProbe(endpoint: endpoint, secret: password!);
      try {
        final nativeId = await probe.createSession(
          title: 'cw060b recovery',
          directory: projectDir!,
        );
        try {
          await probe.selectModel(nativeId);
          await probe.selectAgent(nativeId, 'build');
          final ref = SessionRef(
            const HostId('live_no_ui'),
            const HarnessInstanceId('live_no_ui'),
            nativeId,
          );
          final modes = PermissionModeStore(
            store: V2MetadataStore(backend: Metadata()),
          );
          await modes.initialize();

          // Phase 1 — the automatic responder, on a direct connection: Allow
          // all (the default for a new install) answers a resident request
          // by itself, once, without a tap and without writing a persistent
          // rule.
          final directProfile = EndpointProfile(
            id: 'live_direct',
            label: 'Native QA direct',
            endpoint: Uri.parse(upstream),
          );
          final directRef = SessionRef(
            const HostId('live_direct'),
            const HarnessInstanceId('live_direct'),
            nativeId,
          );
          final directDirectory =
              createSessionLiveDirectory(
                payloads: OutboxStore(),
                permissionModes: modes,
              )!;
          final directHandle = await directDirectory.open(
            profile: directProfile,
            credential: EndpointCredential(
              kind: EndpointAuthKind.password,
              secret: password,
            ),
            session: directRef,
          );
          try {
            await waitView(
              directHandle,
              (view) =>
                  view.phase == SessionLivePhase.live && !view.stale,
              const Duration(seconds: 30),
              'live lease (direct)',
            );
            final (autoId, autoEffect) = await probe.createPermission(
              nativeId,
              'auto-marker.txt',
            );
            expect(autoEffect, 'ask');
            final autoDeadline = DateTime.now().add(
              const Duration(seconds: 30),
            );
            while (DateTime.now().isBefore(autoDeadline)) {
              if ((await probe.listPermissions(nativeId)).isEmpty) break;
              await Future<void>.delayed(const Duration(milliseconds: 250));
            }
            expect(
              await probe.listPermissions(nativeId),
              isEmpty,
              reason: 'auto-once did not settle without a tap',
            );
            expect(autoId.isNotEmpty, isTrue);
            expect(await probe.listSavedPermissions(), isEmpty);
            qaMark('approval-auto', 'passed');
          } finally {
            directHandle.close();
            await directDirectory.close();
          }

          // Phase 2 — the transport drop and Stop, through the relay.
          final profile = EndpointProfile(
            id: 'live_no_ui',
            label: 'Native QA recovery',
            endpoint: endpoint,
          );
          final directory =
              createSessionLiveDirectory(
                payloads: OutboxStore(),
                permissionModes: modes,
              )!;
          final handle = await directory.open(
            profile: profile,
            credential: EndpointCredential(
              kind: EndpointAuthKind.password,
              secret: password,
            ),
            session: ref,
          );
          try {
            await waitView(
              handle,
              (view) =>
                  view.phase == SessionLivePhase.live && !view.stale,
              const Duration(seconds: 30),
              'live lease',
            );

            final submission = await handle.outbox!.submit(
              session: ref,
              commandId: mintCommandId(),
              draft: PromptDraft(text: 'CW060B_SCENARIO_HOLD'),
              delivery: Delivery.steer,
            );
            expect(submission.sent, isTrue);
            expect(submission.entry?.state, SubmissionKind.admitted);
            await waitView(
              handle,
              (view) =>
                  view.state?.execution?.kind.known == ExecutionKind.running,
              const Duration(seconds: 30),
              'running execution',
            );
            expect(handle.canStop, isTrue);

            // Drop the transport mid-turn: the client must observe the
            // disconnect while the server-side turn keeps running.
            await relay.cut();
            try {
              await waitView(
                handle,
                (view) => view.phase == SessionLivePhase.reconnecting,
                const Duration(seconds: 30),
                'reconnecting phase',
              );
              expect(
                handle.current.state?.execution?.kind.known,
                ExecutionKind.running,
              );
              qaMark('reconnect-detection', 'passed');
            } finally {
              await relay.restore();
            }

            // Recovery completes against the restored transport with the
            // turn still running; Stop then settles it.
            await waitView(
              handle,
              (view) =>
                  view.phase == SessionLivePhase.live && !view.stale,
              const Duration(seconds: 45),
              'live again after restore',
            );
            await waitView(
              handle,
              (view) =>
                  view.state?.execution?.kind.known == ExecutionKind.running,
              const Duration(seconds: 15),
              'execution survived reconnect',
            );
            await handle.stop(id: mintCommandId());
            await waitView(
              handle,
              (view) =>
                  view.state?.execution?.kind.known != ExecutionKind.running,
              const Duration(seconds: 30),
              'stop settles execution',
            );
            qaMark('stop-reconnect', 'passed');

            // Idle interrupt is a confirmed no-op, never a Stop pass.
            expect(await probe.interrupt(nativeId), isFalse);
            expect(handle.canStop, isFalse);
            qaMark('stop-idle', 'passed');
          } finally {
            handle.close();
            await directory.close();
          }
          await probe.deleteSession(nativeId);
        } catch (_) {
          await probe.deleteSession(nativeId);
          rethrow;
        }
      } finally {
        relay.close();
        probe.close();
      }
      qaMark('final', 'passed');
    },
    skip: upstream == null
        ? 'Requires explicitly authorized isolated native 2.0.22 runtime'
        : false,
    timeout: const Timeout(Duration(seconds: 300)),
  );
}
