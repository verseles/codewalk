import '../../core/i18n/l10n_context.dart';
import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';

import '../theme/app_shapes.dart';

/// Shared showcase wrapper for the first-use chat tour.
///
/// The default package tooltip actions use plain containers, which can drift
/// away from the app's MD3 button treatment and contrast rules. This wrapper
/// keeps every tour step on the same surface, shape, and action hierarchy.
class ChatTourShowcase extends StatelessWidget {
  const ChatTourShowcase({
    super.key,
    required this.showcaseKey,
    required this.targetKey,
    required this.child,
    required this.title,
    required this.description,
    required this.tooltipPosition,
    this.includePrevious = false,
    this.showSkip = true,
    this.primaryActionLabel,
    this.onPrimaryAction,
    this.onPreviousAction,
    this.onSkipAction,
    this.targetPadding = const EdgeInsets.all(6),
    this.targetBorderRadius,
    this.disableDefaultTargetGestures = true,
  });

  final GlobalKey showcaseKey;
  final GlobalKey targetKey;
  final Widget child;
  final String title;
  final String description;
  final TooltipPosition tooltipPosition;
  final bool includePrevious;
  final bool showSkip;
  final String? primaryActionLabel;
  final VoidCallback? onPrimaryAction;
  final VoidCallback? onPreviousAction;
  final VoidCallback? onSkipAction;
  final EdgeInsets targetPadding;
  final BorderRadius? targetBorderRadius;
  final bool disableDefaultTargetGestures;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Showcase.withWidget(
      key: showcaseKey,
      tooltipPosition: tooltipPosition,
      overlayColor: colorScheme.scrim,
      overlayOpacity: isDark ? 0.74 : 0.58,
      targetPadding: targetPadding,
      targetBorderRadius: targetBorderRadius ?? AppShapes.borderLarge,
      targetTooltipGap: 12,
      disableDefaultTargetGestures: disableDefaultTargetGestures,
      onBarrierClick: () => ShowcaseView.get().dismiss(),
      container: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 336),
        child: Material(
          elevation: 3,
          color: colorScheme.surfaceContainerHigh,
          surfaceTintColor: colorScheme.surfaceTint,
          shadowColor: colorScheme.shadow.withValues(
            alpha: isDark ? 0.42 : 0.18,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: AppShapes.borderExtraLarge,
            side: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.72),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: [
                    if (showSkip)
                      TextButton(
                        onPressed:
                            onSkipAction ?? () => ShowcaseView.get().dismiss(),
                        style: TextButton.styleFrom(
                          foregroundColor: colorScheme.onSurfaceVariant,
                        ),
                        child: Text(context.l10n.tourSkip),
                      ),
                    if (includePrevious)
                      TextButton(
                        onPressed:
                            onPreviousAction ??
                            () => ShowcaseView.get().previous(),
                        child: Text(context.l10n.permissionBack),
                      ),
                    FilledButton(
                      onPressed:
                          onPrimaryAction ??
                          () => ShowcaseView.get().next(force: true),
                      child: Text(
                        primaryActionLabel ?? context.l10n.chatActionNext,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      child: KeyedSubtree(key: targetKey, child: child),
    );
  }
}
