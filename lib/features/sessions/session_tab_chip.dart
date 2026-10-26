import 'dart:math' as math;

import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
        ? Icons.error_outline
        : waiting
        ? Icons.help_outline
        : marks.contains(SessionActivityMark.unread)
        ? Icons.check_circle_outline
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
                child: Icon(Icons.sync, size: 12, color: scheme.secondary),
              ),
          ],
        ),
      ),
    );
  }
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
        : (painter.width + 56).clamp(lower, upper).toDouble();
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
                color: selected
                    ? scheme.secondaryContainer
                    : scheme.surfaceContainer,
                shape: RoundedRectangleBorder(
                  side: BorderSide(
                    color: selected ? scheme.primary : Colors.transparent,
                  ),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(selected ? 8 : 5),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onTap,
                  onDoubleTap: onClose,
                  child: SizedBox(
                    width: width,
                    height: 48,
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
