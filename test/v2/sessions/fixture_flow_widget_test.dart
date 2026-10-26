import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:codewalk/app/app_dependencies.dart';
import 'package:codewalk/app/composition_root.dart';
import 'package:codewalk/app/v2_bootstrap.dart';
import 'package:codewalk/features/sessions/session_error_card.dart';
import 'package:codewalk/features/sessions/session_form_card.dart';
import 'package:codewalk/features/sessions/session_live_page.dart';
import 'package:codewalk/platform/endpoints/pairing_factory_io.dart';
import 'package:codewalk/platform/sessions/session_draft_store.dart';
import 'package:codewalk/shared/sessions/permission_mode.dart';
import 'package:codewalk/shared/sessions/session_live_source.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../../packages/harness_opencode/test/support/fake_opencode_server.dart';
import '../../../packages/harness_opencode/test/support/fixture_replay.dart';
import '../hosts/fakes.dart';
import 'fakes.dart';
import 'fixture_flow_support.dart';
import 'live_fakes.dart';
import 'workspace_support.dart';

/// Layer-2 integrated coverage (V2-060A): the REAL screens and the real
/// composed app graph mounted over the fixture-backed [FakeOpenCodeServer].
///
/// Widget tests run in a fake-async zone; every phase that needs real socket
/// IO runs through [pumpSpin], which alternates a short `runAsync` yield (so
/// the real event loop progresses) with a pump (so fake-zone microtasks flush
/// and frames rebuild). `tester.pump` is never called inside `runAsync`, and
/// no `runAsync` waits on an open stream.
void main() {
  // The test binding mocks every HttpClient with 400 responses; this file
  // exercises the real loopback transport, so the mock must be removed and
  // put back afterwards instead of leaking a process-global override.
  late HttpOverrides? previousOverrides;
  setUpAll(() {
    previousOverrides = HttpOverrides.current;
    HttpOverrides.global = null;
  });

  tearDownAll(() {
    HttpOverrides.global = previousOverrides;
  });

  late OpenCodeFixtures fx;
  late Map<String, Object?> sesRow;
  late List<Map<String, Object?>> bRows;
  late List<Map<String, Object?>> bDone;

  setUp(() {
    fx = OpenCodeFixtures();
    sesRow = bSessionRow(fx);
    bRows = bMessageRows(fx);
    bDone = bCompletedMessageRows(fx);
  });

  /// Advances real async and fake frames until [predicate] holds.
  Future<void> pumpSpin(
    WidgetTester tester,
    bool Function() predicate, {
    String reason = 'condition',
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (!predicate()) {
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

  /// Queues [count] next recorded frames (or every remaining one) on SSE epoch
  /// [index] and pumps until the server reports the writes completed.
  ///
  /// Emission is queued from the fake zone on purpose: each recorded `add`
  /// must run between pumps because `HttpResponse.flush` settles through
  /// fake-zone microtasks. Nothing here awaits a fake-zone future inside
  /// `runAsync`.
  Future<void> emitFrames(
    WidgetTester tester,
    FakeOpenCodeServer server,
    int index, {
    int? count,
  }) async {
    await pumpSpin(
      tester,
      () => server.streams.length > index,
      reason: 'SSE epoch $index',
    );
    final connection = server.streams[index];
    final total = count == null
        ? connection.fixture.frames.length
        : connection.emittedFrames + count;
    final failures = <Object>[];
    for (var queued = connection.emittedFrames; queued < total; queued++) {
      unawaited(connection.emitNext().then((_) {}, onError: failures.add));
    }
    await pumpSpin(
      tester,
      () => connection.emittedFrames >= total || failures.isNotEmpty,
      reason: 'SSE epoch $index frames written',
    );
    if (failures.isNotEmpty) {
      fail('SSE frame emission failed: ${failures.first}');
    }
  }

  /// Closes the fake server inside the fake zone and waits for the shutdown to
  /// finish, so a teardown failure is reported by the test instead of only by
  /// the memoized rig teardown.
  Future<void> closeServer(WidgetTester tester, FixtureFlowRig rig) async {
    Object? closeError;
    var closed = false;
    unawaited(
      rig.server.close().then(
        (_) => closed = true,
        onError: (Object error) => closeError = error,
      ),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await pumpSpin(
      tester,
      () => closed || closeError != null,
      reason: 'server teardown',
    );
    if (closeError != null) fail('server teardown failed: $closeError');
  }

  /// Boots the real app graph over the rig and lands on the sessions page.
  Future<AppHarness> boot(
    WidgetTester tester,
    FixtureFlowRig rig, {
    required Locale locale,
    required Size size,
    SessionLiveDirectory Function()? liveDirectory,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final dependencies = createAppDependencies(
      initialLink: Uri(path: '/sessions'),
      profileRepository: rig.profiles,
      endpointProber: FakeProber(),
      metadataStore: rig.metadata,
      permissionModeStore: rig.modes,
      sessionLiveDirectory: liveDirectory ?? rig.openDirectory,
    );
    dependencies.preferences.setLocale(locale);
    await tester.pumpWidget(CodeWalkV2Bootstrap(dependencies: dependencies));
    await pumpSpin(
      tester,
      () => dependencies.hosts.profiles.isNotEmpty,
      reason: 'profiles loaded',
    );
    return AppHarness(tester, dependencies);
  }

  Future<void> openProfile(WidgetTester tester, AppHarness app) async {
    final read = app.dependencies.sessions!.selectProfile('profile_a');
    await pumpSpin(
      tester,
      () => app.dependencies.sessions!.sessions.isNotEmpty,
      reason: 'catalog rows',
    );
    await read;
  }

  /// Opens the single catalog row's live page inside the mounted app.
  Future<SessionRef> openLive(WidgetTester tester, AppHarness app) async {
    final ref = app.dependencies.sessions!.sessions.single.info.ref;
    // A compact window keeps the list in its drawer.
    await showSessionList(tester);
    final open = find.byKey(ValueKey('live-open-${ref.storageKey}'));
    await tester.ensureVisible(open);
    await tester.tap(open);
    await tester.pump();
    await pumpSpin(
      tester,
      () => find.byType(SessionLivePage).evaluate().isNotEmpty,
      reason: 'live page',
    );
    return ref;
  }

  /// Captured user prompt of the B turn.
  String bUserText() =>
      bRows.firstWhere((row) => row['type'] == 'user')['text'] as String;

  /// Captured assistant text part of the completed B turn.
  String bAssistantText() {
    for (final row in bDone) {
      final content = row['content'];
      if (content is! List) continue;
      for (final part in content) {
        if (part is Map && part['type'] == 'text') {
          return part['text'] as String;
        }
      }
    }
    throw StateError('B assistant text part not found');
  }

  /// Plain texts rendered inside the live page that carry the captured turn
  /// (filtered by its content needles), in render order, used to compare both
  /// data sources. The needles keep the comparison to the texts both sources
  /// share: the captured partial stream ends before the turn outcome, so the
  /// scripted fixture's ToolCall/TurnOutcome have no captured twin. An ordered
  /// list, not a set, so duplicates and order are actually asserted.
  List<String> timelineTexts(WidgetTester tester) {
    const needles = ['marker.txt', 'SP01_B_NATIVE_RECONNECT_OK'];
    return [
      for (final rich in tester.widgetList<RichText>(
        find.descendant(
          of: find.byType(SessionLivePage),
          matching: find.byType(RichText),
        ),
      ))
        if (needles.any(rich.text.toPlainText().contains))
          rich.text.toPlainText(),
    ];
  }

  testWidgets('app-level happy path renders the captured turn and sends', (
    tester,
  ) async {
    final postedIds = <String>[];
    late FixtureFlowRig rig;
    // Reads issued after the stream delivered its text frames observe the
    // completed rows, like the later reads of the capture did; earlier reads
    // keep the in-flight snapshot whose assistant text is still empty.
    List<Map<String, Object?>>? servedRows() {
      if (rig.server.streams.isEmpty) return null;
      final connection = rig.server.streams.first;
      return connection.emittedFrames >= connection.fixture.frames.length
          ? bDone
          : null;
    }

    // The captured asc page is oldest-first; the desc route must serve
    // newest-first, the shape the reader reverses before projection.
    List<Map<String, Object?>>? servedDescRows() =>
        servedRows()?.reversed.toList();

    final scenario = FixtureScenario.routed(
      'flow/widget-happy',
      routes: [
        ...sessionRoutes(
          sessionRow: sesRow,
          messageRows: bRows,
          descRows: servedDescRows,
          ascRows: servedRows,
          times: 30,
        ),
        FixtureRoute(
          FixtureExchange.fromCapture({
            'method': 'POST',
            'path': '/api/session/$bSessionId/prompt',
            'request': null,
            'status': 200,
            'response': null,
          }, 'flow/widget-prompt'),
          matchBody: false,
          times: 10,
          respond: (body) {
            final req = body as Map<String, Object?>;
            postedIds.add(req['id'] as String);
            return promptAdmissionEcho(req);
          },
        ),
      ],
      streams: [FixtureStream('epoch0', bStreamFrames(fx, 'partialStream'))],
    );
    rig = await FixtureFlowRig.start(scenario: scenario);
    await rig.addProfile('profile_a', 'Profile A');
    final app = await boot(
      tester,
      rig,
      locale: const Locale('en'),
      size: const Size(390, 844),
    );
    await openProfile(tester, app);
    final ref = await openLive(tester, app);
    expect(ref.nativeId, bSessionId);

    // The captured turn: connected + full partial stream.
    await emitFrames(tester, rig.server, 0);
    await pumpSpin(
      tester,
      () => find
          .textContaining('SP01_B_NATIVE_RECONNECT_OK', findRichText: true)
          .evaluate()
          .isNotEmpty,
      reason: 'streamed assistant text',
    );
    expect(find.textContaining('marker.txt', findRichText: true), findsWidgets);

    // Composer sends through the fixture server with the client-minted id.
    await tester.enterText(find.byType(TextField), 'Ping from fixture');
    await tester.pump();
    await pumpSpin(
      tester,
      () =>
          tester
              .widget<IconButton>(
                find.byKey(const ValueKey('live-composer-send')),
              )
              .onPressed !=
          null,
      reason: 'send enabled',
    );
    await tester.tap(find.byKey(const ValueKey('live-composer-send')));
    await pumpSpin(
      tester,
      () => postedIds.isNotEmpty,
      reason: 'admission POST',
    );
    expect(postedIds, hasLength(1));
    // Wait for the send pipeline to fully settle: the client validates the
    // admission echo, applies the promoted row and only then clears the
    // draft. Settling here also cancels the request deadline timer before
    // the tree is disposed, so no fake-zone timer outlives the test.
    await pumpSpin(
      tester,
      () => tester
          .widget<EditableText>(find.byType(EditableText))
          .controller
          .text
          .isEmpty,
      reason: 'admission settled and draft cleared',
    );

    expect(tester.takeException(), isNull);
    // Close the server before disposing the app: `_closed` makes the
    // teardown-driven SSE abort intentional instead of a recorded failure.
    // The shutdown is driven by real IO yields and fake-time pumps and awaited
    // here — not only by the memoized rig teardown — so `assertHealthy`
    // inspects a completed shutdown instead of a half-run one.
    await closeServer(tester, rig);
    rig.server.assertHealthy();
  });

  testWidgets('fixture-backed turn renders the captured texts the same as '
      'the scripted live state', (tester) async {
    late FixtureFlowRig rig;
    List<Map<String, Object?>>? servedRows() {
      if (rig.server.streams.isEmpty) return null;
      final connection = rig.server.streams.first;
      return connection.emittedFrames >= connection.fixture.frames.length
          ? bDone
          : null;
    }

    // The captured asc page is oldest-first; the desc route must serve
    // newest-first, the shape the reader reverses before projection.
    List<Map<String, Object?>>? servedDescRows() =>
        servedRows()?.reversed.toList();

    // Phase 1: the captured turn through the fixture-backed server and the
    // real app graph.
    final scenario = FixtureScenario.routed(
      'flow/widget-compare',
      routes: sessionRoutes(
        sessionRow: sesRow,
        messageRows: bRows,
        descRows: servedDescRows,
        ascRows: servedRows,
        times: 30,
      ),
      streams: [FixtureStream('epoch0', bStreamFrames(fx, 'partialStream'))],
    );
    rig = await FixtureFlowRig.start(scenario: scenario);
    await rig.addProfile('profile_a', 'Profile A');
    final app = await boot(
      tester,
      rig,
      locale: const Locale('en'),
      size: const Size(390, 844),
    );
    await openProfile(tester, app);
    await openLive(tester, app);
    await emitFrames(tester, rig.server, 0);
    await pumpSpin(
      tester,
      () => find
          .textContaining('SP01_B_NATIVE_RECONNECT_OK', findRichText: true)
          .evaluate()
          .isNotEmpty,
      reason: 'streamed assistant text',
    );
    final fixtureTexts = timelineTexts(tester);
    expect(fixtureTexts, isNotEmpty);

    // Shut the fake down (memoized; the rig teardown re-awaits it) so phase 2
    // starts from a closed server and any teardown failure surfaces here.
    await closeServer(tester, rig);
    rig.server.assertHealthy();

    // Phase 2: the same turn authored on the scripted domain fake.
    final catalogRig = CatalogRig();
    await catalogRig.save('a');
    final live = LiveDirectory();
    final scripted = createAppDependencies(
      initialLink: Uri(path: '/sessions'),
      profileRepository: catalogRig.repository,
      endpointProber: FakeProber(),
      sessionCatalogFactory: catalogRig.create,
      sessionLiveDirectory: () => live,
    );
    scripted.preferences.setLocale(const Locale('en'));
    await tester.pumpWidget(CodeWalkV2Bootstrap(dependencies: scripted));
    await showSessionList(tester);
    final read = scripted.sessions!.selectProfile('profile_a');
    final catalog = catalogRig.sources.single;
    final row = catalog.row('one', title: 'Fixture turn');
    catalog.respond([row]);
    await read;
    await tester.pumpAndSettle();
    final open = find.byKey(ValueKey('live-open-${row.info.ref.storageKey}'));
    await tester.ensureVisible(open);
    await tester.tap(open);
    await tester.pump();
    await tester.pump();
    expect(find.byType(SessionLivePage), findsOneWidget);
    final ref = row.info.ref;
    final handle = live.grant(ref);
    await tester.pump();
    handle.emit(
      SessionLiveView(
        session: ref,
        phase: SessionLivePhase.live,
        lastSyncedAt: DateTime.utc(2026, 10, 15, 12),
        state: liveState(
          ref,
          items: [
            UserInput(
              meta: liveMeta(ref, 'u1'),
              text: bUserText(),
              delivery: OpenValue.unknown('not observed'),
            ),
            ToolCall(
              meta: liveMeta(ref, 't1'),
              kind: const OpenValue.known(ToolKind.read),
              rawName: 'read',
              input: CanonicalValue({'path': 'marker.txt'}),
            ),
            AssistantText(
              meta: liveMeta(ref, 'a1'),
              text: bAssistantText(),
              complete: true,
            ),
            TurnOutcome(
              meta: liveMeta(ref, 'o1'),
              kind: const OpenValue.known(OutcomeKind.succeeded),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      timelineTexts(tester),
      equals(fixtureTexts),
      reason: 'fixture-backed and scripted renders must converge',
    );
  });

  testWidgets(
    'integrated workspace flow proves pair -> workspace -> tab -> send -> '
    'steer -> stop -> permission -> form -> model switch -> error',
    (tester) async {
      final prevPrefs = SharedPreferencesAsyncPlatform.instance;
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      addTearDown(() => SharedPreferencesAsyncPlatform.instance = prevPrefs);

      const secondSessionId = 'ses_1a10548204a0007f0a42202e750f';
      final secondRow = Map<String, Object?>.from(sesRow)
        ..['id'] = secondSessionId
        ..['title'] = 'Workspace sibling session';
      var currentSessionRow = Map<String, Object?>.from(sesRow);

      final permRow = cPermissionRows(fx, bSessionId).first;
      final reqId = permRow['id'] as String;
      final formRow = cFormRows(fx, bSessionId).first;
      final formId = formRow['id'] as String;

      var activePermissions = <Map<String, Object?>>[];
      var activeForms = <Map<String, Object?>>[];
      final postedPrompts = <Map<String, Object?>>[];
      var interruptCount = 0;
      final permissionReplies = <Map<String, Object?>>[];
      final formReplies = <Map<String, Object?>>[];
      final modelSelections = <Map<String, Object?>>[];

      final partial = bStreamFrames(fx, 'partialStream');
      late FixtureFlowRig rig;
      // Reads issued after the partial stream delivered its text frames
      // observe the completed rows, like the later reads of the capture did.
      List<Map<String, Object?>>? servedRows() {
        if (rig.server.streams.isEmpty) return null;
        final connection = rig.server.streams.first;
        return connection.emittedFrames >= partial.length ? bDone : null;
      }

      List<Map<String, Object?>>? servedDescRows() =>
          servedRows()?.reversed.toList();

      var sequence = partial
          .where((frame) => frame.startsWith('data:'))
          .map((frame) {
            final event = jsonDecode(frame.substring(5)) as Map;
            return (event['durable'] as Map?)?['seq'] as int? ?? 0;
          })
          .fold<int>(0, (a, b) => a > b ? a : b);
      // Continue after the capture's actual cursor, not its frame count.
      final liveStreamFrames = <String>[
        ...partial,
        dExecutionInterruptedFrame(fx, bSessionId, seq: ++sequence),
        ...cPermissionAskedFrames(fx, bSessionId, reqId),
        ...cPermissionRepliedFrames(fx, bSessionId, reqId),
        ...cFormCreatedFrames(fx, bSessionId, formId),
        ...cFormRepliedFrames(fx, bSessionId, formId),
        modelSelectedFrame(
          bSessionId,
          providerId: 'opencode',
          modelId: 'fledge-alpha-free',
          variant: 'high',
          seq: ++sequence,
        ),
        executionStartedFrame(bSessionId, seq: ++sequence),
        executionFailedFrame(
          bSessionId,
          errorType: 'provider.auth',
          message: 'Provider key rejected',
          seq: ++sequence,
        ),
      ];

      final scenario = FixtureScenario.routed(
        'flow/workspace-integrated-060c',
        routes: [
          ...sessionRoutes(
            sessionRow: sesRow,
            sessionRowFn: () => currentSessionRow,
            messageRows: bRows,
            descRows: servedDescRows,
            ascRows: servedRows,
            extraSessionRows: [secondRow],
            permissionRowsFn: () => activePermissions,
            formRowsFn: () => activeForms,
            activeRunning: true,
            times: 80,
          ),
          FixtureRoute(
            FixtureExchange.fromCapture({
              'method': 'POST',
              'path': '/api/session/$bSessionId/prompt',
              'request': null,
              'status': 200,
              'response': null,
            }, 'flow/workspace-prompt'),
            matchBody: false,
            times: 10,
            respond: (body) {
              final req = Map<String, Object?>.from(body as Map);
              postedPrompts.add(req);
              return promptAdmissionEcho(req);
            },
          ),
          FixtureRoute(
            FixtureExchange.fromCapture({
              'method': 'POST',
              'path': '/api/session/$bSessionId/interrupt',
              'request': null,
              'status': 200,
              'response': interruptAck(fx),
            }, 'flow/workspace-interrupt'),
            matchBody: false,
            times: 10,
            respond: (_) {
              interruptCount++;
              return interruptAck(fx);
            },
          ),
          FixtureRoute(
            FixtureExchange.fromCapture({
              'method': 'POST',
              'path': '/api/session/$bSessionId/permission/$reqId/reply',
              'request': null,
              'status': 204,
              'response': null,
            }, 'flow/workspace-permission-reply'),
            matchBody: false,
            times: 10,
            respond: (body) {
              permissionReplies.add(Map<String, Object?>.from(body as Map));
              activePermissions = const [];
              return null;
            },
          ),
          FixtureRoute(
            FixtureExchange.fromCapture({
              'method': 'POST',
              'path': '/api/session/$bSessionId/form/$formId/reply',
              'request': null,
              'status': 204,
              'response': null,
            }, 'flow/workspace-form-reply'),
            matchBody: false,
            times: 10,
            respond: (body) {
              formReplies.add(Map<String, Object?>.from(body as Map));
              activeForms = const [];
              return null;
            },
          ),
          FixtureRoute(
            FixtureExchange.fromCapture({
              'method': 'POST',
              'path': '/api/session/$bSessionId/model',
              'request': null,
              'status': 204,
              'response': null,
            }, 'flow/workspace-model-select'),
            matchBody: false,
            times: 10,
            respond: (body) {
              final req = Map<String, Object?>.from(body as Map);
              modelSelections.add(req);
              final selected = Map<String, Object?>.from(req['model'] as Map);
              currentSessionRow = Map<String, Object?>.from(currentSessionRow)
                ..['model'] = selected;
              return null;
            },
          ),
        ],
        streams: [
          // Shared transport SSE stream for the host's catalog + live sessions.
          FixtureStream('live-session-epoch0', liveStreamFrames),
        ],
      );

      rig = await FixtureFlowRig.start(scenario: scenario);
      addTearDown(() => closeServer(tester, rig));
      const wideSize = Size(1200, 900);
      tester.view.physicalSize = wideSize;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // 1. Pair (`pair`): redeem one-time pairing challenge on /pair and save.
      final pairGrant = rig.server.auth.issuePairing();
      final pairCode = pairGrant['code'] as String;
      final dependencies = createAppDependencies(
        initialLink: Uri(path: '/pair'),
        profileRepository: rig.profiles,
        endpointProber: FakeProber(),
        endpointPairing: createEndpointPairing(),
        metadataStore: rig.metadata,
        permissionModeStore: rig.modes,
        sessionLiveDirectory: rig.openDirectory,
        draftStore: SessionDraftStore(
          payloads: rig.payloads,
          index: rig.metadata,
        ),
      );
      await tester.runAsync(() => dependencies.sessionTabs!.initialize());
      dependencies.preferences.setLocale(const Locale('en'));
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: wideSize),
          child: CodeWalkV2Bootstrap(dependencies: dependencies),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('pairing-link')),
        '${rig.server.endpoint}/auth/connect/$pairCode',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('confirm-pairing')));
      await pumpSpin(
        tester,
        () => find.byKey(const ValueKey('save-pairing')).evaluate().isNotEmpty,
        reason: 'pairing redeemed',
      );
      await tester.tap(find.byKey(const ValueKey('save-pairing')));
      await pumpSpin(
        tester,
        () => dependencies.hosts.profiles.isNotEmpty,
        reason: 'paired profile saved',
      );
      final pairedProfile = dependencies.hosts.profiles.single;
      expect(pairedProfile.endpoint.host, rig.server.endpoint.host);
      expect(pairedProfile.endpoint.port, rig.server.endpoint.port);

      final primaryRef = rig.ref(pairedProfile.id, bSessionId);
      final secondRef = rig.ref(pairedProfile.id, secondSessionId);
      await tester.runAsync(
        () => rig.modes.setSessionMode(primaryRef, PermissionMode.ask),
      );

      // 2. Workspace (`workspace`): wide 2-pane layout with sidebar + canvas.
      dependencies.router.go('/sessions');
      await tester.pump();
      final selectFuture = dependencies.sessions!.selectProfile(
        pairedProfile.id,
      );
      await pumpSpin(
        tester,
        () => dependencies.sessions!.sessions.length == 2,
        reason: 'workspace catalog loaded',
      );
      await selectFuture;
      await emitFrames(tester, rig.server, 0, count: 1);
      expect(find.byKey(const ValueKey('workspace-sidebar')), findsOneWidget);
      expect(find.byKey(const ValueKey('workspace-empty')), findsOneWidget);

      // 3. Tab (`tab`): open sibling session then primary session, verify tabs.
      Future<void> openFromSidebar(SessionRef ref) async {
        final card = find.byKey(ValueKey<SessionRef>(ref));
        await tester.ensureVisible(card);
        await tester.tap(card);
        await tester.pump();
        final openBtn = find.byKey(ValueKey('live-open-${ref.storageKey}'));
        await pumpSpin(
          tester,
          () => openBtn.evaluate().isNotEmpty,
          reason: 'live-open button for ${ref.nativeId}',
        );
        await tester.ensureVisible(openBtn);
        await tester.tap(openBtn);
        await tester.pump();
      }

      await openFromSidebar(secondRef);
      await pumpSpin(
        tester,
        () =>
            find.byType(SessionLivePage).evaluate().isNotEmpty &&
            dependencies.sessionTabs!.selectedFor(secondRef.host) == secondRef,
        reason: 'second session tab live page',
      );

      await openFromSidebar(primaryRef);
      await pumpSpin(
        tester,
        () =>
            dependencies.sessionTabs!.selectedFor(primaryRef.host) ==
            primaryRef,
        reason: 'primary session tab live page',
      );
      expect(find.byKey(const ValueKey('session-tabs')), findsOneWidget);
      expect(
        find.byKey(ValueKey('session-tab-${secondRef.storageKey}')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey('session-tab-${primaryRef.storageKey}')),
        findsOneWidget,
      );

      // Switch tabs via the tab strip and switch back to primary.
      await tester.tap(
        find.byKey(ValueKey('session-tab-${secondRef.storageKey}')),
      );
      await pumpSpin(
        tester,
        () =>
            dependencies.sessionTabs!.selectedFor(secondRef.host) == secondRef,
        reason: 'switched to second tab',
      );
      await tester.tap(
        find.byKey(ValueKey('session-tab-${primaryRef.storageKey}')),
      );
      await pumpSpin(
        tester,
        () =>
            dependencies.sessionTabs!.selectedFor(primaryRef.host) ==
            primaryRef,
        reason: 'switched back to primary tab',
      );

      // 4. Send & Steer (`send` -> `steer`): emit remaining partial stream
      // frames (`partial.first` was emitted on catalog connect) so primary
      // session is live and running, then send a steer prompt.
      await emitFrames(tester, rig.server, 0, count: partial.length - 1);
      await pumpSpin(
        tester,
        () => find
            .textContaining('SP01_B_NATIVE_RECONNECT_OK', findRichText: true)
            .evaluate()
            .isNotEmpty,
        reason: 'primary session streamed text',
      );
      expect(find.byKey(const ValueKey('live-delivery-steer')), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('live-composer-input')),
        'First prompt from workspace',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('live-composer-send')));
      await pumpSpin(
        tester,
        () => postedPrompts.length == 1 &&
            !tester.widget<SessionLivePage>(find.byType(SessionLivePage))
                .controller.composer.sending,
        reason: 'first workspace prompt admitted',
      );
      expect(postedPrompts.first['text'], 'First prompt from workspace');
      await tester.tap(find.byKey(const ValueKey('live-delivery-steer')));
      await tester.enterText(
        find.byKey(const ValueKey('live-composer-input')),
        'Steer prompt from workspace',
      );
      await tester.pump();
      await pumpSpin(
        tester,
        () =>
            tester
                .widget<ButtonStyleButton>(
                  find.byKey(const ValueKey('live-composer-send')),
                )
                .onPressed !=
            null,
        reason: 'steer send enabled',
      );
      await tester.tap(find.byKey(const ValueKey('live-composer-send')));
      await pumpSpin(
        tester,
        () => postedPrompts.length == 2,
        reason: 'steer prompt POST',
      );
      expect(postedPrompts.last['text'], 'Steer prompt from workspace');
      expect(postedPrompts.last['delivery'], 'steer');
      expect(postedPrompts.last['id'], isNot(postedPrompts.first['id']));
      await pumpSpin(
        tester,
        () => tester
            .widget<TextField>(
              find.byKey(const ValueKey('live-composer-input')),
            )
            .controller!
            .text
            .isEmpty,
        reason: 'composer draft cleared after steer send',
      );

      // 5. Stop (`stop`): with composer empty and execution running, tap stop.
      await pumpSpin(
        tester,
        () => find.byKey(const ValueKey('live-stop')).evaluate().isNotEmpty,
        reason: 'stop available after steer admission finishes',
      );
      await tester.tap(find.byKey(const ValueKey('live-stop')));
      await pumpSpin(
        tester,
        () => interruptCount == 1,
        reason: 'interrupt POST',
      );
      // Emit the captured interruption after the existing durable cursor.
      await emitFrames(tester, rig.server, 0, count: 1);
      await pumpSpin(
        tester,
        () => find.byKey(const ValueKey('live-stop')).evaluate().isEmpty,
        reason: 'stop button hidden after interrupted outcome',
      );

      // 6. Permission (`permission`): emit `permission.asked`, tap Allow once.
      activePermissions = [permRow];
      await emitFrames(tester, rig.server, 0, count: 1);
      await pumpSpin(
        tester,
        () => find
            .byKey(ValueKey('live-permission-$reqId'))
            .evaluate()
            .isNotEmpty,
        reason: 'permission card visible',
      );
      final permissionAllow = find.byKey(
        ValueKey('live-permission-allow-$reqId'),
      );
      await pumpSpin(
        tester,
        () => tester.widget<FilledButton>(permissionAllow).onPressed != null,
        reason: 'permission reply enabled after hydration',
      );
      await tester.ensureVisible(permissionAllow);
      await tester.tap(permissionAllow);
      await pumpSpin(
        tester,
        () => permissionReplies.length == 1,
        reason: 'permission reply POST',
      );
      expect(permissionReplies.single['decision'], 'once');
      // Emit `permission.replied` to settle the card.
      await emitFrames(tester, rig.server, 0, count: 1);
      await pumpSpin(
        tester,
        () => find.byKey(ValueKey('live-permission-$reqId')).evaluate().isEmpty,
        reason: 'permission card settled',
      );

      // 7. Form (`form`): emit `form.created`, fill required choice, submit.
      activeForms = [formRow];
      await emitFrames(tester, rig.server, 0, count: 1);
      await pumpSpin(
        tester,
        () => find.byType(SessionFormCard).evaluate().isNotEmpty,
        reason: 'form card visible',
      );
      final choiceChip = find.byKey(const ValueKey('form-option-choice-alpha'));
      await tester.ensureVisible(choiceChip);
      await tester.tap(choiceChip);
      await tester.pump();
      final submitBtn = find.byKey(ValueKey('form-submit-$formId'));
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await pumpSpin(
        tester,
        () => formReplies.length == 1,
        reason: 'form reply POST',
      );
      expect(formReplies.single, {
        'answer': {'choice': 'alpha'},
      });
      // Emit `form.replied` to settle the form card.
      await emitFrames(tester, rig.server, 0, count: 1);
      await pumpSpin(
        tester,
        () => find.byType(SessionFormCard).evaluate().isEmpty,
        reason: 'form card settled',
      );

      // 8. Model switch (`model switch`): open selection dialog, pick variant.
      await tester.ensureVisible(find.byKey(const ValueKey('live-selection')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('live-selection')));
      await tester.pumpAndSettle();
      final variantFinder = find.byKey(
        const ValueKey(
          'live-selection-variant-opencode/fledge-alpha-free#high',
        ),
      );
      await tester.ensureVisible(variantFinder);
      await tester.tap(variantFinder);
      await pumpSpin(
        tester,
        () => modelSelections.length == 1,
        reason: 'model selection POST',
      );
      expect(modelSelections.single, {
        'model': {
          'providerID': 'opencode',
          'id': 'fledge-alpha-free',
          'variant': 'high',
        },
      });
      // Compact chips carry the selected model in their accessible tooltip.
      await emitFrames(tester, rig.server, 0, count: 1);
      await pumpSpin(
        tester,
        () => find
            .byTooltip(RegExp('Fledge Alpha Free#high'))
            .evaluate()
            .isNotEmpty,
        reason: 'selection chip label updated to Fledge Alpha Free#high',
      );
      await tester.tap(find.byKey(const ValueKey('live-jump-latest')));
      await tester.pumpAndSettle();

      // 9. Error (`error`): emit `session.execution.started` + `failed`.
      await emitFrames(tester, rig.server, 0, count: 2);
      await pumpSpin(
        tester,
        () => find.byType(SessionErrorCard).evaluate().isNotEmpty,
        reason: 'error card rendered on execution failure',
      );
      expect(find.byKey(const ValueKey('live-error-card')), findsOneWidget);
      expect(find.textContaining('Provider key rejected'), findsOneWidget);
      expect(find.byKey(const ValueKey('live-error-action')), findsOneWidget);

      expect(tester.takeException(), isNull);
      await closeServer(tester, rig);
      rig.server.assertHealthy();
    },
  );
}

/// One mounted app plus its composed dependencies.
final class AppHarness {
  AppHarness(this.tester, this.dependencies);
  final WidgetTester tester;
  final AppDependencies dependencies;
}
