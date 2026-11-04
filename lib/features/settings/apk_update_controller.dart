import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../shared/releases/apk_download_policy.dart';
import '../../shared/releases/apk_integrity.dart';
import '../../shared/releases/apk_update.dart';
import '../../shared/releases/update_selector.dart';
import 'update_check_controller.dart';

/// Downloads and verifies the exact Android update, then hands it to the
/// system installer. It never installs silently and never opens a browser.
final class ApkUpdateController extends ChangeNotifier {
  ApkUpdateController({
    required ApkAssetFetcher fetcher,
    required ApkInstaller installer,
    required ApkFileStore fileStore,
    required UpdateCheckController checks,
    required Future<String> Function() installedBuildNumber,
    required Future<String> Function() packageName,
    required bool Function() isForeground,
  }) : _fetcher = fetcher,
       _installer = installer,
       _fileStore = fileStore,
       _checks = checks,
       _installedBuildNumber = installedBuildNumber,
       _packageName = packageName,
       _isForeground = isForeground {
    _checks.addListener(_onCheckChanged);
    unawaited(_cleanupStale());
  }

  Future<void> _cleanupStale() async {
    try {
      await _fileStore.cleanupStale();
    } on Object {
      // A missing platform cache is not fatal for the update flow.
    }
  }

  final ApkAssetFetcher _fetcher;
  final ApkInstaller _installer;
  final ApkFileStore _fileStore;
  final UpdateCheckController _checks;
  final Future<String> Function() _installedBuildNumber;
  final Future<String> Function() _packageName;
  final bool Function() _isForeground;

  ApkUpdateStatus _status = ApkUpdateStatus.idle;
  ApkUpdateFailure? _failure;
  double _progress = 0;
  UpdateCandidate? _candidate;
  String? _verifiedPath;
  String? _expectedSha256;
  DateTime? _lastProgressAt;
  int _generation = 0;
  bool _busy = false;
  bool _disposed = false;
  bool _cancelled = false;

  ApkUpdateStatus get status => _status;
  ApkUpdateFailure? get failure => _failure;
  double get progress => _progress;
  UpdateCandidate? get candidate => _candidate;
  bool get hasVerifiedPackage => _verifiedPath != null;

  /// Downloads, verifies and (when foregrounded) opens the installer for the
  /// exact [candidate] selected by [UpdateCheckController].
  Future<void> start(UpdateCandidate candidate) async {
    if (_disposed || _busy) return;
    if (_status == ApkUpdateStatus.downloading ||
        _status == ApkUpdateStatus.verifying ||
        _status == ApkUpdateStatus.handingOff) {
      return;
    }
    _busy = true;
    final generation = ++_generation;
    _cancelled = false;
    _candidate = candidate;
    _verifiedPath = null;
    _expectedSha256 = null;
    _failure = null;
    _progress = 0;
    _status = ApkUpdateStatus.downloading;
    notifyListeners();
    try {
      if (await _packageName() != codewalkAndroidApplicationId) {
        _fail(ApkUpdateFailure.unsupported);
        return;
      }
      final buildNumber = int.tryParse(await _installedBuildNumber());
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
      if (buildNumber != null && manifest.asset.versionCode <= buildNumber) {
        _fail(ApkUpdateFailure.downgrade);
        return;
      }
      _expectedSha256 = manifest.asset.sha256;
      final partPath = await _fileStore.partPath(tag);
      final result = await _fetcher.download(
        candidate.assetUrl,
        partPath,
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
      _verifiedPath = finalPath;
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

  /// Re-opens the verified file without downloading it again.
  Future<void> openInstaller() async {
    if (_disposed) return;
    final generation = _generation;
    final canOpen =
        _status == ApkUpdateStatus.ready ||
        _status == ApkUpdateStatus.installerOpened ||
        (_status == ApkUpdateStatus.failed && _verifiedPath != null);
    if (!canOpen) return;
    final path = _verifiedPath;
    final expected = _expectedSha256;
    if (path == null || expected == null) {
      _fail(ApkUpdateFailure.fileMissing);
      return;
    }
    try {
      if (!await _fileStore.exists(path)) {
        if (!_current(generation)) return;
        _verifiedPath = null;
        _fail(ApkUpdateFailure.fileMissing);
        return;
      }
      if (!_current(generation)) return;
      _status = ApkUpdateStatus.handingOff;
      _notify();
      final digest = await _fileStore.sha256(path);
      if (!_current(generation)) return;
      if (digest == null || digest != expected) {
        await _fileStore.delete(path);
        if (!_current(generation)) return;
        _verifiedPath = null;
        _fail(ApkUpdateFailure.checksumMismatch);
        return;
      }
      if (!_isForeground()) {
        _status = ApkUpdateStatus.ready;
        _notify();
        return;
      }
      final outcome = await _installer.open(path);
      if (!_current(generation)) return;
      switch (outcome) {
        case ApkInstallOutcome.opened:
          _status = ApkUpdateStatus.installerOpened;
        case ApkInstallOutcome.noInstaller:
          _fail(ApkUpdateFailure.installerUnavailable);
        case ApkInstallOutcome.denied:
          _fail(ApkUpdateFailure.installerDenied);
        case ApkInstallOutcome.fileMissing:
          _verifiedPath = null;
          _fail(ApkUpdateFailure.fileMissing);
        case ApkInstallOutcome.failed:
          _fail(ApkUpdateFailure.installerFailed);
      }
      _notify();
    } on Object {
      if (_current(generation)) _fail(ApkUpdateFailure.fileMissing);
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Aborts an active transfer and removes its partial file.
  Future<void> cancel() async {
    if (_disposed) return;
    if (_status == ApkUpdateStatus.idle) return;
    _cancelled = true;
    _generation++;
    _fetcher.cancelActive();
    _status = ApkUpdateStatus.idle;
    _failure = null;
    _progress = 0;
    final tag = _candidate?.tag;
    final path = _verifiedPath;
    _verifiedPath = null;
    if (tag != null) {
      await _fileStore.delete(await _fileStore.partPath(tag));
    }
    if (path != null) await _fileStore.delete(path);
    _notify();
  }

  /// Retries the last failed candidate, reusing a verified APK when the
  /// failure came only from the installer handoff.
  Future<void> retry() async {
    final candidate = _candidate;
    if (candidate == null || _status != ApkUpdateStatus.failed) return;
    final failure = _failure;
    if (_verifiedPath != null &&
        (failure == ApkUpdateFailure.installerUnavailable ||
            failure == ApkUpdateFailure.installerDenied ||
            failure == ApkUpdateFailure.installerFailed)) {
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
    if (_disposed || _status == ApkUpdateStatus.idle) return;
    final candidate = _checks.candidate;
    if (_verifiedPath != null) return;
    if (candidate == null || candidate.tag != _candidate?.tag) {
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
    _fetcher.close();
    super.dispose();
  }
}
