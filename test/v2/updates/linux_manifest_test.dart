import 'dart:convert';

import 'package:codewalk/shared/releases/linux_update.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const tag = 'v2.0.0-beta.7';
  const name = 'codewalk-linux-x64.tar.gz';
  final digest = 'a' * 64;
  Map<String, Object> manifest() => {
    'schema': 1,
    'tag': tag,
    'version': tag.substring(1),
    'assets': {
      name: {'sha256': digest, 'size': 123, 'architecture': 'x64'},
    },
  };
  test('Linux metadata binds exact tag, architecture, size and checksum', () {
    final result = parseLinuxAssetManifest(
      jsonEncode(manifest()),
      '$digest  $name',
      tag: tag,
      assetName: name,
    );
    expect(result, (sha256: digest, size: 123));
    expect(
      parseLinuxAssetManifest(
        jsonEncode(manifest()),
        '${'b' * 64}  $name',
        tag: tag,
        assetName: name,
      ),
      isNull,
    );
    expect(
      parseLinuxAssetManifest(
        jsonEncode(manifest()),
        '$digest  $name',
        tag: 'v2.0.0-beta.8',
        assetName: name,
      ),
      isNull,
    );
    final wrongArch = manifest()
      ..['assets'] = {
        name: {'sha256': digest, 'size': 123, 'architecture': 'arm64'},
      };
    expect(
      parseLinuxAssetManifest(
        jsonEncode(wrongArch),
        '$digest  $name',
        tag: tag,
        assetName: name,
      ),
      isNull,
    );
  });
}
