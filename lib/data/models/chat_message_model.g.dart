// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_message_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ChatMessageModel _$ChatMessageModelFromJson(Map<String, dynamic> json) =>
    ChatMessageModel(
      id: json['id'] as String,
      sessionId: json['sessionID'] as String,
      role: json['role'] as String,
      time: ChatMessageModel._timeFromJson(json['time']),
      parts:
          (json['parts'] as List<dynamic>?)
              ?.map((e) => MessagePartModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      providerId: json['providerID'] as String?,
      modelId: json['modelID'] as String?,
      cost: (json['cost'] as num?)?.toDouble(),
      tokens: json['tokens'] == null
          ? null
          : MessageTokensModel.fromJson(json['tokens'] as Map<String, dynamic>),
      error: json['error'] == null
          ? null
          : MessageErrorModel.fromJson(json['error'] as Map<String, dynamic>),
      mode: json['mode'] as String?,
      system: ChatMessageModel._systemFromJson(json['system']),
      path: ChatMessageModel._pathFromJson(json['path']),
    );

Map<String, dynamic> _$ChatMessageModelToJson(ChatMessageModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'sessionID': instance.sessionId,
      'role': instance.role,
      'time': instance.time.toIso8601String(),
      'parts': instance.parts,
      'providerID': instance.providerId,
      'modelID': instance.modelId,
      'cost': instance.cost,
      'tokens': instance.tokens,
      'error': instance.error,
      'mode': instance.mode,
      'system': instance.system,
      'path': instance.path,
    };

MessagePartModel _$MessagePartModelFromJson(Map<String, dynamic> json) =>
    MessagePartModel(
      id: json['id'] as String,
      messageId: json['messageID'] as String,
      sessionId: json['sessionID'] as String,
      type: json['type'] as String,
      text: json['text'] as String?,
      url: json['url'] as String?,
      mime: json['mime'] as String?,
      filename: json['filename'] as String?,
      source: json['source'] as Map<String, dynamic>?,
      callId: json['callID'] as String?,
      tool: json['tool'] as String?,
      state: json['state'] as Map<String, dynamic>?,
      time: MessagePartModel._partTimeFromJson(json['time']),
      files: (json['files'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      hash: json['hash'] as String?,
    );

Map<String, dynamic> _$MessagePartModelToJson(MessagePartModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'messageID': instance.messageId,
      'sessionID': instance.sessionId,
      'type': instance.type,
      'text': instance.text,
      'url': instance.url,
      'mime': instance.mime,
      'filename': instance.filename,
      'source': instance.source,
      'callID': instance.callId,
      'tool': instance.tool,
      'state': instance.state,
      'time': instance.time?.toIso8601String(),
      'files': instance.files,
      'hash': instance.hash,
    };
