import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../l10n/l10n_context.dart';
import '../theme/app_shapes.dart';
import '../widgets/app_snack_bar.dart';

/// Renders a LaTeX math expression using flutter_math_fork (pure Dart
/// KaTeX port). Falls back to a styled raw-source view when parsing fails.
///
/// V2 port of the legacy `MathExpressionWidget` without legacy imports.
/// Uses v2 l10n (`context.v2L10n`) and shared [AppShapes].
class RenderMathExpression extends StatelessWidget {
  const RenderMathExpression({
    super.key,
    required this.expression,
    required this.isBlock,
    this.textStyle,
  });

  final String expression;
  final bool isBlock;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    if (isBlock) return _buildBlock(context);
    return _buildInline(context);
  }

  Widget _buildInline(BuildContext context) {
    final theme = Theme.of(context);
    final style = _resolveStyle(theme);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow.withValues(alpha: 0.5),
        borderRadius: AppShapes.borderSmall,
      ),
      child: Math.tex(
        expression,
        mathStyle: MathStyle.text,
        textStyle: style,
        onErrorFallback: (err) => _buildInlineFallback(
          context,
          style.copyWith(color: colorScheme.error),
        ),
      ),
    );
  }

  Widget _buildBlock(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final style = _resolveStyle(theme);
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
            child: _buildMathContent(context, style, colorScheme),
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
          Icon(Symbols.function, size: 18, color: colorScheme.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              l10n.mathExpressionLabel,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            key: const ValueKey<String>('math_expression_copy_button'),
            icon: const Icon(Symbols.content_copy, size: 18),
            tooltip: l10n.commonCopiedToClipboard,
            visualDensity: VisualDensity.compact,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: expression));
              if (Theme.of(context).platform == TargetPlatform.android) {
                return;
              }
              final messenger = ScaffoldMessenger.maybeOf(context);
              messenger?.hideCurrentSnackBar();
              showAppSnackBar(messenger, l10n.commonCopiedToClipboard);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMathContent(
    BuildContext context,
    TextStyle style,
    ColorScheme colorScheme,
  ) {
    return ClipRRect(
      borderRadius: AppShapes.borderSmall,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 48),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLowest,
          borderRadius: AppShapes.borderSmall,
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Math.tex(
            expression,
            mathStyle: MathStyle.display,
            textStyle: style,
            onErrorFallback: (err) => _buildBlockFallback(context),
          ),
        ),
      ),
    );
  }

  Widget _buildInlineFallback(BuildContext context, TextStyle style) {
    return SelectableText(
      expression,
      style: style.copyWith(
        fontFamily: 'monospace',
        fontSize: (style.fontSize ?? 14) * 0.85,
      ),
    );
  }

  Widget _buildBlockFallback(BuildContext context) {
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
        expression,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          fontFamily: 'monospace',
          color: colorScheme.onSurfaceVariant,
          height: 1.5,
        ),
      ),
    );
  }

  TextStyle _resolveStyle(ThemeData theme) {
    final base =
        textStyle ??
        theme.textTheme.bodyMedium ??
        const TextStyle(fontSize: 14);
    return base.copyWith(color: theme.colorScheme.onSurface);
  }
}
