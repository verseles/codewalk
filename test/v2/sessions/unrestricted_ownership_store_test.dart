@TestOn('vm')
library;

import 'dart:convert';

import 'package:codewalk/platform/sessions/unrestricted_ownership_store.dart';
import 'package:codewalk/platform/storage/metadata_store.dart';
import 'package:codewalk/shared/sessions/session_unrestricted.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harness_opencode/harness_opencode.dart';

import '../storage/storage_fakes.dart';

SessionRef ref(String id) =>
    SessionRef(const HostId('h'), const HarnessInstanceId('h'), id);

Map<String, String> rule(String action, String resource, String effect) => {
  'action': action,
  'resource': resource,
  'effect': effect,
};

final base = OpenCodeSessionRules.parse([rule('bash', '*', 'ask')]);
final owned = base.withWildcardAllow();

EndpointProfile profile(String url, {String label = 'A', int revision = 0}) =>
    EndpointProfile(
      id: 'profile_a1',
      label: label,
      endpoint: Uri.parse(url),
      bindingRevision: revision,
    );

final a = unrestrictedBindingFor(profile('http://a.test/'));
final b = unrestrictedBindingFor(profile('http://b.test/', revision: 1));

UnrestrictedOwnership record(UnrestrictedStage stage) => UnrestrictedOwnership(
  stage: stage,
  base: unrestrictedFingerprint(base),
  owned: unrestrictedFingerprint(owned),
);

class _CommitThenThrowBackend implements MetadataBackend {
  final values = <String, Object>{};
  bool failNextLedgerWrite = true;

  @override
  Future<Object?> read(String key) async => values[key];

  @override
  Future<void> write(String key, Object value) async {
    values[key] = value;
    if (key == UnrestrictedOwnershipStore.key && failNextLedgerWrite) {
      failNextLedgerWrite = false;
      throw StateError('controlled lost ledger acknowledgement');
    }
  }

  @override
  Future<void> remove(String key) async => values.remove(key);
}

void main() {
  test(
    'committed ownership survives an unknown acknowledgement and a later write',
    () async {
      final backend = _CommitThenThrowBackend();
      UnrestrictedOwnershipStore fresh() =>
          UnrestrictedOwnershipStore(store: V2MetadataStore(backend: backend));
      final store = fresh();
      await store.initialize();
      await store.put(a, ref('one'), record(UnrestrictedStage.owned));
      final beforeSecondWrite = fresh();
      await beforeSecondWrite.initialize();
      expect(beforeSecondWrite.recordFor(a, ref('one')), isNotNull);
      await store.put(a, ref('two'), record(UnrestrictedStage.applying));
      final reopened = fresh();
      await reopened.initialize();
      expect(reopened.recordFor(a, ref('one')), isNotNull);
      expect(reopened.recordFor(a, ref('two')), isNotNull);
    },
  );

  group('classify', () {
    test('without a record a trailing wildcard belongs to someone else', () {
      expect(
        classifyUnrestricted(owned, null).phase,
        SessionUnrestrictedPhase.elsewhere,
      );
      expect(
        classifyUnrestricted(base, null).phase,
        SessionUnrestrictedPhase.off,
      );
      expect(
        classifyUnrestricted(OpenCodeSessionRules.unrecognized, null).phase,
        SessionUnrestrictedPhase.unavailable,
      );
    });

    test('an owned record matches only the exact rules it wrote', () {
      final mine = record(UnrestrictedStage.owned);
      expect(
        classifyUnrestricted(owned, mine).phase,
        SessionUnrestrictedPhase.on,
      );
      final edited = OpenCodeSessionRules.parse([
        rule('bash', '*', 'deny'),
        rule('*', '*', 'allow'),
      ]);
      final conflict = classifyUnrestricted(edited, mine);
      expect(conflict.phase, SessionUnrestrictedPhase.conflict);
      expect(conflict.record, same(mine));
      final removed = classifyUnrestricted(base, mine);
      expect(removed.phase, SessionUnrestrictedPhase.off);
      expect(removed.record, isNull);
    });

    test('an owned record back at its base was removed elsewhere', () {
      final withEarlier = OpenCodeSessionRules.parse([
        rule('*', '*', 'allow'),
        rule('bash', 'rm *', 'deny'),
      ]);
      final mine = UnrestrictedOwnership(
        stage: UnrestrictedStage.owned,
        base: unrestrictedFingerprint(withEarlier),
        owned: unrestrictedFingerprint(withEarlier.withWildcardAllow()),
      );
      final reading = classifyUnrestricted(withEarlier, mine);
      expect(reading.phase, SessionUnrestrictedPhase.off);
      expect(reading.record, isNull);
    });

    test('pending stages resolve by what the rules show', () {
      final applying = record(UnrestrictedStage.applying);
      final applied = classifyUnrestricted(owned, applying);
      expect(applied.phase, SessionUnrestrictedPhase.on);
      expect(applied.record!.stage, UnrestrictedStage.owned);
      final notYet = classifyUnrestricted(base, applying);
      expect(notYet.phase, SessionUnrestrictedPhase.off);
      expect(notYet.record, same(applying));

      final removing = record(UnrestrictedStage.removing);
      final gone = classifyUnrestricted(base, removing);
      expect(gone.phase, SessionUnrestrictedPhase.off);
      expect(gone.record, isNull);
      final kept = classifyUnrestricted(owned, removing);
      expect(kept.phase, SessionUnrestrictedPhase.on);
      expect(kept.record!.stage, UnrestrictedStage.owned);
    });
  });

  group('store', () {
    test('persists records and reloads them', () async {
      final backend = FakeMetadataBackend();
      final store = UnrestrictedOwnershipStore(
        store: V2MetadataStore(backend: backend),
      );
      expect(
        await store.put(a, ref('one'), record(UnrestrictedStage.owned)),
        isFalse,
      );
      await store.initialize();
      expect(
        await store.put(a, ref('one'), record(UnrestrictedStage.owned)),
        isTrue,
      );
      final again = UnrestrictedOwnershipStore(
        store: V2MetadataStore(backend: backend),
      );
      await again.initialize();
      expect(again.recordFor(a, ref('one'))!.stage, UnrestrictedStage.owned);
      expect(await again.remove(a, ref('one')), isTrue);
      expect(again.recordFor(a, ref('one')), isNull);
      expect(await again.remove(a, ref('one')), isTrue);
    });

    test('an unreadable blob is never overwritten', () async {
      for (final raw in ['not json', '{"k":{"stage":"x"}}', '[]']) {
        final backend = FakeMetadataBackend()
          ..values[UnrestrictedOwnershipStore.key] = raw;
        final store = UnrestrictedOwnershipStore(
          store: V2MetadataStore(backend: backend),
        );
        await store.initialize();
        expect(store.unreadable, isTrue, reason: raw);
        expect(store.recordFor(a, ref('one')), isNull);
        expect(
          await store.put(a, ref('one'), record(UnrestrictedStage.applying)),
          isFalse,
        );
        expect(await store.remove(a, ref('one')), isFalse);
        expect(backend.values[UnrestrictedOwnershipStore.key], raw);
      }
    });

    test('a read failure fails closed', () async {
      final store = UnrestrictedOwnershipStore(
        store: V2MetadataStore(backend: FakeMetadataBackend()..failRead = true),
      );
      await store.initialize();
      expect(store.loaded, isTrue);
      expect(store.unreadable, isTrue);
    });

    test('a failed write changes nothing', () async {
      final store = UnrestrictedOwnershipStore(
        store: V2MetadataStore(
          backend: FakeMetadataBackend()
            ..failWrite = UnrestrictedOwnershipStore.key,
        ),
      );
      await store.initialize();
      expect(
        await store.put(a, ref('one'), record(UnrestrictedStage.applying)),
        isFalse,
      );
      expect(store.recordFor(a, ref('one')), isNull);
    });

    test('records stay bounded without eviction', () async {
      final store = UnrestrictedOwnershipStore(
        store: V2MetadataStore(backend: FakeMetadataBackend()),
      );
      await store.initialize();
      for (var i = 0; i < UnrestrictedOwnershipStore.maxRecords; i++) {
        expect(
          await store.put(a, ref('s$i'), record(UnrestrictedStage.owned)),
          isTrue,
        );
      }
      expect(
        await store.put(a, ref('extra'), record(UnrestrictedStage.owned)),
        isFalse,
      );
      expect(store.recordFor(a, ref('s0')), isNotNull);
      // Updating an existing record still works at the bound.
      expect(
        await store.put(a, ref('s0'), record(UnrestrictedStage.removing)),
        isTrue,
      );
    });

    test('a binding never sees or changes another binding record', () async {
      final backend = FakeMetadataBackend();
      final store = UnrestrictedOwnershipStore(
        store: V2MetadataStore(backend: backend),
      );
      await store.initialize();
      expect(
        await store.put(a, ref('one'), record(UnrestrictedStage.owned)),
        isTrue,
      );
      expect(store.recordFor(b, ref('one')), isNull);
      expect(await store.remove(b, ref('one')), isTrue);
      expect(
        await store.put(b, ref('one'), record(UnrestrictedStage.applying)),
        isTrue,
      );
      final again = UnrestrictedOwnershipStore(
        store: V2MetadataStore(backend: backend),
      );
      await again.initialize();
      expect(again.recordFor(a, ref('one'))!.stage, UnrestrictedStage.owned);
      expect(again.recordFor(b, ref('one'))!.stage, UnrestrictedStage.applying);
    });

    test('the binding follows the endpoint and revision, not the label', () {
      final renamed = profile('http://a.test/', label: 'Renamed');
      expect(unrestrictedBindingFor(renamed), a);
      // A return to the first URL after an edit is still another binding.
      expect(
        unrestrictedBindingFor(profile('http://a.test/', revision: 2)),
        isNot(a),
      );
      expect(unrestrictedBindingFor(profile('http://a.test/proxy/')), isNot(a));
    });

    test(
      'records from before binding scopes are kept and never claimed',
      () async {
        final legacy = jsonEncode({
          ref('one').storageKey: {
            'stage': 'owned',
            'base': record(UnrestrictedStage.owned).base,
            'owned': record(UnrestrictedStage.owned).owned,
          },
        });
        final backend = FakeMetadataBackend()
          ..values[UnrestrictedOwnershipStore.key] = legacy;
        final store = UnrestrictedOwnershipStore(
          store: V2MetadataStore(backend: backend),
        );
        await store.initialize();
        expect(store.unreadable, isFalse);
        expect(store.recordFor(a, ref('one')), isNull);
        expect(await store.remove(a, ref('one')), isTrue);
        expect(
          await store.put(a, ref('two'), record(UnrestrictedStage.applying)),
          isTrue,
        );
        final stored =
            backend.values[UnrestrictedOwnershipStore.key]! as String;
        expect(
          (jsonDecode(stored) as Map)[ref('one').storageKey],
          (jsonDecode(legacy) as Map)[ref('one').storageKey],
        );
      },
    );

    test('a write the caller no longer wants is not stored', () async {
      final backend = FakeMetadataBackend();
      final store = UnrestrictedOwnershipStore(
        store: V2MetadataStore(backend: backend),
      );
      await store.initialize();
      expect(
        await store.put(
          a,
          ref('one'),
          record(UnrestrictedStage.owned),
          when: () => false,
        ),
        isFalse,
      );
      expect(store.recordFor(a, ref('one')), isNull);
      expect(backend.writes, isEmpty);
    });

    test('an unknown write outcome refuses every later write', () async {
      final backend = _LostOutcomeBackend();
      final store = UnrestrictedOwnershipStore(
        store: V2MetadataStore(backend: backend),
      );
      await store.initialize();
      expect(
        await store.put(a, ref('one'), record(UnrestrictedStage.owned)),
        isFalse,
      );
      expect(store.unreadable, isTrue);
      backend.lost = false;
      expect(
        await store.put(a, ref('two'), record(UnrestrictedStage.owned)),
        isFalse,
      );
    });
  });
}

/// A write that fails and leaves a read that fails too: whether it was
/// stored cannot be established.
class _LostOutcomeBackend implements MetadataBackend {
  final values = <String, Object>{};
  bool lost = true;
  bool _failed = false;

  @override
  Future<Object?> read(String key) async {
    if (lost && _failed && key == UnrestrictedOwnershipStore.key) {
      throw StateError('read after a lost write');
    }
    return values[key];
  }

  @override
  Future<void> write(String key, Object value) async {
    values[key] = value;
    if (key == UnrestrictedOwnershipStore.key && lost) {
      _failed = true;
      throw StateError('lost acknowledgement');
    }
  }

  @override
  Future<void> remove(String key) async => values.remove(key);
}
