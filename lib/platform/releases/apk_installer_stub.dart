import '../../shared/releases/apk_update.dart';

ApkInstaller createApkInstaller() => const _UnsupportedInstaller();

final class _UnsupportedInstaller implements ApkInstaller {
  const _UnsupportedInstaller();

  @override
  Future<ApkInstallOutcome> open(String path) async {
    return ApkInstallOutcome.noInstaller;
  }
}
