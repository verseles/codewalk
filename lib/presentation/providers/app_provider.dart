import 'package:flutter/foundation.dart';
import '../../domain/entities/app_info.dart';
import '../../domain/usecases/get_app_info.dart';
import '../../domain/usecases/check_connection.dart';
import '../../domain/usecases/update_server_config.dart';
import '../../core/constants/api_constants.dart';

/// Technical comment translated to English.
enum AppStatus { initial, loading, loaded, error, disconnected }

/// Technical comment translated to English.
class AppProvider extends ChangeNotifier {
  final GetAppInfo _getAppInfo;
  final CheckConnection _checkConnection;
  final UpdateServerConfig _updateServerConfig;

  AppProvider({
    required GetAppInfo getAppInfo,
    required CheckConnection checkConnection,
    required UpdateServerConfig updateServerConfig,
  }) : _getAppInfo = getAppInfo,
       _checkConnection = checkConnection,
       _updateServerConfig = updateServerConfig;

  // Technical comment translated to English.
  AppStatus _status = AppStatus.initial;
  AppInfo? _appInfo;
  String _errorMessage = '';
  String _serverHost = ApiConstants.defaultHost;
  int _serverPort = ApiConstants.defaultPort;
  bool _isConnected = false;

  // Getters
  AppStatus get status => _status;
  AppInfo? get appInfo => _appInfo;
  String get errorMessage => _errorMessage;
  String get serverHost => _serverHost;
  int get serverPort => _serverPort;
  bool get isConnected => _isConnected;
  String get serverUrl => 'http://$_serverHost:$_serverPort';

  /// Technical comment translated to English.
  Future<void> getAppInfo() async {
    _setStatus(AppStatus.loading);

    final result = await _getAppInfo();

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
      },
    );

    notifyListeners();
  }

  /// Technical comment translated to English.
  Future<void> checkConnection() async {
    final result = await _checkConnection();

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

  /// Technical comment translated to English.
  Future<bool> updateServerConfig(String host, int port) async {
    final params = UpdateServerConfigParams(host: host, port: port);
    final result = await _updateServerConfig(params);

    return result.fold(
      (failure) {
        _errorMessage = failure.message;
        notifyListeners();
        return false;
      },
      (_) {
        _serverHost = host;
        _serverPort = port;
        _errorMessage = '';
        notifyListeners();
        return true;
      },
    );
  }

  /// Technical comment translated to English.
  void setServerConfig(String host, int port) {
    _serverHost = host;
    _serverPort = port;
    notifyListeners();
  }

  /// Technical comment translated to English.
  void clearError() {
    _errorMessage = '';
    notifyListeners();
  }

  /// Technical comment translated to English.
  void reset() {
    _status = AppStatus.initial;
    _appInfo = null;
    _errorMessage = '';
    _isConnected = false;
    notifyListeners();
  }

  void _setStatus(AppStatus status) {
    _status = status;
  }
}
