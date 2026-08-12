import 'package:codewalk/domain/entities/session_attention_overlay/session_attention_models.dart';
import 'package:codewalk/presentation/widgets/session_attention_overlay/session_attention_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

SessionAttentionItem _item({
  String id = 'session-a',
  RootSessionAttentionKind kind = RootSessionAttentionKind.completed,
  String displayText = 'Final response',
  String speechText = 'Final response',
  SessionAttentionTransportCapability transport =
      SessionAttentionTransportCapability.live,
}) {
  return SessionAttentionItem(
    schemaVersion: 1,
    revision: 1,
    identity: SessionAttentionIdentity(
      serverId: 'server-a',
      directory: '/repo/a',
      rootSessionId: id,
    ),
    title: 'Session $id',
    projectLabel: 'Project A',
    kind: kind,
    startedAtEpochMs: 1,
    lastObservedAtEpochMs: 2,
    observableBusyElapsedMs: 3,
    assistantMessageId: 'message-$id',
    displayText: displayText,
    speechText: speechText,
    displayTruncated: false,
    speechTruncated: false,
    completedAtEpochMs: 4,
    opened: false,
    dismissed: false,
    transportCapability: transport,
    contentDigest: 'digest-$id',
  );
}

Widget _app({
  required List<SessionAttentionItem> items,
  required bool expanded,
  Size? hostSize,
  bool reserveBubbleControls = false,
  ValueChanged<SessionAttentionItem>? onOpen,
  ValueChanged<SessionAttentionItem>? onRead,
  ValueChanged<SessionAttentionItem>? onDismiss,
  VoidCallback? onToggle,
  VoidCallback? onStop,
}) {
  final overlay = SessionAttentionOverlay(
    items: items,
    expanded: expanded,
    semanticLabel: '${items.length} sessions need attention',
    openLabel: 'Open',
    expandLabel: 'Expand',
    collapseLabel: 'Collapse',
    readLabel: 'Read',
    stopReadingLabel: 'Stop reading',
    dismissLabel: 'Dismiss',
    stopOverlayLabel: 'Stop overlay',
    onOpen: onOpen ?? (_) {},
    onRead: onRead,
    onDismiss: onDismiss ?? (_) {},
    onToggleExpanded: onToggle ?? () {},
    onStopOverlay: onStop ?? () {},
  );
  final hostedOverlay = reserveBubbleControls
      ? Padding(
          padding: const EdgeInsetsDirectional.only(end: 8, bottom: 8),
          child: overlay,
        )
      : overlay;
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: hostSize == null
            ? overlay
            : SizedBox.fromSize(
                key: const ValueKey<String>('session_attention_test_host'),
                size: hostSize,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: hostedOverlay,
                ),
              ),
      ),
    ),
  );
}

void main() {
  testWidgets('bubble fits the 96 by 96 Android host', (tester) async {
    await tester.pumpWidget(
      _app(
        items: <SessionAttentionItem>[_item()],
        expanded: false,
        hostSize: const Size(96, 96),
      ),
    );

    expect(
      tester.getSize(
        find.byKey(const ValueKey<String>('session_attention_test_host')),
      ),
      const Size(96, 96),
    );
    final bubbleSize = tester.getSize(
      find.byKey(const ValueKey<String>('session_attention_bubble')),
    );
    expect(bubbleSize.width, lessThanOrEqualTo(96));
    expect(bubbleSize.height, lessThanOrEqualTo(96));
    expect(tester.takeException(), isNull);
  });

  testWidgets('extra-small Android host contains the expand control', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        items: <SessionAttentionItem>[_item()],
        expanded: false,
        hostSize: const Size(56, 56),
        reserveBubbleControls: true,
      ),
    );

    final hostRect = tester.getRect(
      find.byKey(const ValueKey<String>('session_attention_test_host')),
    );
    final expandRect = tester.getRect(
      find.byKey(const ValueKey<String>('session_attention_expand')),
    );
    expect(expandRect.left, greaterThanOrEqualTo(hostRect.left));
    expect(expandRect.top, greaterThanOrEqualTo(hostRect.top));
    expect(expandRect.right, lessThanOrEqualTo(hostRect.right));
    expect(expandRect.bottom, lessThanOrEqualTo(hostRect.bottom));
    expect(tester.takeException(), isNull);
  });

  testWidgets('panel fits the 360 by 240 Android host', (tester) async {
    final items = <SessionAttentionItem>[
      _item(id: 'session-a'),
      _item(id: 'session-b'),
      _item(id: 'session-c'),
    ];
    SessionAttentionItem? opened;
    SessionAttentionItem? read;
    SessionAttentionItem? dismissed;
    await tester.pumpWidget(
      _app(
        items: items,
        expanded: true,
        hostSize: const Size(360, 240),
        onOpen: (item) => opened = item,
        onRead: (item) => read = item,
        onDismiss: (item) => dismissed = item,
      ),
    );

    expect(
      tester.getSize(
        find.byKey(const ValueKey<String>('session_attention_test_host')),
      ),
      const Size(360, 240),
    );
    final panelSize = tester.getSize(
      find.byKey(const ValueKey<String>('session_attention_panel')),
    );
    expect(panelSize.width, lessThanOrEqualTo(360));
    expect(panelSize.height, lessThanOrEqualTo(240));
    expect(
      find.byKey(const ValueKey<String>('session_attention_collapse')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('session_attention_stop')),
      findsOneWidget,
    );

    final finalItem = items.last;
    final finalRow = find.byKey(
      ValueKey<String>('session_attention_item_${finalItem.snapshotId}'),
    );
    await tester.scrollUntilVisible(
      finalRow,
      100,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();
    final openButton = find.descendant(
      of: finalRow,
      matching: find.widgetWithText(TextButton, 'Open'),
    );
    final readButton = find.descendant(
      of: finalRow,
      matching: find.widgetWithText(TextButton, 'Read'),
    );
    final dismissButton = find.descendant(
      of: finalRow,
      matching: find.widgetWithText(TextButton, 'Dismiss'),
    );
    await tester.tap(openButton);
    await tester.tap(readButton);
    await tester.tap(dismissButton);

    expect(opened, same(finalItem));
    expect(read, same(finalItem));
    expect(dismissed, same(finalItem));
    await tester.scrollUntilVisible(
      find.byKey(
        ValueKey<String>('session_attention_item_${items.first.snapshotId}'),
      ),
      -100,
      scrollable: find.byType(Scrollable),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('bubble exposes count semantics and opens primary item', (
    tester,
  ) async {
    SessionAttentionItem? opened;
    final items = <SessionAttentionItem>[
      _item(id: 'receiving', kind: RootSessionAttentionKind.receiving),
      _item(id: 'error', kind: RootSessionAttentionKind.error),
    ];
    await tester.pumpWidget(
      _app(items: items, expanded: false, onOpen: (item) => opened = item),
    );

    expect(
      find.byKey(const ValueKey<String>('session_attention_bubble')),
      findsOneWidget,
    );
    expect(find.text('2'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'Error, 2, 2 sessions need attention',
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('session_attention_bubble')),
    );
    expect(opened?.kind, RootSessionAttentionKind.error);
  });

  testWidgets('panel exposes open read dismiss collapse and stop actions', (
    tester,
  ) async {
    final item = _item();
    var opened = false;
    var read = false;
    var dismissed = false;
    var collapsed = false;
    var stopped = false;
    await tester.pumpWidget(
      _app(
        items: <SessionAttentionItem>[item],
        expanded: true,
        onOpen: (_) => opened = true,
        onRead: (_) => read = true,
        onDismiss: (_) => dismissed = true,
        onToggle: () => collapsed = true,
        onStop: () => stopped = true,
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('session_attention_panel')),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(TextButton, 'Open'));
    await tester.tap(find.widgetWithText(TextButton, 'Read'));
    await tester.tap(find.widgetWithText(TextButton, 'Dismiss'));
    await tester.tap(
      find.byKey(const ValueKey<String>('session_attention_collapse')),
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('session_attention_stop')),
    );

    expect(opened, isTrue);
    expect(read, isTrue);
    expect(dismissed, isTrue);
    expect(collapsed, isTrue);
    expect(stopped, isTrue);
  });

  testWidgets('reopen-required completion disables Read', (tester) async {
    await tester.pumpWidget(
      _app(
        items: <SessionAttentionItem>[
          _item(transport: SessionAttentionTransportCapability.reopenRequired),
        ],
        expanded: true,
        onRead: (_) {},
      ),
    );

    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Read'))
          .onPressed,
      isNull,
    );
  });
}
