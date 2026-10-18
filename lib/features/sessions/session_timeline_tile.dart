import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';
import '../../shared/l10n/l10n_context.dart';
import '../../shared/rendering/canonical_message_body.dart';

/// One read-only timeline item, shared by the history and live views.
///
/// V2-071A: text-bearing canonical items render rich Markdown/math/HTML/
/// Mermaid/code via [CanonicalMessageBody] bound to canonical fields only.
/// Tool/shell/outcome/unknown items keep minimized, payload-redacted markers
/// and never expose `input`/`output`/`raw`. No legacy imports (G4).
class SessionTimelineTile extends StatelessWidget {
  const SessionTimelineTile({
    super.key,
    required this.item,
    this.onTapLink,
    this.onTapFilePath,
    this.onCopyCode,
  });
  final TimelineItem item;
  final void Function(String text, String href, String? title)? onTapLink;
  final void Function(String path, int? line, int? col)? onTapFilePath;
  final ValueChanged<String>? onCopyCode;

  @override
  Widget build(BuildContext context) {
    final l10n = context.v2L10n;
    final item = this.item;
    final (label, icon) = switch (item) {
      UserInput() => (l10n.chatMessageYou, Icons.person_outline),
      AssistantText() => (l10n.historyAssistant, Icons.chat_bubble_outline),
      Reasoning() => (
        l10n.chatMessageThinkingProcess,
        Icons.psychology_outlined,
      ),
      Notice() => (l10n.historyDetails, Icons.info_outline),
      ToolCall() => (l10n.historyDetails, Icons.build_outlined),
      ShellRun() => (l10n.historyDetails, Icons.terminal_outlined),
      TurnOutcome() => (l10n.historyDetails, Icons.flag_outlined),
      UnknownItem() => (l10n.historyDetails, Icons.info_outline),
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
                  child: Semantics(
                    header: true,
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildBody(context, l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, dynamic l10n) {
    final item = this.item;
    switch (item) {
      case UserInput(:final text):
        return SelectionArea(
          child: CanonicalMessageBody(
            key: ValueKey('timeline-content-${item.id.value}'),
            source: text,
            complete: true,
            allowBasicHtml: false,
            onTapLink: onTapLink,
            onTapFilePath: onTapFilePath,
            onCopyCode: onCopyCode,
          ),
        );
      case AssistantText(:final text, :final complete, :final prefixMissing):
        return SelectionArea(
          child: CanonicalMessageBody(
            key: ValueKey('timeline-content-${item.id.value}'),
            source: text,
            complete: complete,
            prefixMissing: prefixMissing,
            allowBasicHtml: true,
            onTapLink: onTapLink,
            onTapFilePath: onTapFilePath,
            onCopyCode: onCopyCode,
          ),
        );
      case Reasoning(:final text, :final complete, :final prefixMissing):
        return SelectionArea(
          child: CanonicalMessageBody(
            key: ValueKey('timeline-content-${item.id.value}'),
            source: text,
            complete: complete,
            prefixMissing: prefixMissing,
            allowBasicHtml: false,
            onTapLink: onTapLink,
            onTapFilePath: onTapFilePath,
            onCopyCode: onCopyCode,
          ),
        );
      case Notice(:final text):
        return SelectionArea(
          child: CanonicalMessageBody(
            key: ValueKey('timeline-content-${item.id.value}'),
            source: text,
            complete: true,
            allowBasicHtml: false,
            onTapLink: onTapLink,
            onTapFilePath: onTapFilePath,
            onCopyCode: onCopyCode,
          ),
        );
      case ToolCall(:final rawName):
        return Text(
          String.fromCharCodes(rawName.runes.take(2000)),
          maxLines: 16,
          overflow: TextOverflow.ellipsis,
        );
      case ShellRun():
        // Minimized marker: never render raw command (redaction contract).
        return Text(
          l10n.chatMessageMessagePartUnavailable as String,
          maxLines: 16,
          overflow: TextOverflow.ellipsis,
        );
      case TurnOutcome(:final kind):
        final text = switch (kind.known) {
          OutcomeKind.succeeded => l10n.liveOutcomeSucceeded as String,
          OutcomeKind.failed => l10n.liveOutcomeFailed as String,
          OutcomeKind.interrupted => l10n.liveOutcomeInterrupted as String,
          null => l10n.chatMessageMessagePartUnavailable as String,
        };
        return Text(text, maxLines: 16, overflow: TextOverflow.ellipsis);
      case UnknownItem():
        // Minimized neutral marker: never expose fallbackText/rawType.
        return Text(
          l10n.chatMessageMessagePartUnavailable as String,
          maxLines: 16,
          overflow: TextOverflow.ellipsis,
        );
    }
  }
}
