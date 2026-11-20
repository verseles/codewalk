import '../../shared/media/location_fix_source.dart';
import 'location_fix_stub.dart'
    if (dart.library.io) 'location_fix_io.dart'
    as impl;

LocationFixSource createLocationFixSource() => impl.createLocationFixSource();
