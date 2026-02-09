import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:codewalk/domain/entities/chat_realtime.dart';
import 'package:codewalk/presentation/widgets/permission_request_card.dart';
import 'package:codewalk/presentation/widgets/question_request_card.dart';

void main() {
  testWidgets('PermissionRequestCard dispatches selected decision', (
    WidgetTester tester,
  ) async {
    String? decided;
    final request = const ChatPermissionRequest(
      id: 'perm_1',
      sessionId: 'ses_1',
      permission: 'edit',
      patterns: <String>['lib/**'],
      always: <String>[],
      metadata: <String, dynamic>{},
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PermissionRequestCard(
            request: request,
            busy: false,
            onDecide: (reply) => decided = reply,
          ),
        ),
      ),
    );

    expect(find.textContaining('Permission request:'), findsOneWidget);
    await tester.tap(find.text('Allow Once'));
    await tester.pump();
    expect(decided, 'once');
  });

  testWidgets('QuestionRequestCard submits selected answers', (
    WidgetTester tester,
  ) async {
    List<List<String>>? submitted;
    var rejected = false;
    final request = const ChatQuestionRequest(
      id: 'q_1',
      sessionId: 'ses_1',
      questions: <ChatQuestionInfo>[
        ChatQuestionInfo(
          question: 'Proceed?',
          header: 'Confirm',
          options: <ChatQuestionOption>[
            ChatQuestionOption(label: 'Yes', description: 'Continue'),
            ChatQuestionOption(label: 'No', description: 'Stop'),
          ],
          multiple: false,
          custom: false,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuestionRequestCard(
            request: request,
            busy: false,
            onSubmit: (answers) => submitted = answers,
            onReject: () => rejected = true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Yes'));
    await tester.pump();
    await tester.tap(find.text('Submit Answers'));
    await tester.pump();

    expect(submitted, isNotNull);
    expect(submitted, const <List<String>>[
      <String>['Yes'],
    ]);

    await tester.tap(find.text('Reject'));
    await tester.pump();
    expect(rejected, isTrue);
  });
}
