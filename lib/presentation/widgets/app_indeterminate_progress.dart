import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../l10n/generated/app_localizations.dart';
import '../theme/app_animations.dart';

/// Shared stepped clock for bounded desktop indeterminate indicators.
///
/// One `Timer` for the whole app, ref-counted by mounted indicators. No
/// vsync ticker is ever scheduled by this clock, so visible indicators cost
/// ~8 wakeups/s instead of 60/s. Never wrap a thin small ring in its own
/// `RepaintBoundary` (it rasterizes into an isolated layer and aliases);
/// this clock exists precisely so isolation is unnecessary.
class AppIndeterminateClock {
  AppIndeterminateClock._();

  static final AppIndeterminateClock instance = AppIndeterminateClock._();

  final ValueNotifier<int> tick = ValueNotifier<int>(0);

  int _refCount = 0;
  Timer? _timer;

  void acquire() {
    if (_refCount++ == 0) {
      _timer = Timer.periodic(AppAnimations.indeterminateStep, (_) {
        tick.value++;
      });
    }
  }

  void release() {
    if (_refCount > 0 && --_refCount == 0) {
      _timer?.cancel();
      _timer = null;
    }
  }

  @visibleForTesting
  void resetForTest() {
    _timer?.cancel();
    _timer = null;
    _refCount = 0;
    tick.value = 0;
  }
}

String _progressLabel(BuildContext context) =>
    Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    )?.chatMessageToolStatusInProgress ??
    'In progress';

/// App-global indeterminate progress indicator.
///
/// Behavior matrix:
/// - Reduced motion: static icon (ring) or static bar (linear), zero ticks.
/// - Desktop + motion on: slots at or below
///   [AppAnimations.compactIndicatorSize] render the static glyph; larger
///   slots render a stepped determinate ring driven by
///   [AppIndeterminateClock] (~8 Hz, no vsync ticker).
/// - Mobile/web + motion on: native indeterminate Material indicators.
class AppIndeterminateRing extends StatefulWidget {
  const AppIndeterminateRing({
    super.key,
    this.size = 36,
    this.strokeWidth = 2,
    this.color,
    this.semanticsLabel,
  });

  final double size;
  final double strokeWidth;
  final Color? color;
  final String? semanticsLabel;

  @override
  State<AppIndeterminateRing> createState() => _AppIndeterminateRingState();
}

class _AppIndeterminateRingState extends State<AppIndeterminateRing> {
  bool _subscribed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncSubscription();
  }

  @override
  void didUpdateWidget(covariant AppIndeterminateRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncSubscription();
  }

  void _syncSubscription() {
    final want =
        AppAnimations.boundedIndeterminate(context) &&
        widget.size > AppAnimations.compactIndicatorSize &&
        TickerMode.valuesOf(context).enabled;
    if (want && !_subscribed) {
      AppIndeterminateClock.instance.acquire();
      _subscribed = true;
    } else if (!want && _subscribed) {
      AppIndeterminateClock.instance.release();
      _subscribed = false;
    }
  }

  @override
  void dispose() {
    if (_subscribed) {
      AppIndeterminateClock.instance.release();
      _subscribed = false;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    final label = widget.semanticsLabel ?? _progressLabel(context);
    if (!AppAnimations.enabled(context)) {
      return _staticRing(color, label);
    }
    if (!AppAnimations.boundedIndeterminate(context)) {
      return Semantics(
        label: label,
        child: SizedBox.square(
          dimension: widget.size,
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: widget.strokeWidth,
              color: color,
            ),
          ),
        ),
      );
    }
    if (widget.size <= AppAnimations.compactIndicatorSize) {
      return _staticRing(color, label);
    }
    if (!TickerMode.valuesOf(context).enabled) {
      return Semantics(
        label: label,
        child: SizedBox.square(
          dimension: widget.size,
          child: Center(
            child: ExcludeSemantics(
              child: CircularProgressIndicator(
                value: 1 / AppAnimations.indeterminateSteps,
                strokeWidth: widget.strokeWidth,
                color: color,
              ),
            ),
          ),
        ),
      );
    }
    return Semantics(
      label: label,
      child: SizedBox.square(
        dimension: widget.size,
        child: Center(
          child: ValueListenableBuilder<int>(
            valueListenable: AppIndeterminateClock.instance.tick,
            builder: (context, tick, _) {
              return ExcludeSemantics(
                child: CircularProgressIndicator(
                  value:
                      ((tick % AppAnimations.indeterminateSteps) + 1) /
                      AppAnimations.indeterminateSteps,
                  strokeWidth: widget.strokeWidth,
                  color: color,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _staticRing(Color color, String label) {
    return Semantics(
      label: label,
      child: Icon(Symbols.progress_activity, size: widget.size, color: color),
    );
  }
}

/// App-global indeterminate linear progress bar.
///
/// Same behavior matrix as [AppIndeterminateRing]: reduced motion renders a
/// static bar, desktop steps a determinate fill at ~8 Hz, mobile/web keeps
/// the native indeterminate sweep.
class AppIndeterminateBar extends StatefulWidget {
  const AppIndeterminateBar({
    super.key,
    this.minHeight = 3,
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

class _AppIndeterminateBarState extends State<AppIndeterminateBar> {
  bool _subscribed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncSubscription();
  }

  @override
  void didUpdateWidget(covariant AppIndeterminateBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncSubscription();
  }

  void _syncSubscription() {
    final want =
        AppAnimations.boundedIndeterminate(context) &&
        TickerMode.valuesOf(context).enabled;
    if (want && !_subscribed) {
      AppIndeterminateClock.instance.acquire();
      _subscribed = true;
    } else if (!want && _subscribed) {
      AppIndeterminateClock.instance.release();
      _subscribed = false;
    }
  }

  @override
  void dispose() {
    if (_subscribed) {
      AppIndeterminateClock.instance.release();
      _subscribed = false;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    final label = widget.semanticsLabel ?? _progressLabel(context);
    if (!AppAnimations.boundedIndeterminate(context)) {
      if (!AppAnimations.enabled(context)) {
        return Semantics(
          label: label,
          child: ExcludeSemantics(
            child: LinearProgressIndicator(
              value: 0.35,
              minHeight: widget.minHeight,
              color: color,
              backgroundColor: widget.backgroundColor,
            ),
          ),
        );
      }
      return Semantics(
        label: label,
        child: LinearProgressIndicator(
          minHeight: widget.minHeight,
          color: color,
          backgroundColor: widget.backgroundColor,
        ),
      );
    }
    if (!TickerMode.valuesOf(context).enabled) {
      return Semantics(
        label: label,
        child: ExcludeSemantics(
          child: LinearProgressIndicator(
            value: 0.35,
            minHeight: widget.minHeight,
            color: color,
            backgroundColor: widget.backgroundColor,
          ),
        ),
      );
    }
    return Semantics(
      label: label,
      child: ValueListenableBuilder<int>(
        valueListenable: AppIndeterminateClock.instance.tick,
        builder: (context, tick, _) {
          return ExcludeSemantics(
            child: LinearProgressIndicator(
              value:
                  ((tick % AppAnimations.indeterminateSteps) + 1) /
                  AppAnimations.indeterminateSteps,
              minHeight: widget.minHeight,
              color: color,
              backgroundColor: widget.backgroundColor,
            ),
          );
        },
      ),
    );
  }
}
