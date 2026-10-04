@TestOn('vm')
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:codewalk/platform/migration/legacy_source.dart';
import 'package:codewalk/platform/migration/migration_report.dart';
import 'package:codewalk/platform/migration/v1_data_importer.dart';
import 'package:codewalk/platform/storage/payload_io.dart';
import 'package:codewalk/platform/storage/payload_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../storage/payload_io_test.dart' as storage;
import 'migration_fakes.dart';

void main() {
  test(
    'unreadable file destination stays unresolved without overwrite or checkpoint',
    () async {
      const key = 'session_composer_draft::existing';
      final fixture = MigrationFixture(preferences: {key: '{"text":"legacy"}'});
      final destination = V1DataImporter.recoveredDraftKey(key);
      final saved = Uint8List.fromList(
        utf8.encode('{"text":"newer user edit"}'),
      );
      final files = storage.FakeFiles()
        ..values[destination] = saved
        ..failRead = true;
      final metadata = fixture.metadata;
      final importer = V1DataImporter(
        source: LegacySource(preferences: fixture.preferences),
        metadata: metadata,
        payloads: FilePayloadStore(
          beforeMutation: metadata.ensureSchema,
          backend: files,
        ),
        exclusiveBeforeConsumers: true,
      );
      final failed = await importer.run();
      expect(files.values[destination], same(saved));
      expect(files.replacements, 0);
      expect(files.removals, 0);
      expect(fixture.backend.values[V1DataImporter.journalKey], isNull);
      expect(
        failed.pending.any(
          (item) => item.reason == MigrationPendingReason.destinationFailed,
        ),
        isTrue,
      );
      files.failRead = false;
      final retry = await importer.run();
      expect(files.values[destination], same(saved));
      expect(files.replacements, 0);
      expect(retry.counts['existingPreserved'], 1);
    },
  );

  test(
    'invalid or oversized existing preferences are preserved by the importer',
    () async {
      const key = 'session_composer_draft::existing';
      for (final saved in <Object>[
        42,
        'x' * (V2PayloadLimits.maxPreferenceChars + 1),
      ]) {
        final fixture = MigrationFixture(
          preferences: {key: '{"text":"legacy"}'},
        );
        final destination = V1DataImporter.recoveredDraftKey(key);
        fixture.backend.values[destination] = saved;
        final metadata = fixture.metadata;
        final report = await V1DataImporter(
          source: LegacySource(preferences: fixture.preferences),
          metadata: metadata,
          payloads: PreferencesPayloadStore(metadata),
          exclusiveBeforeConsumers: true,
        ).run();
        expect(fixture.backend.values[destination], saved);
        expect(report.counts['existingPreserved'], 1);
        expect(fixture.backend.removals, isEmpty);
      }
    },
  );

  test(
    'unported legacy settings are reported with opaque unresolved identities',
    () async {
      final fixture = MigrationFixture(
        preferences: {
          'experience_settings': jsonEncode({
            'composerAutoApprovePermissions': false,
            'dataSaverEnabled': true,
            'loggingEnabled': false,
            'desktopPanes': {'inspector': true},
          }),
        },
      );
      final report = await fixture.importer().run();
      expect(
        fixture.backend.values['cw2.settings.composerAutoApprovePermissions'],
        false,
      );
      final unsupported = report.pending.where(
        (item) => item.reason == MigrationPendingReason.unsupportedSettings,
      );
      expect(unsupported.map((item) => item.id).toSet(), {
        for (final field in [
          'dataSaverEnabled',
          'loggingEnabled',
          'desktopPanes',
        ])
          V1DataImporter.itemId(MigrationCategory.settings, field),
      });
      expect(jsonEncode(report.toJson()), isNot(contains('desktopPanes')));
    },
  );
}
