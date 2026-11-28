import '../../shared/voice/read_aloud.dart';
import 'speech_factory_stub.dart'
    if (dart.library.io) 'speech_factory_io.dart'
    as impl;

/// The synthesizer of [provider] on this platform; null where it cannot
/// run (the Web, and the device's engine for now).
SpeechSynthesizer? createSpeechSynthesizer(SpeechProvider provider) =>
    impl.createSpeechSynthesizer(provider);

/// Where read-aloud keys are kept on this platform.
SpeechKeyStore createSpeechKeyStore() => impl.createSpeechKeyStore();
