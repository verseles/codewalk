import 'dart:convert';

import 'apk_download_policy.dart';
import 'apk_integrity.dart';
import 'update_selector.dart';

({String sha256, int size})? parseLinuxAssetManifest(
  String body,
  String sums, {
  required String tag,
  required String assetName,
}) {
  final architecture = switch (assetName) {
    'codewalk-linux-x64.tar.gz' => 'x64',
    'codewalk-linux-arm64.tar.gz' => 'arm64',
    _ => null,
  };
  if (architecture == null || !tag.startsWith('v2.')) return null;
  try {
    final raw = jsonDecode(body);
    if (raw is! Map ||
        raw['schema'] != 1 ||
        raw['tag'] != tag ||
        raw['version'] != tag.substring(1) ||
        raw['assets'] is! Map) {
      return null;
    }
    final asset = (raw['assets'] as Map)[assetName];
    final digest = parseSha256Sums(sums, assetName);
    if (digest == null ||
        asset is! Map ||
        asset['sha256'] != digest ||
        asset['architecture'] != architecture ||
        asset['size'] is! int ||
        (asset['size'] as int) <= 0 ||
        (asset['size'] as int) > maxApkBytes) {
      return null;
    }
    return (sha256: digest, size: asset['size'] as int);
  } on FormatException {
    return null;
  }
}

enum LinuxUpdateStatus {
  idle,
  downloading,
  verifying,
  installing,
  ready,
  failed,
}

enum LinuxUpdateFailure {
  unavailable,
  network,
  http,
  tooLarge,
  integrity,
  storage,
  install,
  restart,
}

final class LinuxUpdateException implements Exception {
  const LinuxUpdateException(this.failure);
  final LinuxUpdateFailure failure;
}

abstract interface class LinuxUpdateInstaller {
  Future<bool> available();
  Future<void> install(
    UpdateCandidate candidate, {
    required void Function(LinuxUpdateStatus status, double progress)
    onProgress,
  });
  Future<bool> restart();
  void close();
}
