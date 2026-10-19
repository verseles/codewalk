import 'dart:async';
import 'dart:io';

import 'package:codewalk/app/app_dependencies.dart';
import 'package:codewalk/app/composition_root.dart';
import 'package:codewalk/app/v2_bootstrap.dart';
import 'package:codewalk/features/sessions/session_live_page.dart';
import 'package:codewalk/shared/sessions/session_live_source.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../packages/harness_opencode/test/support/fake_opencode_server.dart';
import '../../../packages/harness_opencode/test/support/fixture_replay.dart';
import '../hosts/fakes.dart';
import 'fakes.dart';
import 'fixture_flow_support.dart';
import 'live_fakes.dart';

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
    await tester.tap(find.byKey(ValueKey<SessionRef>(ref)));
    await tester.pump();
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
    await tester.pumpAndSettle();
    final read = scripted.sessions!.selectProfile('profile_a');
    final catalog = catalogRig.sources.single;
    final row = catalog.row('one', title: 'Fixture turn');
    catalog.respond([row]);
    await read;
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey(row.info.ref)));
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
}

/// One mounted app plus its composed dependencies.
final class AppHarness {
  AppHarness(this.tester, this.dependencies);
  final WidgetTester tester;
  final AppDependencies dependencies;
}
