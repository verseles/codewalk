import 'package:codewalk/domain/entities/chat_message.dart';
import 'package:codewalk/presentation/theme/app_shapes.dart';
import 'package:codewalk/presentation/widgets/chat_message_widget.dart';
import 'package:codewalk/presentation/widgets/math_expression_widget.dart';
import 'package:codewalk/presentation/widgets/mermaid_diagram_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump_localized_app.dart';

void main() {
  final time = DateTime.fromMillisecondsSinceEpoch(1000);

  AssistantMessage message(String id, String text) {
    return AssistantMessage(
      id: id,
      sessionId: 'g2_rendering',
      time: time,
      completedTime: time.add(const Duration(seconds: 1)),
      parts: <MessagePart>[
        TextPart(
          id: 'part_$id',
          messageId: id,
          sessionId: 'g2_rendering',
          text: text,
        ),
      ],
    );
  }

  Widget app(AssistantMessage message) {
    return localizedMaterialApp(
      theme: ThemeData(platform: TargetPlatform.android),
      home: Scaffold(
        body: SingleChildScrollView(child: ChatMessageWidget(message: message)),
      ),
    );
  }

  testWidgets(
    'Mermaid and inline/block LaTeX render together in either order',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const sources = <String>[
        r'''Context before the diagram with inline math $x^2$.

```mermaid
graph TD
A[Start] --> B[End]
```

$$
E=mc^2
$$

Context after the formula.''',
        r'''Context before the formula with inline math $x^2$.

$$
E=mc^2
$$

```mermaid
graph TD
A[Start] --> B[End]
```

Context after the diagram.''',
      ];

      for (var index = 0; index < sources.length; index++) {
        await tester.pumpWidget(
          app(message('g2_mixed_$index', sources[index])),
        );
        await tester.pumpAndSettle();

        expect(find.byType(MermaidDiagramWidget), findsOneWidget);
        expect(find.byType(MathExpressionWidget), findsNWidgets(2));
        expect(
          find.textContaining('Context before', findRichText: true),
          findsOneWidget,
        );
        expect(
          find.textContaining('Context after', findRichText: true),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'Markdown tables have rounded bold headers and narrow scrolling',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const source = '''
Message before the table.

| First column | Link | Description |
| --- | --- | --- |
| Alpha | [OpenCode](https://example.com) | <b>Bold cell</b> with a deliberately long description that should remain reachable on a narrow display. |

Message after the table.
''';

      await tester.pumpWidget(app(message('g2_table_mobile', source)));
      await tester.pumpAndSettle();

      final tableFinder = find.byType(Table);
      expect(tableFinder, findsOneWidget);
      final table = tester.widget<Table>(tableFinder);
      expect(table.defaultColumnWidth, isA<IntrinsicColumnWidth>());
      expect(table.border?.borderRadius, AppShapes.borderExtraSmall);
      expect(table.children, hasLength(2));
      final headerDecoration = table.children.first.decoration;
      expect(headerDecoration, isA<BoxDecoration>());
      expect((headerDecoration! as BoxDecoration).color, isNotNull);
      expect(table.children.last.decoration, isNull);
      final tableTextStyles = tester.widgetList<DefaultTextStyle>(
        find.descendant(
          of: tableFinder,
          matching: find.byType(DefaultTextStyle),
        ),
      );
      expect(
        tableTextStyles.any(
          (textStyle) => textStyle.style.fontWeight == FontWeight.bold,
        ),
        isTrue,
      );

      final tableScrollViews = tester.widgetList<SingleChildScrollView>(
        find.ancestor(
          of: tableFinder,
          matching: find.byType(SingleChildScrollView),
        ),
      );
      expect(
        tableScrollViews.any(
          (scrollView) => scrollView.scrollDirection == Axis.horizontal,
        ),
        isTrue,
      );
      final horizontalTableScrollView = tableScrollViews.singleWhere(
        (scrollView) => scrollView.scrollDirection == Axis.horizontal,
      );
      final horizontalScrollViewFinder = find.byWidget(
        horizontalTableScrollView,
      );
      final horizontalScrollableFinder = find.descendant(
        of: horizontalScrollViewFinder,
        matching: find.byType(Scrollable),
      );
      final horizontalScrollable = tester.state<ScrollableState>(
        horizontalScrollableFinder,
      );
      expect(horizontalScrollable.position.maxScrollExtent, greaterThan(0));
      await tester.drag(horizontalScrollViewFinder, const Offset(-200, 0));
      await tester.pumpAndSettle();
      expect(horizontalScrollable.position.pixels, greaterThan(0));

      bool hasRecognizer(InlineSpan span) {
        if (span is! TextSpan) return false;
        return span.recognizer != null ||
            (span.children ?? const <InlineSpan>[]).any(hasRecognizer);
      }

      final tableRichTexts = tester.widgetList<RichText>(
        find.descendant(of: tableFinder, matching: find.byType(RichText)),
      );
      expect(tableRichTexts.any((text) => hasRecognizer(text.text)), isTrue);
      expect(
        find.textContaining('OpenCode', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('First column', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('Bold cell', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('Message before', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('Message after', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('<b>Bold cell</b>'), findsNothing);
      expect(tester.takeException(), isNull);

      tester.view.physicalSize = const Size(1200, 800);
      await tester.pumpWidget(app(message('g2_table_desktop', source)));
      await tester.pumpAndSettle();
      expect(find.byType(Table), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
