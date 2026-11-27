import 'dart:math';

import 'package:codewalk_core/codewalk_core.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../../shared/l10n/l10n_context.dart';
import 'session_message_info.dart';
import 'session_tool_details_dialog.dart';

/// A compact single-line row for a tool call or shell run.
///
/// Shows the tool kind icon, localized label, optional redacted primary target,
/// and a status badge only when the item is queued, running, failed,
/// interrupted, timed out, or killed (never "Done" on clean success). Tapping
/// anywhere on the row opens [showToolDetailsDialog].
class SessionToolResult extends StatelessWidget {
  SessionToolResult({required this.item, this.messageHeader})
    : assert(
        item is ToolCall ||
            item is ShellRun ||
            (item is Notice && item.shellReport != null),
      ),
      super(key: ValueKey('tool-result-${item.id.value}'));

  final TimelineItem item;

  /// Message context when this row opens its message, rendered outside the
  /// row's own tap target so its chip keeps its own details action.
  final MessageContext? messageHeader;

  @override
  Widget build(BuildContext context) {
    final l10n = context.v2L10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final key = item.id.value;
    final summary = toolCompactSummary(item, l10n);
    final status = toolStatusLabel(item, l10n);
    final failed = toolFailed(item);
    final running = toolProgress(item) == ToolProgress.running;
    final hasDetails = toolHasDetails(item);
    final isShell =
        item is ShellRun ||
        (item is ToolCall && (item as ToolCall).kind.known == ToolKind.shell) ||
        (item is Notice && (item as Notice).shellReport != null);
    final semanticsLabel = status == null ? summary : '$summary, $status';

    final content = LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth.isFinite
            ? max(0.0, constraints.maxWidth - 56)
            : 360.0;
        final badgeCap = min(160.0, available * 0.42);
        return ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(8, 6, 8, 6),
            child: Row(
              children: [
                Icon(
                  toolIcon(item),
                  size: 16,
                  color: failed
                      ? scheme.error
                      : running
                      ? scheme.primary
                      : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    summary,
                    key: ValueKey('tool-title-$key'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: failed ? scheme.error : scheme.onSurface,
                      fontFamily: isShell ? 'monospace' : null,
                    ),
                  ),
                ),
                if (status != null) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    flex: 0,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: badgeCap),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: failed
                              ? scheme.errorContainer
                              : scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          child: Text(
                            status,
                            key: ValueKey('tool-status-$key'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: failed
                                  ? scheme.onErrorContainer
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
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

    final labeled = Semantics(
      button: hasDetails,
      label: semanticsLabel,
      excludeSemantics: true,
      child: content,
    );

    final interactive = Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: hasDetails
          ? InkWell(
              key: ValueKey('tool-toggle-$key'),
              borderRadius: BorderRadius.circular(10),
              onTap: () => showToolDetailsDialog(context, item),
              child: labeled,
            )
          : labeled,
    );

    if (messageHeader == null) return interactive;
    return Row(
      children: [
        Expanded(child: interactive),
        MessageElapsedChip(message: messageHeader!),
      ],
    );
  }
}

/// Body for a subagent [ToolCall] card so taps on the card body still open the
/// child conversation while a discrete button opens tool details.
class SessionSubagentToolBody extends StatelessWidget {
  SessionSubagentToolBody({required this.item})
    : super(key: ValueKey('tool-result-${item.id.value}'));

  final ToolCall item;

  @override
  Widget build(BuildContext context) {
    final l10n = context.v2L10n;
    final theme = Theme.of(context);
    final key = item.id.value;
    final compact = MediaQuery.sizeOf(context).width < 600;
    final status = toolStatusLabel(item, l10n);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          toolCompactSummary(item, l10n),
          key: ValueKey('tool-title-$key'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (status != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              status,
              key: ValueKey('tool-status-$key'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: toolFailed(item)
                    ? theme.colorScheme.error
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        if (toolHasDetails(item))
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              key: ValueKey('tool-toggle-$key'),
              onPressed: () => showToolDetailsDialog(context, item),
              child: Text(
                compact ? l10n.chatMessageShow : l10n.chatMessageDetails,
              ),
            ),
          ),
      ],
    );
  }
}
