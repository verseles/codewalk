@TestOn('vm')
library;

// Exercise real asynchronous I/O and its failure/ordering boundaries.
// ignore_for_file: avoid_slow_async_io

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:codewalk/platform/storage/metadata_store.dart';
import 'package:codewalk/platform/storage/payload_io.dart';
import 'package:codewalk/platform/storage/payload_store.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import 'storage_fakes.dart';

Future<void> ready() async {}

final class FakeFiles implements PayloadFileBackend {
  final Map<String, Uint8List> values = {};
  int replacements = 0;
  int removals = 0;
  int reads = 0;
  bool failRead = false;
  bool failWrite = false;
  bool failRemove = false;
  Completer<void>? entered;
  Completer<void>? release;

  @override
  Future<Uint8List?> read(String key, {required int maxBytes}) async {
    reads++;
    if (failRead) throw const FileSystemException('read failure');
    return values[key];
  }

  @override
  Future<void> replace(String key, String value) async {
    if (release != null) {
      if (!(entered?.isCompleted ?? true)) entered!.complete();
      await release!.future;
    }
    if (failWrite) throw const FileSystemException('write failure');
    replacements++;
    values[key] = Uint8List.fromList(utf8.encode(value));
  }

  @override
  Future<void> remove(String key) async {
    if (failRemove) throw const FileSystemException('remove failure');
    removals++;
    values.remove(key);
  }
}

/// Exercises the real backend with a stale stat and injected native failures.
final class FaultFile implements File {
  FaultFile(this.actual, this.mode);
  final File actual;
  final String mode;
  int? requestedEnd;

  @override
  String get path => actual.path;
  @override
  Directory get parent => actual.parent;
  @override
  Future<bool> exists() => actual.exists();
  @override
  Future<int> length() {
    if (mode == 'stat') throw const FileSystemException('stat failure');
    return mode == 'grow' ? Future.value(1) : actual.length();
  }

  @override
  Stream<List<int>> openRead([int? start, int? end]) {
    requestedEnd = end;
    if (mode == 'read') {
      return Stream.error(const FileSystemException('read failure'));
    }
    return actual.openRead(start, end);
  }

  @override
  Future<File> writeAsString(
    String contents, {
    FileMode mode = FileMode.write,
    Encoding encoding = utf8,
    bool flush = false,
  }) {
    if (this.mode == 'write') throw const FileSystemException('write failure');
    return actual.writeAsString(
      contents,
      mode: mode,
      encoding: encoding,
      flush: flush,
    );
  }

  @override
  Future<File> rename(String newPath) {
    if (mode == 'rename') throw const FileSystemException('rename failure');
    return actual.rename(newPath);
  }

  @override
  Future<FileSystemEntity> delete({bool recursive = false}) {
    if (mode == 'remove') throw const FileSystemException('remove failure');
    return actual.delete(recursive: recursive);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('cw2_payload_test_');
  });
  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });
  NativePayloadFileBackend native({File Function(String)? fileFactory}) =>
      NativePayloadFileBackend(
        directory: () async => directory,
        fileFactory: fileFactory,
      );
  File pathFor(String key) =>
      File('${directory.path}/${sha256.convert(utf8.encode(key))}.json');

  test(
    'real native atomic replacement, restart, remove and namespace',
    () async {
      final store = FilePayloadStore(beforeMutation: ready, backend: native());
      await store.write('cw2.snapshot', '旧🙂');
      expect(await pathFor('cw2.snapshot').readAsString(), '旧🙂');
      await store.write('cw2.snapshot', 'new');
      final restarted = FilePayloadStore(
        beforeMutation: ready,
        backend: native(),
      );
      expect(await restarted.read('cw2.snapshot'), 'new');
      expect(await directory.list().length, 1);
      await restarted.remove('cw2.snapshot');
      expect(await pathFor('cw2.snapshot').exists(), isFalse);
      expect(() => store.read('cached_sessions'), throwsArgumentError);
      expect(await directory.list().length, 0);
    },
  );

  test(
    'UTF-16 and UTF-8 limits roundtrip exact multibyte and refuse overage',
    () async {
      final backend = FakeFiles();
      final store = FilePayloadStore(
        beforeMutation: ready,
        backend: backend,
        maxPayloadChars: 4,
        maxReadableBytes: 16,
        maxMemoryEntryChars: 4,
      );
      expect(await store.write('cw2.bmp', '漢漢漢漢'), PayloadWriteResult.written);
      expect(
        await store.write('cw2.emoji', '🙂🙂'),
        PayloadWriteResult.written,
      );
      expect(
        await store.write('cw2.emoji', '🙂🙂a'),
        PayloadWriteResult.refusedOversized,
      );
      final restarted = FilePayloadStore(
        beforeMutation: ready,
        backend: backend,
        maxPayloadChars: 4,
        maxReadableBytes: 16,
      );
      expect(await restarted.read('cw2.bmp'), '漢漢漢漢');
      expect(await restarted.read('cw2.emoji'), '🙂🙂');
      expect(backend.replacements, 2);
    },
  );

  test('production ceilings cannot be widened', () {
    expect(
      () => FilePayloadStore(
        beforeMutation: ready,
        maxPayloadChars: V2PayloadLimits.maxPayloadChars + 1,
      ),
      throwsArgumentError,
    );
    expect(
      () => FilePayloadStore(
        beforeMutation: ready,
        maxReadableBytes: V2PayloadLimits.maxReadableBytes + 1,
      ),
      throwsArgumentError,
    );
  });

  test(
    'LRU aggregate, entry bypass, stale replacement and disk no-op',
    () async {
      final backend = FakeFiles();
      final store = FilePayloadStore(
        beforeMutation: ready,
        backend: backend,
        maxMemoryChars: 8,
        maxMemoryEntryChars: 4,
        maxMemoryEntries: 2,
      );
      await store.write('cw2.a', 'aaaa');
      await store.write('cw2.b', 'bbbb');
      await store.read('cw2.a');
      await store.write('cw2.c', 'cccc');
      expect(store.memoryChars, 8);
      expect(store.memoryEntries, 2);
      final reads = backend.reads;
      expect(await store.read('cw2.a'), 'aaaa');
      expect(backend.reads, reads);
      expect(await store.read('cw2.b'), 'bbbb');
      expect(backend.reads, reads + 1);
      await store.write('cw2.a', 'longer');
      expect(await store.read('cw2.a'), 'longer');
      final replacements = backend.replacements;
      expect(
        await store.write('cw2.a', 'longer'),
        PayloadWriteResult.unchanged,
      );
      expect(backend.replacements, replacements);
      expect(store.memoryChars, lessThanOrEqualTo(8));
    },
  );

  test(
    'invalid UTF8, decoded oversize and ignored byte cap are discarded',
    () async {
      final backend = FakeFiles()
        ..values['cw2.bad'] = Uint8List.fromList([0xff])
        ..values['cw2.chars'] = Uint8List.fromList(utf8.encode('12345'))
        ..values['cw2.bytes'] = Uint8List(17);
      final store = FilePayloadStore(
        beforeMutation: ready,
        backend: backend,
        maxPayloadChars: 4,
        maxReadableBytes: 16,
      );
      for (final key in ['cw2.bad', 'cw2.chars', 'cw2.bytes']) {
        expect(await store.read(key), isNull);
        expect(backend.values.containsKey(key), isFalse);
      }
      expect(backend.removals, 3);
    },
  );

  test(
    'real stream remains bounded after stale stat reports a tiny file',
    () async {
      await pathFor('cw2.growing').writeAsBytes(List.filled(100, 65));
      FaultFile? handle;
      final backend = native(
        fileFactory: (path) => handle = FaultFile(File(path), 'grow'),
      );
      final store = FilePayloadStore(
        beforeMutation: ready,
        backend: backend,
        maxReadableBytes: 8,
      );
      expect(await store.read('cw2.growing'), isNull);
      // The remove call creates a new handle, so read the bounded argument via a
      // separate direct backend read, with no cleanup replacing the handle.
      await pathFor('cw2.growing').writeAsBytes(List.filled(100, 65));
      await expectLater(
        backend.read('cw2.growing', maxBytes: 8),
        throwsA(isA<OversizedPayloadFile>()),
      );
      expect(handle!.requestedEnd, 9);
    },
  );

  for (final failure in ['stat', 'read']) {
    test('native $failure failure reports miss and preserves file', () async {
      await pathFor('cw2.keep').writeAsString('old');
      final store = FilePayloadStore(
        beforeMutation: ready,
        backend: native(fileFactory: (path) => FaultFile(File(path), failure)),
      );
      expect(await store.read('cw2.keep'), isNull);
      expect(await pathFor('cw2.keep').readAsString(), 'old');
    });
  }

  for (final failure in ['write', 'rename']) {
    test(
      'native $failure failure preserves old durable value, no new memory',
      () async {
        await pathFor('cw2.keep').writeAsString('old');
        final store = FilePayloadStore(
          beforeMutation: ready,
          backend: native(
            fileFactory: (path) => FaultFile(File(path), failure),
          ),
        );
        await expectLater(
          store.write('cw2.keep', 'new'),
          throwsA(isA<FileSystemException>()),
        );
        expect(await pathFor('cw2.keep').readAsString(), 'old');
        expect(store.memoryChars, 0);
        expect(await directory.list().length, 1);
      },
    );
  }

  test(
    'directory resolution failure never promotes memory and can retry',
    () async {
      var fail = true;
      final backend = NativePayloadFileBackend(
        directory: () async {
          if (fail) throw const FileSystemException('directory failure');
          return directory;
        },
      );
      final store = FilePayloadStore(beforeMutation: ready, backend: backend);
      await expectLater(
        store.write('cw2.keep', 'new'),
        throwsA(isA<FileSystemException>()),
      );
      expect(store.memoryChars, 0);
      fail = false;
      expect(await store.write('cw2.keep', 'new'), PayloadWriteResult.written);
    },
  );

  test(
    'write and remove failures preserve previous memory and queue recovers',
    () async {
      final backend = FakeFiles();
      final store = FilePayloadStore(beforeMutation: ready, backend: backend);
      await store.write('cw2.keep', 'old');
      backend.failWrite = true;
      await expectLater(
        store.write('cw2.keep', 'new'),
        throwsA(isA<FileSystemException>()),
      );
      expect(await store.read('cw2.keep'), 'old');
      backend.failWrite = false;
      backend.failRemove = true;
      await expectLater(
        store.remove('cw2.keep'),
        throwsA(isA<FileSystemException>()),
      );
      expect(await store.read('cw2.keep'), 'old');
      backend.failRemove = false;
      await store.write('cw2.keep', 'next');
      expect(await store.read('cw2.keep'), 'next');
    },
  );

  test(
    'same-key queued read and remove follow awaited durable replacement',
    () async {
      final backend = FakeFiles()
        ..entered = Completer<void>()
        ..release = Completer<void>();
      final store = FilePayloadStore(beforeMutation: ready, backend: backend);
      final write = store.write('cw2.key', 'new');
      await backend.entered!.future;
      final read = store.read('cw2.key');
      final remove = store.remove('cw2.key');
      expect(store.memoryChars, 0);
      backend.release!.complete();
      await write;
      expect(await read, 'new');
      await remove;
      expect(await store.read('cw2.key'), isNull);
    },
  );

  test(
    'future schema blocks writes, removals and corruption cleanup',
    () async {
      final metadata = V2MetadataStore(
        backend: FakeMetadataBackend()..values['cw2.schema'] = 99,
      );
      final backend = FakeFiles()
        ..values['cw2.bad'] = Uint8List.fromList([0xff]);
      final store = FilePayloadStore(
        beforeMutation: metadata.ensureSchema,
        backend: backend,
      );
      await expectLater(
        store.write('cw2.key', 'new'),
        throwsA(isA<StorageSchemaException>()),
      );
      await expectLater(
        store.remove('cw2.bad'),
        throwsA(isA<StorageSchemaException>()),
      );
      expect(await store.read('cw2.bad'), isNull);
      expect(backend.removals, 0);
      expect(backend.replacements, 0);
      expect(backend.values.containsKey('cw2.bad'), isTrue);
    },
  );
}
