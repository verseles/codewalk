import 'parakeet_model_manager.dart';
import 'speech_input_service.dart';

class ParakeetSpeechInputService implements SpeechInputService {
  ParakeetSpeechInputService(ParakeetModelManager manager);

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
      'Parakeet speech is unavailable on this platform.';

  @override
  String? get unavailableReasonKey => 'platformUnavailable';
}
