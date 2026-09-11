import 'dart:convert';
import 'dart:io';

import 'package:codewalk/data/cache/chat_cache_payload_store_io.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('codewalk-cache-test.');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  FileBackedChatCachePayloadStore newStore({
    int? maxWritableChars,
    int? maxReadableBytes,
    int? maxMemoryCharsTotal,
    int? maxMemoryEntryChars,
  }) {
    return FileBackedChatCachePayloadStore(
      testDirectory: tempDir,
      maxWritableChars: maxWritableChars ?? 64,
      maxReadableBytes: maxReadableBytes ?? 64,
      maxMemoryCharsTotal: maxMemoryCharsTotal ?? 64,
      maxMemoryEntryChars: maxMemoryEntryChars ?? 64,
    );
  }

  test('roundtrips small payloads through disk and memory', () async {
    final store = newStore();

    expect(await store.write('k1', 'hello'), isTrue);
    expect(await store.read('k1'), 'hello');
    // Identical rewrite is a no-op for issue #152.
    expect(await store.write('k1', 'hello'), isFalse);

    await store.remove('k1');
    expect(await store.read('k1'), isNull);
  });

  test('rejects oversized writes without creating files', () async {
    final store = newStore(maxWritableChars: 16);

    expect(await store.write('big', 'x' * 17), isFalse);
    expect(tempDir.listSync(), isEmpty);
    expect(await store.read('big'), isNull);
  });

  test('deletes oversized files instead of reading them', () async {
    final writer = newStore(maxReadableBytes: 16);
    expect(await writer.write('small', 'tiny'), isTrue);

    // Simulate a legacy giant payload already on disk: bypass write() by
    // dropping a big file where the hashed cache file would live.
    final cachedFile = tempDir
        .listSync()
        .whereType<File>()
        .firstWhere((file) => file.path.endsWith('.json'));
    await cachedFile.writeAsString('y' * 1024, flush: true);

    // A fresh instance has an empty memory cache, forcing the disk path.
    final reader = newStore(maxReadableBytes: 16);
    expect(await reader.read('small'), isNull);
    expect(tempDir.listSync(), isEmpty);
  });

  test('treats a corrupt cache file as a miss and deletes it', () async {
    final writer = newStore(maxReadableBytes: 1024);
    expect(await writer.write('k', 'payload'), isTrue);

    final cachedFile = tempDir
        .listSync()
        .whereType<File>()
        .firstWhere((file) => file.path.endsWith('.json'));
    // A NUL byte is invalid UTF-8: readAsString throws FormatException.
    await cachedFile.writeAsBytes(<int>[0x00, 0x00, 0xFF], flush: true);

    final reader = newStore(maxReadableBytes: 1024);
    expect(await reader.read('k'), isNull);
    expect(tempDir.listSync(), isEmpty);
  });

  test('evicts memory entries by byte budget while keeping disk copies',
      () async {
    final store = newStore(
      maxReadableBytes: 1024,
      maxMemoryCharsTotal: 20,
      maxMemoryEntryChars: 1024,
    );

    expect(await store.write('a', '1' * 8), isTrue);
    expect(await store.write('b', '2' * 8), isTrue);
    expect(await store.write('c', '3' * 8), isTrue);

    // 24 chars were stored under a 20-char budget: the oldest entry must
    // have been evicted from memory — but disk copies survive.
    expect(store.debugMemoryChars, lessThanOrEqualTo(20));
    expect(await store.read('a'), '1' * 8);
    expect(await store.read('b'), '2' * 8);
    expect(await store.read('c'), '3' * 8);
    expect(tempDir.listSync().whereType<File>(), hasLength(3));
  });

  test('skips oversized single entries in memory but persists them', () async {
    final store = newStore(
      maxWritableChars: 1024,
      maxReadableBytes: 1024,
      maxMemoryCharsTotal: 1024,
      maxMemoryEntryChars: 8,
    );

    expect(await store.write('big-single', 'z' * 16), isTrue);
    expect(store.debugMemoryChars, 0);
    expect(await store.read('big-single'), 'z' * 16);
  });

  test('updating an entry beyond the memory cap serves the new value',
      () async {
    final store = newStore(
      maxWritableChars: 1024,
      maxReadableBytes: 1024,
      maxMemoryCharsTotal: 1024,
      maxMemoryEntryChars: 8,
    );

    expect(await store.write('k', '12345678'), isTrue);
    expect(await store.read('k'), '12345678');
    // 16 chars exceeds the 8-char memory cap: the stale smaller value must
    // be evicted so the read below serves the updated disk payload.
    expect(await store.write('k', 'Z' * 16), isTrue);
    expect(await store.read('k'), 'Z' * 16);
  });

  test('leaves no temp files behind after a successful write', () async {
    final store = newStore(maxWritableChars: 1024, maxReadableBytes: 1024);
    expect(await store.write('k', 'value'), isTrue);

    final names = tempDir.listSync().map((e) => e.path).toList();
    expect(names.where((p) => p.endsWith('.json')), hasLength(1));
    expect(names.where((p) => p.contains('.tmp')), isEmpty);
  });

  test('failed write rolls back memory and cleans the temp file', () async {
    final store = newStore(maxWritableChars: 1024, maxReadableBytes: 1024);
    // Place a directory at the canonical hashed path so the atomic rename
    // cannot replace it: the write must fail, roll back the LRU entry and
    // leave no temp sibling behind.
    final digest = sha1.convert(utf8.encode('k')).toString();
    Directory('${tempDir.path}/$digest.json').createSync(recursive: true);

    await expectLater(store.write('k', 'never-persisted'), throwsA(anything));

    expect(store.debugMemoryChars, 0);
    expect(
      tempDir.listSync().where((e) => e.path.contains('.tmp')),
      isEmpty,
    );
    expect(await store.read('k'), isNull);
  });
}
