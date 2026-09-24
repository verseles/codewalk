import 'dart:typed_data';

import 'package:codewalk/presentation/services/offline_speech_segment_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ambient noise does not count as speech', () {
    final gate = OfflineSpeechSegmentGate();

    expect(
      gate.isSpeech(Float32List.fromList(<double>[0.01, 0.012, 0.009])),
      isFalse,
    );
    expect(gate.heardSpeech, isFalse);
  });

  test('speech after noise is detected and reset clears it', () {
    final gate = OfflineSpeechSegmentGate();
    gate.isSpeech(Float32List.fromList(<double>[0.01, 0.01]));

    expect(
      gate.isSpeech(Float32List.fromList(<double>[0.2, 0.25, 0.18])),
      isTrue,
    );
    expect(gate.heardSpeech, isTrue);

    gate.reset();
    expect(gate.heardSpeech, isFalse);
  });
}
