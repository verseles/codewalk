import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';

/// Technical comment translated to English.
abstract class AppLocalDataSource {
  /// Technical comment translated to English.
  Future<String?> getServerHost();

  /// Technical comment translated to English.
  Future<void> saveServerHost(String host);

  /// Technical comment translated to English.
  Future<int?> getServerPort();

  /// Technical comment translated to English.
  Future<void> saveServerPort(int port);

  /// Technical comment translated to English.
  Future<String?> getServerProfilesJson();

  /// Technical comment translated to English.
  Future<void> saveServerProfilesJson(String profilesJson);

  /// Technical comment translated to English.
  Future<String?> getActiveServerId();

  /// Technical comment translated to English.
  Future<void> saveActiveServerId(String serverId);

  /// Technical comment translated to English.
  Future<String?> getDefaultServerId();

  /// Technical comment translated to English.
  Future<void> saveDefaultServerId(String? serverId);

  /// Technical comment translated to English.
  Future<String?> getApiKey({String? serverId});

  /// Technical comment translated to English.
  Future<void> saveApiKey(String apiKey, {String? serverId});

  /// Technical comment translated to English.
  Future<String?> getSelectedProvider({String? serverId, String? scopeId});

  /// Technical comment translated to English.
  Future<void> saveSelectedProvider(
    String providerId, {
    String? serverId,
    String? scopeId,
  });

  /// Technical comment translated to English.
  Future<String?> getSelectedModel({String? serverId, String? scopeId});

  /// Technical comment translated to English.
  Future<void> saveSelectedModel(
    String modelId, {
    String? serverId,
    String? scopeId,
  });

  /// Technical comment translated to English.
  Future<String?> getSelectedAgent({String? serverId, String? scopeId});

  /// Technical comment translated to English.
  Future<void> saveSelectedAgent(
    String? agentName, {
    String? serverId,
    String? scopeId,
  });

  /// Technical comment translated to English.
  Future<String?> getSelectedVariantMap({String? serverId, String? scopeId});

  /// Technical comment translated to English.
  Future<void> saveSelectedVariantMap(
    String variantMapJson, {
    String? serverId,
    String? scopeId,
  });

  /// Technical comment translated to English.
  Future<String?> getRecentModelsJson({String? serverId, String? scopeId});

  /// Technical comment translated to English.
  Future<void> saveRecentModelsJson(
    String recentModelsJson, {
    String? serverId,
    String? scopeId,
  });

  /// Technical comment translated to English.
  Future<String?> getModelUsageCountsJson({String? serverId, String? scopeId});

  /// Technical comment translated to English.
  Future<void> saveModelUsageCountsJson(
    String usageCountsJson, {
    String? serverId,
    String? scopeId,
  });

  /// Technical comment translated to English.
  Future<String?> getThemeMode();

  /// Technical comment translated to English.
  Future<void> saveThemeMode(String themeMode);

  /// Technical comment translated to English.
  Future<String?> getExperienceSettingsJson();

  /// Technical comment translated to English.
  Future<void> saveExperienceSettingsJson(String settingsJson);

  /// Technical comment translated to English.
  Future<String?> getLastSessionId();

  /// Technical comment translated to English.
  Future<void> saveLastSessionId(
    String sessionId, {
    String? serverId,
    String? scopeId,
  });

  /// Technical comment translated to English.
  Future<String?> getCurrentSessionId({String? serverId, String? scopeId});

  /// Technical comment translated to English.
  Future<void> saveCurrentSessionId(
    String sessionId, {
    String? serverId,
    String? scopeId,
  });

  /// Technical comment translated to English.
  Future<String?> getCurrentProjectId({String? serverId});

  /// Technical comment translated to English.
  Future<void> saveCurrentProjectId(String projectId, {String? serverId});

  /// Technical comment translated to English.
  Future<String?> getOpenProjectIdsJson({String? serverId});

  /// Technical comment translated to English.
  Future<void> saveOpenProjectIdsJson(
    String projectIdsJson, {
    String? serverId,
  });

  /// Technical comment translated to English.
  Future<String?> getCachedSessions({String? serverId, String? scopeId});

  /// Technical comment translated to English.
  Future<void> saveCachedSessions(
    String sessionsJson, {
    String? serverId,
    String? scopeId,
  });

  /// Technical comment translated to English.
  Future<int?> getCachedSessionsUpdatedAt({String? serverId, String? scopeId});

  /// Technical comment translated to English.
  Future<void> saveCachedSessionsUpdatedAt(
    int epochMs, {
    String? serverId,
    String? scopeId,
  });

  /// Technical comment translated to English.
  Future<void> clearChatContextCache({
    required String serverId,
    required String scopeId,
  });

  /// Technical comment translated to English.
  Future<bool?> getBasicAuthEnabled({String? serverId});

  /// Technical comment translated to English.
  Future<void> saveBasicAuthEnabled(bool enabled, {String? serverId});

  /// Technical comment translated to English.
  Future<String?> getBasicAuthUsername({String? serverId});

  /// Technical comment translated to English.
  Future<void> saveBasicAuthUsername(String username, {String? serverId});

  /// Technical comment translated to English.
  Future<String?> getBasicAuthPassword({String? serverId});

  /// Technical comment translated to English.
  Future<void> saveBasicAuthPassword(String password, {String? serverId});

  /// Technical comment translated to English.
  Future<void> clearAll();
}

/// Technical comment translated to English.
class AppLocalDataSourceImpl implements AppLocalDataSource {
  final SharedPreferences sharedPreferences;

  AppLocalDataSourceImpl({required this.sharedPreferences});

  String _scopedKey(String base, {String? serverId, String? scopeId}) {
    final scopedServer = serverId?.trim();
    if (scopedServer == null || scopedServer.isEmpty) {
      return base;
    }
    final encodedServer = Uri.encodeComponent(scopedServer);
    final scopedContext = scopeId?.trim();
    if (scopedContext == null || scopedContext.isEmpty) {
      return '$base::$encodedServer';
    }
    final encodedContext = Uri.encodeComponent(scopedContext);
    return '$base::$encodedServer::$encodedContext';
  }

  @override
  Future<String?> getServerHost() async {
    return sharedPreferences.getString(AppConstants.serverHostKey);
  }

  @override
  Future<void> saveServerHost(String host) async {
    await sharedPreferences.setString(AppConstants.serverHostKey, host);
  }

  @override
  Future<int?> getServerPort() async {
    return sharedPreferences.getInt(AppConstants.serverPortKey);
  }

  @override
  Future<void> saveServerPort(int port) async {
    await sharedPreferences.setInt(AppConstants.serverPortKey, port);
  }

  @override
  Future<String?> getServerProfilesJson() async {
    return sharedPreferences.getString(AppConstants.serverProfilesKey);
  }

  @override
  Future<void> saveServerProfilesJson(String profilesJson) async {
    await sharedPreferences.setString(
      AppConstants.serverProfilesKey,
      profilesJson,
    );
  }

  @override
  Future<String?> getActiveServerId() async {
    return sharedPreferences.getString(AppConstants.activeServerIdKey);
  }

  @override
  Future<void> saveActiveServerId(String serverId) async {
    await sharedPreferences.setString(AppConstants.activeServerIdKey, serverId);
  }

  @override
  Future<String?> getDefaultServerId() async {
    return sharedPreferences.getString(AppConstants.defaultServerIdKey);
  }

  @override
  Future<void> saveDefaultServerId(String? serverId) async {
    if (serverId == null || serverId.trim().isEmpty) {
      await sharedPreferences.remove(AppConstants.defaultServerIdKey);
      return;
    }
    await sharedPreferences.setString(
      AppConstants.defaultServerIdKey,
      serverId,
    );
  }

  @override
  Future<String?> getApiKey({String? serverId}) async {
    return sharedPreferences.getString(
      _scopedKey(AppConstants.apiKeyKey, serverId: serverId),
    );
  }

  @override
  Future<void> saveApiKey(String apiKey, {String? serverId}) async {
    await sharedPreferences.setString(
      _scopedKey(AppConstants.apiKeyKey, serverId: serverId),
      apiKey,
    );
  }

  @override
  Future<String?> getSelectedProvider({
    String? serverId,
    String? scopeId,
  }) async {
    return sharedPreferences.getString(
      _scopedKey(
        AppConstants.selectedProviderKey,
        serverId: serverId,
        scopeId: scopeId,
      ),
    );
  }

  @override
  Future<void> saveSelectedProvider(
    String providerId, {
    String? serverId,
    String? scopeId,
  }) async {
    await sharedPreferences.setString(
      _scopedKey(
        AppConstants.selectedProviderKey,
        serverId: serverId,
        scopeId: scopeId,
      ),
      providerId,
    );
  }

  @override
  Future<String?> getSelectedModel({String? serverId, String? scopeId}) async {
    return sharedPreferences.getString(
      _scopedKey(
        AppConstants.selectedModelKey,
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
  }) async {
    await sharedPreferences.setString(
      _scopedKey(
        AppConstants.selectedModelKey,
        serverId: serverId,
        scopeId: scopeId,
      ),
      modelId,
    );
  }

  @override
  Future<String?> getSelectedAgent({String? serverId, String? scopeId}) async {
    return sharedPreferences.getString(
      _scopedKey(
        AppConstants.selectedAgentKey,
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
  }) async {
    final key = _scopedKey(
      AppConstants.selectedAgentKey,
      serverId: serverId,
      scopeId: scopeId,
    );
    if (agentName == null || agentName.trim().isEmpty) {
      await sharedPreferences.remove(key);
      return;
    }
    await sharedPreferences.setString(key, agentName);
  }

  @override
  Future<String?> getSelectedVariantMap({
    String? serverId,
    String? scopeId,
  }) async {
    return sharedPreferences.getString(
      _scopedKey(
        AppConstants.selectedVariantMapKey,
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
  }) async {
    await sharedPreferences.setString(
      _scopedKey(
        AppConstants.selectedVariantMapKey,
        serverId: serverId,
        scopeId: scopeId,
      ),
      variantMapJson,
    );
  }

  @override
  Future<String?> getRecentModelsJson({
    String? serverId,
    String? scopeId,
  }) async {
    return sharedPreferences.getString(
      _scopedKey(
        AppConstants.recentModelsKey,
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
  }) async {
    await sharedPreferences.setString(
      _scopedKey(
        AppConstants.recentModelsKey,
        serverId: serverId,
        scopeId: scopeId,
      ),
      recentModelsJson,
    );
  }

  @override
  Future<String?> getModelUsageCountsJson({
    String? serverId,
    String? scopeId,
  }) async {
    return sharedPreferences.getString(
      _scopedKey(
        AppConstants.modelUsageCountsKey,
        serverId: serverId,
        scopeId: scopeId,
      ),
    );
  }

  @override
  Future<void> saveModelUsageCountsJson(
    String usageCountsJson, {
    String? serverId,
    String? scopeId,
  }) async {
    await sharedPreferences.setString(
      _scopedKey(
        AppConstants.modelUsageCountsKey,
        serverId: serverId,
        scopeId: scopeId,
      ),
      usageCountsJson,
    );
  }

  @override
  Future<String?> getThemeMode() async {
    return sharedPreferences.getString(AppConstants.themeKey);
  }

  @override
  Future<void> saveThemeMode(String themeMode) async {
    await sharedPreferences.setString(AppConstants.themeKey, themeMode);
  }

  @override
  Future<String?> getExperienceSettingsJson() async {
    return sharedPreferences.getString(AppConstants.experienceSettingsKey);
  }

  @override
  Future<void> saveExperienceSettingsJson(String settingsJson) async {
    await sharedPreferences.setString(
      AppConstants.experienceSettingsKey,
      settingsJson,
    );
  }

  @override
  Future<String?> getLastSessionId() async {
    return sharedPreferences.getString(AppConstants.lastSessionIdKey);
  }

  @override
  Future<void> saveLastSessionId(
    String sessionId, {
    String? serverId,
    String? scopeId,
  }) async {
    await sharedPreferences.setString(
      _scopedKey(
        AppConstants.lastSessionIdKey,
        serverId: serverId,
        scopeId: scopeId,
      ),
      sessionId,
    );
  }

  @override
  Future<String?> getCurrentSessionId({
    String? serverId,
    String? scopeId,
  }) async {
    return sharedPreferences.getString(
      _scopedKey(
        AppConstants.currentSessionIdKey,
        serverId: serverId,
        scopeId: scopeId,
      ),
    );
  }

  @override
  Future<String?> getCurrentProjectId({String? serverId}) async {
    return sharedPreferences.getString(
      _scopedKey(AppConstants.currentProjectIdKey, serverId: serverId),
    );
  }

  @override
  Future<void> saveCurrentProjectId(
    String projectId, {
    String? serverId,
  }) async {
    await sharedPreferences.setString(
      _scopedKey(AppConstants.currentProjectIdKey, serverId: serverId),
      projectId,
    );
  }

  @override
  Future<String?> getOpenProjectIdsJson({String? serverId}) async {
    return sharedPreferences.getString(
      _scopedKey(AppConstants.openProjectIdsKey, serverId: serverId),
    );
  }

  @override
  Future<void> saveOpenProjectIdsJson(
    String projectIdsJson, {
    String? serverId,
  }) async {
    await sharedPreferences.setString(
      _scopedKey(AppConstants.openProjectIdsKey, serverId: serverId),
      projectIdsJson,
    );
  }

  @override
  Future<void> saveCurrentSessionId(
    String sessionId, {
    String? serverId,
    String? scopeId,
  }) async {
    await sharedPreferences.setString(
      _scopedKey(
        AppConstants.currentSessionIdKey,
        serverId: serverId,
        scopeId: scopeId,
      ),
      sessionId,
    );
  }

  @override
  Future<String?> getCachedSessions({String? serverId, String? scopeId}) async {
    return sharedPreferences.getString(
      _scopedKey(
        AppConstants.cachedSessionsKey,
        serverId: serverId,
        scopeId: scopeId,
      ),
    );
  }

  @override
  Future<void> saveCachedSessions(
    String sessionsJson, {
    String? serverId,
    String? scopeId,
  }) async {
    await sharedPreferences.setString(
      _scopedKey(
        AppConstants.cachedSessionsKey,
        serverId: serverId,
        scopeId: scopeId,
      ),
      sessionsJson,
    );
  }

  @override
  Future<int?> getCachedSessionsUpdatedAt({
    String? serverId,
    String? scopeId,
  }) async {
    return sharedPreferences.getInt(
      _scopedKey(
        AppConstants.cachedSessionsUpdatedAtKey,
        serverId: serverId,
        scopeId: scopeId,
      ),
    );
  }

  @override
  Future<void> saveCachedSessionsUpdatedAt(
    int epochMs, {
    String? serverId,
    String? scopeId,
  }) async {
    await sharedPreferences.setInt(
      _scopedKey(
        AppConstants.cachedSessionsUpdatedAtKey,
        serverId: serverId,
        scopeId: scopeId,
      ),
      epochMs,
    );
  }

  @override
  Future<void> clearChatContextCache({
    required String serverId,
    required String scopeId,
  }) async {
    final keys = <String>[
      _scopedKey(
        AppConstants.cachedSessionsKey,
        serverId: serverId,
        scopeId: scopeId,
      ),
      _scopedKey(
        AppConstants.cachedSessionsUpdatedAtKey,
        serverId: serverId,
        scopeId: scopeId,
      ),
      _scopedKey(
        AppConstants.currentSessionIdKey,
        serverId: serverId,
        scopeId: scopeId,
      ),
      _scopedKey(
        AppConstants.lastSessionIdKey,
        serverId: serverId,
        scopeId: scopeId,
      ),
    ];

    for (final key in keys) {
      await sharedPreferences.remove(key);
    }
  }

  @override
  Future<bool?> getBasicAuthEnabled({String? serverId}) async {
    return sharedPreferences.getBool(
      _scopedKey(AppConstants.basicAuthEnabledKey, serverId: serverId),
    );
  }

  @override
  Future<void> saveBasicAuthEnabled(bool enabled, {String? serverId}) async {
    await sharedPreferences.setBool(
      _scopedKey(AppConstants.basicAuthEnabledKey, serverId: serverId),
      enabled,
    );
  }

  @override
  Future<String?> getBasicAuthUsername({String? serverId}) async {
    return sharedPreferences.getString(
      _scopedKey(AppConstants.basicAuthUsernameKey, serverId: serverId),
    );
  }

  @override
  Future<void> saveBasicAuthUsername(
    String username, {
    String? serverId,
  }) async {
    await sharedPreferences.setString(
      _scopedKey(AppConstants.basicAuthUsernameKey, serverId: serverId),
      username,
    );
  }

  @override
  Future<String?> getBasicAuthPassword({String? serverId}) async {
    return sharedPreferences.getString(
      _scopedKey(AppConstants.basicAuthPasswordKey, serverId: serverId),
    );
  }

  @override
  Future<void> saveBasicAuthPassword(
    String password, {
    String? serverId,
  }) async {
    await sharedPreferences.setString(
      _scopedKey(AppConstants.basicAuthPasswordKey, serverId: serverId),
      password,
    );
  }

  @override
  Future<void> clearAll() async {
    await sharedPreferences.clear();
  }
}
