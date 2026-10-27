@TestOn('vm')
library;

import 'package:codewalk/features/sessions/session_live_scroll.dart';
import 'package:codewalk/features/sessions/session_live_timeline.dart';
import 'package:codewalk/shared/l10n/generated/v2_localizations.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ItemMeta _meta(
  String id, {
  String? message,
  ItemStatus status = ItemStatus.completed,
}) => ItemMeta(
  id: ItemId('golden/$id'),
  generation: 'golden',
  status: OpenValue.known(status),
  source: SourceProvenance(
    harness: const HarnessRef(HostId('h'), HarnessInstanceId('test')),
    version: '2.0.22',
    nativeType: 'golden',
  ),
  message: message == null
      ? null
      : MessageContext(message: MessageRef(message)),
);

/// A finished turn, whose work collapses behind its answer, and a turn in
/// flight: a long reasoning and a run of calls still running.
List<TimelineItem> _work() {
  ToolCall tool(String id, String message, String name, ItemStatus status) =>
      ToolCall(
        meta: _meta(id, message: message, status: status),
        kind: const OpenValue.known(ToolKind.read),
        rawName: name,
      );
  return [
    UserInput(
      meta: _meta('u1'),
      text: 'Fix the build',
      delivery: const OpenValue.known(DeliveryState.delivered),
    ),
    Reasoning(
      meta: _meta('r1', message: 'm1'),
      text: 'The failure is in the parser.',
      complete: true,
    ),
    tool('t1', 'm1', 'read', ItemStatus.completed),
    tool('t2', 'm1', 'grep', ItemStatus.completed),
    ShellRun(
      meta: _meta('s1', message: 'm2'),
      command: 'make test',
      exitCode: 0,
      shellStatus: const OpenValue.known(ShellStatus.exited),
    ),
    AssistantText(
      meta: _meta('a1', message: 'm3'),
      text: 'The build is fixed: the parser accepts empty input again.',
      complete: true,
    ),
    UserInput(
      meta: _meta('u2'),
      text: 'Now add tests',
      delivery: const OpenValue.known(DeliveryState.delivered),
    ),
    Reasoning(
      meta: _meta('r2', message: 'm4', status: ItemStatus.streaming),
      text: [
        for (var i = 1; i <= 8; i++) 'Step $i: look at the parser cases.',
      ].join('\n\n'),
      complete: false,
    ),
    tool('t3', 'm4', 'read', ItemStatus.completed),
    tool('t4', 'm4', 'edit', ItemStatus.streaming),
    tool('t5', 'm4', 'bash', ItemStatus.pending),
  ];
}

/// A composed timeline: prompts, answers of different lengths, a notice and
/// an observed outcome, in chronological order.
List<TimelineItem> _rows(int from, int to) => [
  for (var i = from; i < to; i++)
    switch (i % 4) {
      0 => UserInput(
        meta: _meta('u$i'),
        text: 'Question $i',
        delivery: const OpenValue.known(DeliveryState.delivered),
      ),
      1 => AssistantText(
        meta: _meta('a$i'),
        text: 'Answer $i${' with more words' * (i % 3)}',
        complete: true,
      ),
      2 => Notice(
        meta: _meta('n$i'),
        kind: const OpenValue.known(NoticeKind.system),
        text: 'Notice $i',
      ),
      _ => TurnOutcome(
        meta: _meta('o$i'),
        kind: const OpenValue.known(OutcomeKind.succeeded),
      ),
    },
];

Future<SessionLiveScroll> _pump(
  WidgetTester tester, {
  required Size size,
  required Locale locale,
  required Brightness brightness,
  required List<TimelineItem> items,
  WidgetBuilder? top,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final scroll = SessionLiveScroll();
  addTearDown(scroll.dispose);
  Widget app(List<TimelineItem> items, WidgetBuilder? top) => MaterialApp(
    locale: locale,
    localizationsDelegates: V2Localizations.localizationsDelegates,
    supportedLocales: V2Localizations.supportedLocales,
    theme: ThemeData(
      colorSchemeSeed: Colors.teal,
      brightness: brightness,
      useMaterial3: true,
    ),
    home: Scaffold(
      body: RepaintBoundary(
        key: const ValueKey('live_golden'),
        child: SessionLiveTimeline(
          items: items,
          scroll: scroll,
          settled: false,
          headerBuilder: (context) =>
              const Text('Session header', key: ValueKey('golden-header')),
          topBuilder: top,
        ),
      ),
    ),
  );
  // The timeline first shows the newest rows, then older ones page in above.
  await tester.pumpWidget(
    app(items.length > 12 ? items.sublist(items.length - 12) : items, null),
  );
  await tester.pumpAndSettle();
  await tester.pumpWidget(app(items, top));
  await tester.pumpAndSettle();
  return scroll;
}

/// Scrolls to the top in steps, as a reader does, so the estimated extent of
/// the rows above settles.
Future<void> _toTop(WidgetTester tester, ScrollController controller) async {
  for (var step = 0; step < 100; step++) {
    final position = controller.position;
    if (position.pixels <= position.minScrollExtent + 0.5) break;
    final next = position.pixels - 600;
    controller.jumpTo(
      next < position.minScrollExtent ? position.minScrollExtent : next,
    );
    await tester.pumpAndSettle();
  }
}

Widget _limit(BuildContext context) {
  final l10n = V2Localizations.of(context);
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(l10n.historyLimit),
      TextButton(onPressed: () {}, child: Text(l10n.historyOpen)),
    ],
  );
}

void main() {
  final cases = [
    (
      'mobile_light',
      const Size(390, 844),
      const Locale('en'),
      Brightness.light,
    ),
    ('mobile_dark', const Size(390, 844), const Locale('en'), Brightness.dark),
    (
      'desktop_light',
      const Size(1280, 800),
      const Locale('en'),
      Brightness.light,
    ),
    (
      'mobile_ar_rtl',
      const Size(390, 844),
      const Locale('ar'),
      Brightness.light,
    ),
  ];
  for (final (name, size, locale, brightness) in cases) {
    testWidgets('the top of a full window, $name', (tester) async {
      final scroll = await _pump(
        tester,
        size: size,
        locale: locale,
        brightness: brightness,
        items: _rows(0, 40),
        top: _limit,
      );
      await _toTop(tester, scroll.controller);
      await expectLater(
        find.byKey(const ValueKey('live_golden')),
        matchesGoldenFile('goldens/live_top_$name.png'),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    });
  }

  for (final (name, size, locale, brightness) in cases) {
    testWidgets('work groups and runs, $name', (tester) async {
      await _pump(
        tester,
        size: size,
        locale: locale,
        brightness: brightness,
        items: _work(),
      );
      await expectLater(
        find.byKey(const ValueKey('live_golden')),
        matchesGoldenFile('goldens/live_work_$name.png'),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('work groups and runs opened, mobile_light', (tester) async {
    await _pump(
      tester,
      // Tall enough to show every opened row at once.
      size: const Size(390, 1800),
      locale: const Locale('en'),
      brightness: Brightness.light,
      items: _work(),
    );
    for (final key in [
      'work-group-toggle-work-golden/r1',
      'tool-run-toggle-tools-golden/t3',
      'reasoning-toggle',
    ]) {
      final toggle = find.byKey(ValueKey(key));
      await tester.scrollUntilVisible(
        toggle,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(toggle);
      await tester.pumpAndSettle();
    }
    await expectLater(
      find.byKey(const ValueKey('live_golden')),
      matchesGoldenFile('goldens/live_work_open_mobile_light.png'),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets('the newest rows, mobile_light', (tester) async {
    await _pump(
      tester,
      size: const Size(390, 844),
      locale: const Locale('en'),
      brightness: Brightness.light,
      items: _rows(0, 40),
    );
    await expectLater(
      find.byKey(const ValueKey('live_golden')),
      matchesGoldenFile('goldens/live_tail_mobile_light.png'),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
}
