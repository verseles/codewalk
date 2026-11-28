import 'dart:typed_data';

import '../../shared/media/audio_playback.dart';

AudioPlaybackPort createAudioPlaybackPort() =>
    const _UnsupportedAudioPlayback();

final class _UnsupportedAudioPlayback implements AudioPlaybackPort {
  const _UnsupportedAudioPlayback();

  @override
  bool get supported => false;

  @override
  AudioPlaybackState get current => const AudioPlaybackState();

  @override
  Stream<AudioPlaybackState> get updates => const Stream.empty();

  @override
  Future<void> togglePlay({
    required String id,
    required Uint8List bytes,
    required String mimeType,
  }) async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> stop({String? id}) async {}

  @override
  Future<void> dispose() async {}
}
