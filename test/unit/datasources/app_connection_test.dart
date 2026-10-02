import 'dart:convert';
import 'dart:typed_data';

import 'package:codewalk/core/errors/exceptions.dart';
import 'package:codewalk/core/errors/failures.dart';
import 'package:codewalk/core/network/dio_client.dart';
import 'package:codewalk/core/network/opencode_connection_response.dart';
import 'package:codewalk/data/datasources/app_remote_datasource.dart';
import 'package:codewalk/data/repositories/app_repository_impl.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

const _path = <String, dynamic>{
  'config': '/config',
  'state': '/state',
  'worktree': '/project',
  'directory': '/project',
};

const _legacy = <String, dynamic>{
  'hostname': 'server',
  'git': true,
  'path': <String, dynamic>{
    'config': '/config',
    'data': '/data',
    'root': '/project',
    'cwd': '/project',
    'state': '/state',
  },
};

ResponseBody _json(Object? body, {int status = 200}) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: <String, List<String>>{
    Headers.contentTypeHeader: <String>['application/json'],
  },
);

class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);

  final ResponseBody Function(RequestOptions) respond;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late DioClient client;
  late AppRemoteDataSourceImpl remote;
  late AppRepositoryImpl repository;

  _Adapter respondWith(ResponseBody Function(RequestOptions) respond) {
    final adapter = _Adapter(respond);
    client.dio.httpClientAdapter = adapter;
    return adapter;
  }

  setUp(() {
    client = DioClient(baseUrl: 'https://server.example');
    remote = AppRemoteDataSourceImpl(dio: client.dio);
    repository = AppRepositoryImpl(
      remoteDataSource: remote,
      localDataSource: InMemoryAppLocalDataSource(),
      dioClient: client,
    );
  });

  tearDown(() {
    client.dio.close(force: true);
    client.sseDio.close(force: true);
  });

  test('official v1 Path succeeds without a legacy request', () async {
    final adapter = respondWith((_) => _json(_path));
    final info = await remote.getAppInfo(directory: '/project');
    expect(info.path.cwd, '/project');
    expect(info.path.data, '/state');
    expect(adapter.requests.single.path, '/path');
    expect(adapter.requests.single.queryParameters['directory'], '/project');
  });

  test(
    'valid JSON served as text and existing aliases remain supported',
    () async {
      final adapter = respondWith(
        (_) => ResponseBody.fromString(
          jsonEncode(<String, dynamic>{
            'config': '/config',
            'state': '/state',
            'root': '/project',
            'cwd': '/project',
            'extra': true,
          }),
          200,
          headers: <String, List<String>>{
            Headers.contentTypeHeader: <String>['text/plain'],
          },
        ),
      );
      expect((await remote.getAppInfo()).path.root, '/project');
      expect(adapter.requests, hasLength(1));
    },
  );

  for (final status in <int>[404, 405]) {
    test(
      'missing /path ($status) uses validated legacy data and Basic auth',
      () async {
        client.setBasicAuth(
          'opencode',
          'test-password',
          origin: 'https://server.example',
        );
        final adapter = respondWith(
          (options) => options.path == '/path'
              ? _json(<String, dynamic>{}, status: status)
              : _json(_legacy),
        );
        expect((await remote.getAppInfo()).hostname, 'server');
        expect(adapter.requests.map((request) => request.path), <String>[
          '/path',
          '/app',
        ]);
        expect(
          adapter.requests.every(
            (request) =>
                request.headers['Authorization'] ==
                'Basic ${base64Encode(utf8.encode('opencode:test-password'))}',
          ),
          isTrue,
        );
      },
    );
  }

  test(
    'web shell on missing /path retains valid legacy compatibility',
    () async {
      respondWith(
        (options) => options.path == '/path'
            ? ResponseBody.fromString('<html>legacy shell</html>', 200)
            : _json(_legacy),
      );
      expect((await remote.getAppInfo()).hostname, 'server');
    },
  );

  final invalidBodies = <Object?>[
    null,
    <Object?>[],
    false,
    42,
    '<html>login page</html>',
    <String, dynamic>{},
    <String, dynamic>{'unrelated': true},
    <String, dynamic>{..._path, 'directory': 7},
    <String, dynamic>{..._path, 'home': <String, dynamic>{}},
  ];
  for (var index = 0; index < invalidBodies.length; index++) {
    test(
      'invalid response $index produces ParseFailure from both repository APIs',
      () async {
        respondWith((_) => _json(invalidBodies[index]));
        final info = await repository.getAppInfo();
        final connection = await repository.checkConnection();
        info.fold(
          (failure) => expect(failure, isA<ParseFailure>()),
          (_) => fail('expected failure'),
        );
        connection.fold(
          (failure) => expect(failure, isA<ParseFailure>()),
          (_) => fail('expected failure'),
        );
      },
    );
  }

  test(
    'malformed legacy nested fields become a controlled parse exception',
    () async {
      respondWith(
        (options) => options.path == '/path'
            ? _json(<String, dynamic>{}, status: 404)
            : _json(<String, dynamic>{..._legacy, 'path': 'not an object'}),
      );
      await expectLater(remote.getAppInfo(), throwsA(isA<ParseException>()));
    },
  );

  for (final status in <int>[401, 403, 500]) {
    test('HTTP $status retains its code without a legacy retry', () async {
      final adapter = respondWith(
        (_) => _json(<String, dynamic>{}, status: status),
      );
      final result = await repository.checkConnection();
      result.fold(
        (failure) => expect(failure.code, status),
        (_) => fail('expected failure'),
      );
      expect(adapter.requests, hasLength(1));
    });
  }

  for (final type in <DioExceptionType>[
    DioExceptionType.connectionTimeout,
    DioExceptionType.receiveTimeout,
    DioExceptionType.cancel,
    DioExceptionType.connectionError,
  ]) {
    test('$type is not replaced by a legacy request', () async {
      final adapter = respondWith(
        (options) => throw DioException(requestOptions: options, type: type),
      );
      await expectLater(
        remote.getAppInfo(),
        throwsA(
          isA<DioException>().having((error) => error.type, 'type', type),
        ),
      );
      expect(adapter.requests, hasLength(1));
    });
  }

  test('malformed JSON diagnostics exclude the response body', () async {
    respondWith(
      (_) => ResponseBody.fromString(
        '{private-response',
        200,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>['application/json'],
        },
      ),
    );
    final result = await repository.checkConnection();
    result.fold((failure) {
      expect(failure, isA<ParseFailure>());
      expect(failure.message, isNot(contains('private-response')));
    }, (_) => fail('expected failure'));
  });

  test('health validation accepts official data and respects unhealthy', () {
    expect(
      decodeOpenCodeHealth(<String, dynamic>{
        'healthy': true,
        'version': '1.18.34',
      }),
      isTrue,
    );
    expect(decodeOpenCodeHealth(<String, dynamic>{'healthy': false}), isFalse);
    for (final body in <Object?>[
      '<html>login</html>',
      <String, dynamic>{},
      <String, dynamic>{'healthy': true},
      <String, dynamic>{'healthy': true, 'version': 1},
    ]) {
      expect(() => decodeOpenCodeHealth(body), throwsA(isA<ParseException>()));
    }
  });
}
