import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';
import '../../shared/l10n/l10n_context.dart';
import '../../shared/rendering/canonical_message_body.dart';
import '../../shared/theme/chat_appearance.dart';
import 'session_error_card.dart';
import 'session_message_info.dart';
import 'session_reasoning_body.dart';
import 'session_tool_result.dart';

/// One read-only timeline item, shared by the history and live views.
///
/// V2-071A: text-bearing canonical items render rich Markdown/math/HTML/
/// Mermaid/code via [CanonicalMessageBody] bound to canonical fields only.
/// V2-044D: tool and shell items show what ran and how it stands, with their
/// bounded, redacted input, output and error in a dialog on demand
/// ([SessionToolResult]). Reasoning shows a few lines and the rest on demand
/// ([SessionReasoningBody]). V2-055A: a failed turn that carries its typed
/// error shows a [SessionErrorCard]. Other outcome and unknown items keep minimized
/// markers and never expose `raw` or fallback text. No legacy imports (G4).
class SessionTimelineTile extends StatelessWidget {
  const SessionTimelineTile({
    super.key,
    required this.item,
    this.onTapLink,
    this.onTapFilePath,
    this.onCopyCode,
    this.errorRecovery,
    this.onOpenChild,
    this.messageHeader = false,
  });
  final TimelineItem item;
  final void Function(String text, String href, String? title)? onTapLink;
  final void Function(String path, int? line, int? col)? onTapFilePath;
  final ValueChanged<String>? onCopyCode;

  /// The recovery an error card offers here; null in the read-only history,
  /// whose cards show no button.
  final SessionErrorRecovery? Function(ErrorInfo error)? errorRecovery;

  /// Opens the sub-conversation a subagent call runs; the whole card is the
  /// way in, and its own controls keep their taps. Null for none.
  final ValueChanged<ToolCall>? onOpenChild;

  /// Whether this item opens its message, so its header shows the message's
  /// elapsed time and details.
  final bool messageHeader;

  @override
  Widget build(BuildContext context) {
    final l10n = context.v2L10n;
    final item = this.item;
    if (item is TurnOutcome && item.kind.known == OutcomeKind.failed) {
      final error = item.error;
      if (error != null) {
        return ConversationTextScale(
          child: SessionErrorCard(
            error: error,
            recovery: errorRecovery?.call(error),
          ),
        );
      }
    }
    final (label, icon) = switch (item) {
      UserInput() => (l10n.chatMessageYou, Icons.person_outline),
      AssistantText() => (l10n.historyAssistant, Icons.chat_bubble_outline),
      // Compact screens use the retained reference's short label.
      Reasoning() => (
        MediaQuery.sizeOf(context).width < 600
            ? l10n.chatMessageThinking
            : l10n.chatMessageThinkingProcess,
        Icons.psychology_outlined,
      ),
      Notice() => (l10n.historyDetails, Icons.info_outline),
      ToolCall() => (l10n.historyDetails, Icons.build_outlined),
      ShellRun() => (l10n.historyDetails, Icons.terminal_outlined),
      TurnOutcome() => (l10n.historyDetails, Icons.flag_outlined),
      UnknownItem() => (l10n.historyDetails, Icons.info_outline),
    };
    final open = onOpenChild;
    final child = item is ToolCall && item.kind.known == ToolKind.subagent
        ? open
        : null;
    final message = messageHeader ? item.meta.message : null;
    final assistant = item is! UserInput;
    final body = Padding(
      // Assistant parts sit closer together; a user turn keeps its frame.
      padding: assistant
          ? const EdgeInsets.fromLTRB(16, 12, 16, 12)
          : const EdgeInsets.all(16),
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
              if (message != null) MessageElapsedChip(message: message),
            ],
          ),
          const SizedBox(height: 8),
          _buildBody(context, l10n),
        ],
      ),
    );
    // The refined style frames only the user's turns with a hairline.
    final cardShape = Theme.of(context).cardTheme.shape;
    final shape = assistant && cardShape is RoundedRectangleBorder
        ? cardShape.copyWith(side: BorderSide.none)
        : null;
    if (child == null) {
      return ConversationTextScale(
        child: Card(shape: shape, child: body),
      );
    }
    return ConversationTextScale(
      child: Card(
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: Semantics(
          button: true,
          child: InkWell(
            key: ValueKey('subagent-open-${item.id.value}'),
            onTap: () => child(item as ToolCall),
            child: body,
          ),
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
        return SessionReasoningBody(
          text: text,
          complete: complete,
          child: SelectionArea(
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
      case ToolCall() || ShellRun():
        return SessionToolResult(item: item);
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
