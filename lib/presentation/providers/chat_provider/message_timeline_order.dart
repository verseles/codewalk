import '../../../domain/entities/chat_message.dart';

/// Client-side timeline ordering helpers (issue #179).
///
/// The chat timeline renders `ChatProvider._messages` in list order, so list
/// position — not any single timestamp — is the visible chronology. Optimistic
/// bubbles (`local_user_*`) carry the device wall clock (`DateTime.now()` at
/// send time) while canonical messages carry the server clock
/// (`time.created`). Those two clocks can disagree by seconds or more
/// (mobile vs self-hosted server, tunnel latency), so ordering here is
/// **anchor-first**: a message keeps the slot derived from neighbouring
/// message IDs, and no helper here compares timestamps across clocks at all.
/// Nothing here changes the OpenCode wire contract
/// (ADR-023): no new endpoints, no new fields, `local_user_*` stays
/// client-only and `messageId` is still never sent in `prompt_async`.

/// Prefix identifying client-only optimistic user bubbles.
///
/// Canonical server message IDs (`msg_*`, ...) must never use this prefix
/// (ADR-023 Pitfall P-001); the echo-matching code below relies on it.
const optimisticLocalUserTimelineIdPrefix = 'local_user_';

/// Prefix identifying client-synthesized inline notices (abort/error).
///
/// These are newest-by-definition and are excluded from chronological scans.
const clientInlineTimelineIdPrefix = 'msg_inline_';

/// Whether [id] belongs to a client-timed message whose wall clock must never
/// be compared against server timestamps for ordering purposes.
bool isClientTimedTimelineId(String id) {
  final normalized = id.trim();
  return normalized.startsWith(optimisticLocalUserTimelineIdPrefix) ||
      normalized.startsWith(clientInlineTimelineIdPrefix);
}

/// Whether [id] is a client-only optimistic user bubble.
bool isOptimisticLocalUserTimelineId(String id) {
  return id.trim().startsWith(optimisticLocalUserTimelineIdPrefix);
}

/// Joined trimmed text of a user message, used only to recognise a
/// canonical echo of an optimistic bubble (never as a display value).
String timelineUserTextSignature(UserMessage message) {
  return message.parts
      .whereType<TextPart>()
      .map((part) => part.text.trim())
      .where((text) => text.isNotEmpty)
      .join('\n');
}

/// Sorted lower-cased mime multiset of a user message's file parts.
String timelineUserFileMimeSignature(UserMessage message) {
  final mimes = message.parts
      .whereType<FilePart>()
      .map((part) => part.mime.trim().toLowerCase())
      .where((mime) => mime.isNotEmpty)
      .toList(growable: false)
    ..sort();
  return mimes.join('\n');
}

/// Whether [candidate] reads as the canonical server echo of the optimistic
/// [local] bubble: same session, server-owned user message, equal text and
/// attachment shape within a bounded clock window.
///
/// Mime rewrites are tolerated only when non-empty text anchors the turn;
/// image-only turns still require mime equality so distinct attachments are
/// never collapsed. Pairing callers must enforce one-to-one consumption.
bool timelineIsServerUserEchoFor({
  required UserMessage local,
  required ChatMessage candidate,
}) {
  if (candidate is! UserMessage) {
    return false;
  }
  if (isClientTimedTimelineId(candidate.id)) {
    return false;
  }
  if (candidate.sessionId != local.sessionId) {
    return false;
  }
  final localText = timelineUserTextSignature(local);
  if (localText != timelineUserTextSignature(candidate)) {
    return false;
  }
  final localFiles = local.parts.whereType<FilePart>().length;
  if (localFiles != candidate.parts.whereType<FilePart>().length) {
    return false;
  }
  if (timelineUserFileMimeSignature(local) !=
      timelineUserFileMimeSignature(candidate)) {
    // Same shape but transcoded/relabeled attachments: only trust the match
    // when text identifies the turn. (Residual: fully anonymous transcoded
    // image echoes stay preserved; their order is still anchor-stable.)
    if (localText.isEmpty) {
      return false;
    }
  }
  return candidate.time.difference(local.time).abs() <=
      const Duration(minutes: 10);
}
/// Index at which a client-only local message (currently at [localIndex] in
/// [localSnapshot], e.g. the visible `_messages` list) should be inserted
/// into [target] (e.g. a server snapshot being merged) so it keeps its
/// causal slot instead of being appended after newer content.
///
/// Resolution order, all ID-based and therefore clock-agnostic:
///   1. immediately after the nearest *preceding* local message that is
///      already present in [target];
///   2. else immediately before the nearest *following* local message that is
///      already present in [target];
///   3. else, for a user message, immediately before the first assistant run
///      in [target] — a prompt precedes a response that carries no known
///      prompt (the #179 stall shape: an assistant-only partial snapshot);
///      any other message appends.
/// Step 3 deliberately avoids comparing the optimistic device clock against
/// server clocks, which can disagree by minutes under skew. There is no
/// timestamp fallback: without ID evidence there is no safe time evidence.
int timelineInsertIndexForLocalMessage({
  required List<ChatMessage> target,
  required List<ChatMessage> localSnapshot,
  required int localIndex,
}) {
  if (target.isEmpty) {
    return 0;
  }
  if (localIndex < 0 || localIndex >= localSnapshot.length) {
    return target.length;
  }
  final targetIndexById = <String, int>{};
  for (var index = 0; index < target.length; index += 1) {
    targetIndexById.putIfAbsent(target[index].id, () => index);
  }
  for (var local = localIndex - 1; local >= 0; local -= 1) {
    final anchor = targetIndexById[localSnapshot[local].id];
    if (anchor != null) {
      return (anchor + 1).clamp(0, target.length);
    }
  }
  for (var local = localIndex + 1; local < localSnapshot.length; local += 1) {
    final anchor = targetIndexById[localSnapshot[local].id];
    if (anchor != null) {
      return anchor.clamp(0, target.length);
    }
  }
  if (localSnapshot[localIndex] is UserMessage) {
    final firstAssistant = target.indexWhere(
      (message) => message is AssistantMessage,
    );
    if (firstAssistant != -1) {
      return firstAssistant;
    }
  }
  return target.length;
}

/// Repairs inversions persisted before this fix (issue #179 family).
///
/// Moves an optimistic `local_user_*` user message that sits directly after
/// an assistant run back to the head of that run, but only when no confirmed
/// user message precedes the run. That shape — an assistant reply with no
/// prompting user above it — cannot be a valid conversation turn, while
/// patterns like `[serverUser, localUser2, assistant2]` (in-flight second
/// turn) are left untouched. Returns the input list unchanged when no repair
/// applies, so callers can skip downstream writes on identical output.
List<ChatMessage> healPersistedTimelineInversions(List<ChatMessage> messages) {
  if (messages.length < 2) {
    return messages;
  }
  List<ChatMessage>? repaired;
  var working = messages;
  var index = 0;
  while (index < working.length) {
    final current = working[index];
    if (current is UserMessage &&
        isOptimisticLocalUserTimelineId(current.id)) {
      var runStart = index - 1;
      while (runStart >= 0 && working[runStart] is AssistantMessage) {
        runStart -= 1;
      }
      runStart += 1;
      if (runStart < index && runStart >= 0) {
        var hasConfirmedUserBefore = false;
        for (var scan = 0; scan < runStart; scan += 1) {
          final candidate = working[scan];
          if (candidate is UserMessage &&
              !isOptimisticLocalUserTimelineId(candidate.id)) {
            hasConfirmedUserBefore = true;
            break;
          }
        }
        if (!hasConfirmedUserBefore) {
          repaired ??= List<ChatMessage>.from(working);
          repaired.removeAt(index);
          repaired.insert(runStart, current);
          working = repaired;
          index = runStart + 1;
          continue;
        }
      }
    }
    index += 1;
  }
  return repaired ?? messages;
}
