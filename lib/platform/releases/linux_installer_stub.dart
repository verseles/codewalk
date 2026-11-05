import '../../shared/releases/linux_update.dart';
import '../../shared/releases/update_selector.dart';

final class UnsupportedLinuxInstaller implements LinuxUpdateInstaller {
  @override
  Future<bool> available() async => false;
  @override
  Future<void> install(
    UpdateCandidate candidate, {
    required void Function(LinuxUpdateStatus, double) onProgress,
  }) async => throw const LinuxUpdateException(LinuxUpdateFailure.unavailable);
  @override
  Future<bool> restart() async => false;
  @override
  void close() {}
}

LinuxUpdateInstaller createLinuxInstaller() => UnsupportedLinuxInstaller();
