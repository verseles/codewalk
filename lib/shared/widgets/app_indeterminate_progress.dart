import 'dart:ui' show SemanticsRole;

// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../l10n/generated/v2_localizations.dart';

/// Indeterminate progress across all platforms (ADR-062, superseding ADR-056):
/// - reduced motion: a static glyph or bar on every platform;
/// - motion enabled: the native smooth indeterminate animation on every
///   platform (paused automatically when hidden by [TickerMode]).
abstract final class AppIndeterminate {
  /// Whether animations may play here.
  static bool motion(BuildContext context) =>
      !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);
}

String _label(BuildContext context, String? label) =>
    label ??
    Localizations.of<V2Localizations>(
      context,
      V2Localizations,
    )?.chatMessageToolStatusInProgress ??
    'In progress';

/// A ring that is busy for an unknown time.
class AppIndeterminateRing extends StatelessWidget {
  const AppIndeterminateRing({
    super.key,
    this.size = 36,
    this.strokeWidth = 2,
    this.color,
    this.semanticsLabel,
  });

  /// The square slot the ring fills.
  final double size;
  final double strokeWidth;
  final Color? color;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? Theme.of(context).colorScheme.primary;
    final label = _label(context, semanticsLabel);
    final child = AppIndeterminate.motion(context)
        ? CircularProgressIndicator(strokeWidth: strokeWidth, color: color)
        : Icon(Symbols.progress_activity, size: size, color: color);
    return Semantics(
      label: label,
      role: SemanticsRole.loadingSpinner,
      child: SizedBox.square(
        dimension: size,
        child: Center(child: ExcludeSemantics(child: child)),
      ),
    );
  }
}

/// A bar that is busy for an unknown time.
class AppIndeterminateBar extends StatelessWidget {
  const AppIndeterminateBar({
    super.key,
    this.minHeight,
    this.color,
    this.backgroundColor,
    this.semanticsLabel,
  });

  final double? minHeight;
  final Color? color;
  final Color? backgroundColor;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final label = _label(context, semanticsLabel);
    return Semantics(
      label: label,
      role: SemanticsRole.loadingSpinner,
      child: ExcludeSemantics(
        child: LinearProgressIndicator(
          value: AppIndeterminate.motion(context) ? null : 0.35,
          minHeight: minHeight,
          color: color,
          backgroundColor: backgroundColor,
        ),
      ),
    );
  }
}
