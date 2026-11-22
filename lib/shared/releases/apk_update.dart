/// The lifecycle of one in-app APK update.
enum ApkUpdateStatus {
  idle,
  downloading,
  verifying,
  ready,
  handingOff,
  installing,
  installerOpened,
  failed,
}

/// A typed reason for an update failure.
enum ApkUpdateFailure {
  network,
  timeout,
  http,
  tooLarge,
  storage,
  checksumUnavailable,
  checksumMismatch,
  manifestInvalid,
  downgrade,
  installerUnavailable,
  installerDenied,
  installerFailed,
  fileMissing,
  unsupported,
  cancelled,
}

/// The streamed bytes and digest of a completed APK transfer.
final class ApkDownloadResult {
  const ApkDownloadResult({required this.bytes, required this.sha256});

  final int bytes;
  final String sha256;
}

/// A typed download failure raised by [ApkAssetFetcher].
final class ApkDownloadException implements Exception {
  const ApkDownloadException(this.failure, [this.cause]);

  final ApkUpdateFailure failure;
  final Object? cause;

  @override
  String toString() => 'ApkDownloadException($failure, $cause)';
}

/// The immediate result of committing or handing a verified APK to the system
/// installer.
enum ApkInstallOutcome {
  opened,
  committed,
  noInstaller,
  denied,
  fileMissing,
  storage,
  failed,
}

/// Asynchronous post-commit signals emitted by the native Android
/// `PackageInstaller` session callback receiver.
enum ApkInstallSignal { confirmation, aborted, storage, failed, succeeded }

/// Metadata sidecar persisted next to a verified cached APK (`<apk>.json`).
final class ApkCachedRecord {
  const ApkCachedRecord({
    required this.tag,
    required this.version,
    required this.versionCode,
    required this.assetUrl,
    required this.sha256,
    required this.size,
    required this.path,
    required this.savedAt,
  });

  final String tag;
  final String version;
  final int versionCode;
  final Uri assetUrl;
  final String sha256;
  final int size;
  final String path;
  final DateTime savedAt;

  Map<String, Object?> toJson() => <String, Object?>{
    'schema': 1,
    'tag': tag,
    'version': version,
    'version_code': versionCode,
    'asset_url': assetUrl.toString(),
    'sha256': sha256,
    'size': size,
    'saved_at': savedAt.toUtc().toIso8601String(),
  };

  static ApkCachedRecord? tryParse(Object? raw, {required String path}) {
    if (raw is! Map) return null;
    final schema = raw['schema'];
    final tag = raw['tag'];
    final version = raw['version'];
    final versionCode = raw['version_code'];
    final assetUrlRaw = raw['asset_url'];
    final sha256 = raw['sha256'];
    final size = raw['size'];
    final savedAtRaw = raw['saved_at'];
    if (schema != 1 ||
        tag is! String ||
        tag.isEmpty ||
        version is! String ||
        version.isEmpty ||
        versionCode is! int ||
        versionCode <= 0 ||
        assetUrlRaw is! String ||
        sha256 is! String ||
        sha256.length != 64 ||
        size is! int ||
        size <= 0) {
      return null;
    }
    final assetUrl = Uri.tryParse(assetUrlRaw);
    if (assetUrl == null) return null;
    final savedAt =
        (savedAtRaw is String ? DateTime.tryParse(savedAtRaw) : null)
            ?.toUtc() ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    return ApkCachedRecord(
      tag: tag,
      version: version,
      versionCode: versionCode,
      assetUrl: assetUrl,
      sha256: sha256,
      size: size,
      path: path,
      savedAt: savedAt,
    );
  }
}

/// Reads the small integrity files and streams the APK to disk.
abstract interface class ApkAssetFetcher {
  Future<String> fetchText(Uri uri, {int maxBytes = 256 * 1024});

  Future<ApkDownloadResult> download(
    Uri uri,
    String partPath, {
    required void Function(int received, int? total) onProgress,
    required bool Function() isCancelled,
    int? expectedBytes,
    String? expectedSha256,
  });

  void close();

  /// Aborts the transfer currently in flight, if any.
  void cancelActive();
}

/// Installs a verified local APK through a native `PackageInstaller` session.
abstract interface class ApkInstaller {
  Future<ApkInstallOutcome> open(
    String path, {
    int? versionCode,
    String? tag,
    String? notificationTitle,
    String? notificationBody,
    String? notificationChannel,
  });

  Stream<ApkInstallSignal> get signals;

  Future<void> clearPendingMarker();
}

/// Owns the persistent and partial APK files used by the updater.
abstract interface class ApkFileStore {
  Future<String> partPath(String tag);

  Future<String> finalPath(String tag);

  Future<void> rename(String from, String to);

  Future<void> delete(String path);

  Future<bool> exists(String path);

  Future<String?> sha256(String path);

  Future<void> writeSidecar(ApkCachedRecord record);

  Future<ApkCachedRecord?> restoreCached({required int installedBuildNumber});

  /// Deletes partial transfers older than 24 hours and obsolete or unverified
  /// APKs, keeping a still-newer verified cached APK.
  Future<void> cleanupStale({int? installedBuildNumber});
}
