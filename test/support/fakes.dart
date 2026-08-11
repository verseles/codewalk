import 'dart:async';
import 'dart:convert';

import 'package:codewalk/core/errors/failures.dart';
import 'package:codewalk/data/datasources/app_local_datasource.dart';
import 'package:codewalk/data/datasources/quota_remote_datasource.dart';
import 'package:codewalk/domain/entities/agent.dart';
import 'package:codewalk/domain/entities/app_info.dart';
import 'package:codewalk/domain/entities/chat_message.dart';
import 'package:codewalk/domain/entities/chat_realtime.dart';
import 'package:codewalk/domain/entities/chat_session.dart';
import 'package:codewalk/domain/entities/file_node.dart';
import 'package:codewalk/domain/entities/project.dart';
import 'package:codewalk/domain/entities/provider.dart';
import 'package:codewalk/domain/entities/quota.dart';
import 'package:codewalk/domain/entities/worktree.dart';
import 'package:codewalk/domain/repositories/app_repository.dart';
import 'package:codewalk/domain/repositories/chat_repository.dart';
import 'package:codewalk/domain/repositories/project_repository.dart';
import 'package:codewalk/presentation/services/local_opencode_server_runtime_types.dart';
import 'package:codewalk/presentation/services/workspace_file_operations_service.dart';
import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

class FakeLocalOpencodeServerRuntime implements LocalOpencodeServerRuntime {
  FakeLocalOpencodeServerRuntime({
    this.supported = false,
    this.startResult = const LocalOpencodeServerStartResult(ok: true),
    this.diagnoseResult = const LocalOpencodeEnvironmentReport(
      supported: true,
      platform: 'test',
      opencode: LocalToolStatus(available: false),
      node: LocalToolStatus(available: false),
      npm: LocalToolStatus(available: false),
      bun: LocalToolStatus(available: false),
      wsl: LocalToolStatus(available: false),
      hasNetworkAccess: true,
      installDirectoryWritable: true,
      recommendation: 'test',
    ),
    this.installResult = const LocalOpencodeInstallResult(ok: true),
  });

  bool supported;
  bool running = false;
  LocalOpencodeServerStartResult startResult;
  LocalOpencodeEnvironmentReport diagnoseResult;
  LocalOpencodeInstallResult installResult;
  int startCallCount = 0;
  int stopCallCount = 0;
  int installCallCount = 0;
  int diagnoseCallCount = 0;
  String? lastHost;
  int? lastPort;
  String? lastCommandPath;
  LocalOpencodeInstallMethod? lastInstallMethod;

  final StreamController<String> _stdoutController =
      StreamController<String>.broadcast();
  final StreamController<String> _stderrController =
      StreamController<String>.broadcast();
  final StreamController<int> _exitCodeController =
      StreamController<int>.broadcast();

  @override
  bool get isSupported => supported;

  @override
  bool get isRunning => running;

  @override
  Stream<String> get stdoutLines => _stdoutController.stream;

  @override
  Stream<String> get stderrLines => _stderrController.stream;

  @override
  Stream<int> get exitCodes => _exitCodeController.stream;

  @override
  Future<LocalOpencodeServerStartResult> start({
    required String host,
    required int port,
    String? commandPath,
  }) async {
    startCallCount += 1;
    lastHost = host;
    lastPort = port;
    lastCommandPath = commandPath;
    if (startResult.ok) {
      running = true;
    }
    return startResult;
  }

  @override
  Future<LocalOpencodeEnvironmentReport> diagnose({String? commandPath}) async {
    diagnoseCallCount += 1;
    return diagnoseResult;
  }

  @override
  Future<LocalOpencodeInstallResult> install({
    required LocalOpencodeInstallMethod method,
    void Function(String line)? onLog,
  }) async {
    installCallCount += 1;
    lastInstallMethod = method;
    return installResult;
  }

  @override
  Future<void> stop() async {
    stopCallCount += 1;
    running = false;
  }

  void emitStdout(String line) {
    _stdoutController.add(line);
  }

  void emitStderr(String line) {
    _stderrController.add(line);
  }

  void emitExit(int code) {
    running = false;
    _exitCodeController.add(code);
  }

  @override
  Future<void> dispose() async {
    await _stdoutController.close();
    await _stderrController.close();
    await _exitCodeController.close();
  }
}

class FakeQuotaRemoteDataSource implements QuotaRemoteDataSource {
  FakeQuotaRemoteDataSource({
    List<QuotaProviderResult> results = const <QuotaProviderResult>[],
  }) : _results = results;

  List<QuotaProviderResult> _results;
  int fetchCallCount = 0;
  OpenCodeGoDashboardCredentials? lastOpenCodeGoCredentials;

  set results(List<QuotaProviderResult> value) {
    _results = value;
  }

  @override
  Future<List<QuotaProviderResult>> fetchQuotaResults({
    OpenCodeGoDashboardCredentials? openCodeGoCredentials,
  }) async {
    fetchCallCount += 1;
    lastOpenCodeGoCredentials = openCodeGoCredentials;
    return _results;
  }
}

class InMemoryAppLocalDataSource implements AppLocalDataSource {
  String? serverHost;
  int? serverPort;
  String? serverProfilesJson;
  String? activeServerId;
  String? defaultServerId;
  String? localOpencodeCommand;
  String? dismissedUpdateVersion;
  String? apiKey;
  String? selectedProvider;
  String? selectedModel;
  String? selectedAgent;
  String? selectedVariantMapJson;
  String? sessionSelectionOverridesJson;
  String? agentSelectionMemoryJson;
  String? recentModelsJson;
  String? favoriteModelsJson;
  String? providerCatalogCacheJson;
  String? pinnedSessionsJson;
  String? cannedAnswersJson;
  String? modelUsageCountsJson;
  String? themeMode;
  String? experienceSettingsJson;
  String? lastSessionId;
  String? currentSessionId;
  String? currentProjectId;
  String? openProjectIdsJson;
  String? archivedProjectIdsJson;
  String? hiddenProjectPathsJson;
  String? cachedSessions;
  int? cachedSessionsUpdatedAt;
  String? lastSessionSnapshot;
  int? lastSessionSnapshotUpdatedAt;
  bool? basicAuthEnabled;
  String? basicAuthUsername;
  String? basicAuthPassword;
  final Map<String, String> scopedStrings = <String, String>{};
  final Map<String, int> scopedInts = <String, int>{};
  final Map<String, bool> scopedBools = <String, bool>{};

  String _key(String base, {String? serverId, String? scopeId}) {
    if (serverId == null || serverId.isEmpty) {
      return base;
    }
    if (scopeId == null || scopeId.isEmpty) {
      return '$base::$serverId';
    }
    return '$base::$serverId::$scopeId';
  }

  String _sessionKey(
    String base, {
    required String sessionId,
    String? serverId,
    String? scopeId,
  }) {
    final normalizedSessionId = sessionId.trim();
    if (normalizedSessionId.isEmpty) {
      return _key(base, serverId: serverId, scopeId: scopeId);
    }
    return _key(
      '$base::$normalizedSessionId',
      serverId: serverId,
      scopeId: scopeId,
    );
  }

  @override
  Future<void> clearAll() async {
    serverHost = null;
    serverPort = null;
    serverProfilesJson = null;
    activeServerId = null;
    defaultServerId = null;
    localOpencodeCommand = null;
    dismissedUpdateVersion = null;
    apiKey = null;
    selectedProvider = null;
    selectedModel = null;
    selectedAgent = null;
    selectedVariantMapJson = null;
    sessionSelectionOverridesJson = null;
    agentSelectionMemoryJson = null;
    recentModelsJson = null;
    favoriteModelsJson = null;
    providerCatalogCacheJson = null;
    pinnedSessionsJson = null;
    cannedAnswersJson = null;
    modelUsageCountsJson = null;
    themeMode = null;
    experienceSettingsJson = null;
    lastSessionId = null;
    currentSessionId = null;
    currentProjectId = null;
    openProjectIdsJson = null;
    archivedProjectIdsJson = null;
    hiddenProjectPathsJson = null;
    cachedSessions = null;
    cachedSessionsUpdatedAt = null;
    lastSessionSnapshot = null;
    lastSessionSnapshotUpdatedAt = null;
    basicAuthEnabled = null;
    basicAuthUsername = null;
    basicAuthPassword = null;
    scopedStrings.clear();
    scopedInts.clear();
    scopedBools.clear();
  }

  @override
  Future<void> migrateLegacyLargeCachePayloads() async {}

  @override
  Future<String?> getActiveServerId() async => activeServerId;

  @override
  Future<String?> getApiKey({String? serverId}) async {
    if (serverId == null) return apiKey;
    return scopedStrings[_key('api_key', serverId: serverId)];
  }

  @override
  Future<String?> getOpenCodeGoWorkspaceId({String? serverId}) async {
    return scopedStrings[_key('opencode_go_workspace_id', serverId: serverId)];
  }

  @override
  Future<String?> getOpenCodeGoAuthCookie({String? serverId}) async {
    return scopedStrings[_key('opencode_go_auth_cookie', serverId: serverId)];
  }

  @override
  Future<String?> getDismissedUpdateVersion() async => dismissedUpdateVersion;

  @override
  Future<void> saveDismissedUpdateVersion(String version) async {
    dismissedUpdateVersion = version;
  }

  @override
  Future<bool?> getBasicAuthEnabled({String? serverId}) async {
    if (serverId == null) return basicAuthEnabled;
    return scopedBools[_key('basic_auth_enabled', serverId: serverId)];
  }

  @override
  Future<String?> getBasicAuthPassword({String? serverId}) async {
    if (serverId == null) return basicAuthPassword;
    return scopedStrings[_key('basic_auth_password', serverId: serverId)];
  }

  @override
  Future<String?> getBasicAuthUsername({String? serverId}) async {
    if (serverId == null) return basicAuthUsername;
    return scopedStrings[_key('basic_auth_username', serverId: serverId)];
  }

  @override
  Future<String?> getCachedSessions({String? serverId, String? scopeId}) async {
    if (serverId == null && scopeId == null) return cachedSessions;
    return scopedStrings[_key(
      'cached_sessions',
      serverId: serverId,
      scopeId: scopeId,
    )];
  }

  @override
  Future<int?> getCachedSessionsUpdatedAt({
    String? serverId,
    String? scopeId,
  }) async {
    if (serverId == null && scopeId == null) return cachedSessionsUpdatedAt;
    return scopedInts[_key(
      'cached_sessions_updated_at',
      serverId: serverId,
      scopeId: scopeId,
    )];
  }

  @override
  Future<String?> getLastSessionSnapshot({
    String? serverId,
    String? scopeId,
  }) async {
    if (serverId == null && scopeId == null) return lastSessionSnapshot;
    return scopedStrings[_key(
      'last_session_snapshot',
      serverId: serverId,
      scopeId: scopeId,
    )];
  }

  @override
  Future<int?> getLastSessionSnapshotUpdatedAt({
    String? serverId,
    String? scopeId,
  }) async {
    if (serverId == null && scopeId == null) {
      return lastSessionSnapshotUpdatedAt;
    }
    return scopedInts[_key(
      'last_session_snapshot_updated_at',
      serverId: serverId,
      scopeId: scopeId,
    )];
  }

  @override
  Future<String?> getSessionMessagesSnapshot({
    required String sessionId,
    String? serverId,
    String? scopeId,
  }) async {
    return scopedStrings[_sessionKey(
      'session_messages_snapshot',
      sessionId: sessionId,
      serverId: serverId,
      scopeId: scopeId,
    )];
  }

  @override
  Future<int?> getSessionMessagesSnapshotUpdatedAt({
    required String sessionId,
    String? serverId,
    String? scopeId,
  }) async {
    return scopedInts[_sessionKey(
      'session_messages_snapshot_updated_at',
      sessionId: sessionId,
      serverId: serverId,
      scopeId: scopeId,
    )];
  }

  @override
  Future<String?> getSessionMessagesSnapshotIds({
    String? serverId,
    String? scopeId,
  }) async {
    return scopedStrings[_key(
      'session_messages_snapshot_ids',
      serverId: serverId,
      scopeId: scopeId,
    )];
  }

  @override
  Future<String?> getCurrentSessionId({
    String? serverId,
    String? scopeId,
  }) async {
    if (serverId == null && scopeId == null) return currentSessionId;
    return scopedStrings[_key(
      'current_session_id',
      serverId: serverId,
      scopeId: scopeId,
    )];
  }

  @override
  Future<String?> getCurrentProjectId({String? serverId}) async {
    if (serverId == null) return currentProjectId;
    return scopedStrings[_key('current_project_id', serverId: serverId)];
  }

  @override
  Future<String?> getOpenProjectIdsJson({String? serverId}) async {
    if (serverId == null) return openProjectIdsJson;
    return scopedStrings[_key('open_project_ids', serverId: serverId)];
  }

  @override
  Future<String?> getArchivedProjectIdsJson({String? serverId}) async {
    if (serverId == null) return archivedProjectIdsJson;
    return scopedStrings[_key('archived_project_ids', serverId: serverId)];
  }

  @override
  Future<String?> getHiddenProjectPathsJson({String? serverId}) async {
    if (serverId == null) return hiddenProjectPathsJson;
    return scopedStrings[_key('hidden_project_paths', serverId: serverId)];
  }

  @override
  Future<String?> getDefaultServerId() async => defaultServerId;

  @override
  Future<String?> getLocalOpencodeCommand() async => localOpencodeCommand;

  @override
  Future<String?> getLastSessionId() async => lastSessionId;

  @override
  Future<String?> getSelectedModel({String? serverId, String? scopeId}) async {
    if (serverId == null && scopeId == null) return selectedModel;
    return scopedStrings[_key(
      'selected_model',
      serverId: serverId,
      scopeId: scopeId,
    )];
  }

  @override
  Future<String?> getSelectedAgent({String? serverId, String? scopeId}) async {
    if (serverId == null && scopeId == null) return selectedAgent;
    return scopedStrings[_key(
      'selected_agent',
      serverId: serverId,
      scopeId: scopeId,
    )];
  }

  @override
  Future<String?> getSelectedVariantMap({
    String? serverId,
    String? scopeId,
  }) async {
    if (serverId == null && scopeId == null) return selectedVariantMapJson;
    return scopedStrings[_key(
      'selected_variant_map',
      serverId: serverId,
      scopeId: scopeId,
    )];
  }

  @override
  Future<String?> getSessionSelectionOverridesJson({
    String? serverId,
    String? scopeId,
  }) async {
    if (serverId == null && scopeId == null) {
      return sessionSelectionOverridesJson;
    }
    return scopedStrings[_key(
      'session_selection_overrides',
      serverId: serverId,
      scopeId: scopeId,
    )];
  }

  @override
  Future<String?> getAgentSelectionMemoryJson({
    String? serverId,
    String? scopeId,
  }) async {
    if (serverId == null && scopeId == null) {
      return agentSelectionMemoryJson;
    }
    return scopedStrings[_key(
      'agent_selection_memory',
      serverId: serverId,
      scopeId: scopeId,
    )];
  }

  @override
  Future<String?> getSessionComposerDraftJson({
    required String sessionId,
    String? serverId,
    String? scopeId,
  }) async {
    return scopedStrings[_sessionKey(
      'session_composer_draft',
      sessionId: sessionId,
      serverId: serverId,
      scopeId: scopeId,
    )];
  }

  @override
  Future<String?> getRecentModelsJson({
    String? serverId,
    String? scopeId,
  }) async {
    if (serverId == null && scopeId == null) return recentModelsJson;
    return scopedStrings[_key(
      'recent_models',
      serverId: serverId,
      scopeId: scopeId,
    )];
  }

  @override
  Future<String?> getFavoriteModelsJson({
    String? serverId,
    String? scopeId,
  }) async {
    if (serverId == null && scopeId == null) return favoriteModelsJson;
    return scopedStrings[_key(
      'favorite_models',
      serverId: serverId,
      scopeId: scopeId,
    )];
  }

  @override
  Future<List<String>> getLegacyFavoriteModelsJsonForServer(
    String serverId,
  ) async {
    final serverKey = Uri.encodeComponent(serverId.trim());
    if (serverKey.isEmpty) {
      return const <String>[];
    }
    final prefix = 'favorite_models::$serverKey::';
    return scopedStrings.entries
        .where((entry) => entry.key.startsWith(prefix))
        .map((entry) => entry.value)
        .where((value) => value.trim().isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<void> deleteLegacyFavoriteModelsJsonForServer(String serverId) async {
    final serverKey = Uri.encodeComponent(serverId.trim());
    if (serverKey.isEmpty) {
      return;
    }
    final prefix = 'favorite_models::$serverKey::';
    final keysToDelete = scopedStrings.keys
        .where((key) => key.startsWith(prefix))
        .toList(growable: false);
    for (final key in keysToDelete) {
      scopedStrings.remove(key);
    }
  }

  @override
  Future<String?> getProviderCatalogCacheJson({
    String? serverId,
    String? scopeId,
  }) async {
    if (serverId == null && scopeId == null) {
      return providerCatalogCacheJson;
    }
    return scopedStrings[_key(
      'provider_catalog_cache',
      serverId: serverId,
      scopeId: scopeId,
    )];
  }

  @override
  Future<String?> getPinnedSessionsJson({
    String? serverId,
    String? scopeId,
  }) async {
    if (serverId == null && scopeId == null) return pinnedSessionsJson;
    return scopedStrings[_key(
      'pinned_sessions',
      serverId: serverId,
      scopeId: scopeId,
    )];
  }

  @override
  Future<Map<String, Set<String>>> getPinnedSessionsByScope({
    required String serverId,
  }) async {
    final prefix = 'pinned_sessions::$serverId::';
    final result = <String, Set<String>>{};
    for (final entry in scopedStrings.entries) {
      if (!entry.key.startsWith(prefix)) continue;
      final scopeId = entry.key.substring(prefix.length);
      if (scopeId.isEmpty) continue;
      try {
        final decoded = jsonDecode(entry.value);
        if (decoded is! List) continue;
        final ids = decoded
            .whereType<String>()
            .map((id) => id.trim())
            .where((id) => id.isNotEmpty)
            .toSet();
        if (ids.isNotEmpty) result[scopeId] = ids;
      } catch (_) {
        continue;
      }
    }
    return result;
  }

  @override
  Future<String?> getCannedAnswersJson({
    String? serverId,
    String? scopeId,
  }) async {
    if (serverId == null && scopeId == null) return cannedAnswersJson;
    return scopedStrings[_key(
      'canned_answers',
      serverId: serverId,
      scopeId: scopeId,
    )];
  }

  @override
  Future<String?> getModelUsageCountsJson({
    String? serverId,
    String? scopeId,
  }) async {
    if (serverId == null && scopeId == null) return modelUsageCountsJson;
    return scopedStrings[_key(
      'model_usage_counts',
      serverId: serverId,
      scopeId: scopeId,
    )];
  }

  @override
  Future<String?> getSelectedProvider({
    String? serverId,
    String? scopeId,
  }) async {
    if (serverId == null && scopeId == null) return selectedProvider;
    return scopedStrings[_key(
      'selected_provider',
      serverId: serverId,
      scopeId: scopeId,
    )];
  }

  @override
  Future<String?> getServerProfilesJson() async => serverProfilesJson;

  @override
  Future<String?> getServerHost() async => serverHost;

  @override
  Future<int?> getServerPort() async => serverPort;

  @override
  Future<String?> getThemeMode() async => themeMode;

  @override
  Future<String?> getExperienceSettingsJson() async => experienceSettingsJson;

  @override
  Future<String?> getSessionTabsStateJson({required String serverId}) async {
    return scopedStrings[_key('session_tabs_state', serverId: serverId)];
  }

  @override
  Future<String?> getSessionTabIconOverridesJson({
    required String serverId,
  }) async {
    return scopedStrings[_key(
      'session_tab_icon_overrides',
      serverId: serverId,
    )];
  }

  @override
  Future<void> saveActiveServerId(String serverId) async {
    activeServerId = serverId;
  }

  @override
  Future<void> saveApiKey(String apiKey, {String? serverId}) async {
    if (serverId == null) {
      this.apiKey = apiKey;
      return;
    }
    scopedStrings[_key('api_key', serverId: serverId)] = apiKey;
  }

  @override
  Future<void> saveOpenCodeGoWorkspaceId(
    String workspaceId, {
    String? serverId,
  }) async {
    final key = _key('opencode_go_workspace_id', serverId: serverId);
    if (workspaceId.trim().isEmpty) {
      scopedStrings.remove(key);
      return;
    }
    scopedStrings[key] = workspaceId.trim();
  }

  @override
  Future<void> saveOpenCodeGoAuthCookie(
    String authCookie, {
    String? serverId,
  }) async {
    final key = _key('opencode_go_auth_cookie', serverId: serverId);
    if (authCookie.trim().isEmpty) {
      scopedStrings.remove(key);
      return;
    }
    scopedStrings[key] = authCookie.trim();
  }

  @override
  Future<void> clearOpenCodeGoDashboardCredentials({String? serverId}) async {
    scopedStrings.remove(_key('opencode_go_workspace_id', serverId: serverId));
    scopedStrings.remove(_key('opencode_go_auth_cookie', serverId: serverId));
  }

  @override
  Future<void> saveBasicAuthEnabled(bool enabled, {String? serverId}) async {
    if (serverId == null) {
      basicAuthEnabled = enabled;
      return;
    }
    scopedBools[_key('basic_auth_enabled', serverId: serverId)] = enabled;
  }

  @override
  Future<void> saveBasicAuthPassword(
    String password, {
    String? serverId,
  }) async {
    if (serverId == null) {
      basicAuthPassword = password;
      return;
    }
    scopedStrings[_key('basic_auth_password', serverId: serverId)] = password;
  }

  @override
  Future<void> saveBasicAuthUsername(
    String username, {
    String? serverId,
  }) async {
    if (serverId == null) {
      basicAuthUsername = username;
      return;
    }
    scopedStrings[_key('basic_auth_username', serverId: serverId)] = username;
  }

  @override
  Future<void> saveCachedSessions(
    String sessionsJson, {
    String? serverId,
    String? scopeId,
  }) async {
    if (serverId == null && scopeId == null) {
      cachedSessions = sessionsJson;
      return;
    }
    scopedStrings[_key(
          'cached_sessions',
          serverId: serverId,
          scopeId: scopeId,
        )] =
        sessionsJson;
  }

  @override
  Future<void> saveCachedSessionsUpdatedAt(
    int epochMs, {
    String? serverId,
    String? scopeId,
  }) async {
    if (serverId == null && scopeId == null) {
      cachedSessionsUpdatedAt = epochMs;
      return;
    }
    scopedInts[_key(
          'cached_sessions_updated_at',
          serverId: serverId,
          scopeId: scopeId,
        )] =
        epochMs;
  }

  @override
  Future<void> saveLastSessionSnapshot(
    String snapshotJson, {
    String? serverId,
    String? scopeId,
  }) async {
    if (serverId == null && scopeId == null) {
      lastSessionSnapshot = snapshotJson;
      return;
    }
    scopedStrings[_key(
          'last_session_snapshot',
          serverId: serverId,
          scopeId: scopeId,
        )] =
        snapshotJson;
  }

  @override
  Future<void> saveLastSessionSnapshotUpdatedAt(
    int epochMs, {
    String? serverId,
    String? scopeId,
  }) async {
    if (serverId == null && scopeId == null) {
      lastSessionSnapshotUpdatedAt = epochMs;
      return;
    }
    scopedInts[_key(
          'last_session_snapshot_updated_at',
          serverId: serverId,
          scopeId: scopeId,
        )] =
        epochMs;
  }

  @override
  Future<void> saveSessionMessagesSnapshot(
    String snapshotJson, {
    required String sessionId,
    String? serverId,
    String? scopeId,
  }) async {
    scopedStrings[_sessionKey(
          'session_messages_snapshot',
          sessionId: sessionId,
          serverId: serverId,
          scopeId: scopeId,
        )] =
        snapshotJson;
  }

  @override
  Future<void> saveSessionMessagesSnapshotUpdatedAt(
    int epochMs, {
    required String sessionId,
    String? serverId,
    String? scopeId,
  }) async {
    scopedInts[_sessionKey(
          'session_messages_snapshot_updated_at',
          sessionId: sessionId,
          serverId: serverId,
          scopeId: scopeId,
        )] =
        epochMs;
  }

  @override
  Future<void> saveSessionMessagesSnapshotIds(
    String snapshotIdsJson, {
    String? serverId,
    String? scopeId,
  }) async {
    scopedStrings[_key(
          'session_messages_snapshot_ids',
          serverId: serverId,
          scopeId: scopeId,
        )] =
        snapshotIdsJson;
  }

  @override
  Future<void> saveCurrentSessionId(
    String sessionId, {
    String? serverId,
    String? scopeId,
  }) async {
    if (serverId == null && scopeId == null) {
      currentSessionId = sessionId;
      return;
    }
    scopedStrings[_key(
          'current_session_id',
          serverId: serverId,
          scopeId: scopeId,
        )] =
        sessionId;
  }

  @override
  Future<void> saveCurrentProjectId(
    String projectId, {
    String? serverId,
  }) async {
    if (serverId == null) {
      currentProjectId = projectId;
      return;
    }
    scopedStrings[_key('current_project_id', serverId: serverId)] = projectId;
  }

  @override
  Future<void> saveOpenProjectIdsJson(
    String projectIdsJson, {
    String? serverId,
  }) async {
    if (serverId == null) {
      openProjectIdsJson = projectIdsJson;
      return;
    }
    scopedStrings[_key('open_project_ids', serverId: serverId)] =
        projectIdsJson;
  }

  @override
  Future<void> saveArchivedProjectIdsJson(
    String projectIdsJson, {
    String? serverId,
  }) async {
    if (serverId == null) {
      archivedProjectIdsJson = projectIdsJson;
      return;
    }
    scopedStrings[_key('archived_project_ids', serverId: serverId)] =
        projectIdsJson;
  }

  @override
  Future<void> saveHiddenProjectPathsJson(
    String projectPathsJson, {
    String? serverId,
  }) async {
    if (serverId == null) {
      hiddenProjectPathsJson = projectPathsJson;
      return;
    }
    scopedStrings[_key('hidden_project_paths', serverId: serverId)] =
        projectPathsJson;
  }

  @override
  Future<void> saveDefaultServerId(String? serverId) async {
    defaultServerId = serverId;
  }

  @override
  Future<void> saveLocalOpencodeCommand(String? commandPath) async {
    localOpencodeCommand = commandPath;
  }

  @override
  Future<void> saveLastSessionId(
    String sessionId, {
    String? serverId,
    String? scopeId,
  }) async {
    if (serverId == null && scopeId == null) {
      lastSessionId = sessionId;
      return;
    }
    scopedStrings[_key(
          'last_session_id',
          serverId: serverId,
          scopeId: scopeId,
        )] =
        sessionId;
  }

  @override
  Future<void> saveSelectedModel(
    String modelId, {
    String? serverId,
    String? scopeId,
  }) async {
    if (serverId == null && scopeId == null) {
      selectedModel = modelId;
      return;
    }
    scopedStrings[_key(
          'selected_model',
          serverId: serverId,
          scopeId: scopeId,
        )] =
        modelId;
  }

  @override
  Future<void> saveSelectedAgent(
    String? agentName, {
    String? serverId,
    String? scopeId,
  }) async {
    if (serverId == null && scopeId == null) {
      selectedAgent = agentName;
      return;
    }
    final key = _key('selected_agent', serverId: serverId, scopeId: scopeId);
    if (agentName == null || agentName.trim().isEmpty) {
      scopedStrings.remove(key);
      return;
    }
    scopedStrings[key] = agentName;
  }

  @override
  Future<void> saveSelectedVariantMap(
    String variantMapJson, {
    String? serverId,
    String? scopeId,
  }) async {
    if (serverId == null && scopeId == null) {
      selectedVariantMapJson = variantMapJson;
      return;
    }
    scopedStrings[_key(
          'selected_variant_map',
          serverId: serverId,
          scopeId: scopeId,
        )] =
        variantMapJson;
  }

  @override
  Future<void> saveSessionSelectionOverridesJson(
    String overridesJson, {
    String? serverId,
    String? scopeId,
  }) async {
    if (serverId == null && scopeId == null) {
      sessionSelectionOverridesJson = overridesJson;
      return;
    }
    scopedStrings[_key(
          'session_selection_overrides',
          serverId: serverId,
          scopeId: scopeId,
        )] =
        overridesJson;
  }

  @override
  Future<void> saveAgentSelectionMemoryJson(
    String agentSelectionMemoryJson, {
    String? serverId,
    String? scopeId,
  }) async {
    if (serverId == null && scopeId == null) {
      this.agentSelectionMemoryJson = agentSelectionMemoryJson;
      return;
    }
    scopedStrings[_key(
          'agent_selection_memory',
          serverId: serverId,
          scopeId: scopeId,
        )] =
        agentSelectionMemoryJson;
  }

  @override
  Future<void> saveSessionComposerDraftJson(
    String? draftJson, {
    required String sessionId,
    String? serverId,
    String? scopeId,
  }) async {
    final key = _sessionKey(
      'session_composer_draft',
      sessionId: sessionId,
      serverId: serverId,
      scopeId: scopeId,
    );
    if (draftJson == null || draftJson.trim().isEmpty) {
      scopedStrings.remove(key);
      return;
    }
    scopedStrings[key] = draftJson;
  }

  @override
  Future<void> saveRecentModelsJson(
    String recentModelsJson, {
    String? serverId,
    String? scopeId,
  }) async {
    if (serverId == null && scopeId == null) {
      this.recentModelsJson = recentModelsJson;
      return;
    }
    scopedStrings[_key('recent_models', serverId: serverId, scopeId: scopeId)] =
        recentModelsJson;
  }

  @override
  Future<void> saveFavoriteModelsJson(
    String favoriteModelsJson, {
    String? serverId,
    String? scopeId,
  }) async {
    if (serverId == null && scopeId == null) {
      this.favoriteModelsJson = favoriteModelsJson;
      return;
    }
    scopedStrings[_key(
          'favorite_models',
          serverId: serverId,
          scopeId: scopeId,
        )] =
        favoriteModelsJson;
  }

  @override
  Future<void> saveProviderCatalogCacheJson(
    String providerCatalogJson, {
    String? serverId,
    String? scopeId,
  }) async {
    if (serverId == null && scopeId == null) {
      providerCatalogCacheJson = providerCatalogJson;
      return;
    }
    scopedStrings[_key(
          'provider_catalog_cache',
          serverId: serverId,
          scopeId: scopeId,
        )] =
        providerCatalogJson;
  }

  @override
  Future<void> savePinnedSessionsJson(
    String pinnedSessionsJson, {
    String? serverId,
    String? scopeId,
  }) async {
    if (serverId == null && scopeId == null) {
      this.pinnedSessionsJson = pinnedSessionsJson;
      return;
    }
    scopedStrings[_key(
          'pinned_sessions',
          serverId: serverId,
          scopeId: scopeId,
        )] =
        pinnedSessionsJson;
  }

  @override
  Future<void> saveCannedAnswersJson(
    String cannedAnswersJson, {
    String? serverId,
    String? scopeId,
  }) async {
    if (serverId == null && scopeId == null) {
      this.cannedAnswersJson = cannedAnswersJson;
      return;
    }
    scopedStrings[_key(
          'canned_answers',
          serverId: serverId,
          scopeId: scopeId,
        )] =
        cannedAnswersJson;
  }

  @override
  Future<void> saveModelUsageCountsJson(
    String usageCountsJson, {
    String? serverId,
    String? scopeId,
  }) async {
    if (serverId == null && scopeId == null) {
      modelUsageCountsJson = usageCountsJson;
      return;
    }
    scopedStrings[_key(
          'model_usage_counts',
          serverId: serverId,
          scopeId: scopeId,
        )] =
        usageCountsJson;
  }

  @override
  Future<void> saveSelectedProvider(
    String providerId, {
    String? serverId,
    String? scopeId,
  }) async {
    if (serverId == null && scopeId == null) {
      selectedProvider = providerId;
      return;
    }
    scopedStrings[_key(
          'selected_provider',
          serverId: serverId,
          scopeId: scopeId,
        )] =
        providerId;
  }

  @override
  Future<void> saveServerProfilesJson(String profilesJson) async {
    serverProfilesJson = profilesJson;
  }

  @override
  Future<void> saveServerHost(String host) async {
    serverHost = host;
  }

  @override
  Future<void> saveServerPort(int port) async {
    serverPort = port;
  }

  @override
  Future<void> saveThemeMode(String themeMode) async {
    this.themeMode = themeMode;
  }

  @override
  Future<void> saveExperienceSettingsJson(String settingsJson) async {
    experienceSettingsJson = settingsJson;
  }

  @override
  Future<void> saveSessionTabsStateJson(
    String stateJson, {
    required String serverId,
  }) async {
    scopedStrings[_key('session_tabs_state', serverId: serverId)] = stateJson;
  }

  @override
  Future<void> saveSessionTabIconOverridesJson(
    String stateJson, {
    required String serverId,
  }) async {
    scopedStrings[_key('session_tab_icon_overrides', serverId: serverId)] =
        stateJson;
  }

  @override
  Future<void> deleteSessionTabIconOverrides({required String serverId}) async {
    scopedStrings.remove(
      _key('session_tab_icon_overrides', serverId: serverId),
    );
  }

  @override
  Future<void> clearChatContextCache({
    required String serverId,
    required String scopeId,
  }) async {
    final snapshotIdsRaw =
        scopedStrings[_key(
          'session_messages_snapshot_ids',
          serverId: serverId,
          scopeId: scopeId,
        )];
    if (snapshotIdsRaw != null && snapshotIdsRaw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(snapshotIdsRaw);
        if (decoded is List) {
          for (final id in decoded.whereType<String>()) {
            if (id.trim().isEmpty) {
              continue;
            }
            scopedStrings.remove(
              _sessionKey(
                'session_messages_snapshot',
                sessionId: id,
                serverId: serverId,
                scopeId: scopeId,
              ),
            );
            scopedInts.remove(
              _sessionKey(
                'session_messages_snapshot_updated_at',
                sessionId: id,
                serverId: serverId,
                scopeId: scopeId,
              ),
            );
          }
        }
      } catch (_) {
        // Ignore malformed stored snapshot IDs in tests.
      }
    }

    scopedStrings.remove(
      _key('cached_sessions', serverId: serverId, scopeId: scopeId),
    );
    scopedInts.remove(
      _key('cached_sessions_updated_at', serverId: serverId, scopeId: scopeId),
    );
    scopedStrings.remove(
      _key('current_session_id', serverId: serverId, scopeId: scopeId),
    );
    scopedStrings.remove(
      _key('last_session_id', serverId: serverId, scopeId: scopeId),
    );
    scopedStrings.remove(
      _key('last_session_snapshot', serverId: serverId, scopeId: scopeId),
    );
    scopedInts.remove(
      _key(
        'last_session_snapshot_updated_at',
        serverId: serverId,
        scopeId: scopeId,
      ),
    );
    scopedStrings.remove(
      _key('session_selection_overrides', serverId: serverId, scopeId: scopeId),
    );
    scopedStrings.remove(
      _key(
        'session_messages_snapshot_ids',
        serverId: serverId,
        scopeId: scopeId,
      ),
    );
  }

  @override
  Future<void> clearLastSessionSnapshot({
    String? serverId,
    String? scopeId,
  }) async {
    if (serverId == null && scopeId == null) {
      lastSessionSnapshot = null;
      lastSessionSnapshotUpdatedAt = null;
      return;
    }
    scopedStrings.remove(
      _key('last_session_snapshot', serverId: serverId, scopeId: scopeId),
    );
    scopedInts.remove(
      _key(
        'last_session_snapshot_updated_at',
        serverId: serverId,
        scopeId: scopeId,
      ),
    );
  }

  @override
  Future<void> clearSessionMessagesSnapshot({
    required String sessionId,
    String? serverId,
    String? scopeId,
  }) async {
    scopedStrings.remove(
      _sessionKey(
        'session_messages_snapshot',
        sessionId: sessionId,
        serverId: serverId,
        scopeId: scopeId,
      ),
    );
    scopedInts.remove(
      _sessionKey(
        'session_messages_snapshot_updated_at',
        sessionId: sessionId,
        serverId: serverId,
        scopeId: scopeId,
      ),
    );
  }
}

class DelayedSelectionPersistenceLocalDataSource
    extends InMemoryAppLocalDataSource {
  DelayedSelectionPersistenceLocalDataSource({required this.delay});

  final Duration delay;

  Future<void> _afterDelay(Future<void> Function() action) async {
    await Future<void>.delayed(delay);
    await action();
  }

  @override
  Future<void> saveSelectedProvider(
    String providerId, {
    String? serverId,
    String? scopeId,
  }) {
    return _afterDelay(
      () => super.saveSelectedProvider(
        providerId,
        serverId: serverId,
        scopeId: scopeId,
      ),
    );
  }

  @override
  Future<void> saveSelectedModel(
    String modelId, {
    String? serverId,
    String? scopeId,
  }) {
    return _afterDelay(
      () => super.saveSelectedModel(
        modelId,
        serverId: serverId,
        scopeId: scopeId,
      ),
    );
  }

  @override
  Future<void> saveSelectedAgent(
    String? agentName, {
    String? serverId,
    String? scopeId,
  }) {
    return _afterDelay(
      () => super.saveSelectedAgent(
        agentName,
        serverId: serverId,
        scopeId: scopeId,
      ),
    );
  }

  @override
  Future<void> saveRecentModelsJson(
    String recentModelsJson, {
    String? serverId,
    String? scopeId,
  }) {
    return _afterDelay(
      () => super.saveRecentModelsJson(
        recentModelsJson,
        serverId: serverId,
        scopeId: scopeId,
      ),
    );
  }

  @override
  Future<void> saveFavoriteModelsJson(
    String favoriteModelsJson, {
    String? serverId,
    String? scopeId,
  }) {
    return _afterDelay(
      () => super.saveFavoriteModelsJson(
        favoriteModelsJson,
        serverId: serverId,
        scopeId: scopeId,
      ),
    );
  }

  @override
  Future<void> savePinnedSessionsJson(
    String pinnedSessionsJson, {
    String? serverId,
    String? scopeId,
  }) {
    return _afterDelay(
      () => super.savePinnedSessionsJson(
        pinnedSessionsJson,
        serverId: serverId,
        scopeId: scopeId,
      ),
    );
  }

  @override
  Future<void> saveModelUsageCountsJson(
    String modelUsageCountsJson, {
    String? serverId,
    String? scopeId,
  }) {
    return _afterDelay(
      () => super.saveModelUsageCountsJson(
        modelUsageCountsJson,
        serverId: serverId,
        scopeId: scopeId,
      ),
    );
  }

  @override
  Future<void> saveSelectedVariantMap(
    String variantMapJson, {
    String? serverId,
    String? scopeId,
  }) {
    return _afterDelay(
      () => super.saveSelectedVariantMap(
        variantMapJson,
        serverId: serverId,
        scopeId: scopeId,
      ),
    );
  }

  @override
  Future<void> saveAgentSelectionMemoryJson(
    String agentSelectionMemoryJson, {
    String? serverId,
    String? scopeId,
  }) {
    return _afterDelay(
      () => super.saveAgentSelectionMemoryJson(
        agentSelectionMemoryJson,
        serverId: serverId,
        scopeId: scopeId,
      ),
    );
  }

  @override
  Future<void> saveSessionSelectionOverridesJson(
    String overridesJson, {
    String? serverId,
    String? scopeId,
  }) {
    return _afterDelay(
      () => super.saveSessionSelectionOverridesJson(
        overridesJson,
        serverId: serverId,
        scopeId: scopeId,
      ),
    );
  }
}

class FakeChatRepository implements ChatRepository {
  FakeChatRepository({
    List<ChatSession>? sessions,
    this.providersDefault = const ProvidersResponse(
      providers: <Provider>[],
      defaultModels: <String, String>{},
      connected: <String>[],
    ),
  }) : sessions = sessions ?? <ChatSession>[];

  final List<ChatSession> sessions;
  final Map<String, List<ChatMessage>> messagesBySession =
      <String, List<ChatMessage>>{};
  final ProvidersResponse providersDefault;

  String? lastGetSessionsDirectory;
  int getSessionsCallCount = 0;
  int getMessagesCallCount = 0;
  int getMessageCallCount = 0;
  int? lastGetMessagesLimit;
  final List<int?> getMessagesRequestedLimits = <int?>[];
  int getSessionChildrenCallCount = 0;
  int getSessionTodoCallCount = 0;
  int getSessionDiffCallCount = 0;
  int getSessionStatusCallCount = 0;
  // ADR-023 regression tracking: assert the resolver passes a messageId to
  // the REST /session/{id}/diff call instead of relying on unscoped queries
  // that upstream SessionSummary.diff answers with an empty list.
  String? lastGetSessionDiffMessageId;
  // Per-message diff map keyed by sessionId. When populated, the fake
  // returns the entry matching the requested messageId; otherwise it falls
  // back to the legacy `sessionDiffById` map for backward compatibility.
  final Map<String, Map<String, List<SessionDiff>>> sessionDiffByMessageId =
      <String, Map<String, List<SessionDiff>>>{};

  // Optional delay hooks for concurrency verification in tests.
  Future<void> Function()? getSessionsDelay;
  Future<void> Function()? getMessagesDelay;
  Future<void> Function()? getSessionChildrenDelay;
  Future<void> Function()? getSessionTodoDelay;
  Future<void> Function()? getSessionDiffDelay;
  Future<void> Function()? getSessionStatusDelay;

  String? lastSendProjectId;
  String? lastSendSessionId;
  String? lastSendDirectory;
  ChatInput? lastSendInput;
  Stream<Either<Failure, ChatMessage>> Function(
    String projectId,
    String sessionId,
    ChatInput input,
    String? directory,
  )?
  sendMessageHandler;
  Future<Either<Failure, ChatSession>> Function(
    String projectId,
    String sessionId,
    SessionUpdateInput input,
    String? directory,
  )?
  updateSessionHandler;
  Future<Either<Failure, List<ChatMessage>>> Function(
    String projectId,
    String sessionId, {
    String? directory,
    int? limit,
  })?
  getMessagesHandler;

  Failure? getSessionsFailure;
  Failure? createSessionFailure;
  Failure? getMessagesFailure;
  Failure? deleteSessionFailure;
  Failure? updateSessionFailure;
  Failure? shareSessionFailure;
  Failure? unshareSessionFailure;
  Failure? forkSessionFailure;
  Failure? revertMessageFailure;
  Failure? unrevertMessagesFailure;
  String? lastRevertProjectId;
  String? lastRevertSessionId;
  String? lastRevertMessageId;
  String? lastRevertDirectory;
  String? lastUnrevertProjectId;
  String? lastUnrevertSessionId;
  String? lastUnrevertDirectory;
  Failure? sessionStatusFailure;
  Failure? sessionChildrenFailure;
  Failure? sessionTodoFailure;
  Failure? sessionDiffFailure;
  Future<void> Function()? listPermissionsDelay;
  Future<void> Function()? listQuestionsDelay;
  final StreamController<Either<Failure, ChatEvent>> eventController =
      StreamController<Either<Failure, ChatEvent>>.broadcast();
  final StreamController<Either<Failure, ChatEvent>> globalEventController =
      StreamController<Either<Failure, ChatEvent>>.broadcast();
  List<ChatPermissionRequest> pendingPermissions = <ChatPermissionRequest>[];
  List<ChatQuestionRequest> pendingQuestions = <ChatQuestionRequest>[];
  String? lastPermissionRequestId;
  String? lastPermissionSessionId;
  String? lastPermissionReply;
  String? lastPermissionMessage;
  String? lastQuestionReplyRequestId;
  String? lastQuestionReplySessionId;
  List<List<String>>? lastQuestionAnswers;
  String? lastQuestionRejectRequestId;
  String? lastQuestionRejectSessionId;
  Failure? replyQuestionFailure;
  Failure? rejectQuestionFailure;
  int abortSessionCallCount = 0;
  String? lastAbortProjectId;
  String? lastAbortSessionId;
  String? lastAbortDirectory;
  Failure? abortSessionFailure;
  Map<String, SessionStatusInfo> sessionStatusById =
      <String, SessionStatusInfo>{};
  final Map<String, List<ChatSession>> sessionChildrenById =
      <String, List<ChatSession>>{};
  final Map<String, List<SessionTodo>> sessionTodoById =
      <String, List<SessionTodo>>{};
  final Map<String, List<SessionDiff>> sessionDiffById =
      <String, List<SessionDiff>>{};

  void emitEvent(ChatEvent event) {
    eventController.add(Right(event));
  }

  void emitEventFailure(Failure failure) {
    eventController.add(Left(failure));
  }

  void emitGlobalEvent(ChatEvent event) {
    globalEventController.add(Right(event));
  }

  @override
  Future<Either<Failure, void>> abortSession(
    String projectId,
    String sessionId, {
    String? directory,
  }) async {
    abortSessionCallCount += 1;
    lastAbortProjectId = projectId;
    lastAbortSessionId = sessionId;
    lastAbortDirectory = directory;
    if (abortSessionFailure != null) {
      return Left(abortSessionFailure!);
    }
    return const Right(null);
  }

  @override
  Future<Either<Failure, ChatSession>> createSession(
    String projectId,
    SessionCreateInput input, {
    String? directory,
  }) async {
    if (createSessionFailure != null) return Left(createSessionFailure!);
    final created = ChatSession(
      id: 'ses_${sessions.length + 1}',
      workspaceId: 'default',
      time: DateTime.now(),
      title: input.title ?? 'New chat',
    );
    sessions.insert(0, created);
    messagesBySession.putIfAbsent(created.id, () => <ChatMessage>[]);
    return Right(created);
  }

  @override
  Future<Either<Failure, void>> deleteSession(
    String projectId,
    String sessionId, {
    String? directory,
  }) async {
    if (deleteSessionFailure != null) return Left(deleteSessionFailure!);
    sessions.removeWhere((s) => s.id == sessionId);
    messagesBySession.remove(sessionId);
    return const Right(null);
  }

  @override
  Future<Either<Failure, ChatMessage>> getMessage(
    String projectId,
    String sessionId,
    String messageId, {
    String? directory,
  }) async {
    getMessageCallCount += 1;
    final found = messagesBySession[sessionId]
        ?.where((m) => m.id == messageId)
        .firstOrNull;
    if (found == null) {
      return const Left(NotFoundFailure('Message not found'));
    }
    return Right(found);
  }

  @override
  Future<Either<Failure, List<ChatMessage>>> getMessages(
    String projectId,
    String sessionId, {
    String? directory,
    int? limit,
  }) async {
    getMessagesCallCount += 1;
    lastGetMessagesLimit = limit;
    getMessagesRequestedLimits.add(limit);
    if (getMessagesDelay != null) await getMessagesDelay!();
    final handler = getMessagesHandler;
    if (handler != null) {
      return handler(projectId, sessionId, directory: directory, limit: limit);
    }
    if (getMessagesFailure != null) return Left(getMessagesFailure!);
    var output = List<ChatMessage>.from(
      messagesBySession[sessionId] ?? const [],
    );
    if (limit != null && limit > 0 && output.length > limit) {
      output = output.sublist(output.length - limit);
    }
    return Right(output);
  }

  @override
  Future<Either<Failure, ChatSession>> getSession(
    String projectId,
    String sessionId, {
    String? directory,
  }) async {
    final found = sessions.where((s) => s.id == sessionId).firstOrNull;
    if (found == null) {
      return const Left(NotFoundFailure('Session not found'));
    }
    return Right(found);
  }

  @override
  Future<Either<Failure, List<ChatSession>>> getSessions({
    String? directory,
    String? search,
    bool? rootsOnly,
    int? startEpochMs,
    int? limit,
  }) async {
    getSessionsCallCount += 1;
    lastGetSessionsDirectory = directory;
    if (getSessionsDelay != null) await getSessionsDelay!();
    if (getSessionsFailure != null) return Left(getSessionsFailure!);
    var list = List<ChatSession>.from(sessions);
    if (rootsOnly == true) {
      list = list
          .where((item) => item.parentId == null)
          .toList(growable: false);
    }
    if (search != null && search.trim().isNotEmpty) {
      final term = search.trim().toLowerCase();
      list = list
          .where(
            (item) =>
                (item.title ?? '').toLowerCase().contains(term) ||
                (item.summary ?? '').toLowerCase().contains(term),
          )
          .toList(growable: false);
    }
    if (startEpochMs != null) {
      list = list
          .where((item) => item.time.millisecondsSinceEpoch >= startEpochMs)
          .toList(growable: false);
    }
    if (limit != null && list.length > limit) {
      list = list.take(limit).toList(growable: false);
    }
    return Right(list);
  }

  @override
  Future<Either<Failure, Map<String, SessionStatusInfo>>> getSessionStatus({
    String? directory,
  }) async {
    getSessionStatusCallCount += 1;
    if (getSessionStatusDelay != null) await getSessionStatusDelay!();
    if (sessionStatusFailure != null) {
      return Left(sessionStatusFailure!);
    }
    return Right(Map<String, SessionStatusInfo>.from(sessionStatusById));
  }

  @override
  Future<Either<Failure, List<ChatSession>>> getSessionChildren(
    String projectId,
    String sessionId, {
    String? directory,
  }) async {
    getSessionChildrenCallCount += 1;
    if (getSessionChildrenDelay != null) await getSessionChildrenDelay!();
    if (sessionChildrenFailure != null) {
      return Left(sessionChildrenFailure!);
    }
    return Right(
      List<ChatSession>.from(
        sessionChildrenById[sessionId] ?? const <ChatSession>[],
      ),
    );
  }

  @override
  Future<Either<Failure, List<SessionTodo>>> getSessionTodo(
    String projectId,
    String sessionId, {
    String? directory,
  }) async {
    getSessionTodoCallCount += 1;
    if (getSessionTodoDelay != null) await getSessionTodoDelay!();
    if (sessionTodoFailure != null) {
      return Left(sessionTodoFailure!);
    }
    return Right(
      List<SessionTodo>.from(
        sessionTodoById[sessionId] ?? const <SessionTodo>[],
      ),
    );
  }

  @override
  Future<Either<Failure, List<SessionDiff>>> getSessionDiff(
    String projectId,
    String sessionId, {
    String? messageId,
    String? directory,
  }) async {
    getSessionDiffCallCount += 1;
    lastGetSessionDiffMessageId = messageId;
    if (getSessionDiffDelay != null) await getSessionDiffDelay!();
    if (sessionDiffFailure != null) {
      return Left(sessionDiffFailure!);
    }
    final perMessage = sessionDiffByMessageId[sessionId];
    if (perMessage != null && perMessage.isNotEmpty) {
      if (messageId == null || messageId.isEmpty) {
        return const Right(<SessionDiff>[]);
      }
      return Right(
        List<SessionDiff>.from(perMessage[messageId] ?? const <SessionDiff>[]),
      );
    }
    return Right(
      List<SessionDiff>.from(
        sessionDiffById[sessionId] ?? const <SessionDiff>[],
      ),
    );
  }

  @override
  Future<Either<Failure, void>> initSession(
    String projectId,
    String sessionId, {
    required String messageId,
    required String providerId,
    required String modelId,
    String? directory,
  }) async => const Right(null);

  @override
  Future<Either<Failure, void>> revertMessage(
    String projectId,
    String sessionId,
    String messageId, {
    String? directory,
  }) async {
    lastRevertProjectId = projectId;
    lastRevertSessionId = sessionId;
    lastRevertMessageId = messageId;
    lastRevertDirectory = directory;
    if (revertMessageFailure != null) {
      return Left(revertMessageFailure!);
    }
    return const Right(null);
  }

  @override
  Future<Either<Failure, List<ChatPermissionRequest>>> listPermissions({
    String? directory,
  }) async {
    if (listPermissionsDelay != null) await listPermissionsDelay!();
    return Right(List<ChatPermissionRequest>.from(pendingPermissions));
  }

  @override
  Future<Either<Failure, void>> replyPermission({
    required String sessionId,
    required String requestId,
    required String reply,
    String? message,
    String? directory,
  }) async {
    lastPermissionSessionId = sessionId;
    lastPermissionRequestId = requestId;
    lastPermissionReply = reply;
    lastPermissionMessage = message;
    pendingPermissions = pendingPermissions
        .where((item) => item.id != requestId)
        .toList(growable: false);
    return const Right(null);
  }

  @override
  Future<Either<Failure, List<ChatQuestionRequest>>> listQuestions({
    String? directory,
  }) async {
    if (listQuestionsDelay != null) await listQuestionsDelay!();
    return Right(List<ChatQuestionRequest>.from(pendingQuestions));
  }

  @override
  Future<Either<Failure, void>> replyQuestion({
    String? sessionId,
    required String requestId,
    required List<List<String>> answers,
    String? directory,
  }) async {
    lastQuestionReplySessionId = sessionId;
    lastQuestionReplyRequestId = requestId;
    lastQuestionAnswers = answers;
    if (replyQuestionFailure != null) {
      return Left(replyQuestionFailure!);
    }
    pendingQuestions = pendingQuestions
        .where((item) => item.id != requestId)
        .toList(growable: false);
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> rejectQuestion({
    String? sessionId,
    required String requestId,
    String? directory,
  }) async {
    lastQuestionRejectSessionId = sessionId;
    lastQuestionRejectRequestId = requestId;
    if (rejectQuestionFailure != null) {
      return Left(rejectQuestionFailure!);
    }
    pendingQuestions = pendingQuestions
        .where((item) => item.id != requestId)
        .toList(growable: false);
    return const Right(null);
  }

  @override
  Stream<Either<Failure, ChatEvent>> subscribeEvents({String? directory}) {
    return eventController.stream;
  }

  @override
  Stream<Either<Failure, ChatEvent>> subscribeGlobalEvents() {
    return globalEventController.stream;
  }

  @override
  Stream<Either<Failure, ChatMessage>> sendMessage(
    String projectId,
    String sessionId,
    ChatInput input, {
    String? directory,
  }) {
    lastSendProjectId = projectId;
    lastSendSessionId = sessionId;
    lastSendDirectory = directory;
    lastSendInput = input;

    if (sendMessageHandler != null) {
      return sendMessageHandler!(projectId, sessionId, input, directory);
    }

    final assistant = AssistantMessage(
      id: 'msg_assistant_1',
      sessionId: sessionId,
      time: DateTime.now(),
      completedTime: DateTime.now(),
      parts: const <MessagePart>[
        TextPart(
          id: 'prt_assistant_1',
          messageId: 'msg_assistant_1',
          sessionId: 'session',
          text: 'ok',
        ),
      ],
    );
    messagesBySession
        .putIfAbsent(sessionId, () => <ChatMessage>[])
        .add(assistant);
    return Stream<Either<Failure, ChatMessage>>.value(Right(assistant));
  }

  @override
  Future<Either<Failure, ChatSession>> shareSession(
    String projectId,
    String sessionId, {
    String? directory,
  }) async {
    if (shareSessionFailure != null) return Left(shareSessionFailure!);
    final index = sessions.indexWhere((s) => s.id == sessionId);
    if (index == -1) return const Left(NotFoundFailure('Session not found'));
    final updated = sessions[index].copyWith(
      shared: true,
      shareUrl: 'https://share.mock/$sessionId',
    );
    sessions[index] = updated;
    return Right(updated);
  }

  @override
  Future<Either<Failure, void>> summarizeSession(
    String projectId,
    String sessionId, {
    required String providerId,
    required String modelId,
    String? directory,
  }) async => const Right(null);

  @override
  Future<Either<Failure, ChatSession>> unshareSession(
    String projectId,
    String sessionId, {
    String? directory,
  }) async {
    if (unshareSessionFailure != null) return Left(unshareSessionFailure!);
    final index = sessions.indexWhere((s) => s.id == sessionId);
    if (index == -1) return const Left(NotFoundFailure('Session not found'));
    final updated = sessions[index].copyWith(shared: false, shareUrl: null);
    sessions[index] = updated;
    return Right(updated);
  }

  @override
  Future<Either<Failure, ChatSession>> forkSession(
    String projectId,
    String sessionId, {
    String? messageId,
    String? directory,
  }) async {
    if (forkSessionFailure != null) return Left(forkSessionFailure!);
    final parent = sessions.where((item) => item.id == sessionId).firstOrNull;
    if (parent == null) {
      return const Left(NotFoundFailure('Session not found'));
    }
    final forked = ChatSession(
      id: 'ses_${sessions.length + 1}',
      workspaceId: parent.workspaceId,
      time: DateTime.now(),
      title: '${parent.title ?? 'Conversation'} (fork)',
      parentId: parent.id,
      directory: parent.directory,
    );
    sessions.insert(0, forked);
    sessionChildrenById
        .putIfAbsent(parent.id, () => <ChatSession>[])
        .add(forked);
    return Right(forked);
  }

  @override
  Future<Either<Failure, void>> unrevertMessages(
    String projectId,
    String sessionId, {
    String? directory,
  }) async {
    lastUnrevertProjectId = projectId;
    lastUnrevertSessionId = sessionId;
    lastUnrevertDirectory = directory;
    if (unrevertMessagesFailure != null) {
      return Left(unrevertMessagesFailure!);
    }
    return const Right(null);
  }

  @override
  Future<Either<Failure, ChatSession>> updateSession(
    String projectId,
    String sessionId,
    SessionUpdateInput input, {
    String? directory,
  }) async {
    if (updateSessionHandler != null) {
      return updateSessionHandler!(projectId, sessionId, input, directory);
    }
    if (updateSessionFailure != null) return Left(updateSessionFailure!);
    final index = sessions.indexWhere((s) => s.id == sessionId);
    if (index == -1) return const Left(NotFoundFailure('Session not found'));
    final updated = sessions[index].copyWith(
      title: input.title ?? sessions[index].title,
      archivedAt:
          input.archivedAtEpochMs == null || input.archivedAtEpochMs! <= 0
          ? null
          : DateTime.fromMillisecondsSinceEpoch(input.archivedAtEpochMs!),
    );
    sessions[index] = updated;
    return Right(updated);
  }
}

class FakeAppRepository implements AppRepository {
  Either<Failure, AppInfo> appInfoResult = const Right(
    AppInfo(
      hostname: 'localhost',
      git: true,
      path: AppPath(
        config: '/tmp/config',
        data: '/tmp/data',
        root: '/tmp/root',
        cwd: '/tmp/cwd',
        state: '/tmp/state',
      ),
      time: AppTime(initialized: 1),
    ),
  );
  Either<Failure, bool> checkConnectionResult = const Right(true);
  Either<Failure, bool> initializeResult = const Right(true);
  Either<Failure, ProvidersResponse> providersResult = const Right(
    ProvidersResponse(
      providers: <Provider>[],
      defaultModels: <String, String>{},
      connected: <String>[],
    ),
  );
  Either<Failure, List<Agent>> agentsResult = const Right(<Agent>[
    Agent(name: 'build', mode: 'primary', hidden: false, native: false),
    Agent(name: 'plan', mode: 'primary', hidden: false, native: false),
  ]);
  int getProvidersCallCount = 0;
  Future<void> Function()? getProvidersDelay;
  Future<Either<Failure, ProvidersResponse>> Function(String? directory)?
  getProvidersHandler;
  Future<void> Function()? getAgentsDelay;
  Future<Either<Failure, List<Agent>>> Function(String? directory)?
  getAgentsHandler;
  String? lastGetProvidersDirectory;
  String? lastGetAgentsDirectory;
  String? updatedHost;
  int? updatedPort;

  @override
  Future<Either<Failure, bool>> checkConnection({String? directory}) async {
    return checkConnectionResult;
  }

  @override
  Future<Either<Failure, AppInfo>> getAppInfo({String? directory}) async {
    return appInfoResult;
  }

  @override
  Future<Either<Failure, ProvidersResponse>> getProviders({
    String? directory,
  }) async {
    getProvidersCallCount += 1;
    lastGetProvidersDirectory = directory;
    if (getProvidersDelay != null) await getProvidersDelay!();
    final handler = getProvidersHandler;
    if (handler != null) return handler(directory);
    return providersResult;
  }

  @override
  Future<Either<Failure, List<Agent>>> getAgents({String? directory}) async {
    lastGetAgentsDirectory = directory;
    if (getAgentsDelay != null) await getAgentsDelay!();
    final handler = getAgentsHandler;
    if (handler != null) return handler(directory);
    return agentsResult;
  }

  @override
  Future<Either<Failure, bool>> initializeApp({String? directory}) async {
    return initializeResult;
  }

  @override
  Future<Either<Failure, void>> updateServerConfig(
    String host,
    int port,
  ) async {
    updatedHost = host;
    updatedPort = port;
    return const Right(null);
  }
}

class FakeProjectRepository implements ProjectRepository {
  FakeProjectRepository({
    Project? currentProject,
    List<Project>? projects,
    List<Worktree>? worktrees,
  }) : _currentProject =
           currentProject ??
           Project(
             id: 'default',
             name: 'Default',
             path: '/tmp',
             createdAt: DateTime.fromMillisecondsSinceEpoch(0),
           ),
       _projects =
           projects ??
           <Project>[
             Project(
               id: 'default',
               name: 'Default',
               path: '/tmp',
               createdAt: DateTime.fromMillisecondsSinceEpoch(0),
             ),
           ],
       _worktrees = List<Worktree>.from(worktrees ?? <Worktree>[]);

  final Project _currentProject;
  final List<Project> _projects;
  final List<Worktree> _worktrees;
  int getCurrentProjectCallCount = 0;
  int getProjectsCallCount = 0;
  Failure? currentProjectFailure;
  Failure? getProjectsFailure;
  Failure? worktreeFailure;
  Failure? directoryFailure;
  Failure? fileContentFailure;
  Future<Either<Failure, FileContent>> Function({
    String? directory,
    required String path,
  })?
  readFileContentHandler;
  int readFileContentCallCount = 0;
  Future<void> Function(String path)? listFilesDelay;
  Future<void> Function(String query)? findFilesDelay;
  String? lastCreatedWorktreeName;
  String? lastCreatedWorktreeDirectory;
  final Set<String> gitDirectories = <String>{};
  final Map<String, List<String>> directoriesByPath = <String, List<String>>{};
  final Map<String, List<FileNode>> filesByPath = <String, List<FileNode>>{};
  final Map<String, List<List<FileNode>>> queuedFilesByPath =
      <String, List<List<FileNode>>>{};
  final Map<String, Failure> fileFailuresByPath = <String, Failure>{};
  final Map<String, FileContent> fileContentsByPath = <String, FileContent>{};
  final Map<String, List<FileNode>> searchResultsByQuery =
      <String, List<FileNode>>{};
  final Map<String, List<FileSearchMatch>> contentSearchResultsByPattern =
      <String, List<FileSearchMatch>>{};
  final Map<String, List<WorkspaceSymbol>> symbolsByQuery =
      <String, List<WorkspaceSymbol>>{};

  @override
  Future<Either<Failure, Project>> getCurrentProject({
    String? directory,
  }) async {
    getCurrentProjectCallCount += 1;
    if (currentProjectFailure != null) {
      return Left(currentProjectFailure!);
    }
    if (directory != null && directory.trim().isNotEmpty) {
      final byDirectory = _projects
          .where((project) => project.path == directory)
          .firstOrNull;
      if (byDirectory != null) {
        return Right(byDirectory);
      }
    }
    return Right(_currentProject);
  }

  @override
  Future<Either<Failure, Project>> getProject(String projectId) async {
    return Right(
      _projects.firstWhere(
        (p) => p.id == projectId,
        orElse: () => _currentProject,
      ),
    );
  }

  @override
  Future<Either<Failure, List<Project>>> getProjects() async {
    getProjectsCallCount += 1;
    if (getProjectsFailure != null) {
      return Left(getProjectsFailure!);
    }
    return Right(_projects);
  }

  @override
  Future<Either<Failure, List<Worktree>>> getWorktrees({
    String? directory,
  }) async {
    if (worktreeFailure != null) {
      return Left(worktreeFailure!);
    }
    if (directory == null || directory.trim().isEmpty) {
      return Right(List<Worktree>.from(_worktrees));
    }
    return Right(
      _worktrees
          .where((item) => item.directory.startsWith(directory))
          .toList(growable: false),
    );
  }

  @override
  Future<Either<Failure, Worktree>> createWorktree(
    String name, {
    String? directory,
  }) async {
    if (worktreeFailure != null) {
      return Left(worktreeFailure!);
    }
    lastCreatedWorktreeName = name;
    lastCreatedWorktreeDirectory = directory;
    final normalized = name.trim().toLowerCase().replaceAll(' ', '-');
    final base = directory ?? '/tmp';
    final created = Worktree(
      id: 'wt_${_worktrees.length + 1}',
      name: name,
      directory: '$base/$normalized',
      projectId: _currentProject.id,
      active: false,
      createdAt: DateTime.now(),
    );
    _worktrees.add(created);
    _projects.add(
      Project(
        id: 'proj_${_projects.length + 1}',
        name: name,
        path: created.directory,
        createdAt: DateTime.now(),
      ),
    );
    return Right(created);
  }

  @override
  Future<Either<Failure, void>> resetWorktree(
    String worktreeId, {
    String? directory,
  }) async {
    if (worktreeFailure != null) {
      return Left(worktreeFailure!);
    }
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> deleteWorktree(
    String worktreeId, {
    String? directory,
  }) async {
    if (worktreeFailure != null) {
      return Left(worktreeFailure!);
    }
    _worktrees.removeWhere((item) => item.id == worktreeId);
    return const Right(null);
  }

  @override
  Future<Either<Failure, List<String>>> listDirectories(
    String directory,
  ) async {
    if (directoryFailure != null) {
      return Left(directoryFailure!);
    }
    final key = directory.trim();
    final seeded = directoriesByPath[key];
    if (seeded != null) {
      return Right(List<String>.from(seeded));
    }
    final inferred = <String>[];
    for (final project in _projects) {
      final path = project.path.trim();
      if (path.startsWith('$key/') && path != key) {
        inferred.add(path);
      }
    }
    return Right(inferred);
  }

  @override
  Future<Either<Failure, bool>> isGitDirectory(String directory) async {
    if (directoryFailure != null) {
      return Left(directoryFailure!);
    }
    return Right(gitDirectories.contains(directory.trim()));
  }

  @override
  Future<Either<Failure, List<FileNode>>> listFiles({
    String? directory,
    required String path,
  }) async {
    if (listFilesDelay != null) {
      await listFilesDelay!(path);
    }
    if (directoryFailure != null) {
      return Left(directoryFailure!);
    }
    final key = path.trim();
    final pathFailure = fileFailuresByPath[key];
    if (pathFailure != null) {
      return Left(pathFailure);
    }
    final queued = queuedFilesByPath[key];
    if (queued != null && queued.isNotEmpty) {
      return Right(List<FileNode>.from(queued.removeAt(0)));
    }
    final seeded = filesByPath[key];
    if (seeded != null) {
      return Right(List<FileNode>.from(seeded));
    }
    return const Right(<FileNode>[]);
  }

  @override
  Future<Either<Failure, List<FileNode>>> findFiles({
    String? directory,
    required String query,
    String? type,
    int limit = 50,
  }) async {
    if (findFilesDelay != null) {
      await findFilesDelay!(query);
    }
    if (directoryFailure != null) {
      return Left(directoryFailure!);
    }
    final normalized = query.trim().toLowerCase();
    final seeded = searchResultsByQuery[normalized];
    if (seeded != null) {
      final filtered = type == null
          ? seeded
          : seeded.where((item) {
              switch (type.trim().toLowerCase()) {
                case 'directory':
                  return item.isDirectory;
                case 'file':
                  return item.isFile;
                default:
                  return true;
              }
            });
      return Right(List<FileNode>.from(filtered.take(limit)));
    }
    return const Right(<FileNode>[]);
  }

  @override
  Future<Either<Failure, List<FileSearchMatch>>> searchFileContents({
    String? directory,
    required String pattern,
    int limit = 50,
  }) async {
    if (directoryFailure != null) {
      return Left(directoryFailure!);
    }
    final normalized = pattern.trim().toLowerCase();
    final seeded = contentSearchResultsByPattern[normalized];
    if (seeded != null) {
      return Right(List<FileSearchMatch>.from(seeded.take(limit)));
    }
    return const Right(<FileSearchMatch>[]);
  }

  @override
  Future<Either<Failure, List<WorkspaceSymbol>>> findSymbols({
    String? directory,
    required String query,
    int limit = 10,
  }) async {
    if (directoryFailure != null) {
      return Left(directoryFailure!);
    }
    final normalized = query.trim().toLowerCase();
    final seeded = symbolsByQuery[normalized];
    if (seeded != null) {
      return Right(List<WorkspaceSymbol>.from(seeded.take(limit)));
    }
    return const Right(<WorkspaceSymbol>[]);
  }

  @override
  Future<Either<Failure, FileContent>> readFileContent({
    String? directory,
    required String path,
  }) async {
    readFileContentCallCount += 1;
    final handler = readFileContentHandler;
    if (handler != null) {
      return handler(directory: directory, path: path);
    }
    if (fileContentFailure != null) {
      return Left(fileContentFailure!);
    }
    if (directoryFailure != null) {
      return Left(directoryFailure!);
    }
    final normalized = path.trim();
    final seeded = fileContentsByPath[normalized];
    if (seeded != null) {
      return Right(seeded);
    }
    return Right(FileContent(path: normalized, content: '', isBinary: false));
  }
}

class FakeWorkspaceFileOperationsService
    implements WorkspaceFileOperationsService {
  FakeWorkspaceFileOperationsService({
    this.capabilities = const WorkspaceFileOperationsCapabilities(
      shellFileOpsSupported: false,
      message: 'unsupported',
    ),
  });

  WorkspaceFileOperationsCapabilities capabilities;
  WorkspaceFileOperationResult? createFileResult;
  WorkspaceFileOperationResult? createFolderResult;
  WorkspaceFileOperationResult? renameResult;
  WorkspaceFileOperationResult? duplicateFileResult;
  WorkspaceFileOperationResult? deleteResult;
  WorkspaceFileOperationResult? writeFileResult;
  Future<void> Function({
    required String rootDirectory,
    required String parentDirectory,
    required String name,
  })?
  onCreateFile;
  Future<void> Function({
    required String rootDirectory,
    required String parentDirectory,
    required String name,
  })?
  onCreateFolder;
  Future<void> Function({
    required String rootDirectory,
    required String parentDirectory,
    required String oldName,
    required String newName,
  })?
  onRename;
  Future<void> Function({
    required String rootDirectory,
    required String parentDirectory,
    required String sourceName,
    required String destinationName,
  })?
  onDuplicateFile;
  Future<void> Function({
    required String rootDirectory,
    required String parentDirectory,
    required String name,
  })?
  onDelete;
  Future<void> Function({
    required String rootDirectory,
    required String path,
    required String content,
  })?
  onWriteFile;

  int capabilitiesCallCount = 0;
  int createFileCallCount = 0;
  int createFolderCallCount = 0;
  int renameCallCount = 0;
  int duplicateFileCallCount = 0;
  int deleteCallCount = 0;
  int writeFileCallCount = 0;
  String? lastParentDirectory;
  String? lastName;
  String? lastNewName;
  String? lastServerScopeKey;
  String? lastPath;
  String? lastContent;

  @override
  Future<WorkspaceFileOperationsCapabilities> getCapabilities({
    required String serverScopeKey,
    required String directory,
  }) async {
    capabilitiesCallCount += 1;
    return capabilities;
  }

  @override
  Future<void> invalidateCapabilities({
    required String serverScopeKey,
    required String directory,
  }) async {}

  @override
  Future<WorkspaceFileOperationResult> createFile({
    required String serverScopeKey,
    required String rootDirectory,
    required String parentDirectory,
    required String name,
  }) async {
    createFileCallCount += 1;
    lastParentDirectory = parentDirectory;
    lastName = name;
    await onCreateFile?.call(
      rootDirectory: rootDirectory,
      parentDirectory: parentDirectory,
      name: name,
    );
    return createFileResult ??
        WorkspaceFileOperationResult(
          ok: true,
          code: WorkspaceFileOperationCode.ok,
          message: 'ok',
          path: _joinPath(parentDirectory, name),
        );
  }

  @override
  Future<WorkspaceFileOperationResult> createFolder({
    required String serverScopeKey,
    required String rootDirectory,
    required String parentDirectory,
    required String name,
  }) async {
    createFolderCallCount += 1;
    lastParentDirectory = parentDirectory;
    lastName = name;
    await onCreateFolder?.call(
      rootDirectory: rootDirectory,
      parentDirectory: parentDirectory,
      name: name,
    );
    return createFolderResult ??
        WorkspaceFileOperationResult(
          ok: true,
          code: WorkspaceFileOperationCode.ok,
          message: 'ok',
          path: _joinPath(parentDirectory, name),
        );
  }

  @override
  Future<WorkspaceFileOperationResult> rename({
    required String serverScopeKey,
    required String rootDirectory,
    required String parentDirectory,
    required String oldName,
    required String newName,
  }) async {
    renameCallCount += 1;
    lastParentDirectory = parentDirectory;
    lastName = oldName;
    lastNewName = newName;
    await onRename?.call(
      rootDirectory: rootDirectory,
      parentDirectory: parentDirectory,
      oldName: oldName,
      newName: newName,
    );
    return renameResult ??
        WorkspaceFileOperationResult(
          ok: true,
          code: WorkspaceFileOperationCode.ok,
          message: 'ok',
          path: _joinPath(parentDirectory, oldName),
          newPath: _joinPath(parentDirectory, newName),
        );
  }

  @override
  Future<WorkspaceFileOperationResult> duplicateFile({
    required String serverScopeKey,
    required String rootDirectory,
    required String parentDirectory,
    required String sourceName,
    required String destinationName,
  }) async {
    duplicateFileCallCount += 1;
    lastParentDirectory = parentDirectory;
    lastName = sourceName;
    lastNewName = destinationName;
    await onDuplicateFile?.call(
      rootDirectory: rootDirectory,
      parentDirectory: parentDirectory,
      sourceName: sourceName,
      destinationName: destinationName,
    );
    return duplicateFileResult ??
        WorkspaceFileOperationResult(
          ok: true,
          code: WorkspaceFileOperationCode.ok,
          message: 'ok',
          path: _joinPath(parentDirectory, sourceName),
          newPath: _joinPath(parentDirectory, destinationName),
        );
  }

  @override
  Future<WorkspaceFileOperationResult> delete({
    required String serverScopeKey,
    required String rootDirectory,
    required String parentDirectory,
    required String name,
  }) async {
    deleteCallCount += 1;
    lastParentDirectory = parentDirectory;
    lastName = name;
    await onDelete?.call(
      rootDirectory: rootDirectory,
      parentDirectory: parentDirectory,
      name: name,
    );
    return deleteResult ??
        WorkspaceFileOperationResult(
          ok: true,
          code: WorkspaceFileOperationCode.ok,
          message: 'ok',
          path: _joinPath(parentDirectory, name),
        );
  }

  @override
  Future<WorkspaceFileOperationResult> writeFile({
    required String serverScopeKey,
    required String rootDirectory,
    required String path,
    required String content,
  }) async {
    writeFileCallCount += 1;
    lastServerScopeKey = serverScopeKey;
    lastPath = path;
    lastContent = content;
    await onWriteFile?.call(
      rootDirectory: rootDirectory,
      path: path,
      content: content,
    );
    return writeFileResult ??
        WorkspaceFileOperationResult(
          ok: true,
          code: WorkspaceFileOperationCode.ok,
          message: 'ok',
          path: path,
        );
  }

  String _joinPath(String parent, String name) {
    if (parent == '/') {
      return '/$name';
    }
    return '$parent/$name';
  }
}

DioException dioConnectionError([String message = 'connection error']) {
  return DioException(
    requestOptions: RequestOptions(path: '/'),
    type: DioExceptionType.connectionError,
    message: message,
  );
}
