import 'dart:async';
import 'dart:ui' show SemanticsRole;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../l10n/generated/v2_localizations.dart';

/// Indeterminate progress that never holds a desktop GPU awake (#117,
/// ADR-056), like the retained reference's:
/// - reduced motion: a static glyph or bar on every platform;
/// - Linux, macOS and Windows: slots of at most [compactSize] show a static
///   glyph, larger ones advance in discrete [step]s from one shared timer,
///   without a vsync ticker;
/// - Android, iOS and the web: the native indeterminate animation.
abstract final class AppIndeterminate {
  /// About 8 steps a second.
  static const step = Duration(milliseconds: 125);

  /// Phases of one revolution or sweep.
  static const steps = 12;

  /// Thin rings alias at this size and below, so they stay static.
  static const compactSize = 20.0;

  /// Whether animations may play here.
  static bool motion(BuildContext context) =>
      !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);

  /// Whether this platform uses the bounded, stepped form.
  static bool bounded(BuildContext context) =>
      motion(context) &&
      !kIsWeb &&
      switch (defaultTargetPlatform) {
        TargetPlatform.linux ||
        TargetPlatform.macOS ||
        TargetPlatform.windows => true,
        _ => false,
      };
}

/// One timer for every stepped indicator, running only while one is shown.
final class AppIndeterminateClock {
  AppIndeterminateClock._();

  static final instance = AppIndeterminateClock._();

  final tick = ValueNotifier<int>(0);
  int _users = 0;
  Timer? _timer;

  void acquire() {
    if (_users++ == 0) {
      _timer = Timer.periodic(AppIndeterminate.step, (_) => tick.value++);
    }
  }

  void release() {
    if (_users > 0 && --_users == 0) {
      _timer?.cancel();
      _timer = null;
    }
  }

  @visibleForTesting
  bool get running => _timer != null;
}

String _label(BuildContext context, String? label) =>
    label ??
    Localizations.of<V2Localizations>(
      context,
      V2Localizations,
    )?.chatMessageToolStatusInProgress ??
    'In progress';

/// Subscribes its state to the shared clock while it needs steps.
mixin _Stepped<T extends StatefulWidget> on State<T> {
  bool _subscribed = false;

  bool get wantsSteps;

  void _sync() {
    final want = wantsSteps && TickerMode.valuesOf(context).enabled;
    if (want && !_subscribed) {
      AppIndeterminateClock.instance.acquire();
    } else if (!want && _subscribed) {
      AppIndeterminateClock.instance.release();
    }
    _subscribed = want;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant T oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    if (_subscribed) AppIndeterminateClock.instance.release();
    _subscribed = false;
    super.dispose();
  }

  /// The fill of the current step, from one step to a whole turn.
  double _value(int tick) =>
      (tick % AppIndeterminate.steps + 1) / AppIndeterminate.steps;
}

/// A ring that is busy for an unknown time.
class AppIndeterminateRing extends StatefulWidget {
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
  State<AppIndeterminateRing> createState() => _AppIndeterminateRingState();
}

class _AppIndeterminateRingState extends State<AppIndeterminateRing>
    with _Stepped {
  @override
  bool get wantsSteps =>
      AppIndeterminate.bounded(context) &&
      widget.size > AppIndeterminate.compactSize;

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    final label = _label(context, widget.semanticsLabel);
    Widget slot(Widget child) => Semantics(
      label: label,
      role: SemanticsRole.loadingSpinner,
      child: SizedBox.square(
        dimension: widget.size,
        child: Center(child: child),
      ),
    );
    final bounded = AppIndeterminate.bounded(context);
    if (!AppIndeterminate.motion(context) ||
        (bounded && widget.size <= AppIndeterminate.compactSize)) {
      return slot(
        ExcludeSemantics(
          child: Icon(
            Symbols.progress_activity,
            size: widget.size,
            color: color,
          ),
        ),
      );
    }
    if (!bounded) {
      return slot(
        ExcludeSemantics(
          child: CircularProgressIndicator(
            strokeWidth: widget.strokeWidth,
            color: color,
          ),
        ),
      );
    }
    Widget paint(int tick) => ExcludeSemantics(
      child: CircularProgressIndicator(
        value: _value(tick),
        strokeWidth: widget.strokeWidth,
        color: color,
      ),
    );
    if (!_subscribed) return slot(paint(0));
    return slot(
      ValueListenableBuilder<int>(
        valueListenable: AppIndeterminateClock.instance.tick,
        builder: (context, tick, _) => paint(tick),
      ),
    );
  }
}

/// A bar that is busy for an unknown time.
class AppIndeterminateBar extends StatefulWidget {
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
  State<AppIndeterminateBar> createState() => _AppIndeterminateBarState();
}

class _AppIndeterminateBarState extends State<AppIndeterminateBar>
    with _Stepped {
  @override
  bool get wantsSteps => AppIndeterminate.bounded(context);

  @override
  Widget build(BuildContext context) {
    final label = _label(context, widget.semanticsLabel);
    Widget bar(double? value) => Semantics(
      label: label,
      role: SemanticsRole.loadingSpinner,
      child: ExcludeSemantics(
        child: LinearProgressIndicator(
          value: value,
          minHeight: widget.minHeight,
          color: widget.color,
          backgroundColor: widget.backgroundColor,
        ),
      ),
    );
    if (!AppIndeterminate.motion(context)) return bar(0.35);
    if (!AppIndeterminate.bounded(context)) return bar(null);
    if (!_subscribed) return bar(_value(0));
    return ValueListenableBuilder<int>(
      valueListenable: AppIndeterminateClock.instance.tick,
      builder: (context, tick, _) => bar(_value(tick)),
    );
  }
}
