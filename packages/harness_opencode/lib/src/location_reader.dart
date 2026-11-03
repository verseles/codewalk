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

  /// The configured default agent of [directory]'s location: the value of the
  /// highest-priority config document that sets `default_agent`, or null when
  /// none does. The endpoint lists documents from lowest to highest priority.
  Future<String?> readDefaultAgent({
    required String directory,
    RequestCancellation? cancellation,
  }) async {
    _checkOpen();
    _requireDirectory(directory);
    final path = Uri(
      path: 'api/config',
      queryParameters: {'location[directory]': directory},
    ).toString();
    return _reads.read(path, (value) {
      if (value is! List || value.length > maxEntries) {
        throw const FormatException('Malformed config list.');
      }
      String? agent;
      for (final entry in value) {
        final document = _object(entry);
        final info = document['info'];
        if (document['type'] != 'document' || info is! Map) continue;
        final configured = info['default_agent'];
        if (configured is String && configured.trim().isNotEmpty) {
          agent = configured;
        }
      }
      return agent;
    }, cancellation);
  }

  /// The endpoint's default model for [directory]'s location, named by its
  /// name or, without one, its model id; null when the endpoint has none.
  Future<String?> readDefaultModel({
    required String directory,
    RequestCancellation? cancellation,
  }) async {
    _checkOpen();
    _requireDirectory(directory);
    final path = Uri(
      path: 'api/model/default',
      queryParameters: {'location[directory]': directory},
    ).toString();
    return _reads.read(path, (value) {
      final model = _located(value, directory)['data'];
      if (model == null) return null;
      final object = _object(model);
      final name = object['name'];
      if (name is String && name.trim().isNotEmpty) return name;
      final id = object['modelID'];
      return id is String && id.trim().isNotEmpty ? id : null;
    }, cancellation);
  }

  /// The location's default agent, with its optional model reference: the
  /// configured `default_agent` when selectable, else `build` when
  /// selectable, else the first selectable agent.
  Future<
    ({
      String id,
      String name,
      String? modelId,
      String? providerId,
      String? variant,
    })?
  >
  readDefaultAgentDetails({required String directory}) async {
    _checkOpen();
    _requireDirectory(directory);
    final configured = await readDefaultAgent(directory: directory);
    final path = Uri(
      path: 'api/agent',
      queryParameters: {'location[directory]': directory},
    ).toString();
    return _reads.read(path, (value) {
      final rows = _located(value, directory)['data'];
      if (rows is! List || rows.length > maxEntries) {
        throw const FormatException('Malformed agent list.');
      }
      ({
        String id,
        String name,
        String? modelId,
        String? providerId,
        String? variant,
      })? first,
          build;
      for (final row in rows) {
        final agent = _object(row);
        final mode = agent['mode'];
        final hidden = agent['hidden'];
        if (mode is! String || hidden is! bool) {
          throw const FormatException('Malformed agent.');
        }
        if (hidden || (mode != 'primary' && mode != 'all')) continue;
        final id = _text(agent['id']);
        final name = agent['name'];
        final rawModel = agent['model'];
        final model = rawModel == null ? null : _object(rawModel);
        final details = (
          id: id,
          name: name is String && name.trim().isNotEmpty ? name : id,
          modelId: model == null ? null : _text(model['id']),
          providerId: model == null ? null : _text(model['providerID']),
          variant: model?['variant'] as String?,
        );
        if (id == configured) return details;
        first ??= details;
        if (id == 'build') build ??= details;
      }
      return build ?? first;
    }, null);
  }

  /// The location default model's complete identity and display label.
  Future<({String id, String providerId, String name})?>
  readDefaultModelDetails({required String directory}) async {
    _checkOpen();
    _requireDirectory(directory);
    final path = Uri(
      path: 'api/model/default',
      queryParameters: {'location[directory]': directory},
    ).toString();
    return _reads.read(path, (value) {
      final raw = _located(value, directory)['data'];
      if (raw == null) return null;
      final model = _object(raw);
      final id = _text(model['id']);
      final provider = _text(model['providerID']);
      final name = model['name'];
      return (
        id: id,
        providerId: provider,
        name: name is String && name.trim().isNotEmpty ? name : id,
      );
    }, null);
  }

  /// The display name of agent [id] in [directory]'s location, or null when
  /// the location does not register it.
  Future<String?> readAgentName({
    required String directory,
    required String id,
    RequestCancellation? cancellation,
  }) async {
    _checkOpen();
    _requireDirectory(directory);
    final path = Uri(
      path: 'api/agent',
      queryParameters: {'location[directory]': directory},
    ).toString();
    return _reads.read(path, (value) {
      final rows = _located(value, directory)['data'];
      if (rows is! List || rows.length > maxEntries) {
        throw const FormatException('Malformed agent list.');
      }
      for (final row in rows) {
        final agent = _object(row);
        if (agent['id'] == id) {
          final name = agent['name'];
          return name is String && name.trim().isNotEmpty ? name : id;
        }
      }
      return null;
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

  /// A location-scoped answer wraps its rows under `data` and names the
  /// location it answers, which must be the one asked for.
  Map<String, Object?> _located(Object? value, String directory) {
    final response = _object(value);
    final location = _object(response['location']);
    if (location['directory'] != directory) {
      throw const FormatException('Answer of another location.');
    }
    return response;
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
