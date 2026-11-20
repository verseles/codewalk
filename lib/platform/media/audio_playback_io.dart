import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

import '../../shared/media/audio_playback.dart';

AudioPlaybackPort createAudioPlaybackPort() => _NativeAudioPlayback();

/// Single active inline audio player backed by `audioplayers`.
final class _NativeAudioPlayback implements AudioPlaybackPort {
  _NativeAudioPlayback();

  AudioPlayer? _player;
  final _updates = StreamController<AudioPlaybackState>.broadcast();
  final _subscriptions = <StreamSubscription<Object?>>[];
  AudioPlaybackState _state = const AudioPlaybackState();
  bool _disposed = false;
  bool _unsupportedRuntime = false;

  @override
  bool get supported => !_unsupportedRuntime;

  @override
  AudioPlaybackState get current => _state;

  @override
  Stream<AudioPlaybackState> get updates => Stream.multi((listener) {
    listener.add(_state);
    final sub = _updates.stream.listen(listener.add, onDone: listener.close);
    listener.onCancel = sub.cancel;
  });

  AudioPlayer _ensurePlayer() {
    final existing = _player;
    if (existing != null) return existing;
    final player = AudioPlayer();
    _player = player;
    _subscriptions.addAll([
      player.onDurationChanged.listen((duration) {
        _emit(_state.copyWith(duration: duration));
      }),
      player.onPositionChanged.listen((position) {
        _emit(_state.copyWith(position: position));
      }),
      player.onPlayerStateChanged.listen((playerState) {
        if (_state.activeId == null) return;
        switch (playerState) {
          case PlayerState.playing:
            _emit(_state.copyWith(status: AudioPlaybackStatus.playing));
          case PlayerState.paused:
            _emit(_state.copyWith(status: AudioPlaybackStatus.paused));
          case PlayerState.stopped:
            _emit(
              _state.copyWith(
                status: AudioPlaybackStatus.idle,
                position: Duration.zero,
              ),
            );
          case PlayerState.completed:
            _emit(
              _state.copyWith(
                status: AudioPlaybackStatus.paused,
                position: _state.duration,
              ),
            );
          case PlayerState.disposed:
            break;
        }
      }),
    ]);
    return player;
  }

  void _emit(AudioPlaybackState next) {
    if (_disposed || next == _state) return;
    _state = next;
    _updates.add(next);
  }

  @override
  Future<void> togglePlay({
    required String id,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    if (_disposed || _unsupportedRuntime) return;
    try {
      final player = _ensurePlayer();
      if (_state.activeId == id) {
        if (_state.status == AudioPlaybackStatus.playing) {
          await player.pause();
          return;
        }
        if (_state.status == AudioPlaybackStatus.paused) {
          if (_state.duration > Duration.zero &&
              _state.position >= _state.duration) {
            await player.seek(Duration.zero);
          }
          await player.resume();
          return;
        }
      }
      await player.stop();
      _emit(
        AudioPlaybackState(
          activeId: id,
          status: AudioPlaybackStatus.loading,
        ),
      );
      await player.play(BytesSource(bytes, mimeType: mimeType));
    } on MissingPluginException {
      _unsupportedRuntime = true;
      _emit(
        AudioPlaybackState(
          activeId: id,
          status: AudioPlaybackStatus.error,
        ),
      );
    } on Object {
      _emit(
        AudioPlaybackState(
          activeId: id,
          status: AudioPlaybackStatus.error,
        ),
      );
    }
  }

  @override
  Future<void> seek(Duration position) async {
    if (_disposed || _player == null || _state.activeId == null) return;
    try {
      await _player!.seek(position);
      _emit(_state.copyWith(position: position));
    } on Object {
      // Ignore seek errors on unsupported streams.
    }
  }

  @override
  Future<void> stop() async {
    if (_disposed) return;
    try {
      await _player?.stop();
    } on Object {
      // Best-effort stop.
    }
    _emit(const AudioPlaybackState());
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();
    try {
      await _player?.dispose();
    } on Object {
      // Best-effort dispose.
    }
    _player = null;
    await _updates.close();
  }
}
