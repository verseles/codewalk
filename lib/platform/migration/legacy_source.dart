import '../storage/metadata_store.dart';

enum LegacyReadFailure { unavailable, malformed, oversized }

/// Diagnostics contain no source values, paths, credentials or native causes.
final class LegacyReadException implements Exception {
  const LegacyReadException(this.failure);
  final LegacyReadFailure failure;

  @override
  String toString() => 'LegacyReadException(${failure.name})';
}

abstract interface class LegacyPreferencesReader
    implements LegacyStorageReader {
  Future<Set<String>> keys();
}

abstract interface class LegacySecureReader {
  Future<String?> read(String key);
}

/// Reads original SHA-1-keyed v1 files without deleting malformed/large files.
abstract interface class LegacyPayloadReader {
  Future<String?> read(String logicalKey);
  Future<Set<String>> unclaimedFiles(Set<String> knownLogicalKeys);
}

final class EmptyLegacyPayloadReader implements LegacyPayloadReader {
  const EmptyLegacyPayloadReader();

  @override
  Future<String?> read(String logicalKey) async => null;

  @override
  Future<Set<String>> unclaimedFiles(Set<String> knownLogicalKeys) async => {};
}

/// Read-only boundaries, never retained legacy AppLocalDataSource getters.
final class LegacySource {
  LegacySource({
    required this.preferences,
    this.secure,
    this.payloads = const EmptyLegacyPayloadReader(),
    Set<String> knownPayloadKeys = const {},
  }) : knownPayloadKeys = Set.unmodifiable(knownPayloadKeys);

  final LegacyPreferencesReader preferences;
  final LegacySecureReader? secure;
  final LegacyPayloadReader payloads;

  /// Locator keys supplied by a legacy index/snapshot, never v2 session truth.
  final Set<String> knownPayloadKeys;
}
