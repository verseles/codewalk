import 'dart:async';

import 'package:flutter/material.dart';

/// A small reusable pointer region that unifies secondary-click and
/// long-press handling for context menus.
///
/// It forwards the global position and whether haptic feedback was already
/// requested, so the presenter can decide positioning and haptics exactly
/// once. Keyboard and semantic entry points are intentionally left to the
/// focus owner, which can call the same presenter with the widget center.
class ContextMenuRegion extends StatelessWidget {
  const ContextMenuRegion({
    super.key,
    required this.onOpen,
    required this.child,
  });

  /// Called with the global position of the pointer or long-press, and
  /// whether the caller already performed haptic feedback.
  final Future<void> Function(Offset globalPosition, {required bool haptic}) onOpen;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onSecondaryTapUp: (details) => unawaited(
        onOpen(details.globalPosition, haptic: false),
      ),
      onLongPressStart: (details) => unawaited(
        onOpen(details.globalPosition, haptic: true),
      ),
      child: child,
    );
  }
}

/// Helper to obtain a centered global position for keyboard/semantic triggers.
Offset contextMenuCenterPosition(BuildContext context) {
  final renderObject = context.findRenderObject();
  if (renderObject is RenderBox) {
    return renderObject.localToGlobal(renderObject.size.center(Offset.zero));
  }
  return Offset.zero;
}
