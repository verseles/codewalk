import '../../domain/entities/file_node.dart';

String _normalizeFilePath(String raw) {
  var value = raw.trim().replaceAll('\\', '/');
  if (value.isEmpty) {
    return value;
  }
  if (value.length > 1) {
    value = value.replaceAll(RegExp(r'/+$'), '');
  }
  return value;
}

String _joinParentPath(String parent, String child) {
  if (parent.isEmpty || parent == '/' || parent == '.') {
    return child;
  }
  return '$parent/$child';
}

String _fileBasename(String path) {
  final normalized = _normalizeFilePath(path);
  if (normalized.isEmpty || normalized == '/') {
    return normalized.isEmpty ? 'file' : '/';
  }
  final separator = normalized.lastIndexOf('/');
  if (separator < 0 || separator == normalized.length - 1) {
    return normalized;
  }
  return normalized.substring(separator + 1);
}

FileNodeType _parseFileNodeType(String? raw) {
  final normalized = raw?.trim().toLowerCase() ?? '';
  switch (normalized) {
    case 'file':
      return FileNodeType.file;
    case 'directory':
    case 'dir':
    case 'folder':
      return FileNodeType.directory;
    default:
      return FileNodeType.unknown;
  }
}

String _coercePath(
  dynamic value, {
  required String parentPath,
  String? fallbackName,
}) {
  final raw = value is String ? value.trim() : '';
  if (raw.isNotEmpty) {
    final normalized = _normalizeFilePath(raw);
    if (normalized.startsWith('/')) {
      return normalized;
    }
    // Some servers already return a rooted-relative path (eg: lib/main.dart).
    // In this case, avoid re-joining with parent to prevent duplicated segments.
    if (normalized.contains('/')) {
      return normalized;
    }
    final parent = _normalizeFilePath(parentPath);
    return _normalizeFilePath(_joinParentPath(parent, normalized));
  }

  final safeFallbackName = fallbackName?.trim() ?? '';
  if (safeFallbackName.isEmpty) {
    return _normalizeFilePath(parentPath);
  }
  final parent = _normalizeFilePath(parentPath);
  return _normalizeFilePath(_joinParentPath(parent, safeFallbackName));
}

class FileNodeModel {
  const FileNodeModel({
    required this.path,
    required this.name,
    required this.type,
  });

  final String path;
  final String name;
  final FileNodeType type;

  factory FileNodeModel.fromJson(
    Map<String, dynamic> json, {
    required String parentPath,
  }) {
    final rawName = json['name'] as String?;
    final resolvedPath = _coercePath(
      json['absolute'] ?? json['path'] ?? json['file'] ?? json['id'],
      parentPath: parentPath,
      fallbackName: rawName,
    );
    final fallbackType =
        (json['children'] is List && (json['children'] as List).isNotEmpty)
        ? FileNodeType.directory
        : FileNodeType.unknown;
    final parsedType = _parseFileNodeType(json['type'] as String?);

    return FileNodeModel(
      path: resolvedPath,
      name: (rawName == null || rawName.trim().isEmpty)
          ? _fileBasename(resolvedPath)
          : rawName.trim(),
      type: parsedType == FileNodeType.unknown ? fallbackType : parsedType,
    );
  }

  FileNode toDomain() => FileNode(path: path, name: name, type: type);
}
