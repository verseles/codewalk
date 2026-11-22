import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../../shared/releases/apk_download_policy.dart';
import '../../shared/releases/apk_update.dart';
import 'apk_installer_io.dart';

/// File-system store for updater APKs, rooted in persistent non-backed-up
/// storage on Android (`noBackupFilesDir/updates`) so verified cached APKs
/// survive OS cache eviction and app restarts without entering Auto Backup.
final class ApkFileStoreIo implements ApkFileStore {
  ApkFileStoreIo({
    required Future<String> Function() temporaryDirectory,
    Future<String> Function()? updatesDirectory,
  }) : _temporaryDirectory = temporaryDirectory,
       _updatesDirectory = updatesDirectory;

  final Future<String> Function() _temporaryDirectory;
  final Future<String> Function()? _updatesDirectory;

  Future<String> _root() async {
    try {
      if (_updatesDirectory case final custom?) {
        return await custom();
      }
      return '${await _temporaryDirectory()}/updates';
    } on FileSystemException catch (error) {
      throw ApkDownloadException(ApkUpdateFailure.storage, error);
    }
  }

  @override
  Future<String> partPath(String tag) async =>
      '${await _root()}/$tag/$codewalkAndroidAssetName.part';

  @override
  Future<String> finalPath(String tag) async =>
      '${await _root()}/$tag/$codewalkAndroidAssetName';

  @override
  Future<void> rename(String from, String to) async {
    try {
      final target = File(to);
      await target.parent.create(recursive: true);
      await File(from).rename(to);
      await delete('$from.json');
    } on FileSystemException catch (error) {
      throw ApkDownloadException(ApkUpdateFailure.storage, error);
    }
  }

  @override
  Future<void> delete(String path) async {
    try {
      final file = File(path);
      if (file.existsSync()) await file.delete();
      if (path.endsWith('.part') || path.endsWith('.apk')) {
        final metadata = File('$path.json');
        if (metadata.existsSync()) await metadata.delete();
      }
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
  Future<void> writeSidecar(ApkCachedRecord record) async {
    try {
      final sidecar = File('${record.path}.json');
      await sidecar.parent.create(recursive: true);
      final tmp = File('${record.path}.json.tmp');
      await tmp.writeAsString(jsonEncode(record.toJson()), flush: true);
      await tmp.rename(sidecar.path);
    } on FileSystemException {
      // Sidecar failure degrades only cold-start reminder restoration.
    }
  }

  ApkCachedRecord? _readSidecarSync(String apkPath) {
    try {
      final sidecar = File('$apkPath.json');
      if (!sidecar.existsSync() || FileSystemEntity.isLinkSync(sidecar.path)) {
        return null;
      }
      final raw = jsonDecode(sidecar.readAsStringSync());
      return ApkCachedRecord.tryParse(raw, path: apkPath);
    } on Object {
      return null;
    }
  }

  @override
  Future<ApkCachedRecord?> restoreCached({
    required int installedBuildNumber,
  }) async {
    final root = Directory(await _root());
    if (!root.existsSync() || FileSystemEntity.isLinkSync(root.path)) {
      return null;
    }
    final candidates = <ApkCachedRecord>[];
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final path = entity.path;
      if (!path.endsWith('.apk') || FileSystemEntity.isLinkSync(path)) continue;
      final record = _readSidecarSync(path);
      if (record == null) continue;
      if (record.versionCode <= installedBuildNumber) {
        await delete(path);
        continue;
      }
      candidates.add(record);
    }
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => b.versionCode.compareTo(a.versionCode));
    final newest = candidates.first;
    for (final older in candidates.skip(1)) {
      await delete(older.path);
    }
    return newest;
  }

  @override
  Future<void> cleanupStale({int? installedBuildNumber}) async {
    final root = Directory(await _root());
    if (!root.existsSync() || FileSystemEntity.isLinkSync(root.path)) return;
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    final apkFiles = <File>[];
    final validRecords = <String, ApkCachedRecord>{};

    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final path = entity.path;
      if (FileSystemEntity.isLinkSync(path)) continue;
      try {
        if ((path.endsWith('.part') || path.endsWith('.part.json')) &&
            entity.statSync().modified.isBefore(cutoff)) {
          await entity.delete();
        } else if (path.endsWith('.apk')) {
          apkFiles.add(entity);
          final record = _readSidecarSync(path);
          if (record != null) {
            validRecords[path] = record;
          }
        }
      } on FileSystemException {
        // A locked file is retried on the next start.
      }
    }

    String? protectedApkPath;
    var highestCode = installedBuildNumber ?? 0;
    for (final entry in validRecords.entries) {
      if (entry.value.versionCode > highestCode) {
        highestCode = entry.value.versionCode;
        protectedApkPath = entry.key;
      }
    }

    for (final apk in apkFiles) {
      final path = apk.path;
      if (path == protectedApkPath) continue;
      final record = validRecords[path];
      try {
        final obsoleteInstalled =
            record != null &&
            installedBuildNumber != null &&
            record.versionCode <= installedBuildNumber;
        final supersededByNewer = record != null && protectedApkPath != null;
        final staleUnverified =
            record == null && apk.statSync().modified.isBefore(cutoff);
        if (obsoleteInstalled || supersededByNewer || staleUnverified) {
          await delete(path);
        }
      } on FileSystemException {
        // A locked file is retried on the next start.
      }
    }
  }
}

Future<String> _hashFile(String path) async {
  final digest = await sha256.bind(File(path).openRead()).first;
  return digest.toString();
}

const MethodChannel _apkInstallChannel = MethodChannel(kApkInstallChannelName);

Future<String> _defaultUpdatesDirectory() async {
  if (Platform.isAndroid) {
    try {
      final dir = await _apkInstallChannel.invokeMethod<String>(
        'updatesDirectory',
      );
      if (dir != null && dir.isNotEmpty) return dir;
    } on Object {
      // Fail closed below so the store never writes outside noBackupFilesDir/updates.
    }
    throw const FileSystemException(
      'Android updatesDirectory channel path is unavailable.',
    );
  }
  return '${(await getTemporaryDirectory()).path}/updates';
}

ApkFileStore createApkFileStore() => ApkFileStoreIo(
  temporaryDirectory: () async => (await getTemporaryDirectory()).path,
  updatesDirectory: _defaultUpdatesDirectory,
);
