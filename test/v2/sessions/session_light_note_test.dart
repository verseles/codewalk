import 'package:codewalk/features/sessions/session_timeline_tile.dart';
import 'package:codewalk/shared/l10n/generated/v2_localizations.dart';
import 'package:codewalk/shared/rendering/canonical_message_body.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// #491: reminders and other notes are light lines, not cards.

ItemMeta _meta(String id, {ItemStatus status = ItemStatus.completed}) =>
    ItemMeta(
      id: ItemId('test/$id'),
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
