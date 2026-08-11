import 'dart:async';

import '../../core/utils/path_utils.dart';
import '../../data/datasources/app_local_datasource.dart';
import '../../domain/entities/session_tab_icon_overrides.dart';

class SessionTabIconOverrideStore {
  SessionTabIconOverrideStore({required AppLocalDataSource localDataSource})
    : _localDataSource = localDataSource;

  final AppLocalDataSource _localDataSource;
  final Map<String, Future<void>> _queueByServer = <String, Future<void>>{};
  final Set<String> _removedServerIds = <String>{};

  Future<SessionTabIconOverridesState> load(String serverId) {
    final normalizedServerId = serverId.trim();
    if (normalizedServerId.isEmpty ||
        _removedServerIds.contains(normalizedServerId)) {
      return Future.value(const SessionTabIconOverridesState());
    }
    return _serialize(normalizedServerId, () async {
      final raw = await _localDataSource.getSessionTabIconOverridesJson(
        serverId: normalizedServerId,
      );
      final state = SessionTabIconOverridesState.decode(raw);
      if (SessionTabIconOverridesState.requiresCompaction(raw)) {
        await _localDataSource.saveSessionTabIconOverridesJson(
          state.encode(),
          serverId: normalizedServerId,
        );
      }
      return state;
    });
  }

  Future<SessionTabIconOverridesState> setPreset({
    required String serverId,
    required String directory,
    required String sessionId,
    required String? presetId,
    required int updatedAtMs,
  }) {
    final normalizedServerId = serverId.trim();
    final normalizedDirectory = normalizeFilePath(directory);
    final normalizedSessionId = sessionId.trim();
    return _mutate(normalizedServerId, (entries) {
      entries.removeWhere(
        (entry) =>
            entry.serverId == normalizedServerId &&
            entry.directory == normalizedDirectory &&
            entry.sessionId == normalizedSessionId,
      );
      final normalizedPresetId = presetId?.trim();
      if (normalizedPresetId != null && normalizedPresetId.isNotEmpty) {
        final newestTimestamp = entries.fold<int>(
          0,
          (newest, entry) =>
              entry.updatedAtMs > newest ? entry.updatedAtMs : newest,
        );
        entries.add(
          SessionTabIconOverride(
            serverId: normalizedServerId,
            directory: normalizedDirectory,
            sessionId: normalizedSessionId,
            presetId: normalizedPresetId,
            updatedAtMs: updatedAtMs > newestTimestamp
                ? updatedAtMs
                : newestTimestamp + 1,
          ),
        );
      }
    });
  }

  Future<SessionTabIconOverridesState> removeIdentity({
    required String serverId,
    required String directory,
    required String sessionId,
  }) {
    final normalizedServerId = serverId.trim();
    final normalizedDirectory = normalizeFilePath(directory);
    final normalizedSessionId = sessionId.trim();
    return _mutate(normalizedServerId, (entries) {
      entries.removeWhere(
        (entry) =>
            entry.serverId == normalizedServerId &&
            entry.directory == normalizedDirectory &&
            entry.sessionId == normalizedSessionId,
      );
    });
  }

  Future<SessionTabIconOverridesState> removeDirectory({
    required String serverId,
    required String directory,
  }) {
    final normalizedServerId = serverId.trim();
    final normalizedDirectory = normalizeFilePath(directory);
    return _mutate(normalizedServerId, (entries) {
      entries.removeWhere(
        (entry) =>
            entry.serverId == normalizedServerId &&
            entry.directory == normalizedDirectory,
      );
    });
  }

  Future<void> removeServer(String serverId) async {
    final normalizedServerId = serverId.trim();
    if (normalizedServerId.isEmpty) return;
    _removedServerIds.add(normalizedServerId);
    try {
      await _serialize<void>(
        normalizedServerId,
        () => _localDataSource.deleteSessionTabIconOverrides(
          serverId: normalizedServerId,
        ),
      );
    } catch (_) {
      _removedServerIds.remove(normalizedServerId);
      rethrow;
    }
  }

  Future<void> drain() async {
    await Future.wait(_queueByServer.values);
  }

  Future<SessionTabIconOverridesState> _mutate(
    String serverId,
    void Function(List<SessionTabIconOverride> entries) mutation,
  ) {
    if (serverId.isEmpty || _removedServerIds.contains(serverId)) {
      return Future.error(StateError('Session tab icon store is unavailable'));
    }
    return _serialize(serverId, () async {
      if (_removedServerIds.contains(serverId)) {
        throw StateError('Session tab icon store is unavailable');
      }
      final current = SessionTabIconOverridesState.decode(
        await _localDataSource.getSessionTabIconOverridesJson(
          serverId: serverId,
        ),
      );
      final entries = current.entries.toList(growable: true);
      mutation(entries);
      final next = SessionTabIconOverridesState(entries: entries).compacted();
      if (next.encode() != current.encode()) {
        await _localDataSource.saveSessionTabIconOverridesJson(
          next.encode(),
          serverId: serverId,
        );
      }
      return next;
    });
  }

  Future<T> _serialize<T>(String serverId, Future<T> Function() operation) {
    final previous = _queueByServer[serverId] ?? Future<void>.value();
    final result = Completer<T>();
    final next = previous.then((_) async {
      try {
        result.complete(await operation());
      } catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      }
    });
    _queueByServer[serverId] = next;
    unawaited(
      next.whenComplete(() {
        if (identical(_queueByServer[serverId], next)) {
          _queueByServer.remove(serverId);
        }
      }),
    );
    return result.future;
  }
}
