abstract class ChatCachePayloadStore {
  Future<String?> read(String key);

  /// Writes [value] under [key], returning `true` when a disk write actually
  /// happened and `false` when the payload was already identical in memory.
  /// On desktop this lets callers skip downstream metadata writes (issue #152).
  Future<bool> write(String key, String value);

  Future<void> remove(String key);

  Future<void> clear();
}
