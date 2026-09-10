import '../../../domain/entities/chat_message.dart';
import 'message_timeline_order.dart';

/// Where a message-collection update came from.
///
/// The flicker in #111 came from any of these paths being able to overwrite the
/// visible collection wholesale, so provenance has to travel with the update in
/// order to be judged.
enum MessageUpdateOrigin {
  realtimeEvent,
  httpFallback,
  sessionRefresh,
  cacheHydration,
  localMutation,
  sessionSwitch,
}

/// What the payload claims to be.
///
/// A payload that only carries part of the conversation must never be applied
/// as if it described the whole of it.
enum MessageUpdateKind {
  /// Claims to describe the session's full collection.
  fullSnapshot,

  /// Carries a subset; absent messages say nothing about their existence.
  partialDelta,

  /// The server explicitly said these messages are gone.
  authoritativeRemoval,

  /// Session switch, sign-out, cache eviction: emptying is intended.
  reset,
}

/// Outcome of judging one update.
enum MessageUpdateDecision {
  /// The payload was taken as-is.
  applied,

  /// The payload would have dropped newer messages, so they were kept.
  mergedNonRegressive,
}

/// Result of judging a candidate message collection.
class MessageReconciliation {
  const MessageReconciliation({
    required this.messages,
    required this.decision,
    required this.reason,
    this.preservedIds = const <String>[],
  });

  final List<ChatMessage> messages;
  final MessageUpdateDecision decision;
  final String reason;

  /// Messages the payload omitted but that were newer than anything it carried.
  final List<String> preservedIds;
}

/// Decides what the visible message collection should become.
///
/// Issue #111 had been patched twice (#76, #48) at individual call sites and
/// came back both times. Asynchronous snapshot replacements therefore share one
/// rule: an update may never remove a message newer than everything the update
/// itself carries, unless it is an explicit removal or a reset.
///
/// Pure on purpose, so the invariant can be tested against fabricated event
/// orderings without standing up a provider.
MessageReconciliation reconcileMessages({
  required List<ChatMessage> previous,
  required List<ChatMessage> next,
  required MessageUpdateKind kind,
  String? sessionId,
}) {
  // Resets and explicit removals are authoritative by definition.
  if (kind == MessageUpdateKind.reset ||
      kind == MessageUpdateKind.authoritativeRemoval) {
    return MessageReconciliation(
      messages: List<ChatMessage>.from(next),
      decision: MessageUpdateDecision.applied,
      reason: 'authoritative',
    );
  }

  final scopedPrevious = sessionId == null
      ? previous
      : previous
            .where((message) => message.sessionId == sessionId)
            .toList(growable: false);

  final nextIds = next.map((message) => message.id).toSet();
  final dropped = scopedPrevious
      .where((message) => !nextIds.contains(message.id))
      .toList(growable: false);

  if (kind == MessageUpdateKind.partialDelta && dropped.isNotEmpty) {
    final incomingById = <String, ChatMessage>{
      for (final message in next) message.id: message,
    };
    final merged = <ChatMessage>[];
    for (final message in scopedPrevious) {
      merged.add(incomingById.remove(message.id) ?? message);
    }
    for (final message in next) {
      if (incomingById.remove(message.id) == null) {
        continue;
      }
      // Anchor-first insertion (issue #179): never compare a client-timed
      // bubble against server clocks. Client-timed newcomers append; new
      // canonical messages slot among canonical neighbours by server time.
      if (isClientTimedTimelineId(message.id)) {
        merged.add(message);
        continue;
      }
      final insertionIndex = merged.indexWhere(
        (existing) =>
            !isClientTimedTimelineId(existing.id) &&
            existing.time.isAfter(message.time),
      );
      if (insertionIndex == -1) {
        merged.add(message);
      } else {
        merged.insert(insertionIndex, message);
      }
    }
    return MessageReconciliation(
      messages: merged,
      decision: MessageUpdateDecision.mergedNonRegressive,
      reason: 'partial-delta',
      preservedIds: dropped
          .map((message) => message.id)
          .toList(growable: false),
    );
  }

  if (dropped.isEmpty) {
    return MessageReconciliation(
      messages: List<ChatMessage>.from(next),
      decision: MessageUpdateDecision.applied,
      reason: 'no-drop',
    );
  }

  // The payload drops messages. That is only legitimate when none of them is
  // newer than what the payload itself knows about; otherwise it is stale or
  // partial and is describing an older world than the one already on screen.
  //
  // Client-only optimistic bubbles (`local_user_*`) are always preservable:
  // their device clock is incomparable with server clocks, so a time
  // comparison could mistake an in-flight prompt for a stale entry and drop
  // it right before its echo arrives (issue #179). The one exception is a
  // reconciled bubble: when `next` already carries its canonical echo, the
  // optimistic entry is dropped instead of being resurrected as a duplicate.
  // Echo pairing is one-to-one so repeated intentional prompts stay distinct.
  //
  // Two echo shapes are recognised, mirroring
  // `_shouldSkipLocalUserAppendAsDuplicateEcho` in the merge layer (which
  // suppresses the same bubbles one step earlier):
  // (a) strict echo — equal text and attachment shape within ±10 minutes;
  // (b) fuzzy partial echo — prefix-shared text within the asymmetric
  //     [send-2s, send+45s] window while `next` still carries an incomplete
  //     assistant, i.e. the turn the echo belongs to is still streaming.
  final newestInNext = _newestTime(next);
  final consumedEchoIds = <String>{};
  bool isFuzzyEchoCandidate(ChatMessage candidate, UserMessage local) {
    if (candidate is! UserMessage ||
        isClientTimedTimelineId(candidate.id) ||
        candidate.sessionId != local.sessionId ||
        consumedEchoIds.contains(candidate.id)) {
      return false;
    }
    final localSignature = timelineUserTextSignature(local);
    final candidateSignature = timelineUserTextSignature(candidate);
    if (localSignature.isNotEmpty && candidateSignature.isNotEmpty) {
      final sharesPrefix = localSignature.startsWith(candidateSignature) ||
          candidateSignature.startsWith(localSignature);
      if (!sharesPrefix) {
        return false;
      }
    }
    if (candidate.time.isBefore(
          local.time.subtract(const Duration(seconds: 2)),
        ) ||
        candidate.time.isAfter(local.time.add(const Duration(seconds: 45)))) {
      return false;
    }
    return true;
  }

  final hasInProgressAssistant = next.any(
    (message) => message is AssistantMessage && !message.isCompleted,
  );
  bool isReconciledOptimistic(ChatMessage message) {
    if (message is! UserMessage ||
        !isOptimisticLocalUserTimelineId(message.id)) {
      return false;
    }
    for (final candidate in next) {
      if (consumedEchoIds.contains(candidate.id)) {
        continue;
      }
      if (timelineIsServerUserEchoFor(
        local: message,
        candidate: candidate,
      )) {
        consumedEchoIds.add(candidate.id);
        return true;
      }
    }
    if (!hasInProgressAssistant) {
      return false;
    }
    for (final candidate in next) {
      if (!isFuzzyEchoCandidate(candidate, message)) {
        continue;
      }
      consumedEchoIds.add(candidate.id);
      return true;
    }
    return false;
  }

  final regressive = dropped
      .where(
        (message) =>
            (!isOptimisticLocalUserTimelineId(message.id) &&
                (newestInNext == null ||
                    !message.time.isBefore(newestInNext))) ||
            (isOptimisticLocalUserTimelineId(message.id) &&
                !isReconciledOptimistic(message)),
      )
      .toList(growable: false);

  if (regressive.isEmpty) {
    return MessageReconciliation(
      messages: List<ChatMessage>.from(next),
      decision: MessageUpdateDecision.applied,
      reason: 'drop-older-only',
    );
  }

  // Keep the newer tail the payload failed to mention, spliced back at the
  // anchor positions it held before (issue #179). A wall-clock sort across
  // client-timed bubbles and server messages could invert a turn under
  // clock skew, so previous relative order wins over timestamps here.
  final previousIndexById = <String, int>{};
  for (var index = 0; index < scopedPrevious.length; index += 1) {
    previousIndexById.putIfAbsent(scopedPrevious[index].id, () => index);
  }
  final preserved = List<ChatMessage>.from(next);
  final preservedInPreviousOrder = List<ChatMessage>.from(regressive)
    ..sort(
      (a, b) => previousIndexById[a.id]!.compareTo(previousIndexById[b.id]!),
    );
  for (final message in preservedInPreviousOrder) {
    if (preserved.any((existing) => existing.id == message.id)) {
      continue;
    }
    final ownIndex = previousIndexById[message.id]!;
    var insertAt = preserved.length;
    for (var index = 0; index < preserved.length; index += 1) {
      final neighbourIndex = previousIndexById[preserved[index].id];
      if (neighbourIndex != null && neighbourIndex > ownIndex) {
        insertAt = index;
        break;
      }
    }
    preserved.insert(insertAt, message);
  }

  return MessageReconciliation(
    messages: preserved,
    decision: MessageUpdateDecision.mergedNonRegressive,
    reason: 'stale-or-partial-payload',
    preservedIds: regressive
        .map((message) => message.id)
        .toList(growable: false),
  );
}

DateTime? _newestTime(List<ChatMessage> messages) {
  DateTime? newest;
  for (final message in messages) {
    if (newest == null || message.time.isAfter(newest)) {
      newest = message.time;
    }
  }
  return newest;
}
