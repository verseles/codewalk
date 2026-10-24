import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:codewalk/app/composition_root.dart';
import 'package:codewalk/app/v2_bootstrap.dart';
import 'package:codewalk/features/hosts/hosts_controller.dart';
import 'package:codewalk/features/sessions/session_error_card.dart';
import 'package:codewalk/features/sessions/session_live_controller.dart';
import 'package:codewalk/features/sessions/session_live_page.dart';
import 'package:codewalk/features/sessions/session_permission_card.dart'
    show permissionKeyOf;
import 'package:codewalk/platform/endpoints/pairing_factory_io.dart';
import 'package:codewalk/platform/endpoints/probe_factory_io.dart';
import 'package:codewalk/platform/profiles/endpoint_profile_store.dart';
import 'package:codewalk/platform/sessions/permission_mode_store.dart';
import 'package:codewalk/platform/sessions/session_draft_store.dart';
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
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

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
  final workspaceSmoke =
      io.Platform.environment['CODEWALK_LIVE_SMOKE_UNIT'] == 'V2-060C';

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
  /// completes), while the real slice gives the live socket time. The fake
  /// step is smaller than the real one, so the fake clock runs *slower* than
  /// wall-clock time: the product's 45-second SSE watchdog then elapses later
  /// in real time than it would in production, and a healthy stream cannot
  /// trip it early.
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
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 10));
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
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump(const Duration(milliseconds: 10));
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
      // The launcher derives the zero-spend claim from this marker: the
      // evidence cannot assert a cost the suite did not observe.
      qaMark('native-cost', 'passed', {'cost': assistant['cost']});
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
      await tester.pumpWidget(const SizedBox.shrink());
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

  testWidgets(
    'disposable 2.0.22 integrated workspace flow through the root app',
    (tester) async {
      Future<T> real<T>(Future<T> Function() action) async =>
          (await tester.runAsync(action)) as T;

      final previousPrefs = SharedPreferencesAsyncPlatform.instance;
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      addTearDown(
        () => SharedPreferencesAsyncPlatform.instance = previousPrefs,
      );
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final probe = NativeProbe(
        endpoint: Uri.parse(upstream!),
        secret: password!,
      );
      addTearDown(probe.close);
      final metadata = V2MetadataStore(backend: Metadata());
      final repository = EndpointProfileStore(
        metadata: metadata,
        credentials: EndpointCredentialVault(
          backend: Secrets(),
          beforeMutation: metadata.ensureSchema,
        ),
      );
      final modes = PermissionModeStore(store: metadata);
      await real(modes.initialize);
      final payloads = OutboxStore();
      final directory = createSessionLiveDirectory(
        payloads: payloads,
        permissionModes: modes,
      )!;
      final dependencies = createAppDependencies(
        initialLink: Uri(path: '/pair'),
        metadataStore: metadata,
        profileRepository: repository,
        endpointPairing: createEndpointPairing(),
        permissionModeStore: modes,
        sessionLiveDirectory: () => directory,
        draftStore: SessionDraftStore(payloads: payloads, index: metadata),
      );
      await real(dependencies.sessionTabs!.initialize);
      await real(dependencies.sessions!.initialize);
      dependencies.preferences.setLocale(const Locale('en'));
      final nativeIds = <String>[];
      var cleanedUp = false;
      // This also runs after an assertion fails: no stream watchdog or native
      // session may leak into the next test or the user's persistent state.
      Future<void> cleanUp() async {
        if (cleanedUp) return;
        // Capture the first close future: root disposal also calls close,
        // whose later invocations return before the first shutdown finishes.
        final closing = directory.close();
        await tester.pumpWidget(const SizedBox.shrink());
        var closed = false;
        unawaited(closing.then((_) => closed = true));
        await pumpSpin(
          tester,
          () => closed,
          reason: 'workspace directory closed',
        );
        for (final id in nativeIds) {
          await real(() => probe.deleteSession(id));
        }
        cleanedUp = true;
      }
      addTearDown(cleanUp);
      await tester.pumpWidget(CodeWalkV2Bootstrap(dependencies: dependencies));
      await tester.pumpAndSettle();
      final code = await real(probe.createPairingCode);
      await tester.enterText(
        find.byKey(const ValueKey('pairing-link')),
        '$upstream/auth/connect/$code',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('confirm-pairing')));
      await pumpSpin(
        tester,
        () => find.byKey(const ValueKey('save-pairing')).evaluate().isNotEmpty,
        reason: 'workspace pairing redeemed',
        timeout: const Duration(seconds: 30),
      );
      await tester.tap(find.byKey(const ValueKey('save-pairing')));
      await pumpSpin(
        tester,
        () => dependencies.hosts.profiles.isNotEmpty,
        reason: 'workspace profile saved',
      );
      final profile = dependencies.hosts.profiles.single;
      // Saving reloads the host catalog and its credentials. Profile presence
      // precedes that reload; selectProfile intentionally refuses while busy.
      await pumpSpin(
        tester,
        () => !dependencies.hosts.loading &&
            !dependencies.pairing!.busy &&
            dependencies.hosts.credentialFor(profile) != null,
        reason: 'paired host credential reload complete',
      );
      expect(
        (await real(() => repository.readCredential(profile)))?.kind,
        EndpointAuthKind.paired,
      );
      qaMark('workspace-pairing', 'passed');

      for (var i = 0; i < 2; i++) {
        final id = await real(
          () => probe.createSession(
            title: 'cw060c workspace $i',
            directory: projectDir!,
          ),
        );
        nativeIds.add(id);
        await real(() => probe.selectModel(id));
        await real(() => probe.selectAgent(id, 'build'));
      }
      SessionRef ref(String id) =>
          SessionRef(HostId(profile.id), HarnessInstanceId(profile.id), id);
      final primary = ref(nativeIds.first);
      final sibling = ref(nativeIds.last);
      expect(
        await real(() => modes.setSessionMode(primary, PermissionMode.ask)),
        isTrue,
      );
      dependencies.router.go('/sessions');
      await tester.pump();
      final selecting = dependencies.sessions!.selectProfile(profile.id);
      await pumpSpin(
        tester,
        () {
          final catalog = dependencies.sessions!;
          if (catalog.failure != null) {
            fail('Native catalog failed: ${catalog.failure}');
          }
          return nativeIds.every((id) => catalog.sessions
              .any((row) => row.info.ref.nativeId == id));
        },
        reason: 'native workspace catalog',
      );
      await selecting;
      expect(find.byKey(const ValueKey('workspace-sidebar')), findsOneWidget);
      expect(find.byKey(const ValueKey('workspace-empty')), findsOneWidget);
      qaMark('workspace', 'passed');

      Future<void> open(SessionRef session) async {
        final row = find.byKey(ValueKey<SessionRef>(session));
        await tester.ensureVisible(row);
        await tester.tap(row);
        await tester.pump();
        final button = find.byKey(ValueKey('live-open-${session.storageKey}'));
        await pumpSpin(
          tester,
          () => button.evaluate().isNotEmpty,
          reason: 'workspace open action',
        );
        await tester.ensureVisible(button);
        await tester.tap(button);
        await pumpSpin(
          tester,
          () => dependencies.sessionTabs!.selectedFor(session.host) == session,
          reason: 'workspace selected tab',
        );
      }

      await open(sibling);
      await open(primary);
      expect(find.byKey(const ValueKey('session-tabs')), findsOneWidget);
      for (final session in [sibling, primary]) {
        final tab = find.byKey(ValueKey('session-tab-${session.storageKey}'));
        expect(tab, findsOneWidget);
        await tester.tap(tab);
        await pumpSpin(
          tester,
          () => dependencies.sessionTabs!.selectedFor(session.host) == session,
          reason: 'workspace switch tab',
        );
      }
      qaMark('workspace-tab', 'passed');
      final live = tester
          .widget<SessionLivePage>(find.byType(SessionLivePage))
          .controller;
      await pumpSpin(
        tester,
        () => live.phase == SessionLivePhase.live,
        reason: 'workspace live stream',
      );
      Future<void> send(String text) async {
        final input = find.byKey(const ValueKey('live-composer-input'));
        await tester.enterText(input, text);
        await tester.pump();
        final send = find.byKey(const ValueKey('live-composer-send'));
        await tester.tap(send);
        await pumpSpin(
          tester,
          () =>
              tester.widget<TextField>(input).controller!.text.isEmpty &&
              !live.composer.sending,
          reason: 'workspace prompt admitted',
        );
      }

      await send('CW060B_SCENARIO_SEND workspace');
      await pumpSpin(
        tester,
        () => timelineHas(live, 'CW060B_STUB_SEND_OK'),
        reason: 'workspace streamed send',
        timeout: const Duration(seconds: 30),
      );
      final messages = await real(() => probe.listMessages(primary.nativeId));
      final assistants = messages.where(
        (row) => row['type'] == 'assistant',
      );
      expect(assistants, isNotEmpty);
      for (final message in assistants) {
        expect(message['cost'], 0);
      }
      await pumpSpin(
        tester,
        () => live.state?.execution?.kind.known != ExecutionKind.running,
        reason: 'workspace first turn complete',
      );
      qaMark('workspace-send', 'passed');

      await send('CW060B_SCENARIO_HOLD workspace');
      await pumpSpin(tester, () => live.canStop, reason: 'workspace held turn');
      await tester.enterText(
        find.byKey(const ValueKey('live-composer-input')),
        'workspace steer while holding',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('live-delivery-steer')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('live-composer-send')));
      await pumpSpin(
        tester,
        () =>
            tester
                .widget<TextField>(
                  find.byKey(const ValueKey('live-composer-input')),
                )
                .controller!
                .text
                .isEmpty &&
            !live.composer.sending,
        reason: 'workspace steer admitted',
      );
      qaMark('workspace-steer', 'passed');
      await pumpSpin(
        tester,
        () => find.byKey(const ValueKey('live-stop')).evaluate().isNotEmpty,
        reason: 'workspace stop enabled',
      );
      await tester.tap(find.byKey(const ValueKey('live-stop')));
      await pumpSpin(
        tester,
        () => live.state?.execution?.kind.known != ExecutionKind.running,
        reason: 'workspace turn interrupted',
        timeout: const Duration(seconds: 30),
      );
      expect(live.canStop, isFalse);
      qaMark('workspace-stop', 'passed');

      await real(
        () => probe.createPermission(primary.nativeId, 'workspace-manual'),
      );
      await pumpSpin(
        tester,
        () => (live.state?.interactions ?? const []).any(
          (r) => r.kind.known == InteractionKind.permission,
        ),
        reason: 'workspace permission card',
      );
      final permission = permissionRequest(live);
      await pumpSpin(
        tester,
        () => live.canReply(permission),
        reason: 'workspace permission enabled',
      );
      final allow = find.byKey(
        ValueKey(
          'live-permission-allow-${permissionKeyOf(primary, permission)}',
        ),
      );
      await tester.ensureVisible(allow);
      await tester.tap(allow);
      await pumpSpin(
        tester,
        () async =>
            (await real(() => probe.listPermissions(primary.nativeId))).isEmpty,
        reason: 'workspace permission settled natively',
      );
      expect(await real(probe.listSavedPermissions), isEmpty);
      qaMark('workspace-approval', 'passed');

      final formId = await real(() => probe.createForm(primary.nativeId));
      await pumpSpin(
        tester,
        () => find.byKey(ValueKey('live-form-$formId')).evaluate().isNotEmpty,
        reason: 'workspace form card',
      );
      final choice = find.byKey(const ValueKey('form-option-choice-alpha'));
      await tester.ensureVisible(choice);
      await tester.tap(choice);
      await tester.pump();
      final submit = find.byKey(ValueKey('form-submit-$formId'));
      await pumpSpin(
        tester,
        () => tester.widget<FilledButton>(submit).onPressed != null,
        reason: 'workspace form enabled',
      );
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await pumpSpin(
        tester,
        () async =>
            (await real(() => probe.listForms(primary.nativeId))).isEmpty,
        reason: 'workspace form settled natively',
      );
      final nativeForm = await real(
        () => probe.readForm(primary.nativeId, formId),
      );
      expect((nativeForm['state'] as Map)['answer'], {'choice': 'alpha'});
      qaMark('workspace-form', 'passed');

      await tester.tap(find.byKey(const ValueKey('live-selection')));
      await tester.pumpAndSettle();
      final alternate = find.byKey(
        const ValueKey('live-selection-model-cw060b/stub-alt'),
      );
      await tester.ensureVisible(alternate);
      await tester.tap(alternate);
      await pumpSpin(
        tester,
        () async =>
            ((await real(() => probe.readSession(primary.nativeId)))['model']
                as Map?)?['id'] ==
            'stub-alt',
        reason: 'workspace native model switch',
      );
      await pumpSpin(
        tester,
        () => live.selectionState.selection?.modelId == 'stub-alt',
        reason: 'workspace model chip switched',
      );
      qaMark('workspace-model-switch', 'passed');

      await send('CW060B_SCENARIO_ERROR workspace');
      await pumpSpin(
        tester,
        () => find.byType(SessionErrorCard).evaluate().isNotEmpty,
        reason: 'workspace native provider error',
        timeout: const Duration(seconds: 30),
      );
      final error = tester.widget<SessionErrorCard>(
        find.byType(SessionErrorCard),
      );
      expect(
        error.error.rawMessage,
        contains('cw060c simulated provider auth failure'),
      );
      expect(find.byKey(const ValueKey('live-error-action')), findsOneWidget);
      expect(tester.takeException(), isNull);
      qaMark('workspace-error', 'passed');
      // Widget binding checks timers before addTearDown, so close on success
      // here as well as retaining the failure cleanup above.
      await cleanUp();
    },
    skip: upstream == null || !workspaceSmoke,
    timeout: const Timeout(Duration(seconds: 300)),
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
