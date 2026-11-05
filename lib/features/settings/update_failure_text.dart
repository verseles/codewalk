import '../../shared/l10n/generated/v2_localizations.dart';
import '../../shared/releases/apk_update.dart';
import '../../shared/releases/linux_update.dart';

String apkUpdateFailureText(V2Localizations l, ApkUpdateFailure? failure) =>
    switch (failure) {
      ApkUpdateFailure.network ||
      ApkUpdateFailure.timeout => l.updatesFailureNetwork,
      ApkUpdateFailure.http => l.updatesFailureHttp,
      ApkUpdateFailure.storage => l.updatesFailureStorage,
      ApkUpdateFailure.checksumUnavailable ||
      ApkUpdateFailure.checksumMismatch ||
      ApkUpdateFailure.manifestInvalid => l.updatesFailureIntegrity,
      ApkUpdateFailure.downgrade => l.updatesFailureDowngrade,
      ApkUpdateFailure.unsupported => l.updatesFailureUnsupported,
      ApkUpdateFailure.installerDenied => l.updatesFailureInstallDenied,
      ApkUpdateFailure.installerUnavailable => l.updatesFailureInstallerMissing,
      ApkUpdateFailure.installerFailed => l.updatesFailureInstaller,
      ApkUpdateFailure.fileMissing => l.updatesFailureFileMissing,
      ApkUpdateFailure.tooLarge => l.updatesFailureTooLarge,
      ApkUpdateFailure.cancelled || null => l.updatesUpdateFailed,
    };

String linuxUpdateFailureText(V2Localizations l, LinuxUpdateFailure failure) =>
    switch (failure) {
      LinuxUpdateFailure.unavailable => l.updatesLinuxUnavailable,
      LinuxUpdateFailure.network => l.updatesFailureNetwork,
      LinuxUpdateFailure.http => l.updatesFailureHttp,
      LinuxUpdateFailure.tooLarge => l.updatesFailureTooLarge,
      LinuxUpdateFailure.integrity => l.updatesFailureIntegrity,
      LinuxUpdateFailure.storage => l.updatesFailureStorage,
      LinuxUpdateFailure.install => l.updatesFailureInstaller,
      LinuxUpdateFailure.restart => l.updatesRestartFailed,
    };
