import '../../shared/releases/apk_update.dart';

ApkAssetFetcher createApkFetcher() => const _UnsupportedFetcher();

final class _UnsupportedFetcher implements ApkAssetFetcher {
  const _UnsupportedFetcher();

  @override
  Future<String> fetchText(Uri uri, {int maxBytes = 256 * 1024}) async {
    throw const ApkDownloadException(ApkUpdateFailure.unsupported);
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
    throw const ApkDownloadException(ApkUpdateFailure.unsupported);
  }

  @override
  void close() {}

  @override
  void cancelActive() {}
}
