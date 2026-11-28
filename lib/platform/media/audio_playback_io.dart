import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

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

  // Where the player plays from a file (iOS, macOS, Linux): the one file of
  // the audio now loaded, removed once another takes its place or playback
  // stops, so audio never piles up in the temporary folder (#541).
  File? _file;
  int _files = 0;
  bool _swept = false;

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
      await _release();
      _emit(
        AudioPlaybackState(activeId: id, status: AudioPlaybackStatus.loading),
      );
      await player.play(await _source(bytes, mimeType));
    } on MissingPluginException {
      _unsupportedRuntime = true;
      _emit(
        AudioPlaybackState(activeId: id, status: AudioPlaybackStatus.error),
      );
    } on Object {
      _emit(
        AudioPlaybackState(activeId: id, status: AudioPlaybackStatus.error),
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

  /// The player's source for [bytes]: the bytes themselves where the
  /// platform takes them, else a file of this app's own, which audioplayers
  /// would otherwise write and never remove.
  Future<Source> _source(Uint8List bytes, String mimeType) async {
    if (kIsWeb || !(Platform.isIOS || Platform.isMacOS || Platform.isLinux)) {
      return BytesSource(bytes, mimeType: mimeType);
    }
    final folder = Directory(
      '${(await getTemporaryDirectory()).path}${Platform.pathSeparator}'
      'codewalk_audio',
    );
    await folder.create(recursive: true);
    if (!_swept) {
      // Left behind by a run that ended abruptly.
      _swept = true;
      try {
        await for (final entry in folder.list()) {
          if (entry is File) await entry.delete();
        }
      } on FileSystemException {
        // Swept next time.
      }
    }
    final extension = switch (mimeType) {
      'audio/wav' || 'audio/x-wav' => 'wav',
      'audio/ogg' => 'ogg',
      'audio/aac' => 'aac',
      'audio/mp4' || 'audio/m4a' => 'm4a',
      _ => 'mp3',
    };
    final file = File(
      '${folder.path}${Platform.pathSeparator}play-${_files++}.$extension',
    );
    await file.writeAsBytes(bytes, flush: true);
    _file = file;
    return DeviceFileSource(file.path, mimeType: mimeType);
  }

  Future<void> _release() async {
    final file = _file;
    _file = null;
    if (file == null) return;
    try {
      await file.delete();
    } on FileSystemException {
      // Gone already, or swept on the next run.
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
    await _release();
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
    await _release();
    await _updates.close();
  }
}
