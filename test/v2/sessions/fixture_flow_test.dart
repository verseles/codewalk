import 'dart:async';

import 'package:codewalk/features/hosts/hosts_controller.dart';
import 'package:codewalk/features/sessions/session_composer_controller.dart';
import 'package:codewalk/features/sessions/session_history_controller.dart';
import 'package:codewalk/features/sessions/session_live_controller.dart';
import 'package:codewalk/features/sessions/sessions_controller.dart';
import 'package:codewalk/platform/sessions/session_catalog_factory_io.dart';
import 'package:codewalk/platform/sessions/session_history_factory_io.dart';
import 'package:codewalk/shared/sessions/permission_mode.dart';
import 'package:codewalk/shared/sessions/session_live_source.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../packages/harness_opencode/test/support/fake_opencode_server.dart';
import '../../../packages/harness_opencode/test/support/fixture_replay.dart';
import '../hosts/fakes.dart';
import 'fixture_flow_support.dart';

/// Layer-1 integrated coverage (V2-060A): real IO factories plus the real
/// controllers and the real live directory, driven against the
/// fixture-backed [FakeOpenCodeServer]. No widgets, no hand-rolled
/// transport fakes.
void main() {
  late OpenCodeFixtures fx;
  late Map<String, Object?> sesRow;
  late List<Map<String, Object?>> bRows;

  setUp(() {
    fx = OpenCodeFixtures();
    sesRow = bSessionRow(fx);
    bRows = bMessageRows(fx);
  });

  Future<HostsController> makeHosts(FixtureFlowRig rig) async {
    final hosts = HostsController(
      repository: rig.profiles,
      prober: FakeProber(),
    );
    await hosts.load();
    return hosts;
  }

  /// Waits for the app to open SSE epoch [index], then emits its first
  /// (connected) frame. Epochs never self-emit; nothing hydrates before this.
  Future<void> openEpoch(FakeOpenCodeServer server, int index) async {
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (server.streams.length <= index) {
      if (DateTime.now().isAfter(deadline)) {
        throw TimeoutException('SSE epoch $index never opened');
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    await server.streams[index].emitNext();
  }

  Future<SessionLiveView> untilLive(SessionLiveController live) async {
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    for (;;) {
      final view = live.view;
      if (view != null &&
          view.phase == SessionLivePhase.live &&
          view.state != null) {
        return view;
      }
      if (DateTime.now().isAfter(deadline)) {
        throw TimeoutException('live view never settled');
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  Future<void> untilTrue(FutureOr<bool> Function() test) async {
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (!await test()) {
      if (DateTime.now().isAfter(deadline)) {
        throw TimeoutException('condition never became true');
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  /// Shared live-controller wiring against the rig's real directory.
  Future<SessionLiveController> openLive(
    FixtureFlowRig rig,
    HostsController hosts,
    EndpointProfile profile,
    SessionSummary summary,
  ) async {
    final live = SessionLiveController(
      hosts: hosts,
      profile: profile,
      summary: summary,
      directory: rig.openDirectory(),
      permissionModes: rig.modes,
      commandIds: rig.nextCommand,
    );
    addTearDown(live.dispose);
    await live.start();
    return live;
  }

  group('V2-060A integrated fixture flow (Layer 1)', () {
    test('catalog lists captured sessions through the real source', () async {
      final scenario = FixtureScenario.routed(
        'flow/catalog',
        routes: [
          FixtureRoute(
            FixtureExchange.fromCapture({
              'method': 'GET',
              'path': '/api/session?limit=50&order=desc',
              'request': null,
              'status': 200,
              'response': {
                'data': [sesRow],
                'cursor': {'previous': null, 'next': null},
              },
            }, 'flow/catalog'),
            times: 2,
          ),
        ],
        streams: const [],
      );
      final rig = await FixtureFlowRig.start(scenario: scenario);
      final (:profile, :credential) = await rig.addProfile(
        'profile_a',
        'Profile A',
      );
      final source = createSessionCatalogSource(profile, credential);
      addTearDown(source.close);
      final page = await source.list(SessionQuery(limit: 50)).result;
      expect(page.items, hasLength(1));
      expect(page.items.single.info.ref.nativeId, bSessionId);
      expect(page.items.single.info.title, isNotEmpty);
      expect(
        page.items.single.info.ref.harnessRef,
        const HarnessRef(HostId('profile_a'), HarnessInstanceId('profile_a')),
      );
      await rig.server.close();
      rig.server.assertHealthy();
    });

    test(
      'history hydrates captured timeline through the real source',
      () async {
        final scenario = FixtureScenario.routed(
          'flow/history',
          routes: sessionRoutes(sessionRow: sesRow, messageRows: bRows),
          streams: const [],
        );
        final rig = await FixtureFlowRig.start(scenario: scenario);
        final added = await rig.addProfile('profile_a', 'Profile A');
        final hosts = await makeHosts(rig);
        addTearDown(hosts.dispose);
        final sessions = SessionsController(
          hosts: hosts,
          sourceFactory: createSessionCatalogSource,
        );
        addTearDown(sessions.dispose);
        await sessions.initialize();
        await sessions.selectProfile('profile_a');
        expect(sessions.sessions, hasLength(1));
        final history = SessionHistoryController(
          hosts: hosts,
          profile: added.profile,
          summary: sessions.sessions.single,
          sourceFactory: createSessionHistorySource,
        );
        addTearDown(history.dispose);
        await history.refresh();
        expect(history.items, isNotEmpty);
        expect(
          history.items.whereType<UserInput>().map((i) => i.text).join(' '),
          contains('marker'),
        );
        await rig.server.close();
        rig.server.assertHealthy();
      },
    );

    test(
      'live attach streams captured turns through the real directory',
      () async {
        // Epoch: reconnected `server.connected` (gates live), then the
        // captured partial turn: connected (duplicate, ignored), enqueued
        // (dropped by the current contract: no `delivery` field in this
        // capture), execution.started, instructions.updated.
        final epoch0 = [
          fx.reconnect().streams.first.frames.first,
          ...bStreamFrames(fx, 'partialStream').take(4),
        ];
        final scenario = FixtureScenario.routed(
          'flow/live-attach',
          routes: sessionRoutes(sessionRow: sesRow, messageRows: bRows),
          streams: [FixtureStream('epoch0', epoch0)],
        );
        final rig = await FixtureFlowRig.start(scenario: scenario);
        final (:profile, :credential) = await rig.addProfile(
          'profile_a',
          'Profile A',
        );
        final directory = rig.openDirectory();
        addTearDown(directory.close);
        final session = rig.ref('profile_a', bSessionId);
        final handle = await directory.open(
          profile: profile,
          credential: credential,
          session: session,
        );
        addTearDown(handle.close);
        await openEpoch(rig.server, 0);
        await until(
          handle.updates,
          (v) => v.phase == SessionLivePhase.live && v.state != null,
        );
        // Subscribe before emitting: emission may complete before we listen.
        final running = until(
          handle.updates,
          (v) =>
              v.phase == SessionLivePhase.live &&
              v.state?.execution?.kind.known == ExecutionKind.running,
        );
        // connected (duplicate) + enqueued (dropped) + started + instructions.
        for (var i = 0; i < 3; i++) {
          await rig.server.streams[0].emitNext();
        }
        final turned = await running;
        expect(turned.state!.execution?.kind.known, ExecutionKind.running);
        expect(turned.state!.timeline, isNotEmpty);
        await rig.server.close();
        rig.server.assertHealthy();
      },
    );

    test('lost admission reconciles without duplicate POST', () async {
      final postedIds = <String>[];
      final scenario = FixtureScenario.routed(
        'flow/lost-admission',
        routes: [
          ...sessionRoutes(sessionRow: sesRow, messageRows: bRows),
          FixtureRoute(
            FixtureExchange.fromCapture({
              'method': 'POST',
              'path': '/api/session/$bSessionId/prompt',
              'request': null,
              'status': 200,
              'response': null,
            }, 'flow/prompt'),
            // Exactly two admissions: the dropped attempt plus one replay.
            // A third POST would 409 and fail the test loudly.
            matchBody: false,
            times: 2,
            respond: (body) {
              final req = body as Map<String, Object?>;
              postedIds.add(req['id'] as String);
              return promptAdmissionEcho(req);
            },
          ),
        ],
        streams: [
          FixtureStream('epoch0', [fx.reconnect().streams.first.frames.first]),
        ],
      );
      final rig = await FixtureFlowRig.start(scenario: scenario);
      final (:profile, :credential) = await rig.addProfile(
        'profile_a',
        'Profile A',
      );
      final hosts = await makeHosts(rig);
      addTearDown(hosts.dispose);
      final sessions = SessionsController(
        hosts: hosts,
        sourceFactory: createSessionCatalogSource,
      );
      addTearDown(sessions.dispose);
      await sessions.initialize();
      await sessions.selectProfile('profile_a');
      final live = await openLive(
        rig,
        hosts,
        profile,
        sessions.sessions.single,
      );
      await openEpoch(rig.server, 0);
      await untilLive(live);
      var sends = 0;
      final composer = SessionComposerController(
        live: live,
        commandIds: () => CommandId('cmd_${++sends}'),
      );
      addTearDown(composer.dispose);
      // Drop the admission response mid-flight. The composer auto-checks a
      // fresh uncertain send once: reconcile finds no trace and replays the
      // exact recorded id, so one drop yields exactly one retry.
      final gate = rig.server.holdNextExchange();
      final sending = composer.send('Repeat after me');
      expect(composer.sending, isTrue);
      expect(await gate.admitted, isTrue);
      gate.drop();
      expect(await sending, isTrue);
      expect(postedIds, hasLength(2));
      expect(postedIds[0], postedIds[1]);
      final entry = composer.entries.singleWhere(
        (e) => e.commandId.value == 'cmd_1',
      );
      expect(entry.state, SubmissionKind.admitted);
      expect(composer.notice, ComposerNotice.none);
      await rig.server.close();
      rig.server.assertHealthy();
    });

    test('identical prompts create two distinct entries', () async {
      final postedIds = <String>[];
      final scenario = FixtureScenario.routed(
        'flow/identical-prompts',
        routes: [
          ...sessionRoutes(sessionRow: sesRow, messageRows: bRows),
          FixtureRoute(
            FixtureExchange.fromCapture({
              'method': 'POST',
              'path': '/api/session/$bSessionId/prompt',
              'request': null,
              'status': 200,
              'response': null,
            }, 'flow/prompt-twice'),
            matchBody: false,
            times: 10,
            respond: (body) {
              final req = body as Map<String, Object?>;
              postedIds.add(req['id'] as String);
              return promptAdmissionEcho(req);
            },
          ),
        ],
        streams: [
          FixtureStream('epoch0', [fx.reconnect().streams.first.frames.first]),
        ],
      );
      final rig = await FixtureFlowRig.start(scenario: scenario);
      final (:profile, :credential) = await rig.addProfile(
        'profile_a',
        'Profile A',
      );
      final hosts = await makeHosts(rig);
      addTearDown(hosts.dispose);
      final sessions = SessionsController(
        hosts: hosts,
        sourceFactory: createSessionCatalogSource,
      );
      addTearDown(sessions.dispose);
      await sessions.initialize();
      await sessions.selectProfile('profile_a');
      final live = await openLive(
        rig,
        hosts,
        profile,
        sessions.sessions.single,
      );
      await openEpoch(rig.server, 0);
      await untilLive(live);
      var sends = 0;
      final composer = SessionComposerController(
        live: live,
        commandIds: () => CommandId('cmd_${++sends}'),
      );
      addTearDown(composer.dispose);
      expect(await composer.send('Repeat me'), isTrue);
      expect(await composer.send('Repeat me'), isTrue);
      expect(postedIds, hasLength(2));
      expect(postedIds[0], isNot(postedIds[1]));
      expect(composer.notice, ComposerNotice.none);
      final entries = composer.entries
          .where((e) => e.commandId.value.startsWith('cmd_'))
          .toList();
      expect(entries.map((e) => e.messageId).toSet(), hasLength(2));
      await rig.server.close();
      rig.server.assertHealthy();
    });

    test('inbox promotion marks the uncertain entry delivered', () async {
      // Deterministic promotion without duplicates: the desc history route
      // serves whatever the client has posted so far. The first reconcile
      // after the failed admission therefore finds the message and marks it
      // delivered instead of replaying.
      final postedIds = <String>[];
      final scenario = FixtureScenario.routed(
        'flow/inbox-promotion',
        routes: [
          ...sessionRoutes(
            sessionRow: sesRow,
            messageRows: bRows,
            descRows: () => [
              for (final id in postedIds.take(1))
                {
                  'id': id,
                  'time': {'created': 1791089345000},
                  'text': 'Promote me',
                  'type': 'user',
                },
              ...bRows.reversed,
            ],
          ),
          FixtureRoute(
            FixtureExchange.fromCapture({
              'method': 'POST',
              'path': '/api/session/$bSessionId/prompt',
              'request': null,
              'status': 200,
              'response': null,
            }, 'flow/prompt-promote'),
            matchBody: false,
            times: 10,
            respond: (body) {
              final req = body as Map<String, Object?>;
              postedIds.add(req['id'] as String);
              return promptAdmissionEcho(req);
            },
            statusOverrides: const [503],
          ),
        ],
        streams: [
          FixtureStream('epoch0', [fx.reconnect().streams.first.frames.first]),
        ],
      );
      final rig = await FixtureFlowRig.start(scenario: scenario);
      final (:profile, :credential) = await rig.addProfile(
        'profile_a',
        'Profile A',
      );
      final hosts = await makeHosts(rig);
      addTearDown(hosts.dispose);
      final sessions = SessionsController(
        hosts: hosts,
        sourceFactory: createSessionCatalogSource,
      );
      addTearDown(sessions.dispose);
      await sessions.initialize();
      await sessions.selectProfile('profile_a');
      final live = await openLive(
        rig,
        hosts,
        profile,
        sessions.sessions.single,
      );
      await openEpoch(rig.server, 0);
      await untilLive(live);
      var sends = 0;
      final composer = SessionComposerController(
        live: live,
        commandIds: () => CommandId('cmd_${++sends}'),
      );
      addTearDown(composer.dispose);
      expect(await composer.send('Promote me'), isTrue);
      expect(postedIds, hasLength(1));
      final delivered = composer.entries
          .where((e) => e.commandId.value == 'cmd_1')
          .toList();
      expect(delivered, hasLength(1));
      expect(delivered.single.state, SubmissionKind.delivered);
      await rig.server.close();
      rig.server.assertHealthy();
    });

    test('interrupted stream reconnects without losing state', () async {
      final epoch0 = [
        fx.reconnect().streams.first.frames.first,
        ...bStreamFrames(fx, 'partialStream').take(3),
      ];
      final epoch1 = [fx.reconnect().streams.first.frames.first];
      final scenario = FixtureScenario.routed(
        'flow/reconnect',
        routes: sessionRoutes(sessionRow: sesRow, messageRows: bRows),
        streams: [
          FixtureStream('epoch0', epoch0),
          FixtureStream('epoch1', epoch1),
        ],
      );
      final rig = await FixtureFlowRig.start(scenario: scenario);
      final (:profile, :credential) = await rig.addProfile(
        'profile_a',
        'Profile A',
      );
      final directory = rig.openDirectory();
      addTearDown(directory.close);
      final session = rig.ref('profile_a', bSessionId);
      final handle = await directory.open(
        profile: profile,
        credential: credential,
        session: session,
      );
      addTearDown(handle.close);
      await openEpoch(rig.server, 0);
      await until(
        handle.updates,
        (v) => v.phase == SessionLivePhase.live && v.state != null,
      );
      // Drive the captured partial turn, then wait for running execution.
      final running = until(
        handle.updates,
        (v) =>
            v.phase == SessionLivePhase.live &&
            v.state != null &&
            v.state!.execution?.kind.known == ExecutionKind.running,
      );
      await rig.server.streams[0].emitNext();
      await rig.server.streams[0].emitNext();
      await rig.server.streams[0].emitNext();
      await running;
      final before = handle.current.state!.timeline.length;
      // Clean EOF mid-turn: the app must reconnect and re-hydrate.
      await rig.server.streams[0].finish();
      await untilTrue(() async => rig.server.streams.length == 2);
      await openEpoch(rig.server, 1);
      final back = await until(
        handle.updates,
        (v) =>
            v.phase == SessionLivePhase.live &&
            v.state != null &&
            v.state!.timeline.length == before,
      );
      expect(back.state!.timeline.length, before);
      expect(back.phase, SessionLivePhase.live);
      await rig.server.close();
      rig.server.assertHealthy();
    });

    test('colliding native ids stay isolated across profiles', () async {
      final postedIds = <String>[];
      final scenario = FixtureScenario.routed(
        'flow/collide',
        routes: [
          ...sessionRoutes(sessionRow: sesRow, messageRows: bRows),
          FixtureRoute(
            FixtureExchange.fromCapture({
              'method': 'POST',
              'path': '/api/session/$bSessionId/prompt',
              'request': null,
              'status': 200,
              'response': null,
            }, 'flow/prompt-collide'),
            matchBody: false,
            times: 10,
            respond: (body) {
              final req = body as Map<String, Object?>;
              postedIds.add(req['id'] as String);
              return promptAdmissionEcho(req);
            },
          ),
        ],
        streams: [
          FixtureStream('epochA', [fx.reconnect().streams.first.frames[0]]),
          FixtureStream('epochB', [fx.reconnect().streams.first.frames[0]]),
        ],
      );
      final rig = await FixtureFlowRig.start(scenario: scenario);
      final addedA = await rig.addProfile('profile_a', 'Profile A');
      final addedB = await rig.addProfile('profile_b', 'Profile B');
      final hosts = await makeHosts(rig);
      addTearDown(hosts.dispose);
      final sessions = SessionsController(
        hosts: hosts,
        sourceFactory: createSessionCatalogSource,
      );
      addTearDown(sessions.dispose);
      await sessions.initialize();
      await sessions.selectProfile('profile_a');
      final summaryA = sessions.sessions.single;
      expect(
        summaryA.info.ref.harnessRef,
        isNot(
          const HarnessRef(HostId('profile_b'), HarnessInstanceId('profile_b')),
        ),
      );
      await sessions.selectProfile('profile_b');
      final summaryB = sessions.sessions.single;
      expect(summaryB.info.ref.nativeId, bSessionId);
      expect(summaryB.info.ref, isNot(summaryA.info.ref));
      final directory = rig.openDirectory();
      addTearDown(directory.close);
      final liveA = SessionLiveController(
        hosts: hosts,
        profile: addedA.profile,
        summary: summaryA,
        directory: directory,
        permissionModes: rig.modes,
        commandIds: rig.nextCommand,
      );
      addTearDown(liveA.dispose);
      await liveA.start();
      await openEpoch(rig.server, 0);
      await untilLive(liveA);
      final liveB = SessionLiveController(
        hosts: hosts,
        profile: addedB.profile,
        summary: summaryB,
        directory: directory,
        permissionModes: rig.modes,
        commandIds: rig.nextCommand,
      );
      addTearDown(liveB.dispose);
      await liveB.start();
      await openEpoch(rig.server, 1);
      await untilLive(liveB);
      // Send only on A: B must stay empty and no cross-talk may occur.
      var sends = 0;
      final composerA = SessionComposerController(
        live: liveA,
        commandIds: () => CommandId('cmdA_${++sends}'),
      );
      addTearDown(composerA.dispose);
      final composerB = SessionComposerController(
        live: liveB,
        commandIds: () => CommandId('cmdB_${++sends}'),
      );
      addTearDown(composerB.dispose);
      expect(await composerA.send('Only for A'), isTrue);
      expect(postedIds, hasLength(1));
      expect(composerB.entries, isEmpty);
      expect(liveA.session, isNot(liveB.session));
      await rig.server.close();
      rig.server.assertHealthy();
    });

    test('manual permission reply settles exactly once via stream', () async {
      final permRows = cPermissionRows(fx, bSessionId);
      final reqId = permRows.single['id'] as String;
      var replies = 0;
      final settledFrames = cPermissionRepliedFrames(fx, bSessionId, reqId);
      final scenario = FixtureScenario.routed(
        'flow/permission-manual',
        routes: [
          ...sessionRoutes(
            sessionRow: sesRow,
            messageRows: bRows,
            permissionRows: permRows,
          ),
          FixtureRoute(
            FixtureExchange.fromCapture({
              'method': 'POST',
              'path': '/api/session/$bSessionId/permission/$reqId/reply',
              'request': {'decision': 'once'},
              'status': 204,
              'response': null,
            }, 'flow/permission-reply'),
            times: 1,
            respond: (_) {
              replies++;
              return null;
            },
          ),
        ],
        streams: [
          FixtureStream('epoch0', [
            fx.reconnect().streams.first.frames.first,
            ...settledFrames,
          ]),
        ],
      );
      final rig = await FixtureFlowRig.start(scenario: scenario);
      final (:profile, :credential) = await rig.addProfile(
        'profile_a',
        'Profile A',
      );
      final directory = rig.openDirectory();
      addTearDown(directory.close);
      // Ask mode: nothing is answered without an explicit tap.
      await rig.modes.setSessionMode(
        rig.ref('profile_a', bSessionId),
        PermissionMode.ask,
      );
      final session = rig.ref('profile_a', bSessionId);
      final handle = await directory.open(
        profile: profile,
        credential: credential,
        session: session,
      );
      addTearDown(handle.close);
      await openEpoch(rig.server, 0);
      final resident = await until(
        handle.updates,
        (v) =>
            v.phase == SessionLivePhase.live &&
            v.state != null &&
            v.state!.interactions.any(
              (r) =>
                  r.kind.known == InteractionKind.permission &&
                  r.id.value == reqId,
            ),
      );
      final request = resident.state!.interactions.singleWhere(
        (r) => r.kind.known == InteractionKind.permission,
      );
      expect(handle.canReply(request), isTrue);
      await handle.reply(
        request: request,
        response: ApprovalResponse('once'),
        id: const CommandId('cmd_manual_1'),
      );
      expect(replies, 1);
      // Authoritative settlement arrives on the stream; the card goes away.
      await rig.server.streams[0].emitRemaining();
      await until(
        handle.updates,
        (v) =>
            v.phase == SessionLivePhase.live &&
            v.state != null &&
            !v.state!.interactions.any((r) => r.id.value == reqId),
      );
      expect(
        handle.current.state!.interactions.any((r) => r.id.value == reqId),
        isFalse,
      );
      await rig.server.close();
      rig.server.assertHealthy();
    });

    test('automatic once reply fires without a tap', () async {
      final permRows = cPermissionRows(fx, bSessionId);
      final reqId = permRows.single['id'] as String;
      var replies = 0;
      final settledFrames = cPermissionRepliedFrames(fx, bSessionId, reqId);
      final scenario = FixtureScenario.routed(
        'flow/permission-auto',
        routes: [
          ...sessionRoutes(
            sessionRow: sesRow,
            messageRows: bRows,
            permissionRows: permRows,
          ),
          FixtureRoute(
            FixtureExchange.fromCapture({
              'method': 'POST',
              'path': '/api/session/$bSessionId/permission/$reqId/reply',
              'request': {'decision': 'once'},
              'status': 204,
              'response': null,
            }, 'flow/permission-auto-reply'),
            times: 1,
            respond: (_) {
              replies++;
              return null;
            },
          ),
        ],
        streams: [
          FixtureStream('epoch0', [
            fx.reconnect().streams.first.frames[0],
            ...settledFrames,
          ]),
        ],
      );
      final rig = await FixtureFlowRig.start(scenario: scenario);
      final (:profile, :credential) = await rig.addProfile(
        'profile_a',
        'Profile A',
      );
      final directory = rig.openDirectory();
      addTearDown(directory.close);
      // Default-on policy: no Ask override, no manual call below.
      final session = rig.ref('profile_a', bSessionId);
      final handle = await directory.open(
        profile: profile,
        credential: credential,
        session: session,
      );
      addTearDown(handle.close);
      await openEpoch(rig.server, 0);
      await until(
        handle.updates,
        (v) => v.phase == SessionLivePhase.live && v.state != null,
      );
      // The responder answers the resident once request on its own.
      await untilTrue(() async => replies == 1);
      await rig.server.streams[0].emitRemaining();
      await until(
        handle.updates,
        (v) =>
            v.phase == SessionLivePhase.live &&
            v.state != null &&
            !v.state!.interactions.any((r) => r.id.value == reqId),
      );
      expect(replies, 1);
      await rig.server.close();
      rig.server.assertHealthy();
    });

    test('stop requests the interrupt once and fences repeats', () async {
      var interrupts = 0;
      final scenario = FixtureScenario.routed(
        'flow/stop',
        routes: [
          ...sessionRoutes(
            sessionRow: sesRow,
            messageRows: bRows,
            activeRunning: true,
          ),
          FixtureRoute(
            FixtureExchange.fromCapture({
              'method': 'POST',
              'path': '/api/session/$bSessionId/interrupt',
              'request': null,
              'status': 200,
              'response': interruptAck(fx),
            }, 'flow/interrupt'),
            times: 1,
            respond: (_) {
              interrupts++;
              return interruptAck(fx);
            },
          ),
        ],
        streams: [
          FixtureStream('epoch0', [fx.reconnect().streams.first.frames[0]]),
        ],
      );
      final rig = await FixtureFlowRig.start(scenario: scenario);
      final (:profile, :credential) = await rig.addProfile(
        'profile_a',
        'Profile A',
      );
      final directory = rig.openDirectory();
      addTearDown(directory.close);
      final session = rig.ref('profile_a', bSessionId);
      final handle = await directory.open(
        profile: profile,
        credential: credential,
        session: session,
      );
      addTearDown(handle.close);
      await openEpoch(rig.server, 0);
      await until(
        handle.updates,
        (v) =>
            v.phase == SessionLivePhase.live &&
            v.state != null &&
            v.state!.execution?.kind.known == ExecutionKind.running,
      );
      expect(handle.canStop, isTrue);
      final before = rig.server.completedExchanges;
      await handle.stop(id: const CommandId('stop_1'));
      expect(interrupts, 1);
      // A second stop while the first is in flight sends nothing.
      await handle.stop(id: const CommandId('stop_2'));
      expect(rig.server.completedExchanges, before + 1);
      await rig.server.close();
      rig.server.assertHealthy();
    });
  });
}
