import 'package:codewalk/domain/entities/experience_settings.dart';
import 'package:codewalk/presentation/theme/opencode_theme_presets.dart';
import 'package:codewalk/presentation/widgets/mermaid_diagram_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mermaid/flutter_mermaid.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../support/pump_localized_app.dart';

double _contrastRatio(Color foreground, Color background) {
  final foregroundLuminance = foreground.computeLuminance();
  final backgroundLuminance = background.computeLuminance();
  final lighter = foregroundLuminance > backgroundLuminance
      ? foregroundLuminance
      : backgroundLuminance;
  final darker = foregroundLuminance > backgroundLuminance
      ? backgroundLuminance
      : foregroundLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  group('MermaidDiagramWidget', () {
    testWidgets('renders with valid source and copy button', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        localizedMaterialApp(
          home: Scaffold(
            body: MermaidDiagramWidget(
              code: 'graph TD\n  A[Start] --> B[End]',
              onCopySource: () {},
            ),
          ),
        ),
      );

      expect(find.text('Mermaid Diagram'), findsOneWidget);
      expect(find.byIcon(Symbols.content_copy), findsOneWidget);
    });

    testWidgets('shows fallback source when source is unparseable', (
      WidgetTester tester,
    ) async {
      const invalidSource = '{{{ totally invalid mermaid source }}}';
      await tester.pumpWidget(
        localizedMaterialApp(
          home: Scaffold(
            body: MermaidDiagramWidget(
              code: invalidSource,
              onCopySource: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Header always visible.
      expect(find.text('Mermaid Diagram'), findsOneWidget);
      expect(find.byIcon(Symbols.content_copy), findsOneWidget);
      // Fallback must show the raw source text.
      expect(find.text(invalidSource), findsOneWidget);
    });

    testWidgets('renders empty source without crashing', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        localizedMaterialApp(
          home: Scaffold(
            body: MermaidDiagramWidget(code: '', onCopySource: () {}),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Widget should render even with empty code; header always visible.
      expect(find.text('Mermaid Diagram'), findsOneWidget);
    });

    testWidgets('no copy button when onCopySource is null', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        localizedMaterialApp(
          home: const Scaffold(
            body: MermaidDiagramWidget(code: 'graph TD\n  A --> B'),
          ),
        ),
      );

      expect(find.text('Mermaid Diagram'), findsOneWidget);
      // No copy button should be rendered.
      expect(find.byIcon(Symbols.content_copy), findsNothing);
    });

    testWidgets('uses active theme colors for nodes and edge labels', (
      WidgetTester tester,
    ) async {
      const themeCases = <(OpenCodeThemePreset?, Brightness)>[
        (null, Brightness.light),
        (OpenCodeThemePreset.github, Brightness.light),
        (OpenCodeThemePreset.dracula, Brightness.dark),
        (OpenCodeThemePreset.everforest, Brightness.light),
        (OpenCodeThemePreset.osakaJade, Brightness.dark),
        (OpenCodeThemePreset.carbonfox, Brightness.light),
        (OpenCodeThemePreset.solarized, Brightness.light),
        (OpenCodeThemePreset.vesper, Brightness.dark),
      ];

      for (final themeCase in themeCases) {
        final preset = themeCase.$1;
        final brightness = themeCase.$2;
        final colorScheme = brightness == Brightness.dark
            ? openCodeDarkSchemeFor(preset) ?? const ColorScheme.dark()
            : openCodeLightSchemeFor(preset) ?? const ColorScheme.light();
        final themeTokens = preset == null
            ? classicThemeTokensFrom(colorScheme)
            : openCodeThemeTokensFor(preset, brightness)!;
        final theme = ThemeData(
          platform: TargetPlatform.android,
          colorScheme: colorScheme,
          extensions: preset == null
              ? const <ThemeExtension<dynamic>>[]
              : <ThemeExtension<dynamic>>[themeTokens],
        );

        await tester.pumpWidget(
          localizedMaterialApp(
            theme: theme,
            home: Scaffold(
              body: MermaidDiagramWidget(
                code: 'graph TD\nA[Start] -->|Yes| B[Finish]',
                onCopySource: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final diagram = tester.widget<MermaidDiagram>(
          find.byType(MermaidDiagram),
        );
        final style = diagram.style!;
        expect(
          style.backgroundColor,
          colorScheme.surfaceContainerLowest.toARGB32(),
        );
        expect(
          style.defaultNodeStyle.fillColor,
          themeTokens.surfaceRaised.toARGB32(),
        );
        expect(style.defaultNodeStyle.strokeColor, isNotNull);
        expect(
          style.defaultEdgeStyle.labelBackgroundColor,
          colorScheme.surfaceContainerLowest.toARGB32(),
        );
        final nodeFill = Color(style.defaultNodeStyle.fillColor!);
        final nodeText = Color(style.defaultNodeStyle.textColor!);
        final nodeStroke = Color(style.defaultNodeStyle.strokeColor!);
        final edgeStroke = Color(style.defaultEdgeStyle.strokeColor!);
        final edgeLabel = Color(style.defaultEdgeStyle.labelColor!);
        final edgeLabelBackground = Color(
          style.defaultEdgeStyle.labelBackgroundColor!,
        );
        expect(nodeText.a, 1);
        expect(edgeLabel.a, 1);
        expect(_contrastRatio(nodeText, nodeFill), greaterThanOrEqualTo(4.5));
        expect(
          _contrastRatio(edgeLabel, edgeLabelBackground),
          greaterThanOrEqualTo(4.5),
        );
        expect(_contrastRatio(nodeStroke, nodeFill), greaterThanOrEqualTo(3));
        expect(
          _contrastRatio(edgeStroke, Color(style.backgroundColor)),
          greaterThanOrEqualTo(3),
        );
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('keeps MermaidStyle identity across ordinary rebuilds', (
      WidgetTester tester,
    ) async {
      late StateSetter rebuild;
      var rebuildCount = 0;
      // The widget must stay non-const: a canonicalized const instance is
      // skipped by updateChild, so State.build would never re-run and the
      // identity assertion would pass vacuously.
      await tester.pumpWidget(
        localizedMaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return Scaffold(
                body: Column(
                  children: [
                    Text('$rebuildCount'),
                    // ignore: prefer_const_constructors
                    MermaidDiagramWidget(code: 'graph TD\nA --> B'),
                  ],
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final styleBefore = tester
          .widget<MermaidDiagram>(find.byType(MermaidDiagram))
          .style;

      rebuild(() => rebuildCount++);
      await tester.pumpAndSettle();
      final styleAfter = tester
          .widget<MermaidDiagram>(find.byType(MermaidDiagram))
          .style;

      expect(identical(styleBefore, styleAfter), isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('refreshes MermaidStyle when the theme changes', (
      WidgetTester tester,
    ) async {
      const lightScheme = ColorScheme.light();
      const darkScheme = ColorScheme.dark();
      const code = 'graph TD\nA --> B';

      Future<void> pumpWith(ColorScheme colorScheme) async {
        await tester.pumpWidget(
          localizedMaterialApp(
            theme: ThemeData(
              platform: TargetPlatform.android,
              colorScheme: colorScheme,
              extensions: <ThemeExtension<dynamic>>[
                classicThemeTokensFrom(colorScheme),
              ],
            ),
            home: const Scaffold(body: MermaidDiagramWidget(code: code)),
          ),
        );
        await tester.pumpAndSettle();
      }

      await pumpWith(lightScheme);
      final lightStyle = tester
          .widget<MermaidDiagram>(find.byType(MermaidDiagram))
          .style!;

      await pumpWith(darkScheme);
      final darkStyle = tester
          .widget<MermaidDiagram>(find.byType(MermaidDiagram))
          .style!;

      expect(identical(lightStyle, darkStyle), isFalse);
      expect(
        lightStyle.backgroundColor,
        lightScheme.surfaceContainerLowest.toARGB32(),
      );
      expect(
        darkStyle.backgroundColor,
        darkScheme.surfaceContainerLowest.toARGB32(),
      );
      expect(lightStyle.themeMode, MermaidThemeMode.light);
      expect(darkStyle.themeMode, MermaidThemeMode.dark);
      expect(tester.takeException(), isNull);
    });
  });
}
