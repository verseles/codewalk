import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:open_mode/presentation/widgets/chat_input_widget.dart';

void main() {
  testWidgets('ChatInputWidget renders and sends message', (
    WidgetTester tester,
  ) async {
    String? sentMessage;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatInputWidget(
            onSendMessage: (message) {
              sentMessage = message;
            },
          ),
        ),
      ),
    );

    expect(find.byType(TextField), findsOneWidget);
    expect(find.byIcon(Icons.mic_rounded), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'hello');
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.send_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();

    expect(sentMessage, 'hello');
  });
}
