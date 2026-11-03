import 'dart:math' as math;

import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../platform/sessions/session_tabs_store.dart';
import '../../shared/l10n/l10n_context.dart';
import '../../shared/sessions/session_activity.dart';
import 'session_tab_icons.dart';
import 'session_tabs_controller.dart';
import 'sessions_controller.dart';

/// The common base icon and attention/busy indicators, also used by MRU rows.
class SessionTabGlyph extends StatelessWidget {
  const SessionTabGlyph({super.key, required this.tab, required this.tabs});
  final SessionTab tab;
  final SessionTabsController tabs;

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<SessionsController?>();
    final row = catalog?.findSession(tab.ref);
    final warm = tabs.warmViews.where((v) => v.session == tab.ref).firstOrNull;
    final execution = warm?.state?.execution ?? row?.execution;
    final marks = row == null
        ? <SessionActivityMark>[]
        : catalog!.activityMarks(row);
    final failed =
        execution?.lastOutcome?.kind.known == ExecutionOutcomeKind.failed;
    final waiting =
        marks.contains(SessionActivityMark.needsYou) ||
        const {
          ExecutionKind.waitingForInput,
          ExecutionKind.waitingForApproval,
        }.contains(execution?.kind.known);
    final busy =
        marks.contains(SessionActivityMark.running) ||
        const {
          ExecutionKind.running,
          ExecutionKind.retrying,
          ExecutionKind.interrupting,
        }.contains(execution?.kind.known);
    final scheme = Theme.of(context).colorScheme;
    final l = context.v2L10n;
    final preset = SessionTabIconPreset.fromId(tabs.iconFor(tab.ref));
    final glyph = failed
        ? Symbols.error
        : waiting
        ? Symbols.help
        : marks.contains(SessionActivityMark.unread)
        ? Symbols.notifications_active
        : preset?.icon ?? Icons.folder_open;
    return Semantics(
      label: [
        if (failed) l.sessionsActionFailed,
        if (waiting) l.liveNeedsYou,
        if (busy) l.liveRunning,
        if (marks.contains(SessionActivityMark.unread)) l.sessionsActionUnread,
      ].join(', '),
      child: SizedBox(
        width: 24,
        height: 24,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Icon(
              glyph,
              size: 19,
              color: failed
                  ? scheme.error
                  : waiting
                  ? scheme.tertiary
                  : null,
            ),
            if (busy)
              PositionedDirectional(
                end: -3,
                top: -3,
                child: Icon(
                  Symbols.sync_rounded,
                  size: 12,
                  color: scheme.secondary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The tab outline of v1 `AppTabBorder`: straight sides, a curved shoulder
/// into the bottom corners and a top radius. Private to the tab chip.
class _TabShoulderBorder extends ShapeBorder {
  const _TabShoulderBorder({required this.topRadius, required this.shoulder});

  final double topRadius;
  final double shoulder;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect, textDirection: textDirection);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final lowerCurveTop = rect.bottom - shoulder;
    final r = topRadius;
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
      _TabShoulderBorder(topRadius: topRadius * t, shoulder: shoulder * t);
}

/// A tab has no close button: double-tap, middle-click, Delete and semantic
/// dismiss close it locally. Its parent owns the session-actions menu.
class SessionTabChip extends StatelessWidget {
  const SessionTabChip({
    super.key,
    required this.tabs,
    required this.tab,
    required this.selected,
    required this.pinned,
    required this.maxWidth,
    required this.onTap,
    required this.onClose,
    required this.onPointerIntent,
  });
  final SessionTabsController tabs;
  final SessionTab tab;
  final bool selected;
  final bool pinned;
  final double maxWidth;
  final VoidCallback onTap;
  final VoidCallback onClose;
  final VoidCallback onPointerIntent;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    final title = tab.title.trim().isEmpty
        ? context.v2L10n.sessionExportUntitled
        : tab.title;
    final style = Theme.of(context).textTheme.labelLarge!;
    final painter = TextPainter(
      text: TextSpan(text: title, style: style),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
      textDirection: Directionality.of(context),
    )..layout();
    final upper = math.max(1.0, math.min(maxWidth, compact ? 278.2 : 317.2));
    final lower = math.min(
      upper,
      selected ? (compact ? 140.0 : 150.0) : (compact ? 100.0 : 120.0),
    );
    final width = pinned && !selected
        ? math.min(36.0, upper)
        // The selected tab also holds its close control (24 dp and a 2 dp gap).
        : (painter.width + 56 + (selected ? 26 : 0))
              .clamp(lower, upper)
              .toDouble();
    painter.dispose();
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 2, top: 3),
      child: CallbackShortcuts(
        bindings: {const SingleActivator(LogicalKeyboardKey.delete): onClose},
        child: Listener(
          onPointerDown: (event) {
            onPointerIntent();
            if (event.buttons & kMiddleMouseButton != 0) onClose();
          },
          child: Semantics(
            label: title,
            selected: selected,
            button: true,
            onDismiss: onClose,
            child: Tooltip(
              message: title,
              excludeFromSemantics: true,
              // Hover only: a touch long-press belongs to the tab menu.
              triggerMode: TooltipTriggerMode.manual,
              child: Material(
                key: ValueKey('session-tab-${tab.ref.storageKey}'),
                // v1: app_tab_strip.dart (content fill, shoulder and top radius).
                color: selected ? scheme.surface : Colors.transparent,
                shape: _TabShoulderBorder(
                  topRadius: selected ? 8 : 5,
                  // v1 app_tab_strip.dart: only the selected tab has the shoulder.
                  shoulder: selected ? 10 : 0,
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onTap,
                  onDoubleTap: onClose,
                  child: SizedBox(
                    width: width,
                    // v1 tab height (48 x 0.8). Below the 48 dp target by owner
                    // decision B (S7); recorded as an accessibility exception.
                    height: 38.4,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: pinned && !selected ? 4 : 10,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SessionTabGlyph(tab: tab, tabs: tabs),
                          if (!pinned || selected) ...[
                            const SizedBox(width: 6),
                            Expanded(
                              child: ExcludeSemantics(
                                child: Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: style,
                                ),
                              ),
                            ),
                          ],
                          // The selected tab keeps the v1 trailing close control.
                          if (selected) ...[
                            const SizedBox(width: 2),
                            // Keyboard users close with Delete on the focused
                            // tab, so the button stays out of the focus order.
                            ExcludeFocus(
                              child: IconButton(
                                key: ValueKey(
                                  'session-tab-close-${tab.ref.storageKey}',
                                ),
                                tooltip: context.v2L10n.chatClose,
                                style: IconButton.styleFrom(
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints.tightFor(
                                  width: 24,
                                  height: 24,
                                ),
                                iconSize: 16,
                                onPressed: onClose,
                                icon: const Icon(Symbols.close),
                              ),
                            ),
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
    );
  }
}
