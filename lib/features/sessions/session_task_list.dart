import 'dart:async';
import 'dart:math';

import 'package:codewalk_core/codewalk_core.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../shared/l10n/generated/v2_localizations.dart';
import '../../shared/l10n/l10n_context.dart';
import '../../shared/theme/app_surface_tokens.dart';
import '../../shared/theme/chat_appearance.dart';
import '../../shared/widgets/app_indeterminate_progress.dart';
import 'session_timeline_tile.dart';

/// Top pinned, read-only visual task list for a live conversation.
///
/// Consumes only canonical [PlanSnapshot] / [PlanEntry] / [PlanStatus] types
/// from `codewalk_core`, so every harness that produces structured plans shares
/// the same surface.
class SessionTaskListPanel extends StatefulWidget {
  const SessionTaskListPanel({
    super.key,
    required this.plan,
    required this.collapsed,
    required this.onToggleCollapsed,
    this.forceCollapsed = false,
    this.maxListHeight,
  });

  /// Baseline height of the collapsed panel at 1.0x text scale.
  static const double collapsedHeight = 58.0;

  /// Effective reserved height of the collapsed panel accounting for the
  /// ambient system text scaler and conversation text scale, used by
  /// `SessionLivePage` when partitioning viewport chrome.
  static double collapsedHeightOf(BuildContext context) {
    final convScale =
        ChatAppearance.maybeOf(context)?.conversationTextScale ?? 1;
    final scaledLine = MediaQuery.textScalerOf(context).scale(14 * convScale);
    final header = max(44.0, scaledLine * 1.45 + 14.0);
    // Outer top(6)+bottom(2) + borders(2) + 3px progress bar + header.
    return (header + 13.0).clamp(collapsedHeight, 140.0).toDouble();
  }

  /// Maximum vertical budget reserved when the panel is expanded inside a
  /// viewport of [bodyHeight] logical pixels, scaling with text size and
  /// reserving an extra wrapped-header run on narrow high-scale viewports.
  static double expandedHeightOf(BuildContext context, double bodyHeight) {
    final baseHeader = collapsedHeightOf(context);
    final compact = MediaQuery.sizeOf(context).width < 600;
    final convScale =
        ChatAppearance.maybeOf(context)?.conversationTextScale ?? 1;
    final scaledLine = MediaQuery.textScalerOf(context).scale(14 * convScale);
    final wrapAllowance = compact && scaledLine > 18
        ? (scaledLine * 1.45 + 6.0).clamp(24.0, 56.0).toDouble()
        : 0.0;
    return baseHeader + wrapAllowance + listMaxHeightFor(bodyHeight);
  }

  /// The rows the expanded list shows at once; a longer list scrolls, with
  /// the task in progress in the middle (#550).
  static const visibleRows = 5;

  /// Scrollable list height cap for a viewport of [bodyHeight] logical pixels.
  static double listMaxHeightFor(double bodyHeight) =>
      min(220.0, max(72.0, bodyHeight * 0.28));

  final PlanSnapshot plan;
  final bool collapsed;
  final VoidCallback onToggleCollapsed;

  /// Temporarily collapses the panel (e.g. on a short viewport or open mobile
  /// keyboard) without mutating the user's persisted [collapsed] preference.
  final bool forceCollapsed;

  /// Explicit cap for the expanded scrollable list; defaults to `220.0`.
  final double? maxListHeight;

  @override
  State<SessionTaskListPanel> createState() => _SessionTaskListPanelState();
}

class _SessionTaskListPanelState extends State<SessionTaskListPanel>
    with WidgetsBindingObserver {
  static const _progressDuration = Duration(milliseconds: 260);
  static const _expandDuration = Duration(milliseconds: 200);
  static const _scrollDuration = Duration(milliseconds: 200);

  final _scrollController = ScrollController();
  bool _keyboardOpen = false;

  /// The height of one row as last laid out.
  double _rowExtent = 0;
  String? _lastScrollTarget;
  bool _wasCollapsed = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncKeyboardInset();
    _maybeScheduleAutoScroll();
  }

  @override
  void didChangeMetrics() {
    if (!mounted) return;
    final open = _readKeyboardOpen();
    if (open != _keyboardOpen) {
      setState(() => _keyboardOpen = open);
      _maybeScheduleAutoScroll();
    }
    // A window of another size shows another number of rows.
    _recenter();
  }

  /// Centers the task in progress again after the layout changed.
  void _recenter() {
    _lastScrollTarget = null;
    _maybeScheduleAutoScroll();
  }

  @override
  void didUpdateWidget(covariant SessionTaskListPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _maybeScheduleAutoScroll();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    super.dispose();
  }

  bool _readKeyboardOpen() {
    final view = View.maybeOf(context);
    if (view == null) return false;
    return view.viewInsets.bottom > 0;
  }

  void _syncKeyboardInset() {
    _keyboardOpen = _readKeyboardOpen();
  }

  bool _isCompact(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 600;

  bool _effectiveForceCollapsed(BuildContext context) =>
      widget.forceCollapsed || (_keyboardOpen && _isCompact(context));

  bool _effectiveCollapsed(BuildContext context) =>
      _effectiveForceCollapsed(context) || widget.collapsed;

  String _entryKey(int index, PlanEntry entry) => '$index:${entry.id}';

  void _maybeScheduleAutoScroll() {
    final collapsed = _effectiveCollapsed(context);
    final entries = widget.plan.entries;
    final currentIndex = planCurrentIndex(entries);
    final activeEntry =
        currentIndex >= 0 &&
            entries[currentIndex].status.known == PlanStatus.inProgress
        ? entries[currentIndex]
        : null;
    final justExpanded = _wasCollapsed && !collapsed;
    _wasCollapsed = collapsed;
    if (collapsed || activeEntry == null) return;
    final rowKey = _entryKey(currentIndex, activeEntry);
    final target =
        '${widget.plan.anchor?.orderKey ?? ''}:$rowKey:${activeEntry.title}';
    if (!justExpanded && target == _lastScrollTarget) return;
    _lastScrollTarget = target;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _effectiveCollapsed(context) ||
          !_scrollController.hasClients) {
        return;
      }
      // The task in progress in the middle of what the list shows: two rows
      // before it and two after when it shows five, fewer when it is
      // shorter.
      final position = _scrollController.position;
      final rowTop = 4 + currentIndex * _rowExtent;
      final offset = (rowTop - (position.viewportDimension - _rowExtent) / 2)
          .clamp(0.0, position.maxScrollExtent)
          .toDouble();
      if (AppIndeterminate.motion(context)) {
        unawaited(
          _scrollController.animateTo(
            offset,
            duration: _scrollDuration,
            curve: Curves.easeOut,
          ),
        );
      } else {
        _scrollController.jumpTo(offset);
      }
    });
  }

  /// The height of one row: a line of its text or its icon, whichever is
  /// taller, and its padding, at the text size in effect.
  static double _rowExtentOf(BuildContext context) {
    final painter = TextPainter(
      text: TextSpan(text: 'Ag', style: Theme.of(context).textTheme.bodySmall),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final line = painter.height;
    painter.dispose();
    return max(line, 17.0) + 10.0;
  }

  String _collapsedSummary(
    V2Localizations l10n,
    List<PlanEntry> entries,
    PlanProgress progress,
    int currentIndex, {
    required bool compact,
  }) {
    final displayTotal = progress.total > 0 ? progress.total : entries.length;
    if (currentIndex >= 0 &&
        entries[currentIndex].status.known == PlanStatus.inProgress) {
      final task = entries[currentIndex];
      return compact
          ? l10n.sessionTodoInProgressCompact(
              currentIndex + 1,
              entries.length,
              task.title,
            )
          : l10n.sessionTodoTaskProgress(
              currentIndex + 1,
              entries.length,
              task.title,
            );
    }
    final base = compact
        ? l10n.sessionTodoDoneCompact(progress.completed, displayTotal)
        : l10n.sessionTodoCompletedCount(progress.completed, displayTotal);
    if (progress.cancelled > 0) {
      return '$base · ${l10n.sessionTodoCancelledCount(progress.cancelled)}';
    }
    return base;
  }

  String _statusLabel(V2Localizations l10n, PlanStatus? status) =>
      switch (status) {
        PlanStatus.completed => l10n.liveSubagentsCompleted,
        PlanStatus.inProgress => l10n.chatMessageToolStatusInProgress,
        PlanStatus.pending => l10n.sessionTodoStatusPending,
        PlanStatus.cancelled => l10n.liveSubagentsCancelled,
        PlanStatus.unknown || null => l10n.liveSubagentsUnknown,
      };

  @override
  Widget build(BuildContext context) {
    final entries = widget.plan.entries;
    if (entries.isEmpty) return const SizedBox.shrink();

    final l10n = context.v2L10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = theme.surfaceTokens;
    final compact = _isCompact(context);
    final forceCollapsed = _effectiveForceCollapsed(context);
    final collapsed = forceCollapsed || widget.collapsed;
    final animate = AppIndeterminate.motion(context);

    final progress = planProgress(entries);
    final currentIndex = planCurrentIndex(entries);
    final displayTotal = progress.total > 0 ? progress.total : entries.length;
    final summaryText = _collapsedSummary(
      l10n,
      entries,
      progress,
      currentIndex,
      compact: compact,
    );
    final headerTitle = collapsed ? summaryText : l10n.sessionTodoTasks;
    final progressSemantic = l10n.sessionTodoProgressSemantic(
      progress.completed,
      displayTotal,
    );
    final headerSemanticParts = <String>[
      headerTitle,
      progressSemantic,
      if (!collapsed && progress.cancelled > 0)
        l10n.sessionTodoCancelledCount(progress.cancelled),
      if (progress.extraInProgress > 0)
        l10n.sessionTodoMoreInProgressSemantic(progress.extraInProgress),
    ];
    final headerTitleStyle = theme.textTheme.labelLarge?.copyWith(
      color: collapsed && progress.inProgress > 0
          ? scheme.onSurface
          : scheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );
    final listMaxHeight = widget.maxListHeight ?? 220.0;

    final progressBar = animate
        ? TweenAnimationBuilder<double>(
            duration: _progressDuration,
            curve: Curves.easeInOutCubic,
            tween: Tween<double>(end: progress.fraction),
            builder: (context, value, _) {
              return LinearProgressIndicator(
                key: const ValueKey('session-todo-progress-bar'),
                value: value.clamp(0.0, 1.0),
                minHeight: 3,
                backgroundColor: scheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
              );
            },
          )
        : LinearProgressIndicator(
            key: const ValueKey('session-todo-progress-bar'),
            value: progress.fraction.clamp(0.0, 1.0),
            minHeight: 3,
            backgroundColor: scheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
          );

    final expandedBody = collapsed
        ? const SizedBox.shrink()
        : Builder(
            // Inside the conversation's text scale, as the rows are.
            builder: (context) {
              final extent = _rowExtentOf(context);
              if (extent != _rowExtent) {
                // Rows of another height move the task in progress: it is
                // centered again.
                if (_rowExtent > 0) _recenter();
                _rowExtent = extent;
              }
              return ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: min(
                    listMaxHeight,
                    extent * SessionTaskListPanel.visibleRows + 10,
                  ),
                ),
                child: Scrollbar(
                  controller: _scrollController,
                  thumbVisibility:
                      entries.length > SessionTaskListPanel.visibleRows,
                  child: SingleChildScrollView(
                    key: const ValueKey('session-todo-list'),
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(6, 4, 6, 6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < entries.length; i++)
                          SizedBox(
                            height: extent,
                            child: _buildRow(context, i, entries[i], l10n),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );

    return ConversationTextScale(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          timelineSideInset(context),
          6,
          timelineSideInset(context),
          2,
        ),
        child: Material(
          key: const ValueKey('session-todo-panel'),
          color: tokens.panelSurface,
          shape: RoundedRectangleBorder(
            borderRadius: tokens.controlRadius,
            side: BorderSide(
              color: tokens.separator,
              width: tokens.enabledBorderWidth,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                button: true,
                enabled: !forceCollapsed,
                toggled: !collapsed,
                label: headerSemanticParts.join(', '),
                hint: collapsed ? l10n.chatWorkExpand : l10n.chatWorkHide,
                excludeSemantics: true,
                child: InkWell(
                  key: const ValueKey('session-todo-header'),
                  onTap: forceCollapsed ? null : widget.onToggleCollapsed,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 44),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      child: Row(
                        children: [
                          _buildHeaderIcon(
                            scheme,
                            progress,
                            l10n,
                            collapsed: collapsed,
                          ),
                          const SizedBox(width: 8),
                          if (collapsed) ...[
                            Expanded(
                              child: Text(
                                headerTitle,
                                key: const ValueKey('session-todo-header-text'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: headerTitleStyle,
                              ),
                            ),
                            if (progress.extraInProgress > 0) ...[
                              const SizedBox(width: 6),
                              Flexible(
                                flex: 0,
                                child: _buildCountPill(
                                  theme,
                                  scheme,
                                  l10n.sessionTodoMoreInProgress(
                                    progress.extraInProgress,
                                  ),
                                  key: const ValueKey(
                                    'session-todo-more-in-progress',
                                  ),
                                  highlighted: true,
                                ),
                              ),
                            ],
                          ] else
                            Expanded(
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    headerTitle,
                                    key: const ValueKey(
                                      'session-todo-header-text',
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: headerTitleStyle,
                                  ),
                                  _buildCountPill(
                                    theme,
                                    scheme,
                                    '${progress.completed}/$displayTotal',
                                    highlighted: progress.allCompleted,
                                  ),
                                  if (progress.cancelled > 0)
                                    _buildCountPill(
                                      theme,
                                      scheme,
                                      l10n.sessionTodoCancelledCount(
                                        progress.cancelled,
                                      ),
                                      key: const ValueKey(
                                        'session-todo-cancelled-summary',
                                      ),
                                    ),
                                  if (progress.extraInProgress > 0)
                                    _buildCountPill(
                                      theme,
                                      scheme,
                                      l10n.sessionTodoMoreInProgress(
                                        progress.extraInProgress,
                                      ),
                                      key: const ValueKey(
                                        'session-todo-more-in-progress',
                                      ),
                                      highlighted: true,
                                    ),
                                ],
                              ),
                            ),
                          const SizedBox(width: 4),
                          Icon(
                            collapsed
                                ? Symbols.expand_more_rounded
                                : Symbols.expand_less_rounded,
                            size: 18,
                            color: scheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Semantics(
                label: progressSemantic,
                value: '${(progress.fraction * 100).round()}%',
                child: ExcludeSemantics(child: progressBar),
              ),
              if (animate)
                AnimatedSize(
                  duration: _expandDuration,
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: expandedBody,
                )
              else
                expandedBody,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderIcon(
    ColorScheme scheme,
    PlanProgress progress,
    V2Localizations l10n, {
    required bool collapsed,
  }) {
    if (!collapsed) {
      return Icon(Symbols.checklist, size: 16, color: scheme.primary);
    }
    if (progress.inProgress > 0) {
      return Icon(
        Symbols.double_arrow,
        size: 16,
        color: scheme.primary,
        semanticLabel: l10n.chatMessageToolStatusInProgress,
      );
    }
    if (progress.allCompleted) {
      return Icon(Symbols.check_circle, size: 16, color: scheme.primary);
    }
    if (progress.allCancelled) {
      return Icon(Symbols.cancel, size: 16, color: scheme.onSurfaceVariant);
    }
    return Icon(Symbols.checklist, size: 16, color: scheme.onSurfaceVariant);
  }

  Widget _buildCountPill(
    ThemeData theme,
    ColorScheme scheme,
    String text, {
    Key? key,
    bool highlighted = false,
  }) {
    return DecoratedBox(
      key: key,
      decoration: BoxDecoration(
        color: highlighted
            ? scheme.primaryContainer
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(
            color: highlighted
                ? scheme.onPrimaryContainer
                : scheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildRow(
    BuildContext context,
    int index,
    PlanEntry entry,
    V2Localizations l10n,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = entry.status.known;
    final isCompleted = status == PlanStatus.completed;
    final isInProgress = status == PlanStatus.inProgress;
    final isCancelled = status == PlanStatus.cancelled;

    final icon = switch (status) {
      PlanStatus.completed => Icon(
        Symbols.check_box,
        size: 16,
        color: scheme.primary,
      ),
      PlanStatus.inProgress => Icon(
        Symbols.double_arrow,
        size: 16,
        color: scheme.primary,
        semanticLabel: l10n.chatMessageToolStatusInProgress,
      ),
      PlanStatus.cancelled => Icon(
        Symbols.cancel,
        size: 16,
        color: scheme.outline,
      ),
      PlanStatus.pending => Icon(
        Symbols.check_box_outline_blank,
        size: 16,
        color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
      ),
      PlanStatus.unknown ||
      null => Icon(Symbols.circle, size: 14, color: scheme.outline),
    };

    final textStyle = theme.textTheme.bodySmall?.copyWith(
      decoration: isCompleted ? TextDecoration.lineThrough : null,
      fontStyle: isCancelled ? FontStyle.italic : null,
      fontWeight: isInProgress ? FontWeight.w600 : null,
      color: isCompleted || isCancelled
          ? scheme.onSurfaceVariant.withValues(alpha: 0.68)
          : scheme.onSurface,
    );

    return KeyedSubtree(
      key: ValueKey(_entryKey(index, entry)),
      child: Semantics(
        label: '${entry.title}, ${_statusLabel(l10n, status)}',
        excludeSemantics: true,
        child: DecoratedBox(
          key: ValueKey('session-todo-item-${entry.id}'),
          decoration: BoxDecoration(
            color: isInProgress
                ? scheme.primaryContainer.withValues(alpha: 0.28)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(padding: const EdgeInsets.only(top: 1), child: icon),
                const SizedBox(width: 8),
                Expanded(
                  // One line each, so five rows show five tasks; the whole
                  // title stays in the row's label.
                  child: Text(
                    entry.title,
                    style: textStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
