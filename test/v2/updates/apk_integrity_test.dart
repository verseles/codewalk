import 'dart:convert';

import 'package:codewalk/shared/releases/apk_integrity.dart';
import 'package:flutter_test/flutter_test.dart';

const _sha = '64d338107e0175b26d25343ed00af2a01ac009c9286c16c9f1aed32ac7c58f5b';

String _manifest({
  String tag = 'v2.0.0-beta.1',
  String sha = _sha,
  String signer = codewalkAndroidSignerSha256,
  String abi = 'arm64-v8a',
  String appId = 'com.verseles.codewalk',
  int size = 10,
  int versionCode = 2,
  int schema = 1,
}) => jsonEncode({
  'schema': schema,
  'tag': tag,
  'version': '2.0.0-beta.1',
  'assets': {
    'codewalk-android-arm64.apk': {
      'abi': abi,
      'application_id': appId,
      'sha256': sha,
      'signer_sha256': signer,
      'size': size,
      'version_code': versionCode,
      'version_name': '2.0.0-beta.1',
    },
  },
});

void main() {
  group('parseSha256Sums', () {
    test('reads the exact asset line', () {
      expect(
        parseSha256Sums(
          '$_sha  codewalk-android-arm64.apk\n',
          'codewalk-android-arm64.apk',
        ),
        _sha,
      );
    });

    test('rejects a duplicate line', () {
      const body =
          '$_sha  codewalk-android-arm64.apk\n$_sha  codewalk-android-arm64.apk\n';
      expect(parseSha256Sums(body, 'codewalk-android-arm64.apk'), isNull);
    });

    test('ignores other assets and malformed lines', () {
      const body = 'not a sum\n$_sha  other.zip\n';
      expect(parseSha256Sums(body, 'codewalk-android-arm64.apk'), isNull);
    });
  });

  group('parseReleaseManifest', () {
    test('accepts a matching manifest', () {
      final manifest = parseReleaseManifest(
        _manifest(),
        tag: 'v2.0.0-beta.1',
        assetName: 'codewalk-android-arm64.apk',
      );
      expect(manifest, isNotNull);
      expect(manifest!.asset.sha256, _sha);
      expect(manifest.asset.versionCode, 2);
    });

    test('rejects a different tag, signer, abi or application id', () {
      for (final body in [
        _manifest(tag: 'v2.0.0-beta.2'),
        _manifest(signer: 'a' * 64),
        _manifest(abi: 'x86_64'),
        _manifest(appId: 'com.example'),
      ]) {
        expect(
          parseReleaseManifest(
            body,
            tag: 'v2.0.0-beta.1',
            assetName: 'codewalk-android-arm64.apk',
          ),
          isNull,
        );
      }
    });

    test('rejects schema, size and version code problems', () {
      for (final body in [
        _manifest(schema: 2),
        _manifest(size: 0),
        _manifest(versionCode: 0),
      ]) {
        expect(
          parseReleaseManifest(
            body,
            tag: 'v2.0.0-beta.1',
            assetName: 'codewalk-android-arm64.apk',
          ),
          isNull,
        );
      }
    });
  });
}
