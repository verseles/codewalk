import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../storage/metadata_store.dart';
import '../storage/storage_support.dart';

/// The sessions hidden in CodeWalk, a local state the endpoint never sees.
///
/// The endpoint exposes no archive write, so the hide is CodeWalk's own: it
/// survives a restart and it is never sent to the server. A store that could
/// not be read is never overwritten, because dropping an unreadable hide
/// would show a session the user chose to hide.
final class HiddenSessionStore extends ChangeNotifier {
  HiddenSessionStore({required V2MetadataStore store}) : _store = store;

  /// The hidden sessions, a JSON list of session storage keys.
  static const key = 'cw2.sessions.hidden';

  /// The hide list stays small: a session that is hidden once and never
  /// shown again is not worth an unbounded local list.
  static const maxEntries = 512;

  final V2MetadataStore _store;
  final _executor = KeySerialExecutor();
  final _hidden = <String>{};
  bool _loaded = false;
  bool _unreadable = false;
  bool _persistenceError = false;

  /// True when the hidden list was read.
  bool get loaded => _loaded;

  /// True when the hidden list could not be read or parsed. The content is
  /// unknown, so the list stays empty and is never overwritten.
  bool get unreadable => _unreadable;

  /// True when a write failed and was reverted.
  bool get hasPersistenceError => _persistenceError;

  /// The number of hidden sessions.
  int get length => _hidden.length;

  Future<void> initialize() async {
    if (_loaded) return;
    await _executor.run(key, () async {
      final (raw, failed) = await _read();
      if (failed) {
        _hidden.clear();
        _unreadable = true;
      } else {
        _apply(raw);
      }
      _loaded = true;
      notifyListeners();
    });
  }

  Future<(Object?, bool)> _read() async {
    try {
      requireV2Key(key);
      return (await _store.read(key), false);
    } on Object {
      return (null, true);
    }
  }

  void _apply(Object? raw) {
    _hidden.clear();
    _unreadable = false;
    if (raw == null) return;
    if (raw is! String || raw.isEmpty) {
      _unreadable = true;
      return;
    }
    if (raw.length > V2MetadataStore.maxPreferenceChars) {
      _unreadable = true;
      return;
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      _unreadable = true;
      return;
    }
    if (decoded is! List) {
      _unreadable = true;
      return;
    }
    if (decoded.length > maxEntries) {
      _unreadable = true;
      return;
    }
    for (final entry in decoded) {
      if (entry is! String || entry.isEmpty) {
        _unreadable = true;
        _hidden.clear();
        return;
      }
      _hidden.add(entry);
    }
  }

  /// Whether the session with this storage key is hidden.
  bool isHidden(String storageKey) => _hidden.contains(storageKey);

  /// Hides the session, or shows it again.
  ///
  /// The write happens before the local state changes, so a failed write
  /// leaves the row exactly as it was.
  Future<bool> setHidden(String storageKey, {required bool hidden}) async {
    if (!_loaded || _unreadable) return false;
    if (storageKey.isEmpty) return false;
    var written = false;
    await _executor.run(key, () async {
      final next = _hidden.toSet();
      if (hidden) {
        if (next.length >= maxEntries && !next.contains(storageKey)) {
          _persistenceError = true;
          notifyListeners();
          return;
        }
        next.add(storageKey);
      } else {
        next.remove(storageKey);
      }
      final (raw, failed) = await _write(next);
      if (failed) {
        _persistenceError = true;
        notifyListeners();
        return;
      }
      _hidden
        ..clear()
        ..addAll(next);
      _persistenceError = false;
      written = true;
      notifyListeners();
    });
    return written;
  }

  Future<(Object?, bool)> _write(Set<String> next) async {
    try {
      await _store.write(key, jsonEncode(next.toList(growable: false)));
      return (null, false);
    } on Object {
      return (null, true);
    }
  }
}
