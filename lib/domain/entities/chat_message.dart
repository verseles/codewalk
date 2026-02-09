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
  }) : super(role: MessageRole.assistant);

  final DateTime? completedTime;
  final String? providerId;
  final String? modelId;
  final double? cost;
  final MessageTokens? tokens;
  final MessageError? error;
  final String? mode;

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
    this.source,
  }) : super(type: PartType.file);

  final String url;
  final String mime;
  final String? filename;
  final FileSource? source;

  @override
  List<Object?> get props => [...super.props, url, mime, filename, source];
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
    required this.total,
  });

  final int input;
  final int output;
  final int total;

  @override
  List<Object?> get props => [input, output, total];
}

/// Technical comment translated to English.
class MessageError extends Equatable {
  const MessageError({required this.name, required this.message});

  final String name;
  final String message;

  @override
  List<Object?> get props => [name, message];
}
