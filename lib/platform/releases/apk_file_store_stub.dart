import '../../shared/releases/apk_update.dart';

ApkFileStore createApkFileStore() => const _UnsupportedFileStore();

final class _UnsupportedFileStore implements ApkFileStore {
  const _UnsupportedFileStore();

  @override
  Future<String> partPath(String tag) async => '';

  @override
  Future<String> finalPath(String tag) async => '';

  @override
  Future<void> rename(String from, String to) async {}

  @override
  Future<void> delete(String path) async {}

  @override
  Future<bool> exists(String path) async => false;

  @override
  Future<String?> sha256(String path) async => null;

  @override
  Future<void> cleanupStale() async {}
}
