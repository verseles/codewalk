import '../../shared/releases/apk_update.dart';
import 'apk_fetcher_stub.dart'
    if (dart.library.io) 'apk_fetcher_io.dart'
    as fetcher;
import 'apk_file_store_stub.dart'
    if (dart.library.io) 'apk_file_store_io.dart'
    as file_store;
import 'apk_installer_stub.dart'
    if (dart.library.io) 'apk_installer_io.dart'
    as installer;

ApkAssetFetcher createApkFetcher() => fetcher.createApkFetcher();

ApkInstaller createApkInstaller() => installer.createApkInstaller();

ApkFileStore createApkFileStore() => file_store.createApkFileStore();
