import 'package:flutter/foundation.dart';

import 'session_attention_overlay/session_attention_models.dart';

const int kCarMessagingMaxThreads = 5;
const int kCarMessagingMaxEntriesPerThread = 8;
const int kCarMessagingMaxQueuedReplies = 5;
const int kCarMessagingMaxMessageScalars = 1024;
const Duration kCarMessagingRetention = Duration(hours: 24);
const Duration kCarMessagingReplyRetention = Duration(minutes: 30);

enum CarMessagingRole { user, agent }

enum CarMessagingReplyState { queued, sending, awaitingFinal, failed }

@immutable
class CarMessagingEntry {
  const CarMessagingEntry({
    required this.role,
    required this.text,
    required this.timestampEpochMs,
    this.messageId,
  });

  factory CarMessagingEntry.fromJson(Map<String, dynamic> json) {
    return CarMessagingEntry(
      role: CarMessagingRole.values.firstWhere(
        (role) => role.name == json['role'],
        orElse: () => CarMessagingRole.agent,
      ),
      text: _boundedText(json['text'] as String? ?? ''),
      timestampEpochMs: (json['timestampEpochMs'] as num?)?.toInt() ?? 0,
      messageId: _nonEmpty(json['messageId']),
    );
  }

  final CarMessagingRole role;
  final String text;
  final int timestampEpochMs;
  final String? messageId;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'role': role.name,
    'text': text,
    'timestampEpochMs': timestampEpochMs,
    if (messageId != null) 'messageId': messageId,
  };
}

@immutable
class CarMessagingThread {
  const CarMessagingThread({
    required this.identity,
    required this.title,
    required this.entries,
    required this.updatedAtEpochMs,
    this.unread = false,
  });

  factory CarMessagingThread.fromJson(Map<String, dynamic> json) {
    final rawEntries = json['entries'];
    return CarMessagingThread(
      identity: SessionAttentionIdentity.fromJson(
        Map<String, dynamic>.from(json['identity'] as Map? ?? const {}),
      ),
      title: json['title'] as String? ?? '',
      entries: rawEntries is List
          ? rawEntries
                .whereType<Map>()
                .map(
                  (entry) => CarMessagingEntry.fromJson(
                    Map<String, dynamic>.from(entry),
                  ),
                )
                .toList(growable: false)
          : const <CarMessagingEntry>[],
      updatedAtEpochMs: (json['updatedAtEpochMs'] as num?)?.toInt() ?? 0,
      unread: json['unread'] == true,
    ).normalized();
  }

  final SessionAttentionIdentity identity;
  final String title;
  final List<CarMessagingEntry> entries;
  final int updatedAtEpochMs;
  final bool unread;

  CarMessagingThread normalized() {
    final bounded = entries
        .where((entry) => entry.text.trim().isNotEmpty)
        .map(
          (entry) => CarMessagingEntry(
            role: entry.role,
            text: _boundedText(entry.text),
            timestampEpochMs: entry.timestampEpochMs,
            messageId: _nonEmpty(entry.messageId),
          ),
        )
        .toList(growable: false);
    return CarMessagingThread(
      identity: identity.normalized(),
      title: _boundedText(title),
      entries: List<CarMessagingEntry>.unmodifiable(
        bounded.skip(
          (bounded.length - kCarMessagingMaxEntriesPerThread).clamp(
            0,
            bounded.length,
          ),
        ),
      ),
      updatedAtEpochMs: updatedAtEpochMs,
      unread: unread,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'identity': identity.toJson(),
    'title': title,
    'entries': entries.map((entry) => entry.toJson()).toList(growable: false),
    'updatedAtEpochMs': updatedAtEpochMs,
    'unread': unread,
  };
}

@immutable
class CarMessagingReply {
  const CarMessagingReply({
    required this.id,
    required this.identity,
    required this.text,
    required this.createdAtEpochMs,
    this.state = CarMessagingReplyState.queued,
    this.attempts = 0,
    this.baselineAssistantMessageId,
  });

  factory CarMessagingReply.fromJson(Map<String, dynamic> json) {
    return CarMessagingReply(
      id: json['id'] as String? ?? '',
      identity: SessionAttentionIdentity.fromJson(
        Map<String, dynamic>.from(json['identity'] as Map? ?? const {}),
      ),
      text: _boundedText(json['text'] as String? ?? ''),
      createdAtEpochMs: (json['createdAtEpochMs'] as num?)?.toInt() ?? 0,
      state: CarMessagingReplyState.values.firstWhere(
        (state) => state.name == json['state'],
        orElse: () => CarMessagingReplyState.queued,
      ),
      attempts: ((json['attempts'] as num?)?.toInt() ?? 0).clamp(0, 3),
      baselineAssistantMessageId: _nonEmpty(json['baselineAssistantMessageId']),
    );
  }

  final String id;
  final SessionAttentionIdentity identity;
  final String text;
  final int createdAtEpochMs;
  final CarMessagingReplyState state;
  final int attempts;
  final String? baselineAssistantMessageId;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'identity': identity.toJson(),
    'text': text,
    'createdAtEpochMs': createdAtEpochMs,
    'state': state.name,
    'attempts': attempts,
    if (baselineAssistantMessageId != null)
      'baselineAssistantMessageId': baselineAssistantMessageId,
  };
}

@immutable
class CarMessagingState {
  const CarMessagingState({this.threads = const [], this.replies = const []});

  factory CarMessagingState.fromJson(Map<String, dynamic> json) {
    final rawThreads = json['threads'];
    final rawReplies = json['replies'];
    return CarMessagingState(
      threads: rawThreads is List
          ? rawThreads
                .whereType<Map>()
                .map(
                  (thread) => CarMessagingThread.fromJson(
                    Map<String, dynamic>.from(thread),
                  ),
                )
                .where((thread) => thread.identity.isValid)
                .toList(growable: false)
          : const <CarMessagingThread>[],
      replies: rawReplies is List
          ? rawReplies
                .whereType<Map>()
                .map(
                  (reply) => CarMessagingReply.fromJson(
                    Map<String, dynamic>.from(reply),
                  ),
                )
                .where(
                  (reply) =>
                      reply.id.trim().isNotEmpty &&
                      reply.identity.isValid &&
                      reply.text.trim().isNotEmpty,
                )
                .toList(growable: false)
          : const <CarMessagingReply>[],
    );
  }

  final List<CarMessagingThread> threads;
  final List<CarMessagingReply> replies;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'threads': threads.map((thread) => thread.toJson()).toList(growable: false),
    'replies': replies.map((reply) => reply.toJson()).toList(growable: false),
  };
}

String _boundedText(String value) {
  final runes = value.trim().runes.toList(growable: false);
  return String.fromCharCodes(runes.take(kCarMessagingMaxMessageScalars));
}

String? _nonEmpty(Object? value) {
  final normalized = value?.toString().trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}
