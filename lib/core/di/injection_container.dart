import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/datasources/app_local_datasource.dart';
import '../../data/datasources/app_remote_datasource.dart';
import '../../data/datasources/chat_remote_datasource.dart';
import '../../data/datasources/project_remote_datasource.dart';
import '../../data/datasources/quota_remote_datasource.dart';
import '../../data/datasources/terminal_remote_datasource.dart';
import '../../data/repositories/app_repository_impl.dart';
import '../../data/repositories/chat_repository_impl.dart';
import '../../data/repositories/project_repository_impl.dart';
import '../../data/session_attention/session_attention_snapshot_store.dart';
import '../../domain/entities/experience_settings.dart';
import '../../domain/entities/session_attention_overlay/session_attention_models.dart';
import '../../domain/repositories/app_repository.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../domain/repositories/project_repository.dart';
import '../../domain/usecases/abort_chat_session.dart';
import '../../domain/usecases/check_connection.dart';
import '../../domain/usecases/create_chat_session.dart';
import '../../domain/usecases/delete_chat_session.dart';
import '../../domain/usecases/fork_chat_session.dart';
import '../../domain/usecases/get_agents.dart';
import '../../domain/usecases/get_app_info.dart';
import '../../domain/usecases/get_chat_message.dart';
import '../../domain/usecases/get_chat_messages.dart';
import '../../domain/usecases/get_chat_sessions.dart';
import '../../domain/usecases/get_providers.dart';
import '../../domain/usecases/get_session_children.dart';
import '../../domain/usecases/get_session_diff.dart';
import '../../domain/usecases/get_session_status.dart';
import '../../domain/usecases/get_session_todo.dart';
import '../../domain/usecases/list_pending_permissions.dart';
import '../../domain/usecases/list_pending_questions.dart';
import '../../domain/usecases/reject_question.dart';
import '../../domain/usecases/reply_permission.dart';
import '../../domain/usecases/reply_question.dart';
import '../../domain/usecases/revert_chat_message.dart';
import '../../domain/usecases/send_chat_message.dart';
import '../../domain/usecases/share_chat_session.dart';
import '../../domain/usecases/summarize_chat_session.dart';
import '../../domain/usecases/unrevert_chat_messages.dart';
import '../../domain/usecases/unshare_chat_session.dart';
import '../../domain/usecases/update_chat_session.dart';
import '../../domain/usecases/update_server_config.dart';
import '../../domain/usecases/watch_chat_events.dart';
import '../../domain/usecases/watch_global_chat_events.dart';
import '../../presentation/providers/app_provider.dart';
import '../../presentation/providers/chat_provider.dart';
import '../../presentation/providers/locale_provider.dart';
import '../../presentation/providers/project_icon_provider.dart';
import '../../presentation/providers/project_provider.dart';
import '../../presentation/providers/quota_provider.dart';
import '../../presentation/providers/settings_provider.dart';
import '../../presentation/services/cellular_data_saver_service.dart';
import '../../presentation/services/chat_title_generator.dart';
import '../../presentation/services/event_feedback_dispatcher.dart';
import '../../presentation/services/moonshine_model_manager.dart';
import '../../presentation/services/notification_service.dart';
import '../../presentation/services/parakeet_model_manager.dart';
import '../../presentation/services/project_icon_discovery_service.dart';
import '../../presentation/services/project_icon_store.dart';
import '../../presentation/services/read_aloud_service.dart';
import '../../presentation/services/sensevoice_model_manager.dart';
import '../../presentation/services/session_attention/session_attention_completion_resolver.dart';
import '../../presentation/services/session_attention/session_attention_coordinator.dart';
import '../../presentation/services/session_attention/session_attention_host_protocol.dart';
import '../../presentation/services/session_attention/session_attention_host_service.dart';
import '../../presentation/services/session_tab_icon_override_store.dart';
import '../../presentation/services/sherpa_model_manager.dart';
import '../../presentation/services/sound_service.dart';
import '../../presentation/services/speech_input_service_moonshine.dart';
import '../../presentation/services/speech_input_service_parakeet.dart';
import '../../presentation/services/speech_input_service_sensevoice.dart';
import '../../presentation/services/speech_input_service_sherpa.dart';
import '../../presentation/services/speech_input_service_stt.dart';
import '../../presentation/services/tts/edge_experimental_tts_backend.dart';
import '../../presentation/services/tts/native_tts_backend.dart';
import '../../presentation/services/tts/openai_compatible_tts_backend.dart';
import '../../presentation/services/tts/tts_backend.dart';
import '../../presentation/services/update_check_service.dart';
import '../../presentation/services/workspace_file_operations_service.dart';
import '../auth/tts_api_key_storage.dart';
import '../constants/app_constants.dart';
import '../network/dio_client.dart';
import '../tailscale/tailscale_service.dart';

final sl = GetIt.instance;

/// Initialize dependency injection
Future<void> init() async {
  // External dependencies
  final sharedPreferences = await SharedPreferences.getInstance();
  sl.registerLazySingleton(() => sharedPreferences);

  // Network
  sl.registerLazySingleton(DioClient.new);

  // Data sources
  sl.registerLazySingleton<AppRemoteDataSource>(
    () => AppRemoteDataSourceImpl(dio: sl<DioClient>().dio),
  );

  sl.registerLazySingleton<AppLocalDataSource>(
    () => AppLocalDataSourceImpl(sharedPreferences: sl()),
  );

  sl.registerLazySingleton<ChatRemoteDataSource>(
    () => ChatRemoteDataSourceImpl(
      dio: sl<DioClient>().dio,
      sseDio: sl<DioClient>().sseDio,
    ),
  );

  sl.registerLazySingleton<ProjectRemoteDataSource>(
    () => ProjectRemoteDataSourceImpl(dio: sl<DioClient>().dio),
  );

  sl.registerLazySingleton<QuotaRemoteDataSource>(
    () => QuotaRemoteDataSourceImpl(dio: sl<DioClient>().dio),
  );

  sl.registerLazySingleton<WorkspaceFileOperationsService>(
    () => WorkspaceFileOperationsServiceImpl(dio: sl<DioClient>().dio),
  );

  sl.registerLazySingleton<TerminalRemoteDataSource>(
    () => TerminalRemoteDataSourceImpl(dio: sl<DioClient>().dio),
  );

  sl.registerLazySingleton(NotificationService.new);
  sl.registerLazySingleton(SoundService.new);
  sl.registerLazySingleton(TtsApiKeyStorage.new);
  sl.registerLazySingleton(SessionAttentionSnapshotStore.new);
  final sessionAttentionHostGeneration =
      'main-${DateTime.now().microsecondsSinceEpoch}';
  var sessionAttentionHostRevision = 0;
  var sessionAttentionPublishTail = Future<void>.value();
  SessionAttentionAggregate? liveAttention;
  var sessionAttentionAppInForeground = true;

  Future<void> publishSessionAttention() async {
    final revision = ++sessionAttentionHostRevision;
    final liveSnapshot = liveAttention;
    final publication = sessionAttentionPublishTail.then((_) async {
      final host = sl<SessionAttentionHostService>();
      if (host is! SessionAttentionSnapshotHostService ||
          !sl.isRegistered<SettingsProvider>()) {
        return;
      }
      final preferences = sl<SharedPreferences>();
      await preferences.reload();
      final activeServerId = await sl<AppLocalDataSource>().getActiveServerId();
      final durableSnapshot =
          (await sl<SessionAttentionSnapshotStore>().read()).payload;
      var presentation =
          sl<SettingsProvider>().settings.sessionAttentionPresentation;
      var bubbleSize =
          sl<SettingsProvider>().settings.sessionAttentionBubbleSize;
      final persistedSettings = await sl<AppLocalDataSource>()
          .getExperienceSettingsJson();
      if (persistedSettings != null && persistedSettings.isNotEmpty) {
        try {
          final restored = ExperienceSettings.fromJson(
            Map<String, dynamic>.from(jsonDecode(persistedSettings) as Map),
          );
          presentation = restored.sessionAttentionPresentation;
          bubbleSize = restored.sessionAttentionBubbleSize;
        } catch (_) {
          // Keep the initialized provider value if persisted data is malformed.
        }
      }
      final presentationOverride = preferences.getString(
        AppConstants.sessionAttentionPresentationOverrideKey,
      );
      if (presentationOverride != null) {
        for (final value in SessionAttentionPresentation.values) {
          if (value.name == presentationOverride) {
            presentation = value;
            break;
          }
        }
      }
      await preferences.setInt(
        AppConstants.sessionAttentionMainHeartbeatEpochMsKey,
        DateTime.now().millisecondsSinceEpoch,
      );
      final byIdentity = <SessionAttentionIdentity, SessionAttentionItem>{
        for (final item in durableSnapshot.items)
          if (item.identity.serverId == activeServerId) item.identity: item,
      };
      for (final candidate
          in liveSnapshot?.candidates ??
              const <RootSessionAttentionCandidate>[]) {
        final normalizedIdentity = candidate.identity.normalized();
        if (normalizedIdentity.serverId != activeServerId) continue;
        final liveDigest = sessionAttentionLiveDigest(
          candidate.kind,
          candidate.observedAt.millisecondsSinceEpoch,
        );
        if (durableSnapshot.dismissalTombstones.contains(
          '${normalizedIdentity.key}::$liveDigest',
        )) {
          continue;
        }
        final current = byIdentity[normalizedIdentity];
        if (candidate.kind == RootSessionAttentionKind.completed &&
            current == null) {
          continue;
        }
        if (current != null &&
            rootSessionAttentionPriority(current.kind) >= candidate.priority) {
          continue;
        }
        final observedEpoch = candidate.observedAt.millisecondsSinceEpoch;
        byIdentity[normalizedIdentity] = SessionAttentionItem(
          schemaVersion: SessionAttentionItem.currentSchemaVersion,
          revision: liveSnapshot?.revision ?? revision,
          identity: normalizedIdentity,
          title: candidate.title,
          projectLabel: candidate.projectLabel,
          kind: candidate.kind,
          startedAtEpochMs: observedEpoch,
          lastObservedAtEpochMs: observedEpoch,
          observableBusyElapsedMs:
              candidate.observableBusyElapsed.inMilliseconds,
          assistantMessageId: candidate.completionMessageId,
          displayText: '',
          speechText: '',
          displayTruncated: false,
          speechTruncated: false,
          completedAtEpochMs:
              candidate.kind == RootSessionAttentionKind.completed
              ? observedEpoch
              : null,
          opened: false,
          dismissed: false,
          transportCapability: SessionAttentionTransportCapability.live,
          pauseReason: candidate.pauseReason,
          contentDigest: liveDigest,
        );
      }
      final items = byIdentity.values.toList(growable: false)
        ..sort((left, right) {
          final priority = rootSessionAttentionPriority(
            right.kind,
          ).compareTo(rootSessionAttentionPriority(left.kind));
          return priority != 0
              ? priority
              : right.lastObservedAtEpochMs.compareTo(
                  left.lastObservedAtEpochMs,
                );
        });
      await (host as SessionAttentionSnapshotHostService).publishSnapshot(
        SessionAttentionHostSnapshot(
          generation: sessionAttentionHostGeneration,
          revision: revision,
          presentation: presentation,
          bubbleScale: sessionAttentionBubbleScale(bubbleSize),
          appInForeground: sessionAttentionAppInForeground,
          activeServerId: activeServerId ?? '',
          items: items,
          fullResynchronization: revision == 1,
          activeSpeechSnapshotId: sl.isRegistered<ReadAloudService>()
              ? sl<ReadAloudService>().activeMessageId
              : null,
        ),
      );
    });
    sessionAttentionPublishTail = publication.then<void>(
      (_) {},
      onError: (_, _) {},
    );
    await publication;
  }

  sl.registerLazySingleton(
    () => SessionAttentionCompletionResolver(
      getChatMessages: sl(),
      snapshotStore: sl(),
      onSnapshotChanged: (_) => publishSessionAttention(),
    ),
  );
  sl.registerLazySingleton(() {
    final service = ReadAloudService(
      apiKeyStorage: sl<TtsApiKeyStorage>(),
      backends: <ReadAloudProvider, TtsBackend>{
        ReadAloudProvider.native: NativeTtsBackend(),
        ReadAloudProvider.edgeExperimental: EdgeExperimentalTtsBackend(),
        ReadAloudProvider.openAiCompatible: OpenAiCompatibleTtsBackend(),
      },
    );
    String? lastActiveSnapshotId;
    service.addListener(() {
      final next = service.activeMessageId;
      if (next == lastActiveSnapshotId) return;
      lastActiveSnapshotId = next;
      unawaited(sl<SessionAttentionCompletionResolver>().publishCurrent());
    });
    return service;
  }, dispose: (service) => service.dispose());
  sl.registerLazySingleton(TailscaleService.new);
  sl.registerLazySingleton<SessionAttentionHostService>(
    createSessionAttentionHostService,
  );
  sl.registerLazySingleton(
    () => SessionAttentionCoordinator(cellularDataSaverService: sl()),
    dispose: (service) => service.dispose(),
  );
  sl.registerLazySingleton(
    () => CellularDataSaverService(sharedPreferences: sl()),
  );
  // SherpaModelManager: registered on all platforms; stub on web.
  // On IO platforms it manages on-device Kroko model download and storage.
  sl.registerLazySingleton(SherpaModelManager.new);
  sl.registerLazySingleton(MoonshineModelManager.new);
  sl.registerLazySingleton(ParakeetModelManager.new);
  sl.registerLazySingleton(SenseVoiceModelManager.new);

  // Speech input backends are registered independently and selected at runtime
  // from user settings (Native/speech_to_text or Sherpa on-device).
  sl.registerLazySingleton(SttSpeechInputService.new);
  if (!kIsWeb) {
    sl.registerLazySingleton(
      () => SherpaSpeechInputService(sl<SherpaModelManager>()),
    );
    sl.registerLazySingleton(
      () => MoonshineSpeechInputService(sl<MoonshineModelManager>()),
    );
    sl.registerLazySingleton(
      () => ParakeetSpeechInputService(sl<ParakeetModelManager>()),
    );
    sl.registerLazySingleton(
      () => SenseVoiceSpeechInputService(sl<SenseVoiceModelManager>()),
    );
  }
  sl.registerLazySingleton<ChatTitleGenerator>(
    () => OpenCodeTitleGenerator(dio: sl<DioClient>().dio),
  );
  sl.registerLazySingleton(UpdateCheckService.new);
  sl.registerLazySingleton(createProjectIconStore);
  sl.registerLazySingleton(
    () => createProjectIconDiscoveryService(dio: sl<DioClient>().dio),
  );
  sl.registerLazySingleton(
    () => SessionTabIconOverrideStore(localDataSource: sl()),
  );

  // Repositories
  sl.registerLazySingleton<AppRepository>(
    () => AppRepositoryImpl(
      remoteDataSource: sl(),
      localDataSource: sl(),
      dioClient: sl(),
    ),
  );

  sl.registerLazySingleton<ChatRepository>(
    () => ChatRepositoryImpl(remoteDataSource: sl()),
  );

  sl.registerLazySingleton<ProjectRepository>(
    () => ProjectRepositoryImpl(remoteDataSource: sl()),
  );

  // Use cases
  sl.registerLazySingleton(() => GetAppInfo(sl()));
  sl.registerLazySingleton(() => CheckConnection(sl()));
  sl.registerLazySingleton(() => UpdateServerConfig(sl()));
  sl.registerLazySingleton(() => AbortChatSession(sl()));
  sl.registerLazySingleton(() => SummarizeChatSession(sl()));
  sl.registerLazySingleton(() => SendChatMessage(sl()));
  sl.registerLazySingleton(() => GetChatSessions(sl()));
  sl.registerLazySingleton(() => CreateChatSession(sl()));
  sl.registerLazySingleton(() => GetChatMessages(sl()));
  sl.registerLazySingleton(() => GetChatMessage(sl()));
  sl.registerLazySingleton(() => GetAgents(sl()));
  sl.registerLazySingleton(() => GetProviders(sl()));
  sl.registerLazySingleton(() => DeleteChatSession(sl()));
  sl.registerLazySingleton(() => UpdateChatSession(sl()));
  sl.registerLazySingleton(() => ShareChatSession(sl()));
  sl.registerLazySingleton(() => UnshareChatSession(sl()));
  sl.registerLazySingleton(() => ForkChatSession(sl()));
  sl.registerLazySingleton(() => GetSessionStatus(sl()));
  sl.registerLazySingleton(() => GetSessionChildren(sl()));
  sl.registerLazySingleton(() => GetSessionTodo(sl()));
  sl.registerLazySingleton(() => GetSessionDiff(sl()));
  sl.registerLazySingleton(() => WatchChatEvents(sl()));
  sl.registerLazySingleton(() => WatchGlobalChatEvents(sl()));
  sl.registerLazySingleton(() => ListPendingPermissions(sl()));
  sl.registerLazySingleton(() => ReplyPermission(sl()));
  sl.registerLazySingleton(() => ListPendingQuestions(sl()));
  sl.registerLazySingleton(() => ReplyQuestion(sl()));
  sl.registerLazySingleton(() => RejectQuestion(sl()));
  sl.registerLazySingleton(() => RevertChatMessage(sl()));
  sl.registerLazySingleton(() => UnrevertChatMessages(sl()));

  // State management
  sl.registerFactory(
    () => AppProvider(
      getAppInfo: sl(),
      checkConnection: sl(),
      localDataSource: sl(),
      dioClient: sl(),
      tailscaleService: sl(),
      cellularDataSaverService: sl(),
      sessionAttentionCompletionResolver: sl(),
      sessionTabIconOverrideStore: sl(),
    ),
  );

  sl.registerFactory(
    () => ChatProvider(
      sendChatMessage: sl(),
      abortChatSession: sl(),
      summarizeChatSession: sl(),
      getChatSessions: sl(),
      createChatSession: sl(),
      getChatMessages: sl(),
      getChatMessage: sl(),
      getAgents: sl(),
      getProviders: sl(),
      deleteChatSession: sl(),
      updateChatSession: sl(),
      shareChatSession: sl(),
      unshareChatSession: sl(),
      forkChatSession: sl(),
      getSessionStatus: sl(),
      getSessionChildren: sl(),
      getSessionTodo: sl(),
      getSessionDiff: sl(),
      watchChatEvents: sl(),
      watchGlobalChatEvents: sl(),
      listPendingPermissions: sl(),
      replyPermission: sl(),
      listPendingQuestions: sl(),
      replyQuestion: sl(),
      rejectQuestion: sl(),
      revertChatMessage: sl(),
      unrevertChatMessages: sl(),
      projectProvider: sl(),
      localDataSource: sl(),
      settingsProvider: sl(),
      dioClient: sl(),
      cellularDataSaverService: sl(),
      sessionAttentionCoordinator: sl(),
      sessionAttentionCompletionResolver: sl(),
      sessionTabIconOverrideStore: sl(),
      sessionAttentionAggregatePublisher: (aggregate) async {
        liveAttention = aggregate;
        await publishSessionAttention();
      },
      sessionAttentionAppForegroundPublisher: (isForeground) async {
        sessionAttentionAppInForeground = isForeground;
        await publishSessionAttention();
      },
      eventFeedbackDispatcher: sl(),
      titleGenerator: sl(),
    ),
  );

  sl.registerLazySingleton<ProjectProvider>(
    () => ProjectProvider(projectRepository: sl(), localDataSource: sl()),
  );

  sl.registerLazySingleton<ProjectIconProvider>(
    () => ProjectIconProvider(store: sl(), discoveryService: sl()),
  );

  sl.registerLazySingleton<SettingsProvider>(
    () => SettingsProvider(
      localDataSource: sl(),
      dioClient: sl(),
      soundService: sl(),
      updateCheckService: sl(),
      cellularDataSaverService: sl(),
      sessionAttentionHostService: sl(),
      sessionAttentionStopTts: sl<ReadAloudService>().stop,
      sessionAttentionRepublish:
          sl<SessionAttentionCompletionResolver>().publishCurrent,
      sessionAttentionPresentationOverrideReader: () async {
        final preferences = sl<SharedPreferences>();
        await preferences.reload();
        final raw = preferences.getString(
          AppConstants.sessionAttentionPresentationOverrideKey,
        );
        if (raw == null) return null;
        for (final value in SessionAttentionPresentation.values) {
          if (value.name == raw) return value;
        }
        return null;
      },
      sessionAttentionPresentationOverrideWriter: (presentation) async {
        final preferences = sl<SharedPreferences>();
        await preferences.reload();
        await preferences.setString(
          AppConstants.sessionAttentionPresentationOverrideKey,
          presentation.name,
        );
      },
      nativeReadAloudAvailabilityProbe: () =>
          sl<ReadAloudService>().isProviderAvailable(ReadAloudProvider.native),
    ),
  );

  sl.registerLazySingleton<LocaleProvider>(
    () => LocaleProvider(settingsProvider: sl()),
  );

  sl.registerFactory(
    () => QuotaProvider(remoteDataSource: sl(), localDataSource: sl()),
  );

  sl.registerLazySingleton<EventFeedbackDispatcher>(
    () => EventFeedbackDispatcher(
      settingsProvider: sl(),
      notificationService: sl(),
      soundService: sl(),
    ),
  );

  // Load local configuration
  await _loadLocalConfig();
}

/// Load local configuration
Future<void> _loadLocalConfig() async {
  final localDataSource = sl<AppLocalDataSource>();
  final dioClient = sl<DioClient>();

  final profilesJson = await localDataSource.getServerProfilesJson();
  final activeServerId = await localDataSource.getActiveServerId();
  var loadedFromProfiles = false;

  if (profilesJson != null && profilesJson.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(profilesJson);
      if (decoded is List) {
        Map<String, dynamic>? activeProfile;
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            if (item['id'] == activeServerId) {
              activeProfile = item;
              break;
            }
            activeProfile ??= item;
          }
        }

        if (activeProfile != null) {
          final url = activeProfile['url'] as String?;
          if (url != null && url.isNotEmpty) {
            dioClient.updateBaseUrl(url);
            loadedFromProfiles = true;
          }
          final basicEnabled =
              activeProfile['basicAuthEnabled'] as bool? ?? false;
          final username = activeProfile['basicAuthUsername'] as String? ?? '';
          final password = activeProfile['basicAuthPassword'] as String? ?? '';
          if (basicEnabled && username.isNotEmpty && password.isNotEmpty) {
            dioClient.setBasicAuth(
              username,
              password,
              origin: dioClient.dio.options.baseUrl,
            );
          } else {
            dioClient.clearAuth();
          }
        }
      }
    } catch (_) {
      // Fallback below.
    }
  }

  if (!loadedFromProfiles) {
    final host = await localDataSource.getServerHost();
    final port = await localDataSource.getServerPort();

    if (host != null && port != null) {
      final baseUrl = 'http://$host:$port';
      dioClient.updateBaseUrl(baseUrl);
    }

    final basicEnabled = await localDataSource.getBasicAuthEnabled();
    if (basicEnabled == true) {
      final username = await localDataSource.getBasicAuthUsername();
      final password = await localDataSource.getBasicAuthPassword();
      if ((username != null && username.isNotEmpty) &&
          (password != null && password.isNotEmpty)) {
        dioClient.setBasicAuth(
          username,
          password,
          origin: dioClient.dio.options.baseUrl,
        );
      }
    } else {
      dioClient.clearAuth();
    }
  }
}
