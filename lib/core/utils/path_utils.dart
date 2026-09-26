/// Normalizes a file path: trims whitespace, converts backslashes to forward
/// slashes, and strips trailing slashes except for Unix and Windows drive roots.
String normalizeFilePath(String path) {
  var value = path.trim().replaceAll('\\', '/');
  if (value.isEmpty) {
    return value;
  }
  if (RegExp(r'^/+$').hasMatch(value)) {
    return '/';
  }
  // A drive root is absolute; stripping its slash makes it drive-relative.
  if (RegExp(r'^[A-Za-z]:/+$').hasMatch(value)) {
    return '${value.substring(0, 2)}/';
  }
  if (value.length > 1) {
    value = value.replaceAll(RegExp(r'/+$'), '');
  }
  return value;
}

/// Normalizes an optional path, returning null for empty or placeholder values.
String? normalizeOptionalFilePath(String? path) {
  if (path == null) {
    return null;
  }
  final normalized = normalizeFilePath(path);
  if (normalized.isEmpty || normalized == '-') {
    return null;
  }
  return normalized;
}

/// Compares two paths after applying the shared normalization rules.
bool areEquivalentFilePaths(String? a, String? b) {
  final left = normalizeOptionalFilePath(a);
  final right = normalizeOptionalFilePath(b);
  if (left == null || right == null) {
    return false;
  }
  return left == right;
}

/// Returns the base name (last path component) of a normalized path.
String fileBasename(String path) {
  final normalized = normalizeFilePath(path);
  if (RegExp(r'^[A-Za-z]:/$').hasMatch(normalized)) return normalized;
  if (normalized.isEmpty || normalized == '/') {
    return normalized.isEmpty ? 'file' : '/';
  }
  // normalizeFilePath strips trailing slashes, so separator can never be the
  // last char here (the bare "/" root is already handled above).
  final separator = normalized.lastIndexOf('/');
  if (separator < 0) {
    return normalized;
  }
  return normalized.substring(separator + 1);
}

/// Joins a parent path with a child path segment using a forward slash,
/// returning child unchanged when parent is empty, root, or ".".
String joinParentPath(String parent, String child) {
  if (parent.isEmpty || parent == '/' || parent == '.') {
    return child;
  }
  return '$parent/$child';
}
