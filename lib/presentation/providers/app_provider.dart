import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/constants/api_constants.dart';
import '../../core/logging/app_logger.dart';
import '../../core/network/dio_client.dart';
import '../../data/datasources/app_local_datasource.dart';
import '../../domain/entities/app_info.dart';
import '../../domain/entities/server_profile.dart';
import '../../domain/usecases/check_connection.dart';
import '../../domain/usecases/get_app_info.dart';

enum AppStatus { initial, loading, loaded, error, disconnected }

enum ServerHealthStatus { unknown, healthy, unhealthy }

class AppProvider extends ChangeNotifier {
  AppProvider({
    required GetAppInfo getAppInfo,
    required CheckConnection checkConnection,
    required AppLocalDataSource localDataSource,
    required DioClient dioClient,
    bool enableHealthPolling = true,
  }) : _getAppInfo = getAppInfo,
       _checkConnection = checkConnection,
       _localDataSource = localDataSource,
       _dioClient = dioClient,
       _enableHealthPolling = enableHealthPolling;

  final GetAppInfo _getAppInfo;
  final CheckConnection _checkConnection;
  final AppLocalDataSource _localDataSource;
  final DioClient _dioClient;
  final bool _enableHealthPolling;

  AppStatus _status = AppStatus.initial;
  AppInfo? _appInfo;
  String _errorMessage = '';
  String _serverHost = ApiConstants.defaultHost;
  int _serverPort = ApiConstants.defaultPort;
  bool _isConnected = false;
  bool _initialized = false;
  Future<void>? _initFuture;
  Timer? _healthTimer;

  List<ServerProfile> _serverProfiles = <ServerProfile>[];
  String? _activeServerId;
  String? _defaultServerId;
  final Map<String, ServerHealthStatus> _serverHealthById =
      <String, ServerHealthStatus>{};

  AppStatus get status => _status;
  AppInfo? get appInfo => _appInfo;
  String get errorMessage => _errorMessage;
  String get serverHost => _serverHost;
  int get serverPort => _serverPort;
  bool get isConnected => _isConnected;
  bool get initialized => _initialized;
  String get serverUrl => 'http://$_serverHost:$_serverPort';
  List<ServerProfile> get serverProfiles =>
      List<ServerProfile>.unmodifiable(_serverProfiles);
  String? get activeServerId => _activeServerId;
  String? get defaultServerId => _defaultServerId;
  ServerProfile? get activeServer => _findById(_activeServerId);

  ServerHealthStatus healthFor(String serverId) {
    return _serverHealthById[serverId] ?? ServerHealthStatus.unknown;
  }

  static String normalizeServerUrl(
    String rawUrl, {
    int fallbackPort = ApiConstants.defaultPort,
  }) {
    var normalized = rawUrl.trim();
    if (normalized.isEmpty) {
      throw const FormatException('Server URL is required');
    }

    if (!normalized.contains('://')) {
      normalized = 'http://$normalized';
    }

    final uri = Uri.tryParse(normalized);
    if (uri == null || uri.host.isEmpty) {
      throw const FormatException('Invalid server URL');
    }

    final scheme = uri.scheme.isEmpty ? 'http' : uri.scheme.toLowerCase();
    final port = uri.hasPort
        ? uri.port
        : (scheme == 'https' ? 443 : fallbackPort);

    final compact = Uri(scheme: scheme, host: uri.host, port: port).toString();
    return compact.endsWith('/')
        ? compact.substring(0, compact.length - 1)
        : compact;
  }

  Future<void> initialize() async {
    _initFuture ??= _initializeInternal();
    await _initFuture;
  }

  Future<void> _initializeInternal() async {
    await _loadServerProfiles();
    await _ensureActiveSelection();
    _applyActiveServerToClient();
    _initialized = true;
    unawaited(refreshServerHealth());
    if (_enableHealthPolling) {
      _startHealthPolling();
    }
    notifyListeners();
  }

  Future<void> _loadServerProfiles() async {
    final raw = await _localDataSource.getServerProfilesJson();
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          final parsed = <ServerProfile>[];
          for (final item in decoded) {
            if (item is Map) {
              final map = Map<String, dynamic>.from(item);
              parsed.add(ServerProfile.fromJson(map));
            }
          }
          _serverProfiles = parsed
              .where((p) => p.id.isNotEmpty && p.url.isNotEmpty)
              .toList();
        }
      } catch (e, stackTrace) {
        AppLogger.warn(
          'Failed to decode stored server profiles; falling back to migration',
          error: e,
          stackTrace: stackTrace,
        );
        _serverProfiles = <ServerProfile>[];
      }
    }

    if (_serverProfiles.isEmpty) {
      await _migrateLegacySingleServer();
    }

    _activeServerId = await _localDataSource.getActiveServerId();
    _defaultServerId = await _localDataSource.getDefaultServerId();
  }

  Future<void> _migrateLegacySingleServer() async {
    final oldHost = await _localDataSource.getServerHost();
    final oldPort = await _localDataSource.getServerPort();
    final oldBasicEnabled = await _localDataSource.getBasicAuthEnabled();
    final oldBasicUser = await _localDataSource.getBasicAuthUsername();
    final oldBasicPassword = await _localDataSource.getBasicAuthPassword();

    final host = (oldHost == null || oldHost.trim().isEmpty)
        ? ApiConstants.defaultHost
        : oldHost.trim();
    final port = oldPort ?? ApiConstants.defaultPort;
    final now = DateTime.now().millisecondsSinceEpoch;

    final profile = ServerProfile(
      id: _generateServerId(),
      url: normalizeServerUrl('$host:$port', fallbackPort: port),
      label: 'Primary server',
      basicAuthEnabled: oldBasicEnabled ?? false,
      basicAuthUsername: oldBasicUser ?? '',
      basicAuthPassword: oldBasicPassword ?? '',
      createdAt: now,
      updatedAt: now,
    );
    _serverProfiles = <ServerProfile>[profile];
    _activeServerId = profile.id;
    _defaultServerId = profile.id;
    await _persistServerProfiles();
  }

  Future<void> _ensureActiveSelection() async {
    if (_serverProfiles.isEmpty) {
      return;
    }

    final activeExists = _findById(_activeServerId) != null;
    if (!activeExists) {
      _activeServerId =
          (_findById(_defaultServerId)?.id ?? _serverProfiles.first.id);
    }

    if (_defaultServerId != null && _findById(_defaultServerId) == null) {
      _defaultServerId = _activeServerId;
    }

    if (_activeServerId != null) {
      await _localDataSource.saveActiveServerId(_activeServerId!);
    }
    await _localDataSource.saveDefaultServerId(_defaultServerId);
  }

  ServerProfile? _findById(String? serverId) {
    if (serverId == null) {
      return null;
    }
    for (final profile in _serverProfiles) {
      if (profile.id == serverId) {
        return profile;
      }
    }
    return null;
  }

  Future<void> _persistServerProfiles() async {
    final encoded = jsonEncode(_serverProfiles.map((p) => p.toJson()).toList());
    await _localDataSource.saveServerProfilesJson(encoded);
    if (_activeServerId != null) {
      await _localDataSource.saveActiveServerId(_activeServerId!);
    }
    await _localDataSource.saveDefaultServerId(_defaultServerId);
  }

  void _applyActiveServerToClient() {
    final profile = activeServer;
    if (profile == null) {
      return;
    }
    _dioClient.updateBaseUrl(profile.url);
    if (profile.basicAuthEnabled &&
        profile.basicAuthUsername.trim().isNotEmpty &&
        profile.basicAuthPassword.trim().isNotEmpty) {
      _dioClient.setBasicAuth(
        profile.basicAuthUsername.trim(),
        profile.basicAuthPassword.trim(),
      );
    } else {
      _dioClient.clearAuth();
    }

    final uri = Uri.tryParse(profile.url);
    if (uri != null) {
      _serverHost = uri.host;
      _serverPort = uri.hasPort ? uri.port : ApiConstants.defaultPort;
    }
  }

  Future<bool> addServerProfile({
    required String url,
    String? label,
    bool basicAuthEnabled = false,
    String basicAuthUsername = '',
    String basicAuthPassword = '',
    bool setAsActive = false,
  }) async {
    await initialize();
    final normalized = _safeNormalize(url);
    if (normalized == null) {
      _setError('Invalid server URL');
      return false;
    }

    if (_serverProfiles.any((p) => p.url == normalized)) {
      _setError('A server with this URL already exists');
      return false;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final profile = ServerProfile(
      id: _generateServerId(),
      url: normalized,
      label: label?.trim().isEmpty ?? true ? null : label!.trim(),
      basicAuthEnabled: basicAuthEnabled,
      basicAuthUsername: basicAuthUsername.trim(),
      basicAuthPassword: basicAuthPassword.trim(),
      createdAt: now,
      updatedAt: now,
    );
    _serverProfiles = <ServerProfile>[..._serverProfiles, profile];
    _defaultServerId ??= profile.id;
    if (_activeServerId == null || setAsActive) {
      _activeServerId = profile.id;
    }
    await _persistServerProfiles();
    _applyActiveServerToClient();
    await refreshServerHealth(serverId: profile.id);
    _errorMessage = '';
    notifyListeners();
    return true;
  }

  Future<bool> updateServerProfile({
    required String id,
    required String url,
    String? label,
    required bool basicAuthEnabled,
    required String basicAuthUsername,
    required String basicAuthPassword,
  }) async {
    await initialize();
    final index = _serverProfiles.indexWhere((p) => p.id == id);
    if (index == -1) {
      _setError('Server profile not found');
      return false;
    }

    final normalized = _safeNormalize(url);
    if (normalized == null) {
      _setError('Invalid server URL');
      return false;
    }

    final duplicate = _serverProfiles.any(
      (p) => p.id != id && p.url == normalized,
    );
    if (duplicate) {
      _setError('A server with this URL already exists');
      return false;
    }

    final previous = _serverProfiles[index];
    final updated = previous.copyWith(
      url: normalized,
      label: label?.trim().isEmpty ?? true ? null : label!.trim(),
      basicAuthEnabled: basicAuthEnabled,
      basicAuthUsername: basicAuthUsername.trim(),
      basicAuthPassword: basicAuthPassword.trim(),
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    final copied = List<ServerProfile>.from(_serverProfiles);
    copied[index] = updated;
    _serverProfiles = copied;

    await _persistServerProfiles();
    if (_activeServerId == updated.id) {
      _applyActiveServerToClient();
      await checkConnection();
    }
    await refreshServerHealth(serverId: updated.id);
    _errorMessage = '';
    notifyListeners();
    return true;
  }

  Future<bool> removeServerProfile(String id) async {
    await initialize();
    if (_serverProfiles.length <= 1) {
      _setError('At least one server profile is required');
      return false;
    }

    final exists = _serverProfiles.any((p) => p.id == id);
    if (!exists) {
      _setError('Server profile not found');
      return false;
    }

    _serverProfiles = _serverProfiles.where((p) => p.id != id).toList();
    _serverHealthById.remove(id);

    if (_defaultServerId == id) {
      _defaultServerId = _serverProfiles.first.id;
    }

    if (_activeServerId == id) {
      _activeServerId =
          (_findById(_defaultServerId)?.id ?? _serverProfiles.first.id);
      _applyActiveServerToClient();
      await checkConnection();
    }

    await _persistServerProfiles();
    _errorMessage = '';
    notifyListeners();
    return true;
  }

  Future<bool> setDefaultServer(String id) async {
    await initialize();
    if (_findById(id) == null) {
      _setError('Server profile not found');
      return false;
    }
    _defaultServerId = id;
    await _localDataSource.saveDefaultServerId(id);
    _errorMessage = '';
    notifyListeners();
    return true;
  }

  Future<bool> clearDefaultServer() async {
    await initialize();
    _defaultServerId = null;
    await _localDataSource.saveDefaultServerId(null);
    notifyListeners();
    return true;
  }

  Future<bool> setActiveServer(String id, {bool blockUnhealthy = true}) async {
    await initialize();
    final profile = _findById(id);
    if (profile == null) {
      _setError('Server profile not found');
      return false;
    }

    final health = healthFor(id);
    if (blockUnhealthy && health == ServerHealthStatus.unhealthy) {
      _setError('Cannot activate an unhealthy server');
      return false;
    }

    _activeServerId = id;
    await _localDataSource.saveActiveServerId(id);
    _applyActiveServerToClient();
    _isConnected = false;
    _appInfo = null;
    _errorMessage = '';
    notifyListeners();

    await checkConnection();
    return true;
  }

  Future<void> refreshServerHealth({String? serverId}) async {
    await initialize();
    final targets = serverId == null
        ? List<ServerProfile>.from(_serverProfiles)
        : _serverProfiles.where((p) => p.id == serverId).toList();
    if (targets.isEmpty) {
      return;
    }

    for (final profile in targets) {
      _serverHealthById[profile.id] = await _checkServerHealth(profile);
    }
    notifyListeners();
  }

  Future<ServerHealthStatus> _checkServerHealth(ServerProfile profile) async {
    final dio = Dio(
      BaseOptions(
        baseUrl: profile.url,
        connectTimeout: const Duration(seconds: 3),
        receiveTimeout: const Duration(seconds: 3),
        sendTimeout: const Duration(seconds: 3),
      ),
    );

    if (profile.basicAuthEnabled &&
        profile.basicAuthUsername.trim().isNotEmpty &&
        profile.basicAuthPassword.trim().isNotEmpty) {
      final auth = base64Encode(
        utf8.encode(
          '${profile.basicAuthUsername.trim()}:${profile.basicAuthPassword.trim()}',
        ),
      );
      dio.options.headers[ApiConstants.authorization] = 'Basic $auth';
    }

    try {
      final global = await dio.get('/global/health');
      if (global.statusCode == 200) {
        return ServerHealthStatus.healthy;
      }
    } catch (_) {
      // Fallback below.
    }

    try {
      final fallback = await dio.get('/path');
      if (fallback.statusCode == 200) {
        return ServerHealthStatus.healthy;
      }
      return ServerHealthStatus.unhealthy;
    } catch (_) {
      return ServerHealthStatus.unhealthy;
    }
  }

  Future<void> getAppInfo({String? directory}) async {
    await initialize();
    _setStatus(AppStatus.loading);

    final result = await _getAppInfo(directory: directory);
    result.fold(
      (failure) {
        _errorMessage = failure.message;
        _setStatus(AppStatus.error);
        _isConnected = false;
      },
      (appInfo) {
        _appInfo = appInfo;
        _setStatus(AppStatus.loaded);
        _isConnected = true;
        _errorMessage = '';
      },
    );

    notifyListeners();
  }

  Future<void> checkConnection({String? directory}) async {
    await initialize();
    final result = await _checkConnection(directory: directory);
    result.fold(
      (failure) {
        _errorMessage = failure.message;
        _isConnected = false;
      },
      (connected) {
        _isConnected = connected;
        if (connected) {
          _errorMessage = '';
        }
      },
    );
    notifyListeners();
  }

  Future<bool> updateServerConfig(String host, int port) async {
    await initialize();
    final current = activeServer;
    if (current != null) {
      return updateServerProfile(
        id: current.id,
        url: '$host:$port',
        label: current.label,
        basicAuthEnabled: current.basicAuthEnabled,
        basicAuthUsername: current.basicAuthUsername,
        basicAuthPassword: current.basicAuthPassword,
      );
    }

    final created = await addServerProfile(
      url: '$host:$port',
      label: 'Primary server',
      setAsActive: true,
    );
    if (created) {
      _serverHost = host;
      _serverPort = port;
      _errorMessage = '';
      notifyListeners();
    }
    return created;
  }

  void setServerConfig(String host, int port) {
    _serverHost = host;
    _serverPort = port;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = '';
    notifyListeners();
  }

  void reset() {
    _status = AppStatus.initial;
    _appInfo = null;
    _errorMessage = '';
    _isConnected = false;
    notifyListeners();
  }

  @visibleForTesting
  void setHealthForTesting(String serverId, ServerHealthStatus status) {
    _serverHealthById[serverId] = status;
    notifyListeners();
  }

  @override
  void dispose() {
    _healthTimer?.cancel();
    super.dispose();
  }

  void _startHealthPolling() {
    _healthTimer?.cancel();
    _healthTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      unawaited(refreshServerHealth());
    });
  }

  void _setStatus(AppStatus status) {
    _status = status;
  }

  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  String _generateServerId() {
    final epoch = DateTime.now().microsecondsSinceEpoch;
    final random = Random().nextInt(999999).toString().padLeft(6, '0');
    return 'srv_${epoch}_$random';
  }

  String? _safeNormalize(String value) {
    try {
      return normalizeServerUrl(value);
    } catch (_) {
      return null;
    }
  }
}
