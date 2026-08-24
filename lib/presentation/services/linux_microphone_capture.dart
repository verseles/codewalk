// Conditional export: stub on web (no dart:io), process-backed Linux
// microphone capture on IO platforms. Mirrors the speech engine facade
// convention (e.g. speech_input_service_sherpa.dart).
export 'linux_microphone_capture_stub.dart'
    if (dart.library.io) 'linux_microphone_capture_io.dart';
