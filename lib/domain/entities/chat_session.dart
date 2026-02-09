import 'package:equatable/equatable.dart';

/// Technical comment translated to English.
class ChatSession extends Equatable {
  const ChatSession({
    required this.id,
    required this.workspaceId,
    required this.time,
    this.title,
    this.shared = false,
    this.summary,
    this.path,
  });

  /// Technical comment translated to English.
  final String id;

  /// Technical comment translated to English.
  final String workspaceId;

  /// Technical comment translated to English.
  final DateTime time;

  /// Technical comment translated to English.
  final String? title;

  /// Technical comment translated to English.
  final bool shared;

  /// Technical comment translated to English.
  final String? summary;

  /// Technical comment translated to English.
  final SessionPath? path;

  @override
  List<Object?> get props => [
    id,
    workspaceId,
    time,
    title,
    shared,
    summary,
    path,
  ];

  /// Technical comment translated to English.
  ChatSession copyWith({
    String? id,
    String? workspaceId,
    DateTime? time,
    String? title,
    bool? shared,
    String? summary,
    SessionPath? path,
  }) {
    return ChatSession(
      id: id ?? this.id,
      workspaceId: workspaceId ?? this.workspaceId,
      time: time ?? this.time,
      title: title ?? this.title,
      shared: shared ?? this.shared,
      summary: summary ?? this.summary,
      path: path ?? this.path,
    );
  }
}

/// Technical comment translated to English.
class SessionPath extends Equatable {
  const SessionPath({required this.root, required this.workspace});

  final String root;
  final String workspace;

  @override
  List<Object?> get props => [root, workspace];
}

/// Technical comment translated to English.
class ChatInput extends Equatable {
  const ChatInput({
    this.messageId,
    required this.parts,
    required this.providerId,
    required this.modelId,
    this.mode,
    this.system,
    this.tools,
  });

  final String? messageId;
  final String providerId;
  final String modelId;
  final String? mode;
  final String? system;
  final Map<String, bool>? tools;
  final List<ChatInputPart> parts;

  @override
  List<Object?> get props => [
    messageId,
    providerId,
    modelId,
    mode,
    system,
    tools,
    parts,
  ];
}

/// Technical comment translated to English.
abstract class ChatInputPart extends Equatable {
  const ChatInputPart({required this.type});

  final ChatInputPartType type;

  @override
  List<Object?> get props => [type];
}

/// Technical comment translated to English.
class TextInputPart extends ChatInputPart {
  const TextInputPart({required this.text})
    : super(type: ChatInputPartType.text);

  final String text;

  @override
  List<Object?> get props => [...super.props, text];
}

/// Technical comment translated to English.
class FileInputPart extends ChatInputPart {
  const FileInputPart({required this.source, this.filename})
    : super(type: ChatInputPartType.file);

  final FileInputSource source;
  final String? filename;

  @override
  List<Object?> get props => [...super.props, source, filename];
}

/// Technical comment translated to English.
class AgentInputPart extends ChatInputPart {
  const AgentInputPart({required this.name, this.id, this.source})
    : super(type: ChatInputPartType.agent);

  final String name;
  final String? id;
  final AgentInputSource? source;

  @override
  List<Object?> get props => [...super.props, name, id, source];
}

/// Technical comment translated to English.
enum ChatInputPartType { text, file, agent }

/// Technical comment translated to English.
class FileInputSource extends Equatable {
  const FileInputSource({
    required this.path,
    required this.text,
    required this.type,
  });

  final String path;
  final FileInputSourceText text;
  final String type;

  @override
  List<Object?> get props => [path, text, type];
}

/// Technical comment translated to English.
class FileInputSourceText extends Equatable {
  const FileInputSourceText({
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
class AgentInputSource extends Equatable {
  const AgentInputSource({
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
class SessionCreateInput extends Equatable {
  const SessionCreateInput({this.parentId, this.title});

  final String? parentId;
  final String? title;

  @override
  List<Object?> get props => [parentId, title];
}

/// Technical comment translated to English.
class SessionUpdateInput extends Equatable {
  const SessionUpdateInput({this.title});

  final String? title;

  @override
  List<Object?> get props => [title];
}
