import '../../shared/releases/linux_update.dart';
import 'linux_installer_stub.dart'
    if (dart.library.io) 'linux_installer_io.dart'
    as platform;

LinuxUpdateInstaller createLinuxInstaller() => platform.createLinuxInstaller();
