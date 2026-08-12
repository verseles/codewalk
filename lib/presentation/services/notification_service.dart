import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../core/i18n/l10n_bridge.dart';
import '../../core/logging/app_logger.dart';
import '../../domain/entities/experience_settings.dart';
import 'app_activation_service.dart';
import 'session_attention/session_attention_host_protocol.dart';
import 'web_notification_bridge.dart';

typedef AppActivationCallback = Future<void> Function();
typedef ActiveNotificationsReader = Future<List<ActiveNotification>> Function();
typedef NotificationCanceller =
    Future<void> Function({required int id, String? tag});
typedef AllNotificationsCanceller = Future<void> Function();

class NotificationTapPayload {
  const NotificationTapPayload({
    required this.category,
    this.action,
    this.sessionId,
    this.serverId,
    this.directory,
    this.snapshotId,
    this.notificationId,
  });

  final String category;
  final String? action;
  final String? sessionId;
  final String? serverId;
  final String? directory;
  final String? snapshotId;
  final int? notificationId;

  String toRaw() {
    return jsonEncode(<String, dynamic>{
      'category': category,
      'action': action,
      'sessionId': sessionId,
      'serverId': serverId,
      'directory': directory,
      'snapshotId': snapshotId,
      'notificationId': notificationId,
    });
  }

  static NotificationTapPayload? fromRaw(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final category = decoded['category']?.toString().trim();
      if (category == null || category.isEmpty) {
        return null;
      }
      final sessionId = decoded['sessionId']?.toString().trim();
      final action = decoded['action']?.toString().trim();
      final serverId = decoded['serverId']?.toString().trim();
      final directory = decoded['directory']?.toString().trim();
      final snapshotId = decoded['snapshotId']?.toString().trim();
      final notificationId = _parseNotificationId(decoded['notificationId']);
      return NotificationTapPayload(
        category: category,
        action: (action?.isEmpty ?? true) ? null : action,
        sessionId: (sessionId?.isEmpty ?? true) ? null : sessionId,
        serverId: (serverId?.isEmpty ?? true) ? null : serverId,
        directory: (directory?.isEmpty ?? true) ? null : directory,
        snapshotId: (snapshotId?.isEmpty ?? true) ? null : snapshotId,
        notificationId: notificationId,
      );
    } catch (_) {
      return null;
    }
  }

  static int? _parseNotificationId(Object? value) {
    return switch (value) {
      int id when id >= 0 => id,
      num id when id >= 0 => id.toInt(),
      String raw => _parseNotificationIdString(raw),
      _ => null,
    };
  }

  static int? _parseNotificationIdString(String raw) {
    final id = int.tryParse(raw.trim());
    return id == null || id < 0 ? null : id;
  }
}

class NotificationService {
  NotificationService({
    FlutterLocalNotificationsPlugin? plugin,
    AppActivationCallback? activateApp,
    ActiveNotificationsReader? activeNotificationsReader,
    NotificationCanceller? notificationCanceller,
    AllNotificationsCanceller? allNotificationsCanceller,
    @visibleForTesting bool assumeInitialized = false,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
       _activateApp = activateApp ?? bringCodeWalkToFront,
       _activeNotificationsReader = activeNotificationsReader,
       _notificationCanceller = notificationCanceller,
       _allNotificationsCanceller = allNotificationsCanceller,
       _initialized = assumeInitialized;

  static const String _androidSmallIcon = '@drawable/ic_stat_codewalk';
  static const MethodChannel _overlayActivationChannel = MethodChannel(
    'codewalk/session_overlay_activation',
  );
  static const MethodChannel _overlayHostChannel = MethodChannel(
    'codewalk/session_overlay_host',
  );

  final FlutterLocalNotificationsPlugin _plugin;
  final AppActivationCallback _activateApp;
  final ActiveNotificationsReader? _activeNotificationsReader;
  final NotificationCanceller? _notificationCanceller;
  final AllNotificationsCanceller? _allNotificationsCanceller;
  final StreamController<NotificationTapPayload> _tapController =
      StreamController<NotificationTapPayload>.broadcast();
  final Map<String, Set<int>> _notificationIdsBySession = <String, Set<int>>{};
  bool _initialized;
  NotificationTapPayload? _pendingTap;
  StreamSubscription<String>? _webTapSubscription;
  StreamSubscription<Map<String, dynamic>>? _attentionCommandSubscription;

  Stream<NotificationTapPayload> get onNotificationTapped =>
      _tapController.stream;

  NotificationTapPayload? consumePendingTap() {
    final pending = _pendingTap;
    _pendingTap = null;
    return pending;
  }

  void dispose() {
    try {
      _overlayActivationChannel.setMethodCallHandler(null);
    } catch (_) {
      // Unit tests and early shutdown may not have a binary messenger.
    }
    _webTapSubscription?.cancel();
    _webTapSubscription = null;
    _attentionCommandSubscription?.cancel();
    _attentionCommandSubscription = null;
    _tapController.close();
  }

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    try {
      _attentionCommandSubscription ??= SessionAttentionHostCommandBus.stream
          .listen((command) {
            _emitTap(
              NotificationTapPayload(
                category: 'session_attention',
                action: command['action'] as String?,
                sessionId: command['sessionId'] as String?,
                serverId: command['serverId'] as String?,
                directory: command['directory'] as String?,
                snapshotId: command['snapshotId'] as String?,
              ),
            );
          });
      if (kIsWeb) {
        _webTapSubscription ??= webNotificationTapStream.listen(
          (rawPayload) => unawaited(_handleRawTap(rawPayload)),
        );
        _initialized = true;
        return;
      }

      if (defaultTargetPlatform == TargetPlatform.android) {
        _overlayActivationChannel.setMethodCallHandler((call) async {
          if (call.method != 'activation' || call.arguments is! Map) {
            return false;
          }
          final args = Map<String, dynamic>.from(call.arguments as Map);
          final payload = NotificationTapPayload(
            category: 'session_attention',
            action: args['action'] as String?,
            sessionId: args['sessionId'] as String?,
            serverId: args['serverId'] as String?,
            directory: args['directory'] as String?,
            snapshotId: args['snapshotId'] as String?,
          );
          await _handleRawTap(payload.toRaw());
          return true;
        });
        Map<String, dynamic>? pending;
        try {
          pending = await _overlayHostChannel.invokeMapMethod<String, dynamic>(
            'consumeOverlayActivation',
          );
        } on MissingPluginException {
          pending = null;
        }
        if (pending != null) {
          await _handleRawTap(
            NotificationTapPayload(
              category: 'session_attention',
              action: pending['action'] as String?,
              sessionId: pending['sessionId'] as String?,
              serverId: pending['serverId'] as String?,
              directory: pending['directory'] as String?,
              snapshotId: pending['snapshotId'] as String?,
            ).toRaw(),
          );
        }
      }

      const android = AndroidInitializationSettings('@mipmap/launcher_icon');
      const macos = DarwinInitializationSettings();
      final linux = LinuxInitializationSettings(
        defaultActionName: L10nBridge.current?.notificationActionOpen ?? 'Open',
      );
      const windows = WindowsInitializationSettings(
        appName: 'CodeWalk',
        appUserModelId: 'com.codewalk.app',
        guid: '1f111f3e-6f5e-4fca-9ba2-2c9f8f9ddc7a',
      );
      final settings = InitializationSettings(
        android: android,
        macOS: macos,
        linux: linux,
        windows: windows,
      );

      await _plugin.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: (response) {
          unawaited(_handleRawTap(response.payload));
        },
      );

      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidPlugin?.requestNotificationsPermission();

      final macOsPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >();
      await macOsPlugin?.requestPermissions(
        alert: true,
        badge: false,
        sound: true,
      );

      // Mark ready before reading launch details so notification-tap cleanup can
      // safely run if the launch-details callback is delivered asynchronously.
      _initialized = true;

      final launchDetails = await _plugin.getNotificationAppLaunchDetails();
      if (launchDetails?.didNotificationLaunchApp == true) {
        unawaited(_handleRawTap(launchDetails?.notificationResponse?.payload));
      }
    } catch (error, stackTrace) {
      AppLogger.warn(
        'Notification initialization unavailable on this platform',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<bool> notify({
    required String title,
    required String body,
    required String category,
    String? sessionId,
    String? serverId,
    String? directory,
    bool playSound = true,
    SoundOption soundOption = SoundOption.systemDefault,
    String? soundSource,
  }) async {
    final normalizedSessionId = _normalizeSessionId(sessionId);
    final normalizedDirectory = _normalizeDirectory(directory);
    final notificationId = _nextNotificationId();
    final payload = NotificationTapPayload(
      category: category,
      sessionId: normalizedSessionId,
      serverId: serverId?.trim().isNotEmpty == true ? serverId!.trim() : null,
      directory: normalizedDirectory,
      notificationId: notificationId,
    ).toRaw();

    if (kIsWeb) {
      await initialize();
      final granted = await requestWebNotificationPermission();
      if (!granted) {
        AppLogger.info('Web notification permission denied: $title');
        return false;
      }
      return showWebNotification(title: title, body: body, payload: payload);
    }

    await initialize();

    if (!_initialized) {
      return false;
    }

    try {
      final details = _buildDetails(
        category: category,
        sessionId: normalizedSessionId,
        playSound: playSound,
        soundOption: soundOption,
        soundSource: soundSource,
      );

      await _plugin.show(
        id: notificationId,
        title: title,
        body: body,
        notificationDetails: details,
        payload: payload,
      );

      if (normalizedSessionId != null) {
        _notificationIdsBySession
            .putIfAbsent(normalizedSessionId, () => <int>{})
            .add(notificationId);
        await _showAndroidGroupSummary(
          category: category,
          sessionId: normalizedSessionId,
          payload: payload,
        );
      }

      return true;
    } catch (error, stackTrace) {
      AppLogger.warn(
        'Notification dispatch failed',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  Future<void> clearNotificationsForSession(String sessionId) async {
    final normalizedSessionId = _normalizeSessionId(sessionId);
    if (normalizedSessionId == null) {
      return;
    }

    final task = AppLogger.beginTask(
      'notification_clear',
      tags: const <String>{'notification:clear'},
      context: <String, Object?>{
        'sessionId': AppLogger.safeContextId(normalizedSessionId),
      },
    );
    try {
      await _clearNotificationsForSessionNormalized(normalizedSessionId);
      task.end();
    } catch (error, stackTrace) {
      task.end(status: 'error', error: error, stackTrace: stackTrace);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> _clearNotificationsForSessionNormalized(
    String normalizedSessionId,
  ) async {
    if (kIsWeb) {
      _notificationIdsBySession.remove(normalizedSessionId);
      return;
    }

    await initialize();
    if (!_initialized) {
      return;
    }

    final targets = <_CancelTarget>[];
    final knownIds = _notificationIdsBySession.remove(normalizedSessionId);
    final hadKnownSessionNotifications = knownIds?.isNotEmpty ?? false;
    if (knownIds != null) {
      for (final id in knownIds) {
        targets.add(
          _CancelTarget(id: id, tag: _sessionTag(normalizedSessionId)),
        );
      }
    }

    if (_isWindowsRuntime && !hadKnownSessionNotifications) {
      return;
    }

    var activeHistoryUnavailable = false;
    try {
      final active = await _getActiveNotifications();
      activeHistoryUnavailable = active.isEmpty;
      final expectedGroupKey = _sessionGroupKey(normalizedSessionId);
      final expectedTag = _sessionTag(normalizedSessionId);
      final expectedSummaryTag = _sessionSummaryTag(normalizedSessionId);
      for (final notification in active) {
        final id = notification.id;
        if (id == null) {
          continue;
        }
        final payloadSession = NotificationTapPayload.fromRaw(
          notification.payload,
        )?.sessionId;
        final matches =
            payloadSession == normalizedSessionId ||
            notification.groupKey == expectedGroupKey ||
            notification.tag == expectedTag ||
            notification.tag == expectedSummaryTag;
        if (!matches) {
          continue;
        }
        targets.add(_CancelTarget(id: id, tag: notification.tag));
      }
    } catch (_) {
      // Some platforms may not expose active notifications.
    }

    targets.add(
      _CancelTarget(
        id: _summaryNotificationId(normalizedSessionId),
        tag: _sessionSummaryTag(normalizedSessionId),
      ),
    );

    final dedupe = <String>{};
    for (final target in targets) {
      final key = '${target.id}|${target.tag ?? ''}';
      if (!dedupe.add(key)) {
        continue;
      }
      try {
        await _cancelNotification(id: target.id, tag: target.tag);
      } catch (_) {
        // Best effort cleanup.
      }
    }

    if (_isWindowsRuntime &&
        hadKnownSessionNotifications &&
        activeHistoryUnavailable) {
      await _clearAllWindowsNotificationsBestEffort();
    }
  }

  NotificationDetails _buildDetails({
    required String category,
    required String? sessionId,
    required bool playSound,
    required SoundOption soundOption,
    required String? soundSource,
  }) {
    final channelId = _androidChannelId(
      category: category,
      playSound: playSound,
      soundOption: soundOption,
      soundSource: soundSource,
    );
    final groupKey = sessionId == null ? null : _sessionGroupKey(sessionId);
    final tag = sessionId == null ? null : _sessionTag(sessionId);

    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        _androidChannelName(category),
        channelDescription: _androidChannelDescription(category),
        importance: _androidImportanceForCategory(category),
        priority: _androidPriorityForCategory(category),
        icon: _androidSmallIcon,
        playSound: playSound,
        sound: _resolveAndroidSound(
          playSound: playSound,
          soundOption: soundOption,
          soundSource: soundSource,
        ),
        groupKey: groupKey,
        groupAlertBehavior: sessionId == null
            ? GroupAlertBehavior.all
            : GroupAlertBehavior.children,
        tag: tag,
      ),
      macOS: DarwinNotificationDetails(
        presentSound: playSound,
        threadIdentifier: sessionId,
      ),
      linux: LinuxNotificationDetails(
        sound: _resolveLinuxThemeSound(
          playSound: playSound,
          soundOption: soundOption,
          soundSource: soundSource,
        ),
        suppressSound: !playSound,
      ),
      windows: playSound
          ? WindowsNotificationDetails(
              audio: WindowsNotificationAudio.preset(
                sound: WindowsNotificationSound.defaultSound,
              ),
            )
          : WindowsNotificationDetails(
              audio: WindowsNotificationAudio.silent(),
            ),
    );
  }

  Future<void> _showAndroidGroupSummary({
    required String category,
    required String sessionId,
    required String payload,
  }) async {
    if (!_isAndroidRuntime) {
      return;
    }

    final summaryDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        _androidChannelId(
          category: category,
          playSound: false,
          soundOption: SoundOption.off,
          soundSource: null,
        ),
        _androidChannelName(category),
        channelDescription: _androidChannelDescription(category),
        importance: _androidImportanceForCategory(category),
        priority: _androidPriorityForCategory(category),
        icon: _androidSmallIcon,
        playSound: false,
        groupKey: _sessionGroupKey(sessionId),
        setAsGroupSummary: true,
        groupAlertBehavior: GroupAlertBehavior.children,
        tag: _sessionSummaryTag(sessionId),
      ),
    );

    await _plugin.show(
      id: _summaryNotificationId(sessionId),
      title:
          L10nBridge.current?.notificationConversationUpdates ??
          'Conversation updates',
      body:
          L10nBridge.current?.notificationOpenToClear ??
          'Open this conversation to clear related notifications.',
      notificationDetails: summaryDetails,
      payload: payload,
    );
  }

  Importance _androidImportanceForCategory(String category) {
    return switch (category) {
      'errors' || 'permissions' => Importance.high,
      _ => Importance.defaultImportance,
    };
  }

  Priority _androidPriorityForCategory(String category) {
    return switch (category) {
      'errors' || 'permissions' => Priority.high,
      _ => Priority.defaultPriority,
    };
  }

  AndroidNotificationSound? _resolveAndroidSound({
    required bool playSound,
    required SoundOption soundOption,
    required String? soundSource,
  }) {
    if (!playSound) {
      return null;
    }

    if (soundOption != SoundOption.systemChoice &&
        soundOption != SoundOption.customFile) {
      return null;
    }

    final normalized = _normalizeAndroidSoundSource(soundSource);
    if (normalized == null) {
      return null;
    }
    return UriAndroidNotificationSound(normalized);
  }

  LinuxNotificationSound? _resolveLinuxThemeSound({
    required bool playSound,
    required SoundOption soundOption,
    required String? soundSource,
  }) {
    if (!playSound || soundOption != SoundOption.systemChoice) {
      return null;
    }
    final trimmed = soundSource?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    final slashIndex = trimmed.lastIndexOf('/');
    final fileName = slashIndex >= 0
        ? trimmed.substring(slashIndex + 1)
        : trimmed;
    final dotIndex = fileName.lastIndexOf('.');
    final themeName = dotIndex > 0 ? fileName.substring(0, dotIndex) : fileName;
    if (themeName.isEmpty) {
      return null;
    }
    return ThemeLinuxSound(themeName);
  }

  String _androidChannelName(String category) {
    final l10n = L10nBridge.current;
    return switch (category) {
      'errors' => l10n?.notificationChannelErrors ?? 'CodeWalk errors',
      'permissions' =>
        l10n?.notificationChannelPermissions ?? 'CodeWalk permissions',
      'agent' => l10n?.notificationChannelAgent ?? 'CodeWalk agent',
      _ => 'CodeWalk $category',
    };
  }

  String _androidChannelDescription(String category) {
    final l10n = L10nBridge.current;
    return switch (category) {
      'errors' =>
        l10n?.notificationChannelErrorsDescription ?? 'CodeWalk error alerts',
      'permissions' =>
        l10n?.notificationChannelPermissionsDescription ??
            'CodeWalk action required alerts',
      'agent' =>
        l10n?.notificationChannelAgentDescription ??
            'CodeWalk agent completion alerts',
      _ => 'CodeWalk $category notifications',
    };
  }

  String _androidChannelId({
    required String category,
    required bool playSound,
    required SoundOption soundOption,
    required String? soundSource,
  }) {
    final fingerprint = playSound
        ? '${soundOptionKey(soundOption)}:${soundSource ?? ''}'
        : 'silent';
    final hash = fingerprint.hashCode.abs().toRadixString(16);
    return 'codewalk_${category}_$hash';
  }

  String? _normalizeAndroidSoundSource(String? source) {
    final trimmed = source?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    if (trimmed.startsWith('content://') ||
        trimmed.startsWith('file://') ||
        trimmed.startsWith('android.resource://')) {
      return trimmed;
    }
    if (trimmed.startsWith('/')) {
      return Uri.file(trimmed).toString();
    }
    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.hasScheme) {
      return trimmed;
    }
    return null;
  }

  String? _normalizeSessionId(String? sessionId) {
    final trimmed = sessionId?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  String? _normalizeDirectory(String? directory) {
    final trimmed = directory?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  int _nextNotificationId() {
    return DateTime.now().microsecondsSinceEpoch & 0x7fffffff;
  }

  int _summaryNotificationId(String sessionId) {
    return ('summary:$sessionId').hashCode & 0x7fffffff;
  }

  String _sessionGroupKey(String sessionId) => 'codewalk.session.$sessionId';
  String _sessionTag(String sessionId) => 'session:$sessionId';
  String _sessionSummaryTag(String sessionId) => 'session-summary:$sessionId';

  bool get _isAndroidRuntime {
    if (kIsWeb) {
      return false;
    }
    return defaultTargetPlatform == TargetPlatform.android;
  }

  @visibleForTesting
  Future<void> debugHandleRawTap(String? rawPayload) {
    return _handleRawTap(rawPayload);
  }

  @visibleForTesting
  void debugTrackNotificationForSession(String sessionId, int notificationId) {
    final normalizedSessionId = _normalizeSessionId(sessionId);
    if (normalizedSessionId == null) {
      return;
    }
    _notificationIdsBySession
        .putIfAbsent(normalizedSessionId, () => <int>{})
        .add(notificationId);
  }

  Future<List<ActiveNotification>> _getActiveNotifications() {
    final reader = _activeNotificationsReader;
    if (reader != null) {
      return reader();
    }
    return _plugin.getActiveNotifications();
  }

  Future<void> _cancelNotification({required int id, String? tag}) {
    final canceller = _notificationCanceller;
    if (canceller != null) {
      return canceller(id: id, tag: tag);
    }
    return _plugin.cancel(id: id, tag: tag);
  }

  Future<void> _cancelAllNotifications() {
    final canceller = _allNotificationsCanceller;
    if (canceller != null) {
      return canceller();
    }
    return _plugin.cancelAll();
  }

  Future<void> _handleRawTap(String? rawPayload) async {
    final payload = NotificationTapPayload.fromRaw(rawPayload);
    if (payload == null) {
      return;
    }
    try {
      await _activateApp();
    } catch (error, stackTrace) {
      AppLogger.warn(
        'Notification tap could not bring the app to front',
        error: error,
        stackTrace: stackTrace,
      );
    }
    _emitTap(payload);
    await _dismissTappedNotification(payload);
  }

  void _emitTap(NotificationTapPayload payload) {
    _pendingTap = payload;
    if (!_tapController.isClosed) _tapController.add(payload);
  }

  Future<void> _dismissTappedNotification(
    NotificationTapPayload payload,
  ) async {
    final sessionId = _normalizeSessionId(payload.sessionId);
    final notificationId = payload.notificationId;
    if (notificationId != null) {
      await _cancelNotificationTarget(
        _CancelTarget(
          id: notificationId,
          tag: sessionId == null ? null : _sessionTag(sessionId),
        ),
      );
    }
    if (sessionId != null) {
      await clearNotificationsForSession(sessionId);
    }
  }

  Future<void> _clearAllWindowsNotificationsBestEffort() async {
    try {
      // Unpackaged Win32 builds cannot target individual toasts, but the
      // Windows plugin can clear the app's AUMID history. This may remove
      // notifications from other sessions; only use it after targeted cleanup
      // cannot observe active history.
      await _cancelAllNotifications();
    } catch (_) {
      // Best effort cleanup for Windows builds without package identity.
    }
  }

  Future<void> _cancelNotificationTarget(_CancelTarget target) async {
    try {
      await _cancelNotification(id: target.id, tag: target.tag);
    } catch (_) {
      // Best effort cleanup.
    }
  }

  bool get _isWindowsRuntime {
    if (kIsWeb) {
      return false;
    }
    return defaultTargetPlatform == TargetPlatform.windows;
  }
}

class _CancelTarget {
  const _CancelTarget({required this.id, this.tag});

  final int id;
  final String? tag;
}
