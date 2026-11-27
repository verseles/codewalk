import 'dart:async';
import 'dart:convert';

import 'package:codewalk/features/sessions/session_live_controller.dart';
import 'package:codewalk/features/sessions/session_subagent_capsule.dart';
import 'package:codewalk/shared/l10n/generated/v2_localizations.dart';
import 'package:codewalk/shared/sessions/session_live_source.dart';
import 'package:codewalk/shared/sessions/session_shells.dart';
import 'package:codewalk_core/codewalk_core.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';
import 'live_fakes.dart';

final class _FakeShellPort implements SessionShellPort {
  _FakeShellPort({this.canObserve = true, this.canStop = true});

  @override
  bool canObserve;

  @override
  bool canStop;

  final stopping = <String>{};
  final stopCalls = <String>[];
  final readCalls = <(String, int?, int)>[];
  final cancellations = <SessionShellCancellation>[];
  Future<ShellOutputPage?> Function(
    String shellId,
    int? cursor,
    int limit,
    SessionShellCancellation? cancellation,
  )?
  onReadOutput;
  Future<SessionShellStopOutcome> Function(String shellId)? onStop;

  @override
  bool isStopping(String shellId) => stopping.contains(shellId);

  @override
  Future<void> refresh() async {}

  @override
  Future<ShellOutputPage?> readOutput(
    String shellId, {
    int? cursor,
    int limit = 16 * 1024,
    SessionShellCancellation? cancellation,
  }) {
    readCalls.add((shellId, cursor, limit));
    if (cancellation != null) cancellations.add(cancellation);
    return onReadOutput?.call(shellId, cursor, limit, cancellation) ??
        Future.value(null);
  }

  @override
  Future<SessionShellStopOutcome> stop(String shellId, {CommandId? id}) {
    stopCalls.add(shellId);
    return onStop?.call(shellId) ??
        Future.value(SessionShellStopOutcome.accepted);
  }
}

Future<
  ({
    SessionLiveController live,
    LiveHandle handle,
    SessionRef parent,
    List<SessionRef> opened,
  })
>
_mount(
  WidgetTester tester, {
  SessionShellPort? shellPort,
  DateTime Function()? clock,
  Locale locale = const Locale('en'),
  double scale = 1.0,
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final catalog = CatalogRig();
  await catalog.save('a');
  await catalog.sessions.initialize();
  final directory = LiveDirectory();
  final summary = CatalogSource(profile('a')).row('one');
  final live = SessionLiveController(
    hosts: catalog.hosts,
    profile: profile('a'),
    summary: summary,
    directory: directory,
    now: clock ?? () => DateTime.utc(2026, 11, 19, 1, 0, 10),
  );
  final opened = <SessionRef>[];
  addTearDown(catalog.dispose);
  addTearDown(live.dispose);
  addTearDown(() => tester.pumpWidget(const SizedBox()));
  final opening = live.start();
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: V2Localizations.localizationsDelegates,
      supportedLocales: V2Localizations.supportedLocales,
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        minScaleFactor: scale,
        maxScaleFactor: scale,
        child: child!,
      ),
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              const Expanded(child: SizedBox()),
              SessionSubagentCapsule(live: live, onOpen: opened.add),
              const SizedBox(height: 120),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  final handle = directory.grant(summary.info.ref)..shells = shellPort;
  await opening;
  await tester.pump();
  return (live: live, handle: handle, parent: summary.info.ref, opened: opened);
}

ShellWork _shellWork(
  SessionRef parent,
  String id, {
  String command = 'npm run dev',
  ShellStatus status = ShellStatus.running,
  DateTime? startedAt,
  DateTime? completedAt,
  int? exitCode,
}) => ShellWork(
  id: id,
  owner: SessionOwner(parent),
  command: command,
  status: OpenValue.known(status),
  startedAt: startedAt ?? DateTime.utc(2026, 11, 19, 1, 0, 0),
  completedAt: completedAt,
  exitCode: exitCode,
);

ToolCall _shellTool(
  SessionRef parent,
  String itemId, {
  String? shellId,
  String command = 'npm run dev',
  ShellStatus shellStatus = ShellStatus.running,
  int? exitCode,
  bool background = false,
}) => ToolCall(
  meta: liveMeta(parent, itemId),
  kind: const OpenValue.known(ToolKind.shell),
  rawName: 'shell',
  input: CanonicalValue({'command': command}),
  output: CanonicalValue(const [
    {'type': 'text', 'text': 'timeline shell output'},
  ]),
  runFacts: ToolRunFacts(
    shellId: shellId,
    shellStatus: OpenValue.known(shellStatus),
    exitCode: exitCode,
    background: background,
  ),
);

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  testWidgets(
    'unified capsule counts active subagents + running shells, deduplicates by shellId, ticks elapsed timer while open, and stops cleanly',
    (tester) async {
      var now = DateTime.utc(2026, 11, 19, 1, 0, 10);
      final port = _FakeShellPort();
      final rig = await _mount(tester, shellPort: port, clock: () => now);
      final child = SessionRef(rig.parent.host, rig.parent.harness, 'ses_c1');
      final subagent = WorkItem(
        id: const WorkId('w1'),
        owner: SessionOwner(child, origin: rig.parent),
        child: child,
        parent: rig.parent,
        status: const OpenValue.known(WorkStatus.running),
        completionScope: const OpenValue.known(CompletionScope.child),
        title: 'Analyzer',
      );

      // Running shell sh_1 has a matching timeline twin -> deduplicated to Active ONLY.
      // Completed timeline shell sh_done goes to Completed.
      void emit({
        required List<ShellWork> shells,
        required List<TimelineItem> items,
      }) {
        rig.handle.emit(
          SessionLiveView(
            session: rig.parent,
            phase: SessionLivePhase.live,
            state: liveState(
              rig.parent,
              work: [subagent],
              shells: shells,
              items: items,
            ),
          ),
        );
      }

      final runningShell = _shellWork(
        rig.parent,
        'sh_1',
        command: 'make watch',
      );
      final runningTwin = _shellTool(
        rig.parent,
        'item_sh1',
        shellId: 'sh_1',
        command: 'make watch',
        shellStatus: ShellStatus.running,
        background: true,
      );
      final completedTool = _shellTool(
        rig.parent,
        'item_sh2',
        shellId: 'sh_2',
        command: 'git status',
        shellStatus: ShellStatus.exited,
        exitCode: 0,
      );
      emit(shells: [runningShell], items: [runningTwin, completedTool]);
      await _settle(tester);

      // Badge counts 1 active subagent + 1 running shell = 2.
      expect(find.byKey(const ValueKey('subagent-capsule')), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('subagent-count'))).data,
        '2',
      );

      // Open pop-in: Active shows both Analyzer and sh_1 with elapsed time + Stop.
      await tester.tap(find.byKey(const ValueKey('subagent-capsule')));
      await _settle(tester);
      expect(find.text('Analyzer'), findsOneWidget);
      expect(find.byKey(const ValueKey('shell-row-sh_1')), findsOneWidget);
      expect(find.textContaining('10s'), findsOneWidget);
      expect(find.byKey(const ValueKey('shell-stop-sh_1')), findsOneWidget);

      // Advance clock by 2 seconds: live timer updates elapsed display.
      now = DateTime.utc(2026, 11, 19, 1, 0, 12);
      await tester.pump(const Duration(seconds: 1));
      expect(find.textContaining('12s'), findsOneWidget);

      // Completed tab contains ONLY sh_2 (sh_1 is NOT duplicated there).
      final l10n = V2Localizations.of(
        tester.element(find.byKey(const ValueKey('subagent-popin'))),
      );
      await tester.tap(find.text(l10n.liveSubagentsCompleted));
      await _settle(tester);
      expect(find.byKey(const ValueKey('shell-row-sh_2')), findsOneWidget);
      expect(find.byKey(const ValueKey('shell-row-sh_1')), findsNothing);

      // Return to Active and tap Stop -> triggers single-flight stop on port.
      await tester.tap(find.text(l10n.liveSubagentsActive));
      await _settle(tester);
      await tester.tap(find.byKey(const ValueKey('shell-stop-sh_1')));
      await tester.pump();
      expect(port.stopCalls, ['sh_1']);

      // Simulate shell exit: sh_1 moves out of Active, timer cancels cleanly.
      emit(
        shells: [
          _shellWork(
            rig.parent,
            'sh_1',
            command: 'make watch',
            status: ShellStatus.killed,
            completedAt: DateTime.utc(2026, 11, 19, 1, 0, 12),
          ),
        ],
        items: [runningTwin, completedTool],
      );
      await _settle(tester);
      expect(find.byKey(const ValueKey('shell-row-sh_1')), findsNothing);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('subagent-count'))).data,
        '1',
      );
    },
  );

  testWidgets(
    'running shell opens cursor-paged redacted output dialog, handles truncation/404, and cancels read on dispose',
    (tester) async {
      final port = _FakeShellPort();
      final pendingPage = Completer<ShellOutputPage?>();
      var call = 0;
      port.onReadOutput = (id, cursor, limit, cancel) {
        call++;
        if (call == 1) {
          return Future.value(
            ShellOutputPage(
              output: 'token=mysecretvalue12345\nline 1\n',
              cursor: 32,
              size: 64,
              truncated: false,
            ),
          );
        }
        if (call == 2) {
          return Future.value(
            ShellOutputPage(
              output: 'line 2\n',
              cursor: 64,
              size: 64,
              truncated: true,
            ),
          );
        }
        return pendingPage.future;
      };
      final rig = await _mount(tester, shellPort: port);
      rig.handle.emit(
        SessionLiveView(
          session: rig.parent,
          phase: SessionLivePhase.live,
          state: liveState(
            rig.parent,
            shells: [_shellWork(rig.parent, 'sh_tail', command: 'tail -f log')],
          ),
        ),
      );
      await _settle(tester);

      // Running shell alone activates the sweeping activity border (#525).
      expect(
        tester
            .widget<CustomPaint>(
              find.byKey(const ValueKey('subagent-capsule-activity-border')),
            )
            .foregroundPainter,
        isNotNull,
      );
      expect(tester.binding.hasScheduledFrame, isTrue);

      await tester.tap(find.byKey(const ValueKey('subagent-capsule')));
      await _settle(tester);
      await tester.tap(find.byKey(const ValueKey('shell-row-sh_tail')));
      await _settle(tester);

      expect(
        find.byKey(const ValueKey('shell-output-dialog-sh_tail')),
        findsOneWidget,
      );
      expect(find.textContaining('mysecretvalue12345'), findsNothing);
      expect(find.textContaining('[redacted]'), findsOneWidget);
      expect(find.textContaining('line 1'), findsOneWidget);

      // Tap Load more output -> fetches page 2 at raw cursor=32, shows
      // truncated notice, and hides Load more once cursor==size.
      await tester.tap(find.byKey(const ValueKey('shell-output-more-sh_tail')));
      await _settle(tester);
      expect(port.readCalls[1], ('sh_tail', 32, 16 * 1024));
      expect(find.textContaining('line 2'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('shell-output-truncated')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('shell-output-more-sh_tail')),
        findsNothing,
      );

      // Trigger another refresh and close dialog -> cancellation token is cancelled!
      await tester.tap(
        find.byKey(const ValueKey('shell-output-refresh-sh_tail')),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('shell-output-close')));
      await _settle(tester);
      expect(port.cancellations.last.isCancelled, isTrue);
    },
  );

  testWidgets(
    'without shell.observe or shell.stop capabilities, live shells and Stop are omitted while completed timeline shells still open details',
    (tester) async {
      final port = _FakeShellPort(canObserve: false, canStop: false);
      final rig = await _mount(tester, shellPort: port);
      final completedTool = _shellTool(
        rig.parent,
        'item_hist',
        shellId: 'sh_hist',
        command: 'echo done',
        shellStatus: ShellStatus.exited,
        exitCode: 0,
      );
      rig.handle.emit(
        SessionLiveView(
          session: rig.parent,
          phase: SessionLivePhase.live,
          state: liveState(
            rig.parent,
            shells: [_shellWork(rig.parent, 'sh_hidden', command: 'sleep 99')],
            items: [completedTool],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Badge is absent because sh_hidden is omitted without shell.observe.
      expect(find.byKey(const ValueKey('subagent-capsule')), findsOneWidget);
      expect(find.byKey(const ValueKey('subagent-count')), findsNothing);
      expect(
        tester
            .widget<CustomPaint>(
              find.byKey(const ValueKey('subagent-capsule-activity-border')),
            )
            .foregroundPainter,
        isNull,
      );

      // Opens directly on Completed tab showing only timeline shell sh_hist.
      await tester.tap(find.byKey(const ValueKey('subagent-capsule')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('shell-row-sh_hidden')), findsNothing);
      expect(find.byKey(const ValueKey('shell-row-sh_hist')), findsOneWidget);
      expect(find.byKey(const ValueKey('shell-stop-sh_hidden')), findsNothing);

      // Tapping completed timeline shell opens showToolDetailsDialog.
      await tester.tap(find.byKey(const ValueKey('shell-row-sh_hist')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('tool-details-item_hist')),
        findsOneWidget,
      );
      expect(port.readCalls, isEmpty);
    },
  );

  testWidgets('unified capsule renders cleanly in RTL at 2x text scale', (
    tester,
  ) async {
    final port = _FakeShellPort();
    final rig = await _mount(
      tester,
      shellPort: port,
      locale: const Locale('ar'),
      scale: 2.0,
      size: const Size(320, 640),
    );
    rig.handle.emit(
      SessionLiveView(
        session: rig.parent,
        phase: SessionLivePhase.live,
        state: liveState(
          rig.parent,
          shells: [
            _shellWork(
              rig.parent,
              'sh_rtl',
              command: 'flutter test --no-pub test/v2/sessions',
            ),
          ],
        ),
      ),
    );
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('subagent-capsule')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('shell-row-sh_rtl')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'settled background shell ToolCall leaves Active when absent from state.shells, canObserve=false omits running timeline shells, unknown ShellWork stays Active, and non-sh_ ShellRun deduplicates',
    (tester) async {
      final port = _FakeShellPort(canObserve: true, canStop: true);
      final rig = await _mount(tester, shellPort: port);

      // Settled background ToolCall whose shellId sh_bg is NOT in state.shells
      // must land in Completed rather than sticking in Active.
      final settledBgTool = _shellTool(
        rig.parent,
        'item_bg',
        shellId: 'sh_bg',
        command: 'tail -f app.log',
        shellStatus: ShellStatus.running,
        background: true,
      );
      // Streaming timeline-only shell without ShellWork stays Active but gets NO Stop button.
      final streamingTimelineOnly = ToolCall(
        meta: ItemMeta(
          id: const ItemId('item_stream_only'),
          generation: 'g1',
          status: const OpenValue.known(ItemStatus.streaming),
          source: SourceProvenance(
            harness: rig.parent.harnessRef,
            version: '2.0.22',
            nativeType: 'tool',
          ),
        ),
        kind: const OpenValue.known(ToolKind.shell),
        rawName: 'shell',
        input: CanonicalValue(const {'command': 'make build'}),
        runFacts: ToolRunFacts(
          shellStatus: const OpenValue.known(ShellStatus.running),
        ),
      );
      // Unrecognized ShellWork status stays in Active with Unknown label (never Done / never Stop).
      final unknownWork = ShellWork(
        id: 'sh_mystery',
        owner: SessionOwner(rig.parent),
        command: 'weird-job',
        status: OpenValue<ShellStatus>.unknown('paused'),
      );
      // Non-sh_ harness-neutral ShellRun deduplicates with ShellWork by ShellRun.shellId.
      final customRun = ShellRun(
        meta: liveMeta(rig.parent, 'item_custom'),
        command: 'custom-cmd',
        shellId: 'custom_shell_99',
        shellStatus: const OpenValue.known(ShellStatus.running),
      );
      final customWork = _shellWork(
        rig.parent,
        'custom_shell_99',
        command: 'custom-cmd',
        status: ShellStatus.running,
      );

      rig.handle.emit(
        SessionLiveView(
          session: rig.parent,
          phase: SessionLivePhase.live,
          state: liveState(
            rig.parent,
            shells: [unknownWork, customWork],
            items: [settledBgTool, streamingTimelineOnly, customRun],
          ),
        ),
      );
      await _settle(tester);

      // Badge counts streamingTimelineOnly + customWork = 2 (NOT settledBgTool, NOT unknownWork).
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('subagent-count'))).data,
        '2',
      );

      await tester.tap(find.byKey(const ValueKey('subagent-capsule')));
      await _settle(tester);
      final l10n = V2Localizations.of(
        tester.element(find.byKey(const ValueKey('subagent-popin'))),
      );
      expect(
        find.byKey(const ValueKey('shell-row-sh_mystery')),
        findsOneWidget,
      );
      expect(find.text(l10n.liveSubagentsUnknown), findsOneWidget);
      expect(find.byKey(const ValueKey('shell-stop-sh_mystery')), findsNothing);
      expect(
        find.byKey(const ValueKey('shell-row-custom_shell_99')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('shell-stop-custom_shell_99')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('shell-row-item_stream_only')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('shell-stop-item_stream_only')),
        findsNothing,
      );
      // Settled background shell sh_bg is NOT in Active!
      expect(find.byKey(const ValueKey('shell-row-sh_bg')), findsNothing);

      // Completed tab has sh_bg and NOT custom_shell_99 (deduplicated without sh_ prefix).
      await tester.tap(find.text(l10n.liveSubagentsCompleted));
      await _settle(tester);
      expect(find.byKey(const ValueKey('shell-row-sh_bg')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('shell-row-custom_shell_99')),
        findsNothing,
      );

      // Now verify sessionShellEntries with canObserveShells=false omits running timeline shells.
      final entriesNoObserve = sessionShellEntries(
        rig.live.state,
        canObserveShells: false,
      );
      expect(entriesNoObserve.any((e) => e.key == 'item_stream_only'), isFalse);
      expect(entriesNoObserve.any((e) => e.key == 'sh_bg'), isFalse);
      expect(entriesNoObserve.any((e) => e.key == 'custom_shell_99'), isFalse);
    },
  );

  testWidgets(
    'output dialog handles stop feedback, post-stop/deleted unavailable state, 404 footer, and 64 KiB rune cap',
    (tester) async {
      final port = _FakeShellPort();
      var stopOutcome = SessionShellStopOutcome.rejected;
      var readCount = 0;
      port.onStop = (_) async => stopOutcome;
      port.onReadOutput = (id, cursor, limit, cancel) async {
        readCount++;
        if (readCount == 1) {
          // Short tokens + emoji (< 64 KiB raw) that expand past 64 KiB after
          // credential redaction, verifying strict <= 64 KiB UTF-8 rune cap.
          final expanded = 'token=a 😀\n' * 4500;
          return ShellOutputPage(
            output: expanded,
            cursor: utf8.encode(expanded).length,
            size: 90000,
            truncated: false,
          );
        }
        return null; // 404 on subsequent refresh / Load more
      };

      final rig = await _mount(tester, shellPort: port);
      void emitShells(List<ShellWork> shells) => rig.handle.emit(
        SessionLiveView(
          session: rig.parent,
          phase: SessionLivePhase.live,
          state: liveState(rig.parent, shells: shells),
        ),
      );
      emitShells([_shellWork(rig.parent, 'sh_dlg', command: 'long-cmd')]);
      await _settle(tester);

      // Open pop-in and trigger rejected stop -> inline feedback in pop-in.
      await tester.tap(find.byKey(const ValueKey('subagent-capsule')));
      await _settle(tester);
      await tester.tap(find.byKey(const ValueKey('shell-stop-sh_dlg')));
      await _settle(tester);
      expect(find.byKey(const ValueKey('shell-stop-feedback')), findsOneWidget);

      // Open dialog for sh_dlg -> output capped strictly <= 64 KiB valid UTF-8.
      await tester.tap(find.byKey(const ValueKey('shell-row-sh_dlg')));
      await _settle(tester);
      final textWidget = tester.widget<Text>(
        find.byKey(const ValueKey('shell-output-text-sh_dlg')),
      );
      expect(
        utf8.encode(textWidget.data!).length,
        lessThanOrEqualTo(64 * 1024),
      );
      expect(
        find.byKey(const ValueKey('shell-output-truncated')),
        findsOneWidget,
      );

      // Stop rejected/uncertain surfaces inline notice inside dialog.
      stopOutcome = SessionShellStopOutcome.uncertain;
      await tester.tap(find.byKey(const ValueKey('shell-output-stop-sh_dlg')));
      await _settle(tester);
      expect(
        find.byKey(const ValueKey('shell-output-stop-notice-sh_dlg')),
        findsOneWidget,
      );

      // Refresh returning 404 (confirmed gone) IMMEDIATELY disables Stop &
      // Refresh and shows unavailable footer while keeping prior output!
      await tester.tap(
        find.byKey(const ValueKey('shell-output-refresh-sh_dlg')),
      );
      await _settle(tester);
      expect(
        find.byKey(const ValueKey('shell-output-text-sh_dlg')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('shell-output-unavailable')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('shell-output-stop-sh_dlg')),
        findsNothing,
      );
      final refreshBtn = tester.widget<IconButton>(
        find.byKey(const ValueKey('shell-output-refresh-sh_dlg')),
      );
      expect(refreshBtn.onPressed, isNull);

      // Re-open on a fresh shell to verify reconnecting/stale phase disables
      // BOTH Stop and Refresh without prematurely marking unavailable.
      await tester.tap(find.byKey(const ValueKey('shell-output-close')));
      await _settle(tester);
      readCount = 0;
      port.onReadOutput = (id, cursor, limit, cancel) async =>
          ShellOutputPage(output: 'ok\n', cursor: 3, size: 3, truncated: false);
      emitShells([_shellWork(rig.parent, 'sh_stale', command: 'watch')]);
      await _settle(tester);
      await tester.tap(find.byKey(const ValueKey('subagent-capsule')));
      await _settle(tester);
      await tester.tap(find.byKey(const ValueKey('shell-row-sh_stale')));
      await _settle(tester);
      expect(
        find.byKey(const ValueKey('shell-output-stop-sh_stale')),
        findsOneWidget,
      );
      rig.handle.emit(
        SessionLiveView(
          session: rig.parent,
          phase: SessionLivePhase.reconnecting,
          state: liveState(
            rig.parent,
            shells: [_shellWork(rig.parent, 'sh_stale', command: 'watch')],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('shell-output-stop-sh_stale')),
        findsNothing,
      );
      expect(
        tester
            .widget<IconButton>(
              find.byKey(const ValueKey('shell-output-refresh-sh_stale')),
            )
            .onPressed,
        isNull,
      );
    },
  );

  testWidgets(
    'capsule handles unobserved shells without inferring Done, admits unknown ShellRun, suppresses confirmed-removed streaming twins, and labels code-less exit as Unknown',
    (tester) async {
      final port = _FakeShellPort();
      final rig = await _mount(tester, shellPort: port);

      // 1) Initial /api/shell failed (shellsObserved: false): settled
      //    background shell ToolCall stays unconfirmed in Active (NOT Done!).
      final bgTool = _shellTool(
        rig.parent,
        'item_unobs',
        shellId: 'sh_unobs',
        command: 'bg-server',
        shellStatus: ShellStatus.running,
        background: true,
      );
      final unknownRun = ShellRun(
        meta: liveMeta(rig.parent, 'item_unk_run'),
        command: 'mystery-shell',
        shellId: 'sh_unk_run',
        shellStatus: OpenValue<ShellStatus>.unknown('paused'),
      );
      final unobsState = liveState(
        rig.parent,
        shellsObserved: false,
        items: [bgTool, unknownRun],
      );
      final unobsEntries = sessionShellEntries(
        unobsState,
        canObserveShells: true,
      );
      expect(
        unobsEntries.firstWhere((e) => e.key == 'sh_unobs').isUnconfirmed,
        isTrue,
      );
      expect(
        unobsEntries.firstWhere((e) => e.key == 'sh_unk_run').isUnconfirmed,
        isTrue,
      );

      // 2) Streaming twin confirmed removed after being observed leaves Active,
      //    and exited ShellWork with no exitCode/exitToken renders Unknown.
      final streamingTwin = ToolCall(
        meta: ItemMeta(
          id: const ItemId('item_stream_rm'),
          generation: 'g1',
          status: const OpenValue.known(ItemStatus.streaming),
          source: SourceProvenance(
            harness: rig.parent.harnessRef,
            version: '2.0.22',
            nativeType: 'tool',
          ),
        ),
        kind: const OpenValue.known(ToolKind.shell),
        rawName: 'shell',
        input: CanonicalValue(const {'command': 'sleep 99'}),
        runFacts: ToolRunFacts(
          shellId: 'sh_rm',
          shellStatus: const OpenValue.known(ShellStatus.running),
        ),
      );
      final codeLessExit = _shellWork(
        rig.parent,
        'sh_nocode',
        command: 'exit-nocode',
        status: ShellStatus.exited,
        exitCode: null,
      );
      // First observe sh_rm live, then remove sh_rm while streamingTwin is still streaming.
      rig.handle.emit(
        SessionLiveView(
          session: rig.parent,
          phase: SessionLivePhase.live,
          state: liveState(
            rig.parent,
            shells: [_shellWork(rig.parent, 'sh_rm'), codeLessExit],
            items: [streamingTwin],
          ),
        ),
      );
      await _settle(tester);
      rig.handle.emit(
        SessionLiveView(
          session: rig.parent,
          phase: SessionLivePhase.live,
          state: liveState(
            rig.parent,
            shells: [codeLessExit],
            items: [streamingTwin],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Badge is absent because sh_rm was confirmed removed and sh_nocode exited.
      expect(find.byKey(const ValueKey('subagent-count')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('subagent-capsule')));
      await tester.pumpAndSettle();
      final l10n = V2Localizations.of(
        tester.element(find.byKey(const ValueKey('subagent-popin'))),
      );
      // Completed tab opens directly and labels sh_nocode Unknown (never Done!).
      expect(find.byKey(const ValueKey('shell-row-sh_nocode')), findsOneWidget);
      expect(find.byKey(const ValueKey('shell-row-sh_rm')), findsOneWidget);
      expect(find.text(l10n.liveToolDone), findsNothing);
      expect(find.text(l10n.liveSubagentsUnknown), findsWidgets);
    },
  );
}
