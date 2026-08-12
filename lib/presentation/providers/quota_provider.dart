import 'package:flutter/foundation.dart';

import '../../core/logging/app_logger.dart';
import '../../data/datasources/app_local_datasource.dart';
import '../../data/datasources/quota_remote_datasource.dart';
import '../../domain/entities/quota.dart';
import '../utils/quota_pace_utils.dart';

class QuotaProvider extends ChangeNotifier {
  QuotaProvider({
    required QuotaRemoteDataSource remoteDataSource,
    AppLocalDataSource? localDataSource,
  }) : _remoteDataSource = remoteDataSource,
       _localDataSource = localDataSource;

  final QuotaRemoteDataSource _remoteDataSource;
  final AppLocalDataSource? _localDataSource;

  static const Duration _cacheTtl = Duration(seconds: 60);

  String? _serverId;
  bool _isLoading = false;
  DateTime? _lastFetchedAt;
  List<QuotaProviderResult> _results = const <QuotaProviderResult>[];

  bool get isLoading => _isLoading;
  DateTime? get lastFetchedAt => _lastFetchedAt;
  List<QuotaProviderResult> get results =>
      List<QuotaProviderResult>.unmodifiable(_results);

  bool get hasOpenCodeGoFailure {
    final result = _openCodeGoResult;
    return result != null && result.configured && !result.hasVisibleData;
  }

  String? get openCodeGoError => _openCodeGoResult?.error;
  String? get openCodeGoErrorCode => _openCodeGoResult?.errorCode;

  QuotaProviderResult? get _openCodeGoResult {
    for (final result in _results) {
      if (result.providerId == 'opencode-go') {
        return result;
      }
    }
    return null;
  }

  bool _legacyCredentialsCleared = false;

  bool get hasAnyQuotaData => groups.isNotEmpty;

  List<QuotaProviderGroup> get groups {
    final built = _results
        .where((result) => result.hasVisibleData)
        .map(_buildGroup)
        .where((group) => group.entries.isNotEmpty)
        .toList(growable: false);
    built.sort(
      (left, right) => right.criticalEntry.severityScore.compareTo(
        left.criticalEntry.severityScore,
      ),
    );
    return built;
  }

  Future<void> ensureLoaded({
    required String? serverId,
    bool force = false,
  }) async {
    final normalizedServerId = serverId?.trim();
    AppLogger.info(
      '[Quota] ensureLoaded called — serverId=$normalizedServerId '
      'force=$force isLoading=$_isLoading',
    );
    if (normalizedServerId == null || normalizedServerId.isEmpty) {
      AppLogger.info('[Quota] ensureLoaded abort: serverId is null/empty');
      if (_serverId != null || _results.isNotEmpty || _lastFetchedAt != null) {
        _serverId = null;
        _results = const <QuotaProviderResult>[];
        _lastFetchedAt = null;
        _isLoading = false;
        notifyListeners();
      }
      return;
    }

    final serverChanged = _serverId != normalizedServerId;
    if (serverChanged) {
      _serverId = normalizedServerId;
      _results = const <QuotaProviderResult>[];
      _lastFetchedAt = null;
    }

    if (_isLoading) {
      AppLogger.info('[Quota] ensureLoaded abort: already loading');
      return;
    }

    final now = DateTime.now();
    final isFresh =
        !force &&
        !serverChanged &&
        _lastFetchedAt != null &&
        now.difference(_lastFetchedAt!) < _cacheTtl;
    if (isFresh) {
      AppLogger.info('[Quota] ensureLoaded abort: cache still fresh');
      return;
    }

    _isLoading = true;
    notifyListeners();
    try {
      AppLogger.info('[Quota] ensureLoaded: starting fetch...');
      await _clearLegacyOpenCodeGoCredentials();
      _results = await _remoteDataSource.fetchQuotaResults();
      _lastFetchedAt = DateTime.now();
      final groupSummaries = groups
          .map(
            (group) =>
                '${group.providerId}['
                '${group.entries.map((entry) => '${entry.label}:used=${entry.usedPercent?.round() ?? '-'} value=${entry.valueLabel ?? '-'} pace=${entry.paceInfo?.predictedFinalPercent.round() ?? '-'}').join(', ')}]',
          )
          .toList(growable: false);
      AppLogger.info(
        '[Quota] ensureLoaded: fetch complete — '
        '${_results.length} results, ${groups.length} visible groups',
      );
      AppLogger.info('[Quota] ensureLoaded groups: $groupSummaries');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _clearLegacyOpenCodeGoCredentials() async {
    final localDataSource = _localDataSource;
    if (localDataSource == null || _legacyCredentialsCleared) {
      return;
    }
    await localDataSource.clearOpenCodeGoDashboardCredentials();
    _legacyCredentialsCleared = true;
  }

  QuotaProviderGroup _buildGroup(QuotaProviderResult result) {
    final entries = <QuotaEntry>[];
    final usage = result.usage;
    if (usage == null) {
      return QuotaProviderGroup(
        providerId: result.providerId,
        providerName: result.providerName,
        entries: const <QuotaEntry>[],
      );
    }

    usage.windows.forEach((windowLabel, window) {
      final label =
          usage.windows.length == 1 &&
              usage.models.isEmpty &&
              result.providerId != 'codex'
          ? result.providerName
          : formatWindowLabel(windowLabel);
      final entry = _buildEntry(
        result: result,
        label: label,
        window: window,
        windowLabel: windowLabel,
      );
      final visibleEntry = _filterEntryForDisplay(entry);
      if (visibleEntry != null) {
        entries.add(visibleEntry);
      }
    });

    usage.models.forEach((modelName, modelUsage) {
      modelUsage.windows.forEach((windowLabel, window) {
        final prettyWindow = formatWindowLabel(windowLabel);
        final label = modelUsage.windows.length > 1
            ? '$modelName · $prettyWindow'
            : modelName;
        final entry = _buildEntry(
          result: result,
          label: label,
          window: window,
          windowLabel: windowLabel,
        );
        final visibleEntry = _filterEntryForDisplay(entry);
        if (visibleEntry != null) {
          entries.add(visibleEntry);
        }
      });
    });

    entries.sort(_compareEntriesForDisplay);

    return QuotaProviderGroup(
      providerId: result.providerId,
      providerName: result.providerName,
      entries: entries,
    );
  }

  QuotaEntry? _buildEntry({
    required QuotaProviderResult result,
    required String label,
    required UsageWindow window,
    required String windowLabel,
  }) {
    if (!window.hasVisibleData) {
      return null;
    }
    final paceInfo = calculatePace(
      usedPercent: window.usedPercent,
      resetAt: window.resetAt,
      windowSeconds: window.windowSeconds,
      windowLabel: windowLabel,
    );
    return QuotaEntry(
      providerId: result.providerId,
      providerName: result.providerName,
      label: label,
      usedPercent: window.usedPercent,
      remainingPercent: window.remainingPercent,
      windowSeconds: window.windowSeconds,
      resetAfterSeconds: window.resetAfterSeconds,
      resetAt: window.resetAt,
      valueLabel: window.valueLabel,
      paceInfo: paceInfo,
    );
  }

  QuotaEntry? _filterEntryForDisplay(QuotaEntry? entry) {
    if (entry == null || entry.hasZeroRemainingValueLabel) {
      return null;
    }
    return entry;
  }

  int _compareEntriesForDisplay(QuotaEntry left, QuotaEntry right) {
    final usageComparison = (right.effectiveUsedPercent ?? -1).compareTo(
      left.effectiveUsedPercent ?? -1,
    );
    if (usageComparison != 0) {
      return usageComparison;
    }

    final severityComparison = right.severityScore.compareTo(
      left.severityScore,
    );
    if (severityComparison != 0) {
      return severityComparison;
    }

    final windowComparison = (left.windowSeconds ?? 1 << 30).compareTo(
      right.windowSeconds ?? 1 << 30,
    );
    if (windowComparison != 0) {
      return windowComparison;
    }

    return left.label.compareTo(right.label);
  }
}
