import 'package:codewalk/features/sessions/session_agent_color.dart';
import 'package:codewalk/features/sessions/session_switch_note.dart';
import 'package:codewalk/features/sessions/session_timeline_projection.dart';
import 'package:codewalk/features/sessions/session_timeline_tile.dart';
import 'package:codewalk/shared/l10n/generated/v2_localizations.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';
import 'live_fakes.dart';

/// Model and agent switches in the conversation (#426).
void main() {
  final ref = CatalogSource(profile('a')).row('one').info.ref;

  Notice switched(String id, Selection selection) => Notice(
    meta: liveMeta(ref, id),
    kind: const OpenValue.known(NoticeKind.selectionChanged),
    text: '',
    selection: selection,
  );

  Future<V2Localizations> pump(
    WidgetTester tester,
    List<Notice> notes, {
    bool labels = true,
  }) async {
    final tiles = Column(
      children: [
        for (final note in notes)
          SessionTimelineTile(item: note, messageHeader: false),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: V2Localizations.localizationsDelegates,
        supportedLocales: V2Localizations.supportedLocales,
        home: Scaffold(
          body: labels
              ? SessionSwitchLabels(
                  models: [
                    ModelEntry(id: 'model-b', providerId: 'p', label: 'Beta'),
                  ],
                  agents: [
                    CatalogEntry(
                      id: 'plan',
                      kind: const OpenValue.known(CatalogKind.agent),
                      label: 'Plan',
                    ),
                  ],
                  child: tiles,
                )
              : tiles,
        ),
      ),
    );
    return V2Localizations.of(tester.element(find.byType(Column).first));
  }

  testWidgets('a switch reads as a note with the catalog names', (
    tester,
  ) async {
    final l10n = await pump(tester, [
      switched('s1', const Selection(agentId: 'plan')),
      switched(
        's2',
        const Selection(
          modelId: 'model-b',
          modelProviderId: 'p',
          modelVariant: 'high',
        ),
      ),
    ]);
    expect(find.text(l10n.liveSwitchedAgent('Plan')), findsOneWidget);
    expect(find.text(l10n.liveSwitchedModel('Beta high')), findsOneWidget);
    // The agent on its color.
    final dot = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    expect(dot.backgroundColor, sessionPlanAgentColor);
  });

  testWidgets('without a catalog the note names the reported ids', (
    tester,
  ) async {
    final l10n = await pump(tester, [
      switched('s1', const Selection(agentId: 'review')),
      switched('s2', const Selection(modelId: 'model-z', modelProviderId: 'q')),
    ], labels: false);
    expect(find.text(l10n.liveSwitchedAgent('review')), findsOneWidget);
    expect(find.text(l10n.liveSwitchedModel('model-z')), findsOneWidget);
  });

  testWidgets('a blank catalog name falls back to the reported id', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: V2Localizations.localizationsDelegates,
        supportedLocales: V2Localizations.supportedLocales,
        home: Scaffold(
          body: SessionSwitchLabels(
            models: [ModelEntry(id: 'model-b', providerId: 'p', label: ' ')],
            agents: [
              CatalogEntry(
                id: 'plan',
                kind: const OpenValue.known(CatalogKind.agent),
                label: ' ',
              ),
            ],
            child: Column(
              children: [
                SessionTimelineTile(
                  item: switched('s1', const Selection(agentId: 'plan')),
                  messageHeader: false,
                ),
                SessionTimelineTile(
                  item: switched(
                    's2',
                    const Selection(modelId: 'model-b', modelProviderId: 'p'),
                  ),
                  messageHeader: false,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final l10n = V2Localizations.of(tester.element(find.byType(Column).first));
    expect(find.text(l10n.liveSwitchedAgent('plan')), findsOneWidget);
    expect(find.text(l10n.liveSwitchedModel('model-b')), findsOneWidget);
  });

  test('a switch made while a turn ran stays out of its collapsed work', () {
    ItemMeta inMessage(String id, String message) => ItemMeta(
      id: ItemId(id),
      generation: 'live',
      status: const OpenValue.known(ItemStatus.completed),
      source: liveMeta(ref, id).source,
      message: MessageContext(message: MessageRef(message)),
    );
    final note = switched('n1', const Selection(agentId: 'plan'));
    final rows = SessionTimelinePresentation().project([
      UserInput(
        meta: liveMeta(ref, 'u1'),
        text: 'go',
        delivery: const OpenValue.known(DeliveryState.delivered),
      ),
      ToolCall(
        meta: inMessage('t1', 'm1'),
        kind: const OpenValue.known(ToolKind.read),
        rawName: 'read',
      ),
      note,
      ToolCall(
        meta: inMessage('t2', 'm2'),
        kind: const OpenValue.known(ToolKind.read),
        rawName: 'read',
      ),
      AssistantText(meta: inMessage('a1', 'm3'), text: 'done', complete: true),
    ], settled: true);
    final group = rows.whereType<SessionWorkGroupRow>().single;
    expect(group.work.map((item) => item.id.value), ['t1', 't2']);
    expect(group.messageCount, 2);
    // The note shows after the collapsed work, before the answer.
    final shown = [
      for (final row in rows)
        if (row is SessionItemRow) row.item.id.value,
    ];
    expect(shown, ['u1', 'n1', 'a1']);
    expect(
      rows.indexWhere((row) => row is SessionWorkGroupRow),
      lessThan(rows.indexWhere((row) => row.items.contains(note))),
    );
  });
}
