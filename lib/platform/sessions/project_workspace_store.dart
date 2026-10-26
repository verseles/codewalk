import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../shared/sessions/session_actions.dart';
import '../storage/metadata_store.dart';
import '../storage/storage_support.dart';

/// How the session list is ordered.
enum SessionListSort { recent, oldest, title }

/// What the session list shows, across servers and projects: the search
/// query, the hidden-session filter and the order.
@immutable
final class SessionListPreferences {
  const SessionListPreferences({
    this.query = '',
    this.filter = SessionActionFilter.active,
    this.sort = SessionListSort.recent,
  });
  final String query;
  final SessionActionFilter filter;
  final SessionListSort sort;

  @override
  bool operator ==(Object other) =>
      other is SessionListPreferences &&
      other.query == query &&
      other.filter == filter &&
      other.sort == sort;

  @override
  int get hashCode => Object.hash(query, filter, sort);
}

/// The project contexts of one server: the open ones in their order, the
/// active one, the closed history (most recent first) and the pinned
/// sessions of each open context.
@immutable
final class ProjectWorkspace {
  const ProjectWorkspace({
    this.open = const [],
    this.active,
    this.closed = const [],
    this.pins = const {},
  });
  static const empty = ProjectWorkspace();

  /// The open directories, in the order the user opened them.
  final List<String> open;
  final String? active;
  final List<String> closed;

  /// The pinned session storage keys of each open directory.
  final Map<String, Set<String>> pins;

  bool isPinned(String directory, String storageKey) =>
      pins[directory]?.contains(storageKey) ?? false;
}

/// Why a project change was not saved.
enum ProjectStoreResult {
  saved,

  /// The change was already in place.
  unchanged,

  /// The store was not read, or could not be.
  unavailable,

  /// A bound was reached; nothing is dropped to make room.
  capacity,

  /// The only open context of a server stays open.
  soleContext,

  /// The context is not open.
  notOpen,

  /// The write could not be acknowledged.
  failed,
}

/// The project contexts of every server and the session list preferences,
/// a local state the endpoint never sees.
///
/// Directories are the server's own strings. A state that could not be read
/// is never overwritten, so an unreadable record loses no open project or
/// pin; and a bound refuses the change instead of dropping a choice.
final class ProjectWorkspaceStore extends ChangeNotifier {
  ProjectWorkspaceStore({required V2MetadataStore store}) : _store = store;

  static const key = 'cw2.workspace.projects';
  static const _version = 1;
  static const maxServers = 64;
  static const maxOpen = 32;

  /// The closed history keeps its most recent entries.
  static const maxClosed = 64;
  static const maxPins = 512;
  static const maxQueryChars = 256;
  static const _maxPathBytes = 4096;

  final V2MetadataStore _store;
  final _executor = KeySerialExecutor();
  Map<String, Object?> _raw = {};
  final _servers = <String, ProjectWorkspace>{};
  SessionListPreferences _list = const SessionListPreferences();
  bool _loaded = false;
  bool _unreadable = false;
  bool _persistenceError = false;
  bool _disposed = false;

  bool get loaded => _loaded;
  bool get unreadable => _unreadable;
  bool get hasPersistenceError => _persistenceError;
  SessionListPreferences get listPreferences => _list;

  /// The project contexts of [profile].
  ProjectWorkspace workspace(String profile) =>
      _servers[profile] ?? ProjectWorkspace.empty;

  Future<void> initialize() async {
    if (_loaded || _disposed) return;
    await _executor.run(key, () async {
      if (_loaded) return;
      try {
        _apply(await _store.read(key));
      } on Object {
        _reset(unreadable: true);
      }
      _loaded = true;
      _notify();
    });
  }

  /// Opens [directory] for [profile], or reopens it from the history, and
  /// makes it active unless [activate] is false.
  Future<ProjectStoreResult> open(
    String profile,
    String directory, {
    bool activate = true,
  }) => _change(profile, (state) {
    if (!_validPath(directory)) return ProjectStoreResult.unavailable;
    final opened = state.open.contains(directory);
    if (!opened && state.open.length >= maxOpen) {
      return ProjectStoreResult.capacity;
    }
    return ProjectWorkspace(
      open: opened ? state.open : [...state.open, directory],
      active: activate || state.active == null ? directory : state.active,
      closed: [...state.closed.where((d) => d != directory)],
      pins: state.pins,
    );
  });

  /// Makes the open [directory] the active context of [profile].
  Future<ProjectStoreResult> activate(String profile, String directory) =>
      _change(profile, (state) {
        if (!state.open.contains(directory)) return ProjectStoreResult.notOpen;
        return ProjectWorkspace(
          open: state.open,
          active: directory,
          closed: state.closed,
          pins: state.pins,
        );
      });

  /// Closes [directory] and drops its pins in the same write. A closed
  /// active context hands over to the first remaining open one.
  Future<ProjectStoreResult> close(String profile, String directory) =>
      _change(profile, (state) {
        if (!state.open.contains(directory)) return ProjectStoreResult.notOpen;
        if (state.open.length == 1) return ProjectStoreResult.soleContext;
        final open = [...state.open.where((d) => d != directory)];
        return ProjectWorkspace(
          open: open,
          active: state.active == directory ? open.first : state.active,
          closed: [
            directory,
            ...state.closed.where((d) => d != directory),
          ].take(maxClosed).toList(),
          pins: Map.of(state.pins)..remove(directory),
        );
      });

  /// Removes [directory] from the closed history until it is opened again.
  Future<ProjectStoreResult> forgetClosed(String profile, String directory) =>
      _change(profile, (state) {
        if (!state.closed.contains(directory)) {
          return ProjectStoreResult.unchanged;
        }
        return ProjectWorkspace(
          open: state.open,
          active: state.active,
          closed: [...state.closed.where((d) => d != directory)],
          pins: state.pins,
        );
      });

  /// Pins or unpins a session of the open [directory].
  Future<ProjectStoreResult> setPinned(
    String profile,
    String directory,
    String storageKey, {
    required bool pinned,
  }) => _change(profile, (state) {
    if (!state.open.contains(directory)) return ProjectStoreResult.notOpen;
    if (storageKey.isEmpty) return ProjectStoreResult.unavailable;
    final current = state.pins[directory] ?? const <String>{};
    if (current.contains(storageKey) == pinned) {
      return ProjectStoreResult.unchanged;
    }
    final total = state.pins.values.fold<int>(0, (sum, s) => sum + s.length);
    if (pinned && total >= maxPins) return ProjectStoreResult.capacity;
    final next = pinned
        ? {...current, storageKey}
        : ({...current}..remove(storageKey));
    final pins = Map.of(state.pins);
    if (next.isEmpty) {
      pins.remove(directory);
    } else {
      pins[directory] = next;
    }
    return ProjectWorkspace(
      open: state.open,
      active: state.active,
      closed: state.closed,
      pins: pins,
    );
  });

  /// Saves what the session list shows.
  Future<ProjectStoreResult> setListPreferences(SessionListPreferences next) {
    if (next.query.length > maxQueryChars) {
      return Future.value(ProjectStoreResult.capacity);
    }
    return _write(() => next == _list ? null : (Map.of(_servers), next));
  }

  /// Forgets what is kept for a removed server.
  Future<ProjectStoreResult> forget(String profile) => _write(
    () => _servers.containsKey(profile)
        ? (Map.of(_servers)..remove(profile), _list)
        : null,
  );

  /// Applies [change] to the settled state of [profile]: it returns the next
  /// state, or the [ProjectStoreResult] that refuses the change.
  Future<ProjectStoreResult> _change(
    String profile,
    Object Function(ProjectWorkspace state) change,
  ) {
    if (profile.isEmpty) return Future.value(ProjectStoreResult.unavailable);
    ProjectStoreResult? refused;
    return _write(() {
      final state = workspace(profile);
      final next = change(state);
      if (next is ProjectStoreResult) {
        refused = next;
        return null;
      }
      if (!_servers.containsKey(profile) && _servers.length >= maxServers) {
        refused = ProjectStoreResult.capacity;
        return null;
      }
      return (Map.of(_servers)..[profile] = next as ProjectWorkspace, _list);
    }).then((result) => refused ?? result);
  }

  /// Serializes acknowledgment as well as writes, so an uncertain result
  /// cannot let the next mutation overwrite committed state from a stale
  /// cache.
  Future<ProjectStoreResult> _write(
    (Map<String, ProjectWorkspace>, SessionListPreferences)? Function() next,
  ) async {
    if (_disposed || !_loaded || _unreadable) {
      return ProjectStoreResult.unavailable;
    }
    var result = ProjectStoreResult.unavailable;
    await _executor.run(key, () async {
      if (_disposed || !_loaded || _unreadable) return;
      // The change is computed here, after earlier writes settle.
      final state = next();
      if (state == null) {
        result = ProjectStoreResult.unchanged;
        return;
      }
      final payload = _encode(state.$1, state.$2);
      if (payload == _encode(_servers, _list)) {
        result = ProjectStoreResult.unchanged;
        return;
      }
      if (payload.length > V2MetadataStore.maxPreferenceChars) {
        result = ProjectStoreResult.capacity;
        return;
      }
      try {
        await _store.write(key, payload);
      } on Object {
        try {
          final actual = await _store.read(key);
          _apply(actual);
          if (!_unreadable && actual == payload) {
            result = ProjectStoreResult.saved;
          }
        } on Object {
          _reset(unreadable: true);
        }
        if (result != ProjectStoreResult.saved) {
          result = ProjectStoreResult.failed;
        }
        _persistenceError = result != ProjectStoreResult.saved;
        _notify();
        return;
      }
      _apply(payload);
      _persistenceError = false;
      result = ProjectStoreResult.saved;
      _notify();
    });
    return result;
  }

  String _encode(
    Map<String, ProjectWorkspace> servers,
    SessionListPreferences list,
  ) {
    final previous = _raw['servers'];
    final rawServers = previous is Map<String, Object?> ? previous : const {};
    return jsonEncode({
      ..._raw,
      'v': _version,
      'list': {
        ...?(_raw['list'] as Map<String, Object?>?),
        'query': list.query,
        'filter': list.filter.name,
        'sort': list.sort.name,
      },
      'servers': {
        for (final MapEntry(key: profile, value: state) in servers.entries)
          profile: {
            ...?(rawServers[profile] as Map<String, Object?>?),
            'open': state.open,
            'active': state.active,
            'closed': state.closed,
            'pins': {
              for (final MapEntry(:key, :value) in state.pins.entries)
                key: value.toList(),
            },
          },
      },
    });
  }

  void _reset({required bool unreadable}) {
    _raw = {};
    _servers.clear();
    _list = const SessionListPreferences();
    _unreadable = unreadable;
  }

  void _apply(Object? raw) {
    _reset(unreadable: false);
    if (raw == null) return;
    try {
      if (raw is! String || raw.isEmpty) throw const FormatException();
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, Object?> || decoded['v'] != _version) {
        throw const FormatException();
      }
      final list = _preferences(decoded['list']);
      final servers = decoded['servers'] ?? const <String, Object?>{};
      if (servers is! Map<String, Object?> || servers.length > maxServers) {
        throw const FormatException();
      }
      for (final MapEntry(:key, :value) in servers.entries) {
        if (key.isEmpty) throw const FormatException();
        _servers[key] = _workspace(value);
      }
      _list = list;
      _raw = decoded;
    } on Object {
      _reset(unreadable: true);
    }
  }

  static SessionListPreferences _preferences(Object? value) {
    if (value == null) return const SessionListPreferences();
    if (value is! Map<String, Object?>) throw const FormatException();
    final query = value['query'] ?? '';
    if (query is! String || query.length > maxQueryChars) {
      throw const FormatException();
    }
    // An unknown filter or order falls back to the default: it chooses only
    // what is shown, never what is kept.
    return SessionListPreferences(
      query: query,
      filter:
          SessionActionFilter.values
              .where((f) => f.name == value['filter'])
              .firstOrNull ??
          SessionActionFilter.active,
      sort:
          SessionListSort.values
              .where((s) => s.name == value['sort'])
              .firstOrNull ??
          SessionListSort.recent,
    );
  }

  static ProjectWorkspace _workspace(Object? value) {
    if (value is! Map<String, Object?>) throw const FormatException();
    final open = _paths(value['open'], maxOpen);
    final closed = _paths(value['closed'], maxClosed);
    final active = value['active'];
    if ((active != null && (active is! String || !open.contains(active))) ||
        (active == null && open.isNotEmpty) ||
        closed.any(open.contains)) {
      throw const FormatException();
    }
    final rawPins = value['pins'] ?? const <String, Object?>{};
    if (rawPins is! Map<String, Object?>) throw const FormatException();
    final pins = <String, Set<String>>{};
    var total = 0;
    for (final MapEntry(:key, :value) in rawPins.entries) {
      if (!open.contains(key) || value is! List || value.isEmpty) {
        throw const FormatException();
      }
      final keys = <String>{};
      for (final entry in value) {
        if (entry is! String || entry.isEmpty || !keys.add(entry)) {
          throw const FormatException();
        }
      }
      total += keys.length;
      pins[key] = keys;
    }
    if (total > maxPins) throw const FormatException();
    return ProjectWorkspace(
      open: List.unmodifiable(open),
      active: active as String?,
      closed: List.unmodifiable(closed),
      pins: Map.unmodifiable(pins),
    );
  }

  static List<String> _paths(Object? value, int limit) {
    value ??= const <Object?>[];
    if (value is! List || value.length > limit) throw const FormatException();
    final paths = <String>[];
    for (final entry in value) {
      if (entry is! String || !_validPath(entry) || paths.contains(entry)) {
        throw const FormatException();
      }
      paths.add(entry);
    }
    return paths;
  }

  static bool _validPath(String path) =>
      path.isNotEmpty && utf8.encode(path).length <= _maxPathBytes;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
