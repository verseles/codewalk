/// Shared size policy for large chat cache payloads (ADR-016).
///
/// A ~140MB string once stored in SharedPreferences killed the app on every
/// launch: the value crosses the platform channel inside
/// `StandardMessageCodec.encodeMessage`, which OOMs in engine code that Dart
/// cannot catch. Every layer below must refuse (never truncate, never detour)
/// payloads above these ceilings; snapshots are regenerable via SWR.
abstract final class ChatCachePayloadLimits {
  /// Maximum accepted size, in Dart string characters, for a single cache
  /// payload crossing the file store or the preferences fallback.
  static const int maxPayloadChars = 2 * 1024 * 1024;

  /// Maximum accepted size, in characters, for a single value kept in
  /// SharedPreferences (fallback path and legacy reads).
  static const int maxPrefsChars = 1 * 1024 * 1024;

  /// Aggregate budget, in characters, for the file store in-memory LRU.
  static const int maxMemoryCharsTotal = 2 * 1024 * 1024;

  /// Single entries above this size bypass the in-memory LRU (still
  /// persisted when within [maxPayloadChars]).
  static const int maxMemoryEntryChars = 512 * 1024;
}

abstract class ChatCachePayloadStore {
  Future<String?> read(String key);

  /// Writes [value] under [key], returning `true` when a disk write actually
  /// happened and `false` when the payload was already identical in memory.
  /// On desktop this lets callers skip downstream metadata writes (issue #152).
  Future<bool> write(String key, String value);

  Future<void> remove(String key);

  Future<void> clear();
}
