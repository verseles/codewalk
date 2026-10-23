import 'dart:convert';

import 'package:codewalk/presentation/services/update_check_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Serves scripted GitHub API responses keyed by request path and page.
///
/// A response body is either JSON-encoded or, when it is a [_RawBody],
/// served verbatim so malformed JSON can be exercised.
class _GitHubAdapter implements HttpClientAdapter {
  _GitHubAdapter({this.latest, Map<int, (int, Object?)>? pages})
    : pages = pages ?? <int, (int, Object?)>{};

  final (int, Object?)? latest;
  final Map<int, (int, Object?)> pages;
  final requests = <Uri>[];

  int get latestRequests =>
      requests.where((uri) => uri.path.endsWith('/releases/latest')).length;

  List<int> get pageRequests => requests
      .where((uri) => uri.path.endsWith('/releases'))
      .map((uri) => int.parse(uri.queryParameters['page']!))
      .toList();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options.uri);
    final path = options.uri.path;
    final (int, Object?)? response;
    if (path == '/repos/verseles/codewalk/releases/latest') {
      response = latest;
    } else if (path == '/repos/verseles/codewalk/releases') {
      expect(options.uri.queryParameters['per_page'], '100');
      response = pages[int.parse(options.uri.queryParameters['page']!)];
    } else {
      response = null;
    }
    if (response == null) {
      throw StateError('Unexpected request: ${options.uri}');
    }
    final body = response.$2;
    return ResponseBody.fromString(
      body is _RawBody ? body.text : jsonEncode(body),
      response.$1,
      headers: <String, List<String>>{
        'content-type': ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _RawBody {
  const _RawBody(this.text);

  final String text;
}

Map<String, dynamic> _release(
  String tag, {
  bool draft = false,
  bool prerelease = false,
  bool withApk = true,
}) => <String, dynamic>{
  'tag_name': tag,
  'draft': draft,
  'prerelease': prerelease,
  'html_url': 'https://github.com/verseles/codewalk/releases/tag/$tag',
  'body': '- Notes for $tag',
  'assets': <Map<String, dynamic>>[
    if (withApk)
      <String, dynamic>{
        'name': 'codewalk-$tag.apk',
        'browser_download_url': 'https://example.com/$tag/codewalk.apk',
      },
  ],
};

/// A full page of unrelated stable releases, used to force pagination.
List<Map<String, dynamic>> _fullPage(int seed) => <Map<String, dynamic>>[
  for (var i = 0; i < 100; i++) _release('v1.0.${seed * 100 + i}'),
];

(UpdateCheckService, _GitHubAdapter) _service(_GitHubAdapter adapter) {
  final dio = Dio()..httpClientAdapter = adapter;
  addTearDown(() => dio.close(force: true));
  return (UpdateCheckService(dio: dio), adapter);
}

void main() {
  group('parseStableReleaseTag', () {
    test('accepts plain stable tags with or without the v prefix', () {
      expect(parseStableReleaseTag('v1.266.0'), const Semver(1, 266, 0));
      expect(parseStableReleaseTag('2.0.0'), const Semver(2, 0, 0));
    });

    test('rejects suffixes, partial versions and malformed parts', () {
      for (final tag in <String>[
        'v2.0.0-beta.1',
        'v1.266.0-native.1',
        'v1.2.3+45',
        'v1.2',
        'v1.2.3.4',
        'v1.2.x',
        ' v1.2.3',
        'V1.2.3',
        'release-1.2.3',
        '',
      ]) {
        expect(parseStableReleaseTag(tag), isNull, reason: tag);
      }
    });
  });

  group('UpdateChannel.fromStorage', () {
    test('maps stored values and falls back to stable', () {
      expect(UpdateChannel.fromStorage('v1'), UpdateChannel.v1);
      expect(UpdateChannel.fromStorage('stable'), UpdateChannel.stable);
      expect(UpdateChannel.fromStorage(null), UpdateChannel.stable);
      expect(UpdateChannel.fromStorage('beta'), UpdateChannel.stable);
    });
  });

  group('UpdateCheckService.resolveApiBase', () {
    test('release builds always use the GitHub API', () {
      expect(
        UpdateCheckService.resolveApiBase(
          debugMode: false,
          override: 'http://127.0.0.1:8080',
        ),
        'https://api.github.com',
      );
    });

    test('debug builds honour a non-empty override only', () {
      expect(
        UpdateCheckService.resolveApiBase(
          debugMode: true,
          override: 'http://127.0.0.1:8080/',
        ),
        'http://127.0.0.1:8080',
      );
      expect(
        UpdateCheckService.resolveApiBase(debugMode: true, override: '  '),
        'https://api.github.com',
      );
    });
  });

  group('latest release path', () {
    test('keeps the exact tag and flags a major upgrade', () async {
      final (service, _) = _service(
        _GitHubAdapter(latest: (200, _release('v2.0.0'))),
      );
      final result = await service.check('1.265.1');
      expect(result?.latestVersion, '2.0.0');
      expect(result?.releaseTag, 'v2.0.0');
      expect(result?.isNewer, isTrue);
      expect(result?.isMajorUpgrade, isTrue);
      expect(result?.apkUrl, 'https://example.com/v2.0.0/codewalk.apk');
    });

    test('a same-major release is not a major upgrade', () async {
      final (service, _) = _service(
        _GitHubAdapter(latest: (200, _release('v1.266.0'))),
      );
      final result = await service.check('1.265.1');
      expect(result?.releaseTag, 'v1.266.0');
      expect(result?.isNewer, isTrue);
      expect(result?.isMajorUpgrade, isFalse);
    });

    for (final (name, release) in <(String, Map<String, dynamic>)>[
      ('draft', _release('v1.266.0', draft: true)),
      ('prerelease', _release('v1.266.0', prerelease: true)),
      ('beta tag', _release('v2.0.0-beta.1')),
      ('native cohort tag', _release('v1.266.0-native.1')),
      ('missing draft flag', _release('v1.266.0')..remove('draft')),
    ]) {
      test('rejects a $name instead of offering it', () async {
        final (service, _) = _service(_GitHubAdapter(latest: (200, release)));
        expect(await service.check('1.265.1'), isNull);
        expect(service.cachedResult, isNull);
      });
    }
  });

  group('v1-only selector', () {
    test('offers the highest stable v1 release across pages, ignoring v2, '
        'betas, native cohorts, drafts and prereleases', () async {
      final (service, adapter) = _service(
        _GitHubAdapter(
          pages: <int, (int, Object?)>{
            1: (
              200,
              <Map<String, dynamic>>[
                _release('v2.0.0'),
                _release('v2.0.0-beta.1', prerelease: true),
                _release('v2.1.0-beta.2'),
                _release('v1.266.0-native.1', prerelease: true),
                _release('v1.267.0', draft: true),
                _release('v1.268.0', prerelease: true),
                _release('v1.9.99'),
                ..._fullPage(0).skip(7),
              ],
            ),
            2: (
              200,
              <Map<String, dynamic>>[
                _release('v1.265.1'),
                _release('v1.266.1'),
                _release('v1.10.0'),
              ],
            ),
          },
        ),
      );
      final result = await service.checkV1Only('1.265.1');
      expect(result?.releaseTag, 'v1.266.1');
      expect(result?.latestVersion, '1.266.1');
      expect(result?.isNewer, isTrue);
      expect(result?.isMajorUpgrade, isFalse);
      expect(result?.apkUrl, 'https://example.com/v1.266.1/codewalk.apk');
      expect(
        result?.releaseUrl,
        'https://github.com/verseles/codewalk/releases/tag/v1.266.1',
      );
      expect(adapter.pageRequests, <int>[1, 2]);
      expect(adapter.latestRequests, 0);
    });

    test('orders versions semantically regardless of response order', () async {
      final (service, _) = _service(
        _GitHubAdapter(
          pages: <int, (int, Object?)>{
            1: (
              200,
              <Map<String, dynamic>>[
                _release('v1.9.99'),
                _release('v1.10.0'),
                _release('v1.2.0'),
              ],
            ),
          },
        ),
      );
      final result = await service.checkV1Only('1.0.0');
      expect(result?.releaseTag, 'v1.10.0');
    });

    test('never offers an equal or older version as newer', () async {
      final (service, _) = _service(
        _GitHubAdapter(
          pages: <int, (int, Object?)>{
            1: (
              200,
              <Map<String, dynamic>>[_release('v1.265.1'), _release('v1.2.0')],
            ),
          },
        ),
      );
      final equal = await service.checkV1Only('1.265.1');
      expect(equal?.releaseTag, 'v1.265.1');
      expect(equal?.isNewer, isFalse);

      service.clearCache();
      final newerInstall = await service.checkV1Only('1.300.0');
      expect(newerInstall?.isNewer, isFalse);
    });

    test('caches per channel and clearCache clears every channel', () async {
      final (service, adapter) = _service(
        _GitHubAdapter(
          latest: (200, _release('v2.0.0')),
          pages: <int, (int, Object?)>{
            1: (200, <Map<String, dynamic>>[_release('v1.266.0')]),
          },
        ),
      );
      expect((await service.check('1.265.1'))?.releaseTag, 'v2.0.0');
      expect((await service.checkV1Only('1.265.1'))?.releaseTag, 'v1.266.0');
      expect((await service.check('1.265.1'))?.releaseTag, 'v2.0.0');
      expect((await service.checkV1Only('1.265.1'))?.releaseTag, 'v1.266.0');
      expect(adapter.requests, hasLength(2));

      service.clearCache();
      expect(service.cachedResult, isNull);
      await service.check('1.265.1');
      await service.checkV1Only('1.265.1');
      expect(adapter.requests, hasLength(4));
    });

    for (final (name, pages) in <(String, Map<int, (int, Object?)>)>[
      (
        'a page-2 HTTP error',
        <int, (int, Object?)>{
          1: (200, _fullPage(0)),
          2: (500, <String, dynamic>{'message': 'Server error'}),
        },
      ),
      (
        'a rate limit',
        <int, (int, Object?)>{
          1: (403, <String, dynamic>{'message': 'API rate limit exceeded'}),
        },
      ),
      (
        'malformed JSON',
        <int, (int, Object?)>{1: (200, const _RawBody('[{"tag_name": '))},
      ),
      (
        'a non-list page',
        <int, (int, Object?)>{
          1: (200, <String, dynamic>{'message': 'Not a list'}),
        },
      ),
      (
        'a release with malformed flags',
        <int, (int, Object?)>{
          1: (
            200,
            <Object?>[
              _release('v1.266.0'),
              <String, dynamic>{'tag_name': 'v1.267.0', 'draft': 'no'},
            ],
          ),
        },
      ),
      (
        'a release with a malformed tag',
        <int, (int, Object?)>{
          1: (
            200,
            <Object?>[
              _release('v1.266.0'),
              <String, dynamic>{
                'tag_name': 1267,
                'draft': false,
                'prerelease': false,
              },
            ],
          ),
        },
      ),
      (
        'no stable v1 release at all',
        <int, (int, Object?)>{
          1: (
            200,
            <Map<String, dynamic>>[
              _release('v2.0.0'),
              _release('v1.266.0-native.1'),
            ],
          ),
        },
      ),
      (
        'an exhausted ten-page bound',
        <int, (int, Object?)>{
          for (var page = 1; page <= 10; page++) page: (200, _fullPage(page)),
        },
      ),
    ]) {
      test('fails closed on $name without consulting latest', () async {
        final (service, adapter) = _service(_GitHubAdapter(pages: pages));
        expect(await service.checkV1Only('1.0.0'), isNull);
        expect(service.cachedResult, isNull);
        expect(adapter.latestRequests, 0);
        expect(
          adapter.pageRequests.length,
          lessThanOrEqualTo(UpdateCheckService.maxV1ReleasePages),
        );
      });
    }
  });
}
