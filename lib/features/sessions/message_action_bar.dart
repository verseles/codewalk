import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../shared/l10n/l10n_context.dart';

/// The actions a message bar offers, in the bar's order (#539).
enum MessageActionId {
  copy,
  forward,
  readAloud,
  shareImage,
  undo,
  rewind,
  fork,
}

/// One action of a message's bar (#539). [overflow] ones live in its
/// three-dots menu.
final class MessageAction {
  const MessageAction({
    required this.id,
    required this.label,
    required this.icon,
    required this.onSelected,
    this.overflow = false,
  });

  final MessageActionId id;
  final String label;
  final IconData icon;
  final bool overflow;

  /// Runs the action; [context] is the message's, for any confirmation.
  final void Function(BuildContext context) onSelected;
}

/// What a pointer lands on inside a message (#539).
enum MessagePointerTarget {
  /// A control with a tap of its own: a link, a file path, inline code, a
  /// code block, a chip or a button.
  control,

  /// The message's words, which a long press selects.
  text,

  /// The message's padding, a line's end or its row beside it.
  clean,
}

/// Classifies the point [global] of the message's [content].
@visibleForTesting
MessagePointerTarget classifyMessagePointer(RenderBox content, Offset global) {
  final result = BoxHitTestResult();
  if (!content.hitTest(result, position: content.globalToLocal(global))) {
    return MessagePointerTarget.clean;
  }
  var text = false;
  for (final entry in result.path) {
    final target = entry.target;
    if (target is TextSpan) {
      if (target.recognizer != null) return MessagePointerTarget.control;
      text = true;
    } else if (target is RenderPointerListener && target != content) {
      // Every tappable or scrollable thing inside the message.
      return MessagePointerTarget.control;
    }
  }
  return text ? MessagePointerTarget.text : MessagePointerTarget.clean;
}

/// How long the mouse rests on a message before its bar shows.
const messageBarHoverDelay = Duration(milliseconds: 150);

/// How long the bar stays after the mouse leaves the message and the bar.
const messageBarHideDelay = Duration(milliseconds: 600);

const _barHeight = 48.0;
const _barMargin = 4.0;

/// A long press that answers only where [allow] says so.
class _CleanLongPress extends LongPressGestureRecognizer {
  _CleanLongPress({required this.allow, super.debugOwner})
    : super(
        supportedDevices: const {
          PointerDeviceKind.touch,
          PointerDeviceKind.stylus,
          PointerDeviceKind.invertedStylus,
        },
      );

  final bool Function(Offset global) allow;

  @override
  bool isPointerAllowed(PointerDownEvent event) =>
      super.isPointerAllowed(event) && allow(event.position);
}

class _OpenBarIntent extends Intent {
  const _OpenBarIntent();
}

class _CloseBarIntent extends Intent {
  const _CloseBarIntent();
}

/// Escape on the message or its bar closes the bar, the focus going back
/// to the message from the bar; with no bar, or its menu open, Escape is
/// someone else's.
class _CloseBarAction extends Action<_CloseBarIntent> {
  _CloseBarAction(this._host);

  final _MessageActionHostState _host;

  @override
  bool isEnabled(_CloseBarIntent intent) =>
      _host._portal.isShowing && !_host._menuOpen;

  @override
  Object? invoke(_CloseBarIntent intent) {
    _host._hide(refocus: _host._barHasFocus);
    return null;
  }
}

/// A user's or the agent's message, with always selectable text and its
/// floating action bar (#539).
///
/// A tap with no other function, a long press on a clean area, a secondary
/// click, the Menu key or Shift+F10 opens the bar; on a mouse, resting on
/// the message shows it and leaving hides it after a while. The bar sits
/// half inside, half outside the message's top edge, or its bottom edge
/// when the top has no room. Only one bar shows at a time.
class MessageActionHost extends StatefulWidget {
  const MessageActionHost({
    super.key,
    required this.end,
    required this.constraints,
    required this.actions,
    required this.child,
  });

  /// Whether the message sits at the row's right end (the user's own).
  final bool end;
  final BoxConstraints constraints;

  /// The message's actions, in any order; the bar sorts them.
  final List<MessageAction> actions;
  final Widget child;

  @override
  State<MessageActionHost> createState() => _MessageActionHostState();
}

enum _Edge { top, bottom, pinned }

class _MessageActionHostState extends State<MessageActionHost>
    with AutomaticKeepAliveClientMixin {
  static _MessageActionHostState? _shown;

  final _content = GlobalKey();
  // Inside the message's own repaint boundary: actions run from here, so a
  // share can find the boundary that holds the message alone (#540).
  final _capture = GlobalKey();
  final _link = LayerLink();
  final _portal = OverlayPortalController();
  final _firstButton = FocusNode(debugLabel: 'message bar');
  // Holds the bar's buttons, to tell whether the focus is in the bar.
  final _barFocus = FocusNode(
    debugLabel: 'message bar buttons',
    canRequestFocus: false,
    skipTraversal: true,
  );
  final _messageFocus = FocusNode(debugLabel: 'message');
  bool _highlight = false;
  bool _hasSelection = false;
  bool _pinned = false;
  _Edge _edge = _Edge.top;
  double _pinnedDy = 0;
  Timer? _hoverTimer;
  ValueListenable<bool>? _scrolling;

  // Bar presses wait out a double tap's second tap after a tap opened it,
  // so that tap cannot land on a button by accident.
  Timer? _settling;

  // The mouse is over the bar, which then never hides under it.
  bool _overBar = false;

  // The three-dots menu is open: Escape is its own, and the list keeps the
  // message, whose choice would otherwise be lost.
  bool _menuOpen = false;

  // A check of the bar against the list waits for the end of a frame.
  bool _watching = false;

  // The list's bounds and the hint's side the bar was last built with.
  (Rect, bool)? _built;

  // The press being tracked as a possible tap.
  Offset? _downAt;
  Duration? _downTime;
  bool _downCounts = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final position = Scrollable.maybeOf(context)?.position;
    final scrolling = position?.isScrollingNotifier;
    if (!identical(scrolling, _scrolling)) {
      _scrolling?.removeListener(_scrollChanged);
      _scrolling = scrolling?..addListener(_scrollChanged);
    }
  }

  @override
  bool get wantKeepAlive => _menuOpen;

  @override
  void dispose() {
    _scrolling?.removeListener(_scrollChanged);
    _hoverTimer?.cancel();
    _settling?.cancel();
    if (identical(_shown, this)) _shown = null;
    _firstButton.dispose();
    _barFocus.dispose();
    _messageFocus.dispose();
    super.dispose();
  }

  void _scrollChanged() {
    if (!(_scrolling?.value ?? false)) return;
    // A press that turned into a scroll is no tap.
    _downAt = null;
    _hide();
  }

  /// While the bar shows, the end of each frame checks it against the list
  /// as laid out. Whatever moved or resized the list or the message (a
  /// growing answer, the composer, a side panel), a bar whose edge left the
  /// list goes, and one that stays keeps to the list as it is. Frames come
  /// only when something changes, so a bar at rest costs nothing.
  void _watch() {
    if (_watching) return;
    _watching = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _watching = false;
      if (!mounted || !_portal.isShowing) return;
      _recheck();
      if (_portal.isShowing) _watch();
    });
  }

  void _recheck() {
    final y = _edgeY;
    final viewport = _viewport;
    if (y == null || viewport == null) return;
    // A message the list keeps out of sight, as while its menu is open,
    // has no place on screen.
    if (!y.isFinite || y < viewport.top || y > viewport.bottom) {
      _hide();
    } else if (_built != (viewport, _hintBelow(y, viewport))) {
      setState(() {});
    }
  }

  /// The middle of the bar, which sits on [_edge], in global coordinates.
  double? get _edgeY {
    final box = _contentBox;
    if (box == null) return null;
    final top = box.localToGlobal(Offset.zero).dy;
    return switch (_edge) {
      _Edge.top => top,
      _Edge.bottom => top + box.size.height,
      _Edge.pinned => top + _pinnedDy,
    };
  }

  /// Whether a button's name goes below the bar whose middle is at [y],
  /// for lack of room above it in the list: its gap, its padding and one
  /// line of small text at the current text size.
  bool _hintBelow(double y, Rect viewport) {
    final style = Theme.of(context).textTheme.bodySmall;
    final line =
        MediaQuery.textScalerOf(context).scale(style?.fontSize ?? 12) *
        (style?.height ?? 1.4);
    return y - _barHeight / 2 - (14 + line) < viewport.top;
  }

  Rect? get _viewport {
    final box = Scrollable.maybeOf(context)?.context.findRenderObject();
    return box is RenderBox && box.hasSize && box.attached
        ? box.localToGlobal(Offset.zero) & box.size
        : null;
  }

  bool get _barHasFocus => _barFocus.hasFocus;

  List<MessageAction> get _all =>
      [...widget.actions]..sort((a, b) => a.id.index.compareTo(b.id.index));

  RenderBox? get _contentBox {
    final box = _content.currentContext?.findRenderObject();
    return box is RenderBox && box.hasSize && box.attached ? box : null;
  }

  bool _isClean(Offset global) {
    final box = _contentBox;
    if (box == null) return false;
    return classifyMessagePointer(box, global) == MessagePointerTarget.clean;
  }

  bool _beside(Offset global) {
    final box = _contentBox;
    if (box == null) return false;
    final origin = box.localToGlobal(Offset.zero);
    return !(origin & box.size).contains(global);
  }

  void _show({
    required bool pin,
    Offset? at,
    bool focus = false,
    bool tapped = false,
  }) {
    if (!mounted || _all.isEmpty) return;
    _hoverTimer?.cancel();
    final other = _shown;
    if (other != null && !identical(other, this)) other._hide();
    _shown = this;
    _place(at);
    setState(() => _pinned = _pinned || pin);
    _portal.show();
    _watch();
    _settling?.cancel();
    _settling = tapped
        ? Timer(kDoubleTapTimeout, () {
            if (mounted) setState(() => _settling = null);
          })
        : null;
    if (focus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _firstButton.requestFocus();
      });
    }
  }

  void _hide({bool refocus = false}) {
    _hoverTimer?.cancel();
    // A bar that goes reports no exit of the mouse.
    _overBar = false;
    if (identical(_shown, this)) _shown = null;
    if (!_portal.isShowing) return;
    _portal.hide();
    if (mounted) setState(() => _pinned = false);
    if (refocus && mounted) _messageFocus.requestFocus();
  }

  /// Picks the edge the bar sits on: one whose bar fits in the visible
  /// list, the one away from the finger or pointer that opened it (the top
  /// without one), else near the trigger inside what is visible.
  void _place(Offset? at) {
    final box = _contentBox;
    if (box == null) return;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    final viewport = _viewport ?? Offset.zero & MediaQuery.sizeOf(context);
    const half = _barHeight / 2 + _barMargin;
    bool fits(double y) =>
        y - half >= viewport.top && y + half <= viewport.bottom;
    final top = fits(rect.top);
    final bottom = fits(rect.bottom);
    final away = at != null && at.dy < rect.center.dy;
    if (top && bottom) {
      _edge = away ? _Edge.bottom : _Edge.top;
    } else if (top) {
      _edge = _Edge.top;
    } else if (bottom) {
      _edge = _Edge.bottom;
    } else {
      _edge = _Edge.pinned;
      final wanted = (at?.dy ?? viewport.top + half) - _barHeight;
      final low = viewport.top + half;
      final high = viewport.bottom - half;
      final y = high < low ? low : wanted.clamp(low, high);
      _pinnedDy = y - rect.top;
    }
  }

  void _pointerDown(PointerDownEvent event) {
    _downAt = event.buttons == kPrimaryButton ? event.position : null;
    _downTime = event.timeStamp;
    _downCounts =
        _downAt != null &&
        !_hasSelection &&
        (_beside(event.position) ||
            _contentBox == null ||
            classifyMessagePointer(_contentBox!, event.position) !=
                MessagePointerTarget.control);
  }

  void _pointerMove(PointerMoveEvent event) {
    final downAt = _downAt;
    if (downAt == null) return;
    final slop = event.kind == PointerDeviceKind.mouse
        ? kPrecisePointerHitSlop
        : kTouchSlop;
    // A press that travelled is a drag, even if it comes back.
    if ((event.position - downAt).distance > slop) _downAt = null;
  }

  void _pointerUp(PointerUpEvent event) {
    final downAt = _downAt;
    final downTime = _downTime;
    _downAt = null;
    if (downAt == null || downTime == null || !_downCounts) return;
    final slop = event.kind == PointerDeviceKind.mouse
        ? kPrecisePointerHitSlop
        : kTouchSlop;
    if ((event.position - downAt).distance > slop ||
        event.timeStamp - downTime >= kLongPressTimeout) {
      return;
    }
    // After the tap's own handlers, which may select or clear text.
    scheduleMicrotask(() {
      if (!mounted || _hasSelection) return;
      if (_portal.isShowing && _pinned) {
        _hide();
      } else {
        _show(pin: true, at: event.position, tapped: true);
      }
    });
  }

  void _longPress(LongPressStartDetails details) {
    _downAt = null;
    unawaited(HapticFeedback.selectionClick());
    _show(pin: true, at: details.globalPosition);
  }

  void _hoverEnter(PointerEnterEvent event) {
    if (_pinned || event.buttons != 0) return;
    _hoverTimer?.cancel();
    if (_portal.isShowing) return;
    _hoverTimer = Timer(messageBarHoverDelay, () {
      if (mounted && !_hasSelection) _show(pin: false, at: event.position);
    });
  }

  void _hoverExit(PointerExitEvent event) {
    _hoverTimer?.cancel();
    if (_pinned || !_portal.isShowing) return;
    _hoverTimer = Timer(messageBarHideDelay, () {
      if (mounted && !_pinned) _hide();
    });
  }

  void _selectionChanged(SelectedContent? content) {
    final has = content != null && content.plainText.isNotEmpty;
    _hasSelection = has;
    if (has) _hide();
  }

  void _run(MessageAction action) {
    if (_settling != null) return;
    _hide(refocus: _barHasFocus);
    action.onSelected(_capture.currentContext ?? context);
  }

  Future<void> _more(BuildContext button, List<MessageAction> overflow) async {
    final box = button.findRenderObject() as RenderBox?;
    final overlay = Overlay.maybeOf(context)?.context.findRenderObject();
    if (box == null || overlay is! RenderBox) return;
    final rect = Rect.fromPoints(
      box.localToGlobal(Offset.zero, ancestor: overlay),
      box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay),
    );
    if (_settling != null) return;
    _hoverTimer?.cancel();
    final wasPinned = _pinned;
    setState(() => _pinned = true);
    _menuOpen = true;
    updateKeepAlive();
    final chosen = await showMenu<MessageActionId>(
      context: context,
      position: RelativeRect.fromRect(rect, Offset.zero & overlay.size),
      items: [
        for (final action in overflow)
          PopupMenuItem(
            key: ValueKey('message-action-${action.id.name}'),
            value: action.id,
            child: Row(
              children: [
                Icon(action.icon, size: 20),
                const SizedBox(width: 12),
                Flexible(child: Text(action.label)),
              ],
            ),
          ),
      ],
    );
    _menuOpen = false;
    if (!mounted) return;
    updateKeepAlive();
    // The action as it is now: the message may have changed meanwhile, as
    // when a newer turn moved a fork's cut. It runs even if the bar went
    // away meanwhile, as when the list followed a growing answer.
    final action = _all.where((a) => a.id == chosen).firstOrNull;
    if (action != null) {
      _settling?.cancel();
      _settling = null;
      _run(action);
      return;
    }
    // A tap outside the menu also closed the bar: it stays closed, ready
    // for the mouse again.
    if (!_portal.isShowing) {
      setState(() => _pinned = false);
      return;
    }
    // A dismissed menu leaves the bar as it was: a bar the mouse showed
    // still hides once the mouse is gone.
    setState(() => _pinned = wasPinned);
    if (!wasPinned && !_overBar) {
      _hoverTimer = Timer(messageBarHideDelay, () {
        if (mounted && !_pinned) _hide();
      });
    }
  }

  Widget _bar(BuildContext context) {
    final l10n = context.v2L10n;
    final all = _all;
    final primary = [
      for (final a in all)
        if (!a.overflow) a,
    ];
    final overflow = [
      for (final a in all)
        if (a.overflow) a,
    ];
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final viewport = _viewport;
    final y = _edgeY;
    final hintBelow = y != null && viewport != null && _hintBelow(y, viewport);
    final targetAnchor = switch (_edge) {
      _Edge.bottom => widget.end ? Alignment.bottomRight : Alignment.bottomLeft,
      _ => widget.end ? Alignment.topRight : Alignment.topLeft,
    };
    final followerAnchor = widget.end
        ? Alignment.centerRight
        : Alignment.centerLeft;
    final inset = widget.end ? -8.0 : 8.0;
    var first = true;
    FocusNode? focusFor() {
      if (!first) return null;
      first = false;
      return _firstButton;
    }

    final follower = Align(
      alignment: Alignment.topLeft,
      child: CompositedTransformFollower(
        link: _link,
        showWhenUnlinked: false,
        targetAnchor: targetAnchor,
        followerAnchor: followerAnchor,
        offset: Offset(inset, _edge == _Edge.pinned ? _pinnedDy : 0),
        child: Stack(
          children: [
            // While a double tap may still land, its second tap goes through
            // to the words, which it selects.
            IgnorePointer(
              ignoring: _settling != null,
              child: TapRegion(
                groupId: this,
                child: MouseRegion(
                  onEnter: (_) {
                    _overBar = true;
                    _hoverTimer?.cancel();
                  },
                  onExit: (event) {
                    _overBar = false;
                    _hoverExit(event);
                  },
                  child: Shortcuts(
                    shortcuts: const {
                      SingleActivator(LogicalKeyboardKey.escape):
                          _CloseBarIntent(),
                    },
                    child: Actions(
                      actions: {_CloseBarIntent: _CloseBarAction(this)},
                      child: FocusTraversalGroup(
                        child: Focus(
                          focusNode: _barFocus,
                          child: Semantics(
                            container: true,
                            explicitChildNodes: true,
                            label: l10n.messageActions,
                            // While a double tap may still land, its second tap
                            // goes through to the words, which it selects.
                            child: _ActionPill(
                              end: widget.end,
                              hintBelow: hintBelow,
                              maxWidth: (viewportWidth - 16).clamp(
                                _barHeight,
                                double.infinity,
                              ),
                              buttons: [
                                for (final action in primary)
                                  _PillButton(
                                    key: ValueKey(
                                      'message-action-${action.id.name}',
                                    ),
                                    focusNode: focusFor(),
                                    label: action.label,
                                    icon: action.icon,
                                    onPressed: (_) => _run(action),
                                  ),
                                if (overflow.isNotEmpty)
                                  _PillButton(
                                    key: const ValueKey('message-action-more'),
                                    focusNode: focusFor(),
                                    label: l10n.messageMoreActions,
                                    icon: Symbols.more_vert,
                                    onPressed: (button) =>
                                        unawaited(_more(button, overflow)),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Meanwhile the half of the bar past the message's edge takes
            // taps and does nothing, so they cannot reach the next message.
            if (_settling != null && _edge != _Edge.pinned)
              Positioned.fill(
                child: FractionallySizedBox(
                  alignment: _edge == _Edge.top
                      ? Alignment.topCenter
                      : Alignment.bottomCenter,
                  heightFactor: 0.5,
                  child: TapRegion(
                    groupId: this,
                    child: const AbsorbPointer(child: SizedBox.expand()),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    _built = viewport == null ? null : (viewport, hintBelow);
    return _withinList(context, follower, viewport);
  }

  /// Keeps [bar] inside the visible list, [viewport]: whatever moves the
  /// message, the bar never covers the header or the composer.
  Widget _withinList(BuildContext context, Widget bar, Rect? viewport) {
    final overlay = Overlay.maybeOf(context)?.context.findRenderObject();
    if (viewport == null || overlay is! RenderBox || !overlay.hasSize) {
      return bar;
    }
    final origin = overlay.globalToLocal(viewport.topLeft);
    return Stack(
      children: [
        Positioned.fromRect(
          rect: origin & viewport.size,
          child: ClipRect(child: bar),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final all = _all;
    Widget content = KeyedSubtree(
      key: _content,
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: _highlight
            ? BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2,
                  strokeAlign: BorderSide.strokeAlignOutside,
                ),
                borderRadius: BorderRadius.circular(12),
              )
            : const BoxDecoration(),
        // The message alone, without the focus outline or the bar.
        child: RepaintBoundary(
          child: KeyedSubtree(key: _capture, child: widget.child),
        ),
      ),
    );
    content = SelectionArea(
      onSelectionChanged: _selectionChanged,
      // Deeper than the selection's own long press, so on a clean area it
      // wins the arena and opens the bar; on words the selection wins.
      child: RawGestureDetector(
        behavior: HitTestBehavior.translucent,
        // Screen readers get the bar's actions on the message instead.
        excludeFromSemantics: true,
        gestures: {
          _CleanLongPress:
              GestureRecognizerFactoryWithHandlers<_CleanLongPress>(
                () => _CleanLongPress(allow: _isClean, debugOwner: this),
                (instance) => instance.onLongPressStart = _longPress,
              ),
        },
        child: content,
      ),
    );
    return Semantics(
      container: true,
      customSemanticsActions: {
        for (final action in all)
          CustomSemanticsAction(label: action.label): () => _run(action),
      },
      child: FocusableActionDetector(
        focusNode: _messageFocus,
        onShowFocusHighlight: (value) => setState(() => _highlight = value),
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.contextMenu): _OpenBarIntent(),
          SingleActivator(LogicalKeyboardKey.f10, shift: true):
              _OpenBarIntent(),
          // Only while the bar shows; otherwise Escape goes on as before.
          SingleActivator(LogicalKeyboardKey.escape): _CloseBarIntent(),
        },
        actions: {
          _OpenBarIntent: CallbackAction<_OpenBarIntent>(
            onInvoke: (_) => _show(pin: true, focus: true),
          ),
          _CloseBarIntent: _CloseBarAction(this),
        },
        child: TapRegion(
          groupId: this,
          onTapOutside: (_) {
            if (_portal.isShowing) _hide();
          },
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: _pointerDown,
            onPointerMove: _pointerMove,
            onPointerUp: _pointerUp,
            onPointerCancel: (_) => _downAt = null,
            child: RawGestureDetector(
              // The row beside the message answers a long press too.
              behavior: HitTestBehavior.translucent,
              excludeFromSemantics: true,
              gestures: {
                _CleanLongPress:
                    GestureRecognizerFactoryWithHandlers<_CleanLongPress>(
                      () => _CleanLongPress(allow: _beside, debugOwner: this),
                      (instance) => instance.onLongPressStart = _longPress,
                    ),
                TapGestureRecognizer:
                    GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
                      () => TapGestureRecognizer(debugOwner: this),
                      (instance) =>
                          instance.onSecondaryTapUp = (details) =>
                              _show(pin: true, at: details.globalPosition),
                    ),
              },
              child: Align(
                alignment: widget.end
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: widget.constraints,
                  child: CompositedTransformTarget(
                    link: _link,
                    child: OverlayPortal(
                      controller: _portal,
                      overlayChildBuilder: _bar,
                      // Resting on the message itself, not its row,
                      // shows the bar.
                      child: MouseRegion(
                        onEnter: _hoverEnter,
                        onExit: _hoverExit,
                        child: content,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The bar's pill. A long press, a hover or the focus on a button names it
/// above the pill (below it when the list has no room above), without an overlay of its own, which could not follow
/// the message (#539).
class _ActionPill extends StatefulWidget {
  const _ActionPill({
    required this.end,
    required this.hintBelow,
    required this.maxWidth,
    required this.buttons,
  });

  final bool end;

  /// The list leaves no room for a name above the pill: it goes below.
  final bool hintBelow;
  final double maxWidth;
  final List<_PillButton> buttons;

  @override
  State<_ActionPill> createState() => _ActionPillState();
}

class _ActionPillState extends State<_ActionPill> {
  String? _hint;
  Timer? _clear;

  @override
  void dispose() {
    _clear?.cancel();
    super.dispose();
  }

  void _name(String? label, {Duration? keep}) {
    _clear?.cancel();
    if (keep != null) {
      _clear = Timer(keep, () {
        if (mounted) setState(() => _hint = null);
      });
    }
    if (_hint != label) setState(() => _hint = label);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hint = _hint;
    return _PillScope(
      name: _name,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: widget.maxWidth,
              maxHeight: _barHeight,
            ),
            child: Material(
              key: const ValueKey('message-action-bar'),
              elevation: 3,
              color: scheme.surfaceContainerHigh,
              shape: StadiumBorder(
                side: BorderSide(color: scheme.outlineVariant),
              ),
              clipBehavior: Clip.antiAlias,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: widget.buttons,
                ),
              ),
            ),
          ),
          if (hint != null)
            // Just past the pill, whatever height the density gives it.
            Positioned(
              top: widget.hintBelow ? null : 0,
              bottom: widget.hintBelow ? 0 : null,
              left: widget.end ? null : 0,
              right: widget.end ? 0 : null,
              child: FractionalTranslation(
                translation: Offset(0, widget.hintBelow ? 1 : -1),
                child: Padding(
                  padding: widget.hintBelow
                      ? const EdgeInsets.only(top: 6)
                      : const EdgeInsets.only(bottom: 6),
                  child: ExcludeSemantics(
                    child: Material(
                      key: const ValueKey('message-action-hint'),
                      color: scheme.inverseSurface,
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Text(
                          hint,
                          maxLines: 1,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onInverseSurface,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PillScope extends InheritedWidget {
  const _PillScope({required this.name, required super.child});

  final void Function(String? label, {Duration? keep}) name;

  @override
  bool updateShouldNotify(_PillScope oldWidget) => false;
}

/// One button of the pill: an icon, its name for screen readers, and its
/// name shown on a long press, a hover or the keyboard focus.
class _PillButton extends StatelessWidget {
  const _PillButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.focusNode,
  });

  final String label;
  final IconData icon;
  final FocusNode? focusNode;

  /// Runs the button; the context is the button's, for a menu under it.
  final void Function(BuildContext button) onPressed;

  @override
  Widget build(BuildContext context) {
    final name = context.dependOnInheritedWidgetOfExactType<_PillScope>()?.name;
    return MouseRegion(
      onEnter: (_) => name?.call(label),
      onExit: (_) => name?.call(null),
      child: GestureDetector(
        onLongPress: () {
          unawaited(HapticFeedback.selectionClick());
          name?.call(label, keep: const Duration(milliseconds: 1500));
        },
        child: Focus(
          canRequestFocus: false,
          skipTraversal: true,
          onFocusChange: (focused) => name?.call(focused ? label : null),
          child: IconButton(
            focusNode: focusNode,
            icon: Icon(icon, size: 20, semanticLabel: label),
            onPressed: () => onPressed(context),
          ),
        ),
      ),
    );
  }
}
