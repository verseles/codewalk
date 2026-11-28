import '../../shared/voice/read_aloud.dart';
import 'cloud_speech_io.dart';
import 'edge_speech_io.dart';
import 'speech_key_store_io.dart';

final _synthesizers = <SpeechProvider, SpeechSynthesizer>{};

SpeechSynthesizer? createSpeechSynthesizer(
  SpeechProvider provider,
) => switch (provider) {
  SpeechProvider.edge => _synthesizers.putIfAbsent(provider, EdgeSpeech.new),
  SpeechProvider.openAi || SpeechProvider.elevenLabs || SpeechProvider.nim =>
    _synthesizers.putIfAbsent(provider, () => CloudSpeech(provider)),
  // The device's engine returns with a plugin that builds everywhere.
  SpeechProvider.system => null,
};

SpeechKeyStore createSpeechKeyStore() => SecureSpeechKeys();
