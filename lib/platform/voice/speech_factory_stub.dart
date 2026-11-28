import '../../shared/voice/memory_speech_keys.dart';
import '../../shared/voice/read_aloud.dart';

SpeechSynthesizer? createSpeechSynthesizer(SpeechProvider provider) => null;

SpeechKeyStore createSpeechKeyStore() => MemorySpeechKeys();
