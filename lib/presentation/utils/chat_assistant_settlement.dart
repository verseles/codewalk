import '../../domain/entities/chat_message.dart';

/// Returns true if the given assistant message has revealable content
/// (text, reasoning, etc.) beyond just tool/patch work parts.
///
/// A message is considered revealable when it has at least one part that
/// is neither [ToolPart] nor [PatchPart]. This matches the rendering
/// semantics: tool/patch parts are structural work surfaces; everything
/// else (text, reasoning, subtask, etc.) is user-facing content.
bool hasRevealableAssistantContent(AssistantMessage message) {
  return message.parts.any(
    (part) =>
        part is! ToolPart &&
        part is! PatchPart &&
        part is! StepStartPart &&
        part is! StepFinishPart,
  );
}

/// Returns true when the latest message tail of [sessionId] is a completed
/// assistant message with revealable content.
///
/// Unlike [hasCompletedRevealableAssistantMessage] — which walks past
/// completed tool-only tails to find earlier text — this predicate looks
/// only at the latest tail: a later completed tool-only step, an
/// incomplete assistant, or a newer user message keeps progress visible.
/// Used by the composer/progress gating so a settled final answer clears
/// "raciocinando..." even when a stale busy/retry status lingers, while
/// genuine tool-only busy turns keep showing progress.
bool isLatestTailSettledRevealable(
  List<ChatMessage> messages,
  String sessionId,
) {
  for (var i = messages.length - 1; i >= 0; i--) {
    final message = messages[i];
    if (message.sessionId != sessionId) continue;
    if (message is UserMessage) return false;
    if (message is! AssistantMessage) continue;
    return message.isCompleted && hasRevealableAssistantContent(message);
  }
  return false;
}

/// Determines whether a list of messages for a given session has a settled,
/// revealable completed assistant response, meaning the assistant has produced
/// final text/reasoning content, not just tool-only work parts.
///
/// Used by the provider to distinguish between:
/// - A legitimate tool-only busy tail (multi-step tool chain, keep Stop visible)
/// - A completed final response that happens to also contain ToolPart/PatchPart
/// alongside revealable text/reasoning content (session settled, hide Stop)
bool hasCompletedRevealableAssistantMessage(
  List<ChatMessage> messages,
  String sessionId,
) {
  for (var i = messages.length - 1; i >= 0; i--) {
    final message = messages[i];
    if (message.sessionId != sessionId) continue;
    if (message is UserMessage) return false;
    if (message is! AssistantMessage) continue;
    if (!message.isCompleted) return false;
    if (hasRevealableAssistantContent(message)) return true;
  }
  return false;
}

/// Returns true if the given assistant message is a tool-only work step
/// (all parts are ToolPart or PatchPart, no revealable content).
bool isToolOnlyAssistantMessage(AssistantMessage message) {
  return message.parts.every((part) => part is ToolPart || part is PatchPart);
}
