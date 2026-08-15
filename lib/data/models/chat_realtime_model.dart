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

  factory ChatEventModel.fromJson(Map<String, dynamic> json) {
    final payload = json['payload'];
    if (payload is Map) {
      final payloadMap = _toStringDynamicMap(payload);
      final properties = Map<String, dynamic>.from(
        _toStringDynamicMap(payloadMap['properties']),
      );
      for (final key in const <String>['directory', 'project', 'workspace']) {
        final value = json[key];
        if (value is String && value.trim().isNotEmpty) {
          properties[key] = value;
        }
      }
      return ChatEventModel(
        type: payloadMap['type'] as String? ?? 'unknown',
        properties: properties,
      );
    }
    return ChatEventModel(
      type: json['type'] as String? ?? 'unknown',
      properties: Map<String, dynamic>.from(
        _toStringDynamicMap(json['properties']),
      ),
    );
  }
  const ChatEventModel({required this.type, required this.properties});

  final String type;
  final Map<String, dynamic> properties;

  ChatEvent toDomain() {
    return ChatEvent(type: type, properties: properties);
  }
}

class SessionStatusModel {

  factory SessionStatusModel.fromJson(Map<String, dynamic> json) {
    return SessionStatusModel(
      type: json['type'] as String? ?? 'idle',
      attempt: (json['attempt'] as num?)?.toInt(),
      message: json['message'] as String?,
      nextEpochMs: (json['next'] as num?)?.toInt(),
    );
  }
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

  factory ChatToolRequestRefModel.fromJson(Map<String, dynamic> json) {
    return ChatToolRequestRefModel(
      messageId: json['messageID'] as String? ?? '',
      callId: json['callID'] as String? ?? '',
    );
  }
  const ChatToolRequestRefModel({
    required this.messageId,
    required this.callId,
  });

  final String messageId;
  final String callId;

  ChatToolRequestRef toDomain() {
    return ChatToolRequestRef(messageId: messageId, callId: callId);
  }
}

class ChatPermissionRequestModel {

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

  factory ChatQuestionOptionModel.fromJson(Map<String, dynamic> json) {
    return ChatQuestionOptionModel(
      label: json['label'] as String? ?? '',
      description: json['description'] as String? ?? '',
    );
  }
  const ChatQuestionOptionModel({
    required this.label,
    required this.description,
  });

  final String label;
  final String description;

  ChatQuestionOption toDomain() {
    return ChatQuestionOption(label: label, description: description);
  }
}

class ChatQuestionInfoModel {

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

  factory ChatQuestionRequestModel.fromJson(Map<String, dynamic> json) {
    // Defensive unwrap: some server builds nest the request under an envelope
    // key or use camelCase field names; the SSE reducers already unwrap
    // `question`/`request`/`info`, and the REST list must tolerate the same
    // shapes so requests never land under an empty session key. Only descend
    // into an envelope when the top level carries no request fields.
    var payload = json;
    if (json['id'] == null &&
        json['sessionID'] == null &&
        json['sessionId'] == null) {
      for (final key in const <String>['question', 'request', 'info']) {
        final candidate = json[key];
        if (candidate is Map<String, dynamic>) {
          payload = candidate;
          break;
        }
      }
    }
    return ChatQuestionRequestModel(
      id: payload['id'] as String? ?? payload['requestID'] as String? ?? '',
      sessionId:
          payload['sessionID'] as String? ??
          payload['sessionId'] as String? ??
          '',
      questions:
          (payload['questions'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(ChatQuestionInfoModel.fromJson)
              .toList(growable: false) ??
          const <ChatQuestionInfoModel>[],
      tool: payload['tool'] is Map<String, dynamic>
          ? ChatToolRequestRefModel.fromJson(
              payload['tool'] as Map<String, dynamic>,
            )
          : null,
    );
  }
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
