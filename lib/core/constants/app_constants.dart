/// Application level constants definition
class AppConstants {
  // App information
  static const String appName = 'CodeWalk';
  static const String appSubtitle = 'A Mobile Client for OpenCode';
  static const String appVersion = '1.0.0';
  static const String appDescription = 'CodeWalk - Mobile client for OpenCode';

  // Storage keys
  static const String serverHostKey = 'server_host';
  static const String serverPortKey = 'server_port';
  static const String serverProfilesKey = 'server_profiles';
  static const String activeServerIdKey = 'active_server_id';
  static const String defaultServerIdKey = 'default_server_id';
  static const String storageSchemaVersionKey = 'storage_schema_version';
  static const String migrationV1ToV2CompletedKey =
      'migration_v1_to_v2_completed';
  static const String apiKeyKey = 'api_key';
  static const String selectedProviderKey = 'selected_provider';
  static const String selectedModelKey = 'selected_model';
  static const String selectedVariantMapKey = 'selected_variant_map';
  static const String recentModelsKey = 'recent_models';
  static const String modelUsageCountsKey = 'model_usage_counts';
  static const String themeKey = 'theme_mode';
  static const String lastSessionIdKey = 'last_session_id';
  static const String cachedSessionsKey = 'cached_sessions';
  static const String cachedSessionsUpdatedAtKey = 'cached_sessions_updated_at';
  static const String currentSessionIdKey = 'current_session_id';
  static const String currentProjectIdKey = 'current_project_id';
  static const String openProjectIdsKey = 'open_project_ids';

  // Basic auth storage keys
  static const String basicAuthEnabledKey = 'basic_auth_enabled';
  static const String basicAuthUsernameKey = 'basic_auth_username';
  static const String basicAuthPasswordKey = 'basic_auth_password';

  // Default configuration
  static const String defaultTheme = 'system';
  static const int maxMessageLength = 10000;
  static const int maxFileSize = 10 * 1024 * 1024; // 10MB

  // UI constants
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;
  static const double borderRadius = 12.0;
  static const double smallBorderRadius = 8.0;

  // Animation duration
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 300);
  static const Duration longAnimation = Duration(milliseconds: 500);

  // Error messages
  static const String networkError = 'Network connection error';
  static const String serverError = 'Server error';
  static const String unknownError = 'Unknown error';
  static const String connectionTimeout = 'Connection timeout';
  static const String invalidResponse = 'Invalid response';
}
