import 'dart:math';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../shared/l10n/generated/v2_localizations.dart';
import '../../shared/l10n/l10n_context.dart';
import '../../shared/theme/app_surface_tokens.dart';
import '../../shared/theme/chat_appearance.dart';
import '../../shared/widgets/app_indeterminate_progress.dart';
import 'session_message_info.dart';
import 'session_timeline_projection.dart';

/// Builds the fixed-order descriptive activity fragments for [work], omitting
/// zero categories: edited, explored, searched, fetched, commands, skills,
/// thought, and other steps.
List<String> activitySummaryParts(
  List<TimelineItem> work,
  V2Localizations l10n,
) {
  var edited = 0;
  var explored = 0;
  var searched = 0;
  var fetched = 0;
  var commands = 0;
  var skills = 0;
  var thought = 0;
  var steps = 0;

  for (final item in work) {
    switch (item) {
      case Reasoning():
        thought++;
      case ShellRun():
        commands++;
      case ToolCall(:final kind):
        switch (kind.known) {
          case ToolKind.edit || ToolKind.write:
            edited++;
          case ToolKind.read:
            explored++;
          case ToolKind.search || ToolKind.webSearch:
            searched++;
          case ToolKind.fetch:
            fetched++;
          case ToolKind.shell:
            commands++;
          case ToolKind.skill:
            skills++;
          case ToolKind.question || ToolKind.mcp || ToolKind.other || null:
            steps++;
          case ToolKind.subagent:
            steps++;
        }
      default:
        steps++;
    }
  }

  return [
    if (edited > 0) l10n.activityEdited(edited),
    if (explored > 0) l10n.activityExplored(explored),
    if (searched > 0) l10n.activitySearched(searched),
    if (fetched > 0) l10n.activityFetched(fetched),
    if (commands > 0) l10n.activityCommands(commands),
    if (skills > 0) l10n.activitySkills(skills),
    if (thought > 0) l10n.activityThought(thought),
    if (steps > 0) l10n.activitySteps(steps),
  ];
}

/// The quiet single-line summary header of a collapsed activity stretch,
/// showing descriptive counts plus running/failure indicators and expanding
/// its compact rows in place on tap.
class SessionActivityStretchHeader extends StatelessWidget {
  const SessionActivityStretchHeader({
    super.key,
    required this.row,
    required this.onToggle,
  });

  final SessionActivityStretchRow row;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.v2L10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final quiet = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final parts = activitySummaryParts(row.work, l10n);
    final base = parts.isEmpty
        ? l10n.activitySteps(row.work.length)
        : parts.join(' · ');
    final runningText = row.runningCount > 0
        ? l10n.activityRunning(row.runningCount)
        : null;
    final failedText = row.failedCount > 0
        ? l10n.activityFailed(row.failedCount)
        : null;
    final fullLabel = [base, ?runningText, ?failedText].join(' · ');
    final opening = row.expanded ? null : row.openingMessage;

    final body = LayoutBuilder(
      builder: (context, constraints) {
        final tailCount =
            (runningText != null ? 1 : 0) + (failedText != null ? 1 : 0);
        final available = constraints.maxWidth.isFinite
            ? max(0.0, constraints.maxWidth - 48)
            : 360.0;
        final tailShare = tailCount > 1 ? 0.28 : 0.42;
        final tailCap = min(160.0, available * tailShare);
        return ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(6, 6, 8, 6),
            child: Row(
              children: [
                Icon(
                  row.expanded ? Symbols.expand_less : Symbols.expand_more,
                  size: 18,
                  color: row.failedCount > 0
                      ? scheme.error
                      : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    base,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: quiet,
                  ),
                ),
                if (runningText != null) ...[
                  const SizedBox(width: 6),
                  Flexible(
                    flex: 0,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: tailCap),
                      child: Text(
                        '· $runningText',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: quiet?.copyWith(color: scheme.primary),
                      ),
                    ),
                  ),
                ],
                if (failedText != null) ...[
                  const SizedBox(width: 6),
                  Flexible(
                    flex: 0,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: tailCap),
                      child: Text(
                        '· $failedText',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: quiet?.copyWith(
                          color: scheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );

    final toggle = Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('work-group-toggle-${row.id}'),
        borderRadius: BorderRadius.circular(10),
        onTap: onToggle,
        child: Semantics(
          button: true,
          toggled: row.expanded,
          label: fullLabel,
          excludeSemantics: true,
          child: body,
        ),
      ),
    );

    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ConversationTextScale(
          child: Row(
            key: ValueKey('work-group-${row.id}'),
            children: [
              Expanded(child: toggle),
              if (opening != null) MessageElapsedChip(message: opening),
            ],
          ),
        ),
      ),
    );
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
    final tokens = theme.surfaceTokens;
    return ConversationTextScale(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: tokens.cardSurface,
              borderRadius: tokens.cardRadius,
              border: Border.all(
                color: tokens.separator,
                width: tokens.enabledBorderWidth,
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
