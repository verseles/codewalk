import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

/// Height of the tab strip, also used by the integrated window chrome so the
/// title bar band and the strip stay aligned.
const double kAppTabStripHeight = 54 * 0.8;
const double kAppTabStripHeightCompact = 58 * 0.8;

/// Horizontal room each tab gives to its curved shoulders.
const double kAppTabShoulder = 10;

const double kAppTabInactiveTopRadius = 5;
const double kAppTabActiveTopRadius = 8;
const double kAppTabMinHeight = 48 * 0.8;
const double kAppStripTopPadding = 4 * 0.8;

const double kAppTabMaxWidth = 244 * 1.3;
const double kAppTabCompactMaxWidth = 214 * 1.3;
const double kAppTabPinnedWidth = 36;
const double kAppTabPinnedInactiveInset = 4;
// Floor for regular tabs WITH a trailing control (the selected tab).
const double kAppTabMinWidth = 150;
const double kAppTabCompactMinWidth = 140;
// Floor for tabs WITHOUT a trailing control (inactive).
const double kAppTabMinInactiveWidth = 120;
const double kAppTabCompactMinInactiveWidth = 100;
// Guards against float rounding engaging the ellipsis at the exact fit.
const double kAppTabWidthSlack = 1.0;
// Floor for the expanded selected pinned tab.
const double kAppTabPinnedSelectedMinWidth = 100;
const double kAppTabPinnedRegionMaxFraction = 0.5;
const double kAppTabMinimumRegularRegionWidth = 96;

/// Domain-agnostic tab view model. The strip never interprets [value]; it only
/// routes it back through callbacks. [id] must be stable and unique within the
/// tab list and is used for keys, focus nodes, hover state and reveal.
@immutable
class AppTab<T> {
  const AppTab({
    required this.id,
    required this.value,
    required this.title,
    this.tooltip,
    this.semanticLabel,
    this.titleSuffix,
    this.titleSuffixKey,
    this.isSelected = false,
    this.isPinned = false,
    this.canClose = true,
    this.canOpenContextMenu = true,
  });

  final String id;
  final T value;
  final String title;
  final String? tooltip;
  final String? semanticLabel;
  final String? titleSuffix;
  final Key? titleSuffixKey;
  final bool isSelected;
  final bool isPinned;
  final bool canClose;
  final bool canOpenContextMenu;
}

/// Context-menu callback routed with the tab and the global position.
typedef AppTabContextMenuCallback<T> =
    Future<void> Function(
      AppTab<T> tab,
      Offset globalPosition, {
      required bool haptic,
    });

/// Builds the trailing control of a tab (for example a close button or a
/// context-usage knob). Invoked only when the tab should show a trailing
/// control; return null to reserve no trailing space.
typedef AppTabTrailingBuilder<T> = Widget? Function(BuildContext context, AppTab<T> tab);

/// Builds the 28x28 leading content of a tab (icon, preset or status glyph).
typedef AppTabLeadingBuilder<T> = Widget Function(BuildContext context, AppTab<T> tab);

/// Resolves the tab id that should receive focus after [closedId] is closed.
/// Return null to leave focus untouched (for example file tabs, which must not
/// steal focus from the editor when a dirty close is blocked).
typedef AppTabCloseFallback = String? Function(List<String> tabIds, String closedId);

/// Generic browser-style tab strip shared by session tabs and file tabs.
///
/// The strip is fully controlled: it never mutates selection itself. After
/// [onClose], it restores focus to [closeFocusResolver]'s answer once the
/// controlled list has updated.
class AppTabStrip<T> extends StatefulWidget {
  const AppTabStrip({
    super.key,
    required this.tabs,
    required this.isCompact,
    required this.onActivate,
    required this.onClose,
    this.onContextMenu,
    this.leadingBuilder,
    this.trailingBuilder,
    this.trailingExtentBuilder,
    this.closeFocusResolver,
    this.contextMenuActionLabel,
    this.fillWidth = true,
    this.transparentBackground = false,
    this.showTrailingOnUnselected = false,
    this.keyPrefix = 'tab_',
    this.closeOnMiddleClick = true,
    this.closeOnDoubleTap = true,
    this.closeOnDeleteKey = true,
  });

  final List<AppTab<T>> tabs;
  final bool isCompact;
  final ValueChanged<AppTab<T>> onActivate;
  final ValueChanged<AppTab<T>> onClose;
  final AppTabContextMenuCallback<T>? onContextMenu;
  final AppTabLeadingBuilder<T>? leadingBuilder;
  final AppTabTrailingBuilder<T>? trailingBuilder;

  /// Width reserved for the trailing control when [trailingBuilder] returns
  /// non-null. Defaults to the historical session knob bounds
  /// (40px compact / 32px desktop).
  final double Function(BuildContext context, AppTab<T> tab)? trailingExtentBuilder;
  final AppTabCloseFallback? closeFocusResolver;

  /// Accessibility label for the custom "open menu" semantics action. When
  /// null, no custom semantics action is exposed.
  final String? contextMenuActionLabel;
  final bool fillWidth;
  final bool transparentBackground;

  /// When true, [trailingBuilder] is consulted for every tab instead of only
  /// the selected one. File tabs keep their close button always visible
  /// (touch needs an explicit target); session tabs keep the quiet inactive
  /// look with the trailing control only on the selected tab.
  final bool showTrailingOnUnselected;

  /// Prefix for every internal [ValueKey] (for example `session_tab_` or
  /// `file_viewer_tab_`). Preserves existing test anchors across adapters.
  final String keyPrefix;
  final bool closeOnMiddleClick;
  final bool closeOnDoubleTap;
  final bool closeOnDeleteKey;

  @override
  State<AppTabStrip<T>> createState() => _AppTabStripState<T>();
}

/// Browser-style tab silhouette: the sides flare outwards at the bottom so the
/// tab reads as a tab instead of a rounded rectangle, and neighbours interlock.
/// A zero shoulder keeps the straight sides and top radius only, which the
/// compact inactive tabs use to stay visually quiet and narrow.
class AppTabBorder extends ShapeBorder {
  const AppTabBorder({required this.topRadius, this.shoulder = kAppTabShoulder});

  final double topRadius;
  final double shoulder;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect, textDirection: textDirection);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final shoulder = this.shoulder;
    final r = topRadius;
    final lowerCurveTop = rect.bottom - shoulder;
    return Path()
      ..moveTo(rect.left, rect.bottom)
      ..cubicTo(
        rect.left + shoulder * 0.55,
        rect.bottom,
        rect.left + shoulder,
        rect.bottom - shoulder * 0.45,
        rect.left + shoulder,
        lowerCurveTop,
      )
      ..lineTo(rect.left + shoulder, rect.top + r)
      ..arcToPoint(
        Offset(rect.left + shoulder + r, rect.top),
        radius: Radius.circular(r),
      )
      ..lineTo(rect.right - shoulder - r, rect.top)
      ..arcToPoint(
        Offset(rect.right - shoulder, rect.top + r),
        radius: Radius.circular(r),
      )
      ..lineTo(rect.right - shoulder, lowerCurveTop)
      ..cubicTo(
        rect.right - shoulder,
        rect.bottom - shoulder * 0.45,
        rect.right - shoulder * 0.55,
        rect.bottom,
        rect.right,
        rect.bottom,
      )
      ..close();
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  ShapeBorder scale(double t) =>
      AppTabBorder(topRadius: topRadius * t, shoulder: shoulder * t);
}

class _AppTabStripState<T> extends State<AppTabStrip<T>> {
  final ScrollController _scrollController = ScrollController();
  final ScrollController _pinnedScrollController = ScrollController();
  final Map<String, GlobalKey> _tabKeys = <String, GlobalKey>{};
  final Map<String, FocusNode> _tabFocusNodes = <String, FocusNode>{};
  final Map<String, WidgetStatesController> _tabStatesControllers =
      <String, WidgetStatesController>{};
  String? _hoveredId;
  String? _hoveredTrailingId;
  String? _lastPointerId;
  Offset? _lastPointerGlobalPosition;
  String? _lastSelectedId;
  int? _lastSelectedIndex;
  bool? _lastSelectedIsPinned;
  double? _lastViewportWidth;
  List<double>? _lastLayoutWidths;
  bool? _lastIsCompact;
  bool? _lastFillWidth;
  String? _pendingEnsureVisibleId;
  bool _ensureVisibleScheduled = false;

  @override
  void didUpdateWidget(covariant AppTabStrip<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final ids = widget.tabs.map((tab) => tab.id).toSet();
    final selectedIds = widget.tabs
        .where((tab) => tab.isSelected)
        .map((tab) => tab.id)
        .toSet();
    // A closed tab never gets a pointer-exit, so drop reveal state that points
    // at a tab which no longer exists.
    if (_hoveredId != null && !ids.contains(_hoveredId)) {
      _hoveredId = null;
    }
    // Tabs showing trailing controls while unselected (file tabs) keep their
    // hover tracking across rebuilds; only clear it when the tab is gone or
    // when unselected tabs cannot show trailing controls.
    final trailingGone =
        _hoveredTrailingId != null && !ids.contains(_hoveredTrailingId);
    final trailingDeselected =
        _hoveredTrailingId != null &&
        !selectedIds.contains(_hoveredTrailingId) &&
        !widget.showTrailingOnUnselected;
    if (trailingGone || trailingDeselected) {
      _hoveredTrailingId = null;
    }
    if (_lastPointerId != null && !ids.contains(_lastPointerId)) {
      _lastPointerId = null;
      _lastPointerGlobalPosition = null;
    }
    _tabKeys.removeWhere((id, _) => !ids.contains(id));
    final removedFocusNodes = _tabFocusNodes.entries
        .where((entry) => !ids.contains(entry.key))
        .toList(growable: false);
    for (final entry in removedFocusNodes) {
      _tabFocusNodes.remove(entry.key);
      entry.value.dispose();
    }
    final removedStateControllers = _tabStatesControllers.entries
        .where((entry) => !ids.contains(entry.key))
        .toList(growable: false);
    for (final entry in removedStateControllers) {
      _tabStatesControllers.remove(entry.key);
      entry.value.dispose();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _pinnedScrollController.dispose();
    for (final focusNode in _tabFocusNodes.values) {
      focusNode.dispose();
    }
    for (final controller in _tabStatesControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.tabs.isEmpty) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = widget.isCompact ? 6.0 : 8.0;
        final maxTabWidth = widget.isCompact ? kAppTabCompactMaxWidth : kAppTabMaxWidth;
        // The viewport still caps the maximum so the strip stays responsive
        // to the available width; tabs never compress below their floor.
        final effectiveMaxTabWidth = math.min(
          maxTabWidth,
          math.max(0.0, constraints.maxWidth - horizontalPadding * 2),
        );
        final pinnedTabs = widget.tabs.where((tab) => tab.isPinned).toList(growable: false);
        final regularTabs = widget.tabs.where((tab) => !tab.isPinned).toList(growable: false);
        final availableWidth = math.max(0.0, constraints.maxWidth - horizontalPadding * 2);
        final inactivePinnedWidth = pinnedTabs.fold<double>(
          0,
          (width, tab) => width + (tab.isSelected ? 0 : kAppTabPinnedWidth),
        );
        final selectedPinned = pinnedTabs.where((tab) => tab.isSelected).firstOrNull;
        final selectedPinnedTrailing = selectedPinned == null
            ? null
            : _trailingFor(context, selectedPinned);
        final selectedPinnedContentWidth = selectedPinned == null
            ? 0.0
            : _contentTabWidth(
                context,
                selectedPinned,
                selectedPinnedTrailing,
                maxTabWidth: effectiveMaxTabWidth,
              );
        final desiredPinnedWidth = inactivePinnedWidth + selectedPinnedContentWidth;
        final regularMinimum = math.min(
          kAppTabMinimumRegularRegionWidth,
          availableWidth * 0.5,
        );
        final pinnedWidthLimit = regularTabs.isEmpty
            ? availableWidth
            : math.max(
                0.0,
                math.min(
                  availableWidth * kAppTabPinnedRegionMaxFraction,
                  availableWidth - regularMinimum,
                ),
              );
        // The cap grows to fit the expanded selected pinned tab so it stays
        // fully visible without scrolling, while the regular region keeps at
        // least its minimum usable width.
        final growthRoom = regularTabs.isEmpty
            ? availableWidth
            : math.max(0.0, availableWidth - regularMinimum);
        final cap = selectedPinned != null ? growthRoom : pinnedWidthLimit;
        final pinnedRegionWidth = math.min(desiredPinnedWidth, cap);
        // Never collapse the expanded tab: when the inactive pinned tabs
        // already fill the region, the floor keeps it visible and the pinned
        // viewport scrolls to reveal it.
        final selectedPinnedWidth = math.max(
          kAppTabPinnedSelectedMinWidth,
          pinnedRegionWidth - inactivePinnedWidth,
        );
        final regularLayout = <({AppTab<T> tab, double width, Widget? trailing})>[];
        for (final tab in regularTabs) {
          final trailing =
              (tab.isSelected || widget.showTrailingOnUnselected)
                  ? _trailingFor(context, tab)
                  : null;
          regularLayout.add((
            tab: tab,
            width: _contentTabWidth(
              context,
              tab,
              trailing,
              maxTabWidth: effectiveMaxTabWidth,
            ),
            trailing: trailing,
          ));
        }
        final selectedId = _selectedId();
        final selectedIndex = widget.tabs.indexWhere((tab) => tab.isSelected);
        final selectedIsPinned = selectedId != null && selectedIndex >= 0
            ? widget.tabs[selectedIndex].isPinned
            : false;
        final layoutWidths = <double>[
          for (final tab in pinnedTabs)
            tab.isSelected ? selectedPinnedContentWidth : kAppTabPinnedWidth,
          for (final entry in regularLayout) entry.width,
        ];
        if (selectedId != _lastSelectedId ||
            selectedIndex != _lastSelectedIndex ||
            selectedIsPinned != _lastSelectedIsPinned ||
            constraints.maxWidth != _lastViewportWidth ||
            !listEquals(layoutWidths, _lastLayoutWidths) ||
            widget.isCompact != _lastIsCompact ||
            widget.fillWidth != _lastFillWidth) {
          _lastSelectedId = selectedId;
          _lastSelectedIndex = selectedIndex;
          _lastSelectedIsPinned = selectedIsPinned;
          _lastViewportWidth = constraints.maxWidth;
          _lastLayoutWidths = layoutWidths;
          _lastIsCompact = widget.isCompact;
          _lastFillWidth = widget.fillWidth;
          _scheduleEnsureSelectedVisible(selectedId);
        }

        return Container(
          key: ValueKey<String>('${widget.keyPrefix}strip'),
          height: widget.isCompact ? kAppTabStripHeightCompact : kAppTabStripHeight,
          width: widget.fillWidth ? double.infinity : null,
          // No bottom border: the selected tab reaches the strip edge and
          // merges with the content panel below, like a browser tab.
          decoration: BoxDecoration(
            color: widget.transparentBackground ? Colors.transparent : colorScheme.surfaceContainerHigh,
          ),
          child: Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              horizontalPadding,
              kAppStripTopPadding,
              horizontalPadding,
              0,
            ),
            child: Row(
              mainAxisSize: widget.fillWidth ? MainAxisSize.max : MainAxisSize.min,
              children: [
                if (pinnedTabs.isNotEmpty && pinnedRegionWidth > 0)
                  SizedBox(
                    key: ValueKey<String>('${widget.keyPrefix}pinned_region'),
                    width: pinnedRegionWidth,
                    child: Listener(
                      onPointerSignal: (event) => _handlePointerSignal(
                        event,
                        controller: _pinnedScrollController,
                      ),
                      child: ScrollConfiguration(
                        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                        child: SingleChildScrollView(
                          key: ValueKey<String>('${widget.keyPrefix}pinned_region_scroll_view'),
                          controller: _pinnedScrollController,
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (final tab in pinnedTabs)
                                _buildTab(
                                  context,
                                  tab,
                                  tab.isSelected
                                      ? math.min(selectedPinnedContentWidth, selectedPinnedWidth)
                                      : kAppTabPinnedWidth,
                                  compactPinned: !tab.isSelected,
                                  // Unselected pinned tabs never show trailing
                                  // controls: they render at the fixed 36px
                                  // icon width where nothing else fits.
                                  trailing: tab.isSelected
                                      ? selectedPinnedTrailing
                                      : null,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                if (regularTabs.isNotEmpty)
                  Flexible(
                    fit: widget.fillWidth ? FlexFit.tight : FlexFit.loose,
                    child: Listener(
                      onPointerSignal: (event) => _handlePointerSignal(
                        event,
                        controller: _scrollController,
                      ),
                      child: ScrollConfiguration(
                        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                        child: SingleChildScrollView(
                          key: ValueKey<String>('${widget.keyPrefix}strip_scroll_view'),
                          controller: _scrollController,
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (final entry in regularLayout)
                                _buildTab(
                                  context,
                                  entry.tab,
                                  entry.width,
                                  trailing: entry.trailing,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget? _trailingFor(BuildContext context, AppTab<T> tab) {
    return widget.trailingBuilder?.call(context, tab);
  }

  void _setHovered(String? id) {
    if (!mounted || _hoveredId == id) {
      return;
    }
    setState(() => _hoveredId = id);
  }

  void _setTrailingHovered(String? id) {
    if (!mounted || _hoveredTrailingId == id) {
      return;
    }
    setState(() => _hoveredTrailingId = id);
  }

  FocusNode _focusNodeFor(AppTab<T> tab) {
    return _tabFocusNodes.putIfAbsent(tab.id, () {
      return FocusNode(debugLabel: 'Tab ${tab.id}');
    });
  }

  WidgetStatesController _statesControllerFor(AppTab<T> tab) {
    return _tabStatesControllers.putIfAbsent(tab.id, WidgetStatesController.new);
  }

  void _handlePointerDown(AppTab<T> tab, PointerDownEvent event) {
    _lastPointerId = tab.id;
    _lastPointerGlobalPosition = event.position;
    if (widget.closeOnMiddleClick &&
        tab.canClose &&
        event.buttons & kMiddleMouseButton != 0) {
      _handleClose(tab);
    }
  }

  Offset _contextMenuPosition(AppTab<T> tab) {
    if (_lastPointerId == tab.id && _lastPointerGlobalPosition != null) {
      return _lastPointerGlobalPosition!;
    }
    final renderObject = _tabKeys[tab.id]?.currentContext?.findRenderObject();
    if (renderObject is RenderBox) {
      return renderObject.localToGlobal(renderObject.size.center(Offset.zero));
    }
    return Offset.zero;
  }

  double _measureTitleWidth(BuildContext context, String title, bool selected) {
    final painter = TextPainter(
      text: TextSpan(
        text: title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
        ),
      ),
      maxLines: 1,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  /// Width derived from the tab content, clamped between a floor and the
  /// maximum. Only the first line of the title is measured because the tab
  /// paints a single ellipsized line. The trailing extent is resolved through
  /// [trailingExtentBuilder] so file close buttons do not inherit the session
  /// usage-knob bounds.
  double _contentTabWidth(
    BuildContext context,
    AppTab<T> tab,
    Widget? trailing, {
    required double maxTabWidth,
  }) {
    final trailingWidth = trailing == null
        ? kAppTabShoulder
        : (widget.trailingExtentBuilder?.call(context, tab) ??
                  (widget.isCompact ? 40.0 : 32.0)) +
              kAppTabShoulder;
    final chrome = kAppTabShoulder + 28 + 7 + 2 + trailingWidth;
    final minTabWidth = trailing == null
        ? (widget.isCompact ? kAppTabCompactMinInactiveWidth : kAppTabMinInactiveWidth)
        : (widget.isCompact ? kAppTabCompactMinWidth : kAppTabMinWidth);
    final title = '${tab.title}${tab.titleSuffix ?? ''}'.split('\n').first;
    final titleWidth = _measureTitleWidth(context, title, tab.isSelected);
    // The minimum is applied last so a viewport narrower than the minimum
    // still keeps the tab at its floor and lets the strip scroll.
    return math.max(
      minTabWidth,
      math.min(maxTabWidth, (chrome + titleWidth + kAppTabWidthSlack).ceilToDouble()),
    );
  }

  Widget _buildTab(
    BuildContext context,
    AppTab<T> tab,
    double tabWidth, {
    bool compactPinned = false,
    Widget? trailing,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final title = tab.title;
    final id = tab.id;
    final selected = tab.isSelected;
    final topRadius = selected ? kAppTabActiveTopRadius : kAppTabInactiveTopRadius;
    final radius = BorderRadius.vertical(top: Radius.circular(topRadius));
    final foreground = selected ? colorScheme.onSurface : colorScheme.onSurfaceVariant;
    final hovered = _hoveredId == id;
    final trailingHovered = _hoveredTrailingId == id;
    final tabSurfaceColor = selected
        ? colorScheme.surface
        : hovered && !trailingHovered
            ? colorScheme.surface.withValues(alpha: 0.45)
            : Colors.transparent;
    final focusNode = _focusNodeFor(tab);
    final statesController = _statesControllerFor(tab);
    final canMenu = tab.canOpenContextMenu && widget.onContextMenu != null;

    void openContextMenu({required bool haptic}) {
      final callback = widget.onContextMenu;
      if (callback == null) {
        return;
      }
      unawaited(callback(tab, _contextMenuPosition(tab), haptic: haptic));
    }

    final label = tab.semanticLabel ?? title;
    final tooltip = tab.tooltip ?? title;

    return MouseRegion(
      key: ValueKey<String>('${widget.keyPrefix}item_$id'),
      onEnter: (_) => _setHovered(id),
      onExit: (_) => _setHovered(null),
      child: Listener(
        onPointerDown: (event) => _handlePointerDown(tab, event),
        child: Focus(
          canRequestFocus: false,
          skipTraversal: true,
          child: SizedBox(
            key: _tabKeys.putIfAbsent(id, GlobalKey.new),
            width: tabWidth,
            child: AnimatedBuilder(
              animation: statesController,
              builder: (context, _) {
                final focused = statesController.value.contains(WidgetState.focused);
                final tabOverlayColor = trailingHovered
                    ? Colors.transparent
                    : focused
                        ? colorScheme.primary.withValues(alpha: 0.14)
                        : hovered
                            ? colorScheme.primary.withValues(alpha: 0.09)
                            : Colors.transparent;
                return Material(
                  key: ValueKey<String>('${widget.keyPrefix}$id'),
                  // The selected tab shares the content surface colour, which is what
                  // creates the visual continuity with the panel underneath. No
                  // border on any side: a bottom stroke would draw a hairline between
                  // the tab and the content it is supposed to be joined to.
                  color: tabSurfaceColor,
                  shape: AppTabBorder(
                    topRadius: topRadius,
                    // The selected tab keeps the browser-style flare; inactive
                    // tabs drop it so their silhouette stays quiet and narrow.
                    shoulder: selected ? kAppTabShoulder : 0,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: IgnorePointer(
                          child: ColoredBox(
                            key: ValueKey<String>('${widget.keyPrefix}overlay_$id'),
                            color: tabOverlayColor,
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: Row(
                          children: [
                            Expanded(
                              child: CallbackShortcuts(
                                bindings: <ShortcutActivator, VoidCallback>{
                                  if (canMenu)
                                    const SingleActivator(LogicalKeyboardKey.contextMenu): () =>
                                        openContextMenu(haptic: false),
                                  if (canMenu)
                                    const SingleActivator(LogicalKeyboardKey.f10, shift: true): () =>
                                        openContextMenu(haptic: false),
                                  if (widget.closeOnDeleteKey && tab.canClose)
                                    const SingleActivator(LogicalKeyboardKey.delete): () =>
                                        _handleClose(tab),
                                },
                                child: Semantics(
                                  button: true,
                                  selected: selected,
                                  label: label,
                                  onTap: () => _handleActivate(tab),
                                  onDismiss: tab.canClose ? () => _handleClose(tab) : null,
                                  onLongPress: canMenu ? () => openContextMenu(haptic: true) : null,
                                  customSemanticsActions: canMenu && widget.contextMenuActionLabel != null
                                      ? <CustomSemanticsAction, VoidCallback>{
                                          CustomSemanticsAction(
                                            label: widget.contextMenuActionLabel!,
                                          ): () => openContextMenu(haptic: false),
                                        }
                                      : null,
                                  child: Tooltip(
                                    message: tooltip,
                                    excludeFromSemantics: true,
                                    child: ExcludeSemantics(
                                      child: InkWell(
                                        key: ValueKey<String>('${widget.keyPrefix}activate_$id'),
                                        focusNode: focusNode,
                                        statesController: statesController,
                                        borderRadius: radius,
                                        overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
                                          if (states.contains(WidgetState.pressed)) {
                                            return colorScheme.primary.withValues(alpha: 0.18);
                                          }
                                          return Colors.transparent;
                                        }),
                                        onTap: () => _handleActivate(tab),
                                        onDoubleTap: widget.closeOnDoubleTap && tab.canClose
                                            ? () => _handleClose(tab)
                                            : null,
                                        onSecondaryTapUp: canMenu
                                            ? (details) => unawaited(
                                                  widget.onContextMenu!(
                                                    tab,
                                                    details.globalPosition,
                                                    haptic: false,
                                                  ),
                                                )
                                            : null,
                                        onLongPress: canMenu ? () => openContextMenu(haptic: true) : null,
                                        child: ConstrainedBox(
                                          constraints: const BoxConstraints(minHeight: kAppTabMinHeight),
                                          child: Padding(
                                            padding: EdgeInsetsDirectional.only(
                                              start: compactPinned ? kAppTabPinnedInactiveInset : kAppTabShoulder,
                                            ),
                                            child: Row(
                                              children: [
                                                SizedBox(
                                                  key: ValueKey<String>('${widget.keyPrefix}leading_$id'),
                                                  width: 28,
                                                  height: 28,
                                                  child: widget.leadingBuilder?.call(context, tab) ??
                                                      const SizedBox.shrink(),
                                                ),
                                                if (!compactPinned) ...[
                                                  const SizedBox(width: 7),
                                                  Expanded(
                                                    child: Row(
                                                      children: [
                                                        Flexible(
                                                          child: Text(
                                                            title,
                                                            key: ValueKey<String>(
                                                              '${widget.keyPrefix}title_$id',
                                                            ),
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style: Theme.of(context)
                                                                .textTheme
                                                                .labelLarge
                                                                ?.copyWith(
                                                                  color:
                                                                      foreground,
                                                                  fontWeight: selected
                                                                      ? FontWeight
                                                                          .w700
                                                                      : FontWeight
                                                                          .w600,
                                                                ),
                                                          ),
                                                        ),
                                                        // The suffix (for example
                                                        // the dirty `*`) sits
                                                        // outside the ellipsized
                                                        // title so long names
                                                        // truncate before it.
                                                        if (tab.titleSuffix !=
                                                            null)
                                                          Text(
                                                            tab.titleSuffix!,
                                                            key: tab
                                                                .titleSuffixKey,
                                                            style: Theme.of(context)
                                                                .textTheme
                                                                .labelLarge
                                                                ?.copyWith(
                                                                  color:
                                                                      foreground,
                                                                  fontWeight: selected
                                                                      ? FontWeight
                                                                          .w700
                                                                      : FontWeight
                                                                          .w600,
                                                                ),
                                                          ),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(width: 2),
                                                ],
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
                            if (trailing == null)
                              SizedBox(
                                width: compactPinned ? kAppTabPinnedInactiveInset : kAppTabShoulder,
                              )
                            else
                              Padding(
                                padding: const EdgeInsetsDirectional.only(end: kAppTabShoulder),
                                child: MouseRegion(
                                  key: ValueKey<String>('${widget.keyPrefix}trailing_$id'),
                                  onEnter: (_) => _setTrailingHovered(id),
                                  onExit: (_) => _setTrailingHovered(null),
                                  child: trailing,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  String? _selectedId() {
    for (final tab in widget.tabs) {
      if (tab.isSelected) {
        return tab.id;
      }
    }
    return null;
  }

  void _handleClose(AppTab<T> tab) {
    if (!tab.canClose) {
      return;
    }
    final resolver = widget.closeFocusResolver;
    final fallbackId = resolver?.call(
      <String>[for (final t in widget.tabs) t.id],
      tab.id,
    );
    widget.onClose(tab);
    if (fallbackId == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _tabFocusNodes[fallbackId]?.requestFocus();
    });
  }

  void _handleActivate(AppTab<T> tab) {
    widget.onActivate(tab);
    _scheduleEnsureSelectedVisible(tab.id);
  }

  void _scheduleEnsureSelectedVisible(String? id) {
    _pendingEnsureVisibleId = id;
    if (id == null || _ensureVisibleScheduled) {
      return;
    }
    _ensureVisibleScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureVisibleScheduled = false;
      if (!mounted) {
        return;
      }
      final pendingId = _pendingEnsureVisibleId;
      _pendingEnsureVisibleId = null;
      if (pendingId == null || _selectedId() != pendingId) {
        return;
      }
      final tabContext = _tabKeys[pendingId]?.currentContext;
      final selectedIndex = widget.tabs.indexWhere((tab) => tab.id == pendingId);
      final selectedTab = selectedIndex < 0 ? null : widget.tabs[selectedIndex];
      final controller = selectedTab?.isPinned ?? false ? _pinnedScrollController : _scrollController;
      if (!controller.hasClients || tabContext == null) {
        _scheduleEnsureSelectedVisible(pendingId);
        return;
      }
      final tabRenderObject = tabContext.findRenderObject();
      if (tabRenderObject == null) {
        _scheduleEnsureSelectedVisible(pendingId);
        return;
      }
      final viewport = RenderAbstractViewport.maybeOf(tabRenderObject);
      if (viewport == null) {
        _scheduleEnsureSelectedVisible(pendingId);
        return;
      }
      final position = controller.position;
      // Skip the animation when the selected tab is already fully visible:
      // width changes of unrelated tabs must not yank the user's scroll.
      final revealLeading = viewport.getOffsetToReveal(tabRenderObject, 0.0).offset;
      final revealTrailing = viewport.getOffsetToReveal(tabRenderObject, 1.0).offset;
      if (revealTrailing <= position.pixels && position.pixels <= revealLeading) {
        return;
      }
      final target = viewport
          .getOffsetToReveal(tabRenderObject, 0.5)
          .offset
          .clamp(position.minScrollExtent, position.maxScrollExtent)
          .toDouble();
      unawaited(
        controller.animateTo(
          target,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
        ),
      );
    });
  }

  void _handlePointerSignal(PointerSignalEvent event, {required ScrollController controller}) {
    if (event is! PointerScrollEvent || !controller.hasClients) {
      return;
    }
    final delta = event.scrollDelta.dy.abs() >= event.scrollDelta.dx.abs()
        ? event.scrollDelta.dy
        : event.scrollDelta.dx;
    if (delta == 0) {
      return;
    }
    final position = controller.position;
    final next = (controller.offset + delta).clamp(position.minScrollExtent, position.maxScrollExtent);
    controller.jumpTo(next.toDouble());
  }
}
