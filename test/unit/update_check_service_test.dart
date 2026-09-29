import 'dart:convert';

import 'package:codewalk/presentation/services/update_check_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _ReleaseAdapter implements HttpClientAdapter {
  _ReleaseAdapter(this.responses);

  final List<(int, Object?)> responses;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final response = responses.removeAt(0);
    return ResponseBody.fromString(
      jsonEncode(response.$2),
      response.$1,
      headers: <String, List<String>>{
        'content-type': ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _release(String version) => <String, dynamic>{
  'tag_name': 'v$version',
  'html_url': 'https://example.com/releases/$version',
  'body': '> 📣 New release\n\n- Fixes',
  'assets': <Map<String, dynamic>>[
    {
      'name': 'desktop.zip',
      'browser_download_url': 'https://example.com/app.zip',
    },
    {
      'name': 'android.apk',
      'browser_download_url': 'https://example.com/app.apk',
    },
  ],
};

void main() {
  group('Semver', () {
    test('parses standard version string', () {
      final v = Semver.tryParse('1.8.0');
      expect(v, isNotNull);
      expect(v!.major, 1);
      expect(v.minor, 8);
      expect(v.patch, 0);
    });

    test('parses version with v prefix', () {
      final v = Semver.tryParse('v2.3.1');
      expect(v, isNotNull);
      expect(v!.major, 2);
      expect(v.minor, 3);
      expect(v.patch, 1);
    });

    test('parses version with prerelease suffix', () {
      final v = Semver.tryParse('1.0.0-beta.1');
      expect(v, isNotNull);
      expect(v!.major, 1);
      expect(v.minor, 0);
      expect(v.patch, 0);
    });

    test('parses version with build metadata', () {
      final v = Semver.tryParse('1.2.3+456');
      expect(v, isNotNull);
      expect(v!.major, 1);
      expect(v.minor, 2);
      expect(v.patch, 3);
    });

    test('returns null for invalid input', () {
      expect(Semver.tryParse(''), isNull);
      expect(Semver.tryParse('abc'), isNull);
      expect(Semver.tryParse('1.2'), isNull);
      expect(Semver.tryParse('1.2.x'), isNull);
    });

    test('compares major versions', () {
      final v1 = Semver.tryParse('2.0.0')!;
      final v2 = Semver.tryParse('1.9.9')!;
      expect(v1.isNewerThan(v2), isTrue);
      expect(v2.isNewerThan(v1), isFalse);
    });

    test('compares minor versions', () {
      final v1 = Semver.tryParse('1.5.0')!;
      final v2 = Semver.tryParse('1.4.9')!;
      expect(v1.isNewerThan(v2), isTrue);
      expect(v2.isNewerThan(v1), isFalse);
    });

    test('compares patch versions', () {
      final v1 = Semver.tryParse('1.0.3')!;
      final v2 = Semver.tryParse('1.0.2')!;
      expect(v1.isNewerThan(v2), isTrue);
      expect(v2.isNewerThan(v1), isFalse);
    });

    test('equal versions are not newer', () {
      final v1 = Semver.tryParse('1.8.0')!;
      final v2 = Semver.tryParse('1.8.0')!;
      expect(v1.isNewerThan(v2), isFalse);
      expect(v1 == v2, isTrue);
    });

    test('toString returns clean version', () {
      final v = Semver.tryParse('v1.8.0')!;
      expect(v.toString(), '1.8.0');
    });

    test('compareTo follows semver ordering', () {
      final versions = <Semver>[
        Semver.tryParse('2.0.0')!,
        Semver.tryParse('1.0.0')!,
        Semver.tryParse('1.1.0')!,
        Semver.tryParse('1.0.1')!,
        Semver.tryParse('0.9.9')!,
      ];
      versions.sort();
      expect(versions.map((v) => v.toString()).toList(), [
        '0.9.9',
        '1.0.0',
        '1.0.1',
        '1.1.0',
        '2.0.0',
      ]);
    });
  });

  group('UpdateCheckResult', () {
    test('holds all fields', () {
      const result = UpdateCheckResult(
        latestVersion: '2.0.0',
        releaseUrl: 'https://github.com/verseles/codewalk/releases/tag/v2.0.0',
        releaseNotes: 'Big update',
        isNewer: true,
      );
      expect(result.latestVersion, '2.0.0');
      expect(result.releaseUrl, isNotNull);
      expect(result.releaseNotes, 'Big update');
      expect(result.isNewer, isTrue);
    });

    test('handles null optional fields', () {
      const result = UpdateCheckResult(latestVersion: '1.0.0', isNewer: false);
      expect(result.releaseUrl, isNull);
      expect(result.releaseNotes, isNull);
    });
  });

  group('UpdateCheckService', () {
    test('returns null for invalid current version', () async {
      final adapter = _ReleaseAdapter([]);
      final dio = Dio()..httpClientAdapter = adapter;
      addTearDown(() => dio.close(force: true));
      final service = UpdateCheckService(dio: dio);
      final result = await service.check('invalid');
      expect(result, isNull);
      expect(adapter.requests, isEmpty);
    });

    test(
      'clearCache resets a populated cache and permits a fresh request',
      () async {
        final adapter = _ReleaseAdapter([
          (200, _release('2.0.0')),
          (200, _release('3.0.0')),
        ]);
        final dio = Dio()..httpClientAdapter = adapter;
        addTearDown(() => dio.close(force: true));
        final service = UpdateCheckService(dio: dio);
        final first = await service.check('1.0.0');
        expect(first, isNotNull);
        expect(service.cachedResult, same(first));
        expect(await service.check('1.0.0'), same(first));
        expect(adapter.requests, hasLength(1));

        service.clearCache();
        expect(service.cachedResult, isNull);
        final refreshed = await service.check('1.0.0');
        expect(refreshed?.latestVersion, '3.0.0');
        expect(service.cachedResult, same(refreshed));
        expect(adapter.requests, hasLength(2));
      },
    );

    test('parses release metadata and selects the APK asset', () async {
      final adapter = _ReleaseAdapter([(200, _release('2.0.0'))]);
      final dio = Dio()..httpClientAdapter = adapter;
      addTearDown(() => dio.close(force: true));
      final service = UpdateCheckService(dio: dio);
      final result = await service.check('1.0.0');
      expect(result?.latestVersion, '2.0.0');
      expect(result?.isNewer, isTrue);
      expect(result?.apkUrl, 'https://example.com/app.apk');
      expect(result?.releaseUrl, 'https://example.com/releases/2.0.0');
      expect(result?.announcement, 'New release');
      expect(result?.releaseNotes, '> 📣 New release\n\n- Fixes');
      final request = adapter.requests.single;
      expect(request.uri.path, '/repos/verseles/codewalk/releases/latest');
      expect(request.headers['Accept'], 'application/vnd.github+json');
      expect(request.headers['User-Agent'], 'CodeWalk');
    });

    test(
      'ignoreCooldown requests fresh data even with a populated cache',
      () async {
        final adapter = _ReleaseAdapter([
          (200, _release('1.0.0')),
          (200, _release('2.0.0')),
        ]);
        final dio = Dio()..httpClientAdapter = adapter;
        addTearDown(() => dio.close(force: true));
        final service = UpdateCheckService(dio: dio);
        expect((await service.check('1.0.0'))?.isNewer, isFalse);
        final result = await service.check('1.0.0', ignoreCooldown: true);
        expect(result?.isNewer, isTrue);
        expect(adapter.requests, hasLength(2));
      },
    );

    for (final response in <(String, int, Object?)>[
      ('missing tag', 200, <String, dynamic>{'body': 'No version'}),
      ('invalid tag', 200, <String, dynamic>{'tag_name': 'invalid'}),
      ('empty response', 200, null),
      ('HTTP failure', 503, <String, dynamic>{'message': 'Unavailable'}),
    ]) {
      test('${response.$1} does not populate the release cache', () async {
        final adapter = _ReleaseAdapter([(response.$2, response.$3)]);
        final dio = Dio()..httpClientAdapter = adapter;
        addTearDown(() => dio.close(force: true));
        final service = UpdateCheckService(dio: dio);
        expect(await service.check('1.0.0'), isNull);
        expect(service.cachedResult, isNull);
        expect(adapter.requests, hasLength(1));
      });
    }

  });

  group('parseReleaseAnnouncement', () {
    test('extracts leading blockquote announcement', () {
      expect(parseReleaseAnnouncement('> 📣 Hello!\n\n- feat: x'), 'Hello!');
    });

    test('tolerates no space after quote and leading blanks', () {
      expect(
        parseReleaseAnnouncement('\n\n>📣  Spaced  \n\n- fix: y'),
        'Spaced',
      );
    });

    test('returns null without marker', () {
      expect(parseReleaseAnnouncement('- feat: x\n- fix: y'), isNull);
    });

    test('returns null for null or empty body', () {
      expect(parseReleaseAnnouncement(null), isNull);
      expect(parseReleaseAnnouncement(''), isNull);
      expect(parseReleaseAnnouncement('  \n '), isNull);
    });

    test('ignores megaphone in the middle of notes', () {
      expect(parseReleaseAnnouncement('- feat: x\nSome 📣 text'), isNull);
    });

    test('ignores quote without megaphone', () {
      expect(parseReleaseAnnouncement('> Just a quote\n\n- feat: x'), isNull);
    });

    test('absorbs quote continuation lines without megaphone', () {
      expect(
        parseReleaseAnnouncement('> 📣 First line\n> Second line\n\n- feat: x'),
        'First line\nSecond line',
      );
    });
  });

  group('stripReleaseAnnouncement', () {
    test('removes leading block and keeps notes', () {
      expect(stripReleaseAnnouncement('> 📣 Hello!\n\n- feat: x'), '- feat: x');
    });

    test('removes multiline block including continuations', () {
      expect(
        stripReleaseAnnouncement('> 📣 First\n> Second\n\n- feat: x'),
        '- feat: x',
      );
    });

    test('removes marker-only block with no text', () {
      expect(stripReleaseAnnouncement('> 📣\n\n- feat: x'), '- feat: x');
    });

    test('returns body unchanged without marker', () {
      const body = '- feat: x';
      expect(stripReleaseAnnouncement(body), body);
    });

    test('returns null when only the block exists', () {
      expect(stripReleaseAnnouncement('> 📣 Hello!'), isNull);
    });

    test('passes null through', () {
      expect(stripReleaseAnnouncement(null), isNull);
    });
  });
}
