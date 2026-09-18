import 'package:codewalk/domain/entities/chat_message.dart';
import 'package:codewalk/presentation/widgets/chat_message_widget.dart';
import 'package:codewalk/presentation/widgets/mermaid_diagram_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump_localized_app.dart';

void main() {
  final time = DateTime.fromMillisecondsSinceEpoch(1000);
  ChatMessage message(String text, {bool user = false, bool complete = true}) {
    final parts = [
      TextPart(id: 'text', messageId: 'html', sessionId: 'session', text: text),
    ];
    if (user) {
      return UserMessage(
        id: 'html',
        sessionId: 'session',
        time: time,
        parts: parts,
      );
    }
    return AssistantMessage(
      id: 'html',
      sessionId: 'session',
      time: time,
      completedTime: complete ? time.add(const Duration(seconds: 1)) : null,
      parts: parts,
    );
  }

  Widget app(ChatMessage message, {bool active = false}) =>
      localizedMaterialApp(
        theme: ThemeData(platform: TargetPlatform.android),
        home: Scaffold(
          body: SingleChildScrollView(
            child: ChatMessageWidget(
              message: message,
              isSessionActivelyResponding: active,
            ),
          ),
        ),
      );

  testWidgets('assistant basic HTML renders and whole-message copy stays raw', (
    tester,
  ) async {
    const source =
        '<b>HTML message</b>\n\n<progress value="1" max="2"></progress>';
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(app(message(source)));
    expect(find.text('HTML message'), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      .5,
    );
    await tester.tap(find.text('HTML message'));
    await tester.pump(const Duration(milliseconds: 40));
    await tester.tap(find.text('HTML message'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(copied, source);
    expect(tester.takeException(), isNull);
  });

  testWidgets('user HTML stays on existing Markdown path', (tester) async {
    await tester.pumpWidget(app(message('<b>user</b>', user: true)));
    expect(find.text('<b>user</b>'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('production HTML bold and italic styles compose', (tester) async {
    await tester.pumpWidget(
      app(message('<b><i>[styled](https://example.com)</i></b>')),
    );
    TextSpan? findSpan(InlineSpan span) {
      if (span is! TextSpan) return null;
      if (span.text == 'styled') return span;
      for (final child in span.children ?? <InlineSpan>[]) {
        final found = findSpan(child);
        if (found != null) return found;
      }
      return null;
    }

    final span = tester
        .widgetList<RichText>(find.byType(RichText))
        .map((widget) => findSpan(widget.text))
        .whereType<TextSpan>()
        .first;
    expect(span.style?.fontWeight, FontWeight.bold);
    expect(span.style?.fontStyle, FontStyle.italic);
    expect(tester.takeException(), isNull);
  });

  testWidgets('assistant HTML streaming completion flushes final formatting', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(message('<b>partial', complete: false), active: true),
    );
    expect(find.text('<b>partial'), findsOneWidget);
    await tester.pumpWidget(app(message('<b>finished</b>'), active: false));
    expect(find.text('finished'), findsOneWidget);
    expect(find.text('<b>partial'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('HTML coexists with Mermaid and literal code examples', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        message(
          '<b>Diagram</b>\n\n```mermaid\ngraph TD\nA-->B\n```\n\n`<progress value="1"></progress>`',
        ),
      ),
    );
    expect(find.text('Diagram'), findsOneWidget);
    expect(find.byType(MermaidDiagramWidget), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
