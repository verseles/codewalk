import 'dart:convert';

import 'package:codewalk/platform/migration/legacy_source.dart';
import 'package:codewalk/platform/storage/endpoint_credentials.dart';
import 'package:codewalk/platform/storage/metadata_store.dart';
import 'package:codewalk/platform/storage/payload_store.dart';

/// Raw read-only sources: a byte-preserving snapshot can be compared after
/// every failure or retry without exercising a retained v1 getter.
final class FakeLegacyPreferencesReader implements LegacyPreferencesReader {
  FakeLegacyPreferencesReader([Map<String, Object> initial = const {}])
    : values = {...initial};

  final Map<String, Object> values;
  final Map<String, int> reads = {};
  final Set<String> failReads = {};
  int keyReads = 0;
  bool failKeys = false;

  String get snapshot => jsonEncode(values);

  @override
  Future<Object?> read(String key) async {
    reads[key] = (reads[key] ?? 0) + 1;
    if (failReads.contains(key)) {
      throw const LegacyReadException(LegacyReadFailure.unavailable);
    }
    return values[key];
  }

  @override
  Future<Set<String>> keys() async {
    keyReads++;
    if (failKeys) {
      throw const LegacyReadException(LegacyReadFailure.unavailable);
    }
    return {...values.keys};
  }
}

final class FakeLegacySecureReader implements LegacySecureReader {
  FakeLegacySecureReader([Map<String, String> initial = const {}])
    : values = {...initial};

  final Map<String, String> values;
  final Map<String, int> reads = {};
  final Set<String> failReads = {};

  String get snapshot => jsonEncode(values);

  @override
  Future<String?> read(String key) async {
    reads[key] = (reads[key] ?? 0) + 1;
    if (failReads.contains(key)) {
      throw const LegacyReadException(LegacyReadFailure.unavailable);
    }
    return values[key];
  }
}

final class FakeLegacyPayloadReader implements LegacyPayloadReader {
  FakeLegacyPayloadReader([Map<String, String> initial = const {}])
    : values = {...initial};

  final Map<String, String> values;
  final Map<String, int> reads = {};
  final Map<String, LegacyReadFailure> failures = {};
  final Set<String> orphanFiles = {};
  Set<String>? lastClaimedKeys;

  String get snapshot => jsonEncode(values);

  @override
  Future<String?> read(String logicalKey) async {
    reads[logicalKey] = (reads[logicalKey] ?? 0) + 1;
    final failure = failures[logicalKey];
    if (failure != null) throw LegacyReadException(failure);
    return values[logicalKey];
  }

  @override
  Future<Set<String>> unclaimedFiles(Set<String> knownLogicalKeys) async {
    lastClaimedKeys = {...knownLogicalKeys};
    return {...orphanFiles};
  }
}

/// A backend reused across importer instances models durable state. Failures
/// happen before a backend write commits, unlike afterCheckpoint interruptions.
final class FakeMigrationMetadataBackend implements MetadataBackend {
  final Map<String, Object> values = {};
  final List<String> reads = [];
  final List<String> writeAttempts = [];
  final List<String> writes = [];
  final List<String> removals = [];
  final Set<String> failReads = {};
  String? failWrite;

  @override
  Future<Object?> read(String key) async {
    reads.add(key);
    if (failReads.contains(key)) throw StateError('destination unavailable');
    return values[key];
  }

  @override
  Future<void> write(String key, Object value) async {
    writeAttempts.add(key);
    if (key == failWrite) throw StateError('destination unavailable');
    values[key] = value;
    writes.add(key);
  }

  @override
  Future<void> remove(String key) async {
    removals.add(key);
    values.remove(key);
  }
}

final class FakeMigrationPayloadStore implements PayloadStore {
  final Map<String, String> values = {};
  final List<String> reads = [];
  final List<String> writeAttempts = [];
  final List<String> writes = [];
  final List<String> removals = [];
  final Set<String> refusedKeys = {};
  final Set<String> failedKeys = {};

  @override
  Future<String?> read(String key) async {
    reads.add(key);
    return values[key];
  }

  @override
  Future<PayloadWriteResult> write(String key, String value) async {
    writeAttempts.add(key);
    if (failedKeys.contains(key)) throw StateError('destination unavailable');
    if (refusedKeys.contains(key)) return PayloadWriteResult.refusedOversized;
    if (values[key] == value) return PayloadWriteResult.unchanged;
    values[key] = value;
    writes.add(key);
    return PayloadWriteResult.written;
  }

  @override
  Future<void> remove(String key) async {
    removals.add(key);
    values.remove(key);
  }
}

final class FakeMigrationCredentialBackend
    implements EndpointCredentialBackend {
  final Map<String, String> values = {};
  final List<String> reads = [];
  final List<String> writes = [];
  final List<String> removals = [];
  bool failWrite = false;

  @override
  Future<String?> read(String key) async {
    reads.add(key);
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    if (failWrite) throw StateError('secure destination unavailable');
    values[key] = value;
    writes.add(key);
  }

  @override
  Future<void> remove(String key) async {
    removals.add(key);
    values.remove(key);
  }
}
