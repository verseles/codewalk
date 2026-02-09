import '../../domain/entities/chat_realtime.dart';

Map<String, dynamic> _toStringDynamicMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, val) => MapEntry('$key', val));
  }
  return <String, dynamic>{};
}

class ChatEventModel {
  const ChatEventModel({required this.type, required this.properties});

  final String type;
  final Map<String, dynamic> properties;

  factory ChatEventModel.fromJson(Map<String, dynamic> json) {
    final payload = json['payload'];
    if (payload is Map) {
      final payloadMap = _toStringDynamicMap(payload);
      return ChatEventModel(
        type: payloadMap['type'] as String? ?? 'unknown',
        properties: _toStringDynamicMap(payloadMap['properties']),
      );
    }
    return ChatEventModel(
      type: json['type'] as String? ?? 'unknown',
      properties: _toStringDynamicMap(json['properties']),
    );
  }

  ChatEvent toDomain() {
    return ChatEvent(type: type, properties: properties);
  }
}

class SessionStatusModel {
  const SessionStatusModel({
    required this.type,
    this.attempt,
    this.message,
    this.nextEpochMs,
  });

  final String type;
  final int? attempt;
  final String? message;
  final int? nextEpochMs;

  factory SessionStatusModel.fromJson(Map<String, dynamic> json) {
    return SessionStatusModel(
      type: json['type'] as String? ?? 'idle',
      attempt: (json['attempt'] as num?)?.toInt(),
      message: json['message'] as String?,
      nextEpochMs: (json['next'] as num?)?.toInt(),
    );
  }

  SessionStatusInfo toDomain() {
    final mappedType = switch (type) {
      'busy' => SessionStatusType.busy,
      'retry' => SessionStatusType.retry,
      _ => SessionStatusType.idle,
    };

    return SessionStatusInfo(
      type: mappedType,
      attempt: attempt,
      message: message,
      nextEpochMs: nextEpochMs,
    );
  }
}

class ChatToolRequestRefModel {
  const ChatToolRequestRefModel({
    required this.messageId,
    required this.callId,
  });

  final String messageId;
  final String callId;

  factory ChatToolRequestRefModel.fromJson(Map<String, dynamic> json) {
    return ChatToolRequestRefModel(
      messageId: json['messageID'] as String? ?? '',
      callId: json['callID'] as String? ?? '',
    );
  }

  ChatToolRequestRef toDomain() {
    return ChatToolRequestRef(messageId: messageId, callId: callId);
  }
}

class ChatPermissionRequestModel {
  const ChatPermissionRequestModel({
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
  final ChatToolRequestRefModel? tool;

  factory ChatPermissionRequestModel.fromJson(Map<String, dynamic> json) {
    return ChatPermissionRequestModel(
      id: json['id'] as String? ?? '',
      sessionId: json['sessionID'] as String? ?? '',
      permission: json['permission'] as String? ?? '',
      patterns:
          (json['patterns'] as List<dynamic>?)
              ?.map((value) => '$value')
              .toList(growable: false) ??
          const <String>[],
      always:
          (json['always'] as List<dynamic>?)
              ?.map((value) => '$value')
              .toList(growable: false) ??
          const <String>[],
      metadata: _toStringDynamicMap(json['metadata']),
      tool: json['tool'] is Map<String, dynamic>
          ? ChatToolRequestRefModel.fromJson(
              json['tool'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  ChatPermissionRequest toDomain() {
    return ChatPermissionRequest(
      id: id,
      sessionId: sessionId,
      permission: permission,
      patterns: patterns,
      always: always,
      metadata: metadata,
      tool: tool?.toDomain(),
    );
  }
}

class ChatQuestionOptionModel {
  const ChatQuestionOptionModel({
    required this.label,
    required this.description,
  });

  final String label;
  final String description;

  factory ChatQuestionOptionModel.fromJson(Map<String, dynamic> json) {
    return ChatQuestionOptionModel(
      label: json['label'] as String? ?? '',
      description: json['description'] as String? ?? '',
    );
  }

  ChatQuestionOption toDomain() {
    return ChatQuestionOption(label: label, description: description);
  }
}

class ChatQuestionInfoModel {
  const ChatQuestionInfoModel({
    required this.question,
    required this.header,
    required this.options,
    required this.multiple,
    required this.custom,
  });

  final String question;
  final String header;
  final List<ChatQuestionOptionModel> options;
  final bool multiple;
  final bool custom;

  factory ChatQuestionInfoModel.fromJson(Map<String, dynamic> json) {
    return ChatQuestionInfoModel(
      question: json['question'] as String? ?? '',
      header: json['header'] as String? ?? '',
      options:
          (json['options'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(ChatQuestionOptionModel.fromJson)
              .toList(growable: false) ??
          const <ChatQuestionOptionModel>[],
      multiple: json['multiple'] as bool? ?? false,
      custom: json['custom'] as bool? ?? true,
    );
  }

  ChatQuestionInfo toDomain() {
    return ChatQuestionInfo(
      question: question,
      header: header,
      options: options.map((item) => item.toDomain()).toList(growable: false),
      multiple: multiple,
      custom: custom,
    );
  }
}

class ChatQuestionRequestModel {
  const ChatQuestionRequestModel({
    required this.id,
    required this.sessionId,
    required this.questions,
    this.tool,
  });

  final String id;
  final String sessionId;
  final List<ChatQuestionInfoModel> questions;
  final ChatToolRequestRefModel? tool;

  factory ChatQuestionRequestModel.fromJson(Map<String, dynamic> json) {
    return ChatQuestionRequestModel(
      id: json['id'] as String? ?? '',
      sessionId: json['sessionID'] as String? ?? '',
      questions:
          (json['questions'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(ChatQuestionInfoModel.fromJson)
              .toList(growable: false) ??
          const <ChatQuestionInfoModel>[],
      tool: json['tool'] is Map<String, dynamic>
          ? ChatToolRequestRefModel.fromJson(
              json['tool'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  ChatQuestionRequest toDomain() {
    return ChatQuestionRequest(
      id: id,
      sessionId: sessionId,
      questions: questions
          .map((question) => question.toDomain())
          .toList(growable: false),
      tool: tool?.toDomain(),
    );
  }
}
