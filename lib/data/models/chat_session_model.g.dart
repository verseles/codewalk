// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_session_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ChatSessionModel _$ChatSessionModelFromJson(Map<String, dynamic> json) =>
    ChatSessionModel(
      id: json['id'] as String,
      time: SessionTimeModel.fromJson(json['time'] as Map<String, dynamic>),
      workspaceId: json['workspaceId'] as String?,
      title: json['title'] as String?,
      parentId: json['parentID'] as String?,
      directory: json['directory'] as String?,
      version: json['version'] as String?,
      shared: json['shared'] as bool? ?? false,
      summary: ChatSessionModel._summaryFromJson(json['summary']),
      path: json['path'] == null
          ? null
          : SessionPathModel.fromJson(json['path'] as Map<String, dynamic>),
      share: json['share'] == null
          ? null
          : SessionShareModel.fromJson(json['share'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$ChatSessionModelToJson(ChatSessionModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'workspaceId': instance.workspaceId,
      'time': instance.time,
      'title': instance.title,
      'parentID': instance.parentId,
      'directory': instance.directory,
      'version': instance.version,
      'shared': instance.shared,
      'summary': instance.summary,
      'path': instance.path,
      'share': instance.share,
    };

SessionTimeModel _$SessionTimeModelFromJson(Map<String, dynamic> json) =>
    SessionTimeModel(
      created: (json['created'] as num).toInt(),
      updated: (json['updated'] as num).toInt(),
      archived: (json['archived'] as num?)?.toInt(),
    );

Map<String, dynamic> _$SessionTimeModelToJson(SessionTimeModel instance) =>
    <String, dynamic>{
      'created': instance.created,
      'updated': instance.updated,
      'archived': instance.archived,
    };

SessionShareModel _$SessionShareModelFromJson(Map<String, dynamic> json) =>
    SessionShareModel(url: json['url'] as String);

Map<String, dynamic> _$SessionShareModelToJson(SessionShareModel instance) =>
    <String, dynamic>{'url': instance.url};

SessionPathModel _$SessionPathModelFromJson(Map<String, dynamic> json) =>
    SessionPathModel(
      root: json['root'] as String,
      workspace: json['workspace'] as String,
    );

Map<String, dynamic> _$SessionPathModelToJson(SessionPathModel instance) =>
    <String, dynamic>{'root': instance.root, 'workspace': instance.workspace};

ChatInputModel _$ChatInputModelFromJson(Map<String, dynamic> json) =>
    ChatInputModel(
      messageId: json['messageID'] as String?,
      parts: (json['parts'] as List<dynamic>)
          .map((e) => ChatInputPartModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      providerId: json['providerID'] as String,
      modelId: json['modelID'] as String,
      variant: json['variant'] as String?,
      mode: json['mode'] as String?,
      system: json['system'] as String?,
      tools: (json['tools'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as bool),
      ),
    );

Map<String, dynamic> _$ChatInputModelToJson(ChatInputModel instance) =>
    <String, dynamic>{
      'messageID': instance.messageId,
      'providerID': instance.providerId,
      'modelID': instance.modelId,
      'variant': instance.variant,
      'mode': instance.mode,
      'system': instance.system,
      'tools': instance.tools,
      'parts': instance.parts,
    };

ChatInputPartModel _$ChatInputPartModelFromJson(Map<String, dynamic> json) =>
    ChatInputPartModel(
      type: json['type'] as String,
      text: json['text'] as String?,
      source: json['source'] as Map<String, dynamic>?,
      filename: json['filename'] as String?,
      name: json['name'] as String?,
      id: json['id'] as String?,
    );

Map<String, dynamic> _$ChatInputPartModelToJson(ChatInputPartModel instance) =>
    <String, dynamic>{
      'type': instance.type,
      'text': instance.text,
      'source': instance.source,
      'filename': instance.filename,
      'name': instance.name,
      'id': instance.id,
    };

SessionCreateInputModel _$SessionCreateInputModelFromJson(
  Map<String, dynamic> json,
) => SessionCreateInputModel(
  parentId: json['parentID'] as String?,
  title: json['title'] as String?,
);

Map<String, dynamic> _$SessionCreateInputModelToJson(
  SessionCreateInputModel instance,
) => <String, dynamic>{
  'parentID': ?instance.parentId,
  'title': ?instance.title,
};

SessionUpdateInputModel _$SessionUpdateInputModelFromJson(
  Map<String, dynamic> json,
) => SessionUpdateInputModel(
  title: json['title'] as String?,
  archivedAtEpochMs: (json['archivedAtEpochMs'] as num?)?.toInt(),
);

Map<String, dynamic> _$SessionUpdateInputModelToJson(
  SessionUpdateInputModel instance,
) => <String, dynamic>{
  'title': instance.title,
  'archivedAtEpochMs': instance.archivedAtEpochMs,
};
