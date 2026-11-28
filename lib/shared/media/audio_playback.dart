import 'dart:typed_data';

enum AudioPlaybackStatus { idle, loading, playing, paused, error }

/// Snapshot of the single active inline audio player across timelines.
final class AudioPlaybackState {
  const AudioPlaybackState({
    this.activeId,
    this.status = AudioPlaybackStatus.idle,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.completed = false,
  });

  final String? activeId;
  final AudioPlaybackStatus status;
  final Duration position;
  final Duration duration;

  /// The audio played to its end: it rests paused there, even where the
  /// platform reports no duration.
  final bool completed;

  bool isActive(String id) => activeId == id;

  AudioPlaybackState copyWith({
    String? activeId,
    bool clearActiveId = false,
    AudioPlaybackStatus? status,
    Duration? position,
    Duration? duration,
    bool? completed,
  }) => AudioPlaybackState(
    activeId: clearActiveId ? null : (activeId ?? this.activeId),
    status: status ?? this.status,
    position: position ?? this.position,
    duration: duration ?? this.duration,
    completed: completed ?? false,
  );

  @override
  bool operator ==(Object other) =>
      other is AudioPlaybackState &&
      other.activeId == activeId &&
      other.status == status &&
      other.position == position &&
      other.duration == duration &&
      other.completed == completed;

  @override
  int get hashCode =>
      Object.hash(activeId, status, position, duration, completed);
}

/// Platform-isolated inline audio player port. Only one attachment plays at a
/// time; starting another stops the previous one cleanly.
abstract interface class AudioPlaybackPort {
  bool get supported;
  AudioPlaybackState get current;
  Stream<AudioPlaybackState> get updates;

  Future<void> togglePlay({
    required String id,
    required Uint8List bytes,
    required String mimeType,
  });

  Future<void> seek(Duration position);
  Future<void> stop();
  Future<void> dispose();
}
