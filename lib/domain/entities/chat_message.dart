import 'package:equatable/equatable.dart';

/// Technical comment translated to English.
abstract class ChatMessage extends Equatable {
  const ChatMessage({
    required this.id,
    required this.sessionId,
    required this.role,
    required this.time,
    this.parts = const [],
  });

  final String id;
  final String sessionId;
  final MessageRole role;
  final DateTime time;
  final List<MessagePart> parts;

  @override
  List<Object?> get props => [id, sessionId, role, time, parts];
}

/// Technical comment translated to English.
class UserMessage extends ChatMessage {
  const UserMessage({
    required super.id,
    required super.sessionId,
    required super.time,
    super.parts,
  }) : super(role: MessageRole.user);
}

/// Technical comment translated to English.
class AssistantMessage extends ChatMessage {
  const AssistantMessage({
    required super.id,
    required super.sessionId,
    required super.time,
    super.parts,
    this.completedTime,
    this.providerId,
    this.modelId,
    this.cost,
    this.tokens,
    this.error,
    this.mode,
    this.summary,
  }) : super(role: MessageRole.assistant);

  final DateTime? completedTime;
  final String? providerId;
  final String? modelId;
  final double? cost;
  final MessageTokens? tokens;
  final MessageError? error;
  final String? mode;
  final bool? summary;

  /// Technical comment translated to English.
  bool get isCompleted => completedTime != null;

  @override
  List<Object?> get props => [
    ...super.props,
    completedTime,
    providerId,
    modelId,
    cost,
    tokens,
    error,
    mode,
    summary,
  ];
}

/// Technical comment translated to English.
enum MessageRole { user, assistant }

/// Technical comment translated to English.
abstract class MessagePart extends Equatable {
  const MessagePart({
    required this.id,
    required this.messageId,
    required this.sessionId,
    required this.type,
  });

  final String id;
  final String messageId;
  final String sessionId;
  final PartType type;

  @override
  List<Object?> get props => [id, messageId, sessionId, type];
}

/// Technical comment translated to English.
class TextPart extends MessagePart {
  const TextPart({
    required super.id,
    required super.messageId,
    required super.sessionId,
    required this.text,
    this.time,
  }) : super(type: PartType.text);

  final String text;
  final DateTime? time;

  @override
  List<Object?> get props => [...super.props, text, time];
}

/// Technical comment translated to English.
class FilePart extends MessagePart {
  const FilePart({
    required super.id,
    required super.messageId,
    required super.sessionId,
    required this.url,
    required this.mime,
    this.filename,
    this.fileSource,
    this.symbolSource,
  }) : super(type: PartType.file);

  final String url;
  final String mime;
  final String? filename;
  final FileSource? fileSource;
  final SymbolSource? symbolSource;

  /// Backwards-compatible getter.
  FileSource? get source => fileSource;

  @override
  List<Object?> get props => [
    ...super.props,
    url,
    mime,
    filename,
    fileSource,
    symbolSource,
  ];
}

/// Technical comment translated to English.
class ToolPart extends MessagePart {
  const ToolPart({
    required super.id,
    required super.messageId,
    required super.sessionId,
    required this.callId,
    required this.tool,
    required this.state,
  }) : super(type: PartType.tool);

  final String callId;
  final String tool;
  final ToolState state;

  @override
  List<Object?> get props => [...super.props, callId, tool, state];
}

/// Technical comment translated to English.
class ReasoningPart extends MessagePart {
  const ReasoningPart({
    required super.id,
    required super.messageId,
    required super.sessionId,
    required this.text,
    this.time,
  }) : super(type: PartType.reasoning);

  final String text;
  final DateTime? time;

  @override
  List<Object?> get props => [...super.props, text, time];
}

/// Agent invocation marker emitted by the model/runtime.
class AgentPart extends MessagePart {
  const AgentPart({
    required super.id,
    required super.messageId,
    required super.sessionId,
    required this.name,
    this.source,
  }) : super(type: PartType.agent);

  final String name;
  final AgentSource? source;

  @override
  List<Object?> get props => [...super.props, name, source];
}

/// Step boundary marker for an assistant run.
class StepStartPart extends MessagePart {
  const StepStartPart({
    required super.id,
    required super.messageId,
    required super.sessionId,
    this.snapshot,
  }) : super(type: PartType.stepStart);

  final String? snapshot;

  @override
  List<Object?> get props => [...super.props, snapshot];
}

/// Step completion marker with token/cost details.
class StepFinishPart extends MessagePart {
  const StepFinishPart({
    required super.id,
    required super.messageId,
    required super.sessionId,
    required this.reason,
    required this.cost,
    required this.tokens,
    this.snapshot,
  }) : super(type: PartType.stepFinish);

  final String reason;
  final String? snapshot;
  final double cost;
  final MessageTokens tokens;

  @override
  List<Object?> get props => [...super.props, reason, snapshot, cost, tokens];
}

/// Snapshot pointer emitted by the runtime.
class SnapshotPart extends MessagePart {
  const SnapshotPart({
    required super.id,
    required super.messageId,
    required super.sessionId,
    required this.snapshot,
  }) : super(type: PartType.snapshot);

  final String snapshot;

  @override
  List<Object?> get props => [...super.props, snapshot];
}

/// Patch part containing file change information.
class PatchPart extends MessagePart {
  const PatchPart({
    required super.id,
    required super.messageId,
    required super.sessionId,
    required this.files,
    required this.hash,
  }) : super(type: PartType.patch);

  final List<String> files;
  final String hash;

  @override
  List<Object?> get props => [...super.props, files, hash];
}

/// User-triggered subtask execution description.
class SubtaskPart extends MessagePart {
  const SubtaskPart({
    required super.id,
    required super.messageId,
    required super.sessionId,
    required this.prompt,
    required this.description,
    required this.agent,
    this.model,
    this.command,
  }) : super(type: PartType.subtask);

  final String prompt;
  final String description;
  final String agent;
  final SubtaskModelRef? model;
  final String? command;

  @override
  List<Object?> get props => [
    ...super.props,
    prompt,
    description,
    agent,
    model,
    command,
  ];
}

/// Retry information when provider calls are retried.
class RetryPart extends MessagePart {
  const RetryPart({
    required super.id,
    required super.messageId,
    required super.sessionId,
    required this.attempt,
    required this.createdAt,
    required this.error,
  }) : super(type: PartType.retry);

  final int attempt;
  final DateTime createdAt;
  final RetryErrorDetails error;

  @override
  List<Object?> get props => [...super.props, attempt, createdAt, error];
}

/// Internal compaction marker for long-running sessions.
class CompactionPart extends MessagePart {
  const CompactionPart({
    required super.id,
    required super.messageId,
    required super.sessionId,
    required this.auto,
  }) : super(type: PartType.compaction);

  final bool auto;

  @override
  List<Object?> get props => [...super.props, auto];
}

/// Technical comment translated to English.
enum PartType {
  text,
  file,
  tool,
  agent,
  reasoning,
  stepStart,
  stepFinish,
  snapshot,
  patch,
  subtask,
  retry,
  compaction,
}

/// Source range metadata for agent parts.
class AgentSource extends Equatable {
  const AgentSource({
    required this.value,
    required this.start,
    required this.end,
  });

  final String value;
  final int start;
  final int end;

  @override
  List<Object?> get props => [value, start, end];
}

/// Model reference associated with subtask parts.
class SubtaskModelRef extends Equatable {
  const SubtaskModelRef({required this.providerId, required this.modelId});

  final String providerId;
  final String modelId;

  @override
  List<Object?> get props => [providerId, modelId];
}

/// Retry error details from upstream API failures.
class RetryErrorDetails extends Equatable {
  const RetryErrorDetails({
    required this.message,
    required this.isRetryable,
    this.statusCode,
  });

  final String message;
  final bool isRetryable;
  final int? statusCode;

  @override
  List<Object?> get props => [message, isRetryable, statusCode];
}

/// Technical comment translated to English.
class FileSource extends Equatable {
  const FileSource({
    required this.path,
    required this.text,
    required this.type,
  });

  final String path;
  final FilePartSourceText text;
  final String type;

  @override
  List<Object?> get props => [path, text, type];
}

/// Symbol source for file parts (LSP symbol references).
class SymbolSource extends Equatable {
  const SymbolSource({
    required this.name,
    required this.kind,
    required this.path,
    required this.range,
    required this.text,
  });

  final String name;
  final int kind;
  final String path;
  final SymbolRange range;
  final FilePartSourceText text;

  @override
  List<Object?> get props => [name, kind, path, range, text];
}

/// Range for symbol source positions.
class SymbolRange extends Equatable {
  const SymbolRange({
    required this.startLine,
    required this.startCharacter,
    required this.endLine,
    required this.endCharacter,
  });

  final int startLine;
  final int startCharacter;
  final int endLine;
  final int endCharacter;

  @override
  List<Object?> get props => [startLine, startCharacter, endLine, endCharacter];
}

/// Technical comment translated to English.
class FilePartSourceText extends Equatable {
  const FilePartSourceText({
    required this.value,
    required this.start,
    required this.end,
  });

  final String value;
  final int start;
  final int end;

  @override
  List<Object?> get props => [value, start, end];
}

/// Technical comment translated to English.
abstract class ToolState extends Equatable {
  const ToolState({required this.status});

  final ToolStatus status;

  @override
  List<Object?> get props => [status];
}

/// Technical comment translated to English.
class ToolStatePending extends ToolState {
  const ToolStatePending() : super(status: ToolStatus.pending);
}

/// Technical comment translated to English.
class ToolStateRunning extends ToolState {
  const ToolStateRunning({
    required this.input,
    required this.time,
    this.title,
    this.metadata,
  }) : super(status: ToolStatus.running);

  final Map<String, dynamic> input;
  final DateTime time;
  final String? title;
  final Map<String, dynamic>? metadata;

  @override
  List<Object?> get props => [...super.props, input, time, title, metadata];
}

/// Technical comment translated to English.
class ToolStateCompleted extends ToolState {
  const ToolStateCompleted({
    required this.input,
    required this.output,
    required this.time,
    this.title,
    this.metadata,
  }) : super(status: ToolStatus.completed);

  final Map<String, dynamic> input;
  final String output;
  final ToolTime time;
  final String? title;
  final Map<String, dynamic>? metadata;

  @override
  List<Object?> get props => [
    ...super.props,
    input,
    output,
    time,
    title,
    metadata,
  ];
}

/// Technical comment translated to English.
class ToolStateError extends ToolState {
  const ToolStateError({
    required this.input,
    required this.error,
    required this.time,
    this.title,
    this.metadata,
  }) : super(status: ToolStatus.error);

  final Map<String, dynamic> input;
  final String error;
  final ToolTime time;
  final String? title;
  final Map<String, dynamic>? metadata;

  @override
  List<Object?> get props => [
    ...super.props,
    input,
    error,
    time,
    title,
    metadata,
  ];
}

/// Technical comment translated to English.
enum ToolStatus { pending, running, completed, error }

/// Technical comment translated to English.
class ToolTime extends Equatable {
  const ToolTime({required this.start, this.end});

  final DateTime start;
  final DateTime? end;

  @override
  List<Object?> get props => [start, end];
}

/// Technical comment translated to English.
class MessageTokens extends Equatable {
  const MessageTokens({
    required this.input,
    required this.output,
    this.reasoning = 0,
    this.cacheRead = 0,
    this.cacheWrite = 0,
  });

  final int input;
  final int output;
  final int reasoning;
  final int cacheRead;
  final int cacheWrite;

  int get total => input + output + reasoning;

  @override
  List<Object?> get props => [input, output, reasoning, cacheRead, cacheWrite];
}

/// Technical comment translated to English.
class MessageError extends Equatable {
  const MessageError({required this.name, required this.message});

  final String name;
  final String message;

  @override
  List<Object?> get props => [name, message];
}
