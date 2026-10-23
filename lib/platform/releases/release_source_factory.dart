import '../../shared/releases/release_source.dart';
import '../../shared/releases/update_selector.dart';
import 'release_source_stub.dart'
    if (dart.library.io) 'release_source_io.dart'
    as platform;

ReleaseSource createReleaseSource() => platform.createReleaseSource();

ReleaseSource createUpdateSource() => platform.createUpdateSource();

UpdateTarget? currentUpdateTarget() => platform.currentUpdateTarget();
