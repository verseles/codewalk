import 'dart:convert';

import 'package:codewalk/platform/migration/legacy_source.dart';
import 'package:codewalk/platform/migration/migration_report.dart';
import 'package:codewalk/platform/migration/v1_data_importer.dart';
import 'package:codewalk/platform/storage/metadata_store.dart';
import 'package:codewalk/platform/storage/payload_store.dart';
import 'package:flutter_test/flutter_test.dart';

import 'migration_fakes.dart';

void main() {
  test(
    'real preferences payload boundary persists recovery across new stores',
    () async {
      const sourceKey = 'session_composer_draft::session::server::directory';
      final source = FakeLegacyPreferencesReader({
        sourceKey: '{"text":"retained original","shellMode":true}',
      });
      final original = source.snapshot;
      final backend = FakeMigrationMetadataBackend();

      V1DataImporter importer() {
        final metadata = V2MetadataStore(backend: backend);
        return V1DataImporter(
          source: LegacySource(preferences: source),
          metadata: metadata,
          payloads: PreferencesPayloadStore(metadata),
          exclusiveBeforeConsumers: true,
        );
      }

      await importer().run();
      final destinationKey = V1DataImporter.recoveredDraftKey(sourceKey);
      final destination = jsonDecode(backend.values[destinationKey]! as String);
      expect(destination['text'], 'retained original');
      expect(destination['shellMode'], isTrue);
      expect(destination['mapping'], 'unmapped');

      // A later edit is preserved by a new importer and new destination stores.
      final edited = jsonEncode({'text': 'later user edit'});
      backend.values[destinationKey] = edited;
      final committedWrites = backend.writes.length;
      await importer().run();
      expect(backend.values[destinationKey], edited);
      expect(backend.writes.skip(committedWrites), isEmpty);
      expect(source.snapshot, original);
      expect(backend.removals, isEmpty);
      expect(
        backend.values.keys.every((key) => key.startsWith('cw2.')),
        isTrue,
      );
    },
  );

  test(
    'real preferences refusal leaves large source retryable and unacknowledged',
    () async {
      const sourceKey = 'session_composer_draft::large-session';
      // The raw v1 value fits the source ceiling but its recovered wrapper exceeds
      // the actual 1 MiB Web/preferences destination ceiling.
      final raw = jsonEncode({
        'text': 'x' * (V2PayloadLimits.maxPreferenceChars - 32),
      });
      expect(raw.length, lessThan(V2PayloadLimits.maxPreferenceChars));
      final source = FakeLegacyPreferencesReader({sourceKey: raw});
      final original = source.snapshot;
      final backend = FakeMigrationMetadataBackend();
      final metadata = V2MetadataStore(backend: backend);
      final importer = V1DataImporter(
        source: LegacySource(preferences: source),
        metadata: metadata,
        payloads: PreferencesPayloadStore(metadata),
        exclusiveBeforeConsumers: true,
      );

      final first = await importer.run();
      final second = await importer.run();
      final itemId = V1DataImporter.itemId(MigrationCategory.drafts, sourceKey);
      for (final report in [first, second]) {
        expect(
          report.pending.where(
            (item) =>
                item.id == itemId &&
                item.reason == MigrationPendingReason.oversized,
          ),
          hasLength(1),
        );
        expect(report.counts['durableCompleted'], 0);
      }
      expect(
        backend.values[V1DataImporter.recoveredDraftKey(sourceKey)],
        isNull,
      );
      expect(backend.values[V1DataImporter.journalKey], isNull);
      expect(source.reads[sourceKey], 2);
      expect(source.snapshot, original);
      expect(backend.removals, isEmpty);
    },
  );
}
