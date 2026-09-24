import 'dart:typed_data';

class OfflineSpeechSegmentGate {
  static const trailingSilence = Duration(milliseconds: 800);

  double _noise = 0.012;
  bool heardSpeech = false;

  void reset() {
    heardSpeech = false;
  }

  bool isSpeech(Float32List samples) {
    if (samples.isEmpty) {
      return false;
    }
    var sum = 0.0;
    for (final sample in samples) {
      sum += sample.abs();
    }
    final mean = sum / samples.length;
    const speechFloor = 0.06;
    final speech = mean >= speechFloor && mean >= _noise * 3;
    if (!speech && !heardSpeech && mean < speechFloor) {
      final next = (_noise * 0.85) + (mean * 0.15);
      _noise = next > 0.02 ? 0.02 : next;
    }
    if (speech) {
      heardSpeech = true;
    }
    return speech;
  }
}
