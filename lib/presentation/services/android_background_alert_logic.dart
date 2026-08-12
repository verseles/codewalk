import 'dart:ui' as ui;

import '../../core/config/feature_flags.dart';
import '../../core/i18n/app_locales.dart';
import '../../core/i18n/l10n_bridge.dart';
import '../../domain/entities/experience_settings.dart';
import '../../l10n/generated/app_localizations.dart';

const Duration kBackgroundFastProbeInterval = Duration(minutes: 3);
const Duration kBackgroundTailProbeInterval = Duration(minutes: 5);

/// Resolves [AppLocalizations] for a persisted locale code using the same
/// [AppLocales] conventions as the foreground app. When the app follows the
/// system locale, resolves the platform locale with the same callback.
AppLocalizations resolveBackgroundAlertLocalizations(
  String? localeCode, {
  ui.Locale? systemLocale,
}) {
  return lookupAppLocalizations(
    resolveBackgroundAlertLocale(localeCode, systemLocale: systemLocale),
  );
}

ui.Locale resolveBackgroundAlertLocale(
  String? localeCode, {
  ui.Locale? systemLocale,
}) {
  return AppLocales.localeForCode(localeCode) ??
      AppLocales.resolutionCallback(
        systemLocale ?? ui.PlatformDispatcher.instance.locale,
        AppLocales.supported,
      );
}

bool shouldRunAndroidBackgroundAlerts(ExperienceSettings settings) {
  if (!settings.androidBackgroundAlertsEnabled) {
    return false;
  }
  return settings.notifications.values.any((enabled) => enabled);
}

bool shouldDisableBackgroundNetworkForDataSaver({
  required ExperienceSettings settings,
  required bool isCellularTransport,
}) {
  if (!FeatureFlags.cellularDataSaver) {
    return false;
  }
  return settings.dataSaverEnabled && isCellularTransport;
}

bool shouldResolveFallbackCompletion({
  required String? previousStatus,
  required int sessionUpdatedAtEpochMs,
  required int? lastMainHeartbeatEpochMs,
  required int nowEpochMs,
  required int durableCompletedAtEpochMs,
}) {
  if (previousStatus == 'busy' || previousStatus == 'retry') return true;
  final ageMs = nowEpochMs - sessionUpdatedAtEpochMs;
  return previousStatus == null &&
      lastMainHeartbeatEpochMs != null &&
      lastMainHeartbeatEpochMs > 0 &&
      sessionUpdatedAtEpochMs > lastMainHeartbeatEpochMs &&
      ageMs >= 0 &&
      ageMs <= const Duration(minutes: 10).inMilliseconds &&
      durableCompletedAtEpochMs < sessionUpdatedAtEpochMs;
}

bool hasActiveBackgroundSessions(Map<String, String> sessionStatusById) {
  for (final rawStatus in sessionStatusById.values) {
    final normalized = rawStatus.trim().toLowerCase();
    if (normalized == 'busy' || normalized == 'retry') {
      return true;
    }
  }
  return false;
}

int countActiveBackgroundSessions(Map<String, String> sessionStatusById) {
  var count = 0;
  for (final rawStatus in sessionStatusById.values) {
    final normalized = rawStatus.trim().toLowerCase();
    if (normalized == 'busy' || normalized == 'retry') {
      count += 1;
    }
  }
  return count;
}

bool shouldScheduleBackgroundTailProbe({
  required Map<String, String> previousSessionStatusById,
  required Map<String, String> currentSessionStatusById,
}) {
  final hadActiveSessions = hasActiveBackgroundSessions(
    previousSessionStatusById,
  );
  if (!hadActiveSessions) {
    return false;
  }
  return !hasActiveBackgroundSessions(currentSessionStatusById);
}

class BackgroundInteractionRequest {
  const BackgroundInteractionRequest({
    required this.id,
    required this.sessionId,
    this.always = const <String>[],
  });

  final String id;
  final String sessionId;
  final List<String> always;
}

class BackgroundPollingState {
  const BackgroundPollingState({
    required this.sessionStatusById,
    required this.sessionUpdatedAtById,
    required this.sessionTitleById,
    this.parentSessionIdByChild = const <String, String>{},
    required this.permissionRequests,
    required this.questionRequests,
  });

  final Map<String, String> sessionStatusById;
  final Map<String, int> sessionUpdatedAtById;
  final Map<String, String> sessionTitleById;
  final Map<String, String> parentSessionIdByChild;
  final List<BackgroundInteractionRequest> permissionRequests;
  final List<BackgroundInteractionRequest> questionRequests;
}

class BackgroundAlertSnapshot {
  const BackgroundAlertSnapshot({
    required this.sessionStatusById,
    required this.sessionUpdatedAtById,
    required this.sessionTitleById,
    required this.notifiedPermissionRequestIds,
    required this.notifiedQuestionRequestIds,
    required this.lastPolledAtEpochMs,
  });

  factory BackgroundAlertSnapshot.empty() {
    return const BackgroundAlertSnapshot(
      sessionStatusById: <String, String>{},
      sessionUpdatedAtById: <String, int>{},
      sessionTitleById: <String, String>{},
      notifiedPermissionRequestIds: <String>[],
      notifiedQuestionRequestIds: <String>[],
      lastPolledAtEpochMs: 0,
    );
  }

  factory BackgroundAlertSnapshot.fromJson(Map<String, dynamic> json) {
    final statusRaw = json['sessionStatusById'];
    final updatedRaw = json['sessionUpdatedAtById'];
    final titleRaw = json['sessionTitleById'];
    final permissionRaw = json['notifiedPermissionRequestIds'];
    final questionRaw = json['notifiedQuestionRequestIds'];
    final polledRaw = json['lastPolledAtEpochMs'];

    final statusMap = <String, String>{};
    if (statusRaw is Map) {
      statusRaw.forEach((key, value) {
        final sessionId = key.toString().trim();
        final status = value.toString().trim().toLowerCase();
        if (sessionId.isNotEmpty && status.isNotEmpty) {
          statusMap[sessionId] = status;
        }
      });
    }

    final updatedMap = <String, int>{};
    if (updatedRaw is Map) {
      updatedRaw.forEach((key, value) {
        final sessionId = key.toString().trim();
        final epoch = value is num ? value.toInt() : null;
        if (sessionId.isNotEmpty && epoch != null && epoch > 0) {
          updatedMap[sessionId] = epoch;
        }
      });
    }

    final titleMap = <String, String>{};
    if (titleRaw is Map) {
      titleRaw.forEach((key, value) {
        final sessionId = key.toString().trim();
        final title = value.toString().trim();
        if (sessionId.isNotEmpty && title.isNotEmpty) {
          titleMap[sessionId] = title;
        }
      });
    }

    List<String> parseIds(dynamic raw) {
      if (raw is! List) {
        return const <String>[];
      }
      return raw
          .map((item) => item.toString().trim())
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList(growable: false);
    }

    return BackgroundAlertSnapshot(
      sessionStatusById: statusMap,
      sessionUpdatedAtById: updatedMap,
      sessionTitleById: titleMap,
      notifiedPermissionRequestIds: parseIds(permissionRaw),
      notifiedQuestionRequestIds: parseIds(questionRaw),
      lastPolledAtEpochMs: polledRaw is num ? polledRaw.toInt() : 0,
    );
  }

  final Map<String, String> sessionStatusById;
  final Map<String, int> sessionUpdatedAtById;
  final Map<String, String> sessionTitleById;
  final List<String> notifiedPermissionRequestIds;
  final List<String> notifiedQuestionRequestIds;
  final int lastPolledAtEpochMs;

  bool get hasHistory {
    return sessionStatusById.isNotEmpty ||
        sessionTitleById.isNotEmpty ||
        notifiedPermissionRequestIds.isNotEmpty ||
        notifiedQuestionRequestIds.isNotEmpty ||
        lastPolledAtEpochMs > 0;
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'sessionStatusById': sessionStatusById,
      'sessionUpdatedAtById': sessionUpdatedAtById,
      'sessionTitleById': sessionTitleById,
      'notifiedPermissionRequestIds': notifiedPermissionRequestIds,
      'notifiedQuestionRequestIds': notifiedQuestionRequestIds,
      'lastPolledAtEpochMs': lastPolledAtEpochMs,
    };
  }
}

enum BackgroundAlertKind { completion, error, permission, question }

class BackgroundAlertSignal {
  const BackgroundAlertSignal({
    required this.kind,
    required this.categoryKey,
    required this.title,
    required this.body,
    required this.sessionId,
  });

  final BackgroundAlertKind kind;
  final String categoryKey;
  final String title;
  final String body;
  final String sessionId;
}

class BackgroundAlertPlan {
  const BackgroundAlertPlan({
    required this.signals,
    required this.nextSnapshot,
    required this.baselineOnly,
  });

  final List<BackgroundAlertSignal> signals;
  final BackgroundAlertSnapshot nextSnapshot;
  final bool baselineOnly;
}

class BackgroundAlertPlanner {
  const BackgroundAlertPlanner();

  static const int _maxSeenRequestIds = 300;

  BackgroundAlertPlan plan({
    required BackgroundAlertSnapshot previous,
    required BackgroundPollingState current,
    required ExperienceSettings settings,
    required int nowEpochMs,
  }) {
    final normalizedStatuses = <String, String>{
      for (final entry in current.sessionStatusById.entries)
        if (entry.key.trim().isNotEmpty)
          entry.key.trim(): _normalizeStatus(entry.value),
    };

    final permissionIds = current.permissionRequests
        .map((item) => item.id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    final questionIds = current.questionRequests
        .map((item) => item.id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();

    final nextSnapshot = BackgroundAlertSnapshot(
      sessionStatusById: normalizedStatuses,
      sessionUpdatedAtById: Map<String, int>.from(current.sessionUpdatedAtById),
      sessionTitleById: Map<String, String>.from(current.sessionTitleById),
      notifiedPermissionRequestIds: _mergeSeenIds(
        previous.notifiedPermissionRequestIds,
        permissionIds,
      ),
      notifiedQuestionRequestIds: _mergeSeenIds(
        previous.notifiedQuestionRequestIds,
        questionIds,
      ),
      lastPolledAtEpochMs: nowEpochMs,
    );

    final l10n = L10nBridge.current;
    final agentEnabled =
        settings.notifications[NotificationCategory.agent] ?? true;
    final permissionEnabled =
        settings.notifications[NotificationCategory.permissions] ?? true;
    final errorEnabled =
        settings.notifications[NotificationCategory.errors] ?? true;

    if (!previous.hasHistory) {
      final initialSignals = <BackgroundAlertSignal>[];

      if (errorEnabled) {
        for (final entry in normalizedStatuses.entries) {
          if (entry.value != 'retry') {
            continue;
          }
          initialSignals.add(
            BackgroundAlertSignal(
              kind: BackgroundAlertKind.error,
              categoryKey: 'errors',
              title: _sessionTitleFor(current.sessionTitleById[entry.key]),
              body:
                  l10n?.notificationSessionError ??
                  'A session reported an error.',
              sessionId: entry.key,
            ),
          );
        }
      }

      if (permissionEnabled) {
        for (final request in current.permissionRequests) {
          final requestId = request.id.trim();
          if (requestId.isEmpty) {
            continue;
          }
          initialSignals.add(
            BackgroundAlertSignal(
              kind: BackgroundAlertKind.permission,
              categoryKey: 'permissions',
              title: _sessionTitleFor(
                current.sessionTitleById[request.sessionId],
              ),
              body:
                  l10n?.notificationPermissionNeedsInput ??
                  'A tool permission needs your input.',
              sessionId: request.sessionId,
            ),
          );
        }

        for (final request in current.questionRequests) {
          final requestId = request.id.trim();
          if (requestId.isEmpty) {
            continue;
          }
          initialSignals.add(
            BackgroundAlertSignal(
              kind: BackgroundAlertKind.question,
              categoryKey: 'permissions',
              title: _sessionTitleFor(
                current.sessionTitleById[request.sessionId],
              ),
              body:
                  l10n?.notificationQuestionNeedsInput ??
                  'A tool question needs your input.',
              sessionId: request.sessionId,
            ),
          );
        }
      }

      return BackgroundAlertPlan(
        signals: initialSignals,
        nextSnapshot: nextSnapshot,
        baselineOnly: initialSignals.isEmpty,
      );
    }

    final signals = <BackgroundAlertSignal>[];

    if (agentEnabled || errorEnabled) {
      for (final entry in normalizedStatuses.entries) {
        final sessionId = entry.key;
        final currentStatus = entry.value;
        final previousStatus = previous.sessionStatusById[sessionId];
        if (previousStatus == null || previousStatus.isEmpty) {
          continue;
        }

        final title = _sessionTitleFor(current.sessionTitleById[sessionId]);
        if (agentEnabled &&
            previousStatus == 'busy' &&
            currentStatus == 'idle' &&
            !_isChildSession(
              sessionId,
              parentSessionIdByChild: current.parentSessionIdByChild,
            )) {
          signals.add(
            BackgroundAlertSignal(
              kind: BackgroundAlertKind.completion,
              categoryKey: 'agent',
              title: title,
              body:
                  l10n?.notificationAgentFinished ??
                  'Agent finished the current response.',
              sessionId: sessionId,
            ),
          );
        }

        if (errorEnabled &&
            previousStatus != 'retry' &&
            currentStatus == 'retry') {
          signals.add(
            BackgroundAlertSignal(
              kind: BackgroundAlertKind.error,
              categoryKey: 'errors',
              title: title,
              body:
                  l10n?.notificationSessionError ??
                  'A session reported an error.',
              sessionId: sessionId,
            ),
          );
        }
      }
    }

    if (permissionEnabled) {
      final seenPermission = previous.notifiedPermissionRequestIds.toSet();
      final seenQuestion = previous.notifiedQuestionRequestIds.toSet();

      for (final request in current.permissionRequests) {
        final requestId = request.id.trim();
        if (requestId.isEmpty || seenPermission.contains(requestId)) {
          continue;
        }
        signals.add(
          BackgroundAlertSignal(
            kind: BackgroundAlertKind.permission,
            categoryKey: 'permissions',
            title: _sessionTitleFor(
              current.sessionTitleById[request.sessionId],
            ),
            body:
                l10n?.notificationPermissionNeedsInput ??
                'A tool permission needs your input.',
            sessionId: request.sessionId,
          ),
        );
      }

      for (final request in current.questionRequests) {
        final requestId = request.id.trim();
        if (requestId.isEmpty || seenQuestion.contains(requestId)) {
          continue;
        }
        signals.add(
          BackgroundAlertSignal(
            kind: BackgroundAlertKind.question,
            categoryKey: 'permissions',
            title: _sessionTitleFor(
              current.sessionTitleById[request.sessionId],
            ),
            body:
                l10n?.notificationQuestionNeedsInput ??
                'A tool question needs your input.',
            sessionId: request.sessionId,
          ),
        );
      }
    }

    return BackgroundAlertPlan(
      signals: signals,
      nextSnapshot: nextSnapshot,
      baselineOnly: false,
    );
  }

  List<String> _mergeSeenIds(List<String> previous, Set<String> currentIds) {
    final queue = List<String>.from(previous);
    final seen = queue.toSet();
    for (final id in currentIds) {
      if (seen.add(id)) {
        queue.add(id);
      }
    }
    if (queue.length <= _maxSeenRequestIds) {
      return queue;
    }
    return queue.sublist(queue.length - _maxSeenRequestIds);
  }

  String _normalizeStatus(String raw) {
    final normalized = raw.trim().toLowerCase();
    if (normalized == 'busy' || normalized == 'retry' || normalized == 'idle') {
      return normalized;
    }
    return 'idle';
  }

  String _sessionTitleFor(String? raw) {
    final title = raw?.trim();
    if (title == null || title.isEmpty) {
      return L10nBridge.current?.notificationSession ?? 'Session';
    }
    return title;
  }

  bool _isChildSession(
    String sessionId, {
    required Map<String, String> parentSessionIdByChild,
  }) {
    final parentId = parentSessionIdByChild[sessionId]?.trim();
    return parentId != null && parentId.isNotEmpty;
  }
}
