import 'package:open_filex/open_filex.dart';

import '../../shared/releases/apk_update.dart';

final class OpenFilexApkInstaller implements ApkInstaller {
  const OpenFilexApkInstaller();

  static const String _mimeType = 'application/vnd.android.package-archive';

  @override
  Future<ApkInstallOutcome> open(String path) async {
    try {
      final result = await OpenFilex.open(path, type: _mimeType);
      return switch (result.type) {
        ResultType.done => ApkInstallOutcome.opened,
        ResultType.noAppToOpen => ApkInstallOutcome.noInstaller,
        ResultType.permissionDenied => ApkInstallOutcome.denied,
        ResultType.fileNotFound => ApkInstallOutcome.fileMissing,
        ResultType.error => ApkInstallOutcome.failed,
      };
    } on Object {
      return ApkInstallOutcome.failed;
    }
  }
}

ApkInstaller createApkInstaller() => const OpenFilexApkInstaller();
