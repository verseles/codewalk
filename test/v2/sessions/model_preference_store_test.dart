import 'dart:convert';

import 'package:codewalk/platform/sessions/model_preference_store.dart';
import 'package:codewalk/platform/storage/metadata_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../storage/storage_fakes.dart';

void main() {
  late FakeMetadataBackend backend;

  Future<ModelPreferenceStore> load() async {
    final store = ModelPreferenceStore(
      store: V2MetadataStore(backend: backend),
    );
    addTearDown(store.dispose);
    await store.initialize();
    return store;
  }

  setUp(() => backend = FakeMetadataBackend());

  test('favorites belong to a server and are shared by its projects', () async {
    final store = await load();
    expect(store.writable, isTrue);
    expect(
      await store.setFavorite('server-a', 'p/one', favorite: true),
      isTrue,
    );
    expect(
      await store.setFavorite('server-a', 'p/two', favorite: true),
      isTrue,
    );
    // Starring twice changes nothing.
    expect(
      await store.setFavorite('server-a', 'p/one', favorite: true),
      isFalse,
    );
    expect(store.favorites('server-a'), ['p/one', 'p/two']);
    expect(store.favorites('server-b'), isEmpty);
    expect(store.isFavorite('server-a', 'p/two'), isTrue);
    // They survive a restart.
    final reloaded = await load();
    expect(reloaded.favorites('server-a'), ['p/one', 'p/two']);
    expect(
      await reloaded.setFavorite('server-a', 'p/one', favorite: false),
      isTrue,
    );
    expect(reloaded.favorites('server-a'), ['p/two']);
    expect(
      await reloaded.setFavorite('server-a', 'p/two', favorite: false),
      isTrue,
    );
    // A server without favorites leaves no entry behind.
    final saved =
        jsonDecode(backend.values[ModelPreferenceStore.key]! as String)
            as Map<String, Object?>;
    expect(saved['favorites'], isEmpty);
  });

  test('recents are per project, newest first, eight at most', () async {
    final store = await load();
    for (var i = 0; i < 10; i++) {
      expect(
        await store.recordRecent('server-a', '/work/app', 'p/m$i'),
        isTrue,
      );
    }
    expect(store.recents('server-a', '/work/app'), [
      for (var i = 9; i >= 2; i--) 'p/m$i',
    ]);
    // Picking a recent one again moves it first; the first one stays put.
    expect(await store.recordRecent('server-a', '/work/app', 'p/m5'), isTrue);
    expect(await store.recordRecent('server-a', '/work/app', 'p/m5'), isFalse);
    expect(store.recents('server-a', '/work/app').take(2), ['p/m5', 'p/m9']);
    expect(store.recents('server-a', '/work/app'), hasLength(8));
    expect(store.recents('server-a', '/work/other'), isEmpty);
    expect(store.recents('server-b', '/work/app'), isEmpty);
    final reloaded = await load();
    expect(reloaded.recents('server-a', '/work/app').first, 'p/m5');
  });

  test('the least recently used project drops out first', () async {
    final store = await load();
    for (var i = 0; i <= ModelPreferenceStore.maxProjects; i++) {
      await store.recordRecent('server-a', '/work/$i', 'p/m');
    }
    expect(store.recents('server-a', '/work/0'), isEmpty);
    expect(store.recents('server-a', '/work/1'), ['p/m']);
    expect(
      store.recents('server-a', '/work/${ModelPreferenceStore.maxProjects}'),
      ['p/m'],
    );
  });

  test('a full favorites list refuses one more', () async {
    final store = await load();
    for (var i = 0; i < ModelPreferenceStore.maxFavorites; i++) {
      await store.setFavorite('server-a', 'p/m$i', favorite: true);
    }
    expect(
      await store.setFavorite('server-a', 'p/new', favorite: true),
      isFalse,
    );
    expect(
      store.favorites('server-a'),
      hasLength(ModelPreferenceStore.maxFavorites),
    );
    expect(store.hasPersistenceError, isFalse);
  });

  test('an unreadable record is never overwritten', () async {
    for (final raw in <Object>[
      'not json',
      '[]',
      jsonEncode({'favorites': <String, Object?>{}}),
      jsonEncode({
        'favorites': {
          'server-a': ['p/one', 'p/one'],
        },
        'recents': <Object?>[],
      }),
      jsonEncode({
        'favorites': <String, Object?>{},
        'recents': [
          ['server-a', '/work/app', <Object?>[]],
        ],
      }),
      42,
    ]) {
      backend = FakeMetadataBackend()..values[ModelPreferenceStore.key] = raw;
      final store = await load();
      expect(store.unreadable, isTrue, reason: '$raw');
      expect(store.writable, isFalse);
      expect(store.favorites('server-a'), isEmpty);
      expect(
        await store.setFavorite('server-a', 'p/m', favorite: true),
        isFalse,
      );
      expect(await store.recordRecent('server-a', '/work', 'p/m'), isFalse);
      expect(backend.values[ModelPreferenceStore.key], raw);
    }
  });

  test('a failed read keeps the store closed', () async {
    backend.failRead = true;
    final store = await load();
    expect(store.unreadable, isTrue);
    expect(await store.setFavorite('server-a', 'p/m', favorite: true), isFalse);
    expect(backend.writes, isEmpty);
  });

  test('a failed write changes nothing and is reported', () async {
    final store = await load();
    await store.setFavorite('server-a', 'p/one', favorite: true);
    backend.failWrite = ModelPreferenceStore.key;
    expect(
      await store.setFavorite('server-a', 'p/two', favorite: true),
      isFalse,
    );
    expect(store.favorites('server-a'), ['p/one']);
    expect(store.hasPersistenceError, isTrue);
    backend.failWrite = null;
    expect(
      await store.setFavorite('server-a', 'p/two', favorite: true),
      isTrue,
    );
    expect(store.hasPersistenceError, isFalse);
  });

  test('a record it wrote reads back whole', () async {
    final store = await load();
    await store.setFavorite('server-a', 'p/one', favorite: true);
    await store.recordRecent('server-a', '/work/app', 'p/two');
    await store.recordAgent('server-a', '/work/app', 'plan', previous: 'build');
    await store.recordVariant(
      'server-a',
      '/work/app',
      'p/two',
      'high',
      previous: ModelPreferenceStore.autoVariant,
    );
    await store.rememberAgentModel(
      'server-a',
      '/work/app',
      'plan',
      'p/two',
      null,
    );
    final raw = backend.values[ModelPreferenceStore.key]! as String;
    expect(jsonDecode(raw), {
      'favorites': {
        'server-a': ['p/one'],
      },
      'recents': [
        [
          'server-a',
          '/work/app',
          ['p/two'],
        ],
      ],
      'history': [
        [
          'agent',
          'server-a',
          '/work/app',
          '',
          ['plan', 'build'],
        ],
        [
          'variant',
          'server-a',
          '/work/app',
          'p/two',
          ['high', ''],
        ],
      ],
      'agentModels': [
        ['server-a', '/work/app', 'plan', 'p/two', null],
      ],
    });
    final reloaded = await load();
    expect(reloaded.unreadable, isFalse);
    expect(reloaded.favorites('server-a'), ['p/one']);
    expect(reloaded.recents('server-a', '/work/app'), ['p/two']);
    expect(reloaded.agentRecents('server-a', '/work/app'), ['plan', 'build']);
    expect(reloaded.variantRecents('server-a', '/work/app', 'p/two'), [
      'high',
      ModelPreferenceStore.autoVariant,
    ]);
    expect(reloaded.agentModel('server-a', '/work/app', 'plan'), (
      'p/two',
      null,
    ));
  });

  test('a record without the later lists still reads', () async {
    backend.values[ModelPreferenceStore.key] = jsonEncode({
      'favorites': {
        'server-a': ['p/one'],
      },
      'recents': [
        [
          'server-a',
          '/work/app',
          ['p/two'],
        ],
      ],
    });
    final store = await load();
    expect(store.unreadable, isFalse);
    expect(store.recents('server-a', '/work/app'), ['p/two']);
    expect(store.agentRecents('server-a', '/work/app'), isEmpty);
    expect(store.agentModel('server-a', '/work/app', 'plan'), isNull);
  });

  test('the previous pick follows the new one, so cycling goes back', () async {
    final store = await load();
    await store.recordRecent('server-a', '/work', 'p/b', previous: 'p/a');
    expect(store.recents('server-a', '/work'), ['p/b', 'p/a']);
    await store.recordRecent('server-a', '/work', 'p/a', previous: 'p/b');
    expect(store.recents('server-a', '/work'), ['p/a', 'p/b']);
    await store.recordAgent('server-a', '/work', 'plan');
    await store.recordAgent('server-a', '/work', 'build', previous: 'plan');
    expect(store.agentRecents('server-a', '/work'), ['build', 'plan']);
    // A variant's history is per model.
    await store.recordVariant('server-a', '/work', 'p/a', 'low');
    expect(store.variantRecents('server-a', '/work', 'p/a'), ['low']);
    expect(store.variantRecents('server-a', '/work', 'p/b'), isEmpty);
  });

  test('an agent keeps one model per project, the latest', () async {
    final store = await load();
    await store.rememberAgentModel('server-a', '/work', 'plan', 'p/a', 'high');
    await store.rememberAgentModel('server-a', '/work', 'plan', 'p/b', null);
    expect(store.agentModel('server-a', '/work', 'plan'), ('p/b', null));
    expect(store.agentModel('server-a', '/other', 'plan'), isNull);
    expect(store.agentModel('server-b', '/work', 'plan'), isNull);
    // The same memory again writes nothing.
    final writes = backend.writes.length;
    expect(
      await store.rememberAgentModel('server-a', '/work', 'plan', 'p/b', null),
      isFalse,
    );
    expect(backend.writes, hasLength(writes));
    for (var i = 0; i <= ModelPreferenceStore.maxProjects; i++) {
      await store.rememberAgentModel('server-a', '/w$i', 'plan', 'p/a', null);
    }
    expect(store.agentModel('server-a', '/work', 'plan'), isNull);
  });

  test('history rows that are not this store\'s make it unreadable', () async {
    for (final extra in <Map<String, Object?>>[
      {'unknown': <Object?>[]},
      {
        'history': [
          [
            'model',
            'server-a',
            '/w',
            '',
            ['p/a'],
          ],
        ],
      },
      {
        'history': [
          [
            'agent',
            'server-a',
            '/w',
            'scope',
            ['plan'],
          ],
        ],
      },
      {
        'history': [
          [
            'agent',
            'server-a',
            '/w',
            '',
            [''],
          ],
        ],
      },
      {
        'agentModels': [
          ['server-a', '/w', 'plan', '', null],
        ],
      },
    ]) {
      final raw = jsonEncode({
        'favorites': <String, Object?>{},
        'recents': <Object?>[],
        ...extra,
      });
      backend = FakeMetadataBackend()..values[ModelPreferenceStore.key] = raw;
      final store = await load();
      expect(store.unreadable, isTrue, reason: raw);
    }
  });
}
