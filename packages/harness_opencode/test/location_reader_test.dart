import 'dart:async';
import 'dart:convert';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:codewalk_net/codewalk_net_io.dart';
import 'package:harness_opencode/harness_opencode.dart';
import 'package:test/test.dart';

const harness = HarnessRef(HostId('host-a'), HarnessInstanceId('native-a'));

final class TestTransport implements EndpointHttpTransport {
  TestTransport(this.handle);
  final FutureOr<TransportResponse> Function(TransportRequest) handle;
  final requests = <TransportRequest>[];
  @override
  Uri endpoint = Uri.parse('http://127.0.0.1/proxy/');
  @override
  bool isClosed = false;
  @override
  Future<TransportResponse> send(
    TransportRequest request, {
    RequestCancellation? cancellation,
  }) async {
    requests.add(request);
    expect(request.method, 'GET');
    expect(request.body, isNull);
    return handle(request);
  }

  @override
  void close() => isClosed = true;
}

TransportResponse response(Object? body, {int status = 200}) =>
    TransportResponse(
      statusCode: status,
      headers: {
        'content-type': ['application/json'],
      },
      body: Stream.value(utf8.encode(jsonEncode(body))),
      cancel: () {},
    );

Matcher failure(OpenCodeSessionReadFailure kind) =>
    isA<OpenCodeSessionReadException>().having(
      (e) => e.failure,
      'failure',
      kind,
    );

Map<String, String> query(TransportRequest request) =>
    Uri.parse(request.path).queryParameters;

void main() {
  test('projects list each directory once, project first', () async {
    final transport = TestTransport((request) {
      expect(Uri.parse(request.path).path, 'api/project');
      return response([
        {
          'id': 'prj_a',
          'canonical': '/work/app',
          'time': {'created': 1, 'updated': 2, 'active': 3},
          'sandboxes': ['/work/app-tree', '/work/app'],
        },
        {
          'id': 'global',
          'canonical': '/',
          'time': {'created': 1, 'updated': 2, 'active': 3},
          'sandboxes': <String>[],
        },
      ]);
    });
    final reader = OpenCodeLocationReader(transport, harness: harness);
    final projects = await reader.listProjects();
    expect(projects.map((p) => p.ref.canonicalDirectory), [
      '/work/app',
      '/work/app-tree',
      '/',
    ]);
    expect(projects.first.ref.host, harness.host);
    expect(projects.first.ref.upstreamProjectId, 'prj_a');
    reader.dispose();
  });

  test(
    'project images follow official precedence and every sandbox shares it',
    () async {
      const url = 'data:image/png;base64,AQID';
      const override = 'https://example.com/override.svg';
      final cases = <(Object?, String?)>[
        (null, null),
        ('malformed', null),
        ({'url': url}, url),
        ({'url': url, 'override': override, 'color': 'blue'}, override),
        ({'url': url, 'override': '', 'color': ''}, url),
        ({'url': url, 'color': 'blue'}, null),
        ({'url': url, 'override': 'x' * 65537}, null),
        ({'url': url, 'override': '%broken'}, null),
      ];
      for (final (icon, expected) in cases) {
        final reader = OpenCodeLocationReader(
          TestTransport(
            (_) => response([
              {
                'id': 'p',
                'canonical': '/app',
                'sandboxes': ['/tree', '/app'],
                'icon': icon,
              },
            ]),
          ),
          harness: harness,
        );
        final projects = await reader.listProjects();
        expect(projects.map((p) => p.ref.canonicalDirectory), [
          '/app',
          '/tree',
        ]);
        expect(projects.first.icon?.toString(), expected);
        expect(identical(projects.first.icon, projects.last.icon), isTrue);
        reader.dispose();
      }
    },
  );

  test('icon-bearing lists have a separate finite body budget', () async {
    final body = [
      for (var i = 0; i < 20; i++)
        {
          'id': 'p$i',
          'canonical': '/app$i',
          'sandboxes': <String>[],
          'icon': {'url': 'data:image/png;base64,${'A' * 60000}'},
        },
    ];
    final transport = TestTransport((_) => response(body));
    final reader = OpenCodeLocationReader(transport, harness: harness);
    expect(await reader.listProjects(), hasLength(20));
    reader.dispose();
    final bounded = OpenCodeLocationReader(
      transport,
      harness: harness,
      maxProjectBodyBytes: 1024,
    );
    await expectLater(
      bounded.listProjects(),
      throwsA(failure(OpenCodeSessionReadFailure.bodyTooLarge)),
    );
    bounded.dispose();
    expect(
      () => OpenCodeLocationReader(
        transport,
        harness: harness,
        maxProjectBodyBytes: 0,
      ),
      throwsArgumentError,
    );
  });

  test('a location resolves to the directory the endpoint keys', () async {
    final transport = TestTransport((request) {
      expect(Uri.parse(request.path).path, 'api/location');
      final directory = query(request)['location[directory]'];
      return response({
        'directory': directory == null ? '/home/me' : '/work/app',
        'project': {
          'id': 'prj_a',
          'directory': '/work/app',
          'canonical': '/work/app',
        },
      });
    });
    final reader = OpenCodeLocationReader(transport, harness: harness);
    final fallback = await reader.readLocation();
    expect(fallback.canonicalDirectory, '/home/me');
    expect(query(transport.requests.single), isEmpty);
    final resolved = await reader.readLocation(directory: '/work/app/');
    expect(query(transport.requests.last), {
      'location[directory]': '/work/app/',
    });
    expect(resolved.canonicalDirectory, '/work/app');
    expect(resolved.upstreamProjectId, 'prj_a');
    reader.dispose();
  });

  test('a listing keeps entry paths relative to its location', () async {
    final transport = TestTransport((request) {
      expect(Uri.parse(request.path).path, 'api/fs/list');
      expect(query(request), {
        'location[directory]': '/work/app',
        'path': '..',
      });
      return response({
        'location': {'directory': '/work/app'},
        'data': [
          {'path': '../app', 'type': 'directory'},
          {'path': '../notes.md', 'type': 'file'},
        ],
      });
    });
    final reader = OpenCodeLocationReader(transport, harness: harness);
    final entries = await reader.listDirectory(
      directory: '/work/app',
      path: '..',
    );
    expect(entries.map((e) => (e.ref.path, e.kind.known)), [
      ('../app', FileKind.directory),
      ('../notes.md', FileKind.file),
    ]);
    expect(entries.first.ref.project.canonicalDirectory, '/work/app');
    reader.dispose();
  });

  test('entries of another location or shape are refused', () async {
    for (final body in [
      {
        'location': {'directory': '/elsewhere'},
        'data': <Object?>[],
      },
      {
        'location': {'directory': '/work/app'},
        'data': [
          {'path': 'x', 'type': 'socket'},
        ],
      },
      {
        'location': {'directory': '/work/app'},
        'data': [
          {'path': '', 'type': 'directory'},
        ],
      },
    ]) {
      final reader = OpenCodeLocationReader(
        TestTransport((_) => response(body)),
        harness: harness,
      );
      await expectLater(
        reader.listDirectory(directory: '/work/app'),
        throwsA(failure(OpenCodeSessionReadFailure.incompatibleResponse)),
      );
      reader.dispose();
    }
  });

  test('a directory search asks for directories only, bounded', () async {
    final transport = TestTransport((request) {
      expect(Uri.parse(request.path).path, 'api/fs/find');
      expect(query(request), {
        'location[directory]': '/work',
        'query': 'app',
        'type': 'directory',
        'limit': '50',
      });
      return response({
        'location': {'directory': '/work'},
        'data': [
          {'path': 'app', 'type': 'directory'},
        ],
      });
    });
    final reader = OpenCodeLocationReader(transport, harness: harness);
    final found = await reader.findDirectories(
      directory: '/work',
      query: 'app',
    );
    expect(found.single.ref.path, 'app');
    await expectLater(
      reader.findDirectories(directory: '/work', query: 'app', limit: 201),
      throwsA(failure(OpenCodeSessionReadFailure.invalidRequest)),
    );
    await expectLater(
      reader.findDirectories(directory: '', query: 'app'),
      throwsA(failure(OpenCodeSessionReadFailure.invalidRequest)),
    );
    expect(transport.requests, hasLength(1));
    reader.dispose();
  });

  test('a search that returns a file is refused', () async {
    final reader = OpenCodeLocationReader(
      TestTransport(
        (_) => response({
          'location': {'directory': '/work'},
          'data': [
            {'path': 'app.dart', 'type': 'file'},
          ],
        }),
      ),
      harness: harness,
    );
    await expectLater(
      reader.findDirectories(directory: '/work', query: 'app'),
      throwsA(failure(OpenCodeSessionReadFailure.incompatibleResponse)),
    );
    reader.dispose();
  });

  test('failures stay finite and a disposed reader never sends', () async {
    final transport = TestTransport((_) => response({}, status: 401));
    final reader = OpenCodeLocationReader(transport, harness: harness);
    await expectLater(
      reader.listProjects(),
      throwsA(failure(OpenCodeSessionReadFailure.authenticationRequired)),
    );
    reader.dispose();
    await expectLater(
      reader.readLocation(),
      throwsA(failure(OpenCodeSessionReadFailure.closed)),
    );
    expect(transport.requests, hasLength(1));
    expect(transport.isClosed, isFalse);
  });
}
