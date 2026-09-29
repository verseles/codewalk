import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:codewalk/presentation/services/release_history_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import '../support/release_history_fakes.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.responses);
  final List<(int, String)> responses;
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    expect(options.uri.toString(), ReleaseHistoryService.url);
    final response = responses.removeAt(0);
    return ResponseBody.fromString(response.$2, response.$1);
  }

  @override
  void close({bool force = false}) {}
}

class _FailingCache extends InMemoryAppLocalDataSource {
  bool fail = false;
  @override
  Future<void> saveReleaseHistoryCache(String cache) async {
    if (fail) throw StateError('Disk unavailable');
    await super.saveReleaseHistoryCache(cache);
  }
}

void main() {
  test('parses the real archive, including the recent announcement format', () {
    final entries = parseReleaseHistory(
      File('CHANGELOG.md').readAsStringSync(),
    );
    expect(
      entries
          .singleWhere((entry) => entry.version.toString() == '1.259.0')
          .announcement,
      contains('Mermaid'),
    );
    expect(entries.first.notes, isNot(contains('> 📣')));
  });

  test(
    'handles BOM/CRLF, preserves language, and keeps maintenance sections',
    () {
      final entries = parseReleaseHistory(
        '\uFEFF${releaseHistoryFixture.replaceAll('\n', '\r\n')}',
      );
      expect(entries.map((e) => e.version.toString()), [
        '1.3.0',
        '1.2.0',
        '1.1.1',
        '1.1.0',
        '1.0.0',
      ]);
      expect(entries[2].announcement, isNull);
      expect(entries[3].announcement, 'Novidade em português');
    },
  );

  for (final invalid in <String>[
    '<html>GitHub unavailable</html>',
    '## v1.0.0 - 2026-02-30\n- invalid date',
    '## v1.0.0 - 2026-01-01\n',
    '$releaseHistoryFixture\n## Other heading\n- wrong boundary',
    '$releaseHistoryFixture\n## v1.0.0 - 2026-01-01\n- duplicate',
    '## v1.0.0-beta - 2026-01-01\n- prerelease',
  ]) {
    test('rejects malformed archive ${invalid.hashCode}', () {
      expect(() => parseReleaseHistory(invalid), throwsFormatException);
    });
  }

  test('coalesces fetches and uses a successful cached response', () async {
    final adapter = _Adapter([(200, releaseHistoryFixture)]);
    final local = InMemoryAppLocalDataSource();
    final service = ReleaseHistoryService(
      localDataSource: local,
      dio: Dio()..httpClientAdapter = adapter,
    );
    final results = await Future.wait([service.load(), service.load()]);
    expect(results.first.entries.length, 5);
    expect(adapter.calls, 1);
    expect(local.releaseHistoryCache, isNotNull);
    await service.load();
    expect(adapter.calls, 1);
  });

  for (final response in <(int, String)>[
    (503, 'Offline'),
    (200, '<html>Error</html>'),
    (200, 'x' * (ReleaseHistoryService.maxBytes + 1)),
    (200, '## v1.3.0 - 2026-09-29\n- Shortened archive'),
  ]) {
    test(
      'preserves last cache after bad refresh ${response.$2.length}',
      () async {
        final local = InMemoryAppLocalDataSource();
        final adapter = _Adapter([(200, releaseHistoryFixture), response]);
        final service = ReleaseHistoryService(
          localDataSource: local,
          dio: Dio()..httpClientAdapter = adapter,
        );
        await service.load();
        final old = local.releaseHistoryCache;
        final failed = await service.load(forceRefresh: true);
        expect(failed.failed, isTrue);
        expect(failed.entries.length, 5);
        expect(local.releaseHistoryCache, old);
      },
    );
  }

  test(
    'cold offline startup reads persisted archive without overwriting it',
    () async {
      final local = InMemoryAppLocalDataSource()
        ..releaseHistoryCache = jsonEncode({
          'body': releaseHistoryFixture,
          'fetchedAt': '2026-01-01T00:00:00Z',
        });
      final service = ReleaseHistoryService(
        localDataSource: local,
        dio: Dio()..httpClientAdapter = _Adapter([(503, 'Offline')]),
      );
      final result = await service.load();
      expect(result.failed, isTrue);
      expect(result.entries.length, 5);
    },
  );

  test(
    'bad cache recovers from source; failed persistence keeps old cache',
    () async {
      final local = _FailingCache()..releaseHistoryCache = '{broken';
      final service = ReleaseHistoryService(
        localDataSource: local,
        dio: Dio()
          ..httpClientAdapter = _Adapter([
            (200, releaseHistoryFixture),
            (200, releaseHistoryFixture),
          ]),
      );
      expect((await service.load()).failed, isFalse);
      final saved = local.releaseHistoryCache;
      local.fail = true;
      expect((await service.load(forceRefresh: true)).failed, isTrue);
      expect(local.releaseHistoryCache, saved);
    },
  );
}
