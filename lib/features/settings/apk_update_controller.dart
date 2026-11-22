import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../shared/releases/apk_download_policy.dart';
import '../../shared/releases/apk_integrity.dart';
import '../../shared/releases/apk_update.dart';
import '../../shared/releases/app_version.dart';
import '../../shared/releases/update_selector.dart';
import 'update_check_controller.dart';

/// Downloads and verifies the exact Android update, then commits it to a
/// native `PackageInstaller` session (unattended on Android 12+ when the OS
/// permits, or launching the native confirmation screen on
/// `STATUS_PENDING_USER_ACTION`). It never opens a browser.
final class ApkUpdateController extends ChangeNotifier {
  ApkUpdateController({
    required ApkAssetFetcher fetcher,
    required ApkInstaller installer,
    required ApkFileStore fileStore,
    required UpdateCheckController checks,
    required Future<String> Function() installedBuildNumber,
    required Future<String> Function() packageName,
    required bool Function() isForeground,
    (String title, String body, String channel) Function()? notificationCopy,
  }) : _fetcher = fetcher,
       _installer = installer,
       _fileStore = fileStore,
       _checks = checks,
       _installedBuildNumber = installedBuildNumber,
       _packageName = packageName,
       _isForeground = isForeground,
       _notificationCopy = notificationCopy,
       _lastChannel = checks.channel {
    _checks.addListener(_onCheckChanged);
    _signalSubscription = _installer.signals.listen(_onInstallerSignal);
    _cleanupTask = checks.target == UpdateTarget.androidArm64
        ? _restoreAndCleanup()
        : Future.value();
  }

  bool get blocksNotices => const {
    ApkUpdateStatus.downloading,
    ApkUpdateStatus.verifying,
    ApkUpdateStatus.ready,
    ApkUpdateStatus.handingOff,
    ApkUpdateStatus.installing,
  }.contains(_status);

  Future<void> _restoreAndCleanup() async {
    int? buildNumber;
    try {
      buildNumber = int.tryParse(await _installedBuildNumber());
    } on Object {
      buildNumber = null;
    }
    try {
      await _fileStore.cleanupStale(installedBuildNumber: buildNumber);
    } on Object {
      // A missing platform cache is not fatal for the update flow.
    }
    if (buildNumber == null) return;
    try {
      if (await _packageName() != codewalkAndroidApplicationId) return;
      final record = await _fileStore.restoreCached(
        installedBuildNumber: buildNumber,
      );
      if (record == null) return;
      final parsedVersion = AppVersion.tryParse(record.version);
      if (parsedVersion == null ||
          !isExactReleaseAssetUri(
            record.assetUrl,
            tag: record.tag,
            name: codewalkAndroidAssetName,
          ) ||
          !await _fileStore.exists(record.path)) {
        await _fileStore.delete(record.path);
        return;
      }
      final digest = await _fileStore.sha256(record.path);
      if (digest == null || digest != record.sha256) {
        await _fileStore.delete(record.path);
        return;
      }
      if (_disposed || _generation != 0 || _status != ApkUpdateStatus.idle) {
        return;
      }
      _candidate = UpdateCandidate(
        tag: record.tag,
        version: parsedVersion,
        assetUrl: record.assetUrl,
      );
      _verifiedPath = record.path;
      _expectedSha256 = record.sha256;
      _verifiedVersionCode = record.versionCode;
      _notify();
    } on Object {
      // Corrupt or unreadable cached metadata is ignored safely.
    }
  }

  final ApkAssetFetcher _fetcher;
  final ApkInstaller _installer;
  final ApkFileStore _fileStore;
  final UpdateCheckController _checks;
  final Future<String> Function() _installedBuildNumber;
  final Future<String> Function() _packageName;
  final bool Function() _isForeground;
  final (String title, String body, String channel) Function()?
  _notificationCopy;
  late final Future<void> _cleanupTask;
  StreamSubscription<ApkInstallSignal>? _signalSubscription;
  UpdateChannel _lastChannel;

  ApkUpdateStatus _status = ApkUpdateStatus.idle;
  ApkUpdateFailure? _failure;
  double _progress = 0;
  UpdateCandidate? _candidate;
  String? _verifiedPath;
  String? _expectedSha256;
  int? _verifiedVersionCode;
  DateTime? _lastProgressAt;
  int _generation = 0;
  bool _busy = false;
  bool _disposed = false;
  bool _cancelled = false;
  bool _cancelInProgress = false;

  ApkUpdateStatus get status => _status;
  ApkUpdateFailure? get failure => _failure;
  double get progress => _progress;
  UpdateCandidate? get candidate => _candidate;
  bool get hasVerifiedPackage => _verifiedPath != null;
  bool hasVerifiedCandidate(UpdateCandidate candidate) =>
      _verifiedPath != null && _candidate?.tag == candidate.tag;

  /// Whether a verified downloaded APK is cached locally and ready to install.
  bool get hasPendingCachedUpdate =>
      _verifiedPath != null &&
      _candidate != null &&
      !const {
        ApkUpdateStatus.downloading,
        ApkUpdateStatus.verifying,
        ApkUpdateStatus.handingOff,
        ApkUpdateStatus.installing,
      }.contains(_status);

  /// Downloads, verifies and (when foregrounded) opens the installer for the
  /// exact [candidate] selected by [UpdateCheckController].
  Future<void> start(UpdateCandidate candidate) async {
    if (_disposed || _busy || _cancelInProgress) return;
    if (_status == ApkUpdateStatus.downloading ||
        _status == ApkUpdateStatus.verifying ||
        _status == ApkUpdateStatus.handingOff ||
        _status == ApkUpdateStatus.installing) {
      return;
    }
    if (hasVerifiedCandidate(candidate)) {
      _busy = true;
      try {
        _status = ApkUpdateStatus.ready;
        _failure = null;
        notifyListeners();
        await openInstaller();
      } finally {
        _busy = false;
      }
      return;
    }
    _busy = true;
    final generation = ++_generation;
    final previousVerifiedPath =
        _verifiedPath != null && _candidate?.tag != candidate.tag
        ? _verifiedPath
        : null;
    _cancelled = false;
    _candidate = candidate;
    _verifiedPath = null;
    _expectedSha256 = null;
    _verifiedVersionCode = null;
    _failure = null;
    _progress = 0;
    _status = ApkUpdateStatus.downloading;
    notifyListeners();
    try {
      await _cleanupTask;
      if (!_current(generation)) return;
      if (await _packageName() != codewalkAndroidApplicationId) {
        _fail(ApkUpdateFailure.unsupported);
        return;
      }
      if (!_current(generation)) return;
      final buildNumber = int.tryParse(await _installedBuildNumber());
      if (!_current(generation)) return;
      if (buildNumber == null) {
        _fail(ApkUpdateFailure.unsupported);
        return;
      }
      final tag = candidate.tag;
      if (!isExactReleaseAssetUri(
        candidate.assetUrl,
        tag: tag,
        name: codewalkAndroidAssetName,
      )) {
        _fail(ApkUpdateFailure.http);
        return;
      }
      final sumsBody = await _fetcher.fetchText(
        releaseAssetUri(tag, releaseChecksumsAssetName),
        maxBytes: maxIntegrityBytes,
      );
      if (!_current(generation)) return;
      final manifestBody = await _fetcher.fetchText(
        releaseAssetUri(tag, releaseManifestAssetName),
        maxBytes: maxIntegrityBytes,
      );
      if (!_current(generation)) return;
      final digest = parseSha256Sums(sumsBody, codewalkAndroidAssetName);
      final manifest = parseReleaseManifest(
        manifestBody,
        tag: tag,
        assetName: codewalkAndroidAssetName,
      );
      if (digest == null) {
        _fail(ApkUpdateFailure.checksumUnavailable);
        return;
      }
      if (manifest == null ||
          manifest.asset.sha256 != digest ||
          manifest.asset.signerSha256 != codewalkAndroidSignerSha256) {
        _fail(ApkUpdateFailure.manifestInvalid);
        return;
      }
      if (manifest.asset.versionCode <= buildNumber) {
        _fail(ApkUpdateFailure.downgrade);
        return;
      }
      _expectedSha256 = manifest.asset.sha256;
      final partPath = await _fileStore.partPath(tag);
      if (!_current(generation)) return;
      final result = await _fetcher.download(
        candidate.assetUrl,
        partPath,
        expectedBytes: manifest.asset.size,
        expectedSha256: manifest.asset.sha256,
        onProgress: (received, total) {
          if (!_current(generation)) return;
          final next = total != null && total > 0
              ? (received / total).clamp(0.0, 1.0)
              : 0.0;
          final now = DateTime.now();
          if (!shouldNotifyApkProgress(
            previous: _progress,
            next: next,
            lastNotifiedAt: _lastProgressAt,
            now: now,
          )) {
            return;
          }
          _progress = next;
          _lastProgressAt = now;
          notifyListeners();
        },
        isCancelled: () => _cancelled || !_current(generation),
      );
      if (!_current(generation)) return;
      _status = ApkUpdateStatus.verifying;
      _progress = 1;
      notifyListeners();
      if (result.bytes != manifest.asset.size ||
          result.sha256 != manifest.asset.sha256) {
        await _fileStore.delete(partPath);
        _fail(ApkUpdateFailure.checksumMismatch);
        return;
      }
      final finalPath = await _fileStore.finalPath(tag);
      await _fileStore.rename(partPath, finalPath);
      if (!_current(generation)) {
        await _fileStore.delete(finalPath);
        return;
      }
      if (previousVerifiedPath != null && previousVerifiedPath != finalPath) {
        await _fileStore.delete(previousVerifiedPath);
      }
      await _fileStore.writeSidecar(
        ApkCachedRecord(
          tag: tag,
          version: candidate.version.toString(),
          versionCode: manifest.asset.versionCode,
          assetUrl: candidate.assetUrl,
          sha256: manifest.asset.sha256,
          size: manifest.asset.size,
          path: finalPath,
          savedAt: DateTime.now().toUtc(),
        ),
      );
      if (!_current(generation)) {
        await _fileStore.delete(finalPath);
        return;
      }
      _verifiedPath = finalPath;
      _verifiedVersionCode = manifest.asset.versionCode;
      _status = ApkUpdateStatus.ready;
      notifyListeners();
      if (_isForeground()) await openInstaller();
    } on ApkDownloadException catch (error) {
      if (_current(generation) && error.failure != ApkUpdateFailure.cancelled) {
        _fail(error.failure);
      }
    } on Object {
      if (_current(generation)) _fail(ApkUpdateFailure.network);
    } finally {
      _busy = false;
    }
  }

  /// Opens or re-opens the verified file without downloading it again.
  Future<void> openInstaller() async {
    if (_disposed) return;
    if (_generation == 0) {
      await _cleanupTask;
      if (_disposed) return;
    }
    final generation = _generation;
    final canOpen =
        _status == ApkUpdateStatus.ready ||
        _status == ApkUpdateStatus.installerOpened ||
        ((_status == ApkUpdateStatus.failed ||
                _status == ApkUpdateStatus.idle) &&
            _verifiedPath != null);
    if (!canOpen) return;
    final path = _verifiedPath;
    final expected = _expectedSha256;
    if (path == null || expected == null) {
      _fail(ApkUpdateFailure.fileMissing);
      return;
    }
    try {
      _status = ApkUpdateStatus.handingOff;
      _failure = null;
      _notify();
      if (!await _fileStore.exists(path)) {
        if (!_current(generation)) return;
        _verifiedPath = null;
        _verifiedVersionCode = null;
        _fail(ApkUpdateFailure.fileMissing);
        return;
      }
      if (!_current(generation)) return;
      final digest = await _fileStore.sha256(path);
      if (!_current(generation)) return;
      if (digest == null || digest != expected) {
        await _fileStore.delete(path);
        if (!_current(generation)) return;
        _verifiedPath = null;
        _verifiedVersionCode = null;
        _fail(ApkUpdateFailure.checksumMismatch);
        return;
      }
      if (!_isForeground()) {
        _status = ApkUpdateStatus.ready;
        _notify();
        return;
      }
      final copy = _notificationCopy?.call();
      final outcome = await _installer.open(
        path,
        versionCode: _verifiedVersionCode,
        tag: _candidate?.tag,
        notificationTitle: copy?.$1,
        notificationBody: copy?.$2,
        notificationChannel: copy?.$3,
      );
      if (!_current(generation)) return;
      switch (outcome) {
        case ApkInstallOutcome.committed:
          if (_status == ApkUpdateStatus.handingOff) {
            _status = ApkUpdateStatus.installing;
            _failure = null;
          }
        case ApkInstallOutcome.opened:
          _status = ApkUpdateStatus.installerOpened;
          _failure = null;
        case ApkInstallOutcome.noInstaller:
          _fail(ApkUpdateFailure.installerUnavailable);
        case ApkInstallOutcome.denied:
          _fail(ApkUpdateFailure.installerDenied);
        case ApkInstallOutcome.fileMissing:
          _verifiedPath = null;
          _verifiedVersionCode = null;
          _fail(ApkUpdateFailure.fileMissing);
        case ApkInstallOutcome.storage:
          _fail(ApkUpdateFailure.storage);
        case ApkInstallOutcome.failed:
          _fail(ApkUpdateFailure.installerFailed);
      }
      _notify();
    } on Object {
      if (_current(generation)) _fail(ApkUpdateFailure.installerFailed);
    }
  }

  void _onInstallerSignal(ApkInstallSignal signal) {
    if (_disposed || _verifiedPath == null) return;
    if (_status == ApkUpdateStatus.downloading ||
        _status == ApkUpdateStatus.verifying) {
      return;
    }
    switch (signal) {
      case ApkInstallSignal.confirmation:
        _status = ApkUpdateStatus.installerOpened;
        _failure = null;
        _notify();
      case ApkInstallSignal.aborted:
        if (_status != ApkUpdateStatus.idle) {
          _status = ApkUpdateStatus.ready;
        }
        _failure = null;
        _notify();
      case ApkInstallSignal.storage:
        _fail(ApkUpdateFailure.storage);
      case ApkInstallSignal.failed:
        _fail(ApkUpdateFailure.installerFailed);
      case ApkInstallSignal.succeeded:
        final path = _verifiedPath;
        _verifiedPath = null;
        _verifiedVersionCode = null;
        _expectedSha256 = null;
        _status = ApkUpdateStatus.idle;
        _failure = null;
        _progress = 0;
        _notify();
        if (path != null) {
          unawaited(_fileStore.delete(path));
        }
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Aborts an active transfer and removes its partial or verified file.
  Future<void> cancel() async {
    if (_disposed || _cancelInProgress) return;
    if (_status == ApkUpdateStatus.idle && _verifiedPath == null) return;
    _cancelInProgress = true;
    try {
      _cancelled = true;
      _generation++;
      _fetcher.cancelActive();
      _status = ApkUpdateStatus.idle;
      _failure = null;
      _progress = 0;
      final tag = _candidate?.tag;
      final path = _verifiedPath;
      _verifiedPath = null;
      _verifiedVersionCode = null;
      _expectedSha256 = null;
      if (tag != null) {
        await _fileStore.delete(await _fileStore.partPath(tag));
      }
      if (path != null) await _fileStore.delete(path);
      await _installer.clearPendingMarker();
      _notify();
    } finally {
      _cancelInProgress = false;
    }
  }

  /// Retries the last failed candidate, reusing a verified APK when the
  /// failure came only from the installer handoff or session commit.
  Future<void> retry() async {
    final candidate = _candidate;
    if (candidate == null || _status != ApkUpdateStatus.failed) return;
    final failure = _failure;
    if (_verifiedPath != null &&
        (failure == ApkUpdateFailure.installerUnavailable ||
            failure == ApkUpdateFailure.installerDenied ||
            failure == ApkUpdateFailure.installerFailed ||
            failure == ApkUpdateFailure.storage)) {
      await openInstaller();
      return;
    }
    await start(candidate);
  }

  /// Hides the current result; a verified APK stays for a later install.
  void dismiss() {
    if (_disposed) return;
    _status = ApkUpdateStatus.idle;
    _failure = null;
    _progress = 0;
    notifyListeners();
  }

  void _onCheckChanged() {
    if (_disposed) return;
    final changed = _checks.channel != _lastChannel;
    _lastChannel = _checks.channel;
    final droppedBetaCandidate =
        changed &&
        _checks.channel == UpdateChannel.stable &&
        (_candidate?.version.isPrerelease ?? false) &&
        (_status == ApkUpdateStatus.idle ||
            _status == ApkUpdateStatus.ready ||
            _status == ApkUpdateStatus.failed);
    if (droppedBetaCandidate) {
      unawaited(cancel());
      return;
    }
    final supersededFailure =
        _status == ApkUpdateStatus.failed &&
        _checks.status != UpdateCheckStatus.checking &&
        _checks.candidate?.tag != _candidate?.tag;
    if ((changed || supersededFailure) &&
        _status != ApkUpdateStatus.idle &&
        _verifiedPath == null) {
      unawaited(cancel());
    }
  }

  bool _current(int generation) =>
      !_disposed && generation == _generation && !_cancelled;

  void _fail(ApkUpdateFailure failure) {
    if (_disposed) return;
    _status = ApkUpdateStatus.failed;
    _failure = failure;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _checks.removeListener(_onCheckChanged);
    unawaited(_signalSubscription?.cancel());
    _fetcher.close();
    super.dispose();
  }
}
