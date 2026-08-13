import 'car_messaging_file_store_base.dart';

CarMessagingFileStore createCarMessagingFileStore() =>
    _UnsupportedCarMessagingFileStore();

class _UnsupportedCarMessagingFileStore implements CarMessagingFileStore {
  @override
  Future<T> synchronized<T>(Future<T> Function() operation) => operation();

  @override
  Future<String?> read() async => null;

  @override
  Future<void> writeAtomically(String value) {
    throw UnsupportedError('Encrypted car messaging is unavailable.');
  }

  @override
  Future<void> delete() async {}
}
