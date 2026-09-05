import 'package:flutter/material.dart';

import '../theme/app_animations.dart';

/// Skeleton shimmer placeholder shown during initial chat loading.
/// Renders placeholder message rows with a horizontal gradient sweep,
/// similar to common content-loading patterns.
/// Degrades to static placeholders when animations are disabled.
class ChatSkeletonShimmer extends StatefulWidget {
  const ChatSkeletonShimmer({super.key});

  @override
  State<ChatSkeletonShimmer> createState() => _ChatSkeletonShimmerState();
}

class _ChatSkeletonShimmerState extends State<ChatSkeletonShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  // Placeholder row specs: (alignLeft, widthFraction)
  static const _rows = <(bool, double)>[
    (false, 0.65),
    (true, 0.80),
    (false, 0.50),
    (true, 0.72),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppAnimations.enabled(context)) {
      _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = Theme.of(context).colorScheme.surfaceContainerHighest;
    final animate = AppAnimations.enabled(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        // Issue #176: isolate the shimmer animation repaints.
        child: RepaintBoundary(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (alignLeft, widthFrac) in _rows) ...[
                Align(
                  alignment: alignLeft
                      ? Alignment.centerLeft
                      : Alignment.centerRight,
                  child: animate
                      ? AnimatedBuilder(
                          animation: _controller,
                          builder: (context, child) {
                            return ShaderMask(
                              shaderCallback: (bounds) {
                                final dx = _controller.value * 2 - 0.5;
                                return LinearGradient(
                                  begin: Alignment(dx - 0.3, 0),
                                  end: Alignment(dx + 0.3, 0),
                                  colors: [
                                    baseColor,
                                    baseColor.withValues(alpha: 0.4),
                                    baseColor,
                                  ],
                                  stops: const [0.0, 0.5, 1.0],
                                ).createShader(bounds);
                              },
                              blendMode: BlendMode.srcIn,
                              child: child,
                            );
                          },
                          child: _SkeletonRow(
                            widthFraction: widthFrac,
                            color: baseColor,
                          ),
                        )
                      : _SkeletonRow(
                          widthFraction: widthFrac,
                          color: baseColor,
                        ),
                ),
                const SizedBox(height: 16),
              ],
            ],
          ),
        ),
        ),
      ),
    );
  }
}

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow({required this.widthFraction, required this.color});

  final double widthFraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFraction,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
