import 'dart:convert';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/foundation.dart';
import '../../shared/sessions/permission_mode.dart';
import '../storage/metadata_store.dart';
import '../storage/storage_support.dart';

/// Reads and writes CodeWalk's permission policy for authored v2 (ADR-059):
/// a default-ON global mode plus bounded per-session overrides. A cold or
/// failed read never becomes Allow all, because an unreadable preference must
/// not grant standing approval authority.
final class PermissionModeStore extends ChangeNotifier
    implements PermissionModePolicy {
  PermissionModeStore({required V2MetadataStore store}) : _store = store;

  /// Global default: `ask` | `allowAll`. Absent means the new-install default
  /// (Allow all ON). The v1 importer writes the same key with `ask` for a
  /// preserved OFF value (V2-076A).
  static const globalKey = 'cw2.settings.permissionMode';

  /// Per-session overrides, a JSON object of session storage keys to modes.
  static const overridesKey = 'cw2.sessions.permissionModes';

  /// Overrides stay small and are never evicted to make room: a silently
  /// dropped Ask would re-enable approvals.
  static const maxOverrides = 256;

  final V2MetadataStore _store;
  final _executor = KeySerialExecutor();
  final _overrides = <String, PermissionMode>{};
  PermissionMode? _global;
  PermissionModeSource _globalSource = PermissionModeSource.defaultOn;
  String? _reason;
  bool _loaded = false;
  bool _persistenceError = false;

  /// Set when the stored overrides cannot be read or parsed as a map of known
  /// modes.
  /// Their content is unknown, so no session keeps standing approval: the
  /// corrupted blob is never overwritten, because dropping an unreadable Ask
  /// would silently re-enable approvals for that session.
  bool _overridesUnreadable = false;

  @override
  bool get loaded => _loaded;

  /// True when the policy could not be applied: a write failed and was
  /// reverted, or it was refused because persisting would drop unreadable
  /// overrides or exceed the bound.
  bool get hasPersistenceError => _persistenceError;

  Future<void> initialize() async {
    if (_loaded) return;
    final (rawGlobal, globalFailed) = await _read(globalKey);
    if (globalFailed) {
      // A failed read is not an absent value: fail closed and stay explicit.
      _global = null;
      _reason = 'unreadable';
    } else {
      _applyGlobal(rawGlobal);
    }
    final (rawOverrides, overridesFailed) = await _read(overridesKey);
    if (overridesFailed) {
      // Their content is unknown, so no session keeps standing approval and
      // a later write must not overwrite the unread blob.
      _overrides.clear();
      _overridesUnreadable = true;
    } else {
      _applyOverrides(rawOverrides);
    }
    _loaded = true;
    notifyListeners();
  }

  Future<(Object?, bool)> _read(String key) async {
    try {
      requireV2Key(key);
      return (await _store.read(key), false);
    } on Object {
      return (null, true);
    }
  }

  void _applyGlobal(Object? raw) {
    if (raw == null) {
      _global = PermissionMode.allowAll;
      _globalSource = PermissionModeSource.defaultOn;
      _reason = null;
      return;
    }
    final mode = _parse(raw);
    if (mode == null) {
      _global = null;
      _reason = 'unsupportedMode';
      return;
    }
    _global = mode;
    _globalSource = PermissionModeSource.global;
    _reason = null;
  }

  void _applyOverrides(Object? raw) {
    _overrides.clear();
    _overridesUnreadable = false;
    if (raw == null) return;
    if (raw is! String || raw.isEmpty) {
      _overridesUnreadable = true;
      return;
    }
    if (raw.length > V2MetadataStore.maxPreferenceChars) {
      _overridesUnreadable = true;
      return;
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      _overridesUnreadable = true;
      return;
    }
    if (decoded is! Map) {
      _overridesUnreadable = true;
      return;
    }
    final parsed = <String, PermissionMode>{};
    for (final entry in decoded.entries) {
      final key = entry.key;
      final mode = entry.value is String ? _parse(entry.value) : null;
      if (key is! String || key.isEmpty || mode == null) {
        _overridesUnreadable = true;
        _overrides.clear();
        return;
      }
      parsed[key] = mode;
    }
    _overrides.addAll(parsed);
  }

  static PermissionMode? _parse(Object? raw) => switch (raw) {
    'ask' => PermissionMode.ask,
    'allowAll' => PermissionMode.allowAll,
    _ => null,
  };

  static String _name(PermissionMode mode) => switch (mode) {
    PermissionMode.ask => 'ask',
    PermissionMode.allowAll => 'allowAll',
  };

  @override
  SessionPermissionModeState effectiveFor(SessionRef session) {
    if (!_loaded) {
      return const SessionPermissionModeState.unavailable('loading');
    }
    if (_overridesUnreadable) {
      return const SessionPermissionModeState.unavailable(
        'unreadableOverrides',
      );
    }
    final override = _overrides[session.storageKey];
    if (override != null) {
      return SessionPermissionModeState(
        mode: override,
        source: PermissionModeSource.session,
      );
    }
    final global = _global;
    if (global == null) {
      return SessionPermissionModeState.unavailable(_reason ?? 'unreadable');
    }
    return SessionPermissionModeState(mode: global, source: _globalSource);
  }

  PermissionMode? get defaultMode => _global;

  Future<bool> setDefaultMode(PermissionMode mode) =>
      _executor.run(globalKey, () async {
        // The requested value only takes effect once it is persisted, so the
        // automatic responder never answers under a mode the app then reverts.
        // An already stored equal value counts as success, and an explicit
        // choice records the global source instead of the install default.
        final written = await _write(globalKey, _name(mode));
        if (!written) {
          _persistenceError = true;
          notifyListeners();
          return false;
        }
        _global = mode;
        _globalSource = PermissionModeSource.global;
        _reason = null;
        _persistenceError = false;
        notifyListeners();
        return true;
      });

  Future<bool> setSessionMode(SessionRef session, PermissionMode mode) =>
      _executor.run(overridesKey, () async {
        final key = session.storageKey;
        if (_overridesUnreadable) {
          // Rewriting would drop overrides that cannot be read, so the
          // corrupted blob stays intact until an explicit repair exists.
          _persistenceError = true;
          notifyListeners();
          return false;
        }
        final previous = _overrides[key];
        if (previous == mode) {
          if (_persistenceError) {
            _persistenceError = false;
            notifyListeners();
          }
          return true;
        }
        if (previous == null && _overrides.length >= maxOverrides) {
          _persistenceError = true;
          notifyListeners();
          return false;
        }
        final written = await _write(
          overridesKey,
          _encode({..._overrides, key: mode}),
        );
        if (!written) {
          _persistenceError = true;
          notifyListeners();
          return false;
        }
        _overrides[key] = mode;
        _persistenceError = false;
        notifyListeners();
        return true;
      });

  Future<bool> clearSessionMode(SessionRef session) =>
      _executor.run(overridesKey, () async {
        final key = session.storageKey;
        if (_overridesUnreadable) {
          _persistenceError = true;
          notifyListeners();
          return false;
        }
        if (!_overrides.containsKey(key)) {
          if (_persistenceError) {
            _persistenceError = false;
            notifyListeners();
          }
          return true;
        }
        final next = Map<String, PermissionMode>.from(_overrides)..remove(key);
        final written = await _write(overridesKey, _encode(next));
        if (!written) {
          _persistenceError = true;
          notifyListeners();
          return false;
        }
        _overrides.remove(key);
        _persistenceError = false;
        notifyListeners();
        return true;
      });

  /// Dismisses the "could not be applied" indicator; nothing is retried, so
  /// the settings surface asks the user again instead.
  Future<void> clearPersistenceError() async {
    _persistenceError = false;
    notifyListeners();
  }

  String _encode(Map<String, PermissionMode> modes) => jsonEncode({
    for (final entry in modes.entries) entry.key: _name(entry.value),
  });

  Future<bool> _write(String key, String value) async {
    try {
      requireV2Key(key);
      if (await _store.write(key, value)) return true;
      // A no-op write reports false; it only counts as success when the
      // stored value already matches.
      return await _store.read(key) == value;
    } on Object {
      return false;
    }
  }
}
