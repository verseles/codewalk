import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../../core/config/feature_flags.dart';
import '../../core/constants/app_constants.dart';
import '../../core/i18n/l10n_bridge.dart';
import '../../core/logging/app_logger.dart';
import '../../data/models/chat_realtime_model.dart';
import '../../data/models/chat_session_model.dart';
import '../../domain/entities/experience_settings.dart';
import 'android_background_alert_logic.dart';
import 'car_messaging/car_messaging_action_handler.dart';
import 'car_messaging/car_messaging_dispatch_worker.dart';
import 'car_messaging/car_messaging_gate.dart';
import 'car_messaging/car_messaging_runtime.dart';
import 'cellular_data_saver_service.dart';
import 'notification_service.dart';
import 'permission_auto_approve_runtime.dart';

const String _backgroundAlertWorkUniqueName =
    'codewalk.android.background.alerts';
const String _backgroundAlertOneOffUniqueName =
    'codewalk.android.background.alerts.once';
const String _backgroundAlertTaskName = 'codewalk.background.alerts.poll';
const String _backgroundAlertSnapshotKeyPrefix =
    'codewalk.android.background.alert.snapshot.v1';
const String _backgroundPermissionAutoApproveContextKeyPrefix =
    'codewalk.android.background.permission_auto_approve.v1';
const Duration _backgroundAlertFailureRetryInterval = Duration(minutes: 5);

@pragma('vm:entry-point')
void codewalkBackgroundAlertDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    return AndroidBackgroundAlertWorker.executeTask(
      taskName: task,
      inputData: inputData,
    );
  });
}

class AndroidBackgroundAlertWorker {
  static bool _initialized = false;
  static const Duration activeSessionProbeInterval =
      kBackgroundFastProbeInterval;
  static const Duration tailProbeInterval = kBackgroundTailProbeInterval;

  static Future<void> ensureRegistered() async {
    await syncRegistrationFromPersistedSettings();
  }

  /// Remove replied request IDs from the persisted background alert snapshot
  /// so the background worker does not re-notify about already-handled items.
  ///
  /// This is called from the foreground event reducer when a permission or
  /// question is replied. [serverId] identifies the server profile whose
  /// snapshot should be updated. [permissionRequestIds] and
  /// [questionRequestIds] are the IDs to remove; either may be empty.
  static Future<void> removeNotifiedRequestIds({
    required String serverId,
    List<String> permissionRequestIds = const [],
    List<String> questionRequestIds = const [],
  }) async {
    if (!_isAndroidRuntime()) {
      return;
    }
    if (permissionRequestIds.isEmpty && questionRequestIds.isEmpty) {
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final snapshotKey = _backgroundAlertSnapshotStorageKey(serverId);
      final existing = prefs.getString(snapshotKey);
      if (existing == null || existing.trim().isEmpty) {
        return;
      }
      final decoded = jsonDecode(existing);
      if (decoded is! Map<String, dynamic>) {
        return;
      }
      final snapshot = BackgroundAlertSnapshot.fromJson(decoded);
      final removePerm = permissionRequestIds.toSet();
      final removeQues = questionRequestIds.toSet();
      final updatedPerm = snapshot.notifiedPermissionRequestIds
          .where((id) => !removePerm.contains(id))
          .toList(growable: false);
      final updatedQues = snapshot.notifiedQuestionRequestIds
          .where((id) => !removeQues.contains(id))
          .toList(growable: false);
      final updated = BackgroundAlertSnapshot(
        sessionStatusById: snapshot.sessionStatusById,
        sessionUpdatedAtById: snapshot.sessionUpdatedAtById,
        sessionTitleById: snapshot.sessionTitleById,
        notifiedPermissionRequestIds: updatedPerm,
        notifiedQuestionRequestIds: updatedQues,
        lastPolledAtEpochMs: snapshot.lastPolledAtEpochMs,
      );
      await prefs.setString(snapshotKey, jsonEncode(updated.toJson()));
    } catch (error, stackTrace) {
      AppLogger.warn(
        'removeNotifiedRequestIds failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  static Future<void> syncRegistrationFromPersistedSettings() async {
    if (!_isAndroidRuntime()) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final settings = _readExperienceSettingsFromPrefs(prefs);
    await syncRegistration(
      enabled:
          shouldRunAndroidBackgroundAlerts(settings) &&
          !_shouldDisableBackgroundDataSaver(settings, prefs),
    );
  }

  static Future<void> syncRegistration({required bool enabled}) async {
    if (!_isAndroidRuntime()) {
      return;
    }

    await _ensureInitialized();
    if (!_initialized) {
      return;
    }

    if (!enabled) {
      await _cancelScheduledTasks();
      return;
    }

    try {
      await Workmanager().registerPeriodicTask(
        _backgroundAlertWorkUniqueName,
        _backgroundAlertTaskName,
        frequency: const Duration(minutes: 15),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
        constraints: Constraints(networkType: NetworkType.connected),
        backoffPolicy: BackoffPolicy.linear,
        backoffPolicyDelay: const Duration(minutes: 15),
      );
    } catch (error, stackTrace) {
      AppLogger.warn(
        'Failed to register Android background alert periodic task',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  static Future<void> scheduleProbe({
    Duration initialDelay = activeSessionProbeInterval,
    bool ensureInitialized = true,
  }) async {
    if (!_isAndroidRuntime()) {
      return;
    }

    if (ensureInitialized && !_initialized) {
      await _ensureInitialized();
      if (!_initialized) {
        return;
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final settings = _readExperienceSettingsFromPrefs(prefs);
    if (!shouldRunAndroidBackgroundAlerts(settings) ||
        _shouldDisableBackgroundDataSaver(settings, prefs)) {
      await _cancelScheduledTasks();
      return;
    }

    await _registerOneOffTask(initialDelay: initialDelay);
  }

  static Future<void> _ensureInitialized() async {
    if (_initialized) {
      return;
    }

    try {
      await Workmanager().initialize(codewalkBackgroundAlertDispatcher);
      _initialized = true;
    } catch (error, stackTrace) {
      AppLogger.warn(
        'Failed to initialize Android background alert worker',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  static Future<void> _cancelScheduledTasks() async {
    if (!_initialized) {
      return;
    }

    try {
      await Workmanager().cancelByUniqueName(_backgroundAlertWorkUniqueName);
      await Workmanager().cancelByUniqueName(_backgroundAlertOneOffUniqueName);
      if (!FeatureFlags.androidAutoMessagingPrototype) {
        await Workmanager().cancelByTag(carMessagingReplyWorkTag);
      }
    } catch (error, stackTrace) {
      AppLogger.warn(
        'Failed to cancel Android background alert tasks',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  static Future<void> _registerOneOffTask({
    required Duration initialDelay,
  }) async {
    if (!_isAndroidRuntime()) {
      return;
    }

    try {
      await Workmanager().registerOneOffTask(
        _backgroundAlertOneOffUniqueName,
        _backgroundAlertTaskName,
        initialDelay: initialDelay,
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingWorkPolicy.replace,
        backoffPolicy: BackoffPolicy.linear,
        backoffPolicyDelay: const Duration(minutes: 15),
      );
    } catch (error, stackTrace) {
      AppLogger.warn(
        'Failed to schedule Android background alert one-off task',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  static Future<void> primeSnapshot({
    required String serverId,
    required Map<String, String> sessionStatusById,
    required Map<String, int> sessionUpdatedAtById,
    required Map<String, String> sessionTitleById,
  }) async {
    if (!_isAndroidRuntime()) {
      return;
    }

    final normalizedServerId = serverId.trim();
    if (normalizedServerId.isEmpty) {
      return;
    }

    final normalizedStatusById = <String, String>{};
    for (final entry in sessionStatusById.entries) {
      final sessionId = entry.key.trim();
      final status = entry.value.trim().toLowerCase();
      if (sessionId.isEmpty || status.isEmpty) {
        continue;
      }
      normalizedStatusById[sessionId] = status;
    }

    if (!hasActiveBackgroundSessions(normalizedStatusById)) {
      return;
    }

    final normalizedUpdatedAtById = <String, int>{};
    for (final entry in sessionUpdatedAtById.entries) {
      final sessionId = entry.key.trim();
      final updatedAt = entry.value;
      if (sessionId.isEmpty || updatedAt <= 0) {
        continue;
      }
      normalizedUpdatedAtById[sessionId] = updatedAt;
    }

    final normalizedTitleById = <String, String>{};
    for (final entry in sessionTitleById.entries) {
      final sessionId = entry.key.trim();
      final title = entry.value.trim();
      if (sessionId.isEmpty || title.isEmpty) {
        continue;
      }
      normalizedTitleById[sessionId] = title;
    }

    final prefs = await SharedPreferences.getInstance();
    final settings = _readExperienceSettingsFromPrefs(prefs);
    if (!shouldRunAndroidBackgroundAlerts(settings) ||
        _shouldDisableBackgroundDataSaver(settings, prefs)) {
      return;
    }
    final snapshotKey = _backgroundAlertSnapshotStorageKey(normalizedServerId);
    final existingSnapshotRaw = prefs.getString(snapshotKey);
    var existingSnapshot = BackgroundAlertSnapshot.empty();
    if (existingSnapshotRaw != null && existingSnapshotRaw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(existingSnapshotRaw);
        if (decoded is Map<String, dynamic>) {
          existingSnapshot = BackgroundAlertSnapshot.fromJson(decoded);
        } else if (decoded is Map) {
          existingSnapshot = BackgroundAlertSnapshot.fromJson(
            Map<String, dynamic>.from(decoded),
          );
        }
      } catch (_) {
        // Falls back to an empty snapshot.
      }
    }

    final primedSnapshot = BackgroundAlertSnapshot(
      sessionStatusById: normalizedStatusById,
      sessionUpdatedAtById: normalizedUpdatedAtById,
      sessionTitleById: {
        ...existingSnapshot.sessionTitleById,
        ...normalizedTitleById,
      },
      notifiedPermissionRequestIds:
          existingSnapshot.notifiedPermissionRequestIds,
      notifiedQuestionRequestIds: existingSnapshot.notifiedQuestionRequestIds,
      lastPolledAtEpochMs: DateTime.now().millisecondsSinceEpoch,
    );

    await prefs.setString(snapshotKey, jsonEncode(primedSnapshot.toJson()));
  }

  static Future<void> primePermissionAutoApproveContext({
    required PermissionAutoApproveBackgroundContext context,
    bool Function()? isCurrent,
  }) async {
    if (!_isAndroidRuntime() || !context.isValid) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final disabled = await prefs.setBool(
      _backgroundPermissionAutoApproveDisabledStorageKey(context.serverId),
      true,
    );
    if (!disabled) {
      throw StateError('Failed to stage background permission context');
    }
    if (isCurrent != null && !isCurrent()) {
      return;
    }
    final contextSaved = await prefs.setString(
      _backgroundPermissionAutoApproveContextStorageKey(context.serverId),
      jsonEncode(context.toJson()),
    );
    if (!contextSaved) {
      throw StateError('Failed to persist background permission context');
    }
    if (isCurrent != null && !isCurrent()) {
      return;
    }
    final enabled = await prefs.setBool(
      _backgroundPermissionAutoApproveDisabledStorageKey(context.serverId),
      false,
    );
    if (!enabled) {
      await prefs.setBool(
        _backgroundPermissionAutoApproveDisabledStorageKey(context.serverId),
        true,
      );
      throw StateError('Failed to enable background permission context');
    }
    if (isCurrent != null && !isCurrent()) {
      final redisabled = await prefs.setBool(
        _backgroundPermissionAutoApproveDisabledStorageKey(context.serverId),
        true,
      );
      if (!redisabled) {
        throw StateError(
          'Failed to revoke stale background permission context',
        );
      }
    }
  }

  static Future<void> disablePermissionAutoApproveContext({
    required String serverId,
  }) async {
    if (!_isAndroidRuntime()) {
      return;
    }

    final normalizedServerId = serverId.trim();
    if (normalizedServerId.isEmpty) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final disabled = await prefs.setBool(
      _backgroundPermissionAutoApproveDisabledStorageKey(normalizedServerId),
      true,
    );
    if (!disabled) {
      throw StateError('Failed to disable background permission context');
    }
  }

  static Future<bool> hasEnabledPermissionAutoApproveContext({
    required String serverId,
  }) async {
    if (!_isAndroidRuntime()) {
      return false;
    }
    final normalizedServerId = serverId.trim();
    if (normalizedServerId.isEmpty) {
      return false;
    }
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(
          _backgroundPermissionAutoApproveDisabledStorageKey(
            normalizedServerId,
          ),
        ) ==
        true) {
      return false;
    }
    final raw = prefs.getString(
      _backgroundPermissionAutoApproveContextStorageKey(normalizedServerId),
    );
    return raw != null && raw.trim().isNotEmpty;
  }

  static Future<void> clearPermissionAutoApproveContext({
    required String serverId,
  }) async {
    if (!_isAndroidRuntime()) {
      return;
    }

    final normalizedServerId = serverId.trim();
    if (normalizedServerId.isEmpty) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final disabled = await prefs.setBool(
      _backgroundPermissionAutoApproveDisabledStorageKey(normalizedServerId),
      true,
    );
    if (!disabled) {
      throw StateError('Failed to disable background permission context');
    }
    final contextKey = _backgroundPermissionAutoApproveContextStorageKey(
      normalizedServerId,
    );
    if (!prefs.containsKey(contextKey)) {
      return;
    }
    final removed = await prefs.remove(contextKey);
    if (!removed) {
      throw StateError('Failed to clear background permission context');
    }
  }

  @pragma('vm:entry-point')
  static Future<bool> executeTask({
    required String taskName,
    Map<String, dynamic>? inputData,
  }) async {
    if (!_isAndroidRuntime()) {
      return true;
    }

    _initialized = true;

    // The Workmanager isolate never builds a widget tree, so L10nBridge stays
    // null unless initialized here. Load it from the persisted locale before
    // any notification or channel string is resolved.
    await initializeBackgroundLocale();

    final runner = _AndroidBackgroundAlertRunner(
      planner: const BackgroundAlertPlanner(),
      notificationDispatcher: _BackgroundNotificationDispatcher(),
    );
    final replyId = inputData == null ? null : inputData['replyId']?.toString();
    return runner.run(
      taskName: taskName,
      carReplyId: taskName == carMessagingReplyTaskName ? replyId : null,
    );
  }

  /// Initializes [L10nBridge] from the persisted locale so translated
  /// notification and channel strings are used in the background isolate,
  /// where no widget tree exists to update the bridge. Falls back to English
  /// on any failure. This refreshes on every task because Workmanager may
  /// reuse an isolate after the user changes the app language.
  static Future<void> initializeBackgroundLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final settings = _readExperienceSettingsFromPrefs(prefs);
      L10nBridge.update(
        resolveBackgroundAlertLocalizations(settings.localeCode),
      );
    } catch (error, stackTrace) {
      AppLogger.warn(
        'Failed to initialize background alert locale',
        error: error,
        stackTrace: stackTrace,
      );
      L10nBridge.update(null);
    }
  }
}

class _AndroidBackgroundAlertRunner {
  const _AndroidBackgroundAlertRunner({
    required BackgroundAlertPlanner planner,
    required _BackgroundNotificationDispatcher notificationDispatcher,
  }) : _planner = planner,
       _notificationDispatcher = notificationDispatcher;

  final BackgroundAlertPlanner _planner;
  final _BackgroundNotificationDispatcher _notificationDispatcher;
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  Future<bool> run({required String taskName, String? carReplyId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settings = _readSettings(prefs);
      final isCarReplyTask = taskName == carMessagingReplyTaskName;
      if (!shouldRunAndroidBackgroundAlerts(settings)) {
        await AndroidBackgroundAlertWorker.syncRegistration(enabled: false);
        AppLogger.debug(
          'background_alert_worker skipped ($taskName): disabled in settings',
        );
        return true;
      }
      if (!settings.androidAutoMessagingEnabled && isCarReplyTask) {
        await CarMessagingRuntime.cancelPendingReplyWork();
        return true;
      }
      if (_shouldDisableBackgroundDataSaver(settings, prefs)) {
        return !isCarReplyTask;
      }

      final server = await _resolveServerConfig(prefs);
      if (server == null) {
        AppLogger.debug('background_alert_worker skipped (no active server)');
        return true;
      }

      final dio = _createDioClient(server);
      bool carGateOpen() {
        return shouldRunCarMessagingBackground(
          settings: _readSettings(prefs),
          isCellularTransport:
              CellularDataSaverService.readPersistedTransport(prefs) ==
              DataSaverTransport.cellular,
          featureEnabled: FeatureFlags.androidAutoMessagingPrototype,
        );
      }

      final carMessagingWorker = carGateOpen()
          ? CarMessagingDispatchWorker(
              dio: dio,
              serverId: server.serverId,
              gateOpen: carGateOpen,
            )
          : null;
      final snapshotKey = _snapshotStorageKey(server.serverId);
      final previousSnapshot = _readSnapshot(prefs, snapshotKey);
      final statusById = await _fetchSessionStatusById(dio);
      if (statusById == null) {
        await _scheduleRetryAfterStatusFailure(previousSnapshot);
        AppLogger.warn(
          'background_alert_worker skipped ($taskName): status fetch failed',
        );
        return true;
      }
      final carMessagingResult =
          await carMessagingWorker?.processReplies(
            statusById,
            replyId: carReplyId,
          ) ??
          const CarMessagingDispatchResult();
      if (isCarReplyTask) {
        if (carMessagingResult.pending) return false;
        return true;
      }

      final permissionEnabled =
          settings.notifications[NotificationCategory.permissions] ?? true;
      final agentEnabled =
          settings.notifications[NotificationCategory.agent] ?? true;
      final autoApproveContext = _readPermissionAutoApproveContext(
        prefs,
        server.serverId,
      );
      final shouldAttemptPermissionAutoApprove =
          settings.composerAutoApprovePermissions && autoApproveContext != null;
      final shouldFetchSessionMetadata =
          shouldAttemptPermissionAutoApprove ||
          agentEnabled ||
          settings.notifications.values.any((enabled) => enabled);
      var sessionMetadata = shouldFetchSessionMetadata
          ? await _fetchSessionMetadata(dio)
          : const _SessionMetadata.empty();
      final shouldFetchPermissions =
          permissionEnabled || shouldAttemptPermissionAutoApprove;
      var permissionRequests = shouldFetchPermissions
          ? await _fetchPermissionRequests(dio)
          : const <BackgroundInteractionRequest>[];
      final questionRequests = permissionEnabled
          ? await _fetchQuestionRequests(dio)
          : const <BackgroundInteractionRequest>[];
      if (shouldAttemptPermissionAutoApprove && permissionRequests.isNotEmpty) {
        final autoApproveResult = await _autoApprovePermissionRequests(
          dio: dio,
          context: autoApproveContext,
          sessionMetadata: sessionMetadata,
          permissionRequests: permissionRequests,
        );
        permissionRequests = autoApproveResult.remainingRequests;
      }
      final cachedTitles = <String, String>{
        ...previousSnapshot.sessionTitleById,
        ...sessionMetadata.titleBySessionId,
      };
      final currentState = BackgroundPollingState(
        sessionStatusById: statusById,
        sessionUpdatedAtById: sessionMetadata.updatedAtBySessionId.isEmpty
            ? Map<String, int>.from(previousSnapshot.sessionUpdatedAtById)
            : Map<String, int>.from(sessionMetadata.updatedAtBySessionId),
        sessionTitleById: cachedTitles,
        parentSessionIdByChild: Map<String, String>.from(
          sessionMetadata.parentSessionIdByChild,
        ),
        permissionRequests: permissionRequests,
        questionRequests: questionRequests,
      );

      final nowEpochMs = DateTime.now().millisecondsSinceEpoch;
      var plan = _planner.plan(
        previous: previousSnapshot,
        current: currentState,
        settings: settings,
        nowEpochMs: nowEpochMs,
      );

      if (_shouldRefreshSessionTitles(
        signals: plan.signals,
        cachedTitles: cachedTitles,
      )) {
        if (sessionMetadata.titleBySessionId.isEmpty &&
            sessionMetadata.updatedAtBySessionId.isEmpty) {
          sessionMetadata = await _fetchSessionMetadata(dio);
        }
        final refreshedTitles = <String, String>{
          ...cachedTitles,
          ...sessionMetadata.titleBySessionId,
        };
        final refreshedState = BackgroundPollingState(
          sessionStatusById: statusById,
          sessionUpdatedAtById: sessionMetadata.updatedAtBySessionId,
          sessionTitleById: refreshedTitles,
          parentSessionIdByChild: Map<String, String>.from(
            sessionMetadata.parentSessionIdByChild,
          ),
          permissionRequests: permissionRequests,
          questionRequests: questionRequests,
        );
        plan = _planner.plan(
          previous: previousSnapshot,
          current: refreshedState,
          settings: settings,
          nowEpochMs: nowEpochMs,
        );
      }

      if (!plan.baselineOnly) {
        for (final signal in plan.signals) {
          final directory =
              sessionMetadata.directoryBySessionId[signal.sessionId];
          final isRootCompletion =
              signal.kind == BackgroundAlertKind.completion &&
              !sessionMetadata.parentSessionIdByChild.containsKey(
                signal.sessionId,
              );
          final carPublished =
              isRootCompletion &&
                  directory != null &&
                  directory.trim().isNotEmpty &&
                  !carMessagingResult.notifiedSessionIds.contains(
                    signal.sessionId,
                  )
              ? await carMessagingWorker?.publishCompletion(
                      sessionId: signal.sessionId,
                      directory: directory,
                      title:
                          sessionMetadata.titleBySessionId[signal.sessionId] ??
                          signal.body,
                    ) ==
                    CarMessagingCompletionResult.published
              : carMessagingResult.notifiedSessionIds.contains(
                  signal.sessionId,
                );
          if (carPublished) {
            continue;
          }
          await _notificationDispatcher.show(
            signal: signal,
            serverId: server.serverId,
            directory: directory,
          );
        }
      }

      await prefs.setString(
        snapshotKey,
        jsonEncode(plan.nextSnapshot.toJson()),
      );

      await _scheduleNextProbe(
        previousSnapshot: previousSnapshot,
        currentStatusById: statusById,
        hasPendingCarReply: carMessagingResult.pending,
      );

      AppLogger.debug(
        'background_alert_worker task=$taskName baseline=${plan.baselineOnly} alerts=${plan.signals.length}',
      );
      return true;
    } catch (error, stackTrace) {
      AppLogger.warn(
        'background_alert_worker task failure',
        error: error,
        stackTrace: stackTrace,
      );
      return true;
    }
  }

  Future<void> _scheduleNextProbe({
    required BackgroundAlertSnapshot previousSnapshot,
    required Map<String, String> currentStatusById,
    bool hasPendingCarReply = false,
  }) async {
    if (hasPendingCarReply || hasActiveBackgroundSessions(currentStatusById)) {
      await _scheduleProbe(
        delay: AndroidBackgroundAlertWorker.activeSessionProbeInterval,
        reason: hasPendingCarReply ? 'car-reply' : 'active-session',
      );
      return;
    }

    if (shouldScheduleBackgroundTailProbe(
      previousSessionStatusById: previousSnapshot.sessionStatusById,
      currentSessionStatusById: currentStatusById,
    )) {
      await _scheduleProbe(
        delay: AndroidBackgroundAlertWorker.tailProbeInterval,
        reason: 'tail-after-active-session',
      );
    }
  }

  Future<void> _scheduleRetryAfterStatusFailure(
    BackgroundAlertSnapshot previousSnapshot,
  ) async {
    final wasActive = hasActiveBackgroundSessions(
      previousSnapshot.sessionStatusById,
    );
    await _scheduleProbe(
      delay: wasActive
          ? AndroidBackgroundAlertWorker.activeSessionProbeInterval
          : _backgroundAlertFailureRetryInterval,
      reason: wasActive ? 'status-failure-active' : 'status-failure-fallback',
    );
  }

  Future<void> _scheduleProbe({
    required Duration delay,
    required String reason,
  }) async {
    AppLogger.debug(
      'background_alert_worker schedule_probe reason=$reason delay=${delay.inMinutes}m',
    );

    await AndroidBackgroundAlertWorker.scheduleProbe(
      initialDelay: delay,
      ensureInitialized: false,
    );
  }

  Dio _createDioClient(_ResolvedServerConfig server) {
    final headers = <String, Object>{'Content-Type': 'application/json'};
    final authorizationHeader = server.authorizationHeader;
    if (authorizationHeader != null && authorizationHeader.isNotEmpty) {
      headers['Authorization'] = authorizationHeader;
    }

    return Dio(
      BaseOptions(
        baseUrl: server.baseUrl,
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 12),
        sendTimeout: const Duration(seconds: 12),
        headers: headers,
      ),
    );
  }

  ExperienceSettings _readSettings(SharedPreferences prefs) {
    return _readExperienceSettingsFromPrefs(prefs);
  }

  BackgroundAlertSnapshot _readSnapshot(SharedPreferences prefs, String key) {
    final raw = prefs.getString(key);
    if (raw == null || raw.trim().isEmpty) {
      return BackgroundAlertSnapshot.empty();
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return BackgroundAlertSnapshot.fromJson(decoded);
      }
      if (decoded is Map) {
        return BackgroundAlertSnapshot.fromJson(
          Map<String, dynamic>.from(decoded),
        );
      }
    } catch (_) {
      // Falls back to empty snapshot.
    }
    return BackgroundAlertSnapshot.empty();
  }

  PermissionAutoApproveBackgroundContext? _readPermissionAutoApproveContext(
    SharedPreferences prefs,
    String serverId,
  ) {
    if (prefs.getBool(
          _backgroundPermissionAutoApproveDisabledStorageKey(serverId),
        ) ==
        true) {
      return null;
    }
    final raw = prefs.getString(
      _backgroundPermissionAutoApproveContextStorageKey(serverId),
    );
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        final context = PermissionAutoApproveBackgroundContext.fromJson(
          decoded,
        );
        return context.isValid ? context : null;
      }
      if (decoded is Map) {
        final context = PermissionAutoApproveBackgroundContext.fromJson(
          Map<String, dynamic>.from(decoded),
        );
        return context.isValid ? context : null;
      }
    } catch (_) {
      // Falls back to no context.
    }
    return null;
  }

  String _snapshotStorageKey(String serverId) {
    return _backgroundAlertSnapshotStorageKey(serverId);
  }

  Future<_PermissionAutoApproveRunResult> _autoApprovePermissionRequests({
    required Dio dio,
    required PermissionAutoApproveBackgroundContext? context,
    required _SessionMetadata sessionMetadata,
    required List<BackgroundInteractionRequest> permissionRequests,
  }) async {
    if (context == null || permissionRequests.isEmpty) {
      return _PermissionAutoApproveRunResult(
        remainingRequests: permissionRequests,
      );
    }

    final allowedSessionIds = resolveThreadSessionIdsForBackgroundContext(
      context: context,
      parentSessionIdByChild: sessionMetadata.parentSessionIdByChild,
    );
    if (allowedSessionIds.isEmpty) {
      return _PermissionAutoApproveRunResult(
        remainingRequests: permissionRequests,
      );
    }

    final remainingRequests = <BackgroundInteractionRequest>[];
    for (final request in permissionRequests) {
      final sessionId = request.sessionId.trim();
      if (!allowedSessionIds.contains(sessionId)) {
        remainingRequests.add(request);
        continue;
      }

      final reply = permissionAutoApproveReplyForAlwaysPatterns(request.always);
      final approved = await _replyPermission(
        dio: dio,
        sessionId: sessionId,
        requestId: request.id,
        reply: reply,
        directory: context.directory,
      );
      if (!approved) {
        remainingRequests.add(request);
        continue;
      }

      AppLogger.info(
        'Background auto-approved permission request=${request.id} session=$sessionId reply=$reply scope=${context.scopeId}',
      );
    }

    return _PermissionAutoApproveRunResult(
      remainingRequests: remainingRequests,
    );
  }

  Future<bool> _replyPermission({
    required Dio dio,
    required String sessionId,
    required String requestId,
    required String reply,
    String? directory,
  }) async {
    final normalizedRequestId = requestId.trim();
    if (normalizedRequestId.isEmpty) {
      return false;
    }

    final queryParameters = <String, String>{};
    if (directory != null && directory.trim().isNotEmpty) {
      queryParameters['directory'] = directory.trim();
    }

    try {
      try {
        final response = await dio.post(
          '/session/$sessionId/permissions/$normalizedRequestId',
          data: <String, dynamic>{
            'response': reply,
            if (reply == 'always') 'remember': true,
          },
          queryParameters: queryParameters.isEmpty ? null : queryParameters,
        );
        return response.statusCode == 200;
      } on DioException catch (error) {
        if (error.response?.statusCode == 404 ||
            error.response?.statusCode == 405) {
          final legacyBody = <String, dynamic>{
            'reply': reply,
            if (reply == 'always') 'remember': true,
          };
          final legacyResponse = await dio.post(
            '/permission/$normalizedRequestId/reply',
            data: legacyBody,
            queryParameters: queryParameters.isEmpty ? null : queryParameters,
          );
          return legacyResponse.statusCode == 200;
        }
        rethrow;
      }
    } on DioException catch (error, stackTrace) {
      if (error.response?.statusCode == 404) {
        AppLogger.debug(
          'Background auto-approve treated as already resolved request=$normalizedRequestId',
        );
        return true;
      }
      AppLogger.warn(
        'Background auto-approve failed request=$normalizedRequestId',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    } catch (error, stackTrace) {
      AppLogger.warn(
        'Background auto-approve failed request=$normalizedRequestId',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  Future<_ResolvedServerConfig?> _resolveServerConfig(
    SharedPreferences prefs,
  ) async {
    final profilesRaw = prefs.getString(AppConstants.serverProfilesKey);
    final activeServerId = prefs.getString(AppConstants.activeServerIdKey);
    final defaultServerId = prefs.getString(AppConstants.defaultServerIdKey);

    if (profilesRaw != null && profilesRaw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(profilesRaw);
        if (decoded is List) {
          final profiles = decoded
              .whereType<Map>()
              .map((item) {
                return Map<String, dynamic>.from(item);
              })
              .toList(growable: false);
          if (profiles.isNotEmpty) {
            final selected = _selectServerProfile(
              profiles: profiles,
              activeServerId: activeServerId,
              defaultServerId: defaultServerId,
            );
            if (selected != null) {
              if (!supportsCarMessagingServerProfile(selected)) {
                return null;
              }
              final baseUrl = selected['url']?.toString().trim() ?? '';
              if (baseUrl.isNotEmpty) {
                final serverId = selected['id']?.toString().trim();
                final basicEnabled = selected['basicAuthEnabled'] == true;
                final legacyUsername =
                    selected['basicAuthUsername']?.toString().trim() ?? '';
                final legacyPassword =
                    selected['basicAuthPassword']?.toString().trim() ?? '';
                final effectiveServerId = (serverId == null || serverId.isEmpty)
                    ? 'profile'
                    : serverId;
                final username = await _resolveProfileCredential(
                  serverId: effectiveServerId,
                  base: AppConstants.secureServerProfileBasicAuthUsernameKey,
                  legacyValue: legacyUsername,
                );
                final password = await _resolveProfileCredential(
                  serverId: effectiveServerId,
                  base: AppConstants.secureServerProfileBasicAuthPasswordKey,
                  legacyValue: legacyPassword,
                );
                if (!hasRequiredBackgroundBasicCredentials(
                  basicAuthEnabled: basicEnabled,
                  username: username,
                  password: password,
                )) {
                  return null;
                }
                return _ResolvedServerConfig(
                  serverId: effectiveServerId,
                  baseUrl: baseUrl,
                  authorizationHeader: basicEnabled
                      ? _buildBasicAuthorizationHeader(
                          username: username,
                          password: password,
                        )
                      : null,
                );
              }
            }
          }
        }
      } catch (_) {
        // Falls back to legacy config.
      }
    }

    final host = prefs.getString(AppConstants.serverHostKey)?.trim();
    final port = prefs.getInt(AppConstants.serverPortKey);
    if (host != null && host.isNotEmpty && port != null) {
      final basicEnabled =
          prefs.getBool(AppConstants.basicAuthEnabledKey) ?? false;
      final username = await _resolveLegacyCredential(
        prefs: prefs,
        base: AppConstants.basicAuthUsernameKey,
      );
      final password = await _resolveLegacyCredential(
        prefs: prefs,
        base: AppConstants.basicAuthPasswordKey,
      );
      return _ResolvedServerConfig(
        serverId: 'legacy',
        baseUrl: 'http://$host:$port',
        authorizationHeader: basicEnabled
            ? _buildBasicAuthorizationHeader(
                username: username,
                password: password,
              )
            : null,
      );
    }

    return null;
  }

  String _serverProfileSecureKey({
    required String serverId,
    required String base,
  }) {
    final encodedServerId = Uri.encodeComponent(serverId.trim());
    return '${AppConstants.secureStorageNamespace}::$base::$encodedServerId';
  }

  String _legacySecureKey(String base) {
    return '${AppConstants.secureStorageNamespace}::$base';
  }

  Future<String> _resolveProfileCredential({
    required String serverId,
    required String base,
    required String legacyValue,
  }) async {
    final secureKey = _serverProfileSecureKey(serverId: serverId, base: base);
    try {
      final secureValue = await _secureStorage.read(key: secureKey);
      if (secureValue != null && secureValue.trim().isNotEmpty) {
        return secureValue;
      }
      if (legacyValue.trim().isEmpty) {
        return '';
      }
      await _secureStorage.write(key: secureKey, value: legacyValue);
      return legacyValue;
    } catch (_) {
      return legacyValue;
    }
  }

  Future<String> _resolveLegacyCredential({
    required SharedPreferences prefs,
    required String base,
  }) async {
    final secureKey = _legacySecureKey(base);
    try {
      final secureValue = await _secureStorage.read(key: secureKey);
      if (secureValue != null && secureValue.trim().isNotEmpty) {
        return secureValue;
      }
      final legacyValue = prefs.getString(base) ?? '';
      if (legacyValue.trim().isNotEmpty) {
        await _secureStorage.write(key: secureKey, value: legacyValue);
      }
      return legacyValue;
    } catch (_) {
      return prefs.getString(base) ?? '';
    }
  }

  Map<String, dynamic>? _selectServerProfile({
    required List<Map<String, dynamic>> profiles,
    required String? activeServerId,
    required String? defaultServerId,
  }) {
    for (final profile in profiles) {
      if (profile['id'] == activeServerId) {
        return profile;
      }
    }
    for (final profile in profiles) {
      if (profile['id'] == defaultServerId) {
        return profile;
      }
    }
    return profiles.first;
  }

  String? _buildBasicAuthorizationHeader({
    required String username,
    required String password,
  }) {
    final trimmedUser = username.trim();
    final trimmedPassword = password.trim();
    if (trimmedUser.isEmpty || trimmedPassword.isEmpty) {
      return null;
    }
    final encoded = base64Encode(utf8.encode('$trimmedUser:$trimmedPassword'));
    return 'Basic $encoded';
  }

  Future<Map<String, String>?> _fetchSessionStatusById(Dio dio) async {
    try {
      final response = await dio.get('/session/status');
      if (response.statusCode != 200) {
        return null;
      }
      final raw = response.data;
      if (raw is! Map) {
        return const <String, String>{};
      }

      final result = <String, String>{};
      raw.forEach((key, value) {
        final sessionId = key.toString().trim();
        if (sessionId.isEmpty || value is! Map) {
          return;
        }
        final status = SessionStatusModel.fromJson(
          Map<String, dynamic>.from(value),
        );
        result[sessionId] = status.type;
      });
      return result;
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) {
        return const <String, String>{};
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<_SessionMetadata> _fetchSessionMetadata(Dio dio) async {
    try {
      final response = await dio.get('/session');
      if (response.statusCode != 200) {
        return const _SessionMetadata.empty();
      }
      final raw = response.data;
      if (raw is! List) {
        return const _SessionMetadata.empty();
      }

      final titleById = <String, String>{};
      final updatedAtById = <String, int>{};
      final parentByChildId = <String, String>{};
      final directoryById = <String, String>{};
      for (final item in raw) {
        if (item is! Map) {
          continue;
        }
        final model = ChatSessionModel.fromJson(
          Map<String, dynamic>.from(item),
        );
        final sessionId = model.id.trim();
        if (sessionId.isEmpty) {
          continue;
        }
        final title = model.title?.trim();
        if (title != null && title.isNotEmpty) {
          titleById[sessionId] = title;
        }
        final updatedAt = model.time.updated;
        if (updatedAt > 0) {
          updatedAtById[sessionId] = updatedAt;
        }
        final parentId = model.parentId?.trim();
        if (parentId != null && parentId.isNotEmpty) {
          parentByChildId[sessionId] = parentId;
        }
        final directory = model.directory?.trim();
        if (directory != null && directory.isNotEmpty) {
          directoryById[sessionId] = directory;
        }
      }

      return _SessionMetadata(
        titleBySessionId: titleById,
        updatedAtBySessionId: updatedAtById,
        parentSessionIdByChild: parentByChildId,
        directoryBySessionId: directoryById,
      );
    } catch (_) {
      return const _SessionMetadata.empty();
    }
  }

  Future<List<BackgroundInteractionRequest>> _fetchPermissionRequests(
    Dio dio,
  ) async {
    try {
      final response = await dio.get('/permission');
      if (response.statusCode != 200) {
        return const <BackgroundInteractionRequest>[];
      }
      final raw = response.data;
      if (raw is! List) {
        return const <BackgroundInteractionRequest>[];
      }

      return raw
          .whereType<Map>()
          .map((item) {
            final parsed = ChatPermissionRequestModel.fromJson(
              Map<String, dynamic>.from(item),
            );
            return BackgroundInteractionRequest(
              id: parsed.id,
              sessionId: parsed.sessionId,
              always: parsed.always,
            );
          })
          .where((item) {
            return item.id.trim().isNotEmpty &&
                item.sessionId.trim().isNotEmpty;
          })
          .toList(growable: false);
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) {
        return const <BackgroundInteractionRequest>[];
      }
      return const <BackgroundInteractionRequest>[];
    } catch (_) {
      return const <BackgroundInteractionRequest>[];
    }
  }

  Future<List<BackgroundInteractionRequest>> _fetchQuestionRequests(
    Dio dio,
  ) async {
    try {
      final response = await dio.get('/question');
      if (response.statusCode != 200) {
        return const <BackgroundInteractionRequest>[];
      }
      final raw = response.data;
      if (raw is! List) {
        return const <BackgroundInteractionRequest>[];
      }

      return raw
          .whereType<Map>()
          .map((item) {
            final parsed = ChatQuestionRequestModel.fromJson(
              Map<String, dynamic>.from(item),
            );
            return BackgroundInteractionRequest(
              id: parsed.id,
              sessionId: parsed.sessionId,
            );
          })
          .where((item) {
            return item.id.trim().isNotEmpty &&
                item.sessionId.trim().isNotEmpty;
          })
          .toList(growable: false);
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) {
        return const <BackgroundInteractionRequest>[];
      }
      return const <BackgroundInteractionRequest>[];
    } catch (_) {
      return const <BackgroundInteractionRequest>[];
    }
  }

  bool _shouldRefreshSessionTitles({
    required List<BackgroundAlertSignal> signals,
    required Map<String, String> cachedTitles,
  }) {
    for (final signal in signals) {
      if (!cachedTitles.containsKey(signal.sessionId)) {
        return true;
      }
    }
    return false;
  }
}

class _BackgroundNotificationDispatcher {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _notificationsEnabled = true;

  Future<void> show({
    required BackgroundAlertSignal signal,
    required String serverId,
    String? directory,
  }) async {
    await _ensureInitialized();
    if (!_initialized || !_notificationsEnabled) {
      return;
    }

    final channel = _channelFor(signal.categoryKey);
    final normalizedSessionId = signal.sessionId.trim();
    final hasSessionId = normalizedSessionId.isNotEmpty;
    final payload = NotificationTapPayload(
      category: signal.categoryKey,
      sessionId: hasSessionId ? normalizedSessionId : null,
      serverId: serverId,
      directory: directory,
    ).toRaw();

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channel.id,
        channel.name,
        channelDescription: channel.description,
        importance: channel.highImportance
            ? Importance.high
            : Importance.defaultImportance,
        priority: channel.highImportance
            ? Priority.high
            : Priority.defaultPriority,
        groupKey: hasSessionId ? _sessionGroupKey(normalizedSessionId) : null,
        tag: hasSessionId ? _sessionTag(normalizedSessionId) : null,
      ),
    );

    try {
      await _plugin.show(
        id: _notificationId(signal),
        title: signal.title,
        body: signal.body,
        notificationDetails: details,
        payload: payload,
      );

      if (hasSessionId) {
        await _plugin.show(
          id: _summaryNotificationId(normalizedSessionId),
          title:
              L10nBridge.current?.notificationConversationUpdates ??
              'Conversation updates',
          body:
              L10nBridge.current?.notificationOpenToClear ??
              'Open this conversation to clear related notifications.',
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              channel.id,
              channel.name,
              channelDescription: channel.description,
              importance: channel.highImportance
                  ? Importance.high
                  : Importance.defaultImportance,
              priority: channel.highImportance
                  ? Priority.high
                  : Priority.defaultPriority,
              playSound: false,
              groupKey: _sessionGroupKey(normalizedSessionId),
              setAsGroupSummary: true,
              groupAlertBehavior: GroupAlertBehavior.summary,
              tag: _sessionSummaryTag(normalizedSessionId),
            ),
          ),
          payload: payload,
        );
      }
    } catch (error, stackTrace) {
      AppLogger.warn(
        'Failed to dispatch background alert notification',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) {
      return;
    }
    try {
      const android = AndroidInitializationSettings(
        '@drawable/ic_stat_codewalk',
      );
      const settings = InitializationSettings(android: android);
      await _plugin.initialize(settings: settings);
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      _notificationsEnabled =
          await androidPlugin?.areNotificationsEnabled() ?? true;
      _initialized = true;
    } catch (error, stackTrace) {
      _notificationsEnabled = false;
      AppLogger.warn(
        'Failed to initialize background notification dispatcher',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  int _notificationId(BackgroundAlertSignal signal) {
    final source =
        '${signal.kind.name}:${signal.sessionId}:${DateTime.now().microsecondsSinceEpoch}';
    return source.hashCode & 0x7fffffff;
  }

  int _summaryNotificationId(String sessionId) {
    return ('summary:$sessionId').hashCode & 0x7fffffff;
  }

  String _sessionGroupKey(String sessionId) => 'codewalk.session.$sessionId';
  String _sessionTag(String sessionId) => 'session:$sessionId';
  String _sessionSummaryTag(String sessionId) => 'session-summary:$sessionId';

  _NotificationChannelConfig _channelFor(String categoryKey) {
    final l10n = L10nBridge.current;
    return switch (categoryKey) {
      'errors' => _NotificationChannelConfig(
        id: 'codewalk_errors',
        name: l10n?.notificationChannelErrors ?? 'CodeWalk errors',
        description:
            l10n?.notificationChannelErrorsDescription ??
            'CodeWalk error alerts',
        highImportance: true,
      ),
      'permissions' => _NotificationChannelConfig(
        id: 'codewalk_permissions',
        name: l10n?.notificationChannelPermissions ?? 'CodeWalk permissions',
        description:
            l10n?.notificationChannelPermissionsDescription ??
            'CodeWalk action required alerts',
        highImportance: true,
      ),
      _ => _NotificationChannelConfig(
        id: 'codewalk_agent',
        name: l10n?.notificationChannelAgent ?? 'CodeWalk agent',
        description:
            l10n?.notificationChannelAgentDescription ??
            'CodeWalk agent completion alerts',
        highImportance: false,
      ),
    };
  }
}

class _ResolvedServerConfig {
  const _ResolvedServerConfig({
    required this.serverId,
    required this.baseUrl,
    required this.authorizationHeader,
  });

  final String serverId;
  final String baseUrl;
  final String? authorizationHeader;
}

class _SessionMetadata {
  const _SessionMetadata({
    required this.titleBySessionId,
    required this.updatedAtBySessionId,
    required this.parentSessionIdByChild,
    required this.directoryBySessionId,
  });

  const _SessionMetadata.empty()
    : titleBySessionId = const <String, String>{},
      updatedAtBySessionId = const <String, int>{},
      parentSessionIdByChild = const <String, String>{},
      directoryBySessionId = const <String, String>{};

  final Map<String, String> titleBySessionId;
  final Map<String, int> updatedAtBySessionId;
  final Map<String, String> parentSessionIdByChild;
  final Map<String, String> directoryBySessionId;
}

class _PermissionAutoApproveRunResult {
  const _PermissionAutoApproveRunResult({required this.remainingRequests});

  final List<BackgroundInteractionRequest> remainingRequests;
}

class _NotificationChannelConfig {
  const _NotificationChannelConfig({
    required this.id,
    required this.name,
    required this.description,
    required this.highImportance,
  });

  final String id;
  final String name;
  final String description;
  final bool highImportance;
}

bool _isAndroidRuntime() {
  if (kIsWeb) {
    return false;
  }
  return defaultTargetPlatform == TargetPlatform.android;
}

ExperienceSettings _readExperienceSettingsFromPrefs(SharedPreferences prefs) {
  final raw = prefs.getString(AppConstants.experienceSettingsKey);
  if (raw == null || raw.trim().isEmpty) {
    return ExperienceSettings.defaults();
  }

  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      return ExperienceSettings.fromJson(decoded);
    }
    if (decoded is Map) {
      return ExperienceSettings.fromJson(Map<String, dynamic>.from(decoded));
    }
  } catch (_) {
    // Falls back to defaults.
  }
  return ExperienceSettings.defaults();
}

String _backgroundAlertSnapshotStorageKey(String serverId) {
  final normalized = serverId.trim().isEmpty ? 'legacy' : serverId.trim();
  return '$_backgroundAlertSnapshotKeyPrefix::$normalized';
}

String _backgroundPermissionAutoApproveContextStorageKey(String serverId) {
  final normalized = serverId.trim().isEmpty ? 'legacy' : serverId.trim();
  return '$_backgroundPermissionAutoApproveContextKeyPrefix::$normalized';
}

String _backgroundPermissionAutoApproveDisabledStorageKey(String serverId) {
  final normalized = serverId.trim().isEmpty ? 'legacy' : serverId.trim();
  return '$_backgroundPermissionAutoApproveContextKeyPrefix-disabled::$normalized';
}

bool _shouldDisableBackgroundDataSaver(
  ExperienceSettings settings,
  SharedPreferences prefs,
) {
  return shouldDisableBackgroundNetworkForDataSaver(
    settings: settings,
    isCellularTransport:
        CellularDataSaverService.readPersistedTransport(prefs) ==
        DataSaverTransport.cellular,
  );
}
