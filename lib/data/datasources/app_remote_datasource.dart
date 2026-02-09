import '../models/provider_model.dart';
import '../models/app_info_model.dart';
import '../../core/logging/app_logger.dart';

/// Technical comment translated to English.
abstract class AppRemoteDataSource {
  /// Technical comment translated to English.
  Future<AppInfoModel> getAppInfo({String? directory});

  /// Technical comment translated to English.
  Future<bool> initializeApp({String? directory});

  /// Technical comment translated to English.
  Future<ProvidersResponseModel> getProviders({String? directory});

  /// Technical comment translated to English.
  Future<Map<String, dynamic>> getConfig({String? directory});
}

/// Technical comment translated to English.
class AppRemoteDataSourceImpl implements AppRemoteDataSource {
  final dynamic dio;

  AppRemoteDataSourceImpl({required this.dio});

  @override
  Future<AppInfoModel> getAppInfo({String? directory}) async {
    final queryParams = directory != null
        ? {'directory': directory}
        : <String, dynamic>{};

    // Current API uses GET /path. Keep /app as fallback for older servers.
    try {
      final response = await dio.get('/path', queryParameters: queryParams);
      if (response.data is Map<String, dynamic>) {
        return _appInfoFromPath(response.data as Map<String, dynamic>);
      }
    } catch (_) {
      // Fallback below
    }

    final legacy = await dio.get('/app', queryParameters: queryParams);
    return AppInfoModel.fromJson(legacy.data as Map<String, dynamic>);
  }

  @override
  Future<bool> initializeApp({String? directory}) async {
    final queryParams = directory != null
        ? {'directory': directory}
        : <String, dynamic>{};

    // Newer servers do not expose /app/init; use /path as readiness probe.
    try {
      final response = await dio.get('/path', queryParameters: queryParams);
      return response.statusCode == 200;
    } catch (e) {
      // Backward compatibility for older instances that still support /app/init.
      try {
        final response = await dio.post(
          '/app/init',
          queryParameters: queryParams,
        );
        if (response.data is Map<String, dynamic>) {
          return (response.data as Map<String, dynamic>)['success'] ?? true;
        }
        return response.statusCode == 200;
      } catch (legacyError) {
        AppLogger.error(
          'Error while initializing app with /path fallback',
          error: e,
        );
        AppLogger.error('Legacy init failed (/app/init)', error: legacyError);
        return false;
      }
    }
  }

  @override
  Future<ProvidersResponseModel> getProviders({String? directory}) async {
    final queryParams = directory != null
        ? {'directory': directory}
        : <String, dynamic>{};
    final response = await dio.get('/provider', queryParameters: queryParams);
    return ProvidersResponseModel.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  @override
  Future<Map<String, dynamic>> getConfig({String? directory}) async {
    final queryParams = directory != null
        ? {'directory': directory}
        : <String, dynamic>{};
    final response = await dio.get('/config', queryParameters: queryParams);
    return response.data as Map<String, dynamic>;
  }

  AppInfoModel _appInfoFromPath(Map<String, dynamic> pathData) {
    final configPath = pathData['config'] as String? ?? '';
    final statePath = pathData['state'] as String? ?? '';
    final worktreePath =
        (pathData['worktree'] as String?) ??
        (pathData['root'] as String?) ??
        '';
    final directoryPath =
        (pathData['directory'] as String?) ??
        (pathData['cwd'] as String?) ??
        '';
    final homePath = pathData['home'] as String? ?? '';

    return AppInfoModel(
      hostname: _extractHostFromBaseUrl(),
      git: false,
      path: AppPathModel(
        config: configPath,
        data: homePath.isNotEmpty ? homePath : statePath,
        root: worktreePath,
        cwd: directoryPath,
        state: statePath,
      ),
      time: null,
    );
  }

  String _extractHostFromBaseUrl() {
    try {
      final baseUrl = dio.options.baseUrl as String?;
      if (baseUrl != null && baseUrl.isNotEmpty) {
        final host = Uri.parse(baseUrl).host;
        if (host.isNotEmpty) {
          return host;
        }
      }
    } catch (_) {
      // Keep fallback below
    }
    return 'unknown';
  }
}
