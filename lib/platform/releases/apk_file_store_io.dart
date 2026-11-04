import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

import '../../shared/releases/apk_download_policy.dart';
import '../../shared/releases/apk_update.dart';

/// File-system store for updater APKs, rooted in the app cache.
final class ApkFileStoreIo implements ApkFileStore {
  ApkFileStoreIo({required Future<String> Function() temporaryDirectory})
    : _temporaryDirectory = temporaryDirectory;

  final Future<String> Function() _temporaryDirectory;

  Future<String> _root() async => '${await _temporaryDirectory()}/updates';

  @override
  Future<String> partPath(String tag) async =>
      '${await _root()}/$tag/$codewalkAndroidAssetName.part';

  @override
  Future<String> finalPath(String tag) async =>
      '${await _root()}/$tag/$codewalkAndroidAssetName';

  @override
  Future<void> rename(String from, String to) async {
    final target = File(to);
    await target.parent.create(recursive: true);
    await File(from).rename(to);
  }

  @override
  Future<void> delete(String path) async {
    try {
      final file = File(path);
      if (file.existsSync()) await file.delete();
    } on FileSystemException {
      // Best effort: a missing or locked file is already unusable.
    }
  }

  @override
  Future<bool> exists(String path) async => File(path).existsSync();

  @override
  Future<String?> sha256(String path) async {
    if (!await exists(path)) return null;
    return Isolate.run(() => _hashFile(path));
  }

  @override
  Future<void> cleanupStale() async {
    final root = Directory(await _root());
    if (!root.existsSync()) return;
    await for (final entity in root.list(recursive: true)) {
      if (entity is File && entity.path.endsWith('.part')) {
        try {
          await entity.delete();
        } on FileSystemException {
          // A locked part is retried on the next start.
        }
      }
    }
  }
}

Future<String> _hashFile(String path) async {
  final digest = await sha256.bind(File(path).openRead()).first;
  return digest.toString();
}

ApkFileStore createApkFileStore() => ApkFileStoreIo(
  temporaryDirectory: () async => (await getTemporaryDirectory()).path,
);
