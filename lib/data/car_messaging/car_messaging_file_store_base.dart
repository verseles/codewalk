abstract class CarMessagingFileStore {
  Future<T> synchronized<T>(Future<T> Function() operation);
  Future<String?> read();
  Future<void> writeAtomically(String value);
  Future<void> delete();
}
