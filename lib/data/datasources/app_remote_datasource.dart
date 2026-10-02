import 'package:dio/dio.dart';

import '../../core/errors/exceptions.dart';
import '../../core/logging/app_logger.dart';
import '../../core/network/opencode_connection_response.dart';
import '../models/agent_model.dart';
import '../models/app_info_model.dart';
import '../models/provider_model.dart';

/// Technical comment translated to English.
abstract class AppRemoteDataSource {
  /// Technical comment translated to English.
  Future<AppInfoModel> getAppInfo({String? directory});

  /// Technical comment translated to English.
  Future<bool> initializeApp({String? directory});

  /// Technical comment translated to English.
  Future<ProvidersResponseModel> getProviders({String? directory});

  /// Technical comment translated to English.
  Future<List<AgentModel>> getAgents({String? directory});

  /// Technical comment translated to English.
  Future<Map<String, dynamic>> getConfig({String? directory});
}

/// Technical comment translated to English.
class AppRemoteDataSourceImpl implements AppRemoteDataSource {

  AppRemoteDataSourceImpl({required this.dio});
  final dynamic dio;

  static const List<String> _agentResponseListKeys = <String>[
    'agents',
    'items',
    'data',
    'results',
  ];

  Map<String, dynamic> _workspaceAwareQueryParameters(String? directory) {
    final normalizedDirectory = directory?.trim();
    if (normalizedDirectory == null || normalizedDirectory.isEmpty) {
      return <String, dynamic>{};
    }
    return <String, dynamic>{
      'directory': normalizedDirectory,
      'workspace': normalizedDirectory,
    };
  }

  Map<String, dynamic> _directoryOnlyQueryParameters(String? directory) {
    final normalizedDirectory = directory?.trim();
    if (normalizedDirectory == null || normalizedDirectory.isEmpty) {
      return <String, dynamic>{};
    }
    return <String, dynamic>{'directory': normalizedDirectory};
  }

  List<AgentModel> _agentModelsFromIterable(Iterable<dynamic> items) {
    return items
        .whereType<Map>()
        .map((item) => AgentModel.fromJson(Map<String, dynamic>.from(item)))
        .where((item) => item.name.trim().isNotEmpty)
        .toList(growable: false);
  }

  List<AgentModel> _parseAgentPayload(dynamic payload) {
    if (payload is List) {
      return _agentModelsFromIterable(payload);
    }
    if (payload is! Map) {
      return const <AgentModel>[];
    }

    final map = Map<String, dynamic>.from(payload);

    for (final key in _agentResponseListKeys) {
      final nested = map[key];
      if (nested is List) {
        final parsed = _agentModelsFromIterable(nested);
        if (parsed.isNotEmpty) {
          return parsed;
        }
      }
    }

    final grouped = <Map<String, dynamic>>[];
    for (final entry in map.entries) {
      final groupKey = entry.key.toString().trim();
      final value = entry.value;
      if (value is List) {
        for (final rawItem in value.whereType<Map>()) {
          final item = Map<String, dynamic>.from(rawItem);
          item.putIfAbsent('mode', () => groupKey);
          grouped.add(item);
        }
      }
    }
    if (grouped.isNotEmpty) {
      return _agentModelsFromIterable(grouped);
    }

    final keyed = <Map<String, dynamic>>[];
    for (final entry in map.entries) {
      final name = entry.key.toString().trim();
      final value = entry.value;
      if (name.isEmpty || value is! Map) {
        continue;
      }
      final item = Map<String, dynamic>.from(value);
      item.putIfAbsent('name', () => name);
      keyed.add(item);
    }
    if (keyed.isNotEmpty) {
      return _agentModelsFromIterable(keyed);
    }

    return const <AgentModel>[];
  }

  Future<List<AgentModel>> _fetchAgentsWithQuery(
    Map<String, dynamic> queryParams,
  ) async {
    final response = await dio.get(
      '/agent',
      queryParameters: queryParams.isEmpty ? null : queryParams,
    );
    return _parseAgentPayload(response.data);
  }

  Future<dynamic> _getWithScopedFallback(
    String path, {
    required String logLabel,
    String? directory,
  }) async {
    final workspaceQueryParams = _workspaceAwareQueryParameters(directory);
    if (workspaceQueryParams.isEmpty) {
      final response = await dio.get(path);
      return response.data;
    }

    try {
      final response = await dio.get(path, queryParameters: workspaceQueryParams);
      return response.data;
    } on Exception catch (workspaceError, workspaceStackTrace) {
      AppLogger.warn(
        '$logLabel failed with workspace-scoped query; retrying fallback queries',
        error: workspaceError,
        stackTrace: workspaceStackTrace,
      );
    }

    final directoryOnlyQueryParams = _directoryOnlyQueryParameters(directory);
    if (directoryOnlyQueryParams.isNotEmpty) {
      try {
        final response = await dio.get(
          path,
          queryParameters: directoryOnlyQueryParams,
        );
        AppLogger.warn('$logLabel recovered with directory-only fallback query');
        return response.data;
      } on Exception catch (directoryError, directoryStackTrace) {
        AppLogger.warn(
          '$logLabel directory-only fallback failed; retrying unscoped query',
          error: directoryError,
          stackTrace: directoryStackTrace,
        );
      }
    }

    final response = await dio.get(path);
    AppLogger.warn('$logLabel recovered with unscoped fallback query');
    return response.data;
  }

  @override
  Future<AppInfoModel> getAppInfo({String? directory}) async {
    final queryParams = directory != null
        ? {'directory': directory}
        : <String, dynamic>{};

    // Current API uses GET /path. Keep /app as fallback for older servers.
    try {
      final response = await dio.get(
        '/path',
        queryParameters: queryParams,
        options: Options(responseType: ResponseType.plain),
      );
      return _appInfoFromPath(decodeOpenCodePath(response.data));
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (status != 404 && status != 405) rethrow;
    } on ParseException {
      // Older servers can return their web shell for an unavailable /path.
      // Keep the existing fallback, but require a valid legacy response.
    }

    final legacy = await dio.get(
      '/app',
      queryParameters: queryParams,
      options: Options(responseType: ResponseType.plain),
    );
    final data = decodeOpenCodeObject(legacy.data, '/app');
    try {
      return AppInfoModel.fromJson(data);
    } on TypeError {
      throw const ParseException('Invalid legacy OpenCode response from /app.');
    }
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
    final data = await _getWithScopedFallback(
      '/provider',
      logLabel: 'Provider discovery',
      directory: directory,
    );
    return ProvidersResponseModel.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<List<AgentModel>> getAgents({String? directory}) async {
    final workspaceQueryParams = _workspaceAwareQueryParameters(directory);
    List<AgentModel> scopedAgents;
    try {
      scopedAgents = await _fetchAgentsWithQuery(workspaceQueryParams);
    } on Exception catch (workspaceError, workspaceStackTrace) {
      AppLogger.warn(
        'Agent discovery failed with workspace-scoped query; retrying fallback queries',
        error: workspaceError,
        stackTrace: workspaceStackTrace,
      );
      scopedAgents = const <AgentModel>[];
    }
    if (scopedAgents.isNotEmpty || workspaceQueryParams.isEmpty) {
      return scopedAgents;
    }

    final directoryOnlyQueryParams = _directoryOnlyQueryParameters(directory);
    if (directoryOnlyQueryParams.isNotEmpty) {
      try {
        final directoryOnlyAgents = await _fetchAgentsWithQuery(
          directoryOnlyQueryParams,
        );
        if (directoryOnlyAgents.isNotEmpty) {
          AppLogger.warn(
            'Agent discovery required directory-only fallback query',
          );
          return directoryOnlyAgents;
        }
      } on Exception catch (directoryError, directoryStackTrace) {
        AppLogger.warn(
          'Agent discovery directory-only fallback failed; retrying unscoped query',
          error: directoryError,
          stackTrace: directoryStackTrace,
        );
      }
    }

    final unscopedAgents = await _fetchAgentsWithQuery(const <String, dynamic>{});
    if (unscopedAgents.isNotEmpty) {
      AppLogger.warn('Agent discovery required unscoped fallback query');
    }
    return unscopedAgents;
  }

  @override
  Future<Map<String, dynamic>> getConfig({String? directory}) async {
    final data = await _getWithScopedFallback(
      '/config',
      logLabel: 'Config discovery',
      directory: directory,
    );
    return data as Map<String, dynamic>;
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
