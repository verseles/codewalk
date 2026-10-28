import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../shared/l10n/generated/v2_localizations.dart';
import '../../shared/l10n/l10n_context.dart';
import '../../shared/theme/app_shapes.dart';
import '../../shared/theme/app_visual_style_tokens.dart';
import '../../shared/theme/chat_appearance.dart';
import '../../shared/widgets/app_indeterminate_progress.dart';
import 'session_message_info.dart';
import 'session_timeline_projection.dart';
import 'session_tool_details_dialog.dart';
import 'session_tool_result.dart';

/// The header of a finished turn's work, like the retained reference's: how
/// many messages the work spans and the control that shows or hides it.
class SessionWorkGroupHeader extends StatelessWidget {
  const SessionWorkGroupHeader({
    super.key,
    required this.row,
    required this.onToggle,
  });

  final SessionWorkGroupRow row;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.v2L10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = theme.visualStyleTokens;
    final title = row.messageCount == 1
        ? l10n.chatWorkMessageOne
        : l10n.chatWorkMessagesMultiple(row.messageCount);
    return ConversationTextScale(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: DecoratedBox(
          key: ValueKey('work-group-${row.id}'),
          decoration: BoxDecoration(
            color: tokens.isRefined
                ? tokens.mutedControlSurface
                : scheme.surfaceContainerHighest.withValues(alpha: 0.45),
            borderRadius: tokens.isRefined
                ? tokens.cardRadius
                : BorderRadius.circular(12),
            border: Border.all(
              color: tokens.isRefined
                  ? tokens.separator
                  : scheme.outlineVariant.withValues(alpha: 0.5),
              width: tokens.isRefined ? tokens.enabledBorderWidth : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(12, 4, 4, 4),
            child: Row(
              children: [
                Icon(
                  Symbols.account_tree_rounded,
                  size: 18,
                  color: scheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  key: ValueKey('work-group-toggle-${row.id}'),
                  onPressed: onToggle,
                  child: Text(
                    row.expanded ? l10n.chatWorkHide : l10n.chatWorkExpand,
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

/// A run of tool calls shown together, like the retained reference's tool
/// chain: a count-first summary with what is still running or needs the
/// reader, and every call on demand, each opening its details.
///
/// A message that opens inside the run keeps its details: closed, the run
/// offers the first such message's; open, each call that opens a message
/// offers its own.
class SessionToolRun extends StatelessWidget {
  const SessionToolRun({super.key, required this.row, required this.onToggle});

  final SessionToolRunRow row;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.v2L10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final compact = MediaQuery.sizeOf(context).width < 600;
    final tools = row.tools;
    final counts = {for (final value in ToolProgress.values) value: 0};
    for (final tool in tools) {
      counts.update(toolProgress(tool), (count) => count + 1);
    }
    final calls = l10n.chatMessageToolChainCallsCompact(tools.length);
    final title = row.expanded
        ? l10n.chatMessageToolCallsTitle
        : compact
        ? calls
        : _describe(l10n, tools);
    final progress = [
      if (row.expanded) calls,
      if (row.expanded && counts[ToolProgress.done]! > 0)
        l10n.chatMessageToolDoneCount(counts[ToolProgress.done]!),
      if (counts[ToolProgress.running]! > 0)
        l10n.chatMessageToolRunningCount(counts[ToolProgress.running]!),
      if (counts[ToolProgress.queued]! > 0)
        l10n.chatMessageToolQueuedCount(counts[ToolProgress.queued]!),
      if (counts[ToolProgress.attention]! > 0)
        l10n.chatMessageToolAttentionCount(counts[ToolProgress.attention]!),
    ].join(' • ');
    final opening = row.expanded
        ? null
        : [
            for (final (index, tool) in tools.indexed)
              if (row.messageHeaders[index]) tool.meta.message,
          ].nonNulls.firstOrNull;
    return ConversationTextScale(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: DecoratedBox(
          key: ValueKey('tool-run-${row.id}'),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.36),
            borderRadius: AppShapes.borderSmall,
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 4, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Symbols.account_tree, size: 16, color: scheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            key: ValueKey('tool-run-title-${row.id}'),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (progress.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                progress,
                                key: ValueKey('tool-run-progress-${row.id}'),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: counts[ToolProgress.attention]! > 0
                                      ? scheme.error
                                      : scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (opening != null) MessageElapsedChip(message: opening),
                    TextButton(
                      key: ValueKey('tool-run-toggle-${row.id}'),
                      onPressed: onToggle,
                      child: Text(
                        row.expanded
                            ? l10n.chatMessageHide
                            : compact
                            ? l10n.chatMessageShow
                            : l10n.chatMessageDetails,
                      ),
                    ),
                  ],
                ),
                if (row.expanded)
                  for (final (index, tool) in tools.indexed)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(top: 8, end: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: SessionToolResult(item: tool)),
                          if (tool.meta.message case final message?
                              when row.messageHeaders[index])
                            MessageElapsedChip(message: message),
                        ],
                      ),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The first two calls by name, and how many more there are.
  static String _describe(V2Localizations l10n, List<TimelineItem> tools) {
    final names = [
      for (final tool in tools)
        if (toolTitle(tool).trim() case final name when name.isNotEmpty) name,
    ];
    if (names.isEmpty) {
      return l10n.chatMessageToolChainCallsCompact(tools.length);
    }
    final shown = names.take(2).join(' • ');
    final more = names.length - 2;
    return more > 0 ? '$shown • ${l10n.chatMessageToolChainMore(more)}' : shown;
  }
}

/// Where the Block render mode holds the rest of a turn in flight, like the
/// retained reference's compact generation placeholder.
class SessionGenerationPlaceholder extends StatelessWidget {
  const SessionGenerationPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.v2L10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = theme.visualStyleTokens;
    return ConversationTextScale(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: tokens.isRefined
                  ? tokens.cardSurface
                  : scheme.surfaceContainerHigh,
              borderRadius: tokens.isRefined
                  ? tokens.cardRadius
                  : AppShapes.borderLarge,
              border: Border.all(
                color: tokens.isRefined
                    ? tokens.separator
                    : scheme.outlineVariant.withValues(alpha: 0.35),
                width: tokens.isRefined ? tokens.enabledBorderWidth : 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppIndeterminateRing(
                    size: 18,
                    strokeWidth: 2,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.chatBlockResponsePendingTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.chatBlockResponsePendingDescription,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
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
}
