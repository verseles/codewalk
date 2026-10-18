@TestOn('vm')
library;

import 'package:codewalk/platform/sessions/permission_mode_store.dart';
import 'package:codewalk/platform/storage/metadata_store.dart';
import 'package:codewalk/shared/sessions/permission_mode.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter_test/flutter_test.dart';

import '../storage/storage_fakes.dart';

SessionRef ref(String id) =>
    SessionRef(const HostId('h'), const HarnessInstanceId('h'), id);

V2MetadataStore storeWith(FakeMetadataBackend backend) =>
    V2MetadataStore(backend: backend);

void main() {
  test('new install defaults to Allow all ON with defaultOn source', () async {
    final backend = FakeMetadataBackend();
    final store = PermissionModeStore(store: storeWith(backend));
    expect(store.loaded, isFalse);
    await store.initialize();
    expect(store.loaded, isTrue);
    expect(store.defaultMode, PermissionMode.allowAll);
    final state = store.effectiveFor(ref('ses_one'));
    expect(state.mode, PermissionMode.allowAll);
    expect(state.source, PermissionModeSource.defaultOn);
    expect(state.answering, isTrue);
    expect(PermissionModeStore.globalKey.startsWith('cw2.'), isTrue);
    expect(PermissionModeStore.overridesKey.startsWith('cw2.'), isTrue);
  });

  test('imported OFF stays ask and never answers automatically', () async {
    final backend = FakeMetadataBackend()
      ..values[PermissionModeStore.globalKey] = 'ask';
    final store = PermissionModeStore(store: storeWith(backend));
    await store.initialize();
    expect(store.defaultMode, PermissionMode.ask);
    final state = store.effectiveFor(ref('ses_one'));
    expect(state.mode, PermissionMode.ask);
    expect(state.source, PermissionModeSource.global);
    expect(state.answering, isFalse);
  });

  test('unknown global value fails closed as unavailable', () async {
    final backend = FakeMetadataBackend()
      ..values[PermissionModeStore.globalKey] = 'unrestricted';
    final store = PermissionModeStore(store: storeWith(backend));
    await store.initialize();
    expect(store.loaded, isTrue);
    final state = store.effectiveFor(ref('ses_one'));
    expect(state.mode, isNull);
    expect(state.reason, 'unsupportedMode');
    expect(state.answering, isFalse);
  });

  test(
    'unreadable backend fails closed and never defaults to Allow all',
    () async {
      final backend = FakeMetadataBackend()..failRead = true;
      final store = PermissionModeStore(store: storeWith(backend));
      await store.initialize();
      expect(store.loaded, isTrue);
      final state = store.effectiveFor(ref('ses_one'));
      expect(state.mode, isNull);
      expect(state.answering, isFalse);
    },
  );

  test('per-session override wins and clear restores the global', () async {
    final backend = FakeMetadataBackend();
    final store = PermissionModeStore(store: storeWith(backend));
    await store.initialize();
    expect(
      await store.setSessionMode(ref('ses_one'), PermissionMode.ask),
      isTrue,
    );
    expect(store.effectiveFor(ref('ses_one')).mode, PermissionMode.ask);
    expect(
      store.effectiveFor(ref('ses_one')).source,
      PermissionModeSource.session,
    );
    expect(store.effectiveFor(ref('ses_one')).answering, isFalse);
    // Another session keeps the global default.
    expect(store.effectiveFor(ref('ses_two')).answering, isTrue);
    expect(await store.clearSessionMode(ref('ses_one')), isTrue);
    expect(store.effectiveFor(ref('ses_one')).answering, isTrue);
  });

  test('overrides stay bounded at 256 without eviction', () async {
    final backend = FakeMetadataBackend();
    final store = PermissionModeStore(store: storeWith(backend));
    await store.initialize();
    for (var i = 0; i < PermissionModeStore.maxOverrides; i++) {
      expect(
        await store.setSessionMode(ref('ses_$i'), PermissionMode.ask),
        isTrue,
        reason: 'override $i',
      );
    }
    expect(
      await store.setSessionMode(ref('ses_extra'), PermissionMode.ask),
      isFalse,
    );
    expect(store.hasPersistenceError, isTrue);
    // A silently dropped Ask must never re-enable approvals.
    expect(store.effectiveFor(ref('ses_0')).mode, PermissionMode.ask);
    expect(store.effectiveFor(ref('ses_extra')).answering, isTrue);
  });

  test(
    'failed write keeps the previous value and reports persistence error',
    () async {
      final backend = FakeMetadataBackend();
      final store = PermissionModeStore(store: storeWith(backend));
      await store.initialize();
      backend.failWrite = PermissionModeStore.globalKey;
      expect(await store.setDefaultMode(PermissionMode.ask), isFalse);
      expect(store.defaultMode, PermissionMode.allowAll);
      expect(store.hasPersistenceError, isTrue);
      await store.clearPersistenceError();
      expect(store.hasPersistenceError, isFalse);
      // The requested value is still not in force until it is persisted.
      expect(store.defaultMode, PermissionMode.allowAll);
    },
  );

  test('an overrides read failure keeps writes refused', () async {
    final backend = FakeMetadataBackend()..failRead = true;
    final store = PermissionModeStore(store: storeWith(backend));
    await store.initialize();
    expect(store.effectiveFor(ref('ses_one')).reason, 'unreadableOverrides');
    expect(
      await store.setSessionMode(ref('ses_one'), PermissionMode.ask),
      isFalse,
    );
    expect(await store.clearSessionMode(ref('ses_one')), isFalse);
    expect(backend.values, isEmpty);
  });

  test('corrupt overrides fail closed for every session', () async {
    final backend = FakeMetadataBackend()
      ..values[PermissionModeStore.overridesKey] = '{"ses_one":"maybe"}';
    final store = PermissionModeStore(store: storeWith(backend));
    await store.initialize();
    final state = store.effectiveFor(ref('ses_one'));
    expect(store.defaultMode, PermissionMode.allowAll);
    expect(state.mode, isNull);
    expect(state.reason, 'unreadableOverrides');
    expect(state.answering, isFalse);
    expect(store.effectiveFor(ref('ses_two')).answering, isFalse);
    // Rewriting would drop the unreadable override, so writes are refused.
    expect(
      await store.setSessionMode(ref('ses_two'), PermissionMode.ask),
      isFalse,
    );
    expect(
      backend.values[PermissionModeStore.overridesKey],
      '{"ses_one":"maybe"}',
    );
  });

  test('unparsable overrides blob fails closed and stays untouched', () async {
    final backend = FakeMetadataBackend()
      ..values[PermissionModeStore.overridesKey] = 'not json';
    final store = PermissionModeStore(store: storeWith(backend));
    await store.initialize();
    expect(store.effectiveFor(ref('ses_one')).answering, isFalse);
    expect(await store.clearSessionMode(ref('ses_one')), isFalse);
    expect(backend.values[PermissionModeStore.overridesKey], 'not json');
  });

  test('selecting the already stored mode is a no-op success', () async {
    final backend = FakeMetadataBackend();
    final store = PermissionModeStore(store: storeWith(backend));
    await store.initialize();
    expect(await store.setDefaultMode(PermissionMode.allowAll), isTrue);
    expect(store.hasPersistenceError, isFalse);
    expect(
      await store.setSessionMode(ref('ses_one'), PermissionMode.ask),
      isTrue,
    );
    expect(
      await store.setSessionMode(ref('ses_one'), PermissionMode.ask),
      isTrue,
    );
    expect(store.hasPersistenceError, isFalse);
    expect(store.effectiveFor(ref('ses_one')).mode, PermissionMode.ask);
  });
}
