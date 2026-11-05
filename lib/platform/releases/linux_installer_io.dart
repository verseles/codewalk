import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../shared/releases/apk_download_policy.dart';
import '../../shared/releases/apk_update.dart';
import '../../shared/releases/linux_update.dart';
import '../../shared/releases/update_selector.dart';
import 'apk_fetcher_io.dart';
import 'linux_update_cache_io.dart';

final class LinuxInstallerIo implements LinuxUpdateInstaller {
  LinuxInstallerIo({ApkAssetFetcher? fetcher})
    : _fetcher = fetcher ?? HttpClientApkFetcher();
  final ApkAssetFetcher _fetcher;
  Process? _process;
  bool _closed = false;
  String? _installedTag;

  String get _home => Platform.environment['HOME'] ?? '';
  String get _root =>
      '${Platform.environment['XDG_DATA_HOME'] ?? '$_home/.local/share'}/codewalk-app';
  String get _script => '$_root/updater/install.sh';

  @override
  Future<bool> available() async {
    if (!Platform.isLinux || _home.isEmpty || _closed) return false;
    try {
      final executable = await File(
        Platform.resolvedExecutable,
      ).resolveSymbolicLinks();
      final root = await Directory(_root).resolveSymbolicLinks();
      final version = (await File(
        '$root/.installed-version',
      ).readAsString()).trim();
      return executable == '$root/codewalk' &&
          version.startsWith('v2.') &&
          File(_script).existsSync() &&
          File('/usr/bin/setsid').existsSync();
    } on Object {
      return false;
    }
  }

  @override
  Future<void> install(
    UpdateCandidate candidate, {
    required void Function(LinuxUpdateStatus, double) onProgress,
  }) async {
    if (!await available() || _process != null) {
      throw const LinuxUpdateException(LinuxUpdateFailure.unavailable);
    }
    final name = candidate.assetUrl.pathSegments.last;
    final expectedName = switch (Abi.current()) {
      Abi.linuxX64 => 'codewalk-linux-x64.tar.gz',
      Abi.linuxArm64 => 'codewalk-linux-arm64.tar.gz',
      _ => '',
    };
    if (name != expectedName ||
        !isExactReleaseAssetUri(
          candidate.assetUrl,
          tag: candidate.tag,
          name: name,
        )) {
      throw const LinuxUpdateException(LinuxUpdateFailure.integrity);
    }
    try {
      final sums = await _fetcher.fetchText(
        releaseAssetUri(candidate.tag, releaseChecksumsAssetName),
      );
      final body = await _fetcher.fetchText(
        releaseAssetUri(candidate.tag, releaseManifestAssetName),
      );
      final asset = parseLinuxAssetManifest(
        body,
        sums,
        tag: candidate.tag,
        assetName: name,
      );
      if (asset == null) {
        throw const LinuxUpdateException(LinuxUpdateFailure.integrity);
      }
      final digest = asset.sha256;
      if (_closed) return;
      final cache = await getApplicationCacheDirectory();
      final root = await prepareLinuxUpdateCache(
        Directory('${cache.path}/cw2-updates'),
      );
      final archive = await linuxUpdatePartPath(root, candidate.tag, name);
      onProgress(LinuxUpdateStatus.downloading, 0);
      var lastProgress = 0.0;
      DateTime? lastProgressAt;
      final result = await _fetcher.download(
        candidate.assetUrl,
        archive,
        expectedBytes: asset.size,
        expectedSha256: digest,
        isCancelled: () => _closed,
        onProgress: (received, total) {
          final next = total == null || total == 0 ? 0.0 : received / total;
          final now = DateTime.now();
          if (shouldNotifyApkProgress(
            previous: lastProgress,
            next: next,
            lastNotifiedAt: lastProgressAt,
            now: now,
          )) {
            lastProgress = next;
            lastProgressAt = now;
            onProgress(LinuxUpdateStatus.downloading, next);
          }
        },
      );
      if (_closed) return;
      onProgress(LinuxUpdateStatus.verifying, 1);
      if (result.bytes != asset.size || result.sha256 != digest) {
        await File(archive).delete();
        throw const LinuxUpdateException(LinuxUpdateFailure.integrity);
      }
      onProgress(LinuxUpdateStatus.installing, 1);
      final environment = linuxInstallerEnvironment(
        Platform.environment,
        temporary: root.path,
      );
      environment.addAll({
        'CODEWALK_UPDATE_CONTRACT': '1',
        'CODEWALK_CHANNEL': candidate.version.isPrerelease ? 'beta' : 'stable',
        'CODEWALK_VERSION': candidate.tag,
        'CODEWALK_MIGRATION': 'none',
        'CODEWALK_LOCAL_ARCHIVE': archive,
        'CODEWALK_LOCAL_SHA256': digest,
      });
      final process = _process = await Process.start(
        '/usr/bin/setsid',
        ['/bin/sh', _script],
        environment: environment,
        includeParentEnvironment: false,
      );
      final output = process.stdout.drain<void>();
      final errors = process.stderr.drain<void>();
      if (_closed) {
        await _stop(process);
        return;
      }
      int code;
      try {
        final completed = await Future.wait<Object?>([
          process.exitCode,
          output,
          errors,
        ]).timeout(const Duration(minutes: 5));
        code = completed.first as int;
      } on TimeoutException {
        await _stop(process);
        throw const LinuxUpdateException(LinuxUpdateFailure.install);
      } finally {
        _process = null;
      }
      if (_closed) return;
      if (code != 0 ||
          (await File('$_root/.installed-version').readAsString()).trim() !=
              candidate.tag) {
        throw const LinuxUpdateException(LinuxUpdateFailure.install);
      }
      _installedTag = candidate.tag;
      await File(archive).delete();
      final sidecar = File('$archive.json');
      if (sidecar.existsSync()) await sidecar.delete();
    } on ApkDownloadException catch (error) {
      throw LinuxUpdateException(switch (error.failure) {
        ApkUpdateFailure.storage => LinuxUpdateFailure.storage,
        ApkUpdateFailure.http => LinuxUpdateFailure.http,
        ApkUpdateFailure.tooLarge => LinuxUpdateFailure.tooLarge,
        _ => LinuxUpdateFailure.network,
      });
    } on FileSystemException {
      throw const LinuxUpdateException(LinuxUpdateFailure.storage);
    } on FormatException {
      throw const LinuxUpdateException(LinuxUpdateFailure.integrity);
    }
  }

  Future<void> _stop(Process process) async {
    await Process.run('/bin/kill', ['-TERM', '--', '-${process.pid}']);
    try {
      await process.exitCode.timeout(const Duration(seconds: 3));
    } on TimeoutException {
      await Process.run('/bin/kill', ['-KILL', '--', '-${process.pid}']);
      await process.exitCode;
    }
  }

  @override
  Future<bool> restart() async {
    if (_closed || _installedTag == null) return false;
    try {
      if ((await File('$_root/.installed-version').readAsString()).trim() !=
          _installedTag) {
        return false;
      }
      final launcher = File('$_home/.local/bin/codewalk');
      if (await launcher.resolveSymbolicLinks() !=
          await File('$_root/codewalk').resolveSymbolicLinks()) {
        return false;
      }
      await launchUpdatedLinuxApp(launcher.path);
      return true;
    } on Object {
      return false;
    }
  }

  @override
  void close() {
    _closed = true;
    _fetcher.close();
    final process = _process;
    if (process != null) {
      unawaited(
        _stop(process).catchError((Object _) {
          // Shutdown cannot report through a disposed app graph.
        }),
      );
    }
  }
}

LinuxUpdateInstaller createLinuxInstaller() => LinuxInstallerIo();

Map<String, String> linuxInstallerEnvironment(
  Map<String, String> parent, {
  required String temporary,
}) => {
  for (final key in [
    'HOME',
    'PATH',
    'XDG_DATA_HOME',
    'XDG_CONFIG_HOME',
    'XDG_CACHE_HOME',
    'XDG_RUNTIME_DIR',
    'DISPLAY',
    'WAYLAND_DISPLAY',
    'DBUS_SESSION_BUS_ADDRESS',
  ])
    key: ?parent[key],
  'TMPDIR': temporary,
};

/// Relaunch inherits the desktop session, unlike the scrubbed installer process.
Future<void> launchUpdatedLinuxApp(String executable) async {
  await Process.start(executable, const [], mode: ProcessStartMode.detached);
}
