import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';

import '../../shared/l10n/l10n_context.dart';
import 'session_tool_details_dialog.dart';

/// The body of a tool or shell row: what ran and how it stands, with its
/// input, output and error in a details dialog on demand, like the retained
/// reference, so a long result never stretches the timeline.
///
/// Every value shown was bounded and redacted by the adapter; the row and the
/// dialog redact again before showing it, so a value that reached them some
/// other way is never shown with a credential.
class SessionToolResult extends StatelessWidget {
  SessionToolResult({required this.item})
    : assert(item is ToolCall || item is ShellRun),
      super(key: ValueKey('tool-result-${item.id.value}'));

  final TimelineItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = context.v2L10n;
    final theme = Theme.of(context);
    final key = item.id.value;
    final compact = MediaQuery.sizeOf(context).width < 600;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          toolTitle(item),
          key: ValueKey('tool-title-$key'),
          maxLines: item is ShellRun ? 2 : 1,
          overflow: TextOverflow.ellipsis,
          style: item is ShellRun
              ? theme.textTheme.bodyMedium?.copyWith(fontFamily: 'monospace')
              : null,
        ),
        if (toolStatusLabel(item, l10n) case final status?)
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
