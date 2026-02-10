import 'package:json_annotation/json_annotation.dart';
import '../../domain/entities/chat_session.dart';

part 'chat_session_model.g.dart';

/// Technical comment translated to English.
@JsonSerializable()
class ChatSessionModel {
  const ChatSessionModel({
    required this.id,
    required this.time,
    this.workspaceId,
    this.title,
    this.parentId,
    this.directory,
    this.version,
    this.shared = false,
    this.summary,
    this.path,
    this.share,
  });

  final String id;
  final String? workspaceId;
  final SessionTimeModel time;
  final String? title;
  @JsonKey(name: 'parentID')
  final String? parentId;
  final String? directory;
  final String? version;
  final bool shared;
  @JsonKey(fromJson: _summaryFromJson)
  final String? summary;
  final SessionPathModel? path;
  final SessionShareModel? share;

  factory ChatSessionModel.fromJson(Map<String, dynamic> json) {
    final rawShare = json['share'];
    final shareMap = rawShare is Map ? Map<String, dynamic>.from(rawShare) : null;
    final share = shareMap == null ? null : SessionShareModel.fromJson(shareMap);
    final rawPath = json['path'];
    final pathMap = rawPath is Map ? Map<String, dynamic>.from(rawPath) : null;

    return ChatSessionModel(
      id: json['id'] as String? ?? '',
      workspaceId: json['workspaceId'] as String?,
      time: SessionTimeModel.fromJson(
        (json['time'] as Map?)?.map((key, value) => MapEntry('$key', value)) ??
            const <String, dynamic>{},
      ),
      title: json['title'] as String?,
      parentId: json['parentID'] as String?,
      directory: json['directory'] as String?,
      version: json['version'] as String?,
      shared: share != null || json['shared'] == true,
      summary: _summaryFromJson(json['summary']),
      path: pathMap == null ? null : SessionPathModel.fromJson(pathMap),
      share: share,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'id': id, 'time': time.toJson()};
    if (workspaceId != null) {
      map['workspaceId'] = workspaceId;
    }
    if (title != null) {
      map['title'] = title;
    }
    if (parentId != null) {
      map['parentID'] = parentId;
    }
    if (directory != null) {
      map['directory'] = directory;
    }
    if (version != null) {
      map['version'] = version;
    }
    if (summary != null) {
      map['summary'] = summary;
    }
    if (path != null) {
      map['path'] = path!.toJson();
    }
    if (share != null) {
      map['share'] = share!.toJson();
    }
    return map;
  }

  /// Safely parse summary from API which may return Map or String
  static String? _summaryFromJson(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is Map<String, dynamic>) {
      final additions = value['additions'];
      final deletions = value['deletions'];
      // Convert to a compact string for display
      return 'additions: ${additions ?? 0}, deletions: ${deletions ?? 0}';
    }
    // Fallback to string conversion
    return value.toString();
  }

  /// Technical comment translated to English.
  ChatSession toDomain() {
    return ChatSession(
      id: id,
      workspaceId: workspaceId ?? 'default',
      time: time.toDomain(),
      title: title,
      parentId: parentId,
      directory: directory,
      archivedAt: time.archived == null || time.archived! <= 0
          ? null
          : DateTime.fromMillisecondsSinceEpoch(time.archived!),
      shared: share != null || shared,
      shareUrl: share?.url,
      summary: summary,
      path: path?.toDomain(),
    );
  }

  /// Technical comment translated to English.
  static ChatSessionModel fromDomain(ChatSession session) {
    final timestamp = session.time.millisecondsSinceEpoch;
    return ChatSessionModel(
      id: session.id,
      workspaceId: session.workspaceId,
      time: SessionTimeModel(
        created: timestamp,
        updated: timestamp,
        archived: session.archivedAt?.millisecondsSinceEpoch,
      ),
      title: session.title,
      parentId: session.parentId,
      directory: session.directory,
      shared: session.shared,
      summary: session.summary,
      path: session.path != null
          ? SessionPathModel.fromDomain(session.path!)
          : null,
      share: session.shareUrl == null
          ? null
          : SessionShareModel(url: session.shareUrl!),
    );
  }
}

/// Technical comment translated to English.
@JsonSerializable()
class SessionTimeModel {
  const SessionTimeModel({
    required this.created,
    required this.updated,
    this.archived,
  });

  final int created;
  final int updated;
  final int? archived;

  factory SessionTimeModel.fromJson(Map<String, dynamic> json) {
    return SessionTimeModel(
      created: (json['created'] as num?)?.toInt() ?? 0,
      updated: (json['updated'] as num?)?.toInt() ?? 0,
      archived: (json['archived'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'created': created, 'updated': updated};
    if (archived != null) {
      map['archived'] = archived;
    }
    return map;
  }

  DateTime toDomain() {
    final source = updated > 0 ? updated : created;
    return DateTime.fromMillisecondsSinceEpoch(source);
  }

  static SessionTimeModel fromDomain(DateTime time) {
    final timestamp = time.millisecondsSinceEpoch;
    return SessionTimeModel(created: timestamp, updated: timestamp);
  }
}

/// Technical comment translated to English.
@JsonSerializable()
class SessionShareModel {
  const SessionShareModel({required this.url});

  final String url;

  factory SessionShareModel.fromJson(Map<String, dynamic> json) =>
      _$SessionShareModelFromJson(json);

  Map<String, dynamic> toJson() => _$SessionShareModelToJson(this);
}

/// Technical comment translated to English.
@JsonSerializable()
class SessionPathModel {
  const SessionPathModel({required this.root, required this.workspace});

  final String root;
  final String workspace;

  factory SessionPathModel.fromJson(Map<String, dynamic> json) =>
      _$SessionPathModelFromJson(json);

  Map<String, dynamic> toJson() => _$SessionPathModelToJson(this);

  SessionPath toDomain() {
    return SessionPath(root: root, workspace: workspace);
  }

  static SessionPathModel fromDomain(SessionPath path) {
    return SessionPathModel(root: path.root, workspace: path.workspace);
  }
}

/// Technical comment translated to English.
@JsonSerializable()
class ChatInputModel {
  const ChatInputModel({
    this.messageId,
    required this.parts,
    required this.providerId,
    required this.modelId,
    this.variant,
    this.mode,
    this.system,
    this.tools,
  });

  @JsonKey(name: 'messageID')
  final String? messageId;
  @JsonKey(name: 'providerID')
  final String providerId;
  @JsonKey(name: 'modelID')
  final String modelId;
  final String? variant;
  final String? mode;
  final String? system;
  final Map<String, bool>? tools;
  final List<ChatInputPartModel> parts;

  /// Supports both legacy flat (`providerID`/`modelID` + `mode`) and
  /// current nested (`model` + `agent`) request schemas.
  factory ChatInputModel.fromJson(Map<String, dynamic> json) {
    final model = json['model'] as Map<String, dynamic>?;
    final partsJson = (json['parts'] as List<dynamic>?) ?? const <dynamic>[];

    return ChatInputModel(
      messageId: json['messageID'] as String?,
      providerId:
          (model?['providerID'] as String?) ??
          (json['providerID'] as String?) ??
          '',
      modelId:
          (model?['modelID'] as String?) ?? (json['modelID'] as String?) ?? '',
      variant: json['variant'] as String?,
      mode: (json['agent'] as String?) ?? (json['mode'] as String?),
      system: json['system'] as String?,
      tools: (json['tools'] as Map<String, dynamic>?)?.map(
        (key, value) => MapEntry(key, value == true),
      ),
      parts: partsJson
          .map((e) => ChatInputPartModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'parts': parts.map((p) => p.toJson()).toList(),
      'model': {'providerID': providerId, 'modelID': modelId},
      // Force reply creation from /session/{id}/message for sync prompt flow.
      'noReply': false,
    };
    if (messageId != null) {
      map['messageID'] = messageId;
    }
    if (variant != null && variant!.isNotEmpty) {
      map['variant'] = variant;
    }
    if (mode != null && mode!.isNotEmpty) {
      map['agent'] = mode;
    }
    if (system != null && system!.isNotEmpty) {
      map['system'] = system;
    }
    if (tools != null && tools!.isNotEmpty) {
      map['tools'] = tools;
    }
    return map;
  }

  static ChatInputModel fromDomain(ChatInput input) {
    return ChatInputModel(
      messageId: input.messageId,
      providerId: input.providerId,
      modelId: input.modelId,
      variant: input.variant,
      mode: input.mode,
      system: input.system,
      tools: input.tools,
      parts: input.parts.map((p) => ChatInputPartModel.fromDomain(p)).toList(),
    );
  }
}

/// Technical comment translated to English.
@JsonSerializable()
class ChatInputPartModel {
  const ChatInputPartModel({
    required this.type,
    this.text,
    this.source,
    this.filename,
    this.name,
    this.id,
  });

  final String type;
  final String? text;
  final Map<String, dynamic>? source;
  final String? filename;
  final String? name;
  final String? id;

  factory ChatInputPartModel.fromJson(Map<String, dynamic> json) {
    return ChatInputPartModel(
      type: json['type'] as String,
      text: json['text'] as String?,
      source: json['source'] as Map<String, dynamic>?,
      filename: json['filename'] as String?,
      name: json['name'] as String?,
      id: json['id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'type': type};
    if (text != null) {
      map['text'] = text;
    }
    if (source != null) {
      map['source'] = source;
    }
    if (filename != null) {
      map['filename'] = filename;
    }
    if (name != null) {
      map['name'] = name;
    }
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  /// Technical comment translated to English.
  static ChatInputPartModel fromDomain(ChatInputPart part) {
    switch (part.type) {
      case ChatInputPartType.text:
        final textPart = part as TextInputPart;
        return ChatInputPartModel(
          type: 'text',
          text: textPart.text,
          id: 'prt_${DateTime.now().millisecondsSinceEpoch}', // Technical comment translated to English.
        );
      case ChatInputPartType.file:
        final filePart = part as FileInputPart;
        return ChatInputPartModel(
          type: 'file',
          source: filePart.source.toMap(),
          filename: filePart.filename,
          id: 'prt_${DateTime.now().millisecondsSinceEpoch}', // Technical comment translated to English.
        );
      case ChatInputPartType.agent:
        final agentPart = part as AgentInputPart;
        return ChatInputPartModel(
          type: 'agent',
          name: agentPart.name,
          id:
              agentPart.id ??
              'prt_${DateTime.now().millisecondsSinceEpoch}', // Technical comment translated to English.
          source: agentPart.source?.toMap(),
        );
    }
  }
}

/// Technical comment translated to English.
@JsonSerializable()
class SessionCreateInputModel {
  const SessionCreateInputModel({this.parentId, this.title});

  @JsonKey(name: 'parentID', includeIfNull: false)
  final String? parentId;
  @JsonKey(includeIfNull: false)
  final String? title;

  factory SessionCreateInputModel.fromJson(Map<String, dynamic> json) =>
      _$SessionCreateInputModelFromJson(json);

  // Technical comment translated to English.
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (parentId != null) {
      map['parentID'] = parentId;
    }
    if (title != null) {
      map['title'] = title;
    }
    return map;
  }

  static SessionCreateInputModel fromDomain(SessionCreateInput input) {
    return SessionCreateInputModel(
      parentId: input.parentId,
      title: input.title ?? 'New chat',
    );
  }
}

/// Technical comment translated to English.
@JsonSerializable()
class SessionUpdateInputModel {
  const SessionUpdateInputModel({this.title, this.archivedAtEpochMs});

  final String? title;
  final int? archivedAtEpochMs;

  factory SessionUpdateInputModel.fromJson(Map<String, dynamic> json) =>
      _$SessionUpdateInputModelFromJson(json);

  // Technical comment translated to English.
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (title != null) {
      map['title'] = title;
    }
    if (archivedAtEpochMs != null) {
      map['time'] = <String, dynamic>{'archived': archivedAtEpochMs};
    }
    return map;
  }

  static SessionUpdateInputModel fromDomain(SessionUpdateInput input) {
    return SessionUpdateInputModel(
      title: input.title,
      archivedAtEpochMs: input.archivedAtEpochMs,
    );
  }
}

/// Technical comment translated to English.
extension on FileInputSource {
  Map<String, dynamic> toMap() {
    return {
      'path': path,
      'text': {'value': text.value, 'start': text.start, 'end': text.end},
      'type': type,
    };
  }
}

extension on AgentInputSource {
  Map<String, dynamic> toMap() {
    return {'value': value, 'start': start, 'end': end};
  }
}
