import 'package:codewalk/shared/releases/apk_download_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('release URI policy', () {
    test('accepts the exact asset URL', () {
      final uri = releaseAssetUri('v2.0.0-beta.1', codewalkAndroidAssetName);
      expect(
        isExactReleaseAssetUri(
          uri,
          tag: 'v2.0.0-beta.1',
          name: codewalkAndroidAssetName,
        ),
        isTrue,
      );
      expect(isAllowedReleaseUri(uri), isTrue);
    });

    test('rejects http, user info, fragments and foreign hosts', () {
      for (final uri in [
        Uri.parse(
          'http://github.com/verseles/codewalk/releases/download/v2.0.0-beta.1/$codewalkAndroidAssetName',
        ),
        Uri.parse(
          'https://user@github.com/verseles/codewalk/releases/download/v2.0.0-beta.1/$codewalkAndroidAssetName',
        ),
        Uri.parse(
          'https://github.com/verseles/codewalk/releases/download/v2.0.0-beta.1/$codewalkAndroidAssetName#x',
        ),
        Uri.parse(
          'https://example.com/verseles/codewalk/releases/download/v2.0.0-beta.1/$codewalkAndroidAssetName',
        ),
      ]) {
        expect(isAllowedReleaseUri(uri), isFalse);
      }
    });

    test('rejects a query on the initial URL but allows CDN redirects', () {
      final exact = releaseAssetUri('v2.0.0-beta.1', codewalkAndroidAssetName);
      expect(
        isExactReleaseAssetUri(
          exact.replace(query: 'x=1'),
          tag: 'v2.0.0-beta.1',
          name: codewalkAndroidAssetName,
        ),
        isFalse,
      );
      expect(
        isAllowedReleaseUri(
          Uri.parse('https://release-assets.githubusercontent.com/a?x=1'),
        ),
        isTrue,
      );
    });
  });

  group('progress throttle', () {
    final now = DateTime.utc(2026, 1, 1, 12);

    test('completion always notifies', () {
      expect(
        shouldNotifyApkProgress(
          previous: 0.999,
          next: 1,
          lastNotifiedAt: now,
          now: now,
        ),
        isTrue,
      );
    });

    test('small deltas and short intervals are dropped', () {
      expect(
        shouldNotifyApkProgress(
          previous: 0.5,
          next: 0.505,
          lastNotifiedAt: now,
          now: now,
        ),
        isFalse,
      );
      expect(
        shouldNotifyApkProgress(
          previous: 0.5,
          next: 0.6,
          lastNotifiedAt: now,
          now: now.add(const Duration(milliseconds: 50)),
        ),
        isFalse,
      );
    });

    test('enough delta after enough time notifies', () {
      expect(
        shouldNotifyApkProgress(
          previous: 0.5,
          next: 0.6,
          lastNotifiedAt: now,
          now: now.add(const Duration(milliseconds: 100)),
        ),
        isTrue,
      );
    });
  });
}
