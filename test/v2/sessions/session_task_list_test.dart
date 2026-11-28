import 'package:codewalk/app/app_preferences_controller.dart';
import 'package:codewalk/app/workspace_chrome.dart';
import 'package:codewalk/features/sessions/session_live_controller.dart';
import 'package:codewalk/features/sessions/session_live_page.dart';
import 'package:codewalk/features/sessions/session_task_list.dart';
import 'package:codewalk/features/sessions/session_timeline_projection.dart';
import 'package:codewalk/features/sessions/session_timeline_search.dart';
import 'package:codewalk/features/sessions/session_tool_details_dialog.dart';
import 'package:codewalk/features/sessions/session_work_group.dart';
import 'package:codewalk/features/settings/appearance_settings_page.dart';
import 'package:codewalk/platform/storage/metadata_store.dart';
import 'package:codewalk/shared/l10n/generated/v2_localizations.dart';
import 'package:codewalk/shared/l10n/generated/v2_localizations_en.dart';
import 'package:codewalk/shared/sessions/session_live_source.dart';
import 'package:codewalk/shared/sessions/session_plan.dart';
import 'package:codewalk/shared/theme/app_theme.dart';
import 'package:codewalk/shared/theme/chat_appearance.dart';
import 'package:codewalk/shared/widgets/app_indeterminate_progress.dart';
import 'package:codewalk_core/codewalk_core.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../storage/storage_fakes.dart';
import 'fakes.dart';
import 'live_fakes.dart';

const _host = HostId('host-1');
const _harness = HarnessInstanceId('inst-1');
const _session = SessionRef(_host, _harness, 'ses-1');
const _owner = SessionOwner(_session);

MessageAnchor _anchor(String id) =>
    MessageAnchor(message: MessageRef(id), orderKey: id);

PlanEntry _entry(String id, String title, PlanStatus status) =>
    PlanEntry(id: id, title: title, status: OpenValue.known(status));

PlanSnapshot _plan(List<PlanEntry> entries, {String msgId = 'msg_002'}) =>
    PlanSnapshot(owner: _owner, entries: entries, anchor: _anchor(msgId));

Widget _wrap(
  Widget child, {
  AppPreferencesController? preferences,
  bool disableAnimations = false,
  bool showToolCalls = true,
}) {
  Widget app = MaterialApp(
    theme: AppTheme.lightFrom(
      ColorScheme.fromSeed(seedColor: AppTheme.seedColor),
    ),
    localizationsDelegates: V2Localizations.localizationsDelegates,
    supportedLocales: V2Localizations.supportedLocales,
    locale: const Locale('en'),
    builder: (context, inner) {
      final media = MediaQuery.of(context);
      return MediaQuery(
        data: disableAnimations
            ? media.copyWith(disableAnimations: true)
            : media,
        child: ChatAppearance(
          mathRendering: true,
          conversationTextScale: 1,
          showToolCalls: showToolCalls,
          child: inner ?? const SizedBox.shrink(),
        ),
      );
    },
    home: child,
  );
  if (preferences != null) {
    app = ChangeNotifierProvider<AppPreferencesController>.value(
      value: preferences,
      child: app,
    );
  }
  return app;
}

void main() {
  testWidgets('five rows show, the task in progress in the middle (#550)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    PlanSnapshot plan(int active) => _plan([
      for (var i = 0; i < 10; i++)
        _entry(
          '$i',
          'Task number $i',
          i < active
              ? PlanStatus.completed
              : i == active
              ? PlanStatus.inProgress
              : PlanStatus.pending,
        ),
    ]);
    Future<void> show(int active) async {
      await tester.pumpWidget(
        _wrap(
          Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: SessionTaskListPanel(
                plan: plan(active),
                collapsed: false,
                onToggleCollapsed: () {},
              ),
            ),
          ),
          disableAnimations: true,
        ),
      );
      await tester.pumpAndSettle();
    }

    Set<int> shown() {
      final list = tester.getRect(
        find.byKey(const ValueKey('session-todo-list')),
      );
      return {
        for (var i = 0; i < 10; i++)
          if (list.contains(
            tester.getCenter(find.byKey(ValueKey('session-todo-item-$i'))),
          ))
            i,
      };
    }

    await show(5);
    expect(shown(), {3, 4, 5, 6, 7});
    // Another task in progress: the list turns to it.
    await show(6);
    expect(shown(), {4, 5, 6, 7, 8});
    // Near the end, the last five.
    await show(9);
    expect(shown(), {5, 6, 7, 8, 9});
  });

  TestWidgetsFlutterBinding.ensureInitialized();

  group(
    'ToolKind.plan suppression in timeline, work group, details and search',
    () {
      final source = SourceProvenance(
        harness: _session.harnessRef,
        version: '2.3.2',
        nativeType: 'assistant',
      );
      ToolCall planCall(String id) => ToolCall(
        meta: ItemMeta(
          id: ItemId(id),
          generation: 'g1',
          status: const OpenValue.known(ItemStatus.completed),
          source: source,
          anchor: _anchor('msg_002'),
        ),
        kind: const OpenValue.known(ToolKind.plan),
        rawName: 'todowrite',
        input: CanonicalValue({
          'todos': [
            {'content': 'Secret task text', 'status': 'in_progress'},
          ],
        }),
      );

      test(
        'omits ToolKind.plan from sessionTimelineItems, stretches and search',
        () {
          final user = UserInput(
            meta: ItemMeta(
              id: const ItemId('u1'),
              generation: 'g1',
              status: const OpenValue.known(ItemStatus.completed),
              source: source,
              anchor: _anchor('msg_001'),
            ),
            text: 'Please plan this',
            delivery: const OpenValue.known(DeliveryState.delivered),
            confirmed: true,
          );
          final answer = AssistantText(
            meta: ItemMeta(
              id: const ItemId('a1'),
              generation: 'g1',
              status: const OpenValue.known(ItemStatus.completed),
              source: source,
              anchor: _anchor('msg_002'),
            ),
            text: 'Done planning',
            complete: true,
          );
          final call = planCall('t1');

          expect(sessionTimelineItems([user, call, answer]), [user, answer]);
          expect(SessionTimelinePresentation.isCompactable(call), isFalse);

          final presentation = SessionTimelinePresentation();
          final rows = presentation.project([
            user,
            call,
            answer,
          ], settled: true);
          expect(rows.length, 2);
          expect(rows.expand((r) => r.items), isNot(contains(call)));

          final l10n = V2LocalizationsEn();
          expect(activitySummaryParts([call], l10n), isEmpty);
          expect(toolKindLabel(call, l10n), l10n.sessionTabIconPresetTasks);
          expect(toolIcon(call), isNotNull);

          final search = SessionTimelineSearch();
          expect(
            search.matches(sessionTimelineItems([user, call, answer])),
            isEmpty,
          );
          expect(SessionTimelineSearch.searchableText(call), isNull);
        },
      );
    },
  );

  group('SessionTaskListPanel widget', () {
    testWidgets(
      'shows distinct collapsed vs expanded layouts, progress bar, +N and cancelled',
      (tester) async {
        tester.view.physicalSize = const Size(420, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        var collapsed = true;
        final plan = _plan([
          _entry('0', 'Finished step', PlanStatus.completed),
          _entry('1', 'Active primary step', PlanStatus.inProgress),
          _entry('2', 'Active parallel step', PlanStatus.inProgress),
          _entry('3', 'Skipped step', PlanStatus.cancelled),
          _entry('4', 'Future step', PlanStatus.pending),
        ]);

        await tester.pumpWidget(
          _wrap(
            StatefulBuilder(
              builder: (context, setState) => Scaffold(
                body: SessionTaskListPanel(
                  plan: plan,
                  collapsed: collapsed,
                  onToggleCollapsed: () =>
                      setState(() => collapsed = !collapsed),
                ),
              ),
            ),
            disableAnimations: true,
          ),
        );
        await tester.pumpAndSettle();

        // Compact collapsed summary: count-first + active task + `+1` parallel badge.
        expect(find.text('2/5 Active primary step'), findsOneWidget);
        expect(find.byType(AppIndeterminateRing), findsNothing);
        final collapsedIcon = tester.widget<Icon>(
          find.byIcon(Symbols.double_arrow),
        );
        expect(collapsedIcon.size, 16);
        expect(collapsedIcon.semanticLabel, 'In progress');
        expect(
          find.byKey(const ValueKey('session-todo-more-in-progress')),
          findsOneWidget,
        );
        expect(find.text('+1'), findsOneWidget);
        expect(find.byKey(const ValueKey('session-todo-list')), findsNothing);

        final bar = tester.widget<LinearProgressIndicator>(
          find.byKey(const ValueKey('session-todo-progress-bar')),
        );
        expect(bar.value, closeTo(0.2, 1e-6));

        // Tap header to expand.
        await tester.tap(find.byKey(const ValueKey('session-todo-header')));
        await tester.pumpAndSettle();

        // The chip carries the counts; the title does not repeat them (#549).
        expect(find.text('Tasks'), findsOneWidget);
        expect(find.textContaining('('), findsNothing);
        expect(find.text('1/5'), findsOneWidget);
        expect(find.text('1 cancelled'), findsOneWidget);
        expect(find.text('+1'), findsOneWidget);
        expect(find.byKey(const ValueKey('session-todo-list')), findsOneWidget);
        expect(find.byType(AppIndeterminateRing), findsNothing);
        expect(find.byIcon(Symbols.double_arrow), findsNWidgets(2));
        for (final rowId in ['1', '2']) {
          final rowIcon = tester.widget<Icon>(
            find.descendant(
              of: find.byKey(ValueKey('session-todo-item-$rowId')),
              matching: find.byIcon(Symbols.double_arrow),
            ),
          );
          expect(rowIcon.size, 16);
          expect(rowIcon.semanticLabel, 'In progress');
        }
        expect(find.text('Finished step'), findsOneWidget);
        expect(find.text('Skipped step'), findsOneWidget);
        expect(find.text('Future step'), findsOneWidget);
        // Progress bar stays right below header in expanded state too.
        expect(
          find.byKey(const ValueKey('session-todo-progress-bar')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'wide collapsed layout uses descriptive Task x/y and completed summary',
      (tester) async {
        tester.view.physicalSize = const Size(900, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          _wrap(
            Scaffold(
              body: SessionTaskListPanel(
                plan: _plan([
                  _entry('0', 'First', PlanStatus.completed),
                  _entry('1', 'Second', PlanStatus.inProgress),
                ]),
                collapsed: true,
                onToggleCollapsed: () {},
              ),
            ),
            disableAnimations: true,
          ),
        );
        expect(find.text('Task 2/2 · Second'), findsOneWidget);

        await tester.pumpWidget(
          _wrap(
            Scaffold(
              body: SessionTaskListPanel(
                plan: _plan([
                  _entry('0', 'First', PlanStatus.completed),
                  _entry('1', 'Second', PlanStatus.cancelled),
                ]),
                collapsed: true,
                onToggleCollapsed: () {},
              ),
            ),
            disableAnimations: true,
          ),
        );
        expect(find.text('Tasks 1/2 completed · 1 cancelled'), findsOneWidget);
      },
    );

    testWidgets(
      'mobile keyboard inset auto-collapses without mutating preference and restores',
      (tester) async {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        var toggleCount = 0;
        await tester.pumpWidget(
          _wrap(
            Scaffold(
              body: SessionTaskListPanel(
                plan: _plan([
                  _entry('0', 'Step 1', PlanStatus.inProgress),
                  _entry('1', 'Step 2', PlanStatus.pending),
                ]),
                collapsed: false,
                onToggleCollapsed: () => toggleCount++,
              ),
            ),
            disableAnimations: true,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('session-todo-list')), findsOneWidget);

        // Software keyboard opens -> panel auto-collapses and ignores header taps.
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('session-todo-list')), findsNothing);

        await tester.tap(find.byKey(const ValueKey('session-todo-header')));
        await tester.pumpAndSettle();
        expect(toggleCount, 0);

        // Keyboard closes -> restores expanded state.
        tester.view.viewInsets = FakeViewPadding.zero;
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('session-todo-list')), findsOneWidget);
      },
    );

    testWidgets(
      'handles animations, unknown/all-cancelled statuses, auto-scroll, RTL and 2x text',
      (tester) async {
        tester.view.physicalSize = const Size(390, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        var collapsed = false;
        final longPlan = _plan([
          for (var i = 0; i < 8; i++)
            _entry('$i', 'Completed item $i', PlanStatus.completed),
          _entry('8', 'Active deep task', PlanStatus.inProgress),
          PlanEntry(
            id: '9',
            title: 'Unknown state task',
            status: OpenValue.unknown('deferred'),
          ),
        ]);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightFrom(
              ColorScheme.fromSeed(seedColor: AppTheme.seedColor),
            ),
            localizationsDelegates: V2Localizations.localizationsDelegates,
            supportedLocales: V2Localizations.supportedLocales,
            locale: const Locale('ar'),
            builder: (context, inner) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2.0)),
              child: ChatAppearance(
                mathRendering: true,
                conversationTextScale: 1,
                child: inner ?? const SizedBox.shrink(),
              ),
            ),
            home: StatefulBuilder(
              builder: (context, setState) => Scaffold(
                body: SessionTaskListPanel(
                  plan: longPlan,
                  collapsed: collapsed,
                  onToggleCollapsed: () =>
                      setState(() => collapsed = !collapsed),
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);
        expect(find.text('Active deep task'), findsOneWidget);
        expect(find.text('Unknown state task'), findsOneWidget);
        expect(find.byType(AppIndeterminateRing), findsNothing);
        expect(Symbols.double_arrow.matchTextDirection, isTrue);
        final rtlExpandedFlip = tester.widget<Transform>(
          find.descendant(
            of: find.byIcon(Symbols.double_arrow),
            matching: find.byType(Transform),
          ),
        );
        expect(rtlExpandedFlip.transform.storage[0], -1.0);

        // Collapse with animations active.
        await tester.tap(find.byKey(const ValueKey('session-todo-header')));
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);
        expect(find.byKey(const ValueKey('session-todo-list')), findsNothing);
        expect(find.byType(AppIndeterminateRing), findsNothing);
        final rtlCollapsedFlip = tester.widget<Transform>(
          find.descendant(
            of: find.byIcon(Symbols.double_arrow),
            matching: find.byType(Transform),
          ),
        );
        expect(rtlCollapsedFlip.transform.storage[0], -1.0);

        // All-cancelled header icon path & empty entries no-op path.
        await tester.pumpWidget(
          _wrap(
            Scaffold(
              body: Column(
                children: [
                  SessionTaskListPanel(
                    plan: _plan([
                      _entry('0', 'Only cancelled', PlanStatus.cancelled),
                    ]),
                    collapsed: true,
                    onToggleCollapsed: () {},
                  ),
                  SessionTaskListPanel(
                    plan: _plan(const []),
                    collapsed: true,
                    onToggleCollapsed: () {},
                  ),
                ],
              ),
            ),
            disableAnimations: true,
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(
          find.byKey(const ValueKey('session-todo-panel')),
          findsOneWidget,
        );
      },
    );
  });

  group('Display menu toggle and SessionLivePage integration', () {
    testWidgets(
      'Display sheet toggles showTaskList and Appearance settings has no toggle',
      (tester) async {
        final prefs = AppPreferencesController(
          store: V2MetadataStore(backend: FakeMetadataBackend()),
        );
        addTearDown(prefs.dispose);
        await prefs.initialize();

        await tester.pumpWidget(
          _wrap(
            Builder(
              builder: (context) => Scaffold(
                body: Column(
                  children: [
                    TextButton(
                      key: const ValueKey('open-display'),
                      onPressed: () => showWorkspaceDisplayMenu(context),
                      child: const Text('Display'),
                    ),
                    const Expanded(child: AppearanceSettingsPage()),
                  ],
                ),
              ),
            ),
            preferences: prefs,
          ),
        );
        await tester.pumpAndSettle();

        // Confirm Appearance settings does NOT expose a task list toggle.
        expect(
          find.byKey(const ValueKey('settings_toggle_task_list')),
          findsNothing,
        );

        await tester.tap(find.byKey(const ValueKey('open-display')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('display-toggle-task-list')),
          findsOneWidget,
        );
        expect(prefs.showTaskList, isTrue);

        await tester.tap(
          find.byKey(const ValueKey('display-toggle-task-list')),
        );
        await tester.pumpAndSettle();
        expect(prefs.showTaskList, isFalse);
      },
    );

    testWidgets(
      'SessionLivePage pins plan at top, survives idle/showToolCalls=false, clears on next prompt, and avoids short-viewport overflow',
      (tester) async {
        tester.view.physicalSize = const Size(400, 720);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        final prefs = AppPreferencesController(
          store: V2MetadataStore(backend: FakeMetadataBackend()),
        );
        addTearDown(prefs.dispose);
        await prefs.initialize();

        final rig = CatalogRig();
        addTearDown(rig.dispose);
        await rig.save('a');
        await rig.sessions.initialize();
        final directory = LiveDirectory();
        final summary = CatalogSource(profile('a')).row('one');
        final liveSession = summary.info.ref;

        final source = SourceProvenance(
          harness: liveSession.harnessRef,
          version: '2.3.2',
          nativeType: 'test',
        );
        var state = SessionState(liveSession);
        var seq = 1;
        StreamPosition nextPos() =>
            StreamPosition(id: 's', epoch: '1', seq: BigInt.from(seq++));
        EventMeta nextMeta() => EventMeta(
          owner: SessionOwner(liveSession),
          position: nextPos(),
          receivedAt: DateTime.utc(2026, 11, 23, 12, 0, seq),
          source: source,
        );
        state = reduce(
          state,
          ItemUpserted(
            meta: nextMeta(),
            item: UserInput(
              meta: ItemMeta(
                id: const ItemId('u1'),
                generation: 'g1',
                status: const OpenValue.known(ItemStatus.completed),
                source: source,
                anchor: _anchor('msg_001'),
              ),
              text: 'First turn',
              delivery: const OpenValue.known(DeliveryState.delivered),
              confirmed: true,
            ),
          ),
        ).state;
        state = reduce(
          state,
          PlanChanged(
            meta: nextMeta(),
            plan: PlanSnapshot(
              owner: SessionOwner(liveSession),
              anchor: _anchor('msg_002'),
              entries: [
                _entry('0', 'Completed task', PlanStatus.completed),
                _entry('1', 'Second completed task', PlanStatus.completed),
              ],
            ),
          ),
        ).state;
        state = reduce(
          state,
          ExecutionChanged(
            meta: nextMeta(),
            state: const ExecutionState(
              kind: OpenValue.known(ExecutionKind.idle),
            ),
          ),
        ).state;

        final controller = SessionLiveController(
          hosts: rig.hosts,
          profile: profile('a'),
          summary: summary,
          directory: directory,
        );
        addTearDown(controller.dispose);
        final opening = controller.start();
        final handle = directory.grant(liveSession);
        await opening;
        handle.emit(
          SessionLiveView(
            session: liveSession,
            phase: SessionLivePhase.live,
            state: state,
            lastSyncedAt: DateTime.utc(2026, 11, 23, 12, 1),
          ),
        );

        await tester.pumpWidget(
          _wrap(
            SessionLivePage(controller: controller, ownsController: false),
            preferences: prefs,
            showToolCalls: false,
            disableAnimations: true,
          ),
        );
        await tester.pumpAndSettle();

        // Visible at 100% done while idle, even with showToolCalls=false.
        expect(
          find.byKey(const ValueKey('session-todo-panel')),
          findsOneWidget,
        );
        expect(find.text('Completed task'), findsOneWidget);

        // Short viewport + keyboard inset + permission card: no overflow & collapsed.
        final withPermission = reduce(
          state,
          InteractionOpened(
            meta: nextMeta(),
            request: InteractionRequest(
              id: const InteractionId('perm-1'),
              owner: SessionOwner(liveSession),
              kind: const OpenValue.known(InteractionKind.permission),
              title: 'Allow command?',
              choices: [
                ApprovalChoice(
                  id: 'once',
                  label: 'Allow once',
                  allows: true,
                  scope: const OpenValue.known(ApprovalScope.once),
                  resolutionScope: const OpenValue.known(
                    ResolutionScope.request,
                  ),
                ),
              ],
            ),
          ),
        ).state;
        handle.emit(
          SessionLiveView(
            session: liveSession,
            phase: SessionLivePhase.live,
            state: withPermission,
            lastSyncedAt: DateTime.utc(2026, 11, 23, 12, 2),
          ),
        );
        tester.view.physicalSize = const Size(360, 260);
        tester.view.viewInsets = const FakeViewPadding(bottom: 120);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byKey(const ValueKey('session-todo-list')), findsNothing);

        // Restore normal viewport and send a new user message -> panel clears!
        tester.view.physicalSize = const Size(400, 720);
        tester.view.viewInsets = FakeViewPadding.zero;
        await tester.pumpAndSettle();

        final nextTurn = reduce(
          state,
          ItemUpserted(
            meta: nextMeta(),
            item: UserInput(
              meta: ItemMeta(
                id: const ItemId('u2'),
                generation: 'g1',
                status: const OpenValue.known(ItemStatus.completed),
                source: source,
                anchor: _anchor('msg_003'),
              ),
              text: 'Second turn',
              delivery: const OpenValue.known(DeliveryState.delivered),
              confirmed: true,
            ),
          ),
        ).state;
        handle.emit(
          SessionLiveView(
            session: liveSession,
            phase: SessionLivePhase.live,
            state: nextTurn,
            lastSyncedAt: DateTime.utc(2026, 11, 23, 12, 3),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('session-todo-panel')), findsNothing);

        // Plan capabilities contract exposed via SessionLivePlan extension.
        final SessionLiveHandle baseHandle = handle;
        expect(baseHandle.planCapabilities, isEmpty);
        handle.planCapabilities = {
          PlanCapabilities.observe: Capability(
            support: const OpenValue.known(Support.native),
            verified: true,
          ),
        };
        expect(
          baseHandle.planCapabilities[PlanCapabilities.observe]?.isAvailable,
          isTrue,
        );
      },
    );

    testWidgets(
      'expanded compact 320px at 2x scale, duplicate entry IDs, and header semantics do not overflow or drop +N',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        final semantics = tester.ensureSemantics();
        try {
          final plan = _plan([
            _entry('dup', 'First parallel task', PlanStatus.inProgress),
            _entry('dup', 'Second parallel task', PlanStatus.inProgress),
            _entry('2', 'Cancelled step', PlanStatus.cancelled),
            _entry('3', 'Done step', PlanStatus.completed),
          ]);

          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.lightFrom(
                ColorScheme.fromSeed(seedColor: AppTheme.seedColor),
              ),
              localizationsDelegates: V2Localizations.localizationsDelegates,
              supportedLocales: V2Localizations.supportedLocales,
              locale: const Locale('en'),
              builder: (context, inner) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(2.0)),
                child: ChatAppearance(
                  mathRendering: true,
                  conversationTextScale: 1,
                  child: inner ?? const SizedBox.shrink(),
                ),
              ),
              home: Scaffold(
                body: SessionTaskListPanel(
                  plan: plan,
                  collapsed: false,
                  onToggleCollapsed: () {},
                ),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 200));
          expect(tester.takeException(), isNull);
          expect(find.text('First parallel task'), findsOneWidget);
          expect(find.text('Second parallel task'), findsOneWidget);

          final headerSemantics = tester.getSemantics(
            find.byKey(const ValueKey('session-todo-header')),
          );
          expect(headerSemantics.label, contains('1 more in progress'));
          expect(headerSemantics.label, contains('1 cancelled'));
        } finally {
          semantics.dispose();
        }
      },
    );
  });
}
