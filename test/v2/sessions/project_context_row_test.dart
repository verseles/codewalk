import 'package:codewalk/features/sessions/project_context_list.dart';
import 'package:codewalk/shared/l10n/generated/v2_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // A narrow pane at 2x text keeps the name and the path inside the row, even
  // when the count is three digits and the folder and chevron are dropped.
  for (final width in [120.0, 160.0]) {
    testWidgets('a project row at ${width.toInt()} dp keeps a large count', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: V2Localizations.localizationsDelegates,
          supportedLocales: V2Localizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: width,
                child: ProjectContextRow(
                  directory:
                      '/a/very/long/workspace/path/that/should/ellipsize',
                  active: true,
                  count: 100,
                  complete: false,
                  compact: true,
                  onTap: () {},
                  onClose: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('100+'), findsOneWidget);
    });
  }
}
