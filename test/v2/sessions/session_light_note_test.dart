import 'package:codewalk/features/sessions/session_report_group.dart';
import 'package:codewalk/features/sessions/session_timeline_projection.dart';
import 'package:codewalk/features/sessions/session_timeline_tile.dart';
import 'package:codewalk/shared/l10n/generated/v2_localizations.dart';
import 'package:codewalk/shared/rendering/canonical_message_body.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// #491: reminders and other notes are light lines, not cards.

ItemMeta _meta(
  String id, {
  ItemStatus status = ItemStatus.completed,
  MessageContext? message,
}) => ItemMeta(
  id: ItemId('test/$id'),
  message: message,
  generation: 'test',
  status: OpenValue.known(status),
  source: SourceProvenance(
    harness: const HarnessRef(HostId('h'), HarnessInstanceId('test')),
    version: '2.0.22',
    nativeType: 'test',
  ),
);

Notice _notice(
  String id,
  NoticeKind kind,
  String text, {
  ItemStatus status = ItemStatus.completed,
}) => Notice(
  meta: _meta(id, status: status),
  kind: OpenValue.known(kind),
  text: text,
);

Future<void> _pump(WidgetTester tester, List<TimelineItem> items) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: V2Localizations.localizationsDelegates,
      supportedLocales: V2Localizations.supportedLocales,
      home: Scaffold(
        body: SizedBox(
          width: 320,
          child: Column(
            children: [
              for (final item in items) SessionTimelineTile(item: item),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('running calls share a line and flag a failure on update', (
    tester,
  ) async {
    final anchors = <ItemId>{};
    Future<void> pump(ItemStatus lastStatus) async {
      final calls = [
        for (var i = 0; i < 4; i++)
          SessionItemRow(
            ToolCall(
              meta: _meta(
                'c$i',
                status: i == 3 ? lastStatus : ItemStatus.streaming,
              ),
              kind: const OpenValue.known(ToolKind.subagent),
              rawName: 'subagent',
            ),
            messageHeader: false,
          ),
      ];
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: V2Localizations.localizationsDelegates,
          supportedLocales: V2Localizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: SessionSubagentCalls(
                row: SessionSubagentCallsRow(calls),
                expandedAnchors: anchors,
              ),
            ),
          ),
        ),
      );
    }

    await pump(ItemStatus.streaming);
    expect(find.text('Sub-agents · 4 running'), findsOneWidget);
    expect(find.byType(SessionTimelineTile), findsNothing);
    await pump(ItemStatus.failed);
    final summary = find.text('Failed: 1 · Sub-agents · 4 calls · 3 running');
    expect(summary, findsOneWidget);
    await tester.tap(summary);
    await tester.pump();
    expect(find.byType(SessionTimelineTile), findsNWidgets(4));
    await tester.tap(summary);
    await tester.pump();
    expect(find.byType(SessionTimelineTile), findsNothing);
  });
  testWidgets(
    'collapsed calls expose interruptions, message info and large status text',
    (tester) async {
      final anchors = <ItemId>{};
      final calls = [
        for (final status in [
          ItemStatus.streaming,
          ItemStatus.pending,
          ItemStatus.interrupted,
        ])
          SessionItemRow(
            ToolCall(
              meta: _meta(
                status.name,
                status: status,
                message: status == ItemStatus.pending
                    ? MessageContext(message: MessageRef('m2'))
                    : null,
              ),
              kind: const OpenValue.known(ToolKind.subagent),
              rawName: 'subagent',
            ),
            messageHeader: status == ItemStatus.pending,
          ),
      ];
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: V2Localizations.localizationsDelegates,
          supportedLocales: V2Localizations.supportedLocales,
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: SizedBox(
                width: 300,
                child: SessionSubagentCalls(
                  row: SessionSubagentCallsRow(calls),
                  expandedAnchors: anchors,
                ),
              ),
            ),
          ),
        ),
      );
      final title = find.textContaining('Interrupted (1)');
      expect(tester.widget<Text>(title).maxLines, isNull);
      final toggle = find.ancestor(of: title, matching: find.byType(InkWell));
      expect(tester.getSize(toggle).height, greaterThanOrEqualTo(48));
      expect(tester.getSize(title).height, greaterThan(48));
      await tester.tap(find.byKey(const ValueKey('message-elapsed-m2')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('message-info-m2')), findsOneWidget);
      expect(find.byType(SessionTimelineTile), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'disclosure survives row disposal and older calls joining the group',
    (tester) async {
      final anchors = <ItemId>{};
      Future<void> pump(List<String> ids) async {
        final row = SessionSubagentCallsRow([
          for (final id in ids)
            SessionItemRow(
              ToolCall(
                meta: _meta(id),
                kind: const OpenValue.known(ToolKind.subagent),
                rawName: 'subagent',
              ),
              messageHeader: false,
            ),
        ]);
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: V2Localizations.localizationsDelegates,
            supportedLocales: V2Localizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: SessionSubagentCalls(
                  key: row.key,
                  row: row,
                  expandedAnchors: anchors,
                ),
              ),
            ),
          ),
        );
      }

      await pump(['b', 'c']);
      await tester.tap(find.text('Sub-agents · 2 calls'));
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      await pump(['a', 'b', 'c']);
      expect(find.byType(SessionTimelineTile), findsNWidgets(3));
      await tester.tap(find.text('Sub-agents · 3 calls'));
      await tester.pump();
      await pump(['b', 'c']);
      expect(find.byType(SessionTimelineTile), findsNothing);
    },
  );

  testWidgets(
    'compact replies disclose failures and open one report in place',
    (tester) async {
      const child = SessionRef(HostId('h'), HarnessInstanceId('test'), 'child');
      SessionRef? opened;
      Notice reply(String id, {bool failed = false}) => Notice(
        meta: _meta(id),
        kind: const OpenValue.known(NoticeKind.continuation),
        text: '**Result**',
        report: SubagentReport(
          agent: id,
          outcome: failed ? OutcomeKind.failed : OutcomeKind.succeeded,
        ),
        relatedSession: failed ? null : child,
      );
      Future<void> pump(List<Notice> reports) async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: V2Localizations.localizationsDelegates,
            supportedLocales: V2Localizations.supportedLocales,
            home: Scaffold(
              body: SizedBox(
                width: 320,
                child: SessionReportGroup(
                  reports: reports,
                  onOpenChild: (ref) => opened = ref,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      final first = reply('MiniMax');
      await pump([first]);
      expect(find.text('MiniMax replied'), findsOneWidget);
      expect(find.byType(CanonicalMessageBody), findsNothing);
      await pump([first, reply('Gemini', failed: true)]);
      final summary = find.text('Failed: 1 · 2 subagent replies');
      expect(summary, findsOneWidget);
      expect(tester.widget<Text>(summary).maxLines, 1);
      expect(find.text('MiniMax replied'), findsNothing);
      await tester.tap(summary);
      await tester.pump();
      expect(find.text('Failed · Gemini replied'), findsOneWidget);
      await tester.tap(find.text('MiniMax replied'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CanonicalMessageBody>(find.byType(CanonicalMessageBody))
            .source,
        '**Result**',
      );
      await tester.tap(find.text('Open sub-conversation'));
      expect(opened, child);
      await tester.tap(summary);
      await tester.pump();
      expect(find.byType(CanonicalMessageBody), findsNothing);
    },
  );

  testWidgets('a reminder is one muted line that opens on a tap', (
    tester,
  ) async {
    const long =
        'You are in Plan mode. Do not edit files, only read, search and '
        'plan the change before switching back.';
    await _pump(tester, [
      _notice('r', NoticeKind.continuation, long, status: ItemStatus.pending),
    ]);
    final note = find.byKey(const ValueKey('timeline-note-test/r'));
    expect(note, findsOneWidget);
    expect(find.byType(Card), findsNothing);
    final text = tester.widget<Text>(
      find.descendant(of: note, matching: find.byType(Text)),
    );
    final theme = Theme.of(tester.element(note));
    expect(text.maxLines, 1);
    expect(text.style?.color, theme.colorScheme.onSurfaceVariant);
    expect(text.style?.fontSize, theme.textTheme.labelMedium?.fontSize);
    final closed = tester.getSize(note).height;
    await tester.tap(note);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Text>(find.descendant(of: note, matching: find.byType(Text)))
          .maxLines,
      isNull,
    );
    expect(tester.getSize(note).height, greaterThan(closed));
  });

  testWidgets('system notes, compactions and unknown parts are light too', (
    tester,
  ) async {
    await _pump(tester, [
      _notice('s', NoticeKind.system, 'Instructions updated'),
      _notice('c', NoticeKind.compaction, 'Compacted'),
      UnknownItem(
        meta: _meta('u'),
        rawType: 'future',
        raw: CanonicalValue(const {}),
      ),
    ]);
    for (final id in ['s', 'c', 'u']) {
      expect(
        find.byKey(ValueKey('timeline-note-test/$id')),
        findsOneWidget,
        reason: id,
      );
    }
    expect(find.byType(Card), findsNothing);
    // An unknown part never shows its raw content.
    expect(find.textContaining('future'), findsNothing);
  });

  testWidgets('an open note shows its Markdown, links working', (tester) async {
    await _pump(tester, [
      _notice('m', NoticeKind.system, 'See **the** [docs](https://e.com)'),
    ]);
    final note = find.byKey(const ValueKey('timeline-note-test/m'));
    expect(
      find.descendant(of: note, matching: find.byType(CanonicalMessageBody)),
      findsNothing,
    );
    await tester.tap(note);
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: note, matching: find.byType(CanonicalMessageBody)),
      findsOneWidget,
    );
  });

  testWidgets('a compaction with nothing to say yet keeps its card', (
    tester,
  ) async {
    await _pump(tester, [
      _notice('k', NoticeKind.compaction, '', status: ItemStatus.streaming),
    ]);
    expect(find.byKey(const ValueKey('timeline-note-test/k')), findsNothing);
    expect(find.byType(Card), findsOneWidget);
  });

  testWidgets('a note with no text takes no room', (tester) async {
    await _pump(tester, [_notice('e', NoticeKind.system, '  ')]);
    expect(find.byKey(const ValueKey('timeline-note-test/e')), findsNothing);
    expect(find.byType(Card), findsNothing);
    expect(find.byType(Icon), findsNothing);
  });

  testWidgets('a compaction that failed keeps its card', (tester) async {
    await _pump(tester, [
      _notice(
        'f',
        NoticeKind.compaction,
        'Compaction failed',
        status: ItemStatus.failed,
      ),
    ]);
    expect(find.byKey(const ValueKey('timeline-note-test/f')), findsNothing);
    expect(find.byType(Card), findsOneWidget);
  });
}
