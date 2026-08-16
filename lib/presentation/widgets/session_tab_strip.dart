import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/i18n/l10n_context.dart';
import '../../core/utils/path_utils.dart';
import '../../domain/entities/chat_realtime.dart';
import '../../domain/entities/project.dart';
import '../providers/chat_provider.dart';
import '../services/session_tab_icon_presets.dart';
import 'project_icon.dart';

/// Height of the tab strip, also used by the integrated window chrome so the
/// title bar band and the strip stay aligned.
const double kSessionTabStripHeight = 54 * 0.8;
const double kSessionTabStripHeightCompact = 58 * 0.8;

/// Horizontal room each tab gives to its curved shoulders.
const double _kTabShoulder = 10;

const double _kInactiveTabTopRadius = 5;
const double _kActiveTabTopRadius = 8;
const double _kTabMinHeight = 48 * 0.8;
const double _kStripTopPadding = 4 * 0.8;

const double _kSessionTabWidth = 244 * 1.3;
const double _kCompactSessionTabWidth = 214 * 1.3;
const double _kPinnedSessionTabWidth = 36;
const double _kPinnedInactiveTabInset = 4;
// Floor for regular tabs: the largest selected-tab chrome is 10px start
// padding + 28px leading box + 7px + 2px gaps + the trailing usage button
// (40px compact / 32px desktop, plus 10px padding) = 97px worst case. 150
// desktop / 140 compact keep a readable title area (61px desktop / 43px
// compact) while short titles still shrink the tab; compact trades title
// room for strip capacity.
const double _kMinimumSessionTabWidth = 150;
const double _kMinimumCompactSessionTabWidth = 140;
// Guards against float rounding engaging the ellipsis at the exact fit.
const double _kTabWidthSlack = 1.0;
// Floor for the expanded selected pinned tab: the fixed content is 10px inset
// + 28px leading box + gaps + the trailing usage button (40px compact /
// 32px desktop, plus 10px padding) = 97px worst case, and the shape needs
// 2 * (shoulder + radius) = 36px. 100 keeps a little headroom so small
// trailing-size changes cannot silently overflow. When inactive pinned tabs
// already fill the region the floor keeps the tab usable and the pinned
// viewport scrolls to it.
const double _kPinnedSelectedTabMinWidth = 100;
const double _kPinnedRegionMaxFraction = 0.5;
const double _kMinimumRegularRegionWidth = 96;

typedef SessionTabContextMenuCallback =
    Future<void> Function(
      SessionTabRecord tab,
      Offset globalPosition, {
      required bool haptic,
    });
/// Builds the trailing control (for example the context-usage button) of the
/// selected tab. Invoked only for the selected regular tab and the expanded
/// selected pinned tab; inactive tabs never show a trailing control.
typedef SessionTabTrailingBuilder =
    Widget? Function(BuildContext context, SessionTabRecord tab);

/// Browser-style tab silhouette: the sides flare outwards at the bottom so the
/// tab reads as a tab instead of a rounded rectangle, and neighbours interlock.
/// A zero shoulder keeps the straight sides and top radius only, which the
/// compact inactive tabs use to stay visually quiet and narrow.
class _ChromeTabBorder extends ShapeBorder {
  const _ChromeTabBorder({required this.topRadius, this.shoulder = _kTabShoulder});

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
      _ChromeTabBorder(topRadius: topRadius * t, shoulder: shoulder * t);
}

String sessionTabIdentityKey(SessionTabIdentity identity) {
  return '${identity.serverId}::${identity.directory}::${identity.sessionId}';
}

class SessionTabStrip extends StatefulWidget {
  const SessionTabStrip({
    super.key,
    required this.tabs,
    required this.projects,
    required this.openProjectIds,
    required this.isCompact,
    required this.onActivate,
    required this.onClose,
    required this.onContextMenu,
    required this.trailingBuilder,
    this.fillWidth = true,
    this.transparentBackground = false,
  });

  final List<SessionTabRecord> tabs;
  final List<Project> projects;
  final Set<String> openProjectIds;
  final bool isCompact;

  /// When false the strip sizes itself to its tabs instead of expanding, so the
  /// integrated window chrome can use the leftover space as a drag region.
  final bool fillWidth;

  /// When true the strip paints no band of its own, so it blends into the
  /// surface behind it. The integrated window chrome already paints that band;
  /// standing alone under the app bar the strip still needs its own.
  final bool transparentBackground;
  final ValueChanged<SessionTabRecord> onActivate;
  final ValueChanged<SessionTabRecord> onClose;
  final SessionTabContextMenuCallback onContextMenu;
  final SessionTabTrailingBuilder trailingBuilder;

  @override
  State<SessionTabStrip> createState() => _SessionTabStripState();
}

class _SessionTabStripState extends State<SessionTabStrip> {
  final ScrollController _scrollController = ScrollController();
  final ScrollController _pinnedScrollController = ScrollController();
  final Map<SessionTabIdentity, GlobalKey> _tabKeys =
      <SessionTabIdentity, GlobalKey>{};
  final Map<SessionTabIdentity, FocusNode> _tabFocusNodes =
      <SessionTabIdentity, FocusNode>{};
  SessionTabIdentity? _hoveredIdentity;
  SessionTabIdentity? _lastPointerIdentity;
  Offset? _lastPointerGlobalPosition;
  SessionTabIdentity? _lastSelectedIdentity;
  int? _lastSelectedIndex;
  bool? _lastSelectedIsPinned;
  double? _lastViewportWidth;
  List<double>? _lastLayoutWidths;
  bool? _lastIsCompact;
  bool? _lastFillWidth;
  SessionTabIdentity? _pendingEnsureVisibleIdentity;
  bool _ensureVisibleScheduled = false;

  @override
  void didUpdateWidget(covariant SessionTabStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    final identities = widget.tabs.map((tab) => tab.identity).toSet();
    // A closed tab never gets a pointer-exit, so drop reveal state that points
    // at a tab which no longer exists.
    if (_hoveredIdentity != null && !identities.contains(_hoveredIdentity)) {
      _hoveredIdentity = null;
    }
    if (_lastPointerIdentity != null &&
        !identities.contains(_lastPointerIdentity)) {
      _lastPointerIdentity = null;
      _lastPointerGlobalPosition = null;
    }
    _tabKeys.removeWhere((identity, _) => !identities.contains(identity));
    final removedFocusNodes = _tabFocusNodes.entries
        .where((entry) => !identities.contains(entry.key))
        .toList(growable: false);
    for (final entry in removedFocusNodes) {
      _tabFocusNodes.remove(entry.key);
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
        final maxTabWidth = widget.isCompact
            ? _kCompactSessionTabWidth
            : _kSessionTabWidth;
        final minTabWidth = widget.isCompact
            ? _kMinimumCompactSessionTabWidth
            : _kMinimumSessionTabWidth;
        // The viewport still caps the maximum so the strip stays responsive
        // to the available width; tabs never compress below the minimum.
        final effectiveMaxTabWidth = math.min(
          maxTabWidth,
          math.max(0.0, constraints.maxWidth - horizontalPadding * 2),
        );
        final pinnedTabs = widget.tabs
            .where((tab) => tab.isPinned)
            .toList(growable: false);
        final regularTabs = widget.tabs
            .where((tab) => !tab.isPinned)
            .toList(growable: false);
        final availableWidth = math.max(
          0.0,
          constraints.maxWidth - horizontalPadding * 2,
        );
        final inactivePinnedWidth = pinnedTabs.fold<double>(
          0,
          (width, tab) =>
              width + (tab.isSelected ? 0 : _kPinnedSessionTabWidth),
        );
        final selectedPinned = pinnedTabs
            .where((tab) => tab.isSelected)
            .firstOrNull;
        final selectedPinnedTrailing = selectedPinned == null
            ? null
            : widget.trailingBuilder(context, selectedPinned);
        final selectedPinnedContentWidth = selectedPinned == null
            ? 0.0
            : _contentTabWidth(
                context,
                selectedPinned,
                selectedPinnedTrailing,
                maxTabWidth: effectiveMaxTabWidth,
                minTabWidth: minTabWidth,
              );
        final desiredPinnedWidth =
            inactivePinnedWidth + selectedPinnedContentWidth;
        final regularMinimum = math.min(
          _kMinimumRegularRegionWidth,
          availableWidth * 0.5,
        );
        final pinnedWidthLimit = regularTabs.isEmpty
            ? availableWidth
            : math.max(
                0.0,
                math.min(
                  availableWidth * _kPinnedRegionMaxFraction,
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
          _kPinnedSelectedTabMinWidth,
          pinnedRegionWidth - inactivePinnedWidth,
        );
        final regularLayout =
            <({SessionTabRecord tab, double width, Widget? trailing})>[];
        for (final tab in regularTabs) {
          final trailing = tab.isSelected
              ? widget.trailingBuilder(context, tab)
              : null;
          regularLayout.add((
            tab: tab,
            width: _contentTabWidth(
              context,
              tab,
              trailing,
              maxTabWidth: effectiveMaxTabWidth,
              minTabWidth: minTabWidth,
            ),
            trailing: trailing,
          ));
        }
        final selectedIdentity = _selectedIdentity();
        final selectedIndex = widget.tabs.indexWhere((tab) => tab.isSelected);
        final selectedIsPinned = selectedIdentity != null
            ? widget.tabs[selectedIndex].isPinned
            : false;
        final layoutWidths = <double>[
          for (final tab in pinnedTabs)
            tab.isSelected ? selectedPinnedContentWidth : _kPinnedSessionTabWidth,
          for (final entry in regularLayout) entry.width,
        ];
        if (selectedIdentity != _lastSelectedIdentity ||
            selectedIndex != _lastSelectedIndex ||
            selectedIsPinned != _lastSelectedIsPinned ||
            constraints.maxWidth != _lastViewportWidth ||
            !listEquals(layoutWidths, _lastLayoutWidths) ||
            widget.isCompact != _lastIsCompact ||
            widget.fillWidth != _lastFillWidth) {
          _lastSelectedIdentity = selectedIdentity;
          _lastSelectedIndex = selectedIndex;
          _lastSelectedIsPinned = selectedIsPinned;
          _lastViewportWidth = constraints.maxWidth;
          _lastLayoutWidths = layoutWidths;
          _lastIsCompact = widget.isCompact;
          _lastFillWidth = widget.fillWidth;
          _scheduleEnsureSelectedVisible(selectedIdentity);
        }

        return Container(
          key: const ValueKey<String>('session_tab_strip'),
          height: widget.isCompact
              ? kSessionTabStripHeightCompact
              : kSessionTabStripHeight,
          width: widget.fillWidth ? double.infinity : null,
          // No bottom border: the selected tab reaches the strip edge and
          // merges with the content panel below, like a browser tab.
          decoration: BoxDecoration(
            color: widget.transparentBackground
                ? Colors.transparent
                : colorScheme.surfaceContainerHigh,
          ),
          child: Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              horizontalPadding,
              _kStripTopPadding,
              horizontalPadding,
              0,
            ),
            child: Row(
              mainAxisSize: widget.fillWidth
                  ? MainAxisSize.max
                  : MainAxisSize.min,
              children: [
                if (pinnedTabs.isNotEmpty && pinnedRegionWidth > 0)
                  SizedBox(
                    key: const ValueKey<String>('session_tab_pinned_region'),
                    width: pinnedRegionWidth,
                    child: Listener(
                      onPointerSignal: (event) => _handlePointerSignal(
                        event,
                        controller: _pinnedScrollController,
                      ),
                      child: ScrollConfiguration(
                        behavior: ScrollConfiguration.of(
                          context,
                        ).copyWith(scrollbars: false),
                        child: SingleChildScrollView(
                          key: const ValueKey<String>(
                            'session_tab_pinned_region_scroll_view',
                          ),
                          controller: _pinnedScrollController,
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (final tab in pinnedTabs)
                                _buildTab(
                                  context,
                                  tab,
                                  tab.isSelected
                                      ? math.min(
                                          selectedPinnedContentWidth,
                                          selectedPinnedWidth,
                                        )
                                      : _kPinnedSessionTabWidth,
                                  compactPinned: !tab.isSelected,
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
                        behavior: ScrollConfiguration.of(
                          context,
                        ).copyWith(scrollbars: false),
                        child: SingleChildScrollView(
                          key: const ValueKey<String>(
                            'session_tab_strip_scroll_view',
                          ),
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

  void _setHovered(SessionTabIdentity? identity) {
    if (!mounted || _hoveredIdentity == identity) {
      return;
    }
    setState(() => _hoveredIdentity = identity);
  }

  void _handlePointerDown(SessionTabRecord tab, PointerDownEvent event) {
    _lastPointerIdentity = tab.identity;
    _lastPointerGlobalPosition = event.position;
    if (event.buttons & kMiddleMouseButton != 0) {
      _handleClose(tab);
    }
  }

  Offset _contextMenuPosition(SessionTabRecord tab) {
    if (_lastPointerIdentity == tab.identity &&
        _lastPointerGlobalPosition != null) {
      return _lastPointerGlobalPosition!;
    }
    final renderObject = _tabKeys[tab.identity]?.currentContext
        ?.findRenderObject();
    if (renderObject is RenderBox) {
      return renderObject.localToGlobal(renderObject.size.center(Offset.zero));
    }
    return Offset.zero;
  }

  String _displayTitle(BuildContext context, SessionTabRecord tab) {
    final trimmed = tab.title.trim();
    return trimmed.isEmpty ? context.l10n.sessionExportUntitled : trimmed;
  }

  double _measureTitleWidth(
    BuildContext context,
    String title,
    bool selected,
  ) {
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

  /// Width derived from the tab content, clamped between the minimum and the
  /// maximum. Only the first line of the title is measured because the tab
  /// paints a single ellipsized line. The trailing usage button width is fixed
  /// in production (40px compact / 32px desktop, plus 10px padding); a custom
  /// trailing builder only needs to stay within those bounds.
  double _contentTabWidth(
    BuildContext context,
    SessionTabRecord tab,
    Widget? trailing, {
    required double maxTabWidth,
    required double minTabWidth,
  }) {
    final trailingWidth = trailing == null
        ? _kTabShoulder
        : (widget.isCompact ? 40.0 : 32.0) + _kTabShoulder;
    final chrome = _kTabShoulder + 28 + 7 + 2 + trailingWidth;
    final title = _displayTitle(context, tab).split('\n').first;
    final titleWidth = _measureTitleWidth(context, title, tab.isSelected);
    // The minimum is applied last so a viewport narrower than the minimum
    // still keeps the tab at its floor and lets the strip scroll.
    return math.max(
      minTabWidth,
      math.min(
        maxTabWidth,
        (chrome + titleWidth + _kTabWidthSlack).ceilToDouble(),
      ),
    );
  }

  Widget _buildTab(
    BuildContext context,
    SessionTabRecord tab,
    double tabWidth, {
    bool compactPinned = false,
    Widget? trailing,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final title = _displayTitle(context, tab);
    final key = sessionTabIdentityKey(tab.identity);
    final selected = tab.isSelected;
    final project = _projectForTab(tab);
    final topRadius = selected ? _kActiveTabTopRadius : _kInactiveTabTopRadius;
    final radius = BorderRadius.vertical(top: Radius.circular(topRadius));
    final foreground = selected
        ? colorScheme.onSurface
        : colorScheme.onSurfaceVariant;
    final hovered = _hoveredIdentity == tab.identity;

    void openContextMenu({required bool haptic}) {
      unawaited(
        widget.onContextMenu(tab, _contextMenuPosition(tab), haptic: haptic),
      );
    }

    return MouseRegion(
      key: ValueKey<String>('session_tab_item_$key'),
      onEnter: (_) => _setHovered(tab.identity),
      onExit: (_) => _setHovered(null),
      child: Listener(
        onPointerDown: (event) => _handlePointerDown(tab, event),
        child: Focus(
          canRequestFocus: false,
          skipTraversal: true,
          child: SizedBox(
            key: _tabKeys.putIfAbsent(tab.identity, GlobalKey.new),
            width: tabWidth,
            child: Material(
              key: ValueKey<String>('session_tab_$key'),
              // The selected tab shares the content surface colour, which is what
              // creates the visual continuity with the chat panel underneath. No
              // border on any side: a bottom stroke would draw a hairline between
              // the tab and the content it is supposed to be joined to.
              color: selected
                  ? colorScheme.surface
                  : hovered
                  ? colorScheme.surface.withValues(alpha: 0.45)
                  : Colors.transparent,
              shape: _ChromeTabBorder(
                topRadius: topRadius,
                // The selected tab keeps the browser-style flare; inactive
                // tabs drop it so their silhouette stays quiet and narrow.
                shoulder: selected ? _kTabShoulder : 0,
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Row(
                      children: [
                        Expanded(
                          child: CallbackShortcuts(
                            bindings: <ShortcutActivator, VoidCallback>{
                              const SingleActivator(
                                LogicalKeyboardKey.contextMenu,
                              ): () =>
                                  openContextMenu(haptic: false),
                              const SingleActivator(
                                LogicalKeyboardKey.f10,
                                shift: true,
                              ): () =>
                                  openContextMenu(haptic: false),
                              const SingleActivator(
                                LogicalKeyboardKey.delete,
                              ): () =>
                                  _handleClose(tab),
                            },
                            child: Semantics(
                              button: true,
                              selected: selected,
                              label: _semanticLabel(context, tab, title),
                              onTap: () => _handleActivate(tab),
                              onDismiss: () => _handleClose(tab),
                              onLongPress: () => openContextMenu(haptic: true),
                              customSemanticsActions:
                                  <CustomSemanticsAction, VoidCallback>{
                                    CustomSemanticsAction(
                                      label: context.l10n.chatSessionActions,
                                    ): () =>
                                        openContextMenu(haptic: false),
                                  },
                              child: Tooltip(
                                message: title,
                                excludeFromSemantics: true,
                                child: ExcludeSemantics(
                                  child: InkWell(
                                    key: ValueKey<String>(
                                      'session_tab_activate_$key',
                                    ),
                                    focusNode: _tabFocusNodes.putIfAbsent(
                                      tab.identity,
                                      () => FocusNode(
                                        debugLabel: 'Session tab $key',
                                      ),
                                    ),
                                    borderRadius: radius,
                                    overlayColor:
                                        WidgetStateProperty.resolveWith<Color?>(
                                          (states) {
                                            if (states.contains(
                                              WidgetState.pressed,
                                            )) {
                                              return colorScheme.primary
                                                  .withValues(alpha: 0.18);
                                            }
                                            if (states.contains(
                                              WidgetState.focused,
                                            )) {
                                              return colorScheme.primary
                                                  .withValues(alpha: 0.14);
                                            }
                                            if (states.contains(
                                              WidgetState.hovered,
                                            )) {
                                              return colorScheme.primary
                                                  .withValues(alpha: 0.09);
                                            }
                                            return null;
                                          },
                                        ),
                                    onTap: () => _handleActivate(tab),
                                    onDoubleTap: () => _handleClose(tab),
                                    onSecondaryTapUp: (details) => unawaited(
                                      widget.onContextMenu(
                                        tab,
                                        details.globalPosition,
                                        haptic: false,
                                      ),
                                    ),
                                    onLongPress: () =>
                                        openContextMenu(haptic: true),
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        minHeight: _kTabMinHeight,
                                      ),
                                      child: Padding(
                                        padding: EdgeInsetsDirectional.only(
                                          start: compactPinned
                                              ? _kPinnedInactiveTabInset
                                              : _kTabShoulder,
                                        ),
                                        child: Row(
                                          children: [
                                            _buildLeading(
                                              context,
                                              tab,
                                              project,
                                              title,
                                            ),
                                            if (!compactPinned) ...[
                                              const SizedBox(width: 7),
                                              Expanded(
                                                child: Text(
                                                  title,
                                                  key: ValueKey<String>(
                                                    'session_tab_title_$key',
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .labelLarge
                                                      ?.copyWith(
                                                        color: foreground,
                                                        fontWeight: selected
                                                            ? FontWeight.w700
                                                            : FontWeight.w600,
                                                      ),
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
                            width: compactPinned
                                ? _kPinnedInactiveTabInset
                                : _kTabShoulder,
                          )
                        else
                          Padding(
                            padding: const EdgeInsetsDirectional.only(
                              end: _kTabShoulder,
                            ),
                            child: trailing,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeading(
    BuildContext context,
    SessionTabRecord tab,
    Project? project,
    String title,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final key = sessionTabIdentityKey(tab.identity);
    late final Widget leading;
    if (tab.hasUnseenError) {
      leading = _attentionIcon(
        key: ValueKey<String>('session_tab_leading_error_$key'),
        icon: Symbols.error,
        background: colorScheme.errorContainer,
        foreground: colorScheme.onErrorContainer,
      );
    } else if (tab.hasUnseenQuestion) {
      leading = _attentionIcon(
        key: ValueKey<String>('session_tab_leading_question_$key'),
        icon: Symbols.help,
        background: colorScheme.tertiaryContainer,
        foreground: colorScheme.onTertiaryContainer,
      );
    } else if (tab.hasUnseenCompletion) {
      leading = _attentionIcon(
        key: ValueKey<String>('session_tab_leading_completion_$key'),
        icon: Symbols.notifications_active,
        background: colorScheme.primaryContainer,
        foreground: colorScheme.onPrimaryContainer,
      );
    } else {
      final preset = SessionTabIconPreset.fromId(tab.iconPresetId);
      if (preset != null) {
        leading = Tooltip(
          message: sessionTabIconPresetLabel(context.l10n, preset),
          child: Icon(
            preset.icon,
            key: ValueKey<String>('session_tab_custom_icon_$key'),
            size: 20,
            color: tab.isSelected
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
          ),
        );
      } else {
        final resolvedProject = project ?? _fallbackProject(tab);
        final projectLabel = resolvedProject.name.trim().isEmpty
            ? fileBasename(tab.identity.directory)
            : resolvedProject.name.trim();
        leading = Tooltip(
          message: projectLabel,
          child: ProjectIcon(
            key: ValueKey<String>('session_tab_project_icon_$key'),
            project: resolvedProject,
            size: 20,
            color: tab.isSelected
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
            autoDiscover:
                project != null && widget.openProjectIds.contains(project.id),
          ),
        );
      }
    }

    return SizedBox(
      key: ValueKey<String>('session_tab_leading_$key'),
      width: 28,
      height: 28,
      child: Stack(
        alignment: Alignment.center,
        children: [
          leading,
          if (tab.isBusy)
            PositionedDirectional(
              end: 0,
              bottom: 0,
              child: Container(
                key: ValueKey<String>(
                  'session_tab_busy_${tab.status.name}_$key',
                ),
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: tab.status == SessionStatusType.retry
                      ? colorScheme.tertiary
                      : colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Symbols.sync_rounded,
                  size: 9,
                  color: tab.status == SessionStatusType.retry
                      ? colorScheme.onTertiary
                      : colorScheme.onPrimary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _attentionIcon({
    required Key key,
    required IconData icon,
    required Color background,
    required Color foreground,
  }) {
    return Container(
      key: key,
      width: 26,
      height: 26,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: Icon(icon, size: 16, color: foreground),
    );
  }

  String _semanticLabel(
    BuildContext context,
    SessionTabRecord tab,
    String title,
  ) {
    final base = switch ((
      tab.hasUnseenError,
      tab.hasUnseenQuestion,
      tab.hasUnseenCompletion,
    )) {
      (true, _, _) => context.l10n.sessionHasError(title),
      (false, true, _) => context.l10n.sessionNeedsInput(title),
      (false, false, true) => context.l10n.sessionHasNewReply(title),
      _ => context.l10n.chatSessionChatSessionSession(title),
    };
    if (tab.status == SessionStatusType.retry) {
      return '$base ${context.l10n.chatStatusRetry}';
    }
    if (tab.status == SessionStatusType.busy) {
      return '$base ${context.l10n.chatStatusBusy}';
    }
    return base;
  }

  Project? _projectForTab(SessionTabRecord tab) {
    for (final project in widget.projects) {
      if (areEquivalentFilePaths(project.path, tab.identity.directory)) {
        return project;
      }
    }
    final projectId = tab.projectId?.trim();
    if (projectId == null || projectId.isEmpty) {
      return null;
    }
    for (final project in widget.projects) {
      if (project.id == projectId) {
        return project;
      }
    }
    return null;
  }

  Project _fallbackProject(SessionTabRecord tab) {
    final directoryLabel = fileBasename(tab.identity.directory);
    return Project(
      id: tab.projectId?.trim().isNotEmpty ?? false
          ? tab.projectId!.trim()
          : tab.identity.directory,
      name: directoryLabel,
      path: tab.identity.directory,
      createdAt: DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  SessionTabIdentity? _selectedIdentity() {
    for (final tab in widget.tabs) {
      if (tab.isSelected) {
        return tab.identity;
      }
    }
    return null;
  }

  void _handleClose(SessionTabRecord tab) {
    final fallback = sessionTabCloseFallback(widget.tabs, tab.identity);
    widget.onClose(tab);
    if (fallback == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _tabFocusNodes[fallback.identity]?.requestFocus();
    });
  }

  void _handleActivate(SessionTabRecord tab) {
    widget.onActivate(tab);
    _scheduleEnsureSelectedVisible(tab.identity);
  }

  void _scheduleEnsureSelectedVisible(SessionTabIdentity? identity) {
    _pendingEnsureVisibleIdentity = identity;
    if (identity == null || _ensureVisibleScheduled) {
      return;
    }
    _ensureVisibleScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureVisibleScheduled = false;
      if (!mounted) {
        return;
      }
      final pendingIdentity = _pendingEnsureVisibleIdentity;
      _pendingEnsureVisibleIdentity = null;
      if (pendingIdentity == null || _selectedIdentity() != pendingIdentity) {
        return;
      }
      final tabContext = _tabKeys[pendingIdentity]?.currentContext;
      final selectedIndex = widget.tabs.indexWhere(
        (tab) => tab.identity == pendingIdentity,
      );
      final selectedTab = selectedIndex < 0 ? null : widget.tabs[selectedIndex];
      final controller = selectedTab?.isPinned ?? false
          ? _pinnedScrollController
          : _scrollController;
      if (!controller.hasClients || tabContext == null) {
        _scheduleEnsureSelectedVisible(pendingIdentity);
        return;
      }
      final tabRenderObject = tabContext.findRenderObject();
      if (tabRenderObject == null) {
        _scheduleEnsureSelectedVisible(pendingIdentity);
        return;
      }
      final viewport = RenderAbstractViewport.maybeOf(tabRenderObject);
      if (viewport == null) {
        _scheduleEnsureSelectedVisible(pendingIdentity);
        return;
      }
      final position = controller.position;
      // Skip the animation when the selected tab is already fully visible:
      // width changes of unrelated tabs must not yank the user's scroll.
      // A tab fully inside the viewport satisfies
      // revealTrailing <= pixels <= revealLeading; the interval is empty when
      // the tab is wider than the viewport, so it never skips then.
      final revealLeading = viewport
          .getOffsetToReveal(tabRenderObject, 0.0)
          .offset;
      final revealTrailing = viewport
          .getOffsetToReveal(tabRenderObject, 1.0)
          .offset;
      if (revealTrailing <= position.pixels &&
          position.pixels <= revealLeading) {
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

  void _handlePointerSignal(
    PointerSignalEvent event, {
    required ScrollController controller,
  }) {
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
    final next = (controller.offset + delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    controller.jumpTo(next.toDouble());
  }
}
