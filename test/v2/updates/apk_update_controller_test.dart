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

String manifest({String sha = _sha, int versionCode = 2}) => jsonEncode({
  'schema': 1,
  'tag': 'v2.0.0-beta.2',
  'version': '2.0.0-beta.2',
  'assets': {
    _asset: {
      'abi': 'arm64-v8a',
      'application_id': 'com.verseles.codewalk',
      'sha256': sha,
      'signer_sha256': codewalkAndroidSignerSha256,
      'size': 10,
      'version_code': versionCode,
      'version_name': '2.0.0-beta.2',
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
  ReleaseSourceTask start() => _EmptyTask();
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
  Future<void> delete(String path) async => files.remove(path);

  @override
  Future<bool> exists(String path) async => files.containsKey(path);

  @override
  Future<String?> sha256(String path) async => files[path];

  @override
  Future<void> cleanupStale() async {}
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
  }) async {
    if (failure case final error?) throw error;
    downloaded = uri;
    downloads++;
    store.files[partPath] = downloadSha;
    onProgress(downloadBytes, downloadBytes);
    return ApkDownloadResult(bytes: downloadBytes, sha256: downloadSha);
  }

  @override
  void close() {}

  @override
  void cancelActive() {}
}

class FakeInstaller implements ApkInstaller {
  String? openedPath;
  ApkInstallOutcome outcome = ApkInstallOutcome.opened;

  @override
  Future<ApkInstallOutcome> open(String path) async {
    openedPath = path;
    return outcome;
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
    checks = UpdateCheckController(
      source: EmptySource(),
      store: V2MetadataStore(backend: FakeMetadataBackend()),
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
    );
  }

  setUp(() {
    store = FakeStore();
    fetcher = FakeFetcher(store);
    installer = FakeInstaller();
    build();
  });

  tearDown(() {
    controller.dispose();
    checks.dispose();
  });

  test('downloads the exact asset and reaches ready', () async {
    await controller.start(candidate);
    expect(controller.status, ApkUpdateStatus.ready);
    expect(fetcher.downloaded, candidate.assetUrl);
    expect(installer.openedPath, isNull);
  });

  test('opens the installer and reports installerOpened', () async {
    foreground = true;
    await controller.start(candidate);
    expect(controller.status, ApkUpdateStatus.installerOpened);
    expect(installer.openedPath, isNotNull);
  });

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

  test('retries the installer without downloading again', () async {
    foreground = true;
    installer.outcome = ApkInstallOutcome.failed;
    await controller.start(candidate);
    expect(controller.status, ApkUpdateStatus.failed);
    expect(controller.failure, ApkUpdateFailure.installerFailed);
    installer.outcome = ApkInstallOutcome.opened;
    await controller.retry();
    expect(controller.status, ApkUpdateStatus.installerOpened);
    expect(fetcher.downloads, 1);
  });

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
