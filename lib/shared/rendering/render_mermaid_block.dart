import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mermaid/flutter_mermaid.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../l10n/l10n_context.dart';
import '../theme/app_shapes.dart';
import '../theme/opencode_theme_presets.dart';

/// Renders Mermaid diagram source as a visual diagram (V2, no legacy imports).
///
/// Falls back to styled raw source when the diagram cannot be parsed.
/// `flutter_mermaid` 0.1.0 is pure Dart/CustomPainter with no platform
/// plugins, safe for Android/Linux MVP.
class RenderMermaidBlock extends StatefulWidget {
  const RenderMermaidBlock({super.key, required this.code, this.onCopySource});

  final String code;
  final VoidCallback? onCopySource;

  @override
  State<RenderMermaidBlock> createState() => _RenderMermaidBlockState();
}

class _RenderMermaidBlockState extends State<RenderMermaidBlock> {
  late MermaidStyle _mermaidStyle;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _mermaidStyle = _resolveMermaidStyle(context);
  }

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
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
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
    final l10n = context.v2L10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 4),
      child: Row(
        children: [
          Icon(Symbols.account_tree, size: 18, color: colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            l10n.mermaidDiagramLabel,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(
              Symbols.content_copy,
              size: 18,
              color: colorScheme.onSurfaceVariant,
            ),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: widget.code));
              widget.onCopySource?.call();
            },
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
              code: widget.code,
              style: _mermaidStyle,
              errorBuilder: (ctx, error) => _buildFallbackCodeView(context),
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
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: SelectableText(
        widget.code,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          fontFamily: 'monospace',
          color: colorScheme.onSurfaceVariant,
          height: 1.5,
        ),
      ),
    );
  }

  MermaidStyle _resolveMermaidStyle(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final themeTokens =
        theme.extension<OpenCodeThemeTokens>() ??
        classicThemeTokensFrom(colorScheme);
    final diagramBackground = colorScheme.surfaceContainerLowest;
    final nodeFill = themeTokens.surfaceRaised;
    final nodeText = _colorWithMinimumContrast(
      preferred: themeTokens.textBase,
      fallbacks: <Color>[colorScheme.onSurface, colorScheme.onSurfaceVariant],
      background: nodeFill,
      minimumContrast: 4.5,
    );
    final nodeStroke = _colorWithMinimumContrast(
      preferred: themeTokens.border,
      fallbacks: <Color>[
        themeTokens.textMuted,
        themeTokens.textBase,
        colorScheme.primary,
      ],
      background: nodeFill,
      minimumContrast: 3,
    );
    final edgeStroke = _colorWithMinimumContrast(
      preferred: themeTokens.textMuted,
      fallbacks: <Color>[
        themeTokens.textBase,
        themeTokens.border,
        colorScheme.primary,
      ],
      background: diagramBackground,
      minimumContrast: 3,
    );
    final edgeLabel = _colorWithMinimumContrast(
      preferred: themeTokens.textBase,
      fallbacks: <Color>[colorScheme.onSurface, themeTokens.textMuted],
      background: diagramBackground,
      minimumContrast: 4.5,
    );
    return MermaidStyle(
      backgroundColor: diagramBackground.toARGB32(),
      defaultNodeStyle: NodeStyle(
        fillColor: nodeFill.toARGB32(),
        strokeColor: nodeStroke.toARGB32(),
        textColor: nodeText.toARGB32(),
      ),
      defaultEdgeStyle: EdgeStyle(
        strokeColor: edgeStroke.toARGB32(),
        labelColor: edgeLabel.toARGB32(),
        labelBackgroundColor: diagramBackground.toARGB32(),
      ),
      themeMode: theme.brightness == Brightness.dark
          ? MermaidThemeMode.dark
          : MermaidThemeMode.light,
    );
  }

  Color _colorWithMinimumContrast({
    required Color preferred,
    required List<Color> fallbacks,
    required Color background,
    required double minimumContrast,
  }) {
    final candidates = <Color>[
      preferred,
      ...fallbacks,
      Colors.black,
      Colors.white,
    ];
    for (final candidate in candidates) {
      final opaque = Color.alphaBlend(candidate, background);
      if (_contrastRatio(opaque, background) >= minimumContrast) {
        return opaque;
      }
    }
    return Colors.black;
  }

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
}
