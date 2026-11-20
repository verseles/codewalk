import '../../shared/media/audio_playback.dart';
import 'audio_playback_stub.dart'
    if (dart.library.io) 'audio_playback_io.dart'
    as impl;

AudioPlaybackPort createAudioPlaybackPort() => impl.createAudioPlaybackPort();
