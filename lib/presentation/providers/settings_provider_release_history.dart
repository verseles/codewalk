part of 'settings_provider.dart';

class ReleaseAnnouncementBatch {
  const ReleaseAnnouncementBatch({required this.key, required this.entries});

  final String key;
  final List<ReleaseHistoryEntry> entries;
}

class _InstalledReleaseState {
  const _InstalledReleaseState({
    required this.highest,
    this.from,
    this.to,
    this.includeFrom = false,
  });

  final Semver highest;
  final Semver? from;
  final Semver? to;
  final bool includeFrom;
  String get key => '$from:$to:$includeFrom';

  Map<String, dynamic> toJson() => {
    'schema': 1,
    'highest': highest.toString(),
    if (from != null) 'from': from.toString(),
    if (to != null) 'to': to.toString(),
    'includeFrom': includeFrom,
  };

  static _InstalledReleaseState decode(String raw) {
    final map = jsonDecode(raw) as Map<String, dynamic>;
    if (map['schema'] != 1) {
      throw const FormatException('Unknown history state');
    }
    final highest = Semver.tryParse(map['highest'] as String);
    final from = map['from'] == null
        ? null
        : Semver.tryParse(map['from'] as String);
    final to = map['to'] == null ? null : Semver.tryParse(map['to'] as String);
    if (highest == null ||
        (from == null) != (to == null) ||
        (map['from'] != null && from == null) ||
        (to != null &&
            (from!.compareTo(to) > 0 || to.compareTo(highest) > 0))) {
      throw const FormatException('Invalid history state');
    }
    return _InstalledReleaseState(
      highest: highest,
      from: from,
      to: to,
      includeFrom: map['includeFrom'] == true,
    );
  }
}

extension SettingsProviderReleaseHistory on SettingsProvider {
  ReleaseHistorySnapshot get releaseHistory => _releaseHistory;
  bool get releaseHistoryLoading => _releaseHistoryLoading;
  bool get releaseHistoryCoverageMissing => _releaseHistoryCoverageMissing;
  String? get installedReleaseVersion => _installedVersion?.toString();

  ReleaseAnnouncementBatch? get pendingReleaseAnnouncements {
    final state = _installedReleaseState;
    if (state == null ||
        state.to == null ||
        state.to != _installedVersion ||
        _releaseHistoryCoverageMissing ||
        _presentedAnnouncementKey == state.key ||
        !_coversPendingHistory()) {
      return null;
    }
    final entries = _releaseHistory.entries
        .where((entry) {
          final lower = entry.version.compareTo(state.from!);
          return (lower > 0 || (state.includeFrom && lower == 0)) &&
              entry.version.compareTo(state.to!) <= 0 &&
              (entry.announcement?.isNotEmpty ?? false);
        })
        .toList(growable: false);
    return entries.isEmpty
        ? null
        : ReleaseAnnouncementBatch(
            key: state.key,
            entries: List.unmodifiable(entries),
          );
  }

  bool _coversPendingHistory() {
    final state = _installedReleaseState;
    return state?.to != null &&
        _releaseHistory.contains(state!.to!) &&
        _releaseHistory.contains(state.from!);
  }

  Future<bool> _hasReleaseHistoryInstallEvidence() async {
    if (await _localDataSource.getServerProfilesJson() != null) return true;
    // AppProvider migrates these keys independently during startup. Check the
    // same evidence before that migration has necessarily saved a profile.
    return (await _localDataSource.getServerHost())?.trim().isNotEmpty ==
            true ||
        await _localDataSource.getServerPort() != null ||
        await _localDataSource.getBasicAuthEnabled() == true ||
        (await _localDataSource.getBasicAuthUsername())?.trim().isNotEmpty ==
            true ||
        (await _localDataSource.getBasicAuthPassword())?.trim().isNotEmpty ==
            true;
  }

  Future<void> _initializeReleaseHistory({
    required bool existingInstall,
  }) async {
    if (_releaseHistoryService == null) return;
    final generation = _releaseHistoryGeneration;
    try {
      final info = await PackageInfo.fromPlatform();
      // Build metadata is irrelevant; pre-release builds do not establish a
      // stable installed-version boundary.
      if (info.version.contains('-')) return;
      final current = Semver.tryParse(info.version);
      if (current == null) return;
      final raw = await _localDataSource.getReleaseHistoryState();
      if (generation != _releaseHistoryGeneration) return;
      _installedVersion = current;
      final old = raw == null ? null : _InstalledReleaseState.decode(raw);
      var next = old;
      if (old == null) {
        next = _InstalledReleaseState(
          highest: current,
          from: existingInstall ? current : null,
          to: existingInstall ? current : null,
          includeFrom: existingInstall,
        );
      } else if (current.isNewerThan(old.highest)) {
        next = _InstalledReleaseState(
          highest: current,
          from: old.from ?? old.highest,
          to: current,
          includeFrom: old.from != null && old.includeFrom,
        );
      }
      if (identical(next, old)) {
        _installedReleaseState = old;
      } else {
        await _saveInstalledReleaseState(next!, generation);
      }
    } catch (error, stack) {
      AppLogger.warn(
        'Unable to restore release history state',
        error: error,
        stackTrace: stack,
      );
    }
  }

  Future<void> _saveInstalledReleaseState(
    _InstalledReleaseState state,
    int generation,
  ) {
    final operation = _releaseHistoryWriteQueue.then((_) async {
      if (generation != _releaseHistoryGeneration) return;
      await _localDataSource.saveReleaseHistoryState(
        jsonEncode(state.toJson()),
      );
      if (generation == _releaseHistoryGeneration) {
        _installedReleaseState = state;
      }
    });
    _releaseHistoryWriteQueue = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> loadReleaseHistory({bool forceRefresh = false}) {
    return _releaseHistoryLoad ??= _loadReleaseHistory(
      forceRefresh,
    ).whenComplete(() => _releaseHistoryLoad = null);
  }

  Future<void> _loadReleaseHistory(bool forceRefresh) async {
    final service = _releaseHistoryService;
    if (service == null) {
      _releaseHistory = const ReleaseHistorySnapshot(failed: true);
      _notifyReleaseHistoryChanged();
      return;
    }
    final generation = _releaseHistoryGeneration;
    _releaseHistoryLoading = true;
    _notifyReleaseHistoryChanged();
    try {
      var result = await service.load(forceRefresh: forceRefresh);
      if (generation != _releaseHistoryGeneration) return;
      // A fresh install can outpace the cached main-branch archive.
      final target = _installedReleaseState?.to;
      if (!forceRefresh &&
          !result.failed &&
          target != null &&
          !result.contains(target)) {
        result = await service.load(forceRefresh: true);
      }
      if (generation != _releaseHistoryGeneration) return;
      _releaseHistory = result;
      _releaseHistoryCoverageMissing =
          target != null && !_coversPendingHistory();
      if (!result.failed &&
          target == _installedVersion &&
          _coversPendingHistory() &&
          pendingReleaseAnnouncements == null &&
          _presentedAnnouncementKey != _installedReleaseState!.key) {
        // A valid, fully covered interval can contain only maintenance releases.
        await _saveInstalledReleaseState(
          _InstalledReleaseState(highest: _installedReleaseState!.highest),
          generation,
        );
      }
    } catch (error, stack) {
      if (generation != _releaseHistoryGeneration) return;
      _releaseHistory = ReleaseHistorySnapshot(
        entries: _releaseHistory.entries,
        fetchedAt: _releaseHistory.fetchedAt,
        failed: true,
      );
      AppLogger.warn(
        'Unable to load release history',
        error: error,
        stackTrace: stack,
      );
    } finally {
      if (generation == _releaseHistoryGeneration) {
        _releaseHistoryLoading = false;
        _notifyReleaseHistoryChanged();
      }
    }
  }

  void markReleaseAnnouncementsPresented(String key) {
    if (_installedReleaseState?.key == key) _presentedAnnouncementKey = key;
  }

  Future<bool> acknowledgeReleaseAnnouncements(String key) async {
    final state = _installedReleaseState;
    if (state == null || state.key != key || !_coversPendingHistory()) {
      return false;
    }
    final generation = _releaseHistoryGeneration;
    try {
      await _saveInstalledReleaseState(
        _InstalledReleaseState(highest: state.highest),
        generation,
      );
      if (generation != _releaseHistoryGeneration) return false;
      _notifyReleaseHistoryChanged();
      return true;
    } catch (error, stack) {
      AppLogger.warn(
        'Unable to acknowledge release announcements',
        error: error,
        stackTrace: stack,
      );
      return false;
    }
  }

  Future<void> resetReleaseHistory() async {
    _releaseHistoryGeneration++;
    await _releaseHistoryService?.reset();
    await _releaseHistoryWriteQueue;
    _installedReleaseState = null;
    _installedVersion = null;
    _releaseHistory = const ReleaseHistorySnapshot();
    _releaseHistoryLoading = false;
    _releaseHistoryCoverageMissing = false;
    _presentedAnnouncementKey = null;
    _releaseHistoryLoad = null;
  }
}
