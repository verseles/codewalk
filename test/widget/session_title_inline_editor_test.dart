import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:codewalk/presentation/widgets/session_title_inline_editor.dart';

void main() {
  testWidgets('edits and saves title inline', (tester) async {
    String? saved;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SessionTitleInlineEditor(
            title: 'Session A',
            editingValue: 'Session A',
            onRename: (title) async {
              saved = title;
              return true;
            },
          ),
        ),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('session_title_edit_button')),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>('session_title_editor_field')),
      'Renamed Inline',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('session_title_save_button')),
    );
    await tester.pumpAndSettle();

    expect(saved, 'Renamed Inline');
    expect(
      find.byKey(const ValueKey<String>('session_title_editor_field')),
      findsNothing,
    );
  });

  testWidgets('escape cancels inline edit mode', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SessionTitleInlineEditor(
            title: 'Session A',
            editingValue: 'Session A',
            onRename: (_) async => true,
          ),
        ),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('session_title_edit_button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('session_title_editor_field')),
      findsOneWidget,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('session_title_editor_field')),
      findsNothing,
    );
  });
}
