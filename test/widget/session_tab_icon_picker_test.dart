import 'package:codewalk/presentation/widgets/session_tab_icon_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump_localized_app.dart';

void main() {
  testWidgets('selects a preset from the desktop picker', (tester) async {
    SessionTabIconSelection? selection;
    await tester.pumpWidget(
      localizedMaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                selection = await showSessionTabIconPicker(
                  context,
                  currentPresetId: null,
                  project: null,
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Choose tab icon'), findsOneWidget);
    expect(
      tester
          .getSemantics(
            find.byKey(
              const ValueKey<String>('session_tab_icon_option_terminal'),
            ),
          )
          .getSemanticsData()
          .hasAction(SemanticsAction.tap),
      isTrue,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('session_tab_icon_option_terminal')),
    );
    await tester.pumpAndSettle();

    expect(selection?.presetId, 'terminal');
  });

  testWidgets('mobile picker resets to the project icon without overflow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SessionTabIconSelection? selection;
    await tester.pumpWidget(
      localizedMaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                selection = await showSessionTabIconPicker(
                  context,
                  currentPresetId: 'bug',
                  project: null,
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('session_tab_icon_option_project')),
    );
    await tester.pumpAndSettle();

    expect(selection, isNotNull);
    expect(selection?.presetId, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('short desktop uses the scroll-safe fullscreen picker', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 500));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      localizedMaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showSessionTabIconPicker(
                context,
                currentPresetId: null,
                project: null,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('session_tab_icon_picker_grid')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
