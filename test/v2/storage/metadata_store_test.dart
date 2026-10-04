import 'dart:async';

import 'package:codewalk/platform/storage/metadata_store.dart';
import 'package:flutter_test/flutter_test.dart';

import 'storage_fakes.dart';

void main() {
  test(
    'initializes once; equality and missing remove do not rewrite',
    () async {
      final backend = FakeMetadataBackend();
      final store = V2MetadataStore(backend: backend);
      expect(await store.write('cw2.flag', false), isTrue);
      expect(await store.write('cw2.flag', false), isFalse);
      expect(await store.remove('cw2.absent'), isFalse);
      expect(await store.read('cw2.flag'), isFalse);
      expect(backend.writes, ['cw2.schema', 'cw2.flag']);
      await store.ensureSchema();
      expect(backend.writes, hasLength(2));
    },
  );

  test('guards namespace, schema ownership and preference ceiling', () async {
    final backend = FakeMetadataBackend();
    final store = V2MetadataStore(backend: backend);
    await expectLater(store.write('legacy', 'x'), throwsArgumentError);
    await expectLater(store.write('cw2.schema', 99), throwsArgumentError);
    await expectLater(
      store.write('cw2.big', 'a' * (V2MetadataStore.maxPreferenceChars + 1)),
      throwsArgumentError,
    );
    expect(backend.writes, isEmpty);
    await store.write('cw2.exact', 'a' * V2MetadataStore.maxPreferenceChars);
    expect((await store.read('cw2.exact') as String).length, 1024 * 1024);
  });

  test('list snapshot and element equality guard writes', () async {
    final backend = FakeMetadataBackend();
    final store = V2MetadataStore(backend: backend);
    final source = ['a'];
    final write = store.write('cw2.list', source);
    source.add('b');
    await write;
    expect(await store.read('cw2.list'), ['a']);
    expect(await store.write('cw2.list', ['a']), isFalse);
    expect(
      () => (backend.values['cw2.list'] as List<String>).add('c'),
      throwsUnsupportedError,
    );
  });

  test(
    'read immediately after write cannot overtake schema initialization',
    () async {
      final backend = FakeMetadataBackend();
      final entered = Completer<void>();
      final release = Completer<void>();
      final store = V2MetadataStore(
        backend: backend,
        upgrades: {
          1: (context) async {
            entered.complete();
            await release.future;
            await context.write('cw2.value', 'migration');
          },
        },
      );
      final write = store.write('cw2.value', 'final');
      final read = store.read('cw2.value');
      await entered.future;
      release.complete();
      await write;
      expect(await read, 'final');
    },
  );

  test(
    'failed upgrade restarts step without advancing marker or v1 writes',
    () async {
      final backend = FakeMetadataBackend()..values['cw2.schema'] = 1;
      final source = {'old.allowAll': false};
      var attempts = 0;
      final store = V2MetadataStore(
        backend: backend,
        currentSchema: 3,
        legacy: FakeLegacyReader(source),
        upgrades: {
          2: (context) async {
            attempts++;
            await context.write(
              'cw2.allowAll',
              (await context.legacy!.read('old.allowAll'))!,
            );
            if (attempts == 1) throw StateError('interrupted');
          },
          3: (context) async {
            await context.write('cw2.upgraded', true);
          },
        },
      );
      await expectLater(store.ensureSchema(), throwsStateError);
      expect(backend.values['cw2.schema'], 1);
      expect(backend.values['cw2.allowAll'], false);
      await store.ensureSchema();
      expect(attempts, 2);
      expect(backend.values['cw2.schema'], 3);
      expect(
        backend.writes.where((key) => key == 'cw2.allowAll'),
        hasLength(1),
      );
      expect(source, {'old.allowAll': false});
      expect(backend.writes.every((key) => key.startsWith('cw2.')), isTrue);
    },
  );

  test(
    'marker write failure reruns idempotent step on a new instance',
    () async {
      final backend = FakeMetadataBackend()..failWrite = 'cw2.schema';
      var runs = 0;
      V2MetadataStore instance() => V2MetadataStore(
        backend: backend,
        upgrades: {
          1: (context) async {
            runs++;
            await context.write('cw2.imported', 'value');
          },
        },
      );
      await expectLater(instance().ensureSchema(), throwsStateError);
      expect(backend.values.containsKey('cw2.schema'), isFalse);
      backend.failWrite = null;
      await instance().ensureSchema();
      expect(runs, 2);
      expect(
        backend.writes.where((key) => key == 'cw2.imported'),
        hasLength(1),
      );
    },
  );

  for (final marker in [99, -1, 'broken']) {
    test('schema $marker preserves data and blocks write/remove', () async {
      final backend = FakeMetadataBackend()
        ..values.addAll({
          'cw2.schema': marker,
          'cw2.keep': 'old',
          'legacy': true,
        });
      final store = V2MetadataStore(backend: backend);
      await expectLater(
        store.write('cw2.keep', 'new'),
        throwsA(isA<StorageSchemaException>()),
      );
      await expectLater(
        store.remove('cw2.keep'),
        throwsA(isA<StorageSchemaException>()),
      );
      expect(backend.values, {
        'cw2.schema': marker,
        'cw2.keep': 'old',
        'legacy': true,
      });
      expect(backend.writes, isEmpty);
      expect(backend.removals, isEmpty);
    });
  }

  test('missing schema step does not silently skip an upgrade', () async {
    final backend = FakeMetadataBackend()..values['cw2.schema'] = 1;
    final store = V2MetadataStore(backend: backend, currentSchema: 3);
    await expectLater(
      store.ensureSchema(),
      throwsA(isA<StorageSchemaException>()),
    );
    expect(backend.values['cw2.schema'], 1);
  });

  for (final marker in [99, -1, 'broken']) {
    test(
      'warm instance revalidates externally changed schema $marker',
      () async {
        final backend = FakeMetadataBackend();
        final store = V2MetadataStore(backend: backend);
        await store.write('cw2.keep', 'old');
        backend.values['cw2.schema'] = marker;
        final beforeWrites = backend.writes.length;
        await expectLater(
          store.write('cw2.keep', 'new'),
          throwsA(isA<StorageSchemaException>()),
        );
        await expectLater(
          store.remove('cw2.keep'),
          throwsA(isA<StorageSchemaException>()),
        );
        expect(backend.values['cw2.keep'], 'old');
        expect(backend.values['cw2.schema'], marker);
        expect(backend.writes, hasLength(beforeWrites));
        expect(backend.removals, isEmpty);
      },
    );
  }

  for (final fail in [false, true]) {
    test(
      'retained migration context is revoked after ${fail ? 'failure' : 'success'}',
      () async {
        final backend = FakeMetadataBackend();
        late SchemaMigrationContext retained;
        final store = V2MetadataStore(
          backend: backend,
          upgrades: {
            1: (context) async {
              retained = context;
              await context.write('cw2.initial', 'kept');
              if (fail) throw StateError('hook failure');
            },
          },
        );
        if (fail) {
          await expectLater(store.ensureSchema(), throwsStateError);
        } else {
          await store.ensureSchema();
        }
        final beforeWrites = backend.writes.length;
        await expectLater(
          retained.write('cw2.escaped', 'bad'),
          throwsStateError,
        );
        await expectLater(retained.remove('cw2.initial'), throwsStateError);
        await expectLater(retained.read('cw2.initial'), throwsStateError);
        expect(backend.values['cw2.initial'], 'kept');
        expect(backend.values.containsKey('cw2.escaped'), isFalse);
        expect(backend.writes, hasLength(beforeWrites));
        expect(backend.removals, isEmpty);
      },
    );
  }

  test(
    'hook return drains pending operations in call order before marker',
    () async {
      final backend = FakeMetadataBackend()
        ..blockedKey = 'cw2.pending'
        ..entered = Completer<void>()
        ..release = Completer<void>();
      late SchemaMigrationContext retained;
      final store = V2MetadataStore(
        backend: backend,
        upgrades: {
          1: (context) async {
            retained = context;
            unawaited(context.write('cw2.pending', 'first'));
            unawaited(context.write('cw2.pending', 'second'));
          },
        },
      );
      final initialized = store.ensureSchema();
      await backend.entered!.future;
      expect(backend.values.containsKey('cw2.schema'), isFalse);
      await expectLater(retained.write('cw2.escaped', 'bad'), throwsStateError);
      backend.release!.complete();
      await initialized;
      expect(backend.values['cw2.pending'], 'second');
      expect(backend.writes, ['cw2.pending', 'cw2.pending', 'cw2.schema']);
    },
  );

  test(
    'pending hook operation failure bars promotion without unhandled error',
    () async {
      final backend = FakeMetadataBackend()..failWrite = 'cw2.pending';
      final store = V2MetadataStore(
        backend: backend,
        upgrades: {
          1: (context) async {
            unawaited(context.write('cw2.pending', 'failed'));
            // Let the ignored operation fail before the callback returns. Flutter's
            // test zone would fail this test if its error went unhandled.
            await Future<void>.delayed(Duration.zero);
          },
        },
      );
      await expectLater(store.ensureSchema(), throwsStateError);
      expect(backend.values.containsKey('cw2.schema'), isFalse);
      backend.failWrite = null;
      await store.ensureSchema();
      expect(backend.values['cw2.schema'], 1);
      expect(backend.values['cw2.pending'], 'failed');
    },
  );

  test(
    'failed hook drains its outstanding write before retry is possible',
    () async {
      final backend = FakeMetadataBackend()
        ..blockedKey = 'cw2.pending'
        ..entered = Completer<void>()
        ..release = Completer<void>();
      final store = V2MetadataStore(
        backend: backend,
        upgrades: {
          1: (context) async {
            unawaited(context.write('cw2.pending', 'started'));
            throw StateError('callback failed');
          },
        },
      );
      var finished = false;
      final initialization = store.ensureSchema();
      final checked = expectLater(initialization, throwsStateError).then((_) {
        finished = true;
      });
      await backend.entered!.future;
      expect(finished, isFalse);
      expect(backend.values.containsKey('cw2.schema'), isFalse);
      backend.release!.complete();
      await checked;
      expect(backend.values['cw2.pending'], 'started');
      expect(backend.values.containsKey('cw2.schema'), isFalse);
    },
  );

  test('same-key read/write/remove are ordered; other keys progress', () async {
    final backend = FakeMetadataBackend()
      ..blockedKey = 'cw2.a'
      ..entered = Completer<void>()
      ..release = Completer<void>();
    final store = V2MetadataStore(backend: backend);
    final first = store.write('cw2.a', 'one');
    await backend.entered!.future;
    final read = store.read('cw2.a');
    final second = store.write('cw2.a', 'two');
    final removal = store.remove('cw2.a');
    await store.write('cw2.b', 'independent');
    expect(backend.values['cw2.b'], 'independent');
    backend.release!.complete();
    await first;
    expect(await read, 'one');
    await second;
    await removal;
    await store.flush();
    expect(backend.values.containsKey('cw2.a'), isFalse);
  });

  test(
    'backend failures propagate without poisoning later operations',
    () async {
      final backend = FakeMetadataBackend()..values['cw2.schema'] = 1;
      final store = V2MetadataStore(backend: backend);
      backend.failWrite = 'cw2.value';
      await expectLater(store.write('cw2.value', 'bad'), throwsStateError);
      backend.failWrite = null;
      await store.write('cw2.value', 'good');
      backend.failRead = true;
      await expectLater(store.read('cw2.value'), throwsStateError);
      backend.failRead = false;
      backend.failRemove = true;
      await expectLater(store.remove('cw2.value'), throwsStateError);
      backend.failRemove = false;
      expect(await store.read('cw2.value'), 'good');
    },
  );
}
