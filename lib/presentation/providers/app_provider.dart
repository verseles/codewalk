import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/auth/oauth_service.dart';
import '../../core/constants/api_constants.dart';
import '../../core/i18n/l10n_bridge.dart';
import '../../core/logging/app_logger.dart';
import '../../core/network/dio_client.dart';
import '../../core/tailscale/tailscale_http_adapter.dart';
import '../../core/tailscale/tailscale_service.dart';
import '../../data/datasources/app_local_datasource.dart';
import '../../domain/entities/app_info.dart';
import '../../domain/entities/server_profile.dart';
import '../../domain/usecases/check_connection.dart';
import '../../domain/usecases/get_app_info.dart';
import '../services/car_messaging/car_messaging_runtime.dart';
import '../services/cellular_data_saver_service.dart';
import '../services/local_opencode_server_runtime.dart';
import '../services/local_opencode_server_runtime_types.dart';
import '../services/session_attention/session_attention_completion_resolver.dart';
import '../services/session_tab_icon_override_store.dart';

enum AppStatus { initial, loading, loaded, error, disconnected }

enum ServerHealthStatus { unknown, healthy, unhealthy }

enum LocalServerRuntimeStatus { stopped, starting, running, stopping, failed }

enum SetupDebugSeverity { info, error }

typedef OAuthServiceFactory =
    OAuthService Function({
      required String profileId,
      required String serverUrl,
      Map<String, String>? challengeHeaders,
      String? challengeBody,
      bool Function()? shouldPersistCredential,
    });

class SetupDebugEntry {
  const SetupDebugEntry({
    required this.timestamp,
    required this.source,
    required this.message,
    required this.severity,
  });

  final DateTime timestamp;
  final String source;
  final String message;
  final SetupDebugSeverity severity;
}

class AppProvider extends ChangeNotifier {
  AppProvider({
    required GetAppInfo getAppInfo,
    required CheckConnection checkConnection,
    required AppLocalDataSource localDataSource,
    required DioClient dioClient,
    TailscaleService? tailscaleService,
    Future<bool> Function(Uri authUrl)? tailscaleAuthLauncher,
    CellularDataSaverService? cellularDataSaverService,
    SessionAttentionCompletionResolver? sessionAttentionCompletionResolver,
    LocalOpencodeServerRuntime? localServerRuntime,
    Future<ServerHealthStatus> Function(ServerProfile profile)?
    serverHealthProbe,
    Future<ServerHealthStatus> Function(String url)? localServerHealthProbe,
    Duration serverHealthRequestTimeout = const Duration(seconds: 3),
    bool enableHealthPolling = true,
    OAuthServiceFactory? oauthServiceFactory,
    SessionTabIconOverrideStore? sessionTabIconOverrideStore,
  }) : _getAppInfo = getAppInfo,
       _checkConnection = checkConnection,
       _localDataSource = localDataSource,
       _dioClient = dioClient,
       _tailscaleService = tailscaleService ?? TailscaleService(),
        _tailscaleAuthLauncher =
            tailscaleAuthLauncher ??
            ((authUrl) async {
              try {
                final launched = await launchUrl(
                  authUrl,
                  mode: LaunchMode.externalApplication,
                );
                if (launched) return true;
              } catch (_) {
                // Fall through to platform-default launch below.
              }
              try {
                return await launchUrl(
                  authUrl,
                  mode: LaunchMode.platformDefault,
                );
              } catch (error, stackTrace) {
                AppLogger.warn(
                  'Failed to launch Tailscale authentication URL with fallback',
                  error: error,
                  stackTrace: stackTrace,
                );
                return false;
              }
            }),
       _cellularDataSaverService =
           cellularDataSaverService ?? CellularDataSaverService.disabled(),
       _sessionAttentionCompletionResolver = sessionAttentionCompletionResolver,
       _sessionTabIconOverrideStore =
           sessionTabIconOverrideStore ??
           SessionTabIconOverrideStore(localDataSource: localDataSource),
       _localServerRuntime =
           localServerRuntime ?? createLocalOpencodeServerRuntime(),
       _serverHealthProbe = serverHealthProbe,
       _localServerHealthProbe = localServerHealthProbe,
       _serverHealthRequestTimeout = serverHealthRequestTimeout,
       _enableHealthPolling = enableHealthPolling,
       _oauthServiceFactory =
           oauthServiceFactory ??
           (({
             required String profileId,
             required String serverUrl,
             Map<String, String>? challengeHeaders,
             String? challengeBody,
             bool Function()? shouldPersistCredential,
           }) => OAuthService(
             profileId: profileId,
             serverUrl: serverUrl,
             challengeHeaders: challengeHeaders,
             challengeBody: challengeBody,
             shouldPersistCredential: shouldPersistCredential,
           )) {
    _cellularDataSaverService.addListener(_handleCellularDataSaverChanged);
    _initL10nDefaults();
  }

  final GetAppInfo _getAppInfo;
  final CheckConnection _checkConnection;
  final AppLocalDataSource _localDataSource;
  final DioClient _dioClient;
  final TailscaleService _tailscaleService;
  final Future<bool> Function(Uri authUrl) _tailscaleAuthLauncher;
  final CellularDataSaverService _cellularDataSaverService;
  final SessionAttentionCompletionResolver? _sessionAttentionCompletionResolver;
  final SessionTabIconOverrideStore _sessionTabIconOverrideStore;
  final LocalOpencodeServerRuntime _localServerRuntime;
  final Future<ServerHealthStatus> Function(ServerProfile profile)?
  _serverHealthProbe;
  final Future<ServerHealthStatus> Function(String url)?
  _localServerHealthProbe;
  final Duration _serverHealthRequestTimeout;
  final bool _enableHealthPolling;
  final OAuthServiceFactory _oauthServiceFactory;

  AppStatus _status = AppStatus.initial;
  AppInfo? _appInfo;
  String _errorMessage = '';
  String _serverHost = ApiConstants.defaultHost;
  int _serverPort = ApiConstants.defaultPort;
  bool _isConnected = false;
  bool _initialized = false;
  Future<void>? _initFuture;
  Timer? _healthTimer;
  Duration _currentHealthPollingInterval = const Duration(seconds: 10);
  bool _localServerRuntimeBound = false;
  StreamSubscription<String>? _localServerStdoutSubscription;
  StreamSubscription<String>? _localServerStderrSubscription;
  StreamSubscription<int>? _localServerExitSubscription;
  LocalServerRuntimeStatus _localServerStatus =
      LocalServerRuntimeStatus.stopped;
  String _localServerStatusMessage = '';
  String _localServerLastOutput = '';
  String _localServerCommandPath = '';
  LocalOpencodeEnvironmentReport? _localEnvironmentReport;
  bool _localSetupInProgress = false;
  String _localSetupMessage = '';
  List<String> _localSetupLogs = <String>[];
  List<SetupDebugEntry> _setupDebugEntries = <SetupDebugEntry>[];
  final String _localServerHost = ApiConstants.defaultHost;
  final int _localServerPort = ApiConstants.defaultPort;
  bool _localServerStoppingByRequest = false;

  List<ServerProfile> _serverProfiles = <ServerProfile>[];
  String? _activeServerId;
  String? _defaultServerId;
  final Map<String, ServerHealthStatus> _serverHealthById =
      <String, ServerHealthStatus>{};
  bool _healthCheckInFlight = false;
  bool _queuedHealthRefreshAll = false;
  final Set<String> _queuedHealthServerIds = <String>{};
  StreamSubscription<TailscaleState>? _tailscaleStateSubscription;
  StreamSubscription<List<TailscalePeer>>? _tailscalePeerSubscription;
  TailscaleState _tailscaleState = const TailscaleState.disconnected();
  List<TailscalePeer> _tailscalePeers = const [];

  // OAuth challenge tracking
  final Map<String, Map<String, String>> _oauthChallengeHeaders =
      <String, Map<String, String>>{};
  final Map<String, String> _oauthChallengeBodies = <String, String>{};
  final Set<String> _authenticatedOAuthProfileIds = <String>{};
  final Set<String> _invalidatedOAuthProfileIds = <String>{};
  final Map<String, Future<bool>> _oauthFlowByProfileId =
      <String, Future<bool>>{};

  AppStatus get status => _status;
  AppInfo? get appInfo => _appInfo;
  String get errorMessage => _errorMessage;
  String get serverHost => _serverHost;
  int get serverPort => _serverPort;
  bool get isConnected => _isConnected;
  bool get initialized => _initialized;
  String get serverUrl => 'http://$_serverHost:$_serverPort';
  bool get localServerSupported => _localServerRuntime.isSupported;
  LocalServerRuntimeStatus get localServerStatus => _localServerStatus;
  String get localServerStatusMessage => _localServerStatusMessage;
  String get localServerLastOutput => _localServerLastOutput;
  String get localServerUrl => 'http://$_localServerHost:$_localServerPort';
  String get localServerCommandPath => _localServerCommandPath;
  LocalOpencodeEnvironmentReport? get localEnvironmentReport =>
      _localEnvironmentReport;
  bool get localSetupInProgress => _localSetupInProgress;
  String get localSetupMessage => _localSetupMessage;
  List<String> get localSetupLogs => List<String>.unmodifiable(_localSetupLogs);
  List<SetupDebugEntry> get setupDebugEntries =>
      List<SetupDebugEntry>.unmodifiable(_setupDebugEntries);
  List<ServerProfile> get serverProfiles =>
      List<ServerProfile>.unmodifiable(_serverProfiles);
  String? get activeServerId => _activeServerId;
  String? get defaultServerId => _defaultServerId;
  ServerProfile? get activeServer => _findById(_activeServerId);
  TailscaleState get tailscaleState => _tailscaleState;
  TailscaleNodeState get tailscaleNodeState => _tailscaleState.nodeState;
  Uri? get tailscaleAuthUrl => _tailscaleState.authUrl;
  String? get tailscaleMessage => _tailscaleState.message;
  bool get tailscaleNeedsAuth => _tailscaleState.requiresUserLogin;
  bool get tailscaleNeedsMachineAuth =>
      _tailscaleState.nodeState == TailscaleNodeState.needsMachineAuth;

  /// Current tailnet peers (online-first, alphabetical within each group).
  List<TailscalePeer> get tailscalePeers =>
      List<TailscalePeer>.unmodifiable(_tailscalePeers);

  /// Whether Tailscale is connected and peers are available.
  bool get tailscaleHasPeers =>
      _tailscaleState.isConnected && _tailscalePeers.isNotEmpty;

  bool hasOAuthChallenge(String serverUrl) =>
      _oauthChallengeHeaders.containsKey(serverUrl);

  Map<String, String>? getOAuthChallengeHeaders(String serverUrl) =>
      _oauthChallengeHeaders[serverUrl];

  bool isOAuthAuthenticated(String serverUrl) =>
      _authenticatedOAuthProfileIds.contains(_findByUrl(serverUrl)?.id);

  ServerHealthStatus healthFor(String serverId) {
    return _serverHealthById[serverId] ?? ServerHealthStatus.unknown;
  }

  @visibleForTesting
  Duration get debugCurrentHealthPollingInterval =>
      _currentHealthPollingInterval;

  Duration get _effectiveHealthPollingInterval {
    if (_cellularDataSaverService.shouldThrottleAutomaticForegroundSync) {
      return _cellularDataSaverService.automaticSyncInterval;
    }
    return const Duration(seconds: 10);
  }

  static String normalizeServerUrl(
    String rawUrl, {
    int fallbackPort = ApiConstants.defaultPort,
  }) {
    var normalized = rawUrl.trim();
    if (normalized.isEmpty) {
      throw FormatException(
        L10nBridge.current?.appProviderErrorServerUrlRequired ??
            'Server URL is required',
      );
    }

    if (!normalized.contains('://')) {
      normalized = 'http://$normalized';
    }

    final uri = Uri.tryParse(normalized);
    if (uri == null || uri.host.isEmpty) {
      throw FormatException(
        L10nBridge.current?.appProviderErrorInvalidServerUrl ??
            'Invalid server URL',
      );
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

  static bool get supportsCloudflareAccessOAuth {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows;
  }

  static bool get supportsTailscale {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  Future<void> initialize() async {
    _initFuture ??= _initializeInternal();
    await _initFuture;
  }

  Future<void> _initializeInternal() async {
    await _loadServerProfiles();
    await _ensureActiveSelection();
    await _loadLocalServerCommandConfig();
    await _applyActiveServerToClient();
    _bindLocalServerRuntimeEvents();
    _initialized = true;
    if (_serverProfiles.isNotEmpty) {
      unawaited(refreshServerHealth());
    }
    unawaited(runLocalServerDiagnostics(notify: false));
    _syncHealthPollingLifecycle();
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

    final hasLegacyHost = oldHost != null && oldHost.trim().isNotEmpty;
    final hasLegacyPort = oldPort != null;
    final hasLegacyAuth =
        (oldBasicEnabled ?? false) ||
        (oldBasicUser != null && oldBasicUser.trim().isNotEmpty) ||
        (oldBasicPassword != null && oldBasicPassword.trim().isNotEmpty);
    if (!hasLegacyHost && !hasLegacyPort && !hasLegacyAuth) {
      _serverProfiles = <ServerProfile>[];
      return;
    }

    final host = (oldHost == null || oldHost.trim().isEmpty)
        ? ApiConstants.defaultHost
        : oldHost.trim();
    final port = oldPort ?? ApiConstants.defaultPort;
    final now = DateTime.now().millisecondsSinceEpoch;

    final profile = ServerProfile(
      id: _generateServerId(),
      url: normalizeServerUrl('$host:$port', fallbackPort: port),
      label:
          L10nBridge.current?.appProviderLabelPrimaryServer ?? 'Primary server',
      basicAuthEnabled: oldBasicEnabled ?? false,
      basicAuthUsername: oldBasicUser ?? '',
      basicAuthPassword: oldBasicPassword ?? '',
      aiGeneratedTitlesEnabled: true,
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
      _activeServerId = null;
      _defaultServerId = null;
      await _localDataSource.saveDefaultServerId(null);
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

  ServerProfile? _findByUrl(String serverUrl) {
    for (final profile in _serverProfiles) {
      if (profile.url == serverUrl) {
        return profile;
      }
    }
    return null;
  }

  bool _isCurrentOAuthProfile(ServerProfile profile) {
    final current = _findById(profile.id);
    return profile.oauthEnabled &&
        !_invalidatedOAuthProfileIds.contains(profile.id) &&
        current?.oauthEnabled == true &&
        current?.url == profile.url;
  }

  Future<void> _persistServerProfiles() async {
    final encoded = jsonEncode(_serverProfiles.map((p) => p.toJson()).toList());
    await _localDataSource.saveServerProfilesJson(encoded);
    if (_activeServerId != null) {
      await _localDataSource.saveActiveServerId(_activeServerId!);
    }
    await _localDataSource.saveDefaultServerId(_defaultServerId);
  }

  Future<void> _applyActiveServerToClient() async {
    final profile = activeServer;
    if (profile == null) {
      _dioClient.clearAuth();
      _dioClient.removeTailscaleAdapter();
      await _stopTailscaleTransport();
      _serverHost = ApiConstants.defaultHost;
      _serverPort = ApiConstants.defaultPort;
      return;
    }
    _dioClient.updateBaseUrl(profile.url);
    _dioClient.clearAuth();
    if (profile.oauthEnabled) {
      try {
        final service = _oauthServiceFactory(
          profileId: profile.id,
          serverUrl: profile.url,
          shouldPersistCredential: () => _isCurrentOAuthProfile(profile),
        );
        final cached = await service.getCachedCredential();
        if (activeServer != profile) return;
        if (cached != null) {
          _dioClient.setOAuthToken(cached.accessToken, origin: profile.url);
          _authenticatedOAuthProfileIds.add(profile.id);
        } else {
          _authenticatedOAuthProfileIds.remove(profile.id);
        }
      } catch (_) {
        if (activeServer != profile) return;
        _authenticatedOAuthProfileIds.remove(profile.id);
        AppLogger.warn(
          'Failed to load cached OAuth credential for active profile',
        );
      }
    } else if (profile.basicAuthEnabled &&
        profile.basicAuthUsername.trim().isNotEmpty &&
        profile.basicAuthPassword.trim().isNotEmpty) {
      _dioClient.setBasicAuth(
        profile.basicAuthUsername.trim(),
        profile.basicAuthPassword.trim(),
        origin: profile.url,
      );
    } else {
      _dioClient.clearAuth();
    }

    await _applyTailscaleTransport(profile);
    if (activeServer != profile) return;

    final uri = Uri.tryParse(profile.url);
    if (uri != null) {
      _serverHost = uri.host;
      _serverPort = uri.hasPort ? uri.port : ApiConstants.defaultPort;
    }
  }

  Future<void> _applyTailscaleTransport(ServerProfile profile) async {
    if (!profile.tailscaleEnabled || !supportsTailscale) {
      _dioClient.removeTailscaleAdapter();
      await _stopTailscaleTransport();
      return;
    }

    _listenToTailscaleState();
    final state = await _tailscaleService.upForProfile(
      profileId: profile.id,
      profileLabel: profile.displayName,
    );
    _setTailscaleState(state);
    if (state.isConnected) {
      _dioClient.applyTailscaleAdapter(
        TailscaleHttpAdapter(_tailscaleService.httpClient),
      );
      return;
    }
    _dioClient.removeTailscaleAdapter();
    final shouldStopNode =
        state.nodeState == TailscaleNodeState.error ||
        state.nodeState == TailscaleNodeState.unsupported ||
        state.nodeState == TailscaleNodeState.disconnected;
    if (shouldStopNode) {
      await _stopTailscaleTransport();
    }
  }

  void _listenToTailscaleState() {
    _tailscaleStateSubscription ??= _tailscaleService.stateChanges.listen((
      state,
    ) {
      _setTailscaleState(state);
      if (state.isConnected) {
        _dioClient.applyTailscaleAdapter(
          TailscaleHttpAdapter(_tailscaleService.httpClient),
        );
        final activeId = _activeServerId;
        if (activeId != null) {
          unawaited(refreshServerHealth(serverId: activeId));
          unawaited(checkConnection());
        }
      }
    });
    _tailscalePeerSubscription ??= _tailscaleService.peerChanges.listen((
      peers,
    ) {
      if (!listEquals(_tailscalePeers, peers)) {
        _tailscalePeers = peers;
        notifyListeners();
      }
    });
  }

  void _setTailscaleState(TailscaleState state) {
    if (_tailscaleState == state) return;
    final previous = _tailscaleState;
    _tailscaleState = state;
    if (previous.nodeState != state.nodeState) {
      final details = <String>[state.nodeState.name];
      final authHost = state.authUrl?.host.trim() ?? '';
      if (authHost.isNotEmpty) details.add('authUrl host=$authHost');
      final message = state.message?.trim() ?? '';
      if (message.isNotEmpty) details.add(message);
      _recordSetupDebugEvent(
        source: 'Tailscale',
        message: 'state ${previous.nodeState.name} -> ${details.join(' | ')}',
        severity: state.nodeState == TailscaleNodeState.error
            ? SetupDebugSeverity.error
            : SetupDebugSeverity.info,
        notify: false,
      );
    }
    notifyListeners();
  }

  Future<void> _stopTailscaleTransport() async {
    await _tailscaleStateSubscription?.cancel();
    _tailscaleStateSubscription = null;
    await _tailscalePeerSubscription?.cancel();
    _tailscalePeerSubscription = null;
    _tailscalePeers = const [];
    await _tailscaleService.down();
    _setTailscaleState(const TailscaleState.disconnected());
  }
  Future<bool> authenticateTailscale() async {
    final authUrl = _tailscaleState.authUrl;
    if (authUrl != null) {
      final ok = await _launchTailscaleAuthUrl(authUrl);
      _recordSetupDebugEvent(
        source: 'Tailscale',
        message:
            'auth launch host=${authUrl.host} result=${ok ? 'opened' : 'failed'}',
        severity: ok ? SetupDebugSeverity.info : SetupDebugSeverity.error,
        notify: false,
      );
      return ok;
    }
    final profile = activeServer;
    if (profile == null || !profile.tailscaleEnabled) {
      return false;
    }
    await _applyTailscaleTransport(profile);
    final refreshedUrl = _tailscaleState.authUrl;
    if (refreshedUrl != null) {
      final ok = await _launchTailscaleAuthUrl(refreshedUrl);
      _recordSetupDebugEvent(
        source: 'Tailscale',
        message:
            'auth launch host=${refreshedUrl.host} result=${ok ? 'opened' : 'failed'}',
        severity: ok ? SetupDebugSeverity.info : SetupDebugSeverity.error,
        notify: false,
      );
      return ok;
    }
    final awaitedUrl = await _waitForTailscaleAuthUrl();
    if (awaitedUrl == null) {
      _recordSetupDebugEvent(
        source: 'Tailscale',
        message: 'auth URL never arrived (state ${_tailscaleState.nodeState.name})',
        severity: SetupDebugSeverity.error,
        notify: false,
      );
      return false;
    }
    final ok = await _launchTailscaleAuthUrl(awaitedUrl);
    _recordSetupDebugEvent(
      source: 'Tailscale',
      message:
          'auth launch host=${awaitedUrl.host} result=${ok ? 'opened' : 'failed'}',
      severity: ok ? SetupDebugSeverity.info : SetupDebugSeverity.error,
      notify: false,
    );
    return ok;
  }

  /// Re-reads the native Tailscale status without restarting the node.
  ///
  /// Heals the stale-state trap where the browser login completes while
  /// the app is backgrounded and the IPN state event is missed: the next
  /// health poll (or an explicit Retry) picks up running/needsMachineAuth
  /// instead of staying on a stale needsLogin forever.
  Future<TailscaleState> refreshTailscaleStatus() async {
    final profile = activeServer;
    if (profile == null ||
        !profile.tailscaleEnabled ||
        !supportsTailscale) {
      return _tailscaleState;
    }
    _listenToTailscaleState();
    final before = _tailscaleState;
    late final TailscaleState next;
    try {
      next = await _tailscaleService.refreshStatus();
    } catch (_) {
      return _tailscaleState;
    }
    _setTailscaleState(next);
    if (next.isConnected && !before.isConnected) {
      _dioClient.applyTailscaleAdapter(
        TailscaleHttpAdapter(_tailscaleService.httpClient),
      );
    } else if (!next.isConnected && before.isConnected) {
      _dioClient.removeTailscaleAdapter();
      _serverHealthById[profile.id] = ServerHealthStatus.unknown;
      notifyListeners();
    }
    return next;
  }

  /// Restarts the embedded node for the active Tailscale profile and
  /// re-probes health. Backs the Retry action in onboarding/settings.
  Future<void> retryTailscaleTransport() async {
    final profile = activeServer;
    if (profile == null ||
        !profile.tailscaleEnabled ||
        !supportsTailscale) {
      return;
    }
    await _applyTailscaleTransport(profile);
    if (profile.id == _activeServerId) {
      await refreshServerHealth(serverId: profile.id);
    }
  }

  Future<Uri?> _waitForTailscaleAuthUrl({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final currentUrl = _tailscaleState.authUrl;
    if (currentUrl != null) return currentUrl;

    bool isTerminal(TailscaleState state) =>
        state.nodeState == TailscaleNodeState.connected ||
        state.nodeState == TailscaleNodeState.disconnected ||
        state.nodeState == TailscaleNodeState.error ||
        state.nodeState == TailscaleNodeState.unsupported;

    if (isTerminal(_tailscaleState)) {
      return null;
    }

    final completer = Completer<Uri?>();
    Timer? timer;
    StreamSubscription<TailscaleState>? subscription;

    void complete(Uri? value) {
      if (completer.isCompleted) return;
      timer?.cancel();
      unawaited(subscription?.cancel());
      completer.complete(value);
    }

    subscription = _tailscaleService.stateChanges.listen(
      (state) {
        final authUrl = state.authUrl;
        if (authUrl != null) {
          complete(authUrl);
          return;
        }
        if (isTerminal(state)) {
          complete(null);
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        AppLogger.warn(
          'Failed while waiting for Tailscale authentication URL',
          error: error,
          stackTrace: stackTrace,
        );
        complete(null);
      },
    );
    final latestState = _tailscaleState;
    if (latestState.authUrl != null) {
      complete(latestState.authUrl);
    } else if (isTerminal(latestState)) {
      complete(null);
    }
    if (!completer.isCompleted) {
      timer = Timer(timeout, () => complete(null));
    }
    return completer.future;
  }

  Future<bool> _launchTailscaleAuthUrl(Uri authUrl) async {
    try {
      return _tailscaleAuthLauncher(authUrl);
    } catch (error, stackTrace) {
      AppLogger.warn(
        'Failed to launch Tailscale authentication URL',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  Future<bool> handleOAuthChallenge({
    required String serverUrl,
    Map<String, String>? challengeHeaders,
    String? challengeBody,
  }) async {
    final profile = _findByUrl(serverUrl);
    if (profile == null || !profile.oauthEnabled) {
      return false;
    }

    _oauthChallengeHeaders[serverUrl] = challengeHeaders ?? {};
    if (challengeBody != null) {
      _oauthChallengeBodies[serverUrl] = challengeBody;
    }

    if (_oauthFlowByProfileId.containsKey(profile.id)) {
      return _oauthFlowByProfileId[profile.id]!;
    }

    final service = _oauthServiceFactory(
      profileId: profile.id,
      serverUrl: serverUrl,
      challengeHeaders: challengeHeaders,
      challengeBody: challengeBody,
      shouldPersistCredential: () => _isCurrentOAuthProfile(profile),
    );

    final flow = () async {
      try {
        final result = await service.authenticate();
        if (!_isCurrentOAuthProfile(profile)) return false;
        if (result.ok && result.token != null) {
          if (profile.id == _activeServerId) {
            _dioClient.setOAuthToken(result.token!, origin: profile.url);
          }
          _authenticatedOAuthProfileIds.add(profile.id);
          _oauthChallengeHeaders.remove(serverUrl);
          _oauthChallengeBodies.remove(serverUrl);

          if (profile.id == _activeServerId) {
            // Verify the freshly persisted OAuth token against the active server.
            await checkConnection();
          }
          if (!_isCurrentOAuthProfile(profile)) return false;
          await refreshServerHealth(serverId: profile.id);
          SchedulerBinding.instance.addPostFrameCallback((_) {
            notifyListeners();
          });
          return true;
        }

        // Surface the concrete OAuth failure (token exchange, secure storage,
        // metadata discovery) instead of leaving callers with a generic error.
        final detail = result.error?.trim();
        if (detail != null && detail.isNotEmpty) {
          _setError(detail);
        }
        SchedulerBinding.instance.addPostFrameCallback((_) {
          notifyListeners();
        });
        return false;
      } catch (_) {
        // Every caller receives the same normalized failure future.
        AppLogger.warn('OAuth flow failed for profile');
        return false;
      } finally {
        unawaited(_oauthFlowByProfileId.remove(profile.id));
      }
    }();
    _oauthFlowByProfileId[profile.id] = flow;
    return flow;
  }

  Future<void> clearOAuthCredential(String serverUrl) async {
    final profile = _findByUrl(serverUrl);
    if (profile == null) {
      return;
    }
    await _clearOAuthCredentialForProfile(profile);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  Future<void> _clearOAuthCredentialForProfile(ServerProfile profile) async {
    try {
      final service = _oauthServiceFactory(
        profileId: profile.id,
        serverUrl: profile.url,
      );
      await service.clearCredential();
    } catch (_) {
      AppLogger.warn(
        'Failed to clear persisted OAuth credential; clearing memory state only',
      );
    }
    _authenticatedOAuthProfileIds.remove(profile.id);
    _oauthChallengeHeaders.remove(profile.url);
    _oauthChallengeBodies.remove(profile.url);
    if (activeServer?.id == profile.id) {
      _dioClient.clearOAuthToken();
    }
  }

  Future<bool> addServerProfile({
    required String url,
    String? label,
    bool basicAuthEnabled = false,
    String basicAuthUsername = '',
    String basicAuthPassword = '',
    bool oauthEnabled = false,
    bool tailscaleEnabled = false,
    bool aiGeneratedTitlesEnabled = true,
    bool setAsActive = false,
  }) async {
    await initialize();
    final normalized = _safeNormalize(url);
    if (normalized == null) {
      _setError(
        L10nBridge.current?.appProviderErrorInvalidServerUrl ??
            'Invalid server URL',
      );
      return false;
    }

    if (_serverProfiles.any((p) => p.url == normalized)) {
      _setError(
        L10nBridge.current?.appProviderErrorServerAlreadyExists ??
            'A server with this URL already exists',
      );
      return false;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    if (oauthEnabled && !supportsCloudflareAccessOAuth) {
      _setError(
        L10nBridge.current?.appProviderErrorCloudflareOAuthNotSupported ??
            'Cloudflare Access OAuth is not supported on this platform',
      );
      return false;
    }
    if (tailscaleEnabled && !supportsTailscale) {
      _setError(
        L10nBridge.current?.appProviderErrorTailscaleNotSupported ??
            'Tailscale is not supported on this platform',
      );
      return false;
    }
    final profile = ServerProfile(
      id: _generateServerId(),
      url: normalized,
      label: label?.trim().isEmpty ?? true ? null : label!.trim(),
      basicAuthEnabled: oauthEnabled ? false : basicAuthEnabled,
      basicAuthUsername: oauthEnabled ? '' : basicAuthUsername.trim(),
      basicAuthPassword: oauthEnabled ? '' : basicAuthPassword.trim(),
      oauthEnabled: oauthEnabled,
      tailscaleEnabled: tailscaleEnabled,
      aiGeneratedTitlesEnabled: aiGeneratedTitlesEnabled,
      createdAt: now,
      updatedAt: now,
    );
    _serverProfiles = <ServerProfile>[..._serverProfiles, profile];
    _defaultServerId ??= profile.id;
    if (_activeServerId == null || setAsActive) {
      _activeServerId = profile.id;
    }
    await _persistServerProfiles();
    await _applyActiveServerToClient();
    // Auto-trigger Tailscale auth when adding a new Tailscale-enabled
    // server — the user clicking "Save" is explicit consent to authenticate.
    if (tailscaleEnabled && _tailscaleState.requiresUserLogin) {
      unawaited(authenticateTailscale());
    }
    _syncHealthPollingLifecycle();
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
    required bool oauthEnabled,
    required bool tailscaleEnabled,
    required bool aiGeneratedTitlesEnabled,
  }) async {
    await initialize();
    final index = _serverProfiles.indexWhere((p) => p.id == id);
    if (index == -1) {
      _setError(
        L10nBridge.current?.appProviderErrorServerProfileNotFound ??
            'Server profile not found',
      );
      return false;
    }

    final normalized = _safeNormalize(url);
    if (normalized == null) {
      _setError(
        L10nBridge.current?.appProviderErrorInvalidServerUrl ??
            'Invalid server URL',
      );
      return false;
    }

    final duplicate = _serverProfiles.any(
      (p) => p.id != id && p.url == normalized,
    );
    if (duplicate) {
      _setError(
        L10nBridge.current?.appProviderErrorServerAlreadyExists ??
            'A server with this URL already exists',
      );
      return false;
    }

    if (oauthEnabled && !supportsCloudflareAccessOAuth) {
      _setError(
        L10nBridge.current?.appProviderErrorCloudflareOAuthNotSupported ??
            'Cloudflare Access OAuth is not supported on this platform',
      );
      return false;
    }
    if (tailscaleEnabled && !supportsTailscale) {
      _setError(
        L10nBridge.current?.appProviderErrorTailscaleNotSupported ??
            'Tailscale is not supported on this platform',
      );
      return false;
    }

    final previous = _serverProfiles[index];
    final updated = previous.copyWith(
      url: normalized,
      label: label?.trim().isEmpty ?? true ? null : label!.trim(),
      basicAuthEnabled: oauthEnabled ? false : basicAuthEnabled,
      basicAuthUsername: oauthEnabled ? '' : basicAuthUsername.trim(),
      basicAuthPassword: oauthEnabled ? '' : basicAuthPassword.trim(),
      oauthEnabled: oauthEnabled,
      tailscaleEnabled: tailscaleEnabled,
      aiGeneratedTitlesEnabled: aiGeneratedTitlesEnabled,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    final copied = List<ServerProfile>.from(_serverProfiles);
    copied[index] = updated;
    _serverProfiles = copied;

    if (previous.oauthEnabled &&
        (previous.url != updated.url || !updated.oauthEnabled)) {
      await _clearOAuthCredentialForProfile(previous);
    }

    await _persistServerProfiles();
    if (_activeServerId == updated.id) {
      await _applyActiveServerToClient();
      // Auto-trigger Tailscale auth when enabling Tailscale on an active
      // server — the user saving settings is explicit consent.
      if (tailscaleEnabled &&
          !previous.tailscaleEnabled &&
          _tailscaleState.requiresUserLogin) {
        unawaited(authenticateTailscale());
      }
      await checkConnection();
    }
    await refreshServerHealth(serverId: updated.id);
    _errorMessage = '';
    notifyListeners();
    return true;
  }

  Future<bool> removeServerProfile(String id) async {
    await initialize();
    final removed = _findById(id);
    if (removed == null) {
      _setError(
        L10nBridge.current?.appProviderErrorServerProfileNotFound ??
            'Server profile not found',
      );
      return false;
    }

    _invalidatedOAuthProfileIds.add(id);
    try {
      try {
        await _sessionTabIconOverrideStore.removeServer(id);
      } catch (error, stackTrace) {
        AppLogger.error(
          'Failed to remove session tab icon overrides for server=$id',
          error: error,
          stackTrace: stackTrace,
        );
        _setError(
          L10nBridge.current?.sessionTabIconRemoveFailed ??
              'Failed to remove local session tab icon data',
        );
        return false;
      }
      if (removed.oauthEnabled) {
        await _clearOAuthCredentialForProfile(removed);
      }
      await _sessionAttentionCompletionResolver?.removeServer(id);
      try {
        await CarMessagingRuntime.removeServer(id);
      } catch (error, stackTrace) {
        AppLogger.warn(
          'Failed to remove car messaging state for server=$id',
          error: error,
          stackTrace: stackTrace,
        );
      }

      _serverProfiles = _serverProfiles.where((p) => p.id != id).toList();
      _serverHealthById.remove(id);

      if (_serverProfiles.isEmpty) {
        _activeServerId = null;
        _defaultServerId = null;
        _isConnected = false;
        _appInfo = null;
        await _applyActiveServerToClient();
        _syncHealthPollingLifecycle();
        await _persistServerProfiles();
        _errorMessage = '';
        notifyListeners();
        return true;
      }

      _syncHealthPollingLifecycle();

      if (_defaultServerId == id) {
        _defaultServerId = _serverProfiles.first.id;
      }

      if (_activeServerId == id) {
        _activeServerId =
            (_findById(_defaultServerId)?.id ?? _serverProfiles.first.id);
        await _applyActiveServerToClient();
        await checkConnection();
      }

      await _persistServerProfiles();
      _errorMessage = '';
      notifyListeners();
      return true;
    } finally {
      _invalidatedOAuthProfileIds.remove(id);
    }
  }

  Future<bool> setDefaultServer(String id) async {
    await initialize();
    if (_findById(id) == null) {
      _setError(
        L10nBridge.current?.appProviderErrorServerProfileNotFound ??
            'Server profile not found',
      );
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
      _setError(
        L10nBridge.current?.appProviderErrorServerProfileNotFound ??
            'Server profile not found',
      );
      return false;
    }

    final health = healthFor(id);
    if (blockUnhealthy && health == ServerHealthStatus.unhealthy) {
      _setError(
        L10nBridge.current?.appProviderErrorCannotActivateUnhealthy ??
            'Cannot activate an unhealthy server',
      );
      return false;
    }

    _activeServerId = id;
    await _localDataSource.saveActiveServerId(id);
    await _applyActiveServerToClient();
    _isConnected = false;
    _appInfo = null;
    _errorMessage = '';
    notifyListeners();

    await checkConnection();
    return true;
  }

  Future<void> _loadLocalServerCommandConfig() async {
    final stored = await _localDataSource.getLocalOpencodeCommand();
    _localServerCommandPath = stored?.trim() ?? '';
  }

  Future<LocalOpencodeEnvironmentReport> runLocalServerDiagnostics({
    bool notify = true,
  }) async {
    final report = await _localServerRuntime.diagnose(
      commandPath: _localServerCommandPath.trim().isEmpty
          ? null
          : _localServerCommandPath,
    );
    _localEnvironmentReport = report;

    if (report.opencode.available &&
        _localServerCommandPath.trim().isEmpty &&
        report.opencode.path.trim().isNotEmpty) {
      await _setLocalServerCommandPath(report.opencode.path.trim());
    }

    if (!_localSetupInProgress) {
      _localSetupMessage = report.recommendation;
    }
    final availability = report.opencode.available
        ? (L10nBridge.current?.appProviderSetupOpenCodeDetected ??
              'OpenCode detected')
        : (L10nBridge.current?.appProviderSetupOpenCodeNotDetected ??
              'OpenCode not detected');
    final diagnosticsMessage =
        L10nBridge.current?.setupDebugMessageDiagnosticsResult(
          availability,
          report.platform,
          report.recommendation,
        ) ??
        '$availability on ${report.platform}. ${report.recommendation}';
    _recordSetupDebugEvent(
      source: _setupDebugSourceDiagnostics,
      message: diagnosticsMessage,
      notify: false,
    );
    if (notify) {
      notifyListeners();
    }
    return report;
  }

  Future<bool> useDetectedLocalServerCommand() async {
    await initialize();
    _localSetupInProgress = true;
    _localSetupLogs = <String>[];
    _localSetupMessage =
        L10nBridge.current?.appProviderSetupDetectingOpenCode ??
        'Detecting OpenCode command...';
    _errorMessage = '';
    _recordSetupDebugEvent(
      source: _setupDebugSourceUseExisting,
      message:
          L10nBridge.current?.setupDebugMessageDetectAttempt ??
          'Trying to detect an existing OpenCode command from the current environment.',
      notify: false,
    );
    notifyListeners();

    final report = await _localServerRuntime.diagnose(
      commandPath: _localServerCommandPath.trim().isEmpty
          ? null
          : _localServerCommandPath,
    );
    _localEnvironmentReport = report;

    if (!report.opencode.available || report.opencode.path.trim().isEmpty) {
      final isWindows =
          !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
      final message = isWindows
          ? (L10nBridge.current?.appProviderSetupOpenCodeNotDetectedRefresh ??
                'OpenCode command was not detected. If you installed it moments ago, refresh checks or reopen CodeWalk to reload PATH.')
          : (L10nBridge.current?.appProviderSetupOpenCodeNotDetectedInstall ??
                'OpenCode command was not detected. Run installation from the wizard.');
      _localSetupInProgress = false;
      _localSetupMessage = message;
      _recordSetupDebugEvent(
        source: _setupDebugSourceUseExisting,
        message: message,
        severity: SetupDebugSeverity.error,
        notify: false,
      );
      _setError(message);
      return false;
    }

    await _setLocalServerCommandPath(report.opencode.path.trim());
    _localSetupInProgress = false;
    _localSetupMessage =
        L10nBridge.current?.appProviderSetupUsingOpenCodeAt(
          report.opencode.path,
        ) ??
        'Using OpenCode command at ${report.opencode.path}';
    _errorMessage = '';
    _recordSetupDebugEvent(
      source: _setupDebugSourceUseExisting,
      message: _localSetupMessage,
      notify: false,
    );
    notifyListeners();
    return true;
  }

  Future<bool> installLocalServerRequirements(
    LocalOpencodeInstallMethod method,
  ) async {
    await initialize();
    if (!_localServerRuntime.isSupported) {
      _setError(
        L10nBridge.current?.appProviderErrorManagedDesktopOnly ??
            'Managed local server is available only on desktop.',
      );
      return false;
    }

    _localSetupInProgress = true;
    _localSetupLogs = <String>[];
    _localSetupMessage =
        L10nBridge.current?.appProviderSetupInstallingRequirements ??
        'Installing OpenCode requirements...';
    _errorMessage = '';
    final methodLabel = _installMethodLabel(method);
    _recordSetupDebugEvent(
      source: methodLabel,
      message:
          L10nBridge.current?.setupDebugMessageInstallStarted ??
          'Started OpenCode installation from CodeWalk.',
      notify: false,
    );
    notifyListeners();

    final result = await _localServerRuntime.install(
      method: method,
      onLog: _appendLocalSetupLog,
    );
    if (!result.ok) {
      final message = result.errorMessage?.trim().isNotEmpty == true
          ? result.errorMessage!.trim()
          : (L10nBridge.current?.appProviderErrorInstallationFailed ??
                'OpenCode installation failed.');
      _localSetupInProgress = false;
      _localSetupMessage = message;
      _recordSetupDebugEvent(
        source: methodLabel,
        message: message,
        severity: SetupDebugSeverity.error,
        notify: false,
      );
      _setError(message);
      return false;
    }

    if (result.commandPath?.trim().isNotEmpty == true) {
      await _setLocalServerCommandPath(result.commandPath!.trim());
    }

    await runLocalServerDiagnostics(notify: false);
    _localSetupInProgress = false;
    _localSetupMessage =
        L10nBridge.current?.appProviderSetupRequirementsInstalled ??
        'OpenCode requirements installed successfully.';
    _errorMessage = '';
    _recordSetupDebugEvent(
      source: methodLabel,
      message: result.commandPath?.trim().isNotEmpty == true
          ? (L10nBridge.current?.appProviderSetupInstallationSucceededWithPath(
                  result.commandPath!.trim(),
                ) ??
                'Installation succeeded. OpenCode command available at ${result.commandPath!.trim()}.')
          : (L10nBridge.current?.appProviderSetupInstallationSucceeded ??
                'Installation succeeded.'),
      notify: false,
    );
    notifyListeners();
    return true;
  }

  void clearLocalSetupLogs() {
    _localSetupLogs = <String>[];
    notifyListeners();
  }

  void clearSetupDebugData() {
    _localSetupLogs = <String>[];
    _setupDebugEntries = <SetupDebugEntry>[];
    _localServerLastOutput = '';
    notifyListeners();
  }

  void recordSetupDebugEvent({
    required String source,
    required String message,
    SetupDebugSeverity severity = SetupDebugSeverity.info,
  }) {
    _recordSetupDebugEvent(
      source: source,
      message: message,
      severity: severity,
      notify: true,
    );
  }

  String exportSetupDebugReport() {
    final buffer = StringBuffer()
      ..writeln('=== OpenCode Setup Debug ===')
      ..writeln('Exported: ${DateTime.now().toIso8601String()}')
      ..writeln('Status: $_localServerStatusMessage');

    if (_localSetupMessage.trim().isNotEmpty) {
      buffer.writeln(
        'Setup message: ${_sanitizeSetupDebugText(_localSetupMessage)}',
      );
    }
    if (_localServerCommandPath.trim().isNotEmpty) {
      buffer.writeln(
        'Command path: ${_sanitizeSetupDebugText(_localServerCommandPath)}',
      );
    }
    if (_localServerLastOutput.trim().isNotEmpty) {
      buffer.writeln(
        'Latest server output: ${_sanitizeSetupDebugText(_localServerLastOutput)}',
      );
    }

    final report = _localEnvironmentReport;
    if (report != null) {
      buffer
        ..writeln()
        ..writeln('--- Environment ---')
        ..writeln('Platform: ${_sanitizeSetupDebugText(report.platform)}')
        ..writeln('OpenCode: ${_toolStatusSummary(report.opencode)}')
        ..writeln('Node.js: ${_toolStatusSummary(report.node)}')
        ..writeln('npm: ${_toolStatusSummary(report.npm)}')
        ..writeln('Bun: ${_toolStatusSummary(report.bun)}')
        ..writeln('WSL: ${_toolStatusSummary(report.wsl)}')
        ..writeln(
          'Network: ${report.hasNetworkAccess ? 'reachable' : 'unreachable'}',
        )
        ..writeln(
          'Install directory: ${report.installDirectoryWritable ? 'writable' : 'not writable'}',
        )
        ..writeln(
          'Recommendation: ${_sanitizeSetupDebugText(report.recommendation)}',
        );
    }

    if (_setupDebugEntries.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('--- Timeline ---');
      for (final entry in _setupDebugEntries) {
        buffer.writeln(
          '[${entry.timestamp.toIso8601String()}] ${entry.severity.name.toUpperCase()} ${entry.source}: ${entry.message}',
        );
      }
    }

    if (_localSetupLogs.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('--- Setup Logs ---');
      for (final line in _localSetupLogs) {
        buffer.writeln(line);
      }
    }

    return buffer.toString().trimRight();
  }

  void _appendLocalSetupLog(String line) {
    final value = _sanitizeSetupDebugText(line.trim());
    if (value.isEmpty) {
      return;
    }
    const maxLines = 120;
    _localSetupLogs = <String>[..._localSetupLogs, value];
    if (_localSetupLogs.length > maxLines) {
      _localSetupLogs = _localSetupLogs.sublist(
        _localSetupLogs.length - maxLines,
      );
    }
    notifyListeners();
  }

  Future<void> _setLocalServerCommandPath(String? path) async {
    final normalized = path?.trim() ?? '';
    _localServerCommandPath = normalized;
    await _localDataSource.saveLocalOpencodeCommand(
      normalized.isEmpty ? null : normalized,
    );
  }

  Future<bool> startLocalServer() async {
    await initialize();
    if (!_localServerRuntime.isSupported) {
      _setError(
        L10nBridge.current?.appProviderErrorManagedDesktopOnly ??
            'Managed local server is available only on desktop.',
      );
      return false;
    }
    if (_localServerStatus == LocalServerRuntimeStatus.running ||
        _localServerStatus == LocalServerRuntimeStatus.starting) {
      return true;
    }

    _localServerStoppingByRequest = false;
    _localServerStatus = LocalServerRuntimeStatus.starting;
    _localServerStatusMessage =
        L10nBridge.current?.appProviderStatusStartingLocalServer ??
        'Starting local server...';
    _localServerLastOutput = '';
    _errorMessage = '';
    _recordSetupDebugEvent(
      source: _setupDebugSourceLocalServer,
      message:
          L10nBridge.current?.setupDebugMessageStartLocalServer(
            localServerUrl,
          ) ??
          'Starting managed OpenCode server at $localServerUrl.',
      notify: false,
    );
    notifyListeners();

    if (_localServerCommandPath.trim().isEmpty) {
      await runLocalServerDiagnostics(notify: false);
    }

    final startResult = await _localServerRuntime.start(
      host: _localServerHost,
      port: _localServerPort,
      commandPath: _localServerCommandPath.trim().isEmpty
          ? null
          : _localServerCommandPath,
    );
    if (!startResult.ok) {
      final details = startResult.errorMessage?.trim();
      final message = details != null && details.isNotEmpty
          ? details
          : L10nBridge.current?.appProviderFailedToStart ??
                'Failed to start local OpenCode server.';
      _localServerStatus = LocalServerRuntimeStatus.failed;
      _localServerStatusMessage = message;
      _recordSetupDebugEvent(
        source: _setupDebugSourceLocalServer,
        message: message,
        severity: SetupDebugSeverity.error,
        notify: false,
      );
      _setError(message);
      return false;
    }

    final healthy = await _waitForLocalServerHealth();
    if (!healthy) {
      final message =
          L10nBridge.current?.appProviderErrorLocalServerHealthCheckFailed ??
          'Local server started but health check did not pass.';
      _localServerStatus = LocalServerRuntimeStatus.failed;
      _localServerStatusMessage = message;
      await _localServerRuntime.stop();
      _recordSetupDebugEvent(
        source: _setupDebugSourceLocalServer,
        message: message,
        severity: SetupDebugSeverity.error,
        notify: false,
      );
      _setError(message);
      return false;
    }

    await _ensureLocalServerProfileActive();

    _localServerStatus = LocalServerRuntimeStatus.running;
    _localServerStatusMessage =
        L10nBridge.current?.appProviderStatusRunningAt(localServerUrl) ??
        'Running at $localServerUrl';
    _errorMessage = '';
    _recordSetupDebugEvent(
      source: _setupDebugSourceLocalServer,
      message:
          L10nBridge.current?.setupDebugMessageHealthyRunning(localServerUrl) ??
          'Managed OpenCode server is healthy and running at $localServerUrl.',
      notify: false,
    );
    notifyListeners();
    return true;
  }

  Future<bool> stopLocalServer() async {
    await initialize();
    if (_localServerStatus == LocalServerRuntimeStatus.stopped) {
      return true;
    }

    _localServerStoppingByRequest = true;
    _localServerStatus = LocalServerRuntimeStatus.stopping;
    _localServerStatusMessage =
        L10nBridge.current?.appProviderStatusStoppingLocalServer ??
        'Stopping local server...';
    _errorMessage = '';
    _recordSetupDebugEvent(
      source: _setupDebugSourceLocalServer,
      message:
          L10nBridge.current?.setupDebugMessageStoppingLocalServer ??
          'Stopping managed OpenCode server.',
      notify: false,
    );
    notifyListeners();

    await _localServerRuntime.stop();
    if (_localServerStatus == LocalServerRuntimeStatus.stopping) {
      _localServerStatus = LocalServerRuntimeStatus.stopped;
      _localServerStatusMessage =
          L10nBridge.current?.appProviderStatusLocalServerStopped ??
          'Local server is stopped.';
      _localServerStoppingByRequest = false;
      _recordSetupDebugEvent(
        source: _setupDebugSourceLocalServer,
        message:
            L10nBridge.current?.setupDebugMessageStoppedCleanly ??
            'Managed OpenCode server stopped cleanly.',
        notify: false,
      );
      notifyListeners();
    }

    unawaited(refreshServerHealth());
    return true;
  }

  void _bindLocalServerRuntimeEvents() {
    if (_localServerRuntimeBound) {
      return;
    }
    _localServerRuntimeBound = true;
    _localServerStdoutSubscription = _localServerRuntime.stdoutLines.listen(
      _handleLocalServerOutput,
    );
    _localServerStderrSubscription = _localServerRuntime.stderrLines.listen(
      _handleLocalServerOutput,
    );
    _localServerExitSubscription = _localServerRuntime.exitCodes.listen(
      _handleLocalServerExit,
    );
  }

  void _handleLocalServerOutput(String line) {
    final trimmed = _sanitizeSetupDebugText(line.trim());
    if (trimmed.isEmpty) {
      return;
    }
    _localServerLastOutput = trimmed;
    notifyListeners();
  }

  void _handleLocalServerExit(int code) {
    if (_localServerStoppingByRequest) {
      _localServerStoppingByRequest = false;
      _localServerStatus = LocalServerRuntimeStatus.stopped;
      _localServerStatusMessage =
          L10nBridge.current?.appProviderStatusLocalServerStopped ??
          'Local server is stopped.';
      _recordSetupDebugEvent(
        source: _setupDebugSourceLocalServer,
        message:
            L10nBridge.current?.setupDebugMessageExitedAfterRequestedStop ??
            'Managed OpenCode server exited after a requested stop.',
        notify: false,
      );
      notifyListeners();
      unawaited(refreshServerHealth());
      return;
    }
    if (_localServerStatus == LocalServerRuntimeStatus.stopped) {
      return;
    }

    _localServerStatus = LocalServerRuntimeStatus.failed;
    _localServerStatusMessage =
        L10nBridge.current?.appProviderStatusLocalServerExitedWithCode(code) ??
        'Local server exited with code $code.';
    _recordSetupDebugEvent(
      source: _setupDebugSourceLocalServer,
      message: _localServerStatusMessage,
      severity: SetupDebugSeverity.error,
      notify: false,
    );
    notifyListeners();
    unawaited(refreshServerHealth());
  }

  Future<bool> _waitForLocalServerHealth({
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final startedAt = DateTime.now();
    while (DateTime.now().difference(startedAt) < timeout) {
      final health = await _probeLocalServerHealth();
      if (health == ServerHealthStatus.healthy) {
        return true;
      }
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
    return false;
  }

  Future<ServerHealthStatus> _probeLocalServerHealth() async {
    final normalizedUrl = normalizeServerUrl(
      '$_localServerHost:$_localServerPort',
      fallbackPort: _localServerPort,
    );
    final localServerHealthProbe = _localServerHealthProbe;
    if (localServerHealthProbe != null) {
      return localServerHealthProbe(normalizedUrl);
    }

    final probeProfile = ServerProfile(
      id: '_local_server_probe',
      url: normalizedUrl,
      createdAt: 0,
      updatedAt: 0,
    );
    return _checkServerHealth(probeProfile);
  }

  Future<void> _ensureLocalServerProfileActive() async {
    final normalizedUrl = normalizeServerUrl(
      '$_localServerHost:$_localServerPort',
      fallbackPort: _localServerPort,
    );

    ServerProfile? existing;
    for (final profile in _serverProfiles) {
      if (profile.url == normalizedUrl) {
        existing = profile;
        break;
      }
    }

    if (existing == null) {
      await addServerProfile(
        url: normalizedUrl,
        label:
            L10nBridge.current?.appProviderLabelLocalOpenCodeManaged ??
            'Local OpenCode (Managed)',
        setAsActive: true,
      );
      return;
    }

    await refreshServerHealth(serverId: existing.id);
    await setActiveServer(existing.id, blockUnhealthy: false);
  }

  Future<void> refreshServerHealth({String? serverId}) async {
    await initialize();
    final normalizedServerId = serverId?.trim();

    if (_healthCheckInFlight) {
      _queueHealthRefresh(serverId: normalizedServerId);
      return;
    }

    _healthCheckInFlight = true;
    var runAll = normalizedServerId == null || normalizedServerId.isEmpty;
    var runServerIds = <String>{};
    if (!runAll) {
      runServerIds = <String>{normalizedServerId};
    }

    try {
      while (true) {
        await _refreshServerHealthTargets(
          runAll: runAll,
          serverIds: runServerIds,
        );

        if (_queuedHealthRefreshAll) {
          _queuedHealthRefreshAll = false;
          _queuedHealthServerIds.clear();
          runAll = true;
          runServerIds = <String>{};
          continue;
        }

        if (_queuedHealthServerIds.isNotEmpty) {
          runAll = false;
          runServerIds = Set<String>.from(_queuedHealthServerIds);
          _queuedHealthServerIds.clear();
          continue;
        }

        break;
      }
    } finally {
      _healthCheckInFlight = false;
      _queuedHealthRefreshAll = false;
      _queuedHealthServerIds.clear();
    }
  }

  void _queueHealthRefresh({String? serverId}) {
    final normalizedServerId = serverId?.trim();
    if (normalizedServerId == null || normalizedServerId.isEmpty) {
      _queuedHealthRefreshAll = true;
      _queuedHealthServerIds.clear();
      return;
    }
    if (_queuedHealthRefreshAll) {
      return;
    }
    _queuedHealthServerIds.add(normalizedServerId);
  }

  Future<void> _refreshServerHealthTargets({
    required bool runAll,
    required Set<String> serverIds,
  }) async {
    final targets = runAll
        ? List<ServerProfile>.from(_serverProfiles)
        : _serverProfiles.where((p) => serverIds.contains(p.id)).toList();
    if (targets.isEmpty) {
      return;
    }

    // Heal stale Tailscale state before probing: if the user completed the
    // browser login while the app was backgrounded, the running event may
    // have been missed and _tailscaleState is still needsLogin. One cheap
    // status re-read per poll unblocks connected + healthy without user action.
    final active = activeServer;
    if (active != null &&
        active.tailscaleEnabled &&
        supportsTailscale &&
        !_tailscaleState.isConnected &&
        (runAll || serverIds.contains(active.id))) {
      try {
        await refreshTailscaleStatus();
      } catch (_) {
        // Health probing below still applies the unknown-while-pending gate.
      }
    }

    for (final profile in targets) {
      final previous = _serverHealthById[profile.id];
      final next = await _checkServerHealth(profile);
      _serverHealthById[profile.id] = next;
      if (profile.tailscaleEnabled && previous != next) {
        _recordSetupDebugEvent(
          source: 'Tailscale',
          message:
              'health ${profile.displayName} ${previous?.name ?? 'none'} -> ${next.name} (transport ${_tailscaleState.nodeState.name})',
          severity: next == ServerHealthStatus.unhealthy
              ? SetupDebugSeverity.error
              : SetupDebugSeverity.info,
          notify: false,
        );
      }
    }
    notifyListeners();
  }

  Future<ServerHealthStatus> _checkServerHealth(ServerProfile profile) async {
    final serverHealthProbe = _serverHealthProbe;
    if (serverHealthProbe != null) {
      return serverHealthProbe(profile);
    }

    final isActiveProfile = profile.id == _activeServerId;
    if (profile.tailscaleEnabled && (!isActiveProfile || !supportsTailscale)) {
      return ServerHealthStatus.unknown;
    }
    // Tailscale-first: never probe the destination OpenCode server before
    // the embedded transport is connected. Probing too early uses direct
    // networking, fails, and flaps the profile to Unhealthy.
    if (profile.tailscaleEnabled &&
        isActiveProfile &&
        supportsTailscale &&
        !_tailscaleState.isConnected) {
      return ServerHealthStatus.unknown;
    }

    final dio = profile.tailscaleEnabled
        ? _dioClient.createHealthCheckDio()
        : Dio(
            BaseOptions(
              baseUrl: profile.url,
              connectTimeout: _serverHealthRequestTimeout,
              receiveTimeout: _serverHealthRequestTimeout,
              sendTimeout: _serverHealthRequestTimeout,
            ),
          );
    dio.options.baseUrl = profile.url;
    dio.options.connectTimeout = _serverHealthRequestTimeout;
    dio.options.receiveTimeout = _serverHealthRequestTimeout;
    dio.options.sendTimeout = _serverHealthRequestTimeout;

    if (profile.basicAuthEnabled &&
        profile.basicAuthUsername.trim().isNotEmpty &&
        profile.basicAuthPassword.trim().isNotEmpty) {
      final auth = base64Encode(
        utf8.encode(
          '${profile.basicAuthUsername.trim()}:${profile.basicAuthPassword.trim()}',
        ),
      );
      dio.options.headers[ApiConstants.authorization] = 'Basic $auth';
    } else if (profile.oauthEnabled) {
      try {
        final credential = await _oauthServiceFactory(
          profileId: profile.id,
          serverUrl: profile.url,
        ).getCachedCredential();
        if (credential != null) {
          dio.options.headers[ApiConstants.authorization] =
              'Bearer ${credential.accessToken}';
        }
      } catch (_) {
        AppLogger.warn('Failed to load OAuth credential for health check');
      }
    }

    DioException? firstError;
    try {
      final global = await dio.get('/global/health');
      if (global.statusCode == 200) {
        return ServerHealthStatus.healthy;
      }
      final statusCode = global.statusCode;
      firstError = statusCode == null
          ? DioException(
              requestOptions: global.requestOptions,
              type: DioExceptionType.unknown,
              error: 'Empty status code',
            )
          : DioException.badResponse(
              statusCode: statusCode,
              requestOptions: global.requestOptions,
              response: global,
            );
    } on DioException catch (e) {
      _recordOAuthChallengeFromHealth(profile, e);
      firstError = e;
      // Fallback below.
    }

    try {
      final fallback = await dio.get('/path');
      if (fallback.statusCode == 200) {
        return ServerHealthStatus.healthy;
      }
      _logTailscaleProbeFailure(
        profile,
        DioExceptionType.unknown,
        'HTTP ${fallback.statusCode} (first: ${_probeErrorSummary(firstError)})',
      );
      return ServerHealthStatus.unhealthy;
    } on DioException catch (e) {
      _recordOAuthChallengeFromHealth(profile, e);
      _logTailscaleProbeFailure(profile, e.type, e);
      return ServerHealthStatus.unhealthy;
    }
  }

  /// Records why a Tailscale-profile probe failed. Tailscale transport only
  /// owns the network path, so the concrete Dio failure (timeout type,
  /// refused, TLS, unexpected status) is what distinguishes a tailnet
  /// problem from a dead server. Secrets are redacted by the sanitize
  /// step inside [_recordSetupDebugEvent].
  void _logTailscaleProbeFailure(
    ServerProfile profile,
    DioExceptionType? type,
    Object? error,
  ) {
    if (!profile.tailscaleEnabled) return;
    _recordSetupDebugEvent(
      source: 'Tailscale',
      message:
          'probe ${profile.displayName} failed '
          'type=${type?.name ?? 'http'} '
          'detail=${_probeErrorSummary(error)}',
      severity: SetupDebugSeverity.error,
      notify: false,
    );
  }

  String _probeErrorSummary(Object? error) {
    if (error is DioException) {
      final message = error.message?.trim() ?? '';
      final inner = error.error?.toString().trim() ?? '';
      final combined = <String>[
        if (message.isNotEmpty) message,
        if (inner.isNotEmpty && inner != message) inner,
      ].join(' | ');
      return combined.isEmpty ? error.type.name : combined;
    }
    return error?.toString().trim() ?? 'unknown';
  }

  void _recordOAuthChallengeFromHealth(ServerProfile profile, DioException e) {
    if (!profile.oauthEnabled || e.response == null) return;
    final statusCode = e.response!.statusCode ?? 0;
    final headers = <String, String>{};
    for (final entry in e.response!.headers.map.entries) {
      final value = entry.value.isEmpty ? null : entry.value.first;
      if (value != null) {
        headers[entry.key.toLowerCase()] = value;
      }
    }
    if (!OAuthService.isOAuthChallenge(statusCode, headers)) return;
    _oauthChallengeHeaders[profile.url] = headers;
    final body = e.response!.data;
    if (body is String) {
      _oauthChallengeBodies[profile.url] = body;
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
    if (activeServer == null) {
      _isConnected = false;
      _errorMessage = '';
      notifyListeners();
      return;
    }
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
        oauthEnabled: current.oauthEnabled,
        tailscaleEnabled: current.tailscaleEnabled,
        aiGeneratedTitlesEnabled: current.aiGeneratedTitlesEnabled,
      );
    }

    final created = await addServerProfile(
      url: '$host:$port',
      label:
          L10nBridge.current?.appProviderLabelPrimaryServer ?? 'Primary server',
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

  /// Full in-memory reset after clearAll (used by the app reset feature).
  void resetToDefaults() {
    _status = AppStatus.initial;
    _appInfo = null;
    _errorMessage = '';
    _isConnected = false;
    _initialized = false;
    _initFuture = null;
    _serverProfiles = <ServerProfile>[];
    _activeServerId = null;
    _defaultServerId = null;
    _serverHealthById.clear();
    _healthTimer?.cancel();
    notifyListeners();
  }

  @visibleForTesting
  void setHealthForTesting(String serverId, ServerHealthStatus status) {
    _serverHealthById[serverId] = status;
    notifyListeners();
  }

  @override
  void dispose() {
    _cellularDataSaverService.removeListener(_handleCellularDataSaverChanged);
    _healthTimer?.cancel();
    _localServerStdoutSubscription?.cancel();
    _localServerStderrSubscription?.cancel();
    _localServerExitSubscription?.cancel();
    _tailscaleStateSubscription?.cancel();
    _tailscalePeerSubscription?.cancel();
    unawaited(_localServerRuntime.dispose());
    unawaited(_tailscaleService.down());
    super.dispose();
  }

  void _startHealthPolling() {
    _healthTimer?.cancel();
    _currentHealthPollingInterval = _effectiveHealthPollingInterval;
    _healthTimer = Timer.periodic(_currentHealthPollingInterval, (_) {
      if (_cellularDataSaverService.shouldSuppressBackgroundWork) {
        return;
      }
      if (_cellularDataSaverService.shouldThrottleAutomaticForegroundSync) {
        final activeServerId = _activeServerId;
        if (activeServerId == null || activeServerId.isEmpty) {
          return;
        }
        unawaited(refreshServerHealth(serverId: activeServerId));
        return;
      }
      unawaited(refreshServerHealth());
    });
  }

  void _syncHealthPollingLifecycle() {
    if (!_enableHealthPolling ||
        _serverProfiles.isEmpty ||
        _cellularDataSaverService.shouldSuppressBackgroundWork) {
      _healthTimer?.cancel();
      _healthTimer = null;
      return;
    }
    if (_healthTimer?.isActive == true &&
        _currentHealthPollingInterval == _effectiveHealthPollingInterval) {
      return;
    }
    _startHealthPolling();
  }

  void _handleCellularDataSaverChanged() {
    _syncHealthPollingLifecycle();
  }

  void _initL10nDefaults() {
    final l10n = L10nBridge.current;
    _localServerStatusMessage =
        l10n?.appProviderStatusLocalServerStopped ?? 'Local server is stopped.';
    _localSetupMessage =
        l10n?.onboardingRunDiagnosticsToVerify ??
        'Run diagnostics to verify local OpenCode requirements.';
  }

  void _setStatus(AppStatus status) {
    _status = status;
  }

  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  void _recordSetupDebugEvent({
    required String source,
    required String message,
    SetupDebugSeverity severity = SetupDebugSeverity.info,
    required bool notify,
  }) {
    final sanitizedSource = _sanitizeSetupDebugText(source).trim();
    final sanitizedMessage = _sanitizeSetupDebugText(message).trim();
    if (sanitizedSource.isEmpty || sanitizedMessage.isEmpty) {
      return;
    }

    const maxEntries = 80;
    _setupDebugEntries = <SetupDebugEntry>[
      ..._setupDebugEntries,
      SetupDebugEntry(
        timestamp: DateTime.now(),
        source: sanitizedSource,
        message: sanitizedMessage,
        severity: severity,
      ),
    ];
    if (_setupDebugEntries.length > maxEntries) {
      _setupDebugEntries = _setupDebugEntries.sublist(
        _setupDebugEntries.length - maxEntries,
      );
    }
    if (notify) {
      notifyListeners();
    }
  }

  String get _setupDebugSourceDiagnostics =>
      L10nBridge.current?.setupDebugSourceDiagnostics ?? 'Diagnostics';

  String get _setupDebugSourceUseExisting =>
      L10nBridge.current?.setupDebugSourceUseExisting ?? 'Use Existing';

  String get _setupDebugSourceLocalServer =>
      L10nBridge.current?.setupDebugSourceLocalServer ?? 'Local Server';

  String _installMethodLabel(LocalOpencodeInstallMethod method) {
    final l10n = L10nBridge.current;
    return switch (method) {
      LocalOpencodeInstallMethod.downloadBinary =>
        l10n?.appProviderInstallBinary ?? 'Install Binary',
      LocalOpencodeInstallMethod.npmGlobal =>
        l10n?.appProviderInstallViaNpm ?? 'Install via npm',
      LocalOpencodeInstallMethod.bunGlobal =>
        l10n?.appProviderInstallViaBun ?? 'Install via Bun',
      LocalOpencodeInstallMethod.bunBootstrapThenInstall =>
        l10n?.appProviderInstallBunOpenCode ?? 'Install Bun + OpenCode',
    };
  }

  String _toolStatusSummary(LocalToolStatus status) {
    final details = <String>[];
    if (status.version.trim().isNotEmpty) {
      details.add(_sanitizeSetupDebugText(status.version.trim()));
    }
    if (status.path.trim().isNotEmpty) {
      details.add(_sanitizeSetupDebugText(status.path.trim()));
    }
    if (status.note.trim().isNotEmpty) {
      details.add(_sanitizeSetupDebugText(status.note.trim()));
    }
    if (details.isEmpty) {
      return status.available ? 'available' : 'not available';
    }
    return details.join(' | ');
  }

  String _sanitizeSetupDebugText(String input) {
    if (input.isEmpty) {
      return input;
    }

    var sanitized = input;
    sanitized = sanitized.replaceAllMapped(
      RegExp(r'(Basic\s+)[A-Za-z0-9+/=]+', caseSensitive: false),
      (match) => '${match.group(1)}***',
    );
    sanitized = sanitized.replaceAllMapped(
      RegExp(r'(Bearer\s+)[A-Za-z0-9\-._~+/=]+', caseSensitive: false),
      (match) => '${match.group(1)}***',
    );
    sanitized = sanitized.replaceAllMapped(
      RegExp(r'://([^:@/\s]+):([^@/\s]+)@'),
      (match) => '://${match.group(1)}:***@',
    );
    sanitized = sanitized.replaceAllMapped(
      RegExp(
        "((?:password|token|secret|api[_\\- ]?key|authorization)\\s*[:=]\\s*)([\"']?)([^\"'\\s,;]+)([\"']?)",
        caseSensitive: false,
      ),
      (match) =>
          '${match.group(1)}${match.group(2) ?? ''}***${match.group(4) ?? ''}',
    );
    return sanitized;
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
