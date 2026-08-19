import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

abstract class TtsAudioPlayer {
  Stream<void> get onComplete;
  Stream<Duration> get onDurationChanged;
  Stream<Duration> get onPositionChanged;
  Future<void> playBytes(Uint8List bytes, {String? mimeType});
  Future<void> pause();
  Future<void> resume();
  Future<void> stop();
  Future<void> dispose();
}

class AudioplayersTtsAudioPlayer implements TtsAudioPlayer {
  AudioplayersTtsAudioPlayer({AudioPlayer? player})
    : _player = player ?? AudioPlayer();

  final AudioPlayer _player;

  @override
  Stream<void> get onComplete => _player.onPlayerComplete.map((_) {});

  @override
  Stream<Duration> get onDurationChanged => _player.onDurationChanged;

  @override
  Stream<Duration> get onPositionChanged => _player.onPositionChanged;

  @override
  Future<void> playBytes(Uint8List bytes, {String? mimeType}) {
    return _player.play(BytesSource(bytes, mimeType: mimeType));
  }

  @override
  Future<void> pause() {
    return _player.pause();
  }

  @override
  Future<void> resume() {
    return _player.resume();
  }

  @override
  Future<void> stop() {
    return _player.stop();
  }

  @override
  Future<void> dispose() {
    return _player.dispose();
  }
}
