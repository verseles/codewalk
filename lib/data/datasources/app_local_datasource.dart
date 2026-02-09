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
  Future<String?> getApiKey();

  /// Technical comment translated to English.
  Future<void> saveApiKey(String apiKey);

  /// Technical comment translated to English.
  Future<String?> getSelectedProvider();

  /// Technical comment translated to English.
  Future<void> saveSelectedProvider(String providerId);

  /// Technical comment translated to English.
  Future<String?> getSelectedModel();

  /// Technical comment translated to English.
  Future<void> saveSelectedModel(String modelId);

  /// Technical comment translated to English.
  Future<String?> getThemeMode();

  /// Technical comment translated to English.
  Future<void> saveThemeMode(String themeMode);

  /// Technical comment translated to English.
  Future<String?> getLastSessionId();

  /// Technical comment translated to English.
  Future<void> saveLastSessionId(String sessionId);

  /// Technical comment translated to English.
  Future<String?> getCurrentSessionId();

  /// Technical comment translated to English.
  Future<void> saveCurrentSessionId(String sessionId);

  /// Technical comment translated to English.
  Future<String?> getCachedSessions();

  /// Technical comment translated to English.
  Future<void> saveCachedSessions(String sessionsJson);

  /// Technical comment translated to English.
  Future<bool?> getBasicAuthEnabled();

  /// Technical comment translated to English.
  Future<void> saveBasicAuthEnabled(bool enabled);

  /// Technical comment translated to English.
  Future<String?> getBasicAuthUsername();

  /// Technical comment translated to English.
  Future<void> saveBasicAuthUsername(String username);

  /// Technical comment translated to English.
  Future<String?> getBasicAuthPassword();

  /// Technical comment translated to English.
  Future<void> saveBasicAuthPassword(String password);

  /// Technical comment translated to English.
  Future<void> clearAll();
}

/// Technical comment translated to English.
class AppLocalDataSourceImpl implements AppLocalDataSource {
  final SharedPreferences sharedPreferences;

  AppLocalDataSourceImpl({required this.sharedPreferences});

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
  Future<String?> getApiKey() async {
    return sharedPreferences.getString(AppConstants.apiKeyKey);
  }

  @override
  Future<void> saveApiKey(String apiKey) async {
    await sharedPreferences.setString(AppConstants.apiKeyKey, apiKey);
  }

  @override
  Future<String?> getSelectedProvider() async {
    return sharedPreferences.getString(AppConstants.selectedProviderKey);
  }

  @override
  Future<void> saveSelectedProvider(String providerId) async {
    await sharedPreferences.setString(
      AppConstants.selectedProviderKey,
      providerId,
    );
  }

  @override
  Future<String?> getSelectedModel() async {
    return sharedPreferences.getString(AppConstants.selectedModelKey);
  }

  @override
  Future<void> saveSelectedModel(String modelId) async {
    await sharedPreferences.setString(AppConstants.selectedModelKey, modelId);
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
  Future<String?> getLastSessionId() async {
    return sharedPreferences.getString(AppConstants.lastSessionIdKey);
  }

  @override
  Future<void> saveLastSessionId(String sessionId) async {
    await sharedPreferences.setString(AppConstants.lastSessionIdKey, sessionId);
  }

  @override
  Future<String?> getCurrentSessionId() async {
    return sharedPreferences.getString(AppConstants.currentSessionIdKey);
  }

  @override
  Future<void> saveCurrentSessionId(String sessionId) async {
    await sharedPreferences.setString(
      AppConstants.currentSessionIdKey,
      sessionId,
    );
  }

  @override
  Future<String?> getCachedSessions() async {
    return sharedPreferences.getString(AppConstants.cachedSessionsKey);
  }

  @override
  Future<void> saveCachedSessions(String sessionsJson) async {
    await sharedPreferences.setString(
      AppConstants.cachedSessionsKey,
      sessionsJson,
    );
  }

  @override
  Future<bool?> getBasicAuthEnabled() async {
    return sharedPreferences.getBool(AppConstants.basicAuthEnabledKey);
  }

  @override
  Future<void> saveBasicAuthEnabled(bool enabled) async {
    await sharedPreferences.setBool(AppConstants.basicAuthEnabledKey, enabled);
  }

  @override
  Future<String?> getBasicAuthUsername() async {
    return sharedPreferences.getString(AppConstants.basicAuthUsernameKey);
  }

  @override
  Future<void> saveBasicAuthUsername(String username) async {
    await sharedPreferences.setString(
      AppConstants.basicAuthUsernameKey,
      username,
    );
  }

  @override
  Future<String?> getBasicAuthPassword() async {
    return sharedPreferences.getString(AppConstants.basicAuthPasswordKey);
  }

  @override
  Future<void> saveBasicAuthPassword(String password) async {
    await sharedPreferences.setString(
      AppConstants.basicAuthPasswordKey,
      password,
    );
  }

  @override
  Future<void> clearAll() async {
    await sharedPreferences.clear();
  }
}
