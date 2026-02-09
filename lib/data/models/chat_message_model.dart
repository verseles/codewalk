import 'package:json_annotation/json_annotation.dart';
import '../../domain/entities/chat_message.dart';

part 'chat_message_model.g.dart';

/// Chat message model
@JsonSerializable()
class ChatMessageModel {
  const ChatMessageModel({
    required this.id,
    required this.sessionId,
    required this.role,
    required this.time,
    this.completedTime,
    this.parts = const [],
    this.providerId,
    this.modelId,
    this.cost,
    this.tokens,
    this.error,
    this.mode,
    this.system,
    this.path,
    this.isSummary,
  });

  final String id;
  @JsonKey(name: 'sessionID')
  final String sessionId;
  final String role;
  @JsonKey(fromJson: _timeFromJson)
  final DateTime time;
  @JsonKey(includeFromJson: false, includeToJson: false)
  final DateTime? completedTime;
  /// Whether this message is a summary message.
  @JsonKey(includeFromJson: false, includeToJson: false)
  final bool? isSummary;

  static DateTime _timeFromJson(dynamic value) {
    if (value is Map<String, dynamic>) {
      // Handle {"created": number, "completed": number} format
      final created = value['created'] as int?;
      if (created != null) {
        return DateTime.fromMillisecondsSinceEpoch(created);
      }
    } else if (value is int) {
      // Handle direct timestamp
      return DateTime.fromMillisecondsSinceEpoch(value);
    } else if (value is String) {
      // Handle ISO string format
      return DateTime.parse(value);
    }
    // Default to current time
    return DateTime.now();
  }

  static DateTime? _completedTimeFromJson(dynamic value) {
    if (value is Map<String, dynamic>) {
      // Handle {"created": number, "completed": number} format
      final completed = value['completed'] as int?;
      if (completed != null && completed > 0) {
        return DateTime.fromMillisecondsSinceEpoch(completed);
      }
    }
    return null;
  }

  final List<MessagePartModel> parts;
  @JsonKey(name: 'providerID')
  final String? providerId;
  @JsonKey(name: 'modelID')
  final String? modelId;
  final double? cost;
  final MessageTokensModel? tokens;
  final MessageErrorModel? error;
  final String? mode;
  @JsonKey(fromJson: _systemFromJson)
  final List<String>? system;
  @JsonKey(fromJson: _pathFromJson)
  final Map<String, String>? path;

  static List<String>? _systemFromJson(dynamic value) {
    if (value == null) return null;
    if (value is List) {
      return value
          .where((item) => item != null)
          .map((item) => item.toString())
          .toList();
    }
    if (value is String) {
      return [value];
    }
    return null;
  }

  static Map<String, String>? _pathFromJson(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value.map((key, val) => MapEntry(key, val.toString()));
    }
    return null;
  }

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    final model = _$ChatMessageModelFromJson(json);

    // Manually handle completedTime
    final completedTime = _completedTimeFromJson(json['time']);

    // Prepare parts and synthesize text from summary if needed
    final List<MessagePartModel> computedParts = List<MessagePartModel>.from(model.parts);

    // For UserMessage: server may provide `summary` object without `parts`
    // We synthesize a text part so UI can display meaningful content.
    final dynamic summary = json['summary'];
    if (computedParts.isEmpty && summary is Map<String, dynamic>) {
      final title = (summary['title'] as String?)?.trim();
      final body = (summary['body'] as String?)?.trim();
      final diffs = summary['diffs'] as List<dynamic>?;

      final buffer = StringBuffer();
      if (title != null && title.isNotEmpty) buffer.writeln(title);
      if (body != null && body.isNotEmpty) buffer.writeln(body);
      if (diffs != null && diffs.isNotEmpty) {
        for (final d in diffs) {
          if (d is Map<String, dynamic>) {
            final file = (d['file'] as String?) ?? '';
            final after = (d['after'] as String?) ?? '';
            if (file.isNotEmpty) buffer.writeln('File: $file');
            if (after.isNotEmpty) buffer.writeln(after);
          }
        }
      }

      final synthesizedText = buffer.toString().trim();
      if (synthesizedText.isNotEmpty) {
        computedParts.add(
          MessagePartModel(
            id: 'prt_${DateTime.now().millisecondsSinceEpoch}_summary',
            messageId: model.id,
            sessionId: model.sessionId,
            type: 'text',
            text: synthesizedText,
          ),
        );
      }
    }

    // Parse summary as bool for AssistantMessage
    final bool? isSummary = json['summary'] is bool
        ? json['summary'] as bool
        : null;

    return ChatMessageModel(
      id: model.id,
      sessionId: model.sessionId,
      role: model.role,
      time: model.time,
      completedTime: completedTime,
      parts: computedParts,
      providerId: model.providerId,
      modelId: model.modelId,
      cost: model.cost,
      tokens: model.tokens,
      error: model.error,
      mode: model.mode,
      system: model.system,
      path: model.path,
      isSummary: isSummary,
    );
  }

  Map<String, dynamic> toJson() => _$ChatMessageModelToJson(this);

  /// Convert to domain entity
  ChatMessage toDomain() {
    final messageRole = role == 'user'
        ? MessageRole.user
        : MessageRole.assistant;
    final domainParts = parts.map((p) => p.toDomain()).toList();

    if (messageRole == MessageRole.user) {
      return UserMessage(
        id: id,
        sessionId: sessionId,
        time: time,
        parts: domainParts,
      );
    } else {
      return AssistantMessage(
        id: id,
        sessionId: sessionId,
        time: time,
        parts: domainParts,
        completedTime: completedTime,
        providerId: providerId,
        modelId: modelId,
        cost: cost,
        tokens: tokens?.toDomain(),
        error: error?.toDomain(),
        mode: mode,
        summary: isSummary,
      );
    }
  }

  /// Create from domain entity
  static ChatMessageModel fromDomain(ChatMessage message) {
    final parts = message.parts
        .map((p) => MessagePartModel.fromDomain(p))
        .toList();

    if (message is AssistantMessage) {
      return ChatMessageModel(
        id: message.id,
        sessionId: message.sessionId,
        role: 'assistant',
        time: message.time,
        completedTime: message.completedTime,
        parts: parts,
        providerId: message.providerId,
        modelId: message.modelId,
        cost: message.cost,
        tokens: message.tokens != null
            ? MessageTokensModel.fromDomain(message.tokens!)
            : null,
        error: message.error != null
            ? MessageErrorModel.fromDomain(message.error!)
            : null,
        mode: message.mode,
        isSummary: message.summary,
      );
    } else {
      return ChatMessageModel(
        id: message.id,
        sessionId: message.sessionId,
        role: 'user',
        time: message.time,
        parts: parts,
      );
    }
  }
}

/// Message part model
@JsonSerializable()
class MessagePartModel {
  const MessagePartModel({
    required this.id,
    required this.messageId,
    required this.sessionId,
    required this.type,
    this.text,
    this.url,
    this.mime,
    this.filename,
    this.source,
    this.callId,
    this.tool,
    this.state,
    this.time,
    this.files,
    this.hash,
  });

  final String id;
  @JsonKey(name: 'messageID')
  final String messageId;
  @JsonKey(name: 'sessionID')
  final String sessionId;
  final String type;
  final String? text;
  final String? url;
  final String? mime;
  final String? filename;
  final Map<String, dynamic>? source;
  @JsonKey(name: 'callID')
  final String? callId;
  final String? tool;
  final Map<String, dynamic>? state;
  @JsonKey(fromJson: _partTimeFromJson)
  final DateTime? time;
  // Patch part fields
  final List<String>? files;
  final String? hash;

  static DateTime? _partTimeFromJson(dynamic value) {
    if (value == null) return null;
    if (value is Map<String, dynamic>) {
      // Handle {"start": number, "end": number} format
      final start = value['start'] as int?;
      if (start != null) {
        return DateTime.fromMillisecondsSinceEpoch(start);
      }
    } else if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    } else if (value is String) {
      return DateTime.parse(value);
    }
    return null;
  }

  factory MessagePartModel.fromJson(Map<String, dynamic> json) =>
      _$MessagePartModelFromJson(json);

  Map<String, dynamic> toJson() => _$MessagePartModelToJson(this);

  /// Convert to domain entity
  MessagePart toDomain() {
    final partType = _parsePartType(type);

    switch (partType) {
      case PartType.text:
        return TextPart(
          id: id,
          messageId: messageId,
          sessionId: sessionId,
          text: text ?? '',
          time: time,
        );
      case PartType.file:
        final parsed = source != null
            ? _parseFilePartSource(source!)
            : (fileSource: null as FileSource?, symbolSource: null as SymbolSource?);
        return FilePart(
          id: id,
          messageId: messageId,
          sessionId: sessionId,
          url: url ?? '',
          mime: mime ?? '',
          filename: filename,
          fileSource: parsed.fileSource,
          symbolSource: parsed.symbolSource,
        );
      case PartType.tool:
        return ToolPart(
          id: id,
          messageId: messageId,
          sessionId: sessionId,
          callId: callId ?? '',
          tool: tool ?? '',
          state: _parseToolState(state ?? {}),
        );
      case PartType.reasoning:
        return ReasoningPart(
          id: id,
          messageId: messageId,
          sessionId: sessionId,
          text: text ?? '',
          time: time,
        );
      case PartType.patch:
        return PatchPart(
          id: id,
          messageId: messageId,
          sessionId: sessionId,
          files: files ?? <String>[],
          hash: hash ?? '',
        );
      default:
        // Default to text part
        return TextPart(
          id: id,
          messageId: messageId,
          sessionId: sessionId,
          text: text ?? '',
          time: time,
        );
    }
  }

  /// Create from domain entity
  static MessagePartModel fromDomain(MessagePart part) {
    switch (part.type) {
      case PartType.text:
        final textPart = part as TextPart;
        return MessagePartModel(
          id: part.id,
          messageId: part.messageId,
          sessionId: part.sessionId,
          type: 'text',
          text: textPart.text,
          time: textPart.time,
        );
      case PartType.file:
        final filePart = part as FilePart;
        return MessagePartModel(
          id: part.id,
          messageId: part.messageId,
          sessionId: part.sessionId,
          type: 'file',
          url: filePart.url,
          mime: filePart.mime,
          filename: filePart.filename,
          source: filePart.fileSource != null
              ? _fileSourceToMap(filePart.fileSource!)
              : null,
        );
      case PartType.tool:
        final toolPart = part as ToolPart;
        return MessagePartModel(
          id: part.id,
          messageId: part.messageId,
          sessionId: part.sessionId,
          type: 'tool',
          callId: toolPart.callId,
          tool: toolPart.tool,
          state: _toolStateToMap(toolPart.state),
        );
      case PartType.reasoning:
        final reasoningPart = part as ReasoningPart;
        return MessagePartModel(
          id: part.id,
          messageId: part.messageId,
          sessionId: part.sessionId,
          type: 'reasoning',
          text: reasoningPart.text,
          time: reasoningPart.time,
        );
      case PartType.patch:
        final patchPart = part as PatchPart;
        return MessagePartModel(
          id: part.id,
          messageId: part.messageId,
          sessionId: part.sessionId,
          type: 'patch',
          files: patchPart.files,
          hash: patchPart.hash,
        );
      default:
        return MessagePartModel(
          id: part.id,
          messageId: part.messageId,
          sessionId: part.sessionId,
          type: 'text',
        );
    }
  }

  static PartType _parsePartType(String type) {
    switch (type) {
      case 'text':
        return PartType.text;
      case 'file':
        return PartType.file;
      case 'tool':
        return PartType.tool;
      case 'agent':
        return PartType.agent;
      case 'reasoning':
        return PartType.reasoning;
      case 'step_start':
      case 'step-start':
        return PartType.stepStart;
      case 'step_finish':
      case 'step-finish':
        return PartType.stepFinish;
      case 'snapshot':
        return PartType.snapshot;
      case 'patch':
        return PartType.patch;
      default:
        return PartType.text;
    }
  }

  /// Parse file part source, supporting both FileSource and SymbolSource.
  static ({FileSource? fileSource, SymbolSource? symbolSource}) _parseFilePartSource(
      Map<String, dynamic> source) {
    try {
      final type = source['type'] as String? ?? '';
      final text = source['text'] as Map<String, dynamic>?;
      if (text == null) return (fileSource: null, symbolSource: null);

      final sourceText = FilePartSourceText(
        value: text['value'] as String? ?? '',
        start: text['start'] as int? ?? 0,
        end: text['end'] as int? ?? 0,
      );

      if (type == 'symbol') {
        final range = source['range'] as Map<String, dynamic>?;
        final start = range?['start'] as Map<String, dynamic>?;
        final end = range?['end'] as Map<String, dynamic>?;
        return (
          fileSource: null,
          symbolSource: SymbolSource(
            name: source['name'] as String? ?? '',
            kind: source['kind'] as int? ?? 0,
            path: source['path'] as String? ?? '',
            range: SymbolRange(
              startLine: start?['line'] as int? ?? 0,
              startCharacter: start?['character'] as int? ?? 0,
              endLine: end?['line'] as int? ?? 0,
              endCharacter: end?['character'] as int? ?? 0,
            ),
            text: sourceText,
          ),
        );
      }

      return (
        fileSource: FileSource(
          path: source['path'] as String? ?? '',
          text: sourceText,
          type: type,
        ),
        symbolSource: null,
      );
    } catch (e) {
      return (fileSource: null, symbolSource: null);
    }
  }

  static Map<String, dynamic> _fileSourceToMap(FileSource source) {
    return {
      'path': source.path,
      'text': {
        'value': source.text.value,
        'start': source.text.start,
        'end': source.text.end,
      },
      'type': source.type,
    };
  }

  static ToolState _parseToolState(Map<String, dynamic> state) {
    final status = state['status'] as String?;
    switch (status) {
      case 'pending':
        return const ToolStatePending();
      case 'running':
        return ToolStateRunning(
          input: state['input'] as Map<String, dynamic>? ?? {},
          time: DateTime.fromMillisecondsSinceEpoch(
            (state['time']?['start'] as int?) ?? 0,
          ),
          title: state['title'] as String?,
          metadata: state['metadata'] as Map<String, dynamic>?,
        );
      case 'completed':
        final time = state['time'] as Map<String, dynamic>?;
        return ToolStateCompleted(
          input: state['input'] as Map<String, dynamic>? ?? {},
          output: state['output'] as String? ?? '',
          time: ToolTime(
            start: DateTime.fromMillisecondsSinceEpoch(
              (time?['start'] as int?) ?? 0,
            ),
            end: time?['end'] != null
                ? DateTime.fromMillisecondsSinceEpoch(time!['end'] as int)
                : null,
          ),
          title: state['title'] as String?,
          metadata: state['metadata'] as Map<String, dynamic>?,
        );
      case 'error':
        final time = state['time'] as Map<String, dynamic>?;
        return ToolStateError(
          input: state['input'] as Map<String, dynamic>? ?? {},
          error: state['error'] as String? ?? '',
          time: ToolTime(
            start: DateTime.fromMillisecondsSinceEpoch(
              (time?['start'] as int?) ?? 0,
            ),
            end: time?['end'] != null
                ? DateTime.fromMillisecondsSinceEpoch(time!['end'] as int)
                : null,
          ),
          title: state['title'] as String?,
          metadata: state['metadata'] as Map<String, dynamic>?,
        );
      default:
        return const ToolStatePending();
    }
  }

  static Map<String, dynamic> _toolStateToMap(ToolState state) {
    switch (state.status) {
      case ToolStatus.pending:
        return {'status': 'pending'};
      case ToolStatus.running:
        final runningState = state as ToolStateRunning;
        return {
          'status': 'running',
          'input': runningState.input,
          'time': {'start': runningState.time.millisecondsSinceEpoch},
          'title': runningState.title,
          'metadata': runningState.metadata,
        };
      case ToolStatus.completed:
        final completedState = state as ToolStateCompleted;
        return {
          'status': 'completed',
          'input': completedState.input,
          'output': completedState.output,
          'time': {
            'start': completedState.time.start.millisecondsSinceEpoch,
            'end': completedState.time.end?.millisecondsSinceEpoch,
          },
          'title': completedState.title,
          'metadata': completedState.metadata,
        };
      case ToolStatus.error:
        final errorState = state as ToolStateError;
        return {
          'status': 'error',
          'input': errorState.input,
          'error': errorState.error,
          'time': {
            'start': errorState.time.start.millisecondsSinceEpoch,
            'end': errorState.time.end?.millisecondsSinceEpoch,
          },
          'title': errorState.title,
          'metadata': errorState.metadata,
        };
    }
  }
}

/// Message token model
class MessageTokensModel {
  const MessageTokensModel({
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

  static int _intFromJson(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;
    }
    return 0;
  }

  factory MessageTokensModel.fromJson(Map<String, dynamic> json) {
    final cache = json['cache'] as Map<String, dynamic>?;
    return MessageTokensModel(
      input: _intFromJson(json['input']),
      output: _intFromJson(json['output']),
      reasoning: _intFromJson(json['reasoning']),
      cacheRead: _intFromJson(cache?['read']),
      cacheWrite: _intFromJson(cache?['write']),
    );
  }

  Map<String, dynamic> toJson() => {
        'input': input,
        'output': output,
        'reasoning': reasoning,
        'cache': {'read': cacheRead, 'write': cacheWrite},
      };

  MessageTokens toDomain() {
    return MessageTokens(
      input: input,
      output: output,
      reasoning: reasoning,
      cacheRead: cacheRead,
      cacheWrite: cacheWrite,
    );
  }

  static MessageTokensModel fromDomain(MessageTokens tokens) {
    return MessageTokensModel(
      input: tokens.input,
      output: tokens.output,
      reasoning: tokens.reasoning,
      cacheRead: tokens.cacheRead,
      cacheWrite: tokens.cacheWrite,
    );
  }
}

/// Message error model - supports both `{name, message}` and `{name, data}` formats.
class MessageErrorModel {
  const MessageErrorModel({required this.name, required this.message});

  final String name;
  final String message;

  factory MessageErrorModel.fromJson(Map<String, dynamic> json) {
    final name = json['name'] as String? ?? 'UnknownError';
    // Try 'message' first, then extract from 'data'
    String message;
    if (json['message'] is String) {
      message = json['message'] as String;
    } else if (json['data'] is Map<String, dynamic>) {
      final data = json['data'] as Map<String, dynamic>;
      message = data['message'] as String? ?? name;
    } else {
      message = name;
    }
    return MessageErrorModel(name: name, message: message);
  }

  Map<String, dynamic> toJson() => {'name': name, 'message': message};

  MessageError toDomain() {
    return MessageError(name: name, message: message);
  }

  static MessageErrorModel fromDomain(MessageError error) {
    return MessageErrorModel(name: error.name, message: error.message);
  }
}
