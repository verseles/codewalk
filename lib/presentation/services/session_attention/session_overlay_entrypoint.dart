import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/auth/tts_api_key_storage.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/i18n/l10n_bridge.dart';
import '../../../data/datasources/chat_remote_datasource.dart';
import '../../../data/models/chat_session_model.dart';
import '../../../data/repositories/chat_repository_impl.dart';
import '../../../data/session_attention/session_attention_snapshot_store.dart';
import '../../../domain/entities/experience_settings.dart';
import '../../../domain/entities/session_attention_overlay/session_attention_models.dart';
import '../../../domain/usecases/get_chat_messages.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../widgets/session_attention_overlay/session_attention_overlay.dart';
import '../../widgets/session_attention_overlay/session_attention_overlay_controller.dart';
import '../android_background_alert_logic.dart';
import '../cellular_data_saver_service.dart';
import '../read_aloud_service.dart';
import '../tts/edge_experimental_tts_backend.dart';
import '../tts/elevenlabs_tts_backend.dart';
import '../tts/native_tts_backend.dart';
import '../tts/nvidia_nim_tts_backend.dart';
import '../tts/openai_compatible_tts_backend.dart';
import '../tts/tts_backend.dart';
import 'session_attention_completion_resolver.dart';
import 'session_attention_host_protocol.dart';

const _androidServiceChannel = MethodChannel(
  'codewalk/session_overlay_service',
);

@pragma('vm:entry-point')
void sessionOverlayAndroidMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SessionAttentionHostApp.android());
}

class SessionAttentionHostApp extends StatefulWidget {
  const SessionAttentionHostApp.android({super.key});

  @override
  State<SessionAttentionHostApp> createState() =>
      _SessionAttentionHostAppState();
}

class _SessionAttentionHostAppState extends State<SessionAttentionHostApp> {
  SessionAttentionHostSnapshot? _snapshot;
  ReadAloudService? _androidReadAloudService;
  SessionAttentionOverlayController? _androidController;
  SessionAttentionSnapshotStore? _androidStore;
  Timer? _androidFallbackTimer;
  Timer? _androidFallbackSignalTimer;
  DateTime? _androidFallbackSignalWindowStarted;
  StreamSubscription<dynamic>? _androidFallbackSseSubscription;
  bool _androidFallbackSseHealthy = false;
  String? _androidFallbackScopeKey;
  int _androidFallbackEpoch = 0;
  bool _androidFallbackInFlight = false;
  bool _androidFallbackReconcilePending = false;
  Future<void> _androidCommandTail = Future<void>.value();
  CellularDataSaverService? _androidDataSaverService;
  final Map<String, String> _androidPreviousStatus = <String, String>{};
  final Map<String, DateTime> _androidBusyStarted = <String, DateTime>{};
  final Set<String> _androidErrorSessions = <String>{};
  ExperienceSettings _androidSettings = ExperienceSettings.defaults();
  Locale _androidLocale = const Locale('en');
  @override
  void initState() {
    super.initState();
    _androidServiceChannel.setMethodCallHandler(_handleMethodCall);
    _androidServiceChannel.invokeMethod<void>('requestFullSnapshot');
    unawaited(_initializeAndroidHost());
  }

  Future<void> _initializeAndroidHost() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.reload();
      final rawSettings = preferences.getString(
        AppConstants.experienceSettingsKey,
      );
      var settings = ExperienceSettings.defaults();
      if (rawSettings != null && rawSettings.isNotEmpty) {
        final decoded = jsonDecode(rawSettings);
        if (decoded is Map) {
          settings = ExperienceSettings.fromJson(
            Map<String, dynamic>.from(decoded),
          );
        }
      }
      final presentationOverride = preferences.getString(
        AppConstants.sessionAttentionPresentationOverrideKey,
      );
      if (presentationOverride != null) {
        for (final value in SessionAttentionPresentation.values) {
          if (value.name == presentationOverride) {
            settings = settings.copyWith(sessionAttentionPresentation: value);
            break;
          }
        }
      }
      _androidSettings = settings;
      _updateAndroidLocale();
      final store = SessionAttentionSnapshotStore();
      final readAloud = ReadAloudService(
        apiKeyStorage: TtsApiKeyStorage(),
        backends: <ReadAloudProvider, TtsBackend>{
          ReadAloudProvider.native: NativeTtsBackend(),
          ReadAloudProvider.edgeExperimental: EdgeExperimentalTtsBackend(),
          ReadAloudProvider.openAiCompatible: OpenAiCompatibleTtsBackend(),
          ReadAloudProvider.elevenLabs: ElevenLabsTtsBackend(),
          ReadAloudProvider.nim: NvidiaNimTtsBackend(),
        },
      );
      final controller = SessionAttentionOverlayController(
        snapshotStore: store,
        readAloudService: readAloud,
        settings: () => _androidSettings,
        noteExplicitUserAction: (reason) {
          _androidDataSaverService?.noteExplicitUserAction(reason: reason);
        },
      )..addListener(_handleAndroidControllerChanged);
      _androidDataSaverService = CellularDataSaverService(
        sharedPreferences: preferences,
        startMonitoring: false,
      );
      _androidReadAloudService = readAloud;
      _androidController = controller;
      _androidStore = store;
      final read = await store.read();
      final activeServerId =
          preferences.getString(AppConstants.activeServerIdKey) ?? '';
      final mainProducerAlive =
          await _androidServiceChannel.invokeMethod<bool>(
            'isMainProducerAlive',
          ) ??
          false;
      if (!mainProducerAlive) {
        final snapshot = SessionAttentionHostSnapshot(
          generation: 'service-${DateTime.now().microsecondsSinceEpoch}',
          revision: read.payload.revision,
          presentation: settings.sessionAttentionPresentation,
          bubbleScale: sessionAttentionBubbleScale(
            settings.sessionAttentionBubbleSize,
          ),
          appInForeground: false,
          activeServerId: activeServerId,
          items: read.payload.items
              .where((item) => item.identity.serverId == activeServerId)
              .toList(growable: false),
          fullResynchronization: true,
          producer: 'restore',
        );
        await _androidServiceChannel.invokeMethod<void>(
          'restoreSnapshot',
          snapshot.toJson(),
        );
      }
      _androidFallbackTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => unawaited(_runAndroidFallbackTick()),
      );
      unawaited(_runAndroidFallbackTick(forceReconcile: true));
    } catch (_) {
      // Keep the FGS alive with no sensitive view until the main producer syncs.
    }
  }

  void _handleAndroidControllerChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _applyAndroidLocalState({
    List<SessionAttentionItem>? items,
    SessionAttentionPresentation? presentation,
    int? expectedFallbackEpoch,
    String? expectedServerId,
  }) async {
    final current = _snapshot;
    if (current == null ||
        (expectedFallbackEpoch != null &&
            (_androidFallbackEpoch != expectedFallbackEpoch ||
                current.activeServerId != expectedServerId))) {
      return;
    }
    final next = SessionAttentionHostSnapshot(
      generation: current.generation,
      revision: current.revision,
      presentation: presentation ?? current.presentation,
      bubbleScale: current.bubbleScale,
      appInForeground: expectedFallbackEpoch == null
          ? current.appInForeground
          : false,
      activeServerId: current.activeServerId,
      items: items ?? current.items,
      fullResynchronization: current.fullResynchronization,
      producer: current.producer,
      activeSpeechSnapshotId: _androidReadAloudService?.activeMessageId,
    );
    if (expectedFallbackEpoch != null) {
      final applied =
          await _androidServiceChannel.invokeMethod<bool>(
            'applyFallbackState',
            next.toJson(),
          ) ??
          false;
      final latest = _snapshot;
      if (!applied ||
          _androidFallbackEpoch != expectedFallbackEpoch ||
          latest?.generation != current.generation ||
          latest?.revision != current.revision) {
        return;
      }
      if (mounted) setState(() => _snapshot = next);
      return;
    }
    final applied =
        await _androidServiceChannel.invokeMethod<bool>(
          'applyLocalState',
          next.toJson(),
        ) ??
        false;
    final latest = _snapshot;
    if (applied &&
        mounted &&
        latest?.generation == current.generation &&
        latest?.revision == current.revision) {
      setState(() => _snapshot = next);
    }
  }

  Future<void> _persistAndroidPresentation(
    SessionAttentionPresentation presentation,
  ) async {
    await _reloadAndroidSettings();
    _androidSettings = _androidSettings.copyWith(
      sessionAttentionPresentation: presentation,
    );
    final preferences = await SharedPreferences.getInstance();
    await preferences.reload();
    await preferences.setString(
      AppConstants.sessionAttentionPresentationOverrideKey,
      presentation.name,
    );
  }

  Future<void> _runAndroidFallbackTick({bool forceReconcile = false}) async {
    if (forceReconcile) _androidFallbackReconcilePending = true;
    if (_androidFallbackInFlight) return;
    final reconcile = _androidFallbackReconcilePending;
    _androidFallbackReconcilePending = false;
    _androidFallbackInFlight = true;
    try {
      await _runAndroidFallbackTickOnce(forceReconcile: reconcile);
    } finally {
      _androidFallbackInFlight = false;
      if (_androidFallbackReconcilePending) {
        unawaited(_runAndroidFallbackTick(forceReconcile: true));
      }
    }
  }

  void _scheduleAndroidFallbackReconcile() {
    final now = DateTime.now();
    final started = _androidFallbackSignalWindowStarted ??= now;
    final remaining = const Duration(seconds: 5) - now.difference(started);
    final delay = remaining <= Duration.zero
        ? Duration.zero
        : remaining < const Duration(seconds: 2)
        ? remaining
        : const Duration(seconds: 2);
    _androidFallbackSignalTimer?.cancel();
    _androidFallbackSignalTimer = Timer(delay, () {
      _androidFallbackSignalTimer = null;
      _androidFallbackSignalWindowStarted = null;
      unawaited(_runAndroidFallbackTick(forceReconcile: true));
    });
  }

  Future<void> _runAndroidFallbackTickOnce({
    required bool forceReconcile,
  }) async {
    await _reloadAndroidSettings();
    final store = _androidStore;
    if (store == null ||
        _androidSettings.sessionAttentionPresentation ==
            SessionAttentionPresentation.off) {
      await _stopAndroidFallbackNetwork();
      return;
    }
    final mainAlive =
        await _androidServiceChannel.invokeMethod<bool>(
          'isMainProducerAlive',
        ) ??
        false;
    if (mainAlive) {
      await _stopAndroidFallbackNetwork();
      return;
    }
    final preferences = await SharedPreferences.getInstance();
    await preferences.reload();
    final activeServerId =
        preferences.getString(AppConstants.activeServerIdKey)?.trim() ?? '';
    if (activeServerId.isEmpty) {
      await _stopAndroidFallbackNetwork();
      return;
    }
    if (shouldDisableBackgroundNetworkForDataSaver(
      settings: _androidSettings,
      isCellularTransport:
          CellularDataSaverService.readPersistedTransport(preferences) ==
          DataSaverTransport.cellular,
    )) {
      await _stopAndroidFallbackNetwork();
      _androidBusyStarted.clear();
      _androidPreviousStatus.clear();
      final current = (await store.read()).payload.items
          .where((item) => item.identity.serverId == activeServerId)
          .map(
            (item) => item.withTransport(
              capability:
                  SessionAttentionTransportCapability.backgroundPlainOrBasic,
              reason: SessionAttentionPauseReason.cellularDataSaver,
            ),
          )
          .toList(growable: false);
      await _applyAndroidLocalState(
        items: current,
        expectedFallbackEpoch: _androidFallbackEpoch,
        expectedServerId: activeServerId,
      );
      return;
    }
    final profile = _activeAndroidProfile(preferences);
    if (profile == null) {
      await _stopAndroidFallbackNetwork();
      return;
    }
    if (profile['oauthEnabled'] == true ||
        profile['tailscaleEnabled'] == true) {
      await _stopAndroidFallbackNetwork();
      final reason = profile['oauthEnabled'] == true
          ? SessionAttentionPauseReason.oauthReopenRequired
          : SessionAttentionPauseReason.tailscaleReopenRequired;
      final current = (await store.read()).payload.items
          .where((item) => item.identity.serverId == activeServerId)
          .map(
            (item) => item.withTransport(
              capability: SessionAttentionTransportCapability.reopenRequired,
              reason: reason,
            ),
          )
          .toList(growable: false);
      await _applyAndroidLocalState(
        items: current,
        expectedFallbackEpoch: _androidFallbackEpoch,
        expectedServerId: activeServerId,
      );
      return;
    }
    final serverId = profile['id']?.toString().trim() ?? '';
    final baseUrl = profile['url']?.toString().trim() ?? '';
    if (serverId.isEmpty || baseUrl.isEmpty) {
      await _stopAndroidFallbackNetwork();
      return;
    }
    final scopeKey = _androidFallbackScopeForProfile(profile);
    final fallbackEpoch = await _prepareAndroidFallbackScope(scopeKey);
    if (!forceReconcile &&
        _androidFallbackSseSubscription != null &&
        _androidFallbackSseHealthy) {
      return;
    }
    try {
      final headers = <String, Object>{'Content-Type': 'application/json'};
      if (profile['basicAuthEnabled'] == true) {
        const secure = FlutterSecureStorage();
        final encodedId = Uri.encodeComponent(serverId);
        final username = await secure.read(
          key:
              '${AppConstants.secureStorageNamespace}::${AppConstants.secureServerProfileBasicAuthUsernameKey}::$encodedId',
        );
        final password = await secure.read(
          key:
              '${AppConstants.secureStorageNamespace}::${AppConstants.secureServerProfileBasicAuthPasswordKey}::$encodedId',
        );
        if (username?.isNotEmpty == true && password?.isNotEmpty == true) {
          headers['Authorization'] =
              'Basic ${base64Encode(utf8.encode('$username:$password'))}';
        }
      }
      final dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          headers: headers,
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 12),
          sendTimeout: const Duration(seconds: 12),
        ),
      );
      final remoteDataSource = ChatRemoteDataSourceImpl(dio: dio);
      _androidFallbackSseSubscription ??= remoteDataSource
          .subscribeGlobalEvents(
            onConnected: () {
              if (_androidFallbackEpoch == fallbackEpoch &&
                  _androidFallbackScopeKey == scopeKey) {
                _androidFallbackSseHealthy = true;
              }
            },
            onDisconnected: () {
              if (_androidFallbackEpoch == fallbackEpoch &&
                  _androidFallbackScopeKey == scopeKey) {
                _androidFallbackSseHealthy = false;
              }
            },
          )
          .listen(
            (event) {
              if (_androidFallbackEpoch != fallbackEpoch ||
                  _androidFallbackScopeKey != scopeKey) {
                return;
              }
              final sessionId =
                  event.properties['sessionID']?.toString() ??
                  event.properties['sessionId']?.toString() ??
                  '';
              if (sessionId.isNotEmpty) {
                if (event.type == 'session.error') {
                  _androidErrorSessions.add(sessionId);
                } else if (event.type == 'session.idle') {
                  _androidErrorSessions.remove(sessionId);
                }
              }
              _scheduleAndroidFallbackReconcile();
            },
            onError: (_) {
              if (_androidFallbackEpoch != fallbackEpoch ||
                  _androidFallbackScopeKey != scopeKey) {
                return;
              }
              _androidFallbackSseSubscription?.cancel();
              _androidFallbackSseSubscription = null;
              _androidFallbackSseHealthy = false;
            },
            onDone: () {
              if (_androidFallbackEpoch == fallbackEpoch &&
                  _androidFallbackScopeKey == scopeKey) {
                _androidFallbackSseSubscription = null;
                _androidFallbackSseHealthy = false;
              }
            },
          );
      final statusResponse = await dio.get<dynamic>('/session/status');
      final sessionResponse = await dio.get<dynamic>('/session');
      if (statusResponse.data is! Map || sessionResponse.data is! List) return;
      final statusById = <String, String>{};
      (statusResponse.data as Map).forEach((key, value) {
        if (value is Map) {
          statusById[key.toString()] = value['type']?.toString() ?? 'idle';
        }
      });
      final allSessions = (sessionResponse.data as List)
          .whereType<Map>()
          .map(
            (value) =>
                ChatSessionModel.fromJson(Map<String, dynamic>.from(value)),
          )
          .toList(growable: false);
      final parentBySessionId = <String, String>{
        for (final session in allSessions)
          if (session.parentId?.trim().isNotEmpty == true)
            session.id: session.parentId!.trim(),
      };
      String rootFor(String sessionId) {
        var current = sessionId;
        final visited = <String>{};
        while (visited.add(current)) {
          final parent = parentBySessionId[current];
          if (parent == null || parent.isEmpty) return current;
          current = parent;
        }
        return sessionId;
      }

      final sessions = allSessions
          .where(
            (session) =>
                session.parentId?.trim().isNotEmpty != true &&
                (session.time.archived == null || session.time.archived! <= 0),
          )
          .toList(growable: false);
      final activeRootSessionIds = sessions
          .map((session) => session.id)
          .toSet();
      final rawPending = <String>{
        ...await _fetchAndroidPendingSessions(dio, '/permission'),
        ...await _fetchAndroidPendingSessions(dio, '/question'),
      };
      final pending = rawPending.map(rootFor).toSet();
      final errors = _androidErrorSessions.map(rootFor).toSet();
      if (!await _stillOwnAndroidFallback(
        epoch: fallbackEpoch,
        serverId: serverId,
        scopeKey: scopeKey,
      )) {
        await _stopAndroidFallbackNetwork();
        return;
      }
      final resolver = SessionAttentionCompletionResolver(
        getChatMessages: GetChatMessages(
          ChatRepositoryImpl(remoteDataSource: remoteDataSource),
        ),
        snapshotStore: store,
      );
      final now = DateTime.now();
      final lastMainHeartbeatEpochMs = preferences.getInt(
        AppConstants.sessionAttentionMainHeartbeatEpochMsKey,
      );
      final durableBeforeTick = (await store.read()).payload.items
          .where(
            (item) =>
                item.identity.serverId == serverId &&
                activeRootSessionIds.contains(item.identity.rootSessionId),
          )
          .toList(growable: false);
      final durableBySessionId = <String, SessionAttentionItem>{
        for (final item in durableBeforeTick) item.identity.rootSessionId: item,
      };
      final live = <SessionAttentionItem>[];
      for (final session in sessions) {
        final sessionId = session.id.trim();
        final directory = session.directory?.trim() ?? '';
        if (sessionId.isEmpty || directory.isEmpty) continue;
        final status = statusById[sessionId] ?? 'idle';
        final previous = _androidPreviousStatus[sessionId];
        final working = status == 'busy' || status == 'retry';
        if (working) {
          _androidBusyStarted.putIfAbsent(sessionId, () => now);
        } else if (shouldResolveFallbackCompletion(
          previousStatus: previous,
          sessionUpdatedAtEpochMs: session.time.updated,
          lastMainHeartbeatEpochMs: lastMainHeartbeatEpochMs,
          nowEpochMs: now.millisecondsSinceEpoch,
          durableCompletedAtEpochMs:
              durableBySessionId[sessionId]?.completedAtEpochMs ?? 0,
        )) {
          await resolver.resolve(
            identity: SessionAttentionIdentity(
              serverId: serverId,
              directory: directory,
              rootSessionId: sessionId,
            ),
            title: session.title ?? sessionId,
            projectLabel: session.workspaceId ?? directory,
            completedAt: now,
            transportCapability:
                SessionAttentionTransportCapability.backgroundPlainOrBasic,
            isStillValid: () => _stillOwnAndroidFallback(
              epoch: fallbackEpoch,
              serverId: serverId,
              scopeKey: scopeKey,
            ),
          );
          _androidBusyStarted.remove(sessionId);
        }
        if (!working &&
            !pending.contains(sessionId) &&
            !errors.contains(sessionId)) {
          continue;
        }
        final started = _androidBusyStarted[sessionId] ?? now;
        final identity = SessionAttentionIdentity(
          serverId: serverId,
          directory: directory,
          rootSessionId: sessionId,
        );
        final kind = errors.contains(sessionId)
            ? RootSessionAttentionKind.error
            : pending.contains(sessionId)
            ? RootSessionAttentionKind.pendingInteraction
            : now.difference(started) >= const Duration(minutes: 5)
            ? RootSessionAttentionKind.delayed
            : RootSessionAttentionKind.active;
        final observedAtEpochMs = session.time.updated > 0
            ? session.time.updated
            : session.time.created;
        final contentDigest = sessionAttentionLiveDigest(
          kind,
          observedAtEpochMs,
        );
        live.add(
          SessionAttentionItem(
            schemaVersion: SessionAttentionItem.currentSchemaVersion,
            revision: now.millisecondsSinceEpoch,
            identity: identity,
            title: session.title ?? sessionId,
            projectLabel: session.workspaceId ?? directory,
            kind: kind,
            startedAtEpochMs: started.millisecondsSinceEpoch,
            lastObservedAtEpochMs: now.millisecondsSinceEpoch,
            observableBusyElapsedMs: now.difference(started).inMilliseconds,
            displayText: '',
            speechText: '',
            displayTruncated: false,
            speechTruncated: false,
            opened: false,
            dismissed: false,
            transportCapability:
                SessionAttentionTransportCapability.backgroundPlainOrBasic,
            contentDigest: contentDigest,
          ),
        );
      }
      _androidPreviousStatus
        ..clear()
        ..addAll(statusById);
      if (!await _stillOwnAndroidFallback(
        epoch: fallbackEpoch,
        serverId: serverId,
        scopeKey: scopeKey,
      )) {
        await _stopAndroidFallbackNetwork();
        return;
      }
      final payload = (await store.read()).payload;
      final durable = payload.items.where(
        (item) =>
            item.identity.serverId == serverId &&
            activeRootSessionIds.contains(item.identity.rootSessionId),
      );
      final merged = <SessionAttentionIdentity, SessionAttentionItem>{
        for (final item in durable) item.identity: item,
      };
      for (final item in live) {
        if (payload.dismissalTombstones.contains(
          '${item.identity.key}::${item.contentDigest}',
        )) {
          continue;
        }
        final current = merged[item.identity];
        if (current == null ||
            rootSessionAttentionPriority(item.kind) >
                rootSessionAttentionPriority(current.kind)) {
          merged[item.identity] = item;
        }
      }
      await _applyAndroidLocalState(
        items: merged.values.toList(growable: false),
        expectedFallbackEpoch: fallbackEpoch,
        expectedServerId: serverId,
      );
    } catch (_) {
      _androidBusyStarted.clear();
      _androidPreviousStatus.clear();
      // Preserve the last encrypted snapshot and retry on the next bounded tick.
    }
  }

  Future<int> _prepareAndroidFallbackScope(String scopeKey) async {
    if (_androidFallbackScopeKey == scopeKey) return _androidFallbackEpoch;
    _androidFallbackEpoch += 1;
    _androidFallbackSignalTimer?.cancel();
    _androidFallbackSignalTimer = null;
    _androidFallbackSignalWindowStarted = null;
    _androidFallbackSseHealthy = false;
    await _androidFallbackSseSubscription?.cancel();
    _androidFallbackSseSubscription = null;
    _androidFallbackScopeKey = scopeKey;
    _resetAndroidFallbackObservationState();
    return _androidFallbackEpoch;
  }

  Future<bool> _stillOwnAndroidFallback({
    required int epoch,
    required String serverId,
    required String scopeKey,
  }) async {
    if (_androidFallbackEpoch != epoch ||
        _androidFallbackScopeKey != scopeKey) {
      return false;
    }
    await _reloadAndroidSettings();
    if (_androidSettings.sessionAttentionPresentation ==
        SessionAttentionPresentation.off) {
      return false;
    }
    final preferences = await SharedPreferences.getInstance();
    await preferences.reload();
    if (preferences.getString(AppConstants.activeServerIdKey)?.trim() !=
        serverId) {
      return false;
    }
    final profile = _activeAndroidProfile(preferences);
    if (profile == null ||
        profile['oauthEnabled'] == true ||
        profile['tailscaleEnabled'] == true ||
        _androidFallbackScopeForProfile(profile) != scopeKey) {
      return false;
    }
    if (shouldDisableBackgroundNetworkForDataSaver(
      settings: _androidSettings,
      isCellularTransport:
          CellularDataSaverService.readPersistedTransport(preferences) ==
          DataSaverTransport.cellular,
    )) {
      return false;
    }
    final mainAlive =
        await _androidServiceChannel.invokeMethod<bool>(
          'isMainProducerAlive',
        ) ??
        false;
    return !mainAlive &&
        _androidFallbackEpoch == epoch &&
        _androidFallbackScopeKey == scopeKey;
  }

  String _androidFallbackScopeForProfile(Map<String, dynamic> profile) {
    return <String>[
      profile['id']?.toString().trim() ?? '',
      profile['url']?.toString().trim() ?? '',
      profile['updatedAt']?.toString() ?? '',
      profile['basicAuthEnabled'] == true ? 'basic' : 'plain',
    ].join('|');
  }

  Future<void> _stopAndroidFallbackNetwork() async {
    _androidFallbackEpoch += 1;
    _androidFallbackReconcilePending = false;
    _androidFallbackSignalTimer?.cancel();
    _androidFallbackSignalTimer = null;
    _androidFallbackSignalWindowStarted = null;
    _androidFallbackSseHealthy = false;
    await _androidFallbackSseSubscription?.cancel();
    _androidFallbackSseSubscription = null;
    _androidFallbackScopeKey = null;
    _resetAndroidFallbackObservationState();
  }

  void _resetAndroidFallbackObservationState() {
    _androidBusyStarted.clear();
    _androidPreviousStatus.clear();
    _androidErrorSessions.clear();
  }

  Future<void> _reloadAndroidSettings() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.reload();
    final raw = preferences.getString(AppConstants.experienceSettingsKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        _androidSettings = ExperienceSettings.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map),
        );
      } catch (_) {
        // Keep the last valid settings snapshot.
      }
    }
    final override = preferences.getString(
      AppConstants.sessionAttentionPresentationOverrideKey,
    );
    if (override != null) {
      for (final value in SessionAttentionPresentation.values) {
        if (value.name == override) {
          _androidSettings = _androidSettings.copyWith(
            sessionAttentionPresentation: value,
          );
          break;
        }
      }
    }
    _updateAndroidLocale();
  }

  void _updateAndroidLocale() {
    _androidLocale = resolveBackgroundAlertLocale(_androidSettings.localeCode);
    L10nBridge.update(lookupAppLocalizations(_androidLocale));
    if (mounted) setState(() {});
  }

  Map<String, dynamic>? _activeAndroidProfile(SharedPreferences preferences) {
    final raw = preferences.getString(AppConstants.serverProfilesKey);
    final activeId = preferences.getString(AppConstants.activeServerIdKey);
    if (raw == null || activeId == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      for (final value in decoded.whereType<Map>()) {
        final profile = Map<String, dynamic>.from(value);
        if (profile['id'] == activeId) return profile;
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  Future<Set<String>> _fetchAndroidPendingSessions(Dio dio, String path) async {
    try {
      final response = await dio.get<dynamic>(path);
      if (response.data is! List) return const <String>{};
      return (response.data as List)
          .whereType<Map>()
          .map(
            (value) =>
                value['sessionID']?.toString() ??
                value['sessionId']?.toString() ??
                '',
          )
          .where((value) => value.isNotEmpty)
          .toSet();
    } catch (_) {
      return const <String>{};
    }
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    if (call.method == 'persistPresentationOff') {
      await _stopAndroidFallbackNetwork();
      await _androidReadAloudService?.stop();
      await _persistAndroidPresentation(SessionAttentionPresentation.off);
      return true;
    }
    if (call.method != 'applySnapshot' &&
        call.method != 'sessionAttention.applySnapshot') {
      return null;
    }
    final raw = call.arguments;
    if (raw is! Map) return false;
    late final SessionAttentionHostSnapshot next;
    try {
      next = SessionAttentionHostSnapshot.fromJson(
        Map<String, dynamic>.from(raw),
      );
    } on FormatException {
      return false;
    }
    if (!next.supersedes(_snapshot)) return false;
    if (next.producer == 'main') {
      await _stopAndroidFallbackNetwork();
    }
    if (mounted) {
      setState(() => _snapshot = next);
    }
    return true;
  }

  Future<void> _queueAndroidStateMutation(Future<void> Function() mutation) {
    final operation = _androidCommandTail.then((_) => mutation());
    _androidCommandTail = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  Future<void> _command(String action, [SessionAttentionItem? item]) async {
    if (item != null) {
      final controller = _androidController;
      if (controller != null && action == 'read') {
        await _reloadAndroidSettings();
        await controller.readOrStop(item);
        await _queueAndroidStateMutation(_applyAndroidLocalState);
        return;
      }
      if (controller != null && action == 'dismiss') {
        await _queueAndroidStateMutation(() async {
          await controller.dismiss(item);
          final remaining = (_snapshot?.items ?? const <SessionAttentionItem>[])
              .where((candidate) => candidate.snapshotId != item.snapshotId)
              .toList(growable: false);
          await _applyAndroidLocalState(items: remaining);
        });
        return;
      }
    }
    if (action == 'expand' || action == 'collapse') {
      final presentation = action == 'expand'
          ? SessionAttentionPresentation.panel
          : SessionAttentionPresentation.bubble;
      await _queueAndroidStateMutation(() async {
        await _persistAndroidPresentation(presentation);
        await _applyAndroidLocalState(presentation: presentation);
      });
      return;
    }
    if (action == 'stop') {
      await _androidReadAloudService?.stop();
      await _persistAndroidPresentation(SessionAttentionPresentation.off);
      await _androidServiceChannel.invokeMethod<void>('stopLocal');
      return;
    }
    final payload = <String, dynamic>{
      'action': action,
      if (item != null) ...<String, dynamic>{
        ...item.identity.toJson(),
        'snapshotId': item.snapshotId,
      },
    };
    await _androidServiceChannel.invokeMethod<void>('command', payload);
  }

  @override
  void dispose() {
    _androidServiceChannel.setMethodCallHandler(null);
    _androidFallbackTimer?.cancel();
    _androidFallbackSignalTimer?.cancel();
    _androidFallbackSseSubscription?.cancel();
    _androidDataSaverService?.dispose();
    _androidController
      ?..removeListener(_handleAndroidControllerChanged)
      ..dispose();
    _androidReadAloudService?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    final expanded = snapshot?.presentation.name == 'panel';
    final items = snapshot?.items ?? const <SessionAttentionItem>[];
    final activeSpeechSnapshotId = _androidController?.activeSpeechSnapshotId;
    final l10n = L10nBridge.current;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: _androidLocale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(colorSchemeSeed: const Color(0xff6750a4)),
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: expanded
                ? EdgeInsets.zero
                : const EdgeInsetsDirectional.only(end: 8, bottom: 8),
            child: SessionAttentionOverlay(
              items: items,
              expanded: expanded,
              semanticLabel:
                  l10n?.sessionAttentionSemanticLabel(items.length) ??
                  '${items.length} sessions need attention',
              openLabel: l10n?.notificationActionOpen ?? 'Open',
              expandLabel: l10n?.chatExpandGroup ?? 'Expand group',
              collapseLabel: l10n?.chatCollapseGroup ?? 'Collapse group',
              readLabel: l10n?.msgReadAloud ?? 'Read aloud',
              stopReadingLabel: l10n?.msgStopReadAloud ?? 'Stop reading',
              dismissLabel: l10n?.settingsAboutDismiss ?? 'Dismiss',
              stopOverlayLabel:
                  l10n?.settingsSessionAttentionStop ??
                  'Stop session attention',
              activeSpeechSnapshotId: activeSpeechSnapshotId,
              onOpen: (item) => _command('open', item),
              onRead: (item) => _command('read', item),
              onDismiss: (item) => _command('dismiss', item),
              onToggleExpanded: () =>
                  _command(expanded ? 'collapse' : 'expand'),
              onStopOverlay: () => _command('stop'),
            ),
          ),
        ),
      ),
    );
  }
}
