import 'dart:async';
import 'dart:convert';

import 'package:codewalk/features/settings/apk_update_controller.dart';
import 'package:codewalk/features/settings/update_check_controller.dart';
import 'package:codewalk/platform/storage/metadata_store.dart';
import 'package:codewalk/shared/releases/apk_integrity.dart';
import 'package:codewalk/shared/releases/apk_update.dart';
import 'package:codewalk/shared/releases/app_version.dart';
import 'package:codewalk/shared/releases/release_source.dart';
import 'package:codewalk/shared/releases/update_selector.dart';
import 'package:flutter_test/flutter_test.dart';

import '../storage/storage_fakes.dart';

const _sha = '64d338107e0175b26d25343ed00af2a01ac009c9286c16c9f1aed32ac7c58f5b';
const _asset = 'codewalk-android-arm64.apk';

String manifest({
  String sha = _sha,
  int versionCode = 2,
  String tag = 'v2.0.0-beta.2',
  String version = '2.0.0-beta.2',
}) => jsonEncode({
  'schema': 1,
  'tag': tag,
  'version': version,
  'assets': {
    _asset: {
      'abi': 'arm64-v8a',
      'application_id': 'com.verseles.codewalk',
      'sha256': sha,
      'signer_sha256': codewalkAndroidSignerSha256,
      'size': 10,
      'version_code': versionCode,
      'version_name': version,
    },
  },
});

final candidate = UpdateCandidate(
  tag: 'v2.0.0-beta.2',
  version: AppVersion.tryParse('2.0.0-beta.2')!,
  assetUrl: Uri.parse(
    'https://github.com/verseles/codewalk/releases/download/v2.0.0-beta.2/$_asset',
  ),
);

class EmptySource implements ReleaseSource {
  @override
  ReleaseSourceTask start({String? until}) => _EmptyTask();
  @override
  void close() {}
}

class _EmptyTask implements ReleaseSourceTask {
  @override
  Future<ReleaseSourceResult> get result async =>
      const ReleaseSourceResult.success('[]');
  @override
  void cancel() {}
}

class FakeStore implements ApkFileStore {
  final Map<String, String> files = {};
  final Map<String, ApkCachedRecord> sidecars = {};
  bool throwOnSha = false;

  @override
  Future<String> partPath(String tag) async => '/tmp/$tag.clip.part';

  @override
  Future<String> finalPath(String tag) async => '/tmp/$tag.clip';

  @override
  Future<void> rename(String from, String to) async {
    files[to] = files[from] ?? '';
    files.remove(from);
  }

  @override
  Future<void> delete(String path) async {
    files.remove(path);
    sidecars.remove(path);
  }

  @override
  Future<bool> exists(String path) async => files.containsKey(path);

  @override
  Future<String?> sha256(String path) async {
    if (throwOnSha) throw StateError('hash failed');
    return files[path];
  }

  @override
  Future<void> writeSidecar(ApkCachedRecord record) async {
    sidecars[record.path] = record;
  }

  @override
  Future<ApkCachedRecord?> restoreCached({
    required int installedBuildNumber,
  }) async {
    final valid = <ApkCachedRecord>[];
    for (final entry in sidecars.entries.toList()) {
      if (!files.containsKey(entry.key)) continue;
      if (entry.value.versionCode <= installedBuildNumber) {
        await delete(entry.key);
        continue;
      }
      valid.add(entry.value);
    }
    if (valid.isEmpty) return null;
    valid.sort((a, b) => b.versionCode.compareTo(a.versionCode));
    return valid.first;
  }

  @override
  Future<void> cleanupStale({int? installedBuildNumber}) async {}
}

class FakeFetcher implements ApkAssetFetcher {
  FakeFetcher(this.store);

  final FakeStore store;
  String? sumsBody;
  String? manifestBody;
  String downloadSha = _sha;
  int downloadBytes = 10;
  Uri? downloaded;
  Exception? failure;
  int downloads = 0;
  Completer<void>? downloadGate;
  int cancellations = 0;

  @override
  Future<String> fetchText(Uri uri, {int maxBytes = 256 * 1024}) async {
    if (failure case final error?) throw error;
    if (uri.path.endsWith('SHA256SUMS')) {
      return sumsBody ?? '$_sha  $_asset\n';
    }
    return manifestBody ?? manifest();
  }

  @override
  Future<ApkDownloadResult> download(
    Uri uri,
    String partPath, {
    required void Function(int received, int? total) onProgress,
    required bool Function() isCancelled,
    int? expectedBytes,
    String? expectedSha256,
  }) async {
    if (failure case final error?) throw error;
    downloaded = uri;
    downloads++;
    await downloadGate?.future;
    store.files[partPath] = downloadSha;
    onProgress(downloadBytes, downloadBytes);
    return ApkDownloadResult(bytes: downloadBytes, sha256: downloadSha);
  }

  @override
  void close() {}

  @override
  void cancelActive() => cancellations++;
}

class FakeInstaller implements ApkInstaller {
  String? openedPath;
  int? openedVersionCode;
  String? openedTag;
  String? openedTitle;
  String? openedBody;
  int clearedMarkers = 0;
  bool throwOnOpen = false;
  ApkInstallSignal? emitDuringOpen;
  ApkInstallOutcome outcome = ApkInstallOutcome.committed;
  // ignore: close_sinks
  final StreamController<ApkInstallSignal> signalController =
      StreamController<ApkInstallSignal>.broadcast();

  @override
  Stream<ApkInstallSignal> get signals => signalController.stream;

  @override
  Future<ApkInstallOutcome> open(
    String path, {
    int? versionCode,
    String? tag,
    String? notificationTitle,
    String? notificationBody,
    String? notificationChannel,
  }) async {
    if (throwOnOpen) throw StateError('channel exception');
    openedPath = path;
    openedVersionCode = versionCode;
    openedTag = tag;
    openedTitle = notificationTitle;
    openedBody = notificationBody;
    if (emitDuringOpen case final sig?) {
      signalController.add(sig);
      await pumpEventQueue();
    }
    return outcome;
  }

  @override
  Future<void> clearPendingMarker() async {
    clearedMarkers++;
  }
}

void main() {
  late FakeStore store;
  late FakeFetcher fetcher;
  late FakeInstaller installer;
  late UpdateCheckController checks;
  late ApkUpdateController controller;
  var foreground = false;

  void build({
    String packageName = codewalkAndroidApplicationId,
    String build = '1',
  }) {
    final metadata = V2MetadataStore(backend: FakeMetadataBackend());
    checks = UpdateCheckController(
      source: EmptySource(),
      store: metadata,
      installedVersion: () async => '2.0.0-beta.1',
      target: UpdateTarget.androidArm64,
    );
    controller = ApkUpdateController(
      fetcher: fetcher,
      installer: installer,
      fileStore: store,
      checks: checks,
      installedBuildNumber: () async => build,
      packageName: () async => packageName,
      isForeground: () => foreground,
      notificationCopy: () => ('CodeWalk updated', 'Tap to reopen.', 'Updates'),
    );
  }

  setUp(() {
    foreground = false;
    store = FakeStore();
    fetcher = FakeFetcher(store);
    installer = FakeInstaller();
    build();
  });

  tearDown(() {
    controller.dispose();
    checks.dispose();
    unawaited(installer.signalController.close());
  });

  test(
    'downloads the exact asset, writes sidecar, and reaches ready',
    () async {
      await controller.start(candidate);
      expect(controller.status, ApkUpdateStatus.ready);
      expect(fetcher.downloaded, candidate.assetUrl);
      expect(installer.openedPath, isNull);
      expect(controller.hasPendingCachedUpdate, isTrue);
      expect(store.sidecars.values.single.versionCode, 2);
    },
  );

  test('a release check cannot cancel an active APK download', () async {
    fetcher.downloadGate = Completer<void>();
    final download = controller.start(candidate);
    await pumpEventQueue();
    expect(controller.status, ApkUpdateStatus.downloading);
    await checks.check();
    expect(fetcher.cancellations, 0);
    expect(controller.status, ApkUpdateStatus.downloading);
    fetcher.downloadGate!.complete();
    await download;
    expect(controller.status, ApkUpdateStatus.ready);
  });

  test(
    'commits session as installing and handles confirmation, abort, failure, and success signals',
    () async {
      foreground = true;
      await controller.start(candidate);
      expect(controller.status, ApkUpdateStatus.installing);
      expect(installer.openedPath, isNotNull);
      expect(installer.openedVersionCode, 2);
      expect(installer.openedTag, 'v2.0.0-beta.2');
      expect(installer.openedTitle, 'CodeWalk updated');

      // STATUS_PENDING_USER_ACTION -> confirmation -> installerOpened
      installer.signalController.add(ApkInstallSignal.confirmation);
      await pumpEventQueue();
      expect(controller.status, ApkUpdateStatus.installerOpened);

      // STATUS_FAILURE_ABORTED (D3) -> returns cleanly to ready with no failure
      installer.signalController.add(ApkInstallSignal.aborted);
      await pumpEventQueue();
      expect(controller.status, ApkUpdateStatus.ready);
      expect(controller.failure, isNull);
      expect(controller.hasVerifiedPackage, isTrue);

      // Re-open and test STATUS_FAILURE_STORAGE signal -> recoverable storage failure
      await controller.openInstaller();
      expect(controller.status, ApkUpdateStatus.installing);
      installer.signalController.add(ApkInstallSignal.storage);
      await pumpEventQueue();
      expect(controller.status, ApkUpdateStatus.failed);
      expect(controller.failure, ApkUpdateFailure.storage);
      expect(controller.hasVerifiedPackage, isTrue);

      // Retry reuses the verified APK without re-downloading
      await controller.retry();
      expect(controller.status, ApkUpdateStatus.installing);
      expect(fetcher.downloads, 1);

      // STATUS_SUCCESS while alive clears cached APK and returns to idle
      installer.signalController.add(ApkInstallSignal.succeeded);
      await pumpEventQueue();
      expect(controller.status, ApkUpdateStatus.idle);
      expect(controller.hasVerifiedPackage, isFalse);
      expect(store.files, isEmpty);
    },
  );

  test(
    'does not overwrite an earlier status signal when committed returns afterwards',
    () async {
      foreground = true;
      installer.emitDuringOpen = ApkInstallSignal.confirmation;
      await controller.start(candidate);
      expect(controller.status, ApkUpdateStatus.installerOpened);

      installer.emitDuringOpen = ApkInstallSignal.aborted;
      await controller.openInstaller();
      expect(controller.status, ApkUpdateStatus.ready);
      expect(controller.failure, isNull);

      // Dismissing while installing keeps accepting terminal signals:
      // aborted while idle stays idle; succeeded still deletes the consumed APK.
      installer.emitDuringOpen = null;
      await controller.openInstaller();
      expect(controller.status, ApkUpdateStatus.installing);
      controller.dismiss();
      expect(controller.status, ApkUpdateStatus.idle);
      installer.signalController.add(ApkInstallSignal.aborted);
      await pumpEventQueue();
      expect(controller.status, ApkUpdateStatus.idle);
      expect(controller.hasPendingCachedUpdate, isTrue);
      installer.signalController.add(ApkInstallSignal.succeeded);
      await pumpEventQueue();
      expect(controller.status, ApkUpdateStatus.idle);
      expect(controller.hasPendingCachedUpdate, isFalse);
      expect(store.files, isEmpty);
    },
  );

  test(
    'channel exception in openInstaller maps to installerFailed and keeps cached APK',
    () async {
      foreground = true;
      installer.throwOnOpen = true;
      await controller.start(candidate);
      expect(controller.status, ApkUpdateStatus.failed);
      expect(controller.failure, ApkUpdateFailure.installerFailed);
      expect(controller.hasVerifiedPackage, isTrue);

      installer.throwOnOpen = false;
      await controller.retry();
      expect(controller.status, ApkUpdateStatus.installing);
      expect(fetcher.downloads, 1);
    },
  );

  test(
    'restores still-newer cached APK as idle without starving blocksNotices',
    () async {
      await controller.start(candidate);
      expect(store.sidecars, hasLength(1));
      controller.dispose();
      checks.dispose();

      // Cold start with installed build 1 (< cached versionCode 2)
      build(build: '1');
      await pumpEventQueue();
      expect(controller.status, ApkUpdateStatus.idle);
      expect(controller.blocksNotices, isFalse);
      expect(controller.hasPendingCachedUpdate, isTrue);
      expect(controller.candidate?.tag, 'v2.0.0-beta.2');

      // One-tap openInstaller from idle installs without re-downloading
      foreground = true;
      await controller.openInstaller();
      expect(controller.status, ApkUpdateStatus.installing);
      expect(fetcher.downloads, 1);
    },
  );

  test(
    'deletes obsolete cached APK on cold start when installed build caught up',
    () async {
      await controller.start(candidate);
      expect(store.files, isNotEmpty);
      controller.dispose();
      checks.dispose();

      // Cold start after update landed (build 2 >= cached versionCode 2)
      build(build: '2');
      await pumpEventQueue();
      expect(controller.hasPendingCachedUpdate, isFalse);
      expect(store.files, isEmpty);
    },
  );

  test(
    'cancel clears verified APK, sidecar, and native marker; newer download deletes superseded APK',
    () async {
      await controller.start(candidate);
      expect(controller.hasPendingCachedUpdate, isTrue);

      final newer = UpdateCandidate(
        tag: 'v2.2.0',
        version: AppVersion.tryParse('2.2.0')!,
        assetUrl: Uri.parse(
          'https://github.com/verseles/codewalk/releases/download/v2.2.0/$_asset',
        ),
      );
      fetcher.manifestBody = manifest(
        versionCode: 3,
        tag: 'v2.2.0',
        version: '2.2.0',
      );
      await controller.start(newer);
      expect(store.files.keys, ['/tmp/v2.2.0.clip']);
      expect(controller.candidate?.tag, 'v2.2.0');

      await controller.cancel();
      expect(controller.hasPendingCachedUpdate, isFalse);
      expect(store.files, isEmpty);
      expect(installer.clearedMarkers, 1);
    },
  );

  test('fails closed when the checksum file is missing', () async {
    fetcher.sumsBody = '';
    await controller.start(candidate);
    expect(controller.status, ApkUpdateStatus.failed);
    expect(controller.failure, ApkUpdateFailure.checksumUnavailable);
  });

  test('fails closed when the manifest disagrees with the sums', () async {
    fetcher.manifestBody = manifest(sha: 'a' * 64);
    await controller.start(candidate);
    expect(controller.status, ApkUpdateStatus.failed);
    expect(controller.failure, ApkUpdateFailure.manifestInvalid);
  });

  test('fails closed when the streamed bytes disagree', () async {
    fetcher.downloadSha = 'b' * 64;
    await controller.start(candidate);
    expect(controller.status, ApkUpdateStatus.failed);
    expect(controller.failure, ApkUpdateFailure.checksumMismatch);
  });

  test(
    'retries the installer without downloading again on denied or failed',
    () async {
      foreground = true;
      installer.outcome = ApkInstallOutcome.denied;
      await controller.start(candidate);
      expect(controller.status, ApkUpdateStatus.failed);
      expect(controller.failure, ApkUpdateFailure.installerDenied);
      installer.outcome = ApkInstallOutcome.opened;
      await controller.retry();
      expect(controller.status, ApkUpdateStatus.installerOpened);
      expect(fetcher.downloads, 1);
    },
  );

  test('refuses a downgrade', () async {
    build(build: '999');
    await controller.start(candidate);
    expect(controller.status, ApkUpdateStatus.failed);
    expect(controller.failure, ApkUpdateFailure.downgrade);
  });

  test('refuses a non-production package', () async {
    build(packageName: 'com.verseles.codewalk.v2preview');
    await controller.start(candidate);
    expect(controller.status, ApkUpdateStatus.failed);
    expect(controller.failure, ApkUpdateFailure.unsupported);
  });

  test('refuses a non-canonical asset URL', () async {
    final bad = UpdateCandidate(
      tag: candidate.tag,
      version: candidate.version,
      assetUrl: Uri.parse('https://example.com/codewalk-android-arm64.apk'),
    );
    await controller.start(bad);
    expect(controller.status, ApkUpdateStatus.failed);
    expect(controller.failure, ApkUpdateFailure.http);
    expect(fetcher.downloaded, isNull);
  });
}
