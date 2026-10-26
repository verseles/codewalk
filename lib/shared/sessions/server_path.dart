/// Lexical handling of a server's directory paths.
///
/// The server keys a location by its exact directory string, so these helpers
/// never decide identity: they only name a directory, step to its parent, or
/// build the absolute path to ask the server about. The server's answer is
/// the identity.
library;

final _drive = RegExp(r'^[A-Za-z]:([\\/]|$)');
final _separators = RegExp(r'[\\/]');

/// Whether [path] is absolute on a POSIX or Windows server: `/…`, a drive
/// root such as `C:/` or `C:\`, or a native UNC path `\\server\share`. A
/// bare `C:` is drive-relative, not absolute.
bool isAbsoluteServerPath(String path) =>
    path.startsWith('/') ||
    (_drive.hasMatch(path) && path.length > 2) ||
    _unc(path) != null;

/// The directory's own name for display: its last segment, or its root.
String serverPathName(String path) {
  final parts = _split(path);
  return parts.segments.isEmpty ? parts.root : parts.segments.last;
}

/// The parent of an absolute [path], or null at its root.
String? serverPathParent(String path) {
  if (!isAbsoluteServerPath(path)) return null;
  final parts = _split(path);
  if (parts.segments.isEmpty) return null;
  return _join(
    parts.root,
    parts.segments.take(parts.segments.length - 1),
    parts.separator,
  );
}

/// The absolute path of [relative] inside [base], resolving `.` and `..`
/// lexically and never above the root. An absolute [relative] is returned
/// as it is.
String resolveServerPath(String base, String relative) {
  if (isAbsoluteServerPath(relative)) return relative;
  final parts = _split(base);
  final segments = [...parts.segments];
  for (final segment in relative.split(_separators)) {
    if (segment.isEmpty || segment == '.') continue;
    if (segment == '..') {
      if (segments.isNotEmpty) segments.removeLast();
      continue;
    }
    segments.add(segment);
  }
  return _join(parts.root, segments, parts.separator);
}

({String root, List<String> segments, String separator}) _split(String path) {
  final unc = _unc(path);
  if (unc != null) {
    return (
      root: unc,
      segments: _segments(path.substring(unc.length)),
      separator: r'\',
    );
  }
  final drive = _drive.firstMatch(path);
  if (drive != null) {
    final separator = path.contains(r'\') ? r'\' : '/';
    return (
      root: '${path.substring(0, 2)}$separator',
      segments: _segments(path.substring(2)),
      separator: separator,
    );
  }
  if (path.startsWith('/')) {
    return (root: '/', segments: _segments(path), separator: '/');
  }
  return (root: '', segments: _segments(path), separator: '/');
}

/// The `\\server\share` root of a native UNC path.
String? _unc(String path) {
  if (!path.startsWith(r'\\')) return null;
  final parts = path.substring(2).split(r'\');
  if (parts.length < 2 || parts[0].isEmpty || parts[1].isEmpty) return null;
  return '\\\\${parts[0]}\\${parts[1]}';
}

List<String> _segments(String path) =>
    path.split(_separators).where((segment) => segment.isNotEmpty).toList();

String _join(String root, Iterable<String> segments, String separator) {
  final tail = segments.join(separator);
  if (root.isEmpty) return tail;
  if (tail.isEmpty) return root;
  // A UNC root carries no trailing separator; the other roots end in one.
  return root.endsWith(separator) ? '$root$tail' : '$root$separator$tail';
}
