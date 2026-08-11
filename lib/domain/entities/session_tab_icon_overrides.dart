import 'dart:convert';

import '../../core/utils/path_utils.dart';

const int maxSessionTabIconOverridesPerServer = 256;

class SessionTabIconOverride {
  SessionTabIconOverride({
    required String serverId,
    required String directory,
    required String sessionId,
    required String presetId,
    required this.updatedAtMs,
  }) : serverId = serverId.trim(),
       directory = normalizeFilePath(directory),
       sessionId = sessionId.trim(),
       presetId = presetId.trim();

  final String serverId;
  final String directory;
  final String sessionId;
  final String presetId;
  final int updatedAtMs;

  bool get isValid =>
      serverId.isNotEmpty &&
      directory.isNotEmpty &&
      sessionId.isNotEmpty &&
      presetId.isNotEmpty &&
      updatedAtMs >= 0;

  String get identityKey =>
      jsonEncode(<String>[serverId, directory, sessionId]);

  Map<String, Object> toJson() => <String, Object>{
    'serverId': serverId,
    'directory': directory,
    'sessionId': sessionId,
    'presetId': presetId,
    'updatedAtMs': updatedAtMs,
  };

  static SessionTabIconOverride? fromJson(Object? value) {
    if (value is! Map) return null;
    try {
      final entry = SessionTabIconOverride(
        serverId: value['serverId'] is String
            ? value['serverId'] as String
            : '',
        directory: value['directory'] is String
            ? value['directory'] as String
            : '',
        sessionId: value['sessionId'] is String
            ? value['sessionId'] as String
            : '',
        presetId: value['presetId'] is String
            ? value['presetId'] as String
            : '',
        updatedAtMs: value['updatedAtMs'] is num
            ? (value['updatedAtMs'] as num).toInt()
            : -1,
      );
      return entry.isValid ? entry : null;
    } catch (_) {
      return null;
    }
  }
}

class SessionTabIconOverridesState {
  const SessionTabIconOverridesState({this.entries = const []});

  static const int currentVersion = 1;

  final List<SessionTabIconOverride> entries;

  SessionTabIconOverridesState compacted({
    int maxEntries = maxSessionTabIconOverridesPerServer,
  }) {
    final byIdentity = <String, SessionTabIconOverride>{};
    for (final entry in entries) {
      if (!entry.isValid) continue;
      final previous = byIdentity[entry.identityKey];
      if (previous == null || entry.updatedAtMs >= previous.updatedAtMs) {
        byIdentity[entry.identityKey] = entry;
      }
    }
    final compacted = byIdentity.values.toList(growable: false)
      ..sort((a, b) {
        final timestamp = b.updatedAtMs.compareTo(a.updatedAtMs);
        return timestamp != 0
            ? timestamp
            : a.identityKey.compareTo(b.identityKey);
      });
    return SessionTabIconOverridesState(
      entries: List<SessionTabIconOverride>.unmodifiable(
        compacted.take(maxEntries),
      ),
    );
  }

  String encode() {
    final state = compacted();
    return jsonEncode(<String, Object>{
      'version': currentVersion,
      'entries': state.entries.map((entry) => entry.toJson()).toList(),
    });
  }

  static SessionTabIconOverridesState decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return const SessionTabIconOverridesState();
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map || decoded['version'] != currentVersion) {
        return const SessionTabIconOverridesState();
      }
      final rawEntries = decoded['entries'];
      if (rawEntries is! List) return const SessionTabIconOverridesState();
      return SessionTabIconOverridesState(
        entries: rawEntries
            .map(SessionTabIconOverride.fromJson)
            .whereType<SessionTabIconOverride>()
            .toList(growable: false),
      ).compacted();
    } catch (_) {
      return const SessionTabIconOverridesState();
    }
  }

  static bool requiresCompaction(String? raw) {
    if (raw == null || raw.trim().isEmpty) return false;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map &&
          decoded['version'] == currentVersion &&
          decoded['entries'] is List &&
          (decoded['entries'] as List).length >
              maxSessionTabIconOverridesPerServer;
    } catch (_) {
      return false;
    }
  }
}
