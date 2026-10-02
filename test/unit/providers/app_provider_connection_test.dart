import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:codewalk/core/errors/failures.dart';
import 'package:codewalk/core/network/dio_client.dart';
import 'package:codewalk/domain/usecases/check_connection.dart';
import 'package:codewalk/domain/usecases/get_app_info.dart';
import 'package:codewalk/presentation/providers/app_provider.dart';
import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

class _QueuedConnectionRepository extends FakeAppRepository {
  final calls = <Completer<Either<Failure, bool>>>[];

  @override
  Future<Either<Failure, bool>> checkConnection({String? directory}) {
    final call = Completer<Either<Failure, bool>>();
    calls.add(call);
    return call.future;
  }
}

void main() {
  late HttpServer server;
  late AppProvider provider;
  late FakeAppRepository repository;
  late Object? globalBody;
  late Object? pathBody;
  late int globalStatus;
  late bool globalHtml;
  late bool pathHtml;
  String? globalRaw;
  final requests = <String>[];
  final authorization = <String?>[];

  setUp(() async {
    globalBody = <String, dynamic>{'healthy': true, 'version': '1.18.34'};
    pathBody = <String, dynamic>{
      'config': '/config',
      'state': '/state',
      'worktree': '/project',
      'directory': '/project',
    };
    globalStatus = 200;
    globalHtml = false;
    pathHtml = false;
    globalRaw = null;
    requests.clear();
    authorization.clear();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      requests.add(request.uri.path);
      authorization.add(request.headers.value(HttpHeaders.authorizationHeader));
      final isGlobal = request.uri.path == '/global/health';
      request.response.statusCode = isGlobal ? globalStatus : 200;
      final html = isGlobal ? globalHtml : pathHtml;
      request.response.headers.contentType = html
          ? ContentType.html
          : ContentType.json;
      request.response.write(
        html
            ? '<html>login</html>'
            : (isGlobal ? globalRaw : null) ??
                  jsonEncode(isGlobal ? globalBody : pathBody),
      );
      await request.response.close();
    });
    repository = FakeAppRepository();
    provider = AppProvider(
      getAppInfo: GetAppInfo(repository),
      checkConnection: CheckConnection(repository),
      localDataSource: InMemoryAppLocalDataSource(),
      dioClient: DioClient(),
      localServerRuntime: FakeLocalOpencodeServerRuntime(),
      enableHealthPolling: false,
    );
    await provider.initialize();
  });

  tearDown(() async {
    provider.dispose();
    await server.close(force: true);
  });

  Future<String> addProfile() async {
    expect(
      await provider.addServerProfile(
        url: 'http://127.0.0.1:${server.port}',
        basicAuthEnabled: true,
        basicAuthUsername: 'opencode',
        basicAuthPassword: 'test-password',
        setAsActive: true,
      ),
      isTrue,
    );
    return provider.activeServerId!;
  }

  test(
    'production probe accepts official health and sends Basic auth',
    () async {
      final id = await addProfile();
      expect(provider.healthFor(id), ServerHealthStatus.healthy);
      expect(requests, <String>['/global/health']);
      expect(
        authorization.single,
        'Basic ${base64Encode(utf8.encode('opencode:test-password'))}',
      );
    },
  );

  test('explicit unhealthy response cannot be overridden by /path', () async {
    globalBody = <String, dynamic>{'healthy': false};
    final id = await addProfile();
    expect(provider.healthFor(id), ServerHealthStatus.unhealthy);
    expect(requests, <String>['/global/health']);
    expect(provider.healthErrorFor(id), isNotEmpty);
  });

  test(
    'HTML 200 stays unhealthy, keeps profile, and clears diagnostic on recovery',
    () async {
      globalHtml = true;
      pathHtml = true;
      final id = await addProfile();
      expect(provider.healthFor(id), ServerHealthStatus.unhealthy);
      expect(provider.healthErrorFor(id), contains('/path'));
      expect(provider.serverProfiles, hasLength(1));
      expect(requests, <String>['/global/health', '/path']);
      pathHtml = false;
      await provider.refreshServerHealth(serverId: id);
      expect(provider.healthFor(id), ServerHealthStatus.healthy);
      expect(provider.healthErrorFor(id), isNull);
    },
  );

  test('unavailable health shape falls back to a verified path', () async {
    globalBody = <String, dynamic>{'ok': true};
    final id = await addProfile();
    expect(provider.healthFor(id), ServerHealthStatus.healthy);
    expect(requests, <String>['/global/health', '/path']);
  });

  test(
    'authentication failure stops probing and retains its HTTP code',
    () async {
      globalStatus = 401;
      final id = await addProfile();
      expect(provider.healthFor(id), ServerHealthStatus.unhealthy);
      expect(provider.healthErrorFor(id), contains('HTTP 401'));
      expect(requests, <String>['/global/health']);
    },
  );

  test(
    'active app-info failure survives successful health and profile save',
    () async {
      final id = await addProfile();
      repository.checkConnectionResult = const Left(
        NetworkFailure('Client error', 403),
      );
      expect(
        await provider.updateServerProfile(
          id: id,
          url: provider.activeServer!.url,
          basicAuthEnabled: true,
          basicAuthUsername: 'opencode',
          basicAuthPassword: 'test-password',
          oauthEnabled: false,
          tailscaleEnabled: false,
          aiGeneratedTitlesEnabled: true,
        ),
        isTrue,
      );
      expect(provider.healthFor(id), ServerHealthStatus.healthy);
      expect(provider.isConnected, isFalse);
      expect(provider.errorMessage, contains('HTTP 403'));
      expect(provider.serverProfiles, hasLength(1));
    },
  );
  test(
    'older connection result cannot replace a newer successful check',
    () async {
      final queued = _QueuedConnectionRepository();
      provider.dispose();
      provider = AppProvider(
        getAppInfo: GetAppInfo(queued),
        checkConnection: CheckConnection(queued),
        localDataSource: InMemoryAppLocalDataSource(),
        dioClient: DioClient(),
        localServerRuntime: FakeLocalOpencodeServerRuntime(),
        enableHealthPolling: false,
      );
      await provider.initialize();
      await addProfile();
      final first = provider.checkConnection();
      await Future<void>.delayed(Duration.zero);
      final second = provider.checkConnection();
      await Future<void>.delayed(Duration.zero);
      expect(queued.calls, hasLength(2));
      queued.calls[1].complete(const Right(true));
      await second;
      queued.calls[0].complete(const Left(NetworkFailure('stale failure')));
      await first;
      expect(provider.isConnected, isTrue);
      expect(provider.errorMessage, isEmpty);
    },
  );

  test('malformed JSON health falls back to a verified path', () async {
    globalRaw = '{invalid-json';
    final id = await addProfile();
    expect(provider.healthFor(id), ServerHealthStatus.healthy);
    expect(requests, <String>['/global/health', '/path']);
  });

  test('malformed JSON 401 health retains HTTP diagnostic', () async {
    globalRaw = '{private-response';
    globalStatus = 401;
    final id = await addProfile();
    expect(provider.healthFor(id), ServerHealthStatus.unhealthy);
    expect(provider.healthErrorFor(id), contains('HTTP 401'));
    expect(provider.healthErrorFor(id), isNot(contains('private-response')));
    expect(requests, <String>['/global/health']);
  });

  test('delayed update cannot restore an error after a newer check', () async {
    final health = Completer<ServerHealthStatus>();
    var delayHealth = false;
    provider.dispose();
    provider = AppProvider(
      getAppInfo: GetAppInfo(repository),
      checkConnection: CheckConnection(repository),
      localDataSource: InMemoryAppLocalDataSource(),
      dioClient: DioClient(),
      serverHealthProbe: (_) => delayHealth
          ? health.future
          : Future.value(ServerHealthStatus.healthy),
      enableHealthPolling: false,
    );
    await provider.initialize();
    final id = await addProfile();
    delayHealth = true;
    repository.checkConnectionResult = const Left(NetworkFailure('old', 403));
    final updating = provider.updateServerProfile(
      id: id,
      url: provider.activeServer!.url,
      basicAuthEnabled: false,
      basicAuthUsername: '',
      basicAuthPassword: '',
      oauthEnabled: false,
      tailscaleEnabled: false,
      aiGeneratedTitlesEnabled: true,
    );
    await Future<void>.delayed(Duration.zero);
    expect(provider.errorMessage, contains('HTTP 403'));
    repository.checkConnectionResult = const Right(true);
    await provider.checkConnection();
    health.complete(ServerHealthStatus.healthy);
    await updating;
    expect(provider.isConnected, isTrue);
    expect(provider.errorMessage, isEmpty);
  });

  test(
    'cancelled update preserves newer unhealthy status and diagnostic',
    () async {
      final queued = _QueuedConnectionRepository();
      provider.dispose();
      provider = AppProvider(
        getAppInfo: GetAppInfo(queued),
        checkConnection: CheckConnection(queued),
        localDataSource: InMemoryAppLocalDataSource(),
        dioClient: DioClient(),
        enableHealthPolling: false,
      );
      await provider.initialize();
      final id = await addProfile();
      final token = CancelToken();
      final oldUpdate = provider.updateServerProfile(
        id: id,
        url: provider.activeServer!.url,
        basicAuthEnabled: false,
        basicAuthUsername: '',
        basicAuthPassword: '',
        oauthEnabled: false,
        tailscaleEnabled: false,
        aiGeneratedTitlesEnabled: true,
        healthCancelToken: token,
      );
      await Future<void>.delayed(Duration.zero);
      token.cancel();
      globalHtml = true;
      pathHtml = true;
      await provider.refreshServerHealth(serverId: id);
      final currentHealthError = provider.healthErrorFor(id);
      expect(currentHealthError, isNotNull);
      final newerCheck = provider.checkConnection();
      await Future<void>.delayed(Duration.zero);
      queued.calls[1].complete(const Left(NetworkFailure('current', 401)));
      await newerCheck;
      queued.calls[0].complete(const Left(NetworkFailure('obsolete', 403)));
      await oldUpdate;
      expect(provider.healthFor(id), ServerHealthStatus.unhealthy);
      expect(provider.healthErrorFor(id), currentHealthError);
      expect(provider.errorMessage, contains('HTTP 401'));
    },
  );

  test('cancelled add cannot clear a newer connection failure', () async {
    final health = Completer<ServerHealthStatus>();
    provider.dispose();
    provider = AppProvider(
      getAppInfo: GetAppInfo(repository),
      checkConnection: CheckConnection(repository),
      localDataSource: InMemoryAppLocalDataSource(),
      dioClient: DioClient(),
      serverHealthProbe: (_) => health.future,
      enableHealthPolling: false,
    );
    await provider.initialize();
    final token = CancelToken();
    final adding = provider.addServerProfile(
      url: 'http://127.0.0.1:${server.port}',
      setAsActive: true,
      healthCancelToken: token,
    );
    await Future<void>.delayed(Duration.zero);
    token.cancel();
    repository.checkConnectionResult = const Left(
      NetworkFailure('current', 401),
    );
    await provider.checkConnection();
    health.complete(ServerHealthStatus.healthy);
    await adding;
    expect(provider.errorMessage, contains('HTTP 401'));
    expect(
      provider.healthFor(provider.activeServerId!),
      ServerHealthStatus.unknown,
    );
    expect(provider.serverProfiles, hasLength(1));
  });

  test(
    'adding an inactive profile preserves the active HTTP failure',
    () async {
      final activeId = await addProfile();
      repository.checkConnectionResult = const Left(
        NetworkFailure('active', 401),
      );
      await provider.checkConnection();
      await provider.addServerProfile(url: 'http://localhost:${server.port}');
      expect(provider.activeServerId, activeId);
      expect(provider.errorMessage, contains('HTTP 401'));
      expect(
        provider.healthFor(provider.serverProfiles.last.id),
        ServerHealthStatus.healthy,
      );
    },
  );

  test(
    'uncancelled delayed add preserves a newer connection failure',
    () async {
      final health = Completer<ServerHealthStatus>();
      provider.dispose();
      provider = AppProvider(
        getAppInfo: GetAppInfo(repository),
        checkConnection: CheckConnection(repository),
        localDataSource: InMemoryAppLocalDataSource(),
        dioClient: DioClient(),
        serverHealthProbe: (_) => health.future,
        enableHealthPolling: false,
      );
      await provider.initialize();
      final adding = provider.addServerProfile(
        url: 'http://127.0.0.1:${server.port}',
        setAsActive: true,
      );
      await Future<void>.delayed(Duration.zero);
      repository.checkConnectionResult = const Left(
        NetworkFailure('current', 401),
      );
      await provider.checkConnection();
      health.complete(ServerHealthStatus.healthy);
      await adding;
      expect(provider.errorMessage, contains('HTTP 401'));
    },
  );

  test('cancelled queued edit retains its completed health result', () async {
    final health = Completer<ServerHealthStatus>();
    String? delayedId;
    var editedProbeCalls = 0;
    provider.dispose();
    provider = AppProvider(
      getAppInfo: GetAppInfo(repository),
      checkConnection: CheckConnection(repository),
      localDataSource: InMemoryAppLocalDataSource(),
      dioClient: DioClient(),
      serverHealthProbe: (profile) {
        if (profile.id == delayedId) return health.future;
        if (profile.url.contains('edited.example')) editedProbeCalls++;
        return Future.value(ServerHealthStatus.healthy);
      },
      enableHealthPolling: false,
    );
    await provider.initialize();
    delayedId = await addProfile();
    await provider.addServerProfile(url: 'http://secondary.example:4096');
    final secondary = provider.serverProfiles.last;
    final sweep = provider.refreshServerHealth(serverId: delayedId);
    await Future<void>.delayed(Duration.zero);
    final token = CancelToken();
    final editing = provider.updateServerProfile(
      id: secondary.id,
      url: 'http://edited.example:4096',
      basicAuthEnabled: false,
      basicAuthUsername: '',
      basicAuthPassword: '',
      oauthEnabled: false,
      tailscaleEnabled: false,
      aiGeneratedTitlesEnabled: true,
      healthCancelToken: token,
    );
    await Future<void>.delayed(Duration.zero);
    token.cancel();
    health.complete(ServerHealthStatus.healthy);
    await sweep;
    await editing;
    expect(editedProbeCalls, 0);
    expect(provider.healthFor(secondary.id), ServerHealthStatus.healthy);
  });

  test(
    'queued interactive refresh receives an unexpected probe failure',
    () async {
      final health = Completer<ServerHealthStatus>();
      String? delayedId;
      provider.dispose();
      provider = AppProvider(
        getAppInfo: GetAppInfo(repository),
        checkConnection: CheckConnection(repository),
        localDataSource: InMemoryAppLocalDataSource(),
        dioClient: DioClient(),
        serverHealthProbe: (profile) => profile.id == delayedId
            ? health.future
            : Future.value(ServerHealthStatus.healthy),
        enableHealthPolling: false,
      );
      await provider.initialize();
      delayedId = await addProfile();
      await provider.addServerProfile(url: 'http://secondary.example:4096');
      final secondary = provider.serverProfiles.last;
      final sweep = provider.refreshServerHealth(serverId: delayedId);
      await Future<void>.delayed(Duration.zero);
      final editing = provider.updateServerProfile(
        id: secondary.id,
        url: 'http://edited.example:4096',
        basicAuthEnabled: false,
        basicAuthUsername: '',
        basicAuthPassword: '',
        oauthEnabled: false,
        tailscaleEnabled: false,
        aiGeneratedTitlesEnabled: true,
      );
      await Future<void>.delayed(Duration.zero);
      final expectations = <Future<void>>[
        expectLater(sweep, throwsA(isA<StateError>())),
        expectLater(editing, throwsA(isA<StateError>())),
      ];
      health.completeError(StateError('Unexpected health failure'));
      await Future.wait(expectations);
      expect(provider.serverProfiles, hasLength(2));
    },
  );
}
