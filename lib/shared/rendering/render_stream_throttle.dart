import 'dart:async';

import 'package:flutter/widgets.dart';

/// Trailing-edge throttle for streaming rich re-parses (V2, no legacy import).
///
/// Matches the legacy `_StreamingMarkdownThrottle` contract: desktop 120ms,
/// mobile/web 48ms, no throttle once `complete == true`, flush on completion.
class RenderStreamThrottle extends StatefulWidget {
  const RenderStreamThrottle({
    super.key,
    required this.text,
    required this.complete,
    required this.isDesktop,
    required this.builder,
  });

  final String text;
  final bool complete;
  final bool isDesktop;
  final Widget Function(String renderedText) builder;

  static Duration windowFor(bool isDesktop) => isDesktop
      ? const Duration(milliseconds: 120)
      : const Duration(milliseconds: 48);

  @override
  State<RenderStreamThrottle> createState() => _RenderStreamThrottleState();
}

class _RenderStreamThrottleState extends State<RenderStreamThrottle> {
  late String _renderedText = widget.text;
  Timer? _timer;

  @override
  void didUpdateWidget(covariant RenderStreamThrottle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text == _renderedText) return;
    if (widget.complete || widget.text == oldWidget.text) {
      _timer?.cancel();
      _timer = null;
      setState(() => _renderedText = widget.text);
      return;
    }
    _schedule();
  }

  void _schedule() {
    if (widget.text == _renderedText) return;
    _timer ??= Timer(RenderStreamThrottle.windowFor(widget.isDesktop), () {
      _timer = null;
      if (!mounted || widget.text == _renderedText) return;
      setState(() => _renderedText = widget.text);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(_renderedText);
}
