import 'dart:async';

import 'package:codewalk/platform/storage/endpoint_credentials.dart';
import 'package:codewalk/platform/storage/metadata_store.dart';

final class FakeMetadataBackend implements MetadataBackend {
  final Map<String, Object> values = {};
  final List<String> writes = [];
  final List<String> removals = [];
  String? failWrite;
  bool failRead = false;
  bool failRemove = false;
  String? blockedKey;
  Completer<void>? entered;
  Completer<void>? release;

  @override
  Future<Object?> read(String key) async {
    if (failRead) throw StateError('read failure');
    return values[key];
  }

  @override
  Future<void> write(String key, Object value) async {
    writes.add(key);
    if (key == blockedKey && release != null) {
      if (!(entered?.isCompleted ?? true)) entered!.complete();
      await release!.future;
    }
    if (key == failWrite) throw StateError('write failure');
    values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    if (failRemove) throw StateError('remove failure');
    removals.add(key);
    values.remove(key);
  }
}

final class FakeLegacyReader implements LegacyStorageReader {
  FakeLegacyReader(this.values);
  final Map<String, Object> values;

  @override
  Future<Object?> read(String key) async => values[key];
}

final class FakeCredentialBackend implements EndpointCredentialBackend {
  final Map<String, String> values = {};
  int writes = 0;
  int removals = 0;
  bool failRead = false;
  bool failWrite = false;
  bool failRemove = false;

  @override
  Future<String?> read(String key) async {
    if (failRead) throw StateError('read failure');
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    if (failWrite) throw StateError('write failure');
    writes++;
    values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    if (failRemove) throw StateError('remove failure');
    removals++;
    values.remove(key);
  }
}
