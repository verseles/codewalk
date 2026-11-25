import 'package:codewalk/features/sessions/session_compaction_note.dart';
import 'package:codewalk/features/sessions/session_timeline_projection.dart';
import 'package:codewalk/features/sessions/session_timeline_tile.dart';
import 'package:codewalk/shared/l10n/generated/v2_localizations.dart';
import 'package:codewalk/shared/rendering/canonical_message_body.dart';
import 'package:codewalk/shared/theme/chat_appearance.dart';
import 'package:codewalk/shared/widgets/app_indeterminate_progress.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _harness = HarnessRef(HostId('h'), HarnessInstanceId('test'));

Notice _compaction(
  String id, {
  required ItemStatus status,
  String text = '',
  CompactionInfo? compaction,
}) => Notice(
  meta: ItemMeta(
    id: ItemId('cmp/$id'),
    generation: 'g1',
    status: OpenValue.known(status),
    source: SourceProvenance(
      harness: _harness,
      version: '2.0.22',
      nativeType: 'session.compaction',
    ),
  ),
  kind: const OpenValue.known(NoticeKind.compaction),
  text: text,
  compaction: compaction,
);

Widget _host(
  Widget child, {
  double width = 390,
  Locale locale = const Locale('en'),
  TextScaler textScaler = TextScaler.noScaling,
  VoidCallback? onReaderToggle,
}) => MaterialApp(
  locale: locale,
  localizationsDelegates: V2Localizations.localizationsDelegates,
  supportedLocales: V2Localizations.supportedLocales,
  home: MediaQuery(
    data: MediaQueryData(size: Size(width, 800), textScaler: textScaler),
    child: Scaffold(
      body: PageStorage(
        bucket: PageStorageBucket(),
        child: SessionTimelineScope(
          items: ValueNotifier<List<TimelineItem>>(const []),
          onReaderToggle: onReaderToggle ?? () {},
          child: SizedBox(width: width, child: child),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets(
    'running compaction shows centered divider with spinner and stable height',
    (tester) async {
      await tester.pumpWidget(
        _host(
          SessionTimelineTile(
            item: _compaction('run', status: ItemStatus.streaming),
          ),
        ),
      );
      expect(find.byType(SessionCompactionNote), findsOneWidget);
      expect(find.byType(Card), findsNothing);
      expect(find.text('Details'), findsNothing);
      expect(find.text('Compacting context…'), findsOneWidget);
      expect(find.byType(AppIndeterminateRing), findsOneWidget);
      expect(
        find.byKey(const ValueKey('timeline-compaction-toggle-cmp/run')),
        findsNothing,
      );
      final runningHeight = tester
          .getSize(find.byKey(const ValueKey('timeline-compaction-cmp/run')))
          .height;

      await tester.pumpWidget(
        _host(
          SessionTimelineTile(
            item: _compaction(
              'run',
              status: ItemStatus.completed,
              text: 'Kept **decisions** and [spec](https://example.test).',
            ),
          ),
        ),
      );
      final completedHeight = tester
          .getSize(find.byKey(const ValueKey('timeline-compaction-cmp/run')))
          .height;
      expect(completedHeight, closeTo(runningHeight, 0.5));
      expect(find.text('Context compacted'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('timeline-compaction-body-cmp/run')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'completed compaction expands collapsed summary, trigger, and token usage on tap',
    (tester) async {
      var toggles = 0;
      String? tappedHref;
      final item = _compaction(
        'done',
        status: ItemStatus.completed,
        text: 'Summary kept.\n\n[docs](https://example.test/docs)',
        compaction: CompactionInfo(
          trigger: const OpenValue.known(CompactionTrigger.requested),
          usage: TokenBreakdown(
            input: 12000,
            cacheRead: 400,
            cacheWrite: 0,
            output: 1500,
            reasoning: 300,
          ),
        ),
      );
      await tester.pumpWidget(
        _host(
          SessionTimelineTile(
            item: item,
            onTapLink: (_, href, _) => tappedHref = href,
          ),
          onReaderToggle: () => toggles++,
        ),
      );

      final toggle = find.byKey(
        const ValueKey('timeline-compaction-toggle-cmp/done'),
      );
      expect(toggle, findsOneWidget);
      expect(tester.getSize(toggle).height, greaterThanOrEqualTo(48));
      // Pill is centered and both hairlines span edge-to-edge.
      expect(tester.getCenter(toggle).dx, closeTo(195, 1.0));
      final dividers = find.descendant(
        of: find.byType(SessionCompactionNote),
        matching: find.byType(Divider),
      );
      expect(dividers, findsNWidgets(2));
      expect(tester.getTopLeft(dividers.first).dx, closeTo(0, 0.5));
      expect(tester.getTopRight(dividers.last).dx, closeTo(390, 0.5));
      expect(find.byType(CanonicalMessageBody), findsNothing);

      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(toggles, 1);
      expect(
        find.byKey(const ValueKey('timeline-compaction-body-cmp/done')),
        findsOneWidget,
      );
      expect(find.text('Manual · 12.4k in · 1.8k out'), findsOneWidget);
      expect(find.byType(CanonicalMessageBody), findsOneWidget);

      await tester.tap(find.text('docs', findRichText: true));
      expect(tappedHref, 'https://example.test/docs');

      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(toggles, 2);
      expect(find.byType(CanonicalMessageBody), findsNothing);
    },
  );

  testWidgets(
    'empty completed compaction renders static divider with no card',
    (tester) async {
      await tester.pumpWidget(
        _host(
          SessionTimelineTile(
            item: _compaction(
              'empty',
              status: ItemStatus.completed,
              text: '   ',
            ),
          ),
        ),
      );
      expect(find.text('Context compacted'), findsOneWidget);
      expect(find.byType(Card), findsNothing);
      expect(
        find.byKey(const ValueKey('timeline-compaction-toggle-cmp/empty')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'failed compaction shows error divider and expands plain error text',
    (tester) async {
      await tester.pumpWidget(
        _host(
          SessionTimelineTile(
            item: _compaction(
              'fail',
              status: ItemStatus.failed,
              text: 'Context window exceeded for [redacted].',
              compaction: const CompactionInfo(
                trigger: OpenValue.known(CompactionTrigger.automatic),
              ),
            ),
          ),
        ),
      );
      expect(find.byType(Card), findsNothing);
      expect(find.text('Details'), findsNothing);
      expect(find.text('Context compaction failed'), findsOneWidget);

      final toggle = find.byKey(
        const ValueKey('timeline-compaction-toggle-cmp/fail'),
      );
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(find.text('Automatic'), findsOneWidget);
      expect(
        find.text('Context window exceeded for [redacted].'),
        findsOneWidget,
      );
      expect(find.byType(CanonicalMessageBody), findsNothing);
    },
  );

  testWidgets(
    'interrupted compaction, RTL, and 200% text scale render without overflow',
    (tester) async {
      await tester.pumpWidget(
        _host(
          SingleChildScrollView(
            child: Column(
              children: [
                SessionTimelineTile(
                  item: _compaction(
                    'int',
                    status: ItemStatus.interrupted,
                    text: 'Stopped early',
                  ),
                ),
                SessionTimelineTile(
                  item: _compaction(
                    'hl',
                    status: ItemStatus.completed,
                    text: 'Highlighted summary',
                  ),
                  highlighted: true,
                ),
              ],
            ),
          ),
          width: 320,
          locale: const Locale('ar'),
          textScaler: const TextScaler.linear(2.0),
        ),
      );
      expect(
        find.byKey(const ValueKey('timeline-compaction-body-cmp/hl')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  test('block render mode publishes streaming compaction immediately', () {
    final running = _compaction('blk', status: ItemStatus.streaming);
    final rows = SessionTimelinePresentation().project(
      [running],
      settled: false,
      renderMode: ChatRenderMode.block,
    );
    expect(rows.whereType<SessionItemRow>().map((r) => r.item), [running]);
  });

  testWidgets(
    'highlighted overrides stored collapsed state and pt locale formats decimals',
    (tester) async {
      final bucket = PageStorageBucket();
      final item = _compaction(
        'pt',
        status: ItemStatus.completed,
        text: 'Resumo preservado',
        compaction: CompactionInfo(
          trigger: const OpenValue.known(CompactionTrigger.automatic),
          usage: TokenBreakdown(input: 12400, output: 1800),
        ),
      );
      Widget build({required bool highlighted}) => MaterialApp(
        locale: const Locale('pt'),
        localizationsDelegates: V2Localizations.localizationsDelegates,
        supportedLocales: V2Localizations.supportedLocales,
        home: Scaffold(
          body: PageStorage(
            bucket: bucket,
            child: SessionTimelineTile(item: item, highlighted: highlighted),
          ),
        ),
      );
      // Expand then collapse so PageStorage stores false.
      await tester.pumpWidget(build(highlighted: false));
      final toggle = find.byKey(
        const ValueKey('timeline-compaction-toggle-cmp/pt'),
      );
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(
        find.text('Automática · 12,4k entrada · 1,8k saída'),
        findsOneWidget,
      );
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('timeline-compaction-body-cmp/pt')),
        findsNothing,
      );

      // Remount with highlighted: true -> must auto-expand despite stored false.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(build(highlighted: true));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('timeline-compaction-body-cmp/pt')),
        findsOneWidget,
      );
    },
  );
}
