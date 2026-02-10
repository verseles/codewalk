import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:codewalk/presentation/widgets/chat_input_widget.dart';

void main() {
  testWidgets('ChatInputWidget renders and sends message', (
    WidgetTester tester,
  ) async {
    ChatInputSubmission? sentSubmission;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatInputWidget(
            onSendMessage: (submission) {
              sentSubmission = submission;
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

    expect(sentSubmission?.text, 'hello');
    expect(sentSubmission?.mode, ChatComposerMode.normal);
  });

  testWidgets(
    'holding send button for 300ms inserts newline instead of sending',
    (WidgetTester tester) async {
      ChatInputSubmission? sentSubmission;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatInputWidget(
              onSendMessage: (submission) {
                sentSubmission = submission;
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

      expect(sentSubmission, isNull);
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller!.text, 'hello\n');
    },
  );

  testWidgets('typing ! enters shell mode and sends shell submission', (
    WidgetTester tester,
  ) async {
    ChatInputSubmission? sentSubmission;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatInputWidget(
            onSendMessage: (submission) {
              sentSubmission = submission;
            },
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '!pwd');
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('composer_shell_mode_chip')),
      findsOneWidget,
    );

    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();

    expect(sentSubmission?.mode, ChatComposerMode.shell);
    expect(sentSubmission?.text, 'pwd');
  });

  testWidgets('slash popover inserts selected command prefix', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatInputWidget(
            onSendMessage: (_) {},
            onSlashQuery: (query) async {
              return const <ChatComposerSlashCommandSuggestion>[
                ChatComposerSlashCommandSuggestion(
                  name: 'open',
                  source: 'command',
                  description: 'Open file',
                ),
              ];
            },
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '/op');
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('composer_popover_slash')),
      findsOneWidget,
    );
    await tester.tap(find.text('/open'));
    await tester.pumpAndSettle();

    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.controller!.text, '/open ');
  });

  testWidgets('mention popover inserts @ token', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatInputWidget(
            onSendMessage: (_) {},
            onMentionQuery: (query) async {
              return const <ChatComposerMentionSuggestion>[
                ChatComposerMentionSuggestion(
                  value: 'README.md',
                  type: ChatComposerSuggestionType.file,
                  subtitle: 'file',
                ),
              ];
            },
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '@REA');
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('composer_popover_mention')),
      findsOneWidget,
    );
    await tester.tap(find.text('README.md'));
    await tester.pumpAndSettle();

    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.controller!.text, '@README.md ');
  });

  testWidgets('mention selection keeps input focused while typing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatInputWidget(
            onSendMessage: (_) {},
            onMentionQuery: (query) async {
              return const <ChatComposerMentionSuggestion>[
                ChatComposerMentionSuggestion(
                  value: 'lib/main.dart',
                  type: ChatComposerSuggestionType.file,
                  subtitle: 'file',
                ),
              ];
            },
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '@ma');
    await tester.pumpAndSettle();

    final inputField = tester.widget<TextField>(find.byType(TextField));
    expect(inputField.focusNode?.hasFocus, isTrue);
  });

  testWidgets(
    'mention insertion guarantees space before trailing punctuation',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatInputWidget(
              onSendMessage: (_) {},
              onMentionQuery: (query) async {
                return const <ChatComposerMentionSuggestion>[
                  ChatComposerMentionSuggestion(
                    value: 'README.md',
                    type: ChatComposerSuggestionType.file,
                    subtitle: 'file',
                  ),
                ];
              },
            ),
          ),
        ),
      );

      await tester.showKeyboard(find.byType(TextField));
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '@REA?',
          selection: TextSelection.collapsed(offset: 4),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('README.md'));
      await tester.pumpAndSettle();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller!.text, '@README.md ?');
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
