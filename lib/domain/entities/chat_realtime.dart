import 'package:equatable/equatable.dart';

/// Generic realtime event emitted by the OpenCode server SSE stream.
class ChatEvent extends Equatable {
  const ChatEvent({required this.type, required this.properties});

  final String type;
  final Map<String, dynamic> properties;

  @override
  List<Object?> get props => [type, properties];
}

enum SessionStatusType { idle, busy, retry }

/// Session execution status synchronized from `session.status` events.
class SessionStatusInfo extends Equatable {
  const SessionStatusInfo({
    required this.type,
    this.attempt,
    this.message,
    this.nextEpochMs,
  });

  final SessionStatusType type;
  final int? attempt;
  final String? message;
  final int? nextEpochMs;

  @override
  List<Object?> get props => [type, attempt, message, nextEpochMs];
}

/// Optional reference to the tool call that originated an interaction request.
class ChatToolRequestRef extends Equatable {
  const ChatToolRequestRef({required this.messageId, required this.callId});

  final String messageId;
  final String callId;

  @override
  List<Object?> get props => [messageId, callId];
}

/// Permission approval request shown to the user.
class ChatPermissionRequest extends Equatable {
  const ChatPermissionRequest({
    required this.id,
    required this.sessionId,
    required this.permission,
    required this.patterns,
    required this.always,
    required this.metadata,
    this.tool,
  });

  final String id;
  final String sessionId;
  final String permission;
  final List<String> patterns;
  final List<String> always;
  final Map<String, dynamic> metadata;
  final ChatToolRequestRef? tool;

  @override
  List<Object?> get props => [
    id,
    sessionId,
    permission,
    patterns,
    always,
    metadata,
    tool,
  ];
}

/// Question option offered by the server.
class ChatQuestionOption extends Equatable {
  const ChatQuestionOption({required this.label, required this.description});

  final String label;
  final String description;

  @override
  List<Object?> get props => [label, description];
}

/// Question descriptor containing prompt and options.
class ChatQuestionInfo extends Equatable {
  const ChatQuestionInfo({
    required this.question,
    required this.header,
    required this.options,
    this.multiple = false,
    this.custom = true,
  });

  final String question;
  final String header;
  final List<ChatQuestionOption> options;
  final bool multiple;
  final bool custom;

  @override
  List<Object?> get props => [question, header, options, multiple, custom];
}

/// Question request requiring user answers.
class ChatQuestionRequest extends Equatable {
  const ChatQuestionRequest({
    required this.id,
    required this.sessionId,
    required this.questions,
    this.tool,
  });

  final String id;
  final String sessionId;
  final List<ChatQuestionInfo> questions;
  final ChatToolRequestRef? tool;

  @override
  List<Object?> get props => [id, sessionId, questions, tool];
}
