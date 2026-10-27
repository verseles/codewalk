import 'dart:math';

import 'package:flutter/material.dart';

import '../../shared/l10n/l10n_context.dart';
import 'session_timeline_projection.dart';

/// The body of a reasoning row, like the retained reference's: a few lines
/// in a bounded area, more on demand, and while the reasoning streams the
/// area keeps its newest lines in view without moving the timeline.
class SessionReasoningBody extends StatefulWidget {
  const SessionReasoningBody({
    super.key,
    required this.text,
    required this.complete,
    required this.child,
  });

  /// The lines the area shows, closed and opened.
  static const closedLines = 4;
  static const openLines = 12;

  /// The reasoning text; a change to it while it streams is followed.
  final String text;

  /// Whether the reasoning stopped streaming.
  final bool complete;

  /// The rendered reasoning.
  final Widget child;

  @override
  State<SessionReasoningBody> createState() => _SessionReasoningBodyState();
}

class _SessionReasoningBodyState extends State<SessionReasoningBody> {
  final _scroll = ScrollController();
  bool _open = false;

  /// Whether the reasoning was ever taller than the closed area, measured
  /// on the rendered content; once it was, the control stays, so a reasoning
  /// that grows past the limit never switches back and forth.
  bool _overflowed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A new width or text size can make the same text overflow.
    _afterLayout();
  }

  @override
  void didUpdateWidget(covariant SessionReasoningBody old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) _afterLayout();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Once the content is laid out: offers the control if it overflows, and
  /// keeps the newest lines in view while the reasoning streams.
  void _afterLayout() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final end = _scroll.position.maxScrollExtent;
      if (end > 0 && !_overflowed) setState(() => _overflowed = true);
      if (end > 0 && !widget.complete) _scroll.jumpTo(end);
    });
  }

  /// The area's content or size changed, whatever changed it: a narrower
  /// pane, a rotation or a new text size. Only the area's own vertical
  /// scroll counts, not a code block, formula or diagram scrolling sideways
  /// inside it.
  bool _onMetrics(ScrollMetricsNotification notification) {
    if (notification.depth == 0 &&
        notification.metrics.axis == Axis.vertical &&
        notification.metrics.maxScrollExtent > 0 &&
        !_overflowed) {
      setState(() => _overflowed = true);
    }
    return false;
  }

  void _toggle() {
    SessionTimelineScope.maybeOf(context)?.onReaderToggle();
    setState(() => _open = !_open);
    _afterLayout();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.v2L10n;
    final style = Theme.of(context).textTheme.bodyMedium;
    final line =
        MediaQuery.textScalerOf(context).scale(style?.fontSize ?? 14) *
        (style?.height ?? 1.4);
    final lines = _open
        ? SessionReasoningBody.openLines
        : SessionReasoningBody.closedLines;
    final compact = MediaQuery.sizeOf(context).width < 600;
    final area = NotificationListener<ScrollMetricsNotification>(
      onNotification: _onMetrics,
      child: SingleChildScrollView(
        controller: _scroll,
        primary: false,
        child: widget.child,
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: max(1, lines) * line),
          child: _open
              ? Scrollbar(
                  controller: _scroll,
                  thumbVisibility: true,
                  child: area,
                )
              : area,
        ),
        if (_overflowed)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              key: const ValueKey('reasoning-toggle'),
              onPressed: _toggle,
              child: Text(
                _open
                    ? (compact
                          ? l10n.chatMessageShowLessCompact
                          : l10n.chatMessageShowLess)
                    : (compact
                          ? l10n.chatMessageShowMoreCompact
                          : l10n.chatMessageShowMore),
              ),
            ),
          ),
      ],
    );
  }
}
