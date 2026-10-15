import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';
import '../../shared/l10n/l10n_context.dart';

/// One read-only timeline item, shared by the history and live views.
class SessionTimelineTile extends StatelessWidget {
  const SessionTimelineTile({super.key, required this.item});
  final TimelineItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = context.v2L10n;
    final item = this.item;
    final (label, text, icon) = switch (item) {
      UserInput() => (l10n.chatMessageYou, item.text, Icons.person_outline),
      AssistantText() => (
        l10n.historyAssistant,
        item.prefixMissing ? '…${item.text}' : item.text,
        Icons.chat_bubble_outline,
      ),
      Reasoning() => (
        l10n.chatMessageThinkingProcess,
        item.prefixMissing ? '…${item.text}' : item.text,
        Icons.psychology_outlined,
      ),
      Notice() => (l10n.historyDetails, item.text, Icons.info_outline),
      ToolCall() => (l10n.historyDetails, item.rawName, Icons.build_outlined),
      TurnOutcome() => (
        l10n.historyDetails,
        switch (item.kind.known) {
          OutcomeKind.succeeded => l10n.liveOutcomeSucceeded,
          OutcomeKind.failed => l10n.liveOutcomeFailed,
          OutcomeKind.interrupted => l10n.liveOutcomeInterrupted,
          null => l10n.chatMessageMessagePartUnavailable,
        },
        Icons.flag_outlined,
      ),
      _ => (
        l10n.historyDetails,
        l10n.chatMessageMessagePartUnavailable,
        Icons.info_outline,
      ),
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              String.fromCharCodes(text.runes.take(2000)),
              maxLines: 16,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
