import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../shared/l10n/l10n_context.dart';
import 'app_preferences_controller.dart';

/// The conversations [pane] beside the [chat]. A [resizable] pane (expanded
/// windows and wider) has a handle that resizes it at once within 160–500;
/// the width is saved when the drag ends and a double tap restores the
/// default. Otherwise (a medium window) it keeps 260 behind a plain divider.
/// The chat keeps at least 320 by narrowing the shown pane, never the saved
/// width.
class ResizableSessionPane extends StatefulWidget {
  const ResizableSessionPane({
    super.key,
    required this.preferences,
    required this.resizable,
    required this.pane,
    required this.chat,
  });

  final AppPreferencesController? preferences;
  final bool resizable;
  final Widget pane;
  final Widget chat;

  /// What the chat keeps beside the pane.
  static const chatMin = 320.0;

  /// The pane of a medium window.
  static const fixedWidth = 260.0;
  static const _handle = 8.0;

  @override
  State<ResizableSessionPane> createState() => _ResizableSessionPaneState();
}

class _ResizableSessionPaneState extends State<ResizableSessionPane> {
  /// The width while a drag is in progress, before it is saved.
  double? _dragging;

  @override
  void didUpdateWidget(ResizableSessionPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A window narrowed to medium mid-drag drops the unsaved width.
    if (!widget.resizable) _dragging = null;
  }

  double get _saved =>
      widget.preferences?.sessionPaneWidth ??
      AppPreferencesController.sessionPaneDefault;

  void _drag(DragUpdateDetails details) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final delta = rtl ? -details.delta.dx : details.delta.dx;
    setState(() {
      _dragging = ((_dragging ?? _saved) + delta).clamp(
        AppPreferencesController.sessionPaneMin,
        AppPreferencesController.sessionPaneMax,
      );
    });
  }

  void _end() {
    final width = _dragging;
    if (width == null) return;
    widget.preferences?.setSessionPaneWidth(width);
    setState(() => _dragging = null);
  }

  void _reset() {
    setState(() => _dragging = null);
    widget.preferences?.setSessionPaneWidth(null);
  }

  static double _bounded(double width) => width.clamp(
    AppPreferencesController.sessionPaneMin,
    AppPreferencesController.sessionPaneMax,
  );

  void _step(double delta) {
    widget.preferences?.setSessionPaneWidth(_saved + delta);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final resizable = widget.resizable;
      final divider = resizable ? ResizableSessionPane._handle : 1.0;
      final room = box.maxWidth - ResizableSessionPane.chatMin - divider;
      final width = min(
        resizable ? _dragging ?? _saved : ResizableSessionPane.fixedWidth,
        max(AppPreferencesController.sessionPaneMin, room),
      );
      return Row(
        children: [
          SizedBox(
            key: const ValueKey('workspace-sidebar'),
            width: width,
            child: widget.pane,
          ),
          if (resizable)
            _handleFor(context, width)
          else
            const VerticalDivider(width: 1),
          Expanded(child: widget.chat),
        ],
      );
    },
  );

  Widget _handleFor(BuildContext context, double width) => Semantics(
    label: context.v2L10n.chatConversationsPane,
    value: '${width.round()}',
    increasedValue: '${_bounded(_saved + 16).round()}',
    decreasedValue: '${_bounded(_saved - 16).round()}',
    onIncrease: () => _step(16),
    onDecrease: () => _step(-16),
    child: MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        key: const ValueKey('workspace-sidebar-handle'),
        behavior: HitTestBehavior.opaque,
        // The handle follows the pointer from where it went down.
        dragStartBehavior: DragStartBehavior.down,
        onHorizontalDragUpdate: _drag,
        onHorizontalDragEnd: (_) => _end(),
        onHorizontalDragCancel: _end,
        onDoubleTap: _reset,
        child: SizedBox(
          width: ResizableSessionPane._handle,
          child: Center(
            child: VerticalDivider(
              width: 1,
              color: _dragging == null
                  ? null
                  : Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ),
    ),
  );
}
