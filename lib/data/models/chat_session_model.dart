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
  final String? version;
  final bool shared;
  @JsonKey(fromJson: _summaryFromJson)
  final String? summary;
  final SessionPathModel? path;
  final SessionShareModel? share;

  factory ChatSessionModel.fromJson(Map<String, dynamic> json) =>
      _$ChatSessionModelFromJson(json);

  Map<String, dynamic> toJson() => _$ChatSessionModelToJson(this);

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
      shared: share != null,
      summary: summary,
      path: path?.toDomain(),
    );
  }

  /// Technical comment translated to English.
  static ChatSessionModel fromDomain(ChatSession session) {
    return ChatSessionModel(
      id: session.id,
      workspaceId: session.workspaceId,
      time: SessionTimeModel.fromDomain(session.time),
      title: session.title,
      shared: session.shared,
      summary: session.summary,
      path: session.path != null
          ? SessionPathModel.fromDomain(session.path!)
          : null,
    );
  }
}

/// Technical comment translated to English.
@JsonSerializable()
class SessionTimeModel {
  const SessionTimeModel({required this.created, required this.updated});

  final int created;
  final int updated;

  factory SessionTimeModel.fromJson(Map<String, dynamic> json) =>
      _$SessionTimeModelFromJson(json);

  Map<String, dynamic> toJson() => _$SessionTimeModelToJson(this);

  DateTime toDomain() {
    return DateTime.fromMillisecondsSinceEpoch(created);
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
  final String? mode;
  final String? system;
  final Map<String, bool>? tools;
  final List<ChatInputPartModel> parts;

  factory ChatInputModel.fromJson(Map<String, dynamic> json) =>
      _$ChatInputModelFromJson(json);

  Map<String, dynamic> toJson() => _$ChatInputModelToJson(this);

  static ChatInputModel fromDomain(ChatInput input) {
    return ChatInputModel(
      messageId: input.messageId,
      providerId: input.providerId,
      modelId: input.modelId,
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

  factory ChatInputPartModel.fromJson(Map<String, dynamic> json) =>
      _$ChatInputPartModelFromJson(json);

  Map<String, dynamic> toJson() => _$ChatInputPartModelToJson(this);

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
  const SessionUpdateInputModel({this.title});

  final String? title;

  factory SessionUpdateInputModel.fromJson(Map<String, dynamic> json) =>
      _$SessionUpdateInputModelFromJson(json);

  // Technical comment translated to English.
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (title != null) {
      map['title'] = title;
    }
    return map;
  }

  static SessionUpdateInputModel fromDomain(SessionUpdateInput input) {
    return SessionUpdateInputModel(title: input.title);
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
