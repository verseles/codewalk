@TestOn('vm')
library;

// These fixtures are owned temporary files, never installed preferences.
// ignore_for_file: avoid_slow_async_io

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:codewalk/platform/migration/legacy_file_reader_io.dart';
import 'package:codewalk/platform/migration/legacy_source.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

Matcher readFailure(LegacyReadFailure failure) => throwsA(
  isA<LegacyReadException>().having(
    (error) => error.failure,
    'failure',
    failure,
  ),
);

/// Wraps a real source file to exercise stream failure or growth after stat.
final class ObservedFile implements File {
  ObservedFile(this.actual, {this.growth, this.unreadable = false});

  final File actual;
  final Uint8List? growth;
  final bool unreadable;
  bool streamOpened = false;
  int? requestedEnd;

  @override
  String get path => actual.path;

  @override
  Future<FileStat> stat() async {
    final earlier = await actual.stat();
    if (growth != null) await actual.writeAsBytes(growth!, flush: true);
    return earlier;
  }

  @override
  Stream<List<int>> openRead([int? start, int? end]) {
    streamOpened = true;
    requestedEnd = end;
    if (unreadable) {
      return Stream.error(FileSystemException('native failure ${actual.path}'));
    }
    return actual.openRead(start, end);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('cw2_legacy_reader_');
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  File source(String key) =>
      File(path.join(directory.path, '${sha1.convert(utf8.encode(key))}.json'));

  NativeLegacyPayloadReader reader({
    int maxReadableBytes = NativeLegacyPayloadReader.byteCeiling,
    int maxPayloadChars = NativeLegacyPayloadReader.characterCeiling,
    File Function(String)? fileFactory,
  }) => NativeLegacyPayloadReader(
    directory: directory,
    maxReadableBytes: maxReadableBytes,
    maxPayloadChars: maxPayloadChars,
    fileFactory: fileFactory,
  );

  test('reads original SHA-1 raw UTF-8 and leaves bytes untouched', () async {
    const key = 'session_composer_draft::server::scope::session';
    const value = '{"text":"旧🙂","explicitOff":false}\n';
    final bytes = utf8.encode(value);
    await source(key).writeAsBytes(bytes, flush: true);

    expect(await reader().read(key), value);
    expect(await reader().read(key), value);
    expect(await source(key).readAsBytes(), bytes);
    expect(
      await directory.list().map((entry) => path.basename(entry.path)).toList(),
      [path.basename(source(key).path)],
    );
    expect(await reader().unclaimedFiles({key}), isEmpty);
  });

  test('missing source returns a miss without creating directories', () async {
    final absent = Directory(path.join(directory.path, 'never-created'));
    final missing = NativeLegacyPayloadReader(directory: absent);

    expect(await missing.read('absent'), isNull);
    expect(await missing.unclaimedFiles({}), isEmpty);
    expect(await absent.exists(), isFalse);
    expect(await reader().read('absent'), isNull);
    expect(await directory.list().toList(), isEmpty);
  });

  test('empty and malformed JSON stay raw; invalid UTF-8 fails', () async {
    await source('empty').writeAsBytes([]);
    await source('json').writeAsString('{invalid json');
    const invalidBytes = [0xC3, 0x28, 0xFF];
    await source('encoding').writeAsBytes(invalidBytes, flush: true);

    expect(await reader().read('empty'), '');
    expect(await reader().read('json'), '{invalid json');
    await expectLater(
      reader().read('encoding'),
      readFailure(LegacyReadFailure.malformed),
    );
    expect(await source('encoding').readAsBytes(), invalidBytes);
    expect(await source('json').readAsString(), '{invalid json');
  });

  test('exact UTF-16 character ceiling survives and overage is kept', () async {
    final exact = '🙂' * (NativeLegacyPayloadReader.characterCeiling ~/ 2);
    await source('exact').writeAsString(exact, flush: true);
    final excess = utf8.encode('$exact!');
    await source('excess').writeAsBytes(excess, flush: true);

    expect(exact.length, NativeLegacyPayloadReader.characterCeiling);
    expect(await reader().read('exact'), exact);
    await expectLater(
      reader().read('excess'),
      readFailure(LegacyReadFailure.oversized),
    );
    expect(await source('excess').readAsBytes(), excess);
    expect(await source('exact').readAsString(), exact);
  });

  test('stat rejects byte overage before opening its stream', () async {
    final bytes = Uint8List(NativeLegacyPayloadReader.byteCeiling + 1);
    final actual = source('oversized');
    await actual.writeAsBytes(bytes, flush: true);
    final file = ObservedFile(actual, unreadable: true);

    await expectLater(
      reader(fileFactory: (_) => file).read('oversized'),
      readFailure(LegacyReadFailure.oversized),
    );
    expect(file.streamOpened, isFalse);
    expect(await actual.readAsBytes(), bytes);
  });

  test(
    'byte boundary is inclusive before the independent char limit',
    () async {
      const exact = '漢漢'; // Six UTF-8 bytes, two UTF-16 code units.
      await source('exact-byte').writeAsString(exact);
      await source('extra-byte').writeAsString('$exact!');
      final bounded = reader(maxReadableBytes: 6, maxPayloadChars: 2);

      expect(await bounded.read('exact-byte'), exact);
      await expectLater(
        bounded.read('extra-byte'),
        readFailure(LegacyReadFailure.oversized),
      );
      expect(await source('extra-byte').readAsString(), '$exact!');

      final actual = source('production-byte-boundary');
      await actual.writeAsBytes(
        Uint8List(NativeLegacyPayloadReader.byteCeiling),
        flush: true,
      );
      final file = ObservedFile(actual);
      // Exactly 8 MiB passes stat/stream, then exceeds the UTF-16 char ceiling.
      await expectLater(
        reader(fileFactory: (_) => file).read('production-byte-boundary'),
        readFailure(LegacyReadFailure.oversized),
      );
      expect(file.streamOpened, isTrue);
      expect(file.requestedEnd, NativeLegacyPayloadReader.byteCeiling + 1);
      expect(await actual.length(), NativeLegacyPayloadReader.byteCeiling);
    },
  );

  test(
    'stream catches real growth after stat and preserves grown bytes',
    () async {
      final actual = source('grows');
      await actual.writeAsString('x');
      final grown = Uint8List(NativeLegacyPayloadReader.byteCeiling + 1);
      final file = ObservedFile(actual, growth: grown);

      await expectLater(
        reader(fileFactory: (_) => file).read('grows'),
        readFailure(LegacyReadFailure.oversized),
      );
      expect(file.requestedEnd, NativeLegacyPayloadReader.byteCeiling + 1);
      expect(await actual.readAsBytes(), grown);
    },
  );

  test('native read error exposes only safe typed failure', () async {
    const value = 'source value kept';
    final actual = source('unavailable');
    await actual.writeAsString(value);
    final unavailable = reader(
      fileFactory: (_) => ObservedFile(actual, unreadable: true),
    );

    await expectLater(
      unavailable.read('unavailable'),
      throwsA(
        isA<LegacyReadException>()
            .having(
              (error) => error.failure,
              'failure',
              LegacyReadFailure.unavailable,
            )
            .having(
              (error) => error.toString(),
              'safe diagnostic',
              'LegacyReadException(unavailable)',
            ),
      ),
    );
    expect(await actual.readAsString(), value);
  });

  test('orphan listing reads no contents and preserves source files', () async {
    const known = 'known';
    const orphan = 'unindexed-draft';
    const invalid = 'malformed-orphan';
    await source(known).writeAsString('known value');
    await source(orphan).writeAsString('unknown value');
    await source(invalid).writeAsBytes([0xFF]);
    await File(path.join(directory.path, 'other.json')).writeAsString('other');
    await File('${source('temporary').path}.tmp').writeAsString('temporary');
    final nested = await Directory(
      path.join(directory.path, 'nested'),
    ).create();
    await File(
      path.join(nested.path, path.basename(source('nested').path)),
    ).writeAsString('nested value');
    var fileOpened = false;
    final enumeration = reader(
      fileFactory: (filename) {
        fileOpened = true;
        return File(filename);
      },
    );

    expect(await enumeration.unclaimedFiles({known}), {
      path.basename(source(orphan).path),
      path.basename(source(invalid).path),
    });
    expect(fileOpened, isFalse);
    expect(await source(known).readAsString(), 'known value');
    expect(await source(orphan).readAsString(), 'unknown value');
    expect(await source(invalid).readAsBytes(), [0xFF]);
    expect(await nested.exists(), isTrue);
  });

  test('nonregular digest entries remain unresolved and unread', () async {
    final folder = await Directory(source('folder').path).create();
    final nested = File(path.join(folder.path, 'kept'));
    await nested.writeAsString('nested original');

    await expectLater(
      reader().read('folder'),
      readFailure(LegacyReadFailure.unavailable),
    );
    expect(await reader().unclaimedFiles({}), {path.basename(folder.path)});
    expect(await nested.readAsString(), 'nested original');
  });

  test(
    'source and digest symlinks never read the outside target',
    () async {
      final outside = await Directory.systemTemp.createTemp(
        'cw2_legacy_outside_',
      );
      try {
        final target = File(path.join(outside.path, 'kept'));
        await target.writeAsString('outside original');
        final linked = Link(source('linked').path);
        await linked.create(target.path);
        var fileOpened = false;
        final bounded = reader(
          fileFactory: (filename) {
            fileOpened = true;
            return File(filename);
          },
        );

        await expectLater(
          bounded.read('linked'),
          readFailure(LegacyReadFailure.unavailable),
        );
        expect(fileOpened, isFalse);
        expect(await bounded.unclaimedFiles({}), {path.basename(linked.path)});
        expect(await linked.target(), target.path);
        expect(await target.readAsString(), 'outside original');

        final alias = Link(path.join(directory.path, 'directory-alias'));
        await alias.create(outside.path);
        final linkedDirectory = NativeLegacyPayloadReader(
          directory: Directory(alias.path),
        );
        await expectLater(
          linkedDirectory.read('any'),
          readFailure(LegacyReadFailure.unavailable),
        );
        await expectLater(
          linkedDirectory.unclaimedFiles({}),
          readFailure(LegacyReadFailure.unavailable),
        );
        expect(await target.readAsString(), 'outside original');
      } finally {
        await outside.delete(recursive: true);
      }
    },
    skip: Platform.isWindows
        ? 'Symlink creation requires Windows privileges'
        : false,
  );

  test('limits may narrow but never widen production ceilings', () {
    expect(
      () => reader(maxReadableBytes: NativeLegacyPayloadReader.byteCeiling + 1),
      throwsArgumentError,
    );
    expect(
      () => reader(
        maxPayloadChars: NativeLegacyPayloadReader.characterCeiling + 1,
      ),
      throwsArgumentError,
    );
    expect(() => reader(maxReadableBytes: 0), throwsArgumentError);
    expect(() => reader(maxPayloadChars: -1), throwsArgumentError);
  });
}
