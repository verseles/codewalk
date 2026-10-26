import 'dart:convert';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:codewalk_net/codewalk_net.dart';

import 'json_reads.dart';
import 'session_reader.dart';

/// The endpoint's projects, locations and directories: what a project picker
/// offers. Every read is bounded like a session read and fails with the same
/// finite [OpenCodeSessionReadException].
///
/// Directories stay the endpoint's own strings: the reader never normalizes
/// a path, because the endpoint keys a location by its exact directory.
final class OpenCodeLocationReader {
  OpenCodeLocationReader(
    this.transport, {
    required this.harness,
    this.deadline = const Duration(seconds: 20),
    this.maxBodyBytes = 1024 * 1024,
    this.maxEntries = 10000,
    this.maxFindResults = 200,
  }) : _endpoint = transport.endpoint {
    if (deadline <= Duration.zero ||
        maxBodyBytes <= 0 ||
        maxEntries <= 0 ||
        maxFindResults <= 0 ||
        harness.host.value.isEmpty ||
        harness.harness.value.isEmpty) {
      throw ArgumentError('Location read limits must be positive.');
    }
  }

  final EndpointHttpTransport transport;
  final HarnessRef harness;
  final Duration deadline;
  final int maxBodyBytes;
  final int maxEntries;
  final int maxFindResults;
  final Uri _endpoint;
  late final _reads = OpenCodeJsonReads(
    transport,
    deadline: deadline,
    maxBodyBytes: maxBodyBytes,
    checkOpen: _checkOpen,
  );
  bool _disposed = false;

  /// The directories of the projects the endpoint knows, in its order: each
  /// project's directory, then its sandboxes. The project id is only an
  /// annotation; a directory listed twice keeps its first place.
  Future<List<ProjectRef>> listProjects({
    RequestCancellation? cancellation,
  }) async {
    _checkOpen();
    return _reads.read('api/project', (value) {
      if (value is! List || value.length > maxEntries) {
        throw const FormatException('Malformed project list.');
      }
      final seen = <String>{};
      final result = <ProjectRef>[];
      void add(String directory, String id) {
        if (seen.add(directory)) {
          result.add(
            ProjectRef(harness.host, directory, upstreamProjectId: id),
          );
        }
      }

      for (final row in value) {
        final project = _object(row);
        final id = _text(project['id']);
        final sandboxes = project['sandboxes'];
        if (sandboxes is! List || sandboxes.length > maxEntries) {
          throw const FormatException('Malformed project sandboxes.');
        }
        add(_text(project['canonical']), id);
        for (final sandbox in sandboxes) {
          add(_text(sandbox), id);
        }
        if (result.length > maxEntries) {
          throw const FormatException('Project list limit.');
        }
      }
      return result;
    }, cancellation);
  }

  /// Resolves [directory], or the endpoint's default location when it is
  /// null. The answer is the directory as the endpoint keys it, which may
  /// differ from the one asked for.
  Future<ProjectRef> readLocation({
    String? directory,
    RequestCancellation? cancellation,
  }) async {
    _checkOpen();
    if (directory != null) _requireDirectory(directory);
    final path = Uri(
      path: 'api/location',
      queryParameters: {'location[directory]': ?directory},
    ).toString();
    return _reads.read(path, (value) {
      final info = _object(value);
      final project = _object(info['project']);
      return ProjectRef(
        harness.host,
        _text(info['directory']),
        upstreamProjectId: _text(project['id']),
      );
    }, cancellation);
  }

  /// The direct children of [path] in [directory]'s location; [path] is
  /// absolute or relative to [directory] and defaults to it. Entry paths stay
  /// relative to [directory], even for a parent or sibling.
  Future<List<FileEntry>> listDirectory({
    required String directory,
    String? path,
    RequestCancellation? cancellation,
  }) async {
    _checkOpen();
    _requireDirectory(directory);
    if (path != null && utf8.encode(path).length > 4096) {
      throw const OpenCodeSessionReadException(
        OpenCodeSessionReadFailure.invalidRequest,
      );
    }
    final request = Uri(
      path: 'api/fs/list',
      queryParameters: {'location[directory]': directory, 'path': ?path},
    ).toString();
    return _reads.read(
      request,
      (value) => _entries(value, directory, maxEntries),
      cancellation,
    );
  }

  /// The directories in [directory]'s location that match [query], ranked by
  /// the endpoint.
  Future<List<FileEntry>> findDirectories({
    required String directory,
    required String query,
    int limit = 50,
    RequestCancellation? cancellation,
  }) async {
    _checkOpen();
    _requireDirectory(directory);
    if (limit <= 0 ||
        limit > maxFindResults ||
        query.isEmpty ||
        utf8.encode(query).length > 4096) {
      throw const OpenCodeSessionReadException(
        OpenCodeSessionReadFailure.invalidRequest,
      );
    }
    final request = Uri(
      path: 'api/fs/find',
      queryParameters: {
        'location[directory]': directory,
        'query': query,
        'type': 'directory',
        'limit': '$limit',
      },
    ).toString();
    return _reads.read(request, (value) {
      final entries = _entries(value, directory, limit);
      if (entries.any((entry) => entry.kind.known != FileKind.directory)) {
        throw const FormatException('Directory search returned a file.');
      }
      return entries;
    }, cancellation);
  }

  /// Disposes owned reads, never the borrowed transport or caller signal.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _reads.dispose();
  }

  /// A location-scoped answer names its location, which must be the one
  /// asked for.
  List<FileEntry> _entries(Object? value, String directory, int limit) {
    final response = _object(value);
    final location = _object(response['location']);
    if (location['directory'] != directory) {
      throw const FormatException('Entries of another location.');
    }
    final rows = response['data'];
    if (rows is! List || rows.length > limit) {
      throw const FormatException('Malformed entry list.');
    }
    final project = ProjectRef(harness.host, directory);
    return [
      for (final row in rows)
        () {
          final entry = _object(row);
          final kind = switch (entry['type']) {
            'file' => FileKind.file,
            'directory' => FileKind.directory,
            _ => throw const FormatException('Malformed entry type.'),
          };
          return FileEntry(
            ref: FileRef(project: project, path: _text(entry['path'])),
            kind: OpenValue.known(kind),
          );
        }(),
    ];
  }

  void _requireDirectory(String directory) {
    if (directory.isEmpty || utf8.encode(directory).length > 4096) {
      throw const OpenCodeSessionReadException(
        OpenCodeSessionReadFailure.invalidRequest,
      );
    }
  }

  void _checkOpen() {
    if (_disposed || transport.isClosed) {
      throw const OpenCodeSessionReadException(
        OpenCodeSessionReadFailure.closed,
      );
    }
    if (transport.endpoint != _endpoint) {
      throw const OpenCodeSessionReadException(
        OpenCodeSessionReadFailure.invalidScope,
      );
    }
  }
}

Map<String, Object?> _object(Object? value) {
  if (value is! Map<String, Object?>) {
    throw const FormatException('Malformed location object.');
  }
  return value;
}

String _text(Object? value) {
  if (value is! String ||
      value.isEmpty ||
      utf8.encode(value).length > 4096 ||
      utf8.decode(utf8.encode(value)) != value) {
    throw const FormatException('Malformed location text.');
  }
  return value;
}
