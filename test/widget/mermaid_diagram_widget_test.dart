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
        expect(
          style.defaultNodeStyle.strokeColor,
          themeTokens.border.toARGB32(),
        );
        expect(
          style.defaultNodeStyle.textColor,
          themeTokens.textBase.toARGB32(),
        );
        expect(
          style.defaultEdgeStyle.strokeColor,
          themeTokens.textMuted.toARGB32(),
        );
        expect(
          style.defaultEdgeStyle.labelColor,
          themeTokens.textBase.toARGB32(),
        );
        expect(
          style.defaultEdgeStyle.labelBackgroundColor,
          colorScheme.surfaceContainerLowest.toARGB32(),
        );
        expect(
          _contrastRatio(
            Color(style.defaultNodeStyle.textColor!),
            Color(style.defaultNodeStyle.fillColor!),
          ),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          _contrastRatio(
            Color(style.defaultEdgeStyle.labelColor!),
            Color(style.defaultEdgeStyle.labelBackgroundColor!),
          ),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          _contrastRatio(
            Color(style.defaultEdgeStyle.strokeColor!),
            Color(style.backgroundColor),
          ),
          greaterThanOrEqualTo(3),
        );
        expect(tester.takeException(), isNull);
      }
    });
  });
}
