import '../../shared/releases/apk_update.dart';

ApkInstaller createApkInstaller() => const _UnsupportedInstaller();

final class _UnsupportedInstaller implements ApkInstaller {
  const _UnsupportedInstaller();

  @override
  Stream<ApkInstallSignal> get signals =>
      const Stream<ApkInstallSignal>.empty();

  @override
  Future<ApkInstallOutcome> open(
    String path, {
    int? versionCode,
    String? tag,
    String? notificationTitle,
    String? notificationBody,
    String? notificationChannel,
  }) async {
    return ApkInstallOutcome.noInstaller;
  }

  @override
  Future<void> clearPendingMarker() async {}
}
