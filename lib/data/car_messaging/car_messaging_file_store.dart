import 'car_messaging_file_store_base.dart';
import 'car_messaging_file_store_stub.dart'
    if (dart.library.io) 'car_messaging_file_store_io.dart'
    as implementation;

export 'car_messaging_file_store_base.dart';

CarMessagingFileStore createCarMessagingFileStore() {
  return implementation.createCarMessagingFileStore();
}
