import 'sensevoice_model_manager.dart';
import 'speech_input_service.dart';

class SenseVoiceSpeechInputService implements SpeechInputService {
  SenseVoiceSpeechInputService(SenseVoiceModelManager manager);

  @override
  Future<bool> initialize() async => false;

  @override
  Future<void> startListening({
    required void Function(String text, bool isFinal) onResult,
    required void Function(String status) onStatus,
    required void Function() onError,
    Duration? pauseFor,
    String? localeId,
  }) async {
    onError();
  }

  @override
  Future<void> stopListening() async {}

  @override
  bool get isListening => false;

  @override
  bool get isAvailable => false;

  @override
  String? get unavailableReason =>
      'SenseVoice speech is unavailable on this platform.';

  @override
  String? get unavailableReasonKey => 'platformUnavailable';
}
