import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:codewalk/domain/entities/chat_session.dart';
import 'package:codewalk/presentation/widgets/chat_session_list.dart';

void main() {
  ChatSession session({bool shared = false, DateTime? archivedAt}) {
    return ChatSession(
      id: 'ses_1',
      workspaceId: 'default',
      time: DateTime.fromMillisecondsSinceEpoch(1000),
      title: 'Session 1',
      shared: shared,
      shareUrl: shared ? 'https://share.mock/s/ses_1' : null,
      archivedAt: archivedAt,
    );
  }

  testWidgets('rename menu action calls rename callback', (tester) async {
    String? renamedTitle;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatSessionList(
            sessions: <ChatSession>[session()],
            onSessionRenamed: (item, title) async {
              renamedTitle = title;
              return true;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Renamed title');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(renamedTitle, 'Renamed title');
  });

  testWidgets('share toggle action calls callback', (tester) async {
    var calls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatSessionList(
            sessions: <ChatSession>[session(shared: false)],
            onSessionShareToggled: (item) async {
              calls += 1;
              return true;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();

    expect(calls, 1);
  });

  testWidgets('archive and delete actions call callbacks', (tester) async {
    var archivedCalls = 0;
    var deleteCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatSessionList(
            sessions: <ChatSession>[session()],
            onSessionArchiveToggled: (item, archived) async {
              archivedCalls += archived ? 1 : 0;
              return true;
            },
            onSessionDeleted: (item) async {
              deleteCalls += 1;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();
    expect(archivedCalls, 1);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    expect(deleteCalls, 1);
  });
}
