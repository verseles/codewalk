import 'package:codewalk/platform/storage/metadata_store.dart';
import 'package:codewalk/platform/storage/payload_store.dart';
import 'package:flutter_test/flutter_test.dart';

import 'storage_fakes.dart';

final class RacingPayloadStore implements PayloadStore {
  String? value = '{bad';
  int removals = 0;

  @override
  Future<String?> read(String key) async {
    final snapshot = value;
    // Model a valid replacement committed after the read took its snapshot and
    // before readJson resumes to decode that older malformed snapshot.
    await write(key, '{"new":"valid"}');
    return snapshot;
  }

  @override
  Future<PayloadWriteResult> write(String key, String input) async {
    value = input;
    return PayloadWriteResult.written;
  }

  @override
  Future<void> remove(String key) async {
    removals++;
    value = null;
  }
}

void main() {
  test(
    'fallback exact ceiling, no-op, type safety and legacy preservation',
    () async {
      final backend = FakeMetadataBackend()
        ..values['cached_sessions'] = 'legacy';
      final store = PreferencesPayloadStore(V2MetadataStore(backend: backend));
      final exact = '漢' * V2PayloadLimits.maxPreferenceChars;
      expect(
        await store.write('cw2.payload', exact),
        PayloadWriteResult.written,
      );
      expect(
        await store.write('cw2.payload', exact),
        PayloadWriteResult.unchanged,
      );
      expect(
        await store.write('cw2.payload', '$exact!'),
        PayloadWriteResult.refusedOversized,
      );
      expect(await store.read('cw2.payload'), exact);
      backend.values['cw2.oversized'] = '$exact!';
      backend.values['cw2.wrong'] = 42;
      expect(await store.read('cw2.oversized'), isNull);
      expect(await store.read('cw2.wrong'), isNull);
      await store.remove('cw2.payload');
      expect(backend.values['cached_sessions'], 'legacy');
      expect(backend.writes.every((key) => key.startsWith('cw2.')), isTrue);
      expect(backend.removals, ['cw2.payload']);
    },
  );

  test(
    'JSON corruption is a non-destructive miss; valid JSON is preserved',
    () async {
      final backend = FakeMetadataBackend()..values['cw2.bad'] = '{bad';
      final store = PreferencesPayloadStore(V2MetadataStore(backend: backend));
      expect(await store.readJson('cw2.bad'), isNull);
      expect(backend.values['cw2.bad'], '{bad');
      await store.writeJson('cw2.good', {'text': '你好', 'explicitOff': false});
      expect(await store.readJson('cw2.good'), {
        'text': '你好',
        'explicitOff': false,
      });
      expect(await store.readJson('cw2.bad'), isNull);
      expect(backend.values['cw2.bad'], '{bad');
      expect(backend.removals, isEmpty);
    },
  );

  test(
    'fallback failure preserves previous value without ephemeral success',
    () async {
      final backend = FakeMetadataBackend()..values['cw2.payload'] = 'old';
      final store = PreferencesPayloadStore(V2MetadataStore(backend: backend));
      backend.failWrite = 'cw2.payload';
      await expectLater(store.write('cw2.payload', 'new'), throwsStateError);
      expect(await store.read('cw2.payload'), 'old');
      backend.failWrite = null;
      expect(
        await store.write('cw2.payload', 'new'),
        PayloadWriteResult.written,
      );
    },
  );

  test('malformed read snapshot never deletes a newer valid payload', () async {
    final store = RacingPayloadStore();
    expect(await store.readJson('cw2.race'), isNull);
    expect(store.value, '{"new":"valid"}');
    expect(store.removals, 0);
    expect(await store.readJson('cw2.race'), {'new': 'valid'});
  });
}
