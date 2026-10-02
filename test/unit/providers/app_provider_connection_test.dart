import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:codewalk/core/errors/failures.dart';
import 'package:codewalk/core/network/dio_client.dart';
import 'package:codewalk/domain/usecases/check_connection.dart';
import 'package:codewalk/domain/usecases/get_app_info.dart';
import 'package:codewalk/presentation/providers/app_provider.dart';
import 'package:dartz/dartz.dart';
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
            : jsonEncode(isGlobal ? globalBody : pathBody),
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
}
