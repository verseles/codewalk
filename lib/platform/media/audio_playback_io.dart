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
  // The folder is this run's own, readable by this user only.
  File? _file;
  int _files = 0;
  Future<Directory>? _folder;

  // The id of a start still under way, which a stop for another id spares.
  String? _starting;

  // Each start, stop or disposal supersedes the starts still under way.
  int _op = 0;

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
                completed: true,
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
    final op = ++_op;
    File? mine;
    _starting = id;
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
      if (op != _op) return;
      _emit(
        AudioPlaybackState(activeId: id, status: AudioPlaybackStatus.loading),
      );
      final (source, file) = await _source(bytes, mimeType);
      mine = file;
      // Stopped, replaced or disposed meanwhile: this audio never plays.
      if (op != _op || _disposed) {
        await _delete(file);
        return;
      }
      _file = file;
      await player.play(source);
    } on MissingPluginException {
      _unsupportedRuntime = true;
      await _failed(op, id, mine);
    } on Object {
      // Audio that cannot play leaves no file behind.
      await _failed(op, id, mine);
    } finally {
      if (op == _op) _starting = null;
    }
  }

  /// Reports start [op] of [id] as failed, unless a later start or stop
  /// owns the player by then: its state and file are left alone.
  Future<void> _failed(int op, String id, File? mine) async {
    if (op != _op) return _delete(mine);
    await _release();
    if (op != _op) return;
    _emit(AudioPlaybackState(activeId: id, status: AudioPlaybackStatus.error));
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
  Future<(Source, File?)> _source(Uint8List bytes, String mimeType) async {
    if (kIsWeb || !(Platform.isIOS || Platform.isMacOS || Platform.isLinux)) {
      return (BytesSource(bytes, mimeType: mimeType), null);
    }
    // One folder per run, even for starts that overlap; made again if the
    // system removed it meanwhile.
    final creating = _folder ??= _createFolder();
    var folder = await _awaitFolder(creating);
    if (!folder.existsSync()) {
      // Starts that find it gone together share one new folder.
      if (identical(_folder, creating)) _folder = _createFolder();
      folder = await _awaitFolder(_folder ??= _createFolder());
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
    return (DeviceFileSource(file.path, mimeType: mimeType), file);
  }

  /// [creating]'s folder; a creation that fails is tried again next time.
  Future<Directory> _awaitFolder(Future<Directory> creating) async {
    try {
      return await creating;
    } on Object {
      if (identical(_folder, creating)) _folder = null;
      rethrow;
    }
  }

  /// This run's folder, made by the system for this user alone; folders of
  /// runs that ended abruptly over a day ago go.
  Future<Directory> _createFolder() async {
    final temp = await getTemporaryDirectory();
    try {
      final now = DateTime.now();
      await for (final entry in temp.list()) {
        final name = entry.uri.pathSegments.where((s) => s.isNotEmpty).last;
        if (entry is! Directory || !name.startsWith('codewalk_audio_')) {
          continue;
        }
        try {
          final changed = entry.statSync().modified;
          if (now.difference(changed) > const Duration(days: 1)) {
            await entry.delete(recursive: true);
          }
        } on FileSystemException {
          // Another user's, or in use: left alone.
        }
      }
    } on FileSystemException {
      // Swept another time.
    }
    return temp.createTemp('codewalk_audio_');
  }

  Future<void> _release() {
    final file = _file;
    _file = null;
    return _delete(file);
  }

  static Future<void> _delete(File? file) async {
    if (file == null) return;
    try {
      await file.delete();
    } on FileSystemException {
      // Gone already, or removed with the folder.
    }
  }

  @override
  Future<void> stop({String? id}) async {
    if (_disposed) return;
    // Only that audio: the one starting, or the one playing when nothing
    // starts in its place.
    if (id != null &&
        _starting != id &&
        (_starting != null || _state.activeId != id)) {
      return;
    }
    final op = ++_op;
    _starting = null;
    try {
      await _player?.stop();
    } on Object {
      // Best-effort stop.
    }
    // A start made meanwhile owns the player and its file.
    if (op != _op) return;
    await _release();
    if (op != _op) return;
    _emit(const AudioPlaybackState());
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _op++;
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
    try {
      await (await _folder)?.delete(recursive: true);
    } on Object {
      // Never made, or swept by a later run.
    }
    await _updates.close();
  }
}
