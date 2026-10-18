@TestOn('vm')
library;

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

UnrestrictedOwnership record(UnrestrictedStage stage) => UnrestrictedOwnership(
  stage: stage,
  base: unrestrictedFingerprint(base),
  owned: unrestrictedFingerprint(owned),
);

void main() {
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
        await store.put(ref('one'), record(UnrestrictedStage.owned)),
        isFalse,
      );
      await store.initialize();
      expect(
        await store.put(ref('one'), record(UnrestrictedStage.owned)),
        isTrue,
      );
      final again = UnrestrictedOwnershipStore(
        store: V2MetadataStore(backend: backend),
      );
      await again.initialize();
      expect(again.recordFor(ref('one'))!.stage, UnrestrictedStage.owned);
      expect(await again.remove(ref('one')), isTrue);
      expect(again.recordFor(ref('one')), isNull);
      expect(await again.remove(ref('one')), isTrue);
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
        expect(store.recordFor(ref('one')), isNull);
        expect(
          await store.put(ref('one'), record(UnrestrictedStage.applying)),
          isFalse,
        );
        expect(await store.remove(ref('one')), isFalse);
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
        await store.put(ref('one'), record(UnrestrictedStage.applying)),
        isFalse,
      );
      expect(store.recordFor(ref('one')), isNull);
    });

    test('records stay bounded without eviction', () async {
      final store = UnrestrictedOwnershipStore(
        store: V2MetadataStore(backend: FakeMetadataBackend()),
      );
      await store.initialize();
      for (var i = 0; i < UnrestrictedOwnershipStore.maxRecords; i++) {
        expect(
          await store.put(ref('s$i'), record(UnrestrictedStage.owned)),
          isTrue,
        );
      }
      expect(
        await store.put(ref('extra'), record(UnrestrictedStage.owned)),
        isFalse,
      );
      expect(store.recordFor(ref('s0')), isNotNull);
      // Updating an existing record still works at the bound.
      expect(
        await store.put(ref('s0'), record(UnrestrictedStage.removing)),
        isTrue,
      );
    });
  });
}
