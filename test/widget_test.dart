import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:codewalk/presentation/widgets/chat_input_widget.dart';

void main() {
  testWidgets('ChatInputWidget renders and sends message', (
    WidgetTester tester,
  ) async {
    String? sentMessage;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatInputWidget(
            onSendMessage: (message, attachments) {
              sentMessage = message;
            },
          ),
        ),
      ),
    );

    expect(find.byType(TextField), findsOneWidget);
    expect(find.byTooltip('Start voice input'), findsOneWidget);
    expect(find.byIcon(Icons.send_rounded), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_return_rounded), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'hello');
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.send_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();

    expect(sentMessage, 'hello');
  });

  testWidgets(
    'holding send button for 300ms inserts newline instead of sending',
    (WidgetTester tester) async {
      String? sentMessage;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatInputWidget(
              onSendMessage: (message, attachments) {
                sentMessage = message;
              },
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'hello');
      await tester.pumpAndSettle();

      final sendButtonFinder = find.byType(FilledButton);
      final gesture = await tester.startGesture(
        tester.getCenter(sendButtonFinder),
      );
      await tester.pump(const Duration(milliseconds: 350));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(sentMessage, isNull);
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller!.text, 'hello\n');
    },
  );

  test('microphone button uses default palette when inactive', () {
    const colorScheme = ColorScheme.light();
    expect(
      microphoneButtonBackgroundColor(
        isListening: false,
        colorScheme: colorScheme,
      ),
      colorScheme.secondaryContainer,
    );
    expect(
      microphoneButtonForegroundColor(
        isListening: false,
        colorScheme: colorScheme,
      ),
      colorScheme.onSecondaryContainer,
    );
  });

  test('microphone button turns red while listening', () {
    const colorScheme = ColorScheme.light();
    expect(
      microphoneButtonBackgroundColor(
        isListening: true,
        colorScheme: colorScheme,
      ),
      colorScheme.error,
    );
    expect(
      microphoneButtonForegroundColor(
        isListening: true,
        colorScheme: colorScheme,
      ),
      colorScheme.onError,
    );
  });
}
