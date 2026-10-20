import 'package:codewalk/platform/sessions/hidden_session_store.dart';
import 'package:codewalk/platform/storage/metadata_store.dart';
import 'package:flutter_test/flutter_test.dart';

final class _MemoryBackend implements MetadataBackend {
  final values = <String, Object>{};
  bool failRead = false;
  bool failWrite = false;

  @override
  Future<Object?> read(String key) async {
    if (failRead) throw StateError('unreadable');
    return values[key];
  }

  @override
  Future<void> write(String key, Object value) async {
    if (failWrite) throw StateError('unwritable');
    values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }
}

void main() {
  test('a hidden session is kept and comes back', () async {
    final backend = _MemoryBackend();
    final store = HiddenSessionStore(store: V2MetadataStore(backend: backend));
    await store.initialize();
    expect(store.unreadable, isFalse);
    expect(store.isHidden('ses_a'), isFalse);
    expect(await store.setHidden('ses_a', hidden: true), isTrue);
    expect(store.isHidden('ses_a'), isTrue);
    expect(backend.values.containsKey(HiddenSessionStore.key), isTrue);
    // The hide survives a restart.
    final reloaded = HiddenSessionStore(
      store: V2MetadataStore(backend: backend),
    );
    await reloaded.initialize();
    expect(reloaded.isHidden('ses_a'), isTrue);
  });

  test('an unreadable list is never overwritten', () async {
    final backend = _MemoryBackend()
      ..values[HiddenSessionStore.key] = 'not a list';
    final store = HiddenSessionStore(store: V2MetadataStore(backend: backend));
    await store.initialize();
    expect(store.unreadable, isTrue);
    expect(await store.setHidden('ses_a', hidden: true), isFalse);
    expect(backend.values[HiddenSessionStore.key], 'not a list');
  });

  test('a failed read leaves the store unreadable', () async {
    final backend = _MemoryBackend()..failRead = true;
    final store = HiddenSessionStore(store: V2MetadataStore(backend: backend));
    await store.initialize();
    expect(store.unreadable, isTrue);
    expect(await store.setHidden('ses_a', hidden: true), isFalse);
  });

  test('a failed write keeps the row visible', () async {
    final backend = _MemoryBackend()..failWrite = true;
    final store = HiddenSessionStore(store: V2MetadataStore(backend: backend));
    await store.initialize();
    expect(await store.setHidden('ses_a', hidden: true), isFalse);
    expect(store.isHidden('ses_a'), isFalse);
  });

  test('the list is bounded and never evicts a hidden session', () async {
    final backend = _MemoryBackend();
    final store = HiddenSessionStore(store: V2MetadataStore(backend: backend));
    await store.initialize();
    for (var i = 0; i < HiddenSessionStore.maxEntries; i++) {
      expect(await store.setHidden('ses_$i', hidden: true), isTrue);
    }
    expect(await store.setHidden('ses_overflow', hidden: true), isFalse);
    expect(store.isHidden('ses_0'), isTrue);
    expect(store.length, HiddenSessionStore.maxEntries);
  });
}
