import '../../shared/media/message_image.dart';
import 'message_image_sink_stub.dart'
    if (dart.library.io) 'message_image_sink_io.dart'
    as impl;

MessageImageSink createMessageImageSink() => impl.createMessageImageSink();
