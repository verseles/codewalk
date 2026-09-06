import 'dart:async';

import 'package:codewalk/core/auth/oauth_credential.dart';
import 'package:codewalk/core/auth/oauth_service.dart';
import 'package:codewalk/core/errors/failures.dart';
import 'package:codewalk/core/network/dio_client.dart';
import 'package:codewalk/core/tailscale/tailscale_service.dart';
import 'package:codewalk/domain/entities/experience_settings.dart';
import 'package:codewalk/domain/entities/server_profile.dart';
import 'package:codewalk/domain/usecases/check_connection.dart';
import 'package:codewalk/domain/usecases/get_app_info.dart';
import 'package:codewalk/presentation/providers/app_provider.dart';
import 'package:codewalk/presentation/services/cellular_data_saver_service.dart';
import 'package:codewalk/presentation/services/local_opencode_server_runtime_types.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../../support/fakes.dart';

class _FakeTailscaleService extends TailscaleService {
  _FakeTailscaleService(this.nextState);

  final TailscaleState nextState;
  final StreamController<TailscaleState> controller =
      StreamController<TailscaleState>.broadcast();
  var downCalled = false;

  @override
  TailscaleState get state => nextState;

  @override
  Stream<TailscaleState> get stateChanges => controller.stream;

  @override
  http.Client get httpClient => _httpClient;

  final http.Client _httpClient = http.Client();

  @override
  Future<TailscaleState> upForProfile({
    required String profileId,
    required String profileLabel,
  }) async {
    upCalls++;
    if (upDelay > Duration.zero) {
      await Future<void>.delayed(upDelay);
    }
    return nextState;
  }

  Duration upDelay = Duration.zero;
  int upCalls = 0;

  @override
  Future<void> down() async {
    downCalled = true;
  }

  @override
  Future<TailscaleState> refreshStatus() async => nextState;

  var logoutCalled = false;

  @override
  Future<void> logout() async {
    logoutCalled = true;
  }
}

class _FakeOAuthService extends OAuthService {
  _FakeOAuthService({
    required super.profileId,
    required super.serverUrl,
    required this.authenticateHandler,
    this.clearCredentialHandler,
  });

  final Future<OAuthFlowResult> Function() authenticateHandler;
  final Future<void> Function()? clearCredentialHandler;

  @override
  Future<OAuthFlowResult> authenticate({bool skipCache = false}) {
    return authenticateHandler();
  }

  @override
  Future<OAuthCredential?> getCachedCredential() async {
    return null;
  }

  @override
  Future<void> clearCredential() async {
    await clearCredentialHandler?.call();
  }
}

class _CachedCredentialOAuthService extends OAuthService {
  _CachedCredentialOAuthService({required this.credential})
    : super(profileId: 'terminal', serverUrl: 'https://code.example.com');

  final OAuthCredential? credential;

  @override
  Future<OAuthFlowResult> authenticate({bool skipCache = false}) {
    throw UnimplementedError();
  }

  @override
  Future<OAuthCredential?> getCachedCredential() async => credential;

  @override
  Future<void> clearCredential() async {}
}

class _DialRecordingTailscaleService extends _FakeTailscaleService {
  _DialRecordingTailscaleService(super.nextState);

  String? dialHost;
  int? dialPort;

  @override
  Future<TailscaleTcpConnection> dialTcp(
    String host,
    int port, {
    Duration? timeout,
  }) async {
    dialHost = host;
    dialPort = port;
    throw StateError('sentinel-dial');
  }
}

void main() {
  group('AppProvider', () {
    late FakeAppRepository repository;
    late InMemoryAppLocalDataSource localDataSource;
    late FakeLocalOpencodeServerRuntime localServerRuntime;
    late AppProvider provider;

    setUp(() {
      repository = FakeAppRepository();
      localDataSource = InMemoryAppLocalDataSource();
      localServerRuntime = FakeLocalOpencodeServerRuntime();
      provider = AppProvider(
        getAppInfo: GetAppInfo(repository),
        checkConnection: CheckConnection(repository),
        localDataSource: localDataSource,
        dioClient: DioClient(),
        localServerRuntime: localServerRuntime,
        enableHealthPolling: false,
      );
    });

    test('getAppInfo sets loaded state on success', () async {
      await provider.getAppInfo();

      expect(provider.status, AppStatus.loaded);
      expect(provider.isConnected, isTrue);
      expect(provider.errorMessage, isEmpty);
      expect(provider.appInfo?.hostname, 'localhost');
    });

    test('getAppInfo sets error state on failure', () async {
      repository.appInfoResult = const Left(
        NetworkFailure('server unavailable'),
      );

      await provider.getAppInfo();

      expect(provider.status, AppStatus.error);
      expect(provider.isConnected, isFalse);
      expect(provider.errorMessage, 'server unavailable');
    });

    test(
      'updateServerConfig persists host and port in provider state',
      () async {
        await provider.initialize();
        final updated = await provider.updateServerConfig('10.0.0.10', 5050);

        expect(updated, isTrue);
        expect(provider.serverHost, '10.0.0.10');
        expect(provider.serverPort, 5050);
        expect(provider.serverUrl, 'http://10.0.0.10:5050');
      },
    );

    test(
      'initialize migrates legacy host/port into server profile list',
      () async {
        localDataSource.serverHost = '10.10.0.7';
        localDataSource.serverPort = 4010;
        localDataSource.basicAuthEnabled = true;
        localDataSource.basicAuthUsername = 'user';
        localDataSource.basicAuthPassword = 'pass';

        await provider.initialize();

        expect(provider.serverProfiles, hasLength(1));
        expect(provider.activeServerId, isNotNull);
        expect(provider.defaultServerId, provider.activeServerId);
        expect(provider.activeServer?.url, 'http://10.10.0.7:4010');
        expect(provider.activeServer?.basicAuthEnabled, isTrue);
        expect(localDataSource.serverProfilesJson, isNotNull);
      },
    );

    test(
      'initialize keeps empty server list when no legacy config exists',
      () async {
        await provider.initialize();

        expect(provider.serverProfiles, isEmpty);
        expect(provider.activeServerId, isNull);
        expect(provider.defaultServerId, isNull);
      },
    );

    test(
      'checkConnection skips remote call when no server is configured',
      () async {
        repository.checkConnectionResult = const Left(
          NetworkFailure('should not be used without server'),
        );

        await provider.initialize();
        await provider.checkConnection();

        expect(provider.isConnected, isFalse);
        expect(provider.errorMessage, isEmpty);
      },
    );

    test('addServerProfile rejects duplicates after normalization', () async {
      await provider.initialize();
      final created = await provider.addServerProfile(
        url: 'http://127.0.0.1:5009',
      );
      final duplicate = await provider.addServerProfile(url: '127.0.0.1:5009/');

      expect(created, isTrue);
      expect(duplicate, isFalse);
      expect(provider.errorMessage, 'A server with this URL already exists');
    });

    test('removing a server clears its tab icon overrides', () async {
      await provider.initialize();
      expect(
        await provider.addServerProfile(url: 'http://127.0.0.1:5010'),
        isTrue,
      );
      final serverId = provider.activeServer!.id;
      await localDataSource.saveSessionTabIconOverridesJson(
        '{"version":1,"entries":[]}',
        serverId: serverId,
      );

      expect(await provider.removeServerProfile(serverId), isTrue);

      expect(
        await localDataSource.getSessionTabIconOverridesJson(
          serverId: serverId,
        ),
        isNull,
      );
    });

    test('addServerProfile allows OAuth on Android', () async {
      final previous = debugDefaultTargetPlatformOverride;
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await provider.initialize();
        final created = await provider.addServerProfile(
          url: 'https://code.example.com',
          oauthEnabled: true,
        );

        expect(created, isTrue);
        expect(provider.activeServer?.oauthEnabled, isTrue);
        expect(provider.errorMessage, isEmpty);
      } finally {
        debugDefaultTargetPlatformOverride = previous;
      }
    });

    test(
      'addServerProfile blocks OAuth on unsupported platforms (web)',
      () async {
        final previous = debugDefaultTargetPlatformOverride;
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        try {
          await provider.initialize();
          final created = await provider.addServerProfile(
            url: 'https://code.example.com',
            oauthEnabled: true,
          );

          expect(created, isFalse);
          expect(
            provider.errorMessage,
            'Cloudflare Access OAuth is not supported on this platform',
          );
        } finally {
          debugDefaultTargetPlatformOverride = previous;
        }
      },
    );

    test(
      'addServerProfile makes OAuth mutually exclusive with Basic Auth',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.linux;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);

        await provider.initialize();
        final created = await provider.addServerProfile(
          url: 'https://code.example.com',
          basicAuthEnabled: true,
          basicAuthUsername: 'opencode',
          basicAuthPassword: 'password',
          oauthEnabled: true,
        );

        expect(created, isTrue);
        expect(provider.activeServer?.oauthEnabled, isTrue);
        expect(provider.activeServer?.basicAuthEnabled, isFalse);
        expect(provider.activeServer?.basicAuthUsername, isEmpty);
        expect(provider.activeServer?.basicAuthPassword, isEmpty);
      },
    );

    test('OAuth result is discarded after its profile is disabled', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final started = Completer<void>();
      final release = Completer<void>();
      bool? persistAllowed;

      provider = AppProvider(
        getAppInfo: GetAppInfo(repository),
        checkConnection: CheckConnection(repository),
        localDataSource: localDataSource,
        dioClient: DioClient(),
        localServerRuntime: localServerRuntime,
        serverHealthProbe: (_) async => ServerHealthStatus.unknown,
        enableHealthPolling: false,
        oauthServiceFactory:
            ({
              required profileId,
              required serverUrl,
              challengeHeaders,
              challengeBody,
              shouldPersistCredential,
            }) => _FakeOAuthService(
              profileId: profileId,
              serverUrl: serverUrl,
              authenticateHandler: () async {
                if (!started.isCompleted) started.complete();
                await release.future;
                persistAllowed = shouldPersistCredential?.call();
                return OAuthFlowResult(token: 'stale-token');
              },
            ),
      );

      await provider.initialize();
      await provider.addServerProfile(
        url: 'https://code.example.com',
        oauthEnabled: true,
      );
      final profile = provider.activeServer!;
      final auth = provider.handleOAuthChallenge(serverUrl: profile.url);
      await started.future;

      await provider.updateServerProfile(
        id: profile.id,
        url: profile.url,
        label: profile.label,
        basicAuthEnabled: false,
        basicAuthUsername: '',
        basicAuthPassword: '',
        oauthEnabled: false,
        tailscaleEnabled: profile.tailscaleEnabled,
        aiGeneratedTitlesEnabled: profile.aiGeneratedTitlesEnabled,
      );
      release.complete();

      expect(await auth, isFalse);
      expect(persistAllowed, isFalse);
      expect(provider.isOAuthAuthenticated(profile.url), isFalse);
    });

    test('OAuth result is discarded while its profile is removed', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final authStarted = Completer<void>();
      final authRelease = Completer<void>();
      final cleanupStarted = Completer<void>();
      final cleanupRelease = Completer<void>();
      bool? persistAllowed;

      provider = AppProvider(
        getAppInfo: GetAppInfo(repository),
        checkConnection: CheckConnection(repository),
        localDataSource: localDataSource,
        dioClient: DioClient(),
        localServerRuntime: localServerRuntime,
        serverHealthProbe: (_) async => ServerHealthStatus.unknown,
        enableHealthPolling: false,
        oauthServiceFactory:
            ({
              required profileId,
              required serverUrl,
              challengeHeaders,
              challengeBody,
              shouldPersistCredential,
            }) => _FakeOAuthService(
              profileId: profileId,
              serverUrl: serverUrl,
              authenticateHandler: () async {
                if (!authStarted.isCompleted) authStarted.complete();
                await authRelease.future;
                persistAllowed = shouldPersistCredential?.call();
                return OAuthFlowResult(token: 'stale-token');
              },
              clearCredentialHandler: shouldPersistCredential == null
                  ? () async {
                      cleanupStarted.complete();
                      await cleanupRelease.future;
                    }
                  : null,
            ),
      );

      await provider.initialize();
      await provider.addServerProfile(
        url: 'https://code.example.com',
        oauthEnabled: true,
      );
      final profile = provider.activeServer!;
      final auth = provider.handleOAuthChallenge(serverUrl: profile.url);
      await authStarted.future;

      final removal = provider.removeServerProfile(profile.id);
      await cleanupStarted.future;
      authRelease.complete();

      expect(await auth, isFalse);
      expect(persistAllowed, isFalse);
      cleanupRelease.complete();
      expect(await removal, isTrue);
      expect(provider.serverProfiles, isEmpty);
    });

    test('shared OAuth callers receive one normalized failure', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final started = Completer<void>();
      final release = Completer<void>();
      var authenticateCalls = 0;

      provider = AppProvider(
        getAppInfo: GetAppInfo(repository),
        checkConnection: CheckConnection(repository),
        localDataSource: localDataSource,
        dioClient: DioClient(),
        localServerRuntime: localServerRuntime,
        serverHealthProbe: (_) async => ServerHealthStatus.unknown,
        enableHealthPolling: false,
        oauthServiceFactory:
            ({
              required profileId,
              required serverUrl,
              challengeHeaders,
              challengeBody,
              shouldPersistCredential,
            }) => _FakeOAuthService(
              profileId: profileId,
              serverUrl: serverUrl,
              authenticateHandler: () async {
                authenticateCalls++;
                if (!started.isCompleted) started.complete();
                await release.future;
                throw StateError('synthetic OAuth failure');
              },
            ),
      );

      await provider.initialize();
      await provider.addServerProfile(
        url: 'https://code.example.com',
        oauthEnabled: true,
      );
      final first = provider.handleOAuthChallenge(
        serverUrl: 'https://code.example.com',
      );
      await started.future;
      final second = provider.handleOAuthChallenge(
        serverUrl: 'https://code.example.com',
      );
      release.complete();

      expect(await Future.wait(<Future<bool>>[first, second]), <bool>[
        false,
        false,
      ]);
      expect(authenticateCalls, 1);
    });

    test('setActiveServer blocks unhealthy profiles', () async {
      await provider.initialize();
      await provider.addServerProfile(url: 'http://127.0.0.1:5001');
      await provider.addServerProfile(url: 'http://127.0.0.1:5002');
      final target = provider.serverProfiles
          .where((p) => p.url == 'http://127.0.0.1:5002')
          .first;
      provider.setHealthForTesting(target.id, ServerHealthStatus.unhealthy);

      final ok = await provider.setActiveServer(target.id);

      expect(ok, isFalse);
      expect(provider.errorMessage, 'Cannot activate an unhealthy server');
    });

    test(
      'aggressive cellular data saver health polling uses 30 seconds',
      () async {
        final dataSaverService = CellularDataSaverService.disabled()
          ..debugSetDataSaverLevel(DataSaverLevel.aggressive)
          ..debugSetTransport(DataSaverTransport.cellular)
          ..debugSetAppInForeground(true);
        addTearDown(dataSaverService.dispose);
        final testedProvider = AppProvider(
          getAppInfo: GetAppInfo(repository),
          checkConnection: CheckConnection(repository),
          localDataSource: localDataSource,
          dioClient: DioClient(),
          cellularDataSaverService: dataSaverService,
          localServerRuntime: localServerRuntime,
          enableHealthPolling: true,
        );
        addTearDown(testedProvider.dispose);

        await testedProvider.initialize();
        await testedProvider.addServerProfile(url: 'http://127.0.0.1:5001');

        expect(
          testedProvider.debugCurrentHealthPollingInterval,
          const Duration(seconds: 30),
        );
      },
    );

    test('persists AI-generated-title toggle in server profiles', () async {
      await provider.initialize();
      final created = await provider.addServerProfile(
        url: 'http://127.0.0.1:5010',
        aiGeneratedTitlesEnabled: true,
      );

      expect(created, isTrue);
      final profile = provider.serverProfiles
          .where((item) => item.url == 'http://127.0.0.1:5010')
          .first;
      expect(profile.aiGeneratedTitlesEnabled, isTrue);

      final updated = await provider.updateServerProfile(
        id: profile.id,
        url: profile.url,
        label: profile.label,
        basicAuthEnabled: profile.basicAuthEnabled,
        basicAuthUsername: profile.basicAuthUsername,
        basicAuthPassword: profile.basicAuthPassword,
        oauthEnabled: profile.oauthEnabled,
        tailscaleEnabled: profile.tailscaleEnabled,
        aiGeneratedTitlesEnabled: false,
      );

      expect(updated, isTrue);
      final refreshed = provider.serverProfiles
          .where((item) => item.id == profile.id)
          .first;
      expect(refreshed.aiGeneratedTitlesEnabled, isFalse);
    });

    test('inactive Tailscale profile health remains unknown', () async {
      await provider.initialize();
      final activeCreated = await provider.addServerProfile(
        url: 'http://127.0.0.1:5011',
        setAsActive: true,
      );
      final tailscaleCreated = await provider.addServerProfile(
        url: 'http://codewalk.tailnet.ts.net:4096',
        tailscaleEnabled: true,
      );

      expect(activeCreated, isTrue);
      expect(tailscaleCreated, isTrue);
      final tailscaleProfile = provider.serverProfiles
          .where((item) => item.tailscaleEnabled)
          .first;
      expect(tailscaleProfile.id, isNot(provider.activeServerId));
      expect(
        provider.healthFor(tailscaleProfile.id),
        ServerHealthStatus.unknown,
      );
    });

    test(
      'exposes Tailscale machine-auth state for the active profile',
      () async {
        final tailscale = _FakeTailscaleService(
          const TailscaleState(
            nodeState: TailscaleNodeState.needsMachineAuth,
            message: 'Waiting for admin approval.',
          ),
        );
        addTearDown(tailscale.controller.close);
        provider = AppProvider(
          getAppInfo: GetAppInfo(repository),
          checkConnection: CheckConnection(repository),
          localDataSource: localDataSource,
          dioClient: DioClient(),
          tailscaleService: tailscale,
          localServerRuntime: localServerRuntime,
          enableHealthPolling: false,
        );

        await provider.initialize();
        final created = await provider.addServerProfile(
          url: 'http://codewalk.tailnet.ts.net:4096',
          tailscaleEnabled: true,
          setAsActive: true,
        );

        expect(created, isTrue);
        expect(provider.tailscaleNeedsMachineAuth, isTrue);
        expect(provider.tailscaleMessage, 'Waiting for admin approval.');
      },
    );

    test('logoutTailscale clears transport and marks profiles unknown', () async {
      final tailscale = _FakeTailscaleService(
        const TailscaleState(nodeState: TailscaleNodeState.connected),
      );
      addTearDown(tailscale.controller.close);
      provider = AppProvider(
        getAppInfo: GetAppInfo(repository),
        checkConnection: CheckConnection(repository),
        localDataSource: localDataSource,
        dioClient: DioClient(),
        tailscaleService: tailscale,
        localServerRuntime: localServerRuntime,
        enableHealthPolling: false,
      );

      await provider.initialize();
      final created = await provider.addServerProfile(
        url: 'http://codewalk.tailnet.ts.net:4096',
        tailscaleEnabled: true,
        setAsActive: true,
      );
      expect(created, isTrue);
      expect(
        provider.tailscaleState.nodeState,
        TailscaleNodeState.connected,
      );

      await provider.logoutTailscale();

      expect(tailscale.logoutCalled, isTrue);
      expect(
        provider.tailscaleState.nodeState,
        TailscaleNodeState.disconnected,
      );
      expect(
        provider.healthFor(provider.activeServerId!),
        ServerHealthStatus.unknown,
      );
    });

    test('concurrent authenticateTailscale calls share one login attempt',
        () async {
      final tailscale = _FakeTailscaleService(
        const TailscaleState(nodeState: TailscaleNodeState.connecting),
      );
      addTearDown(tailscale.controller.close);
      final launched = <Uri>[];
      provider = AppProvider(
        getAppInfo: GetAppInfo(repository),
        checkConnection: CheckConnection(repository),
        localDataSource: localDataSource,
        dioClient: DioClient(),
        tailscaleService: tailscale,
        tailscaleAuthLauncher: (authUrl) async {
          launched.add(authUrl);
          return true;
        },
        localServerRuntime: localServerRuntime,
        serverHealthProbe: (_) async => ServerHealthStatus.unknown,
        enableHealthPolling: false,
      );

      await provider.initialize();
      final created = await provider.addServerProfile(
        url: 'http://codewalk.tailnet.ts.net:4096',
        tailscaleEnabled: true,
        setAsActive: true,
      );
      expect(created, isTrue);

      final loginUrl = Uri.parse('https://login.tailscale.com/a/test');
      final first = provider.authenticateTailscale();
      final second = provider.authenticateTailscale();
      await Future<void>.delayed(Duration.zero);
      tailscale.controller.add(
        TailscaleState(
          nodeState: TailscaleNodeState.needsLogin,
          authUrl: loginUrl,
        ),
      );

      expect(await first, isTrue);
      expect(await second, isTrue);
      expect(launched, <Uri>[loginUrl]);
    });

    test('concurrent retries share one transport restart', () async {
      final tailscale = _FakeTailscaleService(
        const TailscaleState(nodeState: TailscaleNodeState.error),
      );
      tailscale.upDelay = const Duration(milliseconds: 100);
      addTearDown(tailscale.controller.close);
      provider = AppProvider(
        getAppInfo: GetAppInfo(repository),
        checkConnection: CheckConnection(repository),
        localDataSource: localDataSource,
        dioClient: DioClient(),
        tailscaleService: tailscale,
        localServerRuntime: localServerRuntime,
        serverHealthProbe: (_) async => ServerHealthStatus.unknown,
        enableHealthPolling: false,
      );

      await provider.initialize();
      final created = await provider.addServerProfile(
        url: 'http://codewalk.tailnet.ts.net:4096',
        tailscaleEnabled: true,
        setAsActive: true,
      );
      expect(created, isTrue);
      final callsAfterSetup = tailscale.upCalls;

      final first = provider.retryTailscaleTransport();
      final second = provider.retryTailscaleTransport();
      expect(provider.tailscaleRetryBusy, isTrue);
      expect(provider.tailscaleBusy, isTrue);
      await first;
      await second;

      expect(tailscale.upCalls, callsAfterSetup + 1);
      expect(provider.tailscaleRetryBusy, isFalse);
    });

    test('connected transition consumes the open-tab flag', () async {
      final previous = debugDefaultTargetPlatformOverride;
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() {
        debugDefaultTargetPlatformOverride = previous;
        AppProvider.setTailscaleTabOpenedForTesting(null);
      });

      final tailscale = _FakeTailscaleService(
        const TailscaleState(nodeState: TailscaleNodeState.connecting),
      );
      addTearDown(tailscale.controller.close);
      provider = AppProvider(
        getAppInfo: GetAppInfo(repository),
        checkConnection: CheckConnection(repository),
        localDataSource: localDataSource,
        dioClient: DioClient(),
        tailscaleService: tailscale,
        localServerRuntime: localServerRuntime,
        serverHealthProbe: (_) async => ServerHealthStatus.unknown,
        enableHealthPolling: false,
      );

      await provider.initialize();
      final created = await provider.addServerProfile(
        url: 'http://codewalk.tailnet.ts.net:4096',
        tailscaleEnabled: true,
        setAsActive: true,
      );
      expect(created, isTrue);

      AppProvider.setTailscaleTabOpenedForTesting(DateTime.now());
      tailscale.controller.add(
        const TailscaleState(nodeState: TailscaleNodeState.connected),
      );
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(AppProvider.tailscaleTabOpenedForTesting, isNull);
      expect(
        provider.tailscaleState.nodeState,
        TailscaleNodeState.connected,
      );
    });

    test('waits for Tailscale auth URL before launching login', () async {
      final previous = debugDefaultTargetPlatformOverride;
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      addTearDown(() => debugDefaultTargetPlatformOverride = previous);

      final tailscale = _FakeTailscaleService(
        const TailscaleState(nodeState: TailscaleNodeState.connecting),
      );
      addTearDown(tailscale.controller.close);
      final launched = <Uri>[];
      provider = AppProvider(
        getAppInfo: GetAppInfo(repository),
        checkConnection: CheckConnection(repository),
        localDataSource: localDataSource,
        dioClient: DioClient(),
        tailscaleService: tailscale,
        tailscaleAuthLauncher: (authUrl) async {
          launched.add(authUrl);
          return true;
        },
        localServerRuntime: localServerRuntime,
        serverHealthProbe: (_) async => ServerHealthStatus.unknown,
        enableHealthPolling: false,
      );

      await provider.initialize();
      final created = await provider.addServerProfile(
        url: 'http://codewalk.tailnet.ts.net:4096',
        tailscaleEnabled: true,
        setAsActive: true,
      );

      expect(created, isTrue);

      final loginUrl = Uri.parse('https://login.tailscale.com/a/test');
      final authFuture = provider.authenticateTailscale();
      await Future<void>.delayed(Duration.zero);
      tailscale.controller.add(
        TailscaleState(
          nodeState: TailscaleNodeState.needsLogin,
          authUrl: loginUrl,
        ),
      );

      expect(await authFuture, isTrue);
      expect(launched, <Uri>[loginUrl]);
    });

    test(
      'startLocalServer creates and activates managed local profile',
      () async {
        localServerRuntime.supported = true;
        provider = AppProvider(
          getAppInfo: GetAppInfo(repository),
          checkConnection: CheckConnection(repository),
          localDataSource: localDataSource,
          dioClient: DioClient(),
          localServerRuntime: localServerRuntime,
          localServerHealthProbe: (_) async => ServerHealthStatus.healthy,
          enableHealthPolling: false,
        );

        await provider.initialize();
        final ok = await provider.startLocalServer();

        expect(ok, isTrue);
        expect(provider.localServerStatus, LocalServerRuntimeStatus.running);
        expect(provider.activeServer?.url, 'http://127.0.0.1:4096');
        expect(
          provider.serverProfiles
              .where((profile) => profile.url == 'http://127.0.0.1:4096')
              .isNotEmpty,
          isTrue,
        );
      },
    );

    test('stopLocalServer moves status back to stopped', () async {
      localServerRuntime.supported = true;
      provider = AppProvider(
        getAppInfo: GetAppInfo(repository),
        checkConnection: CheckConnection(repository),
        localDataSource: localDataSource,
        dioClient: DioClient(),
        localServerRuntime: localServerRuntime,
        localServerHealthProbe: (_) async => ServerHealthStatus.healthy,
        enableHealthPolling: false,
      );

      await provider.initialize();
      await provider.startLocalServer();
      final ok = await provider.stopLocalServer();

      expect(ok, isTrue);
      expect(provider.localServerStatus, LocalServerRuntimeStatus.stopped);
    });

    test('startLocalServer reports launch failures', () async {
      localServerRuntime = FakeLocalOpencodeServerRuntime(
        supported: true,
        startResult: const LocalOpencodeServerStartResult(
          ok: false,
          errorMessage: 'opencode command was not found',
        ),
      );
      provider = AppProvider(
        getAppInfo: GetAppInfo(repository),
        checkConnection: CheckConnection(repository),
        localDataSource: localDataSource,
        dioClient: DioClient(),
        localServerRuntime: localServerRuntime,
        enableHealthPolling: false,
      );

      await provider.initialize();
      final ok = await provider.startLocalServer();

      expect(ok, isFalse);
      expect(provider.localServerStatus, LocalServerRuntimeStatus.failed);
      expect(provider.errorMessage, 'opencode command was not found');
    });

    test('runLocalServerDiagnostics stores detected command path', () async {
      localServerRuntime.supported = true;
      localServerRuntime.diagnoseResult = const LocalOpencodeEnvironmentReport(
        supported: true,
        platform: 'linux',
        opencode: LocalToolStatus(
          available: true,
          path: '/tmp/opencode',
          version: '1.2.4',
        ),
        node: LocalToolStatus(available: true),
        npm: LocalToolStatus(available: true),
        bun: LocalToolStatus(available: true),
        wsl: LocalToolStatus(available: false),
        hasNetworkAccess: true,
        installDirectoryWritable: true,
        recommendation: 'Use existing OpenCode',
      );

      await provider.initialize();
      await provider.runLocalServerDiagnostics();

      expect(provider.localEnvironmentReport, isNotNull);
      expect(provider.localServerCommandPath, '/tmp/opencode');
      expect(localDataSource.localOpencodeCommand, '/tmp/opencode');
    });

    test('installLocalServerRequirements persists installer command', () async {
      localServerRuntime.supported = true;
      localServerRuntime.installResult = const LocalOpencodeInstallResult(
        ok: true,
        commandPath: '/opt/codewalk/opencode',
      );
      localServerRuntime.diagnoseResult = const LocalOpencodeEnvironmentReport(
        supported: true,
        platform: 'linux',
        opencode: LocalToolStatus(
          available: true,
          path: '/opt/codewalk/opencode',
          version: '1.2.4',
        ),
        node: LocalToolStatus(available: true),
        npm: LocalToolStatus(available: true),
        bun: LocalToolStatus(available: true),
        wsl: LocalToolStatus(available: false),
        hasNetworkAccess: true,
        installDirectoryWritable: true,
        recommendation: 'Ready',
      );

      await provider.initialize();
      final ok = await provider.installLocalServerRequirements(
        LocalOpencodeInstallMethod.downloadBinary,
      );

      expect(ok, isTrue);
      expect(provider.localSetupInProgress, isFalse);
      expect(provider.localServerCommandPath, '/opt/codewalk/opencode');
      expect(localDataSource.localOpencodeCommand, '/opt/codewalk/opencode');
      expect(
        localServerRuntime.lastInstallMethod,
        LocalOpencodeInstallMethod.downloadBinary,
      );
    });

    test('setup debug events redact secrets in entries and export', () async {
      await provider.initialize();

      provider.recordSetupDebugEvent(
        source: 'Manual connection',
        message: 'Authorization: Bearer secret-token password=hunter2',
        severity: SetupDebugSeverity.error,
      );

      expect(provider.setupDebugEntries, isNotEmpty);
      expect(
        provider.setupDebugEntries.last.message,
        contains('Authorization:'),
      );
      expect(provider.setupDebugEntries.last.message, contains('***'));
      expect(
        provider.setupDebugEntries.last.message,
        isNot(contains('hunter2')),
      );
      expect(
        provider.setupDebugEntries.last.message,
        isNot(contains('secret-token')),
      );

      final export = provider.exportSetupDebugReport();
      expect(export, contains('Authorization:'));
      expect(export, contains('***'));
      expect(export, isNot(contains('secret-token')));
      expect(export, isNot(contains('hunter2')));
    });

    test('terminalAuthHeaders prefers explicit basic auth', () async {
      await provider.initialize();

      const profile = ServerProfile(
        id: 'srv',
        url: 'http://100.64.0.5:4096',
        basicAuthEnabled: true,
        basicAuthUsername: 'user',
        basicAuthPassword: 'pass',
        createdAt: 0,
        updatedAt: 0,
      );

      final headers = await provider.terminalAuthHeaders(profile);

      expect(headers?['Authorization'], startsWith('Basic '));
    });

    test('terminalAuthHeaders uses the cached oauth bearer', () async {
      provider = AppProvider(
        getAppInfo: GetAppInfo(repository),
        checkConnection: CheckConnection(repository),
        localDataSource: localDataSource,
        dioClient: DioClient(),
        localServerRuntime: localServerRuntime,
        enableHealthPolling: false,
        oauthServiceFactory:
            ({
              required profileId,
              required serverUrl,
              challengeHeaders,
              challengeBody,
              shouldPersistCredential,
            }) => _CachedCredentialOAuthService(
              credential: const OAuthCredential(
                profileId: 'terminal',
                accessToken: 'oauth-token',
                serverUrl: 'https://code.example.com',
              ),
            ),
      );
      await provider.initialize();

      const profile = ServerProfile(
        id: 'srv',
        url: 'https://code.example.com',
        oauthEnabled: true,
        createdAt: 0,
        updatedAt: 0,
      );

      final headers = await provider.terminalAuthHeaders(profile);

      expect(headers?['Authorization'], 'Bearer oauth-token');
    });

    test('terminalAuthHeaders returns null without credentials', () async {
      await provider.initialize();

      const profile = ServerProfile(
        id: 'srv',
        url: 'http://100.64.0.5:4096',
        createdAt: 0,
        updatedAt: 0,
      );

      expect(await provider.terminalAuthHeaders(profile), isNull);
    });

    test(
      'openTerminalSocketOverTailscale fails fast while disconnected',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.linux;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        final tailscale = _FakeTailscaleService(
          const TailscaleState(nodeState: TailscaleNodeState.disconnected),
        );
        addTearDown(tailscale.controller.close);
        provider = AppProvider(
          getAppInfo: GetAppInfo(repository),
          checkConnection: CheckConnection(repository),
          localDataSource: localDataSource,
          dioClient: DioClient(),
          tailscaleService: tailscale,
          localServerRuntime: localServerRuntime,
          enableHealthPolling: false,
        );
        await provider.initialize();

        expect(
          () => provider.openTerminalSocketOverTailscale(
            url: Uri.parse(
              'ws://100.64.0.5:4096/pty/x/connect?directory=%2Fa',
            ),
          ),
          throwsA(isA<StateError>()),
        );
      },
    );

    test(
      'openTerminalSocketOverTailscale dials the tailnet when connected',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.linux;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        final tailscale = _DialRecordingTailscaleService(
          const TailscaleState(nodeState: TailscaleNodeState.connected),
        );
        addTearDown(tailscale.controller.close);
        provider = AppProvider(
          getAppInfo: GetAppInfo(repository),
          checkConnection: CheckConnection(repository),
          localDataSource: localDataSource,
          dioClient: DioClient(),
          tailscaleService: tailscale,
          localServerRuntime: localServerRuntime,
          enableHealthPolling: false,
        );
        await provider.initialize();
        final created = await provider.addServerProfile(
          url: 'http://codewalk.tailnet.ts.net:4096',
          tailscaleEnabled: true,
          setAsActive: true,
        );
        expect(created, isTrue);
        expect(
          provider.tailscaleState.nodeState,
          TailscaleNodeState.connected,
        );

        await expectLater(
          provider.openTerminalSocketOverTailscale(
            url: Uri.parse(
              'ws://100.64.0.5:4096/pty/x/connect?directory=%2Fa',
            ),
          ),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              contains('sentinel-dial'),
            ),
          ),
        );
        expect(tailscale.dialHost, '100.64.0.5');
        expect(tailscale.dialPort, 4096);
      },
    );
  });

  group('health sweep notifications (issue #180)', () {
    Future<AppProvider> buildProbeProvider(
      ServerHealthStatus Function() current,
    ) async {
      final repo = FakeAppRepository();
      final dataSource = InMemoryAppLocalDataSource();
      final runtime = FakeLocalOpencodeServerRuntime();
      final probeProvider = AppProvider(
        getAppInfo: GetAppInfo(repo),
        checkConnection: CheckConnection(repo),
        localDataSource: dataSource,
        dioClient: DioClient(),
        localServerRuntime: runtime,
        serverHealthProbe: (_) async => current(),
        enableHealthPolling: false,
      );
      await probeProvider.initialize();
      await probeProvider.addServerProfile(url: 'https://a.example.com');
      return probeProvider;
    }

    test('identical sweep does not notify', () async {
      final probeProvider = await buildProbeProvider(
        () => ServerHealthStatus.healthy,
      );
      final profileId = probeProvider.serverProfiles.single.id;
      await probeProvider.refreshServerHealth();

      var notifications = 0;
      probeProvider.addListener(() => notifications += 1);
      await probeProvider.refreshServerHealth();

      expect(notifications, 0);
      expect(
        probeProvider.healthFor(profileId),
        ServerHealthStatus.healthy,
      );
    });

    test('changed sweep notifies once per sweep', () async {
      var probeResult = ServerHealthStatus.healthy;
      final probeProvider = await buildProbeProvider(() => probeResult);
      final profileId = probeProvider.serverProfiles.single.id;
      await probeProvider.refreshServerHealth();

      probeResult = ServerHealthStatus.unhealthy;
      var notifications = 0;
      probeProvider.addListener(() => notifications += 1);
      await probeProvider.refreshServerHealth();

      expect(notifications, 1);
      expect(
        probeProvider.healthFor(profileId),
        ServerHealthStatus.unhealthy,
      );
    });
  });
}
