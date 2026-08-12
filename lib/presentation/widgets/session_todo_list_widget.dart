import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../domain/entities/chat_session.dart';
import '../../l10n/generated/app_localizations.dart';
import '../theme/app_animations.dart';

class SessionTodoListWidget extends StatefulWidget {
  const SessionTodoListWidget({
    super.key,
    required this.todos,
    required this.collapsed,
    required this.onToggleCollapsed,
    this.maxVisibleItems = 5,
  });

  final List<SessionTodo> todos;
  final bool collapsed;
  final VoidCallback onToggleCollapsed;
  final int maxVisibleItems;

  @override
  State<SessionTodoListWidget> createState() => _SessionTodoListWidgetState();
}

class _SessionTodoListWidgetState extends State<SessionTodoListWidget> {
  static const Duration _allCompletedHideDelay = Duration(seconds: 3);
  static const double _itemHeight = 24;
  static const Duration _progressAnimationDuration = Duration(
    milliseconds: 260,
  );
  static const Curve _progressAnimationCurve = Curves.easeInOutCubic;

  final ScrollController _scrollController = ScrollController();
  Timer? _hideTimer;
  bool _hidden = false;

  @override
  void initState() {
    super.initState();
    _syncHideTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToInProgress();
    });
  }

  @override
  void didUpdateWidget(SessionTodoListWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncHideTimer();
    if (!widget.collapsed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToInProgress();
      });
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  bool get _allCompleted {
    return widget.todos.isNotEmpty &&
        widget.todos.every((t) => t.status == 'completed');
  }

  void _syncHideTimer() {
    if (_allCompleted) {
      if (_hideTimer == null) {
        _hideTimer = Timer(_allCompletedHideDelay, () {
          if (!mounted) return;
          setState(() => _hidden = true);
        });
      }
    } else {
      _hideTimer?.cancel();
      _hideTimer = null;
      if (_hidden) {
        setState(() => _hidden = false);
      }
    }
  }

  void _scrollToInProgress() {
    if (!_scrollController.hasClients) return;
    final index = widget.todos.indexWhere((t) => t.status == 'in_progress');
    if (index < 0) return;
    final target = index * _itemHeight;
    final maxScroll = _scrollController.position.maxScrollExtent;
    if (target <= maxScroll) {
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  bool _isCompactLayout(BuildContext context) {
    return MediaQuery.sizeOf(context).width < 600;
  }

  String _collapsedSummary(AppLocalizations? l10n, {required bool compact}) {
    final todos = widget.todos;
    final inProgressIndex = todos.indexWhere((t) => t.status == 'in_progress');
    if (inProgressIndex >= 0) {
      final task = todos[inProgressIndex];
      if (compact) {
        return l10n?.sessionTodoInProgressCompact(
              inProgressIndex + 1,
              todos.length,
            ) ??
            '${inProgressIndex + 1}/${todos.length} in progress';
      }
      return l10n?.sessionTodoTaskProgress(
            task.content,
            inProgressIndex + 1,
            todos.length,
          ) ??
          'Task ${inProgressIndex + 1}/${todos.length} ${task.content}';
    }
    final completedCount = todos.where((t) => t.status == 'completed').length;
    if (compact) {
      return l10n?.sessionTodoDoneCompact(completedCount, todos.length) ??
          '$completedCount/${todos.length} done';
    }
    return l10n?.sessionTodoCompletedCount(completedCount, todos.length) ??
        'Tasks $completedCount/${todos.length} completed';
  }

  int get _completedCount {
    return widget.todos.where((todo) => todo.status == 'completed').length;
  }

  double get _completionProgress {
    final total = widget.todos.length;
    if (total == 0) {
      return 0;
    }
    return _completedCount / total;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.todos.isEmpty || _hidden) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final needsScroll = widget.todos.length > widget.maxVisibleItems;
    final compactLayout = _isCompactLayout(context);
    final l10n = Localizations.of<AppLocalizations>(context, AppLocalizations);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: widget.onToggleCollapsed,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.collapsed
                          ? Symbols.expand_more_rounded
                          : Symbols.expand_less_rounded,
                      size: 18,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        widget.collapsed
                            ? _collapsedSummary(l10n, compact: compactLayout)
                            : l10n?.sessionTodoTasksCount(
                                    widget.todos.length,
                                  ) ??
                                  'Tasks (${widget.todos.length})',
                        style: textTheme.labelMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                SizedBox(
                  width: double.infinity,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: TweenAnimationBuilder<double>(
                      duration: _progressAnimationDuration,
                      curve: _progressAnimationCurve,
                      tween: Tween<double>(end: _completionProgress),
                      builder: (context, animatedValue, child) {
                        final normalizedValue = animatedValue.clamp(0.0, 1.0);
                        return LinearProgressIndicator(
                          key: const ValueKey<String>(
                            'session_todo_progress_bar',
                          ),
                          value: normalizedValue,
                          minHeight: 3,
                          backgroundColor: colorScheme.surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            colorScheme.primary,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: AppAnimations.standard,
          curve: AppAnimations.standardCurve,
          alignment: Alignment.topCenter,
          child: !widget.collapsed
              ? Padding(
                  padding: const EdgeInsets.only(left: 4, top: 2),
                  child: needsScroll
                      ? ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: widget.maxVisibleItems * _itemHeight,
                          ),
                          child: Scrollbar(
                            controller: _scrollController,
                            thumbVisibility: true,
                            child: ListView.builder(
                              controller: _scrollController,
                              itemCount: widget.todos.length,
                              itemExtent: _itemHeight,
                              padding: EdgeInsets.zero,
                              itemBuilder: (context, index) {
                                return _buildTodoItem(
                                  context,
                                  widget.todos[index],
                                );
                              },
                            ),
                          ),
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: widget.todos
                              .map((todo) {
                                return _buildTodoItem(context, todo);
                              })
                              .toList(growable: false),
                        ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildTodoItem(BuildContext context, SessionTodo todo) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isCompleted = todo.status == 'completed';
    final isInProgress = todo.status == 'in_progress';

    final statusIcon = isCompleted
        ? Icon(Symbols.check_box, size: 16, color: colorScheme.primary)
        : isInProgress
        ? SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
            ),
          )
        : Icon(
            Symbols.check_box_outline_blank,
            size: 16,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          );

    final priorityColor = switch (todo.priority) {
      'high' => colorScheme.error,
      'medium' => colorScheme.primary,
      _ => colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
    };

    return SizedBox(
      height: _itemHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          statusIcon,
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              todo.content,
              style: textTheme.bodySmall?.copyWith(
                decoration: isCompleted ? TextDecoration.lineThrough : null,
                color: isCompleted
                    ? colorScheme.onSurfaceVariant.withValues(alpha: 0.5)
                    : null,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: priorityColor,
            ),
          ),
        ],
      ),
    );
  }
}
