import '../../domain/entities/worktree.dart';

DateTime? _parseDate(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is num) {
    if (value <= 0) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  }
  if (value is String && value.trim().isNotEmpty) {
    return DateTime.tryParse(value);
  }
  return null;
}

String _lastPathSegment(String path) {
  final normalized = path.trim();
  if (normalized.isEmpty) {
    return 'Workspace';
  }
  final withoutTrailing = normalized.endsWith('/')
      ? normalized.substring(0, normalized.length - 1)
      : normalized;
  final separatorIndex = withoutTrailing.lastIndexOf('/');
  if (separatorIndex == -1 || separatorIndex == withoutTrailing.length - 1) {
    return withoutTrailing;
  }
  return withoutTrailing.substring(separatorIndex + 1);
}

class WorktreeModel {
  const WorktreeModel({
    required this.id,
    required this.name,
    required this.directory,
    this.projectId,
    this.active = false,
    this.createdAt,
  });

  final String id;
  final String name;
  final String directory;
  final String? projectId;
  final bool active;
  final DateTime? createdAt;

  factory WorktreeModel.fromJson(Map<String, dynamic> json) {
    final directory =
        (json['directory'] as String?) ??
        (json['path'] as String?) ??
        (json['root'] as String?) ??
        '';
    final id =
        (json['id'] as String?) ??
        (json['worktreeID'] as String?) ??
        (json['workspaceID'] as String?) ??
        directory;
    final name = (json['name'] as String?) ?? _lastPathSegment(directory);

    return WorktreeModel(
      id: id,
      name: name,
      directory: directory,
      projectId:
          (json['projectID'] as String?) ?? (json['projectId'] as String?),
      active: json['active'] as bool? ?? false,
      createdAt: _parseDate(json['createdAt']),
    );
  }

  Worktree toDomain() {
    return Worktree(
      id: id,
      name: name,
      directory: directory,
      projectId: projectId,
      active: active,
      createdAt: createdAt,
    );
  }
}
