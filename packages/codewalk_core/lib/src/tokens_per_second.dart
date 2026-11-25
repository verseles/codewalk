import 'identity.dart';
import 'timeline.dart';

/// Computes turn-level tokens per second from assistant step [MessageContext]s
/// using the official OpenCode formula (#499):
///
/// `output = sum(tokens.output + tokens.reasoning)`
/// `totalMs = sum(max(0, streamed - (firstToken ?? created)))`
///
/// Returns `null` unless [steps] is non-empty, every distinct step carries a
/// [MessageContext.streamed] timestamp and a start instant
/// (`firstToken ?? created`), output/reasoning tokens are reported and
/// positive, and total streaming duration is positive. Never fabricates a rate
/// from `completed - created`.
double? computeTurnTokensPerSecond(Iterable<MessageContext> steps) {
  final byMessage = <MessageRef, MessageContext>{};
  for (final step in steps) {
    final existing = byMessage[step.message];
    byMessage[step.message] = existing == null ? step : existing.merge(step);
  }
  if (byMessage.isEmpty) return null;

  var totalOutput = 0.0;
  var totalMs = 0;
  for (final step in byMessage.values) {
    final streamed = step.streamed;
    final start = step.firstToken ?? step.created;
    final tokens = step.tokens;
    if (streamed == null || start == null || tokens == null) return null;
    if (tokens.output == null && tokens.reasoning == null) return null;
    final output =
        (tokens.output?.toDouble() ?? 0.0) +
        (tokens.reasoning?.toDouble() ?? 0.0);
    if (!output.isFinite || output < 0) return null;
    totalOutput += output;
    final deltaMs = streamed.difference(start).inMilliseconds;
    if (deltaMs > 0) totalMs += deltaMs;
  }
  if (!totalOutput.isFinite || totalOutput <= 0 || totalMs <= 0) return null;
  final rate = totalOutput / (totalMs / 1000.0);
  return rate.isFinite && rate > 0 ? rate : null;
}

/// Maps the final completed non-empty [AssistantText] item ID of each
/// completed turn in [items] to its turn-level tokens-per-second rate (#499).
///
/// Turns are delimited by active [UserInput] items ([isActivePlanUserInput]).
/// Items before the first active prompt are skipped: a truncated or paged
/// window may have cut that turn, so its steps are not known to be whole.
/// The trailing turn counts only when [trailingTurnClosed] says no more of it
/// can arrive (an idle live session, or a history read with no later page):
/// between two steps every resident item looks finished. Turns whose last
/// non-empty assistant answer is still streaming, turns that ended with a
/// failed or interrupted outcome, and turns where any step lacks streaming
/// timing or output token counts are omitted.
Map<ItemId, double> resolveTurnTokensPerSecondByAnswer(
  List<TimelineItem> items, {
  bool trailingTurnClosed = true,
}) {
  bool opensTurn(TimelineItem item) =>
      item is UserInput && isActivePlanUserInput(item);
  var index = items.indexWhere(opensTurn);
  if (index < 0) return const {};
  final result = <ItemId, double>{};

  while (index < items.length) {
    // items[index] is the active prompt that opens this turn.
    var end = index + 1;
    while (end < items.length && !opensTurn(items[end])) {
      end++;
    }
    final start = index + 1;
    index = end;
    if (end == items.length && !trailingTurnClosed) break;

    final steps = <MessageContext>[];
    AssistantText? lastAnswer;
    var failedOrInterrupted = false;
    var hasIncompleteItem = false;
    for (var i = start; i < end; i++) {
      final item = items[i];
      if (item is TurnOutcome) {
        final known = item.kind.known;
        if (known == OutcomeKind.failed || known == OutcomeKind.interrupted) {
          failedOrInterrupted = true;
        }
        continue;
      }
      if (item is Notice) {
        if (item.kind.known == NoticeKind.interruption) {
          failedOrInterrupted = true;
        }
        continue;
      }
      if (item is UserInput) continue;
      if (item is UnknownItem) {
        // An unsupported assistant part is still a step of the turn: its
        // timing and tokens join the strict check, never the answer.
        if (item.meta.message case final context?) steps.add(context);
        continue;
      }
      final status = item.status.known;
      if (status == ItemStatus.streaming || status == ItemStatus.pending) {
        hasIncompleteItem = true;
      }
      if (item is AssistantText && !item.complete) {
        hasIncompleteItem = true;
      }
      if (item is Reasoning && !item.complete) {
        hasIncompleteItem = true;
      }
      if (item.meta.message case final context?) {
        steps.add(context);
      }
      if (item is AssistantText && item.text.trim().isNotEmpty) {
        lastAnswer = item;
      }
    }

    if (!failedOrInterrupted &&
        !hasIncompleteItem &&
        lastAnswer != null &&
        lastAnswer.complete &&
        steps.isNotEmpty) {
      final tps = computeTurnTokensPerSecond(steps);
      if (tps != null) {
        result[lastAnswer.id] = tps;
      }
    }
  }

  return result;
}
