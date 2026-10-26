import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../storage/metadata_store.dart';
import '../storage/storage_support.dart';

/// Where the workspace was left: the active server and the last real project
/// of each server, a local state the endpoint never sees.
///
/// A state that could not be read is never overwritten, so an unreadable
/// record does not lose the user's last server or projects.
final class WorkspaceStore extends ChangeNotifier {
  WorkspaceStore({required V2MetadataStore store}) : _store = store;

  /// The workspace state, one JSON object.
  static const key = 'cw2.workspace.state';
  static const _version = 1;

  /// The servers whose last project is kept; the oldest entry leaves first.
  static const maxProjects = 64;

  final V2MetadataStore _store;
  final _executor = KeySerialExecutor();
  String? _active;
  String? _default;
  Map<String, Object?> _raw = {};

  /// The last project of each server, by profile id, oldest first.
  final _projects = <String, String>{};
  bool _loaded = false;
  bool _unreadable = false;
  bool _persistenceError = false;
  bool _disposed = false;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// True when the state was read.
  bool get loaded => _loaded;

  /// True when the state could not be read or parsed. It is never
  /// overwritten, and nothing is saved.
  bool get unreadable => _unreadable;

  /// True when the last write could not be acknowledged.
  bool get hasPersistenceError => _persistenceError;

  /// The profile id of the server the workspace used last.
  String? get activeProfile => _active;

  /// A fallback choice, independent of the server currently in use.
  String? get defaultProfile => _default;

  /// The storage key of the last real project of [profile].
  String? lastProject(String profile) => _projects[profile];

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

  /// Reconciles an uncertain write without attempting another mutation.
  Future<void> retry() async {
    if (_disposed) return;
    await _executor.run(key, () async {
      try {
        _apply(await _store.read(key));
      } on Object {
        _reset(unreadable: true);
      }
      _loaded = true;
      _persistenceError = _unreadable;
      _notify();
    });
  }

  void _reset({required bool unreadable}) {
    _active = null;
    _default = null;
    _raw = {};
    _projects.clear();
    _unreadable = unreadable;
  }

  void _apply(Object? raw) {
    _reset(unreadable: false);
    if (raw == null) return;
    if (raw is! String || raw.isEmpty) return _reset(unreadable: true);
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return _reset(unreadable: true);
    }
    if (decoded is! Map<String, Object?> ||
        decoded['v'] != _version ||
        decoded['active'] is! String? ||
        decoded['default'] is! String? ||
        decoded['projects'] is! Map<String, Object?>?) {
      return _reset(unreadable: true);
    }
    final active = decoded['active'] as String?;
    final defaultProfile = decoded['default'] as String?;
    final projects = decoded['projects'] as Map<String, Object?>? ?? const {};
    if (active == '' || defaultProfile == '' || projects.length > maxProjects) {
      return _reset(unreadable: true);
    }
    for (final MapEntry(:key, :value) in projects.entries) {
      if (key.isEmpty || value is! String || value.isEmpty) {
        return _reset(unreadable: true);
      }
      _projects[key] = value;
    }
    _active = active;
    _default = defaultProfile;
    _raw = decoded;
  }

  /// Records [profile] as the server the workspace uses.
  Future<bool> setActiveProfile(String profile) {
    if (profile.isEmpty) return Future.value(false);
    return _update(
      (projects) => profile == _active ? null : (profile, _default, projects),
    );
  }

  Future<bool> setDefaultProfile(String? profile) {
    if (profile == '') return Future.value(false);
    return _update(
      (projects) => profile == _default ? null : (_active, profile, projects),
    );
  }

  /// Records [project] as the last real project of [profile].
  Future<bool> setLastProject(String profile, String project) {
    if (profile.isEmpty || project.isEmpty) {
      return Future.value(false);
    }
    return _update((projects) {
      if (projects[profile] == project) return null;
      final next = Map.of(projects)
        ..remove(profile)
        ..[profile] = project;
      while (next.length > maxProjects) {
        next.remove(next.keys.first);
      }
      return (_active, _default, next);
    });
  }

  /// Forgets what is kept for a removed server.
  Future<bool> forget(String profile) {
    return _update((projects) {
      if (_active != profile &&
          _default != profile &&
          !projects.containsKey(profile)) {
        return null;
      }
      return (
        _active == profile ? null : _active,
        _default == profile ? null : _default,
        Map.of(projects)..remove(profile),
      );
    });
  }

  /// Serializes acknowledgment as well as writes, so an uncertain result
  /// cannot let the next mutation overwrite committed state from a stale cache.
  Future<bool> _update(
    (String?, String?, Map<String, String>)? Function(
      Map<String, String> projects,
    )
    next,
  ) async {
    if (_disposed || !_loaded || _unreadable) return false;
    var written = false;
    await _executor.run(key, () async {
      if (!_loaded || _unreadable) return;
      // Equality and existence are checked here, after earlier writes settle.
      final state = next(Map.unmodifiable(_projects));
      if (state == null) return;
      final (active, defaultProfile, projects) = state;
      final data = <String, Object?>{
        ..._raw,
        'v': _version,
        'active': active,
        'projects': projects,
      };
      if (defaultProfile == null) {
        data.remove('default');
      } else {
        data['default'] = defaultProfile;
      }
      final payload = jsonEncode(data);
      try {
        await _store.write(key, payload);
      } on Object {
        try {
          final actual = await _store.read(key);
          _apply(actual);
          written = !_unreadable && actual == payload;
        } on Object {
          _reset(unreadable: true);
        }
        _persistenceError = !written;
        _notify();
        return;
      }
      _apply(payload);
      _persistenceError = false;
      written = true;
      _notify();
    });
    return written;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
