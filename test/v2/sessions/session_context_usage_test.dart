import 'package:codewalk/app/app_preferences_controller.dart';
import 'package:codewalk/app/workspace_chrome.dart';
import 'package:codewalk/app/workspace_chrome_controller.dart';
import 'package:codewalk/features/hosts/endpoint_health_controller.dart';
import 'package:codewalk/features/sessions/session_context_usage.dart';
import 'package:codewalk/features/sessions/session_live_controller.dart';
import 'package:codewalk/features/sessions/session_tabs_controller.dart';
import 'package:codewalk/features/sessions/sessions_controller.dart';
import 'package:codewalk/platform/sessions/session_tabs_store.dart';
import 'package:codewalk/platform/storage/metadata_store.dart';
import 'package:codewalk/shared/l10n/generated/v2_localizations.dart';
import 'package:codewalk/shared/l10n/generated/v2_localizations_en.dart';
import 'package:codewalk/shared/sessions/session_live_source.dart';
import 'package:codewalk/shared/sessions/session_selection.dart';
import 'package:codewalk/shared/sessions/session_turn_actions.dart';
import 'package:codewalk/shared/theme/app_surface_tokens.dart';
import 'package:codewalk/shared/widgets/app_indeterminate_progress.dart';
import 'package:codewalk_core/codewalk_core.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harness_opencode/harness_opencode.dart';
import 'package:provider/provider.dart';

import '../storage/storage_fakes.dart';
import 'fakes.dart';
import 'live_fakes.dart';

final class _FakeTurnPort implements SessionTurnActionPort {
  _FakeTurnPort({this.canCompactFlag = true, bool compacting = false})
    : state = SessionTurnState(compacting: compacting);

  bool canCompactFlag;
  int compactCalls = 0;

  @override
  SessionTurnState state;

  @override
  SessionTurnUnavailable? unavailable(SessionTurnAction action) {
    if (action == SessionTurnAction.compact) {
      if (state.compacting || !canCompactFlag) {
        return SessionTurnUnavailable.busy;
      }
    }
    return null;
  }

  @override
  Future<SessionTurnResult> compact({required CommandId id}) async {
    compactCalls++;
    return const SessionTurnResult(applied: true);
  }

  @override
  Future<SessionTurnResult> redoAll({required CommandId id}) async =>
      const SessionTurnResult(applied: true);

  @override
  Future<SessionTurnResult> redoNext({required CommandId id}) async =>
      const SessionTurnResult(applied: true);

  @override
  Future<SessionTurnResult> stage(
    ItemId boundary, {
    required CommandId id,
  }) async => const SessionTurnResult(applied: true);

  @override
  Future<void> refresh() async {}
}

final class _UsageRig {
  _UsageRig(
    this.tester, {
    required this.usageCapabilities,
    bool canCompact = true,
    bool compacting = false,
  }) : port = _FakeTurnPort(canCompactFlag: canCompact, compacting: compacting);

  final WidgetTester tester;
  final Map<String, Capability> usageCapabilities;
  final _FakeTurnPort port;

  late final CatalogRig catalog;
  late final LiveDirectory directory;
  late final EndpointHealthController health;
  late final SessionTabsController tabs;
  late final WorkspaceChromeController chrome;
  late final AppPreferencesController preferences;
  late final SessionLiveController live;
  late final LiveHandle handle;
  late final SessionRef ref;

  Future<void> start({bool attachSession = true}) async {
    catalog = CatalogRig();
    directory = LiveDirectory();
    await catalog.save('a');
    await catalog.sessions.initialize();
    final selecting = catalog.sessions.selectProfile('profile_a');
    final source = catalog.sources.single;
    final row = source.row('current', directory: '/work/a');
    ref = row.info.ref;
    source.respond([row]);
    await selecting;
    catalog.sessions.selectProject(row.info.project!);

    preferences = AppPreferencesController(
      store: V2MetadataStore(backend: FakeMetadataBackend()),
    );
    await preferences.initialize();

    health = EndpointHealthController(
      hosts: catalog.hosts,
      now: () => tester.binding.clock.now().toUtc(),
    );
    tabs = SessionTabsController(
      catalog: catalog.sessions,
      store: SessionTabsStore(
        store: V2MetadataStore(backend: FakeMetadataBackend()),
      ),
    );
    await tabs.initialize();
    chrome = WorkspaceChromeController(
      health: health,
      catalog: catalog.sessions,
      tabs: tabs,
    );

    live = SessionLiveController(
      hosts: catalog.hosts,
      profile: profile('a'),
      summary: row,
      directory: directory,
    );
    final startFuture = live.start();
    handle = directory.grant(
      ref,
      turnActions: port,
      usageCapabilities: usageCapabilities,
    );
    await startFuture;

    if (attachSession) {
      tabs.live(ref, () => live);
      chrome.locationChanged('/s/${ref.host.value}/${ref.nativeId}');
    } else {
      chrome.locationChanged('/sessions');
    }
  }

  void emitState({
    List<TimelineItem> timeline = const [],
    List<UsageObservation> usage = const [],
    List<ModelEntry> models = const [],
    Selection? selection,
    int? defaultModelContextLimit,
  }) {
    handle.selectionState = SessionSelectionState(
      selection: selection,
      models: models,
      defaultModelContextLimit: defaultModelContextLimit,
    );
    final readStart = StreamPosition(id: 's', epoch: 'e1', seq: BigInt.zero);
    final baseState = beginHydration(
      SessionState(ref, streamPosition: readStart),
      generation: 'g1',
      readStart: readStart,
    );
    final snap = SessionSnapshot(
      ref: ref,
      hydrationGeneration: 'g1',
      timeline: SnapshotCollection(
        values: timeline,
        boundary: SnapshotBoundary(
          owner: SessionOwner(ref),
          hydrationGeneration: 'g1',
          readStart: StreamPosition(id: 's', epoch: 'e1', seq: BigInt.zero),
          readStartedAt: DateTime.utc(2026, 11, 21, 12, 0),
          readCompletedAt: DateTime.utc(2026, 11, 21, 12, 0, 1),
          authority: const OpenValue.known(SnapshotAuthority.authoritative),
        ),
        complete: true,
      ),
      usage: SnapshotCollection(
        values: usage,
        boundary: SnapshotBoundary(
          owner: SessionOwner(ref),
          hydrationGeneration: 'g1',
          readStart: StreamPosition(id: 's', epoch: 'e1', seq: BigInt.zero),
          readStartedAt: DateTime.utc(2026, 11, 21, 12, 0),
          readCompletedAt: DateTime.utc(2026, 11, 21, 12, 0, 1),
          authority: const OpenValue.known(SnapshotAuthority.authoritative),
        ),
        complete: true,
      ),
    );
    final hydrated = hydrate(baseState, snap).state;
    handle.emit(
      SessionLiveView(
        session: ref,
        phase: SessionLivePhase.live,
        state: hydrated,
      ),
    );
  }

  Widget buildApp({required double width, Locale locale = const Locale('en')}) {
    final compact = width < 600;
    final scheme = ColorScheme.fromSeed(seedColor: Colors.blue);
    return MaterialApp(
      locale: locale,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        extensions: [AppSurfaceTokens.fromScheme(scheme, Brightness.light)],
      ),
      localizationsDelegates: V2Localizations.localizationsDelegates,
      supportedLocales: V2Localizations.supportedLocales,
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider<AppPreferencesController?>.value(
            value: preferences,
          ),
          ChangeNotifierProvider<SessionsController?>.value(
            value: catalog.sessions,
          ),
          ChangeNotifierProvider<WorkspaceChromeController?>.value(
            value: chrome,
          ),
        ],
        child: Scaffold(
          appBar: AppBar(actions: [WorkspaceAppBarActions(compact: compact)]),
          body: const SizedBox.expand(),
        ),
      ),
    );
  }

  void dispose() {
    live.dispose();
    chrome.dispose();
    tabs.dispose();
    health.dispose();
    preferences.dispose();
    catalog.dispose();
  }
}

AssistantText _assistantStep(
  SessionRef ref, {
  required String msgId,
  required num input,
  required num output,
  required num reasoning,
  required num cacheRead,
  required num cacheWrite,
  required num cost,
  String modelId = 'm1',
  String providerId = 'p1',
}) => AssistantText(
  meta: ItemMeta(
    id: ItemId('$msgId:0'),
    anchor: MessageAnchor(message: MessageRef(msgId), orderKey: msgId),
    generation: 'g1',
    status: const OpenValue.known(ItemStatus.completed),
    source: SourceProvenance(
      harness: ref.harnessRef,
      version: '2.0.22',
      nativeType: 'session.message.list',
    ),
    message: MessageContext(
      message: MessageRef(msgId),
      modelId: modelId,
      modelProviderId: providerId,
      tokens: TokenBreakdown(
        input: input,
        output: output,
        reasoning: reasoning,
        cacheRead: cacheRead,
        cacheWrite: cacheWrite,
      ),
      cost: Cost(amount: cost, currency: 'USD'),
    ),
  ),
  text: 'reply',
  complete: true,
);

void main() {
  test(
    'formatUsageCost handles USD, other currencies, and unknown currency',
    () {
      final l10n = V2LocalizationsEn();
      expect(
        formatUsageCost(
          Cost(amount: 0.0425, currency: 'USD'),
          const Locale('en'),
          l10n,
        ),
        r'$0.0425',
      );
      expect(
        formatUsageCost(
          Cost(amount: 12.5, currency: 'USD'),
          const Locale('en'),
          l10n,
        ),
        r'$12.50',
      );
      expect(
        formatUsageCost(
          Cost(amount: 3.25, currency: 'EUR'),
          const Locale('en'),
          l10n,
        ),
        'EUR 3.25',
      );
      expect(
        formatUsageCost(Cost(amount: 1.5), const Locale('en'), l10n),
        '1.50 (Unknown currency)',
      );
      expect(formatUsageCost(Cost(), const Locale('en'), l10n), '—');
    },
  );

  testWidgets(
    'knob is hidden without active session while overflow row keeps pin toggle active',
    (tester) async {
      final rig = _UsageRig(
        tester,
        usageCapabilities: openCodeUsageCapabilities('2.0.22'),
      );
      addTearDown(rig.dispose);
      await rig.start(attachSession: false);
      tester.view.physicalSize = const Size(900, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(rig.buildApp(width: 900));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('workspace-pinned-contextUsage')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('workspace-pinned-newChat')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('workspace-actions')));
      await tester.pumpAndSettle();
      final menuRow = tester.widget<MenuItemButton>(
        find.byKey(const ValueKey('workspace-menu-contextUsage')),
      );
      expect(menuRow.onPressed, isNull);

      await tester.tap(
        find.byKey(const ValueKey('workspace-pin-contextUsage')),
      );
      await tester.pump();
      expect(
        rig.preferences.appBarPins,
        isNot(contains(WorkspacePinnedAction.contextUsage)),
      );
    },
  );

  testWidgets('knob is hidden when harness exposes zero usage capabilities', (
    tester,
  ) async {
    final rig = _UsageRig(tester, usageCapabilities: const {});
    addTearDown(rig.dispose);
    await rig.start();
    rig.emitState();
    tester.view.physicalSize = const Size(900, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(rig.buildApp(width: 900));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('workspace-pinned-contextUsage')),
      findsNothing,
    );
  });

  testWidgets(
    'knob renders left of New Chat with neutral dash before usage, then updates and opens wide popover with Compact now',
    (tester) async {
      final rig = _UsageRig(
        tester,
        usageCapabilities: openCodeUsageCapabilities('2.0.22'),
      );
      addTearDown(rig.dispose);
      await rig.start();
      rig.emitState(
        models: [
          ModelEntry(
            id: 'm1',
            providerId: 'p1',
            label: 'Model 1',
            contextLimit: 100000,
          ),
        ],
        defaultModelContextLimit: 100000,
      );
      tester.view.physicalSize = const Size(900, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(rig.buildApp(width: 900));
      await tester.pumpAndSettle();

      final knobFinder = find.byKey(
        const ValueKey('workspace-pinned-contextUsage'),
      );
      final newChatFinder = find.byKey(
        const ValueKey('workspace-pinned-newChat'),
      );
      expect(knobFinder, findsOneWidget);
      expect(newChatFinder, findsOneWidget);
      // Positioned immediately to the left of New Chat.
      expect(
        tester.getTopLeft(knobFinder).dx,
        lessThan(tester.getTopLeft(newChatFinder).dx),
      );
      // Neutral dash before any reported usage (never 0%).
      expect(
        find.descendant(of: knobFinder, matching: find.text('—')),
        findsOneWidget,
      );
      expect(find.text('0%'), findsNothing);

      // Emit measured usage (88% -> error color band).
      rig.emitState(
        models: [
          ModelEntry(
            id: 'm1',
            providerId: 'p1',
            label: 'Model 1',
            contextLimit: 100000,
          ),
        ],
        timeline: [
          _assistantStep(
            rig.ref,
            msgId: 'msg_1',
            input: 70000,
            output: 8000,
            reasoning: 2000,
            cacheRead: 6000,
            cacheWrite: 2000,
            cost: 0.42,
          ),
        ],
        usage: [
          UsageObservation(
            id: 'session-total',
            owner: SessionOwner(rig.ref),
            scope: const OpenValue.known(UsageScope.session),
            source: const OpenValue.known(UsageSource.native),
            observedAt: DateTime.utc(2026, 11, 21, 12, 1),
            cumulative: true,
            aggregationKey: 'session-total',
            cost: Cost(amount: 0.42, currency: 'USD', cumulative: true),
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(
        find.descendant(of: knobFinder, matching: find.text('88')),
        findsOneWidget,
      );
      final ring = tester
          .widgetList<CircularProgressIndicator>(
            find.descendant(
              of: knobFinder,
              matching: find.byType(CircularProgressIndicator),
            ),
          )
          .last;
      final theme = Theme.of(tester.element(knobFinder));
      expect(
        (ring.valueColor! as AlwaysStoppedAnimation<Color>).value,
        theme.colorScheme.error,
      );

      // Open anchored wide popover.
      await tester.tap(knobFinder);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('context-usage-popover')),
        findsOneWidget,
      );
      expect(find.text('88%'), findsOneWidget);
      expect(find.text('88,000'), findsOneWidget);
      expect(find.text(r'$0.4200'), findsOneWidget);
      expect(find.text('100,000'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('context-usage-breakdown')),
        findsOneWidget,
      );
      expect(
        find.text('Quota is not exposed by this harness.'),
        findsOneWidget,
      );

      // Trigger Compact now inside popover.
      await tester.tap(find.byKey(const ValueKey('context-usage-compact-now')));
      await tester.pumpAndSettle();
      expect(rig.port.compactCalls, 1);
    },
  );

  testWidgets('unpinned wide overflow action opens bounded dialog', (
    tester,
  ) async {
    final rig = _UsageRig(
      tester,
      usageCapabilities: openCodeUsageCapabilities('2.0.22'),
    );
    addTearDown(rig.dispose);
    await rig.start();
    rig.preferences.setAppBarPinned(WorkspacePinnedAction.contextUsage, false);
    rig.emitState();
    tester.view.physicalSize = const Size(900, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(rig.buildApp(width: 900));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('workspace-pinned-contextUsage')),
      findsNothing,
    );
    await tester.tap(find.byKey(const ValueKey('workspace-actions')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('workspace-menu-contextUsage')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('context-usage-dialog')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('context-usage-dialog-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('context-usage-dialog')), findsNothing);
  });

  testWidgets(
    'compact 360dp opens bottom sheet with full-width Compact now and supports RTL & quota windows',
    (tester) async {
      final capsWithQuota = {
        ...openCodeUsageCapabilities('2.0.22'),
        UsageCapabilities.quota: Capability(
          support: const OpenValue.known(Support.native),
          verified: true,
        ),
      };
      final rig = _UsageRig(
        tester,
        usageCapabilities: capsWithQuota,
        compacting: true,
      );
      addTearDown(rig.dispose);
      await rig.start();
      rig.emitState(
        usage: [
          UsageObservation(
            id: 'quota-1',
            owner: SessionOwner(rig.ref),
            scope: const OpenValue.known(UsageScope.account),
            source: const OpenValue.known(UsageSource.native),
            observedAt: DateTime.utc(2026, 11, 21, 12, 0),
            quotas: [
              QuotaWindow(
                id: 'w1',
                label: 'Weekly',
                source: const OpenValue.known(UsageSource.native),
                usedPercent: 120,
              ),
              QuotaWindow(
                id: 'w2',
                label: 'Rolling',
                source: const OpenValue.known(UsageSource.native),
              ),
            ],
          ),
        ],
      );
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        rig.buildApp(width: 360, locale: const Locale('ar')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final knobFinder = find.byKey(
        const ValueKey('workspace-pinned-contextUsage'),
      );
      expect(
        find.descendant(
          of: knobFinder,
          matching: find.byType(AppIndeterminateRing),
        ),
        findsOneWidget,
      );

      await tester.tap(knobFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const ValueKey('context-usage-sheet')), findsOneWidget);
      expect(find.text('Weekly'), findsOneWidget);
      expect(find.text('120%'), findsOneWidget);
      expect(find.text('Rolling'), findsOneWidget);

      // Compact row is disabled while compacting and at least 48dp tall.
      final compactFinder = find.byKey(
        const ValueKey('context-usage-compact-now'),
      );
      expect(tester.getSize(compactFinder).height, greaterThanOrEqualTo(48));
      expect(tester.widget<InkWell>(compactFinder).onTap, isNull);
    },
  );
}
