import 'package:equatable/equatable.dart';

/// Technical comment translated to English.
enum MessageRole { user, assistant }

/// Technical comment translated to English.
abstract class Message extends Equatable {
  final String id;
  final String sessionId;
  final MessageRole role;
  final MessageTime time;

  const Message({
    required this.id,
    required this.sessionId,
    required this.role,
    required this.time,
  });
}

/// Technical comment translated to English.
class UserMessage extends Message {
  const UserMessage({
    required String id,
    required String sessionId,
    required MessageTime time,
  }) : super(id: id, sessionId: sessionId, role: MessageRole.user, time: time);

  @override
  List<Object> get props => [id, sessionId, role, time];
}

/// Technical comment translated to English.
class AssistantMessage extends Message {
  final MessageError? error;
  final List<String> system;
  final String modelId;
  final String providerId;
  final String mode;
  final MessagePath path;
  final bool? summary;
  final double cost;
  final MessageTokens tokens;

  const AssistantMessage({
    required String id,
    required String sessionId,
    required MessageTime time,
    this.error,
    required this.system,
    required this.modelId,
    required this.providerId,
    required this.mode,
    required this.path,
    this.summary,
    required this.cost,
    required this.tokens,
  }) : super(
         id: id,
         sessionId: sessionId,
         role: MessageRole.assistant,
         time: time,
       );

  @override
  List<Object?> get props => [
    id,
    sessionId,
    role,
    time,
    error,
    system,
    modelId,
    providerId,
    mode,
    path,
    summary,
    cost,
    tokens,
  ];
}

/// Technical comment translated to English.
class MessageTime extends Equatable {
  final int created;
  final int? completed;

  const MessageTime({required this.created, this.completed});

  @override
  List<Object?> get props => [created, completed];
}

/// Technical comment translated to English.
class MessagePath extends Equatable {
  final String cwd;
  final String root;

  const MessagePath({required this.cwd, required this.root});

  @override
  List<Object> get props => [cwd, root];
}

/// Technical comment translated to English.
class MessageTokens extends Equatable {
  final int input;
  final int output;
  final int reasoning;
  final TokenCache cache;

  const MessageTokens({
    required this.input,
    required this.output,
    required this.reasoning,
    required this.cache,
  });

  @override
  List<Object> get props => [input, output, reasoning, cache];
}

/// Technical comment translated to English.
class TokenCache extends Equatable {
  final int read;
  final int write;

  const TokenCache({required this.read, required this.write});

  @override
  List<Object> get props => [read, write];
}

/// Technical comment translated to English.
abstract class MessageError extends Equatable {
  final String name;

  const MessageError({required this.name});
}

/// Technical comment translated to English.
class ProviderAuthError extends MessageError {
  final String providerId;
  final String message;

  const ProviderAuthError({required this.providerId, required this.message})
    : super(name: 'ProviderAuthError');

  @override
  List<Object> get props => [name, providerId, message];
}

/// Technical comment translated to English.
class UnknownError extends MessageError {
  final String message;

  const UnknownError({required this.message}) : super(name: 'UnknownError');

  @override
  List<Object> get props => [name, message];
}

/// Technical comment translated to English.
class MessageOutputLengthError extends MessageError {
  const MessageOutputLengthError() : super(name: 'MessageOutputLengthError');

  @override
  List<Object> get props => [name];
}

/// Technical comment translated to English.
class MessageAbortedError extends MessageError {
  const MessageAbortedError() : super(name: 'MessageAbortedError');

  @override
  List<Object> get props => [name];
}
