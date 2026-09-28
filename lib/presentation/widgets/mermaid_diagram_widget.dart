import 'package:flutter/material.dart';
import 'package:flutter_mermaid/flutter_mermaid.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/i18n/l10n_context.dart';
import '../theme/app_shapes.dart';
import '../theme/opencode_theme_presets.dart';

/// Renders Mermaid diagram source code as a visual diagram.
///
/// Falls back to displaying the raw source in a styled code block when
/// the diagram cannot be parsed or rendered.
class MermaidDiagramWidget extends StatelessWidget {
  const MermaidDiagramWidget({
    super.key,
    required this.code,
    this.onCopySource,
  });

  /// The Mermaid diagram source text.
  final String code;

  /// Called when the user taps the copy source action.
  final VoidCallback? onCopySource;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: AppShapes.borderMedium,
        side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(context, colorScheme),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: _buildDiagram(context, colorScheme),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ColorScheme colorScheme) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 4),
      child: Row(
        children: [
          Icon(
            Symbols.account_tree,
            size: 18,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Text(
            l10n.mermaidDiagramLabel,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const Spacer(),
          if (onCopySource != null)
            IconButton(
              icon: Icon(
                Symbols.content_copy,
                size: 18,
                color: colorScheme.onSurfaceVariant,
              ),
              onPressed: onCopySource,
              tooltip: l10n.mermaidCopySourceTooltip,
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }

  Widget _buildDiagram(BuildContext context, ColorScheme colorScheme) {
    return ClipRRect(
      borderRadius: AppShapes.borderSmall,
      child: Container(
        constraints: const BoxConstraints(minHeight: 100),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLowest,
          borderRadius: AppShapes.borderSmall,
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 200),
            child: MermaidDiagram(
              code: code,
              style: _resolveMermaidStyle(context),
              errorBuilder: (ctx, error) =>
                  _buildFallbackCodeView(ctx),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackCodeView(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: AppShapes.borderSmall,
        border:
            Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: SelectableText(
        code,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
              color: colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
      ),
    );
  }

  /// Resolves Mermaid colors from the active app theme.
  MermaidStyle _resolveMermaidStyle(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final themeTokens =
        theme.extension<OpenCodeThemeTokens>() ??
        classicThemeTokensFrom(colorScheme);
    final diagramBackground = colorScheme.surfaceContainerLowest;

    return MermaidStyle(
      backgroundColor: diagramBackground.toARGB32(),
      defaultNodeStyle: NodeStyle(
        fillColor: themeTokens.surfaceRaised.toARGB32(),
        strokeColor: themeTokens.border.toARGB32(),
        textColor: themeTokens.textBase.toARGB32(),
      ),
      defaultEdgeStyle: EdgeStyle(
        strokeColor: themeTokens.textMuted.toARGB32(),
        labelColor: themeTokens.textBase.toARGB32(),
        labelBackgroundColor: diagramBackground.toARGB32(),
      ),
      themeMode: theme.brightness == Brightness.dark
          ? MermaidThemeMode.dark
          : MermaidThemeMode.light,
    );
  }
}
