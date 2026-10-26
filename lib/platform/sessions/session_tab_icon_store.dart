import 'dart:convert';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/foundation.dart';

import '../storage/metadata_store.dart';
import '../storage/storage_support.dart';
import 'session_tabs_store.dart';

@immutable
final class _TabIcon {
  const _TabIcon(this.project, this.preset);
  final ProjectRef? project;
  final String preset;
}

/// Local glyph choices, independent of tab recency, visibility and order.
/// Project is cleanup metadata; the complete SessionRef remains the identity.
final class SessionTabIconStore extends ChangeNotifier {
  SessionTabIconStore({required V2MetadataStore store}) : _store = store;

  static const key = 'cw2.sessions.tab_icons';
  static const maxIcons = 512;
  final V2MetadataStore _store;
  final _queue = KeySerialExecutor();
  Map<SessionRef, _TabIcon> _icons = {};
  bool _loaded = false;
  bool _unreadable = false;

  bool get unreadable => _unreadable;
  String? presetFor(SessionRef ref) => _unreadable ? null : _icons[ref]?.preset;
  bool anyWhere(bool Function(SessionRef, ProjectRef?) matches) =>
      _icons.entries.any((e) => matches(e.key, e.value.project));

  /// Whether a glyph was saved under another project than [projects] gives
  /// its session.
  bool differs(Map<SessionRef, ProjectRef> projects) =>
      projects.entries.any((entry) {
        final icon = _icons[entry.key];
        return icon != null && icon.project != entry.value;
      });

  /// Moves the glyphs of [projects] to the project given for their session,
  /// keeping each preset, so that project's closure finds them.
  Future<bool> follow(Map<SessionRef, ProjectRef> projects) => _change((icons) {
    for (final MapEntry(key: ref, value: project) in projects.entries) {
      final icon = icons[ref];
      if (icon != null && icon.project != project) {
        icons[ref] = _TabIcon(project, icon.preset);
      }
    }
    return true;
  });

  Future<void> initialize() => _queue.run(key, () async {
    if (_loaded) return;
    await _read();
    notifyListeners();
  });

  Future<void> _read() async {
    try {
      final value = await _store.read(key);
      if (value == null) {
        _icons = {};
      } else {
        final raw = value is String ? jsonDecode(value) : null;
        if (raw is! Map<String, Object?> ||
            raw['version'] != 1 ||
            raw['icons'] is! Map<String, Object?>) {
          throw const FormatException('tab icons');
        }
        final entries = raw['icons']! as Map<String, Object?>;
        if (entries.length > maxIcons) {
          throw const FormatException('tab icon capacity');
        }
        final decoded = <SessionRef, _TabIcon>{};
        for (final entry in entries.entries) {
          // A bad individual glyph falls back; a malformed envelope is kept
          // unreadable instead of replacing an unknown record.
          try {
            final ref = SessionRef.fromStorageKey(entry.key);
            final item = entry.value! as Map<String, Object?>;
            final preset = item['preset']! as String;
            final project = item['project'] == null
                ? null
                : ProjectRef.fromStorageKey(item['project']! as String);
            if (preset.isEmpty ||
                preset.length > 64 ||
                (project != null && project.host != ref.host)) {
              continue;
            }
            decoded[ref] = _TabIcon(project, preset);
          } on Object {
            continue;
          }
        }
        _icons = decoded;
      }
      _unreadable = false;
    } on Object {
      _unreadable = true;
    }
    _loaded = true;
  }

  Future<bool> set(SessionTab tab, String? preset) {
    if (preset != null && (preset.isEmpty || preset.length > 64)) {
      return Future.value(false);
    }
    return _change((icons) {
      if (preset == null) {
        icons.remove(tab.ref);
      } else {
        if (!icons.containsKey(tab.ref) && icons.length >= maxIcons) {
          return false;
        }
        icons[tab.ref] = _TabIcon(tab.project, preset);
      }
      return true;
    });
  }

  Future<bool> removeWhere(bool Function(SessionRef, ProjectRef?) matches) =>
      _change((icons) {
        icons.removeWhere((ref, icon) => matches(ref, icon.project));
        return true;
      });

  Future<bool> _change(
    bool Function(Map<SessionRef, _TabIcon>) change,
  ) => _queue.run(key, () async {
    if (_unreadable) return false;
    // Re-read before mutation, including after a write whose acknowledgement
    // was lost. A later glyph must not overwrite that committed choice.
    await _read();
    if (_unreadable) return false;
    final next = {..._icons};
    if (!change(next)) return false;
    String encode(Map<SessionRef, _TabIcon> icons) => jsonEncode({
      'version': 1,
      'icons': {
        for (final entry in icons.entries)
          entry.key.storageKey: {
            'preset': entry.value.preset,
            'project': entry.value.project?.storageKey,
          },
      },
    });
    if (encode(next) == encode(_icons)) return true;
    try {
      await _store.write(key, encode(next));
    } on Object {
      return false;
    }
    _icons = next;
    notifyListeners();
    return true;
  });
}
