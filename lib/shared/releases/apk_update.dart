/// The lifecycle of one in-app APK update.
enum ApkUpdateStatus {
  idle,
  downloading,
  verifying,
  ready,
  handingOff,
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

/// The result of handing a verified APK to the system installer.
enum ApkInstallOutcome { opened, noInstaller, denied, fileMissing, failed }

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

/// Opens a verified local APK with the system installer.
abstract interface class ApkInstaller {
  Future<ApkInstallOutcome> open(String path);
}

/// Owns the temporary APK files used by the updater.
abstract interface class ApkFileStore {
  Future<String> partPath(String tag);

  Future<String> finalPath(String tag);

  Future<void> rename(String from, String to);

  Future<void> delete(String path);

  Future<bool> exists(String path);

  Future<String?> sha256(String path);

  /// Deletes partial transfers from previous runs, keeping verified APKs.
  Future<void> cleanupStale();
}
