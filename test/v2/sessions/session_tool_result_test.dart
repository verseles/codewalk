import 'package:codewalk/features/sessions/session_timeline_projection.dart';
import 'package:codewalk/features/sessions/session_timeline_tile.dart';
import 'package:codewalk/shared/l10n/generated/v2_localizations.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

ItemMeta _meta(String id, ItemStatus status) => ItemMeta(
  id: ItemId(id),
  generation: 'test',
  status: OpenValue.known(status),
  source: SourceProvenance(
    harness: const HarnessRef(HostId('h'), HarnessInstanceId('test')),
    version: '2.0.22',
    nativeType: 'test',
  ),
);

ToolCall _tool(
  String id,
  ItemStatus status, {
  Object? input = const {'path': 'lib/main.dart'},
  Object? output,
  OutputRef? outputRef,
  ErrorInfo? error,
}) => ToolCall(
  meta: _meta(id, status),
  kind: const OpenValue.known(ToolKind.read),
  rawName: 'read',
  input: input == null ? null : CanonicalValue(input),
  output: output == null ? null : CanonicalValue(output),
  outputRef: outputRef,
  error: error,
);

ShellRun _shell(
  String id,
  ShellStatus status, {
  int? exit,
  String? token,
  String? output,
  bool truncated = false,
}) => ShellRun(
  meta: _meta(id, switch (status) {
    ShellStatus.running => ItemStatus.streaming,
    ShellStatus.exited when exit == 0 => ItemStatus.completed,
    ShellStatus.killed => ItemStatus.interrupted,
    _ => ItemStatus.failed,
  }),
  command: 'make test',
  exitCode: exit,
  exitToken: token,
  shellStatus: OpenValue.known(status),
  outputText: output,
  output: OutputRef(id: 'sh_$id', truncated: truncated),
);

Future<V2Localizations> _pump(
  WidgetTester tester,
  List<TimelineItem> items, {
  Size size = const Size(390, 844),
  Locale locale = const Locale('en'),
  double scale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: V2Localizations.localizationsDelegates,
      supportedLocales: V2Localizations.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
        child: Scaffold(
          body: ListView(
            children: [
              for (final item in items) SessionTimelineTile(item: item),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return V2Localizations.of(tester.element(find.byType(ListView)));
}

/// Opens the details dialog of the row [id].
Future<void> _open(WidgetTester tester, String id) async {
  final toggle = find.byKey(ValueKey('tool-toggle-$id'));
  await tester.scrollUntilVisible(
    toggle,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(toggle);
  await tester.pumpAndSettle();
  expect(find.byKey(ValueKey('tool-details-$id')), findsOneWidget);
}

Future<void> _close(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('tool-details-close')));
  await tester.pumpAndSettle();
}

ScrollPosition _sectionScroll(WidgetTester tester, String id, int index) =>
    tester
        .state<ScrollableState>(
          find.descendant(
            of: find.byKey(ValueKey('tool-section-$id-$index')),
            matching: find.byType(Scrollable),
          ),
        )
        .position;

void main() {
  testWidgets('a tool row is a compact single line and opens details on tap', (
    tester,
  ) async {
    final l10n = await _pump(tester, [
      _tool(
        'done',
        ItemStatus.completed,
        output: const [
          {'type': 'text', 'text': 'line one\nline two'},
          {'type': 'file', 'mime': 'image/png', 'available': false},
        ],
      ),
    ]);
    // Compact row shows localized kind + target on one line, no Done badge, no Show/Details button.
    expect(find.text('${l10n.toolKindRead} · lib/main.dart'), findsOneWidget);
    expect(find.byKey(const ValueKey('tool-status-done')), findsNothing);
    expect(find.text(l10n.liveToolDone), findsNothing);
    expect(find.text(l10n.chatMessageShow), findsNothing);
    expect(find.text(l10n.chatMessageDetails), findsNothing);
    expect(find.textContaining('line one'), findsNothing);
    expect(
      tester.getSize(find.byKey(const ValueKey('tool-toggle-done'))).height,
      greaterThanOrEqualTo(48),
    );
    await _open(tester, 'done');
    expect(find.text(l10n.liveToolDone), findsOneWidget);
    expect(find.text(l10n.chatMessageToolInput), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('tool-section-done-0')),
        matching: find.textContaining('lib/main.dart'),
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('line one\nline two\n[image/png]'),
      findsOneWidget,
    );
    await _close(tester);
    expect(find.textContaining('line one'), findsNothing);
    // Escape closes it too.
    await _open(tester, 'done');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('tool-details-done')), findsNothing);
  });

  testWidgets(
    'a wide screen keeps the same single-line row without a Details button',
    (tester) async {
      final l10n = await _pump(tester, [
        _tool('wide', ItemStatus.completed),
      ], size: const Size(1280, 800));
      expect(find.byKey(const ValueKey('tool-toggle-wide')), findsOneWidget);
      expect(find.text('${l10n.toolKindRead} · lib/main.dart'), findsOneWidget);
      expect(find.text(l10n.chatMessageDetails), findsNothing);
      expect(find.text(l10n.chatMessageShow), findsNothing);
    },
  );

  testWidgets(
    'queued, running, failed, interrupted, and background shell tools show status badges',
    (tester) async {
      final l10n = await _pump(tester, [
        _tool('queued', ItemStatus.pending, input: null),
        _tool('run', ItemStatus.streaming, input: null),
        ToolCall(
          meta: _meta('bg', ItemStatus.completed),
          kind: const OpenValue.known(ToolKind.shell),
          rawName: 'shell',
          input: CanonicalValue(const {'command': 'npm run dev'}),
          runFacts: ToolRunFacts(
            shellId: 'sh_bg1',
            background: true,
            shellStatus: const OpenValue.known(ShellStatus.running),
          ),
        ),
        ToolCall(
          meta: _meta('shok', ItemStatus.completed),
          kind: const OpenValue.known(ToolKind.shell),
          rawName: 'shell',
          input: CanonicalValue(const {'command': 'echo hi'}),
          runFacts: ToolRunFacts(
            exitCode: 0,
            shellStatus: const OpenValue.known(ShellStatus.exited),
          ),
        ),
        ToolCall(
          meta: _meta('shbad', ItemStatus.completed),
          kind: const OpenValue.known(ToolKind.shell),
          rawName: 'shell',
          input: CanonicalValue(const {'command': 'false'}),
          runFacts: ToolRunFacts(
            exitCode: 1,
            shellStatus: const OpenValue.known(ShellStatus.exited),
          ),
        ),
        _tool(
          'fail',
          ItemStatus.failed,
          error: ErrorInfo(
            kind: const OpenValue.known(ErrorKind.toolFailure),
            rawType: 'unknown',
            rawMessage: 'file not found',
          ),
        ),
        _tool(
          'stop',
          ItemStatus.interrupted,
          input: null,
          error: ErrorInfo(
            kind: const OpenValue.known(ErrorKind.toolFailure),
            rawType: 'aborted',
            rawMessage: '',
          ),
        ),
      ]);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('tool-status-queued')))
            .data,
        l10n.composerQueued,
      );
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('tool-status-run'))).data,
        l10n.toolRunning,
      );
      // Background shell tool stays Running even if tool part completed.
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('tool-status-bg'))).data,
        l10n.toolRunning,
      );
      // Clean shell tool exit 0 shows no status badge.
      expect(find.byKey(const ValueKey('tool-status-shok')), findsNothing);
      // Nonzero shell exit shows failure badge.
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('tool-status-shbad')))
            .data,
        '${l10n.statusFailed} · ${l10n.liveShellExitCode} 1',
      );
      // A running tool with nothing to show has no details control.
      expect(find.byKey(const ValueKey('tool-toggle-run')), findsNothing);
      expect(find.text(l10n.statusFailed), findsOneWidget);
      expect(find.text(l10n.liveToolInterrupted), findsOneWidget);
      await _open(tester, 'fail');
      expect(find.text('file not found'), findsOneWidget);
      await _close(tester);
      await _open(tester, 'stop');
      expect(find.text('aborted'), findsOneWidget);
    },
  );

  testWidgets(
    'a shell row shows its command, non-clean outcomes, and output on tap',
    (tester) async {
      final l10n = await _pump(tester, [
        _shell('ok', ShellStatus.exited, exit: 0, output: 'all passed'),
        _shell('bad', ShellStatus.exited, exit: 2, output: 'error: x'),
        _shell(
          'slow',
          ShellStatus.timeout,
          token: 'NaN',
          output: 'partial',
          truncated: true,
        ),
        _shell('live', ShellStatus.running),
      ]);
      expect(find.text('${l10n.toolKindShell} · make test'), findsNWidgets(4));
      expect(find.byKey(const ValueKey('tool-status-ok')), findsNothing);
      expect(
        find.text('${l10n.statusFailed} · ${l10n.liveShellExitCode} 2'),
        findsOneWidget,
      );
      expect(
        find.text('${l10n.liveShellTimedOut} · ${l10n.liveShellExitCode} NaN'),
        findsOneWidget,
      );
      expect(find.text(l10n.toolRunning), findsOneWidget);
      expect(find.textContaining('all passed'), findsNothing);
      await _open(tester, 'ok');
      expect(find.text(l10n.liveToolDone), findsOneWidget);
      expect(find.text('all passed'), findsOneWidget);
      await _close(tester);
      await _open(tester, 'slow');
      expect(find.text(l10n.liveShellOutputPartial), findsOneWidget);
    },
  );

  testWidgets('an exit without a code is not called a failure', (tester) async {
    final l10n = await _pump(tester, [
      _shell('none', ShellStatus.exited),
      _shell('nan', ShellStatus.exited, token: 'NaN'),
    ]);
    expect(find.byKey(const ValueKey('tool-status-none')), findsNothing);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('tool-status-nan'))).data,
      '${l10n.liveShellExitCode} NaN',
    );
    expect(find.textContaining(l10n.statusFailed), findsNothing);
  });

  testWidgets('the dialog follows its item and keeps the reader in place', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    String lines(int count) =>
        [for (var i = 0; i < count; i++) 'row $i'].join('\n');
    final short = _shell('grow', ShellStatus.running, output: lines(2));
    final long = _shell('read', ShellStatus.running, output: lines(30));
    final live = ValueNotifier<List<TimelineItem>>([short, long]);
    addTearDown(live.dispose);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: V2Localizations.localizationsDelegates,
        supportedLocales: V2Localizations.supportedLocales,
        home: Scaffold(
          body: SessionTimelineScope(
            items: live,
            onReaderToggle: () {},
            child: ListView(
              children: [
                SessionTimelineTile(item: short),
                SessionTimelineTile(item: long),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // A value that fits follows its growth: the reader is at its end.
    await _open(tester, 'grow');
    live.value = [
      _shell('grow', ShellStatus.exited, exit: 0, output: lines(30)),
      long,
    ];
    await tester.pumpAndSettle();
    expect(find.textContaining('row 29'), findsOneWidget);
    final grown = _sectionScroll(tester, 'grow', 1);
    expect(grown.maxScrollExtent, greaterThan(0));
    expect(grown.pixels, grown.maxScrollExtent);
    await _close(tester);
    // A value that opens longer than its area opens at its top, and stays
    // there while it grows.
    await _open(tester, 'read');
    final top = _sectionScroll(tester, 'read', 1);
    expect(top.pixels, 0);
    live.value = [
      short,
      _shell('read', ShellStatus.running, output: lines(35)),
    ];
    await tester.pumpAndSettle();
    expect(find.textContaining('row 34'), findsOneWidget);
    expect(_sectionScroll(tester, 'read', 1).pixels, 0);
  });

  testWidgets('a long value shows its first part and the rest on demand', (
    tester,
  ) async {
    final lines = [for (var i = 0; i < 100; i++) 'row $i'].join('\n');
    final l10n = await _pump(tester, [
      _shell('long', ShellStatus.exited, exit: 0, output: lines),
    ]);
    await _open(tester, 'long');
    expect(find.textContaining('row 39'), findsOneWidget);
    expect(find.textContaining('row 40'), findsNothing);
    expect(find.text(l10n.chatMessageToolOutputTruncated), findsOneWidget);
    final more = find.text(l10n.chatMessageShowMore);
    await tester.ensureVisible(more);
    await tester.tap(more);
    await tester.pumpAndSettle();
    expect(find.textContaining('row 99'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a credential never reaches the screen', (tester) async {
    await _pump(tester, [
      _tool(
        'secret',
        ItemStatus.completed,
        input: const {'command': 'deploy --token abcdefgh12345678'},
        output: const [
          {'type': 'text', 'text': 'password=hunter2xyz'},
        ],
      ),
      _shell(
        'secret2',
        ShellStatus.exited,
        exit: 0,
        output: 'Authorization: Bearer abcdefgh12345678',
      ),
    ]);
    for (final id in ['secret', 'secret2']) {
      await _open(tester, id);
      expect(find.textContaining('abcdefgh12345678'), findsNothing);
      expect(find.textContaining('hunter2xyz'), findsNothing);
      expect(find.textContaining('[redacted]'), findsWidgets);
      await _close(tester);
    }
  });

  for (final (name, size, locale, scale) in const [
    ('compact', Size(390, 844), Locale('en'), 1.0),
    ('wide', Size(1280, 800), Locale('en'), 1.0),
    ('rtl', Size(390, 844), Locale('ar'), 1.0),
    ('2x', Size(390, 844), Locale('en'), 2.0),
  ]) {
    testWidgets('the rows lay out without overflow, $name', (tester) async {
      await _pump(
        tester,
        [
          _tool(
            'a',
            ItemStatus.failed,
            output: const [
              {'type': 'text', 'text': 'x'},
            ],
            error: ErrorInfo(
              kind: const OpenValue.known(ErrorKind.toolFailure),
              rawType: 'unknown',
              rawMessage: 'a long failure message ' * 8,
            ),
          ),
          _shell('b', ShellStatus.timeout, token: 'Infinity', output: 'y'),
        ],
        size: size,
        locale: locale,
        scale: scale,
      );
      await _open(tester, 'a');
      expect(tester.takeException(), isNull);
      await _close(tester);
      await _open(tester, 'b');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'compact tool toggle preserves SemanticsAction.tap, failed/interrupted status overrides running runFacts, and 320px 2x with elapsed chip fits',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        final runningFacts = ToolRunFacts(
          shellId: 'sh_stale',
          background: true,
          shellStatus: const OpenValue.known(ShellStatus.running),
        );
        final failedWithRunningFacts = ToolCall(
          meta: ItemMeta(
            id: const ItemId('fail-bg'),
            generation: 'test',
            status: const OpenValue.known(ItemStatus.failed),
            source: SourceProvenance(
              harness: const HarnessRef(HostId('h'), HarnessInstanceId('test')),
              version: '2.0.22',
              nativeType: 'test',
            ),
            message: MessageContext(
              message: MessageRef('m1'),
              created: DateTime.utc(2026, 11, 19, 1, 0, 0),
              completed: DateTime.utc(2026, 11, 19, 1, 0, 5),
            ),
          ),
          kind: const OpenValue.known(ToolKind.shell),
          rawName: 'shell',
          input: CanonicalValue(const {'command': 'make very-long-command'}),
          runFacts: runningFacts,
        );
        final interruptedWithRunningFacts = ToolCall(
          meta: _meta('stop-bg', ItemStatus.interrupted),
          kind: const OpenValue.known(ToolKind.shell),
          rawName: 'shell',
          input: CanonicalValue(const {'command': 'sleep 99'}),
          runFacts: runningFacts,
        );

        final l10n = await _pump(
          tester,
          [failedWithRunningFacts, interruptedWithRunningFacts],
          size: const Size(320, 640),
          scale: 2.0,
        );
        expect(tester.takeException(), isNull);
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('tool-status-fail-bg')))
              .data,
          l10n.statusFailed,
        );
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('tool-status-stop-bg')))
              .data,
          l10n.liveToolInterrupted,
        );
        final node = tester.getSemantics(
          find.byKey(const ValueKey('tool-toggle-fail-bg')),
        );
        expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'tool details dialog shows localized shortened notices for client-cut output and error',
    (tester) async {
      final l10n = await _pump(tester, [
        _tool(
          'cut',
          ItemStatus.failed,
          output: const [
            {'type': 'text', 'text': 'bounded output prefix'},
          ],
          outputRef: OutputRef(id: 'call_cut', truncated: true),
          error: ErrorInfo(
            kind: const OpenValue.known(ErrorKind.toolFailure),
            rawType: 'tool.execution',
            rawMessage: 'bounded error prefix',
            details: CanonicalValue(const {'messageTruncated': true}),
          ),
        ),
      ]);
      await _open(tester, 'cut');
      expect(find.text(l10n.liveToolValueShortened), findsOneWidget);
      expect(find.text(l10n.liveErrorShortened), findsOneWidget);
      await _close(tester);
    },
  );
}
