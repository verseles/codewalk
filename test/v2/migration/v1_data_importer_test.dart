import 'dart:convert';

import 'package:codewalk/platform/migration/legacy_source.dart';
import 'package:codewalk/platform/migration/migration_report.dart';
import 'package:codewalk/platform/migration/v1_data_importer.dart';
import 'package:codewalk/platform/storage/endpoint_credentials.dart';
import 'package:codewalk/platform/storage/metadata_store.dart';
import 'package:codewalk/platform/storage/payload_store.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'migration_fakes.dart';

void main() {
  for (final failure in ['unavailable', 'oversized']) {
    test(
      'a $failure newer preference never imports an older file draft',
      () async {
        const sourceKey = 'session_composer_draft::newer-preference';
        final newer = jsonEncode({
          'text': failure == 'oversized'
              ? 'n' * V2PayloadLimits.maxPayloadChars
              : 'newer preference draft',
        });
        final fixture = MigrationFixture(
          preferences: {sourceKey: newer},
          legacyPayloads: {sourceKey: '{"text":"older file draft"}'},
          knownPayloadKeys: {sourceKey},
        );
        if (failure == 'unavailable') {
          fixture.preferences.failReads.add(sourceKey);
        }
        final originalPreferences = fixture.preferences.snapshot;
        final originalFiles = fixture.legacyPayloads.snapshot;

        final report = await fixture.importer().run();

        expectMigrationPending(
          report,
          MigrationCategory.drafts,
          sourceKey,
          failure == 'oversized'
              ? MigrationPendingReason.oversized
              : MigrationPendingReason.sourceUnavailable,
        );
        expect(fixture.legacyPayloads.reads[sourceKey], isNull);
        expect(fixture.payloads.values, isEmpty);
        expect(fixture.payloads.writeAttempts, isEmpty);
        expect(fixture.completed, isEmpty);
        expect(fixture.preferences.snapshot, originalPreferences);
        expect(fixture.legacyPayloads.snapshot, originalFiles);

        if (failure == 'unavailable') {
          fixture.preferences.failReads.clear();
          await fixture.importer().run();
          expect(fixture.draft(sourceKey)['text'], 'newer preference draft');
          expect(fixture.legacyPayloads.reads[sourceKey], isNull);
          expect(fixture.preferences.snapshot, originalPreferences);
          expect(fixture.legacyPayloads.snapshot, originalFiles);
        }
      },
    );
  }

  test(
    'missing secure access cannot promote an inline password into the vault',
    () async {
      final fixture = MigrationFixture(
        preferences: {
          'server_profiles': jsonEncode([
            migrationProfile(password: 'stale-inline-secret'),
          ]),
        },
        secure: {
          migrationSecureKey('password'): 'unavailable-newer-secure-secret',
        },
      );
      final originalPreferences = fixture.preferences.snapshot;
      final originalSecure = fixture.secure.snapshot;

      final report = await fixture.importer(includeSecureReader: false).run();

      expectMigrationPending(
        report,
        MigrationCategory.credentials,
        'password:profile-one',
        MigrationPendingReason.sourceUnavailable,
      );
      if (kIsWeb) {
        expectMigrationPending(
          report,
          MigrationCategory.credentials,
          'password:profile-one',
          MigrationPendingReason.ephemeralCredential,
        );
      }
      expect(fixture.secure.reads, isEmpty);
      expect(fixture.credentialBackend.reads, isEmpty);
      expect(fixture.credentialBackend.writes, isEmpty);
      expect(fixture.credentialBackend.values, isEmpty);
      expect(
        fixture.completed.containsKey(
          V1DataImporter.itemId(
            MigrationCategory.credentials,
            'password:profile-one',
          ),
        ),
        isFalse,
      );
      expect(
        jsonEncode(fixture.backend.values),
        isNot(contains('inline-secret')),
      );
      expect(fixture.preferences.snapshot, originalPreferences);
      expect(fixture.secure.snapshot, originalSecure);
    },
  );

  test(
    'missing exclusive window fails before any source or destination access',
    () async {
      const legacyKey = 'session_composer_draft::exclusive-window';
      final fixture = MigrationFixture(
        preferences: {
          'experience_settings': '{"composerAutoApprovePermissions":false}',
          'server_profiles': jsonEncode([
            migrationProfile(password: 'inline-secret'),
          ]),
          legacyKey: '{"text":"private draft"}',
        },
        secure: {migrationSecureKey('password'): 'secure-secret'},
        legacyPayloads: {legacyKey: '{"text":"private file draft"}'},
        knownPayloadKeys: {legacyKey},
      );
      final originalPreferences = fixture.preferences.snapshot;
      final originalSecure = fixture.secure.snapshot;
      final originalPayloads = fixture.legacyPayloads.snapshot;

      await expectLater(
        fixture.importer(exclusiveBeforeConsumers: false).run(),
        migrationFailure(MigrationFailure.exclusivityRequired),
      );

      expect(fixture.preferences.reads, isEmpty);
      expect(fixture.preferences.keyReads, 0);
      expect(fixture.secure.reads, isEmpty);
      expect(fixture.legacyPayloads.reads, isEmpty);
      expect(fixture.legacyPayloads.lastClaimedKeys, isNull);
      expect(fixture.backend.reads, isEmpty);
      expect(fixture.backend.writeAttempts, isEmpty);
      expect(fixture.backend.values, isEmpty);
      expect(fixture.backend.removals, isEmpty);
      expect(fixture.payloads.reads, isEmpty);
      expect(fixture.payloads.writeAttempts, isEmpty);
      expect(fixture.payloads.values, isEmpty);
      expect(fixture.payloads.removals, isEmpty);
      expect(fixture.credentialBackend.reads, isEmpty);
      expect(fixture.credentialBackend.writes, isEmpty);
      expect(fixture.credentialBackend.values, isEmpty);
      expect(fixture.credentialBackend.removals, isEmpty);
      expect(
        fixture.backend.values.containsKey(V1DataImporter.journalKey),
        isFalse,
      );
      expect(
        fixture.backend.values.containsKey(V1DataImporter.reportKey),
        isFalse,
      );
      expect(fixture.preferences.snapshot, originalPreferences);
      expect(fixture.secure.snapshot, originalSecure);
      expect(fixture.legacyPayloads.snapshot, originalPayloads);
    },
  );

  group('selected settings', () {
    for (final failure in ['unavailable', 'oversized', 'malformed']) {
      test(
        '$failure experience settings never checkpoint older global values',
        () async {
          final latest = jsonEncode({
            'themeMode': 'dark',
            'localeCode': 'pt-BR',
            'composerAutoApprovePermissions': false,
          });
          final fixture = MigrationFixture(
            preferences: {
              'experience_settings': failure == 'oversized'
                  ? 'x' * (V2PayloadLimits.maxPayloadChars + 1)
                  : failure == 'malformed'
                  ? '{broken'
                  : latest,
              'theme_mode': 'light',
              'locale_code': 'en',
            },
          );
          if (failure == 'unavailable') {
            fixture.preferences.failReads.add('experience_settings');
          }
          final original = fixture.preferences.snapshot;

          final pending = await fixture.importer().run();

          expectMigrationPending(
            pending,
            MigrationCategory.settings,
            'experience_settings',
            failure == 'oversized'
                ? MigrationPendingReason.oversized
                : failure == 'malformed'
                ? MigrationPendingReason.malformed
                : MigrationPendingReason.sourceUnavailable,
          );
          expect(fixture.backend.values['cw2.settings.themeMode'], isNull);
          expect(fixture.backend.values['cw2.settings.localeCode'], isNull);
          expect(fixture.preferences.reads['theme_mode'], isNull);
          expect(fixture.preferences.reads['locale_code'], isNull);
          expect(fixture.completed, isEmpty);
          expect(fixture.preferences.snapshot, original);

          fixture.preferences.failReads.clear();
          fixture.preferences.values['experience_settings'] = latest;
          final repaired = fixture.preferences.snapshot;
          await fixture.importer().run();
          expect(fixture.backend.values['cw2.settings.themeMode'], 'dark');
          expect(fixture.backend.values['cw2.settings.localeCode'], 'pt-BR');
          expect(
            fixture
                .backend
                .values['cw2.settings.composerAutoApprovePermissions'],
            isFalse,
          );
          expect(fixture.preferences.reads['theme_mode'], isNull);
          expect(fixture.preferences.reads['locale_code'], isNull);
          expect(fixture.preferences.snapshot, repaired);
        },
      );
    }

    test(
      'a valid partial experience document does not revive older globals',
      () async {
        final fixture = MigrationFixture(
          preferences: {
            'experience_settings': '{"composerAutoApprovePermissions":false}',
            'theme_mode': 'light',
            'locale_code': 'en',
          },
        );

        await fixture.importer().run();

        expect(fixture.backend.values['cw2.settings.themeMode'], isNull);
        expect(fixture.backend.values['cw2.settings.localeCode'], isNull);
        expect(fixture.preferences.reads['theme_mode'], isNull);
        expect(fixture.preferences.reads['locale_code'], isNull);
        expect(
          fixture.backend.values['cw2.settings.composerAutoApprovePermissions'],
          isFalse,
        );
      },
    );

    test('explicit AllowAll OFF survives import and a second run', () async {
      final fixture = MigrationFixture(
        preferences: {
          'experience_settings': jsonEncode({
            'composerAutoApprovePermissions': false,
            'useAmoledDark': true,
            'systemFontScale': 1.2,
            'localeCode': 'pt-BR',
            'shortcuts': {
              'focus_input': 'Ctrl+Enter',
              'send': 'unsupported shortcut',
            },
            'notifications': {'permissions': false},
            'unknownFeature': 'not selected',
          }),
        },
      );
      final original = fixture.preferences.snapshot;

      await fixture.importer().run();
      final writes = fixture.backend.writes.length;
      final second = await fixture.importer().run();

      expect(
        fixture.backend.values['cw2.settings.composerAutoApprovePermissions'],
        isFalse,
      );
      expect(fixture.backend.values['cw2.settings.useAmoledDark'], isTrue);
      expect(fixture.backend.values['cw2.settings.systemFontScale'], 1.2);
      expect(fixture.backend.values['cw2.settings.localeCode'], 'pt-BR');
      expect(
        jsonDecode(fixture.backend.values['cw2.settings.shortcuts'] as String),
        {'focus_input': 'Ctrl+Enter'},
      );
      expect(
        jsonDecode(
          fixture.backend.values['cw2.settings.notifications'] as String,
        ),
        {'permissions': false},
      );
      expect(
        fixture.backend.values.containsKey('cw2.settings.unknownFeature'),
        isFalse,
      );
      expect(fixture.backend.writes, hasLength(writes));
      expect(second.counts['durableCompleted'], 6);
      expect(fixture.preferences.snapshot, original);
      expect(
        fixture.backend.writes.every((key) => key.startsWith('cw2.')),
        isTrue,
      );
      expect(fixture.backend.removals, isEmpty);
    });

    test('absent AllowAll stays absent without an invented default', () async {
      final fixture = MigrationFixture(
        preferences: {'experience_settings': '{}'},
      );

      final report = await fixture.importer().run();

      expect(
        fixture.backend.values.containsKey(
          'cw2.settings.composerAutoApprovePermissions',
        ),
        isFalse,
      );
      expect(
        report.pending.where(
          (item) => item.category == MigrationCategory.settings,
        ),
        isEmpty,
      );
      expect(fixture.completed, isEmpty);
    });

    for (final invalid in <Object?>['false', 0, null]) {
      test('invalid AllowAll $invalid is distinct from absence', () async {
        final fixture = MigrationFixture(
          preferences: {
            'experience_settings': jsonEncode({
              'composerAutoApprovePermissions': invalid,
            }),
          },
        );
        final original = fixture.preferences.snapshot;

        final report = await fixture.importer().run();

        expect(
          fixture.backend.values.containsKey(
            'cw2.settings.composerAutoApprovePermissions',
          ),
          isFalse,
        );
        expectMigrationPending(
          report,
          MigrationCategory.settings,
          'composerAutoApprovePermissions',
          MigrationPendingReason.malformed,
        );
        expect(fixture.completed, isEmpty);
        expect(fixture.preferences.snapshot, original);
      });
    }

    test(
      'legacy locale and theme fallbacks are imported without defaults',
      () async {
        final fixture = MigrationFixture(
          preferences: {'theme_mode': 'dark', 'locale_code': 'ar'},
        );

        await fixture.importer().run();

        expect(fixture.backend.values['cw2.settings.themeMode'], 'dark');
        expect(fixture.backend.values['cw2.settings.localeCode'], 'ar');
        expect(
          fixture.backend.values.containsKey('cw2.settings.appDensity'),
          isFalse,
        );
      },
    );

    for (final unsafeUrl in [
      'https://user:private-url-password@voice.invalid/v1',
      'https://voice.invalid/v1?api_key=private-query-secret',
      'https://voice.invalid/v1#private-fragment',
    ]) {
      test('voice settings do not copy URL credentials ($unsafeUrl)', () async {
        final fixture = MigrationFixture(
          preferences: {
            'experience_settings': jsonEncode({
              'speechApiBaseUrl': unsafeUrl,
              'readAloudBaseUrl': unsafeUrl,
            }),
          },
        );
        final original = fixture.preferences.snapshot;

        final report = await fixture.importer().run();

        for (final field in ['speechApiBaseUrl', 'readAloudBaseUrl']) {
          expect(
            fixture.backend.values.containsKey('cw2.settings.$field'),
            isFalse,
          );
          expectMigrationPending(
            report,
            MigrationCategory.settings,
            field,
            MigrationPendingReason.malformed,
          );
        }
        expect(jsonEncode(fixture.backend.values), isNot(contains(unsafeUrl)));
        expect(fixture.preferences.snapshot, original);
      });
    }
  });

  group('profiles and credential boundaries', () {
    test(
      'original URL and port persist with a compatibility review marker',
      () async {
        const password = 'private-endpoint-password';
        const originalUrl = 'https://LEGACY.invalid:4096/nested/path';
        final fixture = MigrationFixture(
          preferences: {
            'server_profiles': jsonEncode([
              migrationProfile(
                url: originalUrl,
                password: 'stale-inline-password',
              ),
            ]),
            'active_server_id': 'profile-one',
            'default_server_id': 'profile-one',
          },
          secure: {
            migrationSecureKey('username'): 'opencode',
            migrationSecureKey('password'): password,
          },
        );
        final originalPreferences = fixture.preferences.snapshot;
        final originalSecure = fixture.secure.snapshot;

        final report = await fixture.importer().run();
        final profile = fixture.profile('profile-one');
        final scope = EndpointCredentialScope(
          endpoint: Uri.parse(originalUrl),
          profileId: profile['id'] as String,
        );

        expect(profile['url'], originalUrl);
        expect(Uri.parse(profile['url'] as String).port, 4096);
        expect(profile['compatibility'], 'needsOpenCode2Check');
        expect(profile['legacyId'], 'profile-one');
        expect(profile.containsKey('basicAuthPassword'), isFalse);
        expect(profile.containsKey('basicAuthUsername'), isFalse);
        if (kIsWeb) {
          expect(fixture.credentialBackend.values, isEmpty);
          expectMigrationPending(
            report,
            MigrationCategory.credentials,
            'password:profile-one',
            MigrationPendingReason.ephemeralCredential,
          );
        } else {
          expect(
            fixture.credentialBackend.values[scope.key(
              EndpointCredentialKind.endpointPassword,
            )],
            password,
          );
          expect(fixture.credentialBackend.values, hasLength(1));
        }
        expect(
          fixture.credentialBackend.values.containsKey(
            scope.key(EndpointCredentialKind.pairingToken),
          ),
          isFalse,
        );
        expect(jsonEncode(fixture.backend.values), isNot(contains(password)));
        expect(report.counts['durableCompleted'], kIsWeb ? 1 : 2);
        expect(fixture.preferences.snapshot, originalPreferences);
        expect(fixture.secure.snapshot, originalSecure);
        expect(fixture.preferences.reads['active_server_id'], isNull);
        expect(fixture.preferences.reads['default_server_id'], isNull);
      },
    );

    for (final changedUrl in [
      'http://legacy.invalid:49374/project',
      'http://different.invalid:4096/project',
      'https://legacy.invalid:4096/project',
    ]) {
      test(
        'existing destination $changedUrl blocks credential transfer',
        () async {
          final fixture = MigrationFixture(
            preferences: {
              'server_profiles': jsonEncode([
                migrationProfile(password: 'source-secret'),
              ]),
            },
          );
          final destinationKey = V1DataImporter.profileKey('profile-one');
          final existing = jsonEncode({
            'id':
                'legacy:${V1DataImporter.itemId(MigrationCategory.profiles, 'profile-one')}',
            'url': changedUrl,
            'label': 'Later user edit',
          });
          fixture.backend.values[destinationKey] = existing;

          final report = await fixture.importer().run();

          expect(fixture.backend.values[destinationKey], existing);
          expect(fixture.credentialBackend.values, isEmpty);
          expect(fixture.credentialBackend.writes, isEmpty);
          expectMigrationPending(
            report,
            MigrationCategory.credentials,
            'password:profile-one',
            MigrationPendingReason.credentialOriginMismatch,
          );
          expect(
            fixture.completed.containsKey(
              V1DataImporter.itemId(
                MigrationCategory.credentials,
                'password:profile-one',
              ),
            ),
            isFalse,
          );
        },
        skip: kIsWeb ? 'Web rejects credentials before origin transfer' : false,
      );
    }

    test(
      'a path-only destination edit retains the same credential origin',
      () async {
        final fixture = MigrationFixture(
          preferences: {
            'server_profiles': jsonEncode([
              migrationProfile(password: 'same-origin-secret'),
            ]),
          },
        );
        final profileId =
            'legacy:${V1DataImporter.itemId(MigrationCategory.profiles, 'profile-one')}';
        final existing = jsonEncode({
          'id': profileId,
          'url': 'http://legacy.invalid:4096/different/path',
        });
        fixture.backend.values[V1DataImporter.profileKey('profile-one')] =
            existing;

        await fixture.importer().run();

        final scope = EndpointCredentialScope(
          endpoint: Uri.parse('http://legacy.invalid:4096'),
          profileId: profileId,
        );
        expect(
          fixture.credentialBackend.values[scope.key(
            EndpointCredentialKind.endpointPassword,
          )],
          'same-origin-secret',
        );
        expect(
          fixture.backend.values[V1DataImporter.profileKey('profile-one')],
          existing,
        );
      },
      skip: kIsWeb ? 'Requires a durable native credential destination' : false,
    );

    test(
      'non-opencode, OAuth, API and voice secrets remain unresolved',
      () async {
        final fixture = MigrationFixture(
          preferences: {
            'server_profiles': jsonEncode([
              migrationProfile(
                id: 'other-user',
                username: 'someone',
                password: 'other-secret',
              ),
              migrationProfile(
                id: 'oauth',
                oauthEnabled: true,
                basicAuthEnabled: false,
              ),
            ]),
            'api_key::private-scope': 'private-api-secret',
            'basic_auth_password::private-scope': 'unbound-secret',
          },
          secure: {
            'codewalk.secure::stt_api_key::openai': 'private-stt-secret',
            'codewalk.secure::tts_api_key::elevenlabs': 'private-tts-secret',
          },
        );
        final originalPreferences = fixture.preferences.snapshot;
        final originalSecure = fixture.secure.snapshot;

        final report = await fixture.importer().run();

        for (final identity in [
          'password:other-user',
          'oauth:oauth',
          'api_key::private-scope',
          'basic_auth_password::private-scope',
          'codewalk.secure::stt_api_key::openai',
          'codewalk.secure::tts_api_key::elevenlabs',
        ]) {
          expectMigrationPending(
            report,
            MigrationCategory.credentials,
            identity,
            MigrationPendingReason.unsupportedCredential,
          );
          expect(
            fixture.completed.containsKey(
              V1DataImporter.itemId(MigrationCategory.credentials, identity),
            ),
            isFalse,
          );
        }
        expect(fixture.credentialBackend.values, isEmpty);
        expect(fixture.credentialBackend.writes, isEmpty);
        expect(fixture.preferences.snapshot, originalPreferences);
        expect(fixture.secure.snapshot, originalSecure);
      },
    );

    test(
      'failed secure source read never falls back to a stale inline secret',
      () async {
        final fixture = MigrationFixture(
          preferences: {
            'server_profiles': jsonEncode([
              migrationProfile(password: 'stale-inline-secret'),
            ]),
          },
          secure: {
            migrationSecureKey('username'): 'opencode',
            migrationSecureKey('password'): 'current-secure-secret',
          },
        );
        fixture.secure.failReads.add(migrationSecureKey('password'));
        final originalPreferences = fixture.preferences.snapshot;
        final originalSecure = fixture.secure.snapshot;

        final report = await fixture.importer().run();

        expectMigrationPending(
          report,
          MigrationCategory.credentials,
          'password:profile-one',
          MigrationPendingReason.sourceUnavailable,
        );
        expect(fixture.credentialBackend.values, isEmpty);
        expect(fixture.credentialBackend.writes, isEmpty);
        expect(
          fixture.completed.containsKey(
            V1DataImporter.itemId(
              MigrationCategory.credentials,
              'password:profile-one',
            ),
          ),
          isFalse,
        );
        expect(fixture.preferences.snapshot, originalPreferences);
        expect(fixture.secure.snapshot, originalSecure);
        expect(
          jsonEncode(fixture.backend.values),
          isNot(contains('stale-inline-secret')),
        );
      },
    );

    test(
      'Web cannot promote a memory vault to durable with a caller flag',
      () async {
        final fixture = MigrationFixture(
          preferences: {
            'server_profiles': jsonEncode([
              migrationProfile(password: 'browser-secret'),
            ]),
          },
        );

        final report = await fixture
            .importer(credentialsAreDurable: true)
            .run();

        expectMigrationPending(
          report,
          MigrationCategory.credentials,
          'password:profile-one',
          MigrationPendingReason.ephemeralCredential,
        );
        expect(fixture.credentialBackend.values, isEmpty);
        expect(fixture.credentialBackend.writes, isEmpty);
        expect(
          fixture.completed.containsKey(
            V1DataImporter.itemId(
              MigrationCategory.credentials,
              'password:profile-one',
            ),
          ),
          isFalse,
        );
      },
      skip: !kIsWeb
          ? 'Browser-only hard guard; native durability is covered separately'
          : false,
    );

    test(
      'credential checkpoint interruption propagates after durable secure write',
      () async {
        final fixture = MigrationFixture(
          preferences: {
            'server_profiles': jsonEncode([
              migrationProfile(password: 'durable-secret'),
            ]),
          },
        );
        final credentialId = V1DataImporter.itemId(
          MigrationCategory.credentials,
          'password:profile-one',
        );

        await expectLater(
          fixture
              .importer(
                afterCheckpoint: (id) async {
                  if (id == credentialId) {
                    throw StateError('fixture interruption');
                  }
                },
              )
              .run(),
          throwsStateError,
        );

        expect(fixture.completed[credentialId], 'imported');
        expect(fixture.credentialBackend.values.values, ['durable-secret']);
        expect(
          fixture.backend.values.containsKey(V1DataImporter.reportKey),
          isFalse,
        );
        await fixture.importer().run();
        expect(fixture.credentialBackend.writes, hasLength(1));
      },
      skip: kIsWeb ? 'Requires a durable native credential destination' : false,
    );

    test(
      'profile URL credentials remain only in the untouched legacy source',
      () async {
        const url = 'http://opencode:private-url-secret@legacy.invalid:4096';
        final fixture = MigrationFixture(
          preferences: {
            'server_profiles': jsonEncode([migrationProfile(url: url)]),
          },
        );
        final original = fixture.preferences.snapshot;

        final report = await fixture.importer().run();

        expectMigrationPending(
          report,
          MigrationCategory.profiles,
          'profile-one',
          MigrationPendingReason.malformed,
        );
        expect(
          fixture.backend.values.containsKey(
            V1DataImporter.profileKey('profile-one'),
          ),
          isFalse,
        );
        expect(fixture.credentialBackend.values, isEmpty);
        expect(fixture.completed, isEmpty);
        expect(
          jsonEncode(fixture.backend.values),
          isNot(contains('private-url-secret')),
        );
        expect(fixture.preferences.snapshot, original);
      },
    );

    for (final includeVault in [true, false]) {
      test(
        'ephemeral or unavailable vault has no credential checkpoint ($includeVault)',
        () async {
          final fixture = MigrationFixture(
            preferences: {
              'server_profiles': jsonEncode([
                migrationProfile(password: 'private-secret'),
              ]),
            },
          );

          final report = await fixture
              .importer(
                credentialsAreDurable: false,
                includeVault: includeVault,
              )
              .run();

          expectMigrationPending(
            report,
            MigrationCategory.credentials,
            'password:profile-one',
            MigrationPendingReason.ephemeralCredential,
          );
          expect(fixture.credentialBackend.values, isEmpty);
          expect(fixture.credentialBackend.writes, isEmpty);
          expect(
            fixture.completed.containsKey(
              V1DataImporter.itemId(
                MigrationCategory.credentials,
                'password:profile-one',
              ),
            ),
            isFalse,
          );
        },
      );
    }

    test(
      'secure destination failure is retried without a premature checkpoint',
      () async {
        final fixture = MigrationFixture(
          preferences: {
            'server_profiles': jsonEncode([
              migrationProfile(password: 'retry-secret'),
            ]),
          },
        );
        fixture.credentialBackend.failWrite = true;
        final credentialId = V1DataImporter.itemId(
          MigrationCategory.credentials,
          'password:profile-one',
        );

        final failed = await fixture.importer().run();

        expectMigrationPending(
          failed,
          MigrationCategory.credentials,
          'password:profile-one',
          MigrationPendingReason.destinationFailed,
        );
        expect(fixture.completed.containsKey(credentialId), isFalse);
        expect(fixture.credentialBackend.values, isEmpty);

        fixture.credentialBackend.failWrite = false;
        await fixture.importer().run();

        expect(fixture.completed[credentialId], 'imported');
        expect(fixture.credentialBackend.values.values, ['retry-secret']);
        expect(fixture.credentialBackend.writes, hasLength(1));
      },
      skip: kIsWeb ? 'Requires a durable native credential destination' : false,
    );
  });

  group('failure and interruption recovery', () {
    test(
      'metadata destination failure remains retryable and source stays intact',
      () async {
        const destination = 'cw2.settings.composerAutoApprovePermissions';
        final fixture = MigrationFixture(
          preferences: {
            'experience_settings': '{"composerAutoApprovePermissions":false}',
          },
        );
        final original = fixture.preferences.snapshot;
        fixture.backend.failWrite = destination;
        final opaque = V1DataImporter.itemId(
          MigrationCategory.settings,
          'composerAutoApprovePermissions',
        );

        final failed = await fixture.importer().run();

        expect(fixture.backend.values.containsKey(destination), isFalse);
        expect(fixture.completed.containsKey(opaque), isFalse);
        expectMigrationPending(
          failed,
          MigrationCategory.settings,
          'composerAutoApprovePermissions',
          MigrationPendingReason.destinationFailed,
        );
        expect(fixture.preferences.snapshot, original);

        fixture.backend.failWrite = null;
        final retried = await fixture.importer().run();

        expect(fixture.backend.values[destination], isFalse);
        expect(fixture.completed[opaque], 'imported');
        expect(retried.counts['unresolved'], 0);
        expect(
          fixture.backend.writes.where((key) => key == destination),
          hasLength(1),
        );
        expect(fixture.preferences.snapshot, original);
      },
    );

    for (final refusal in [true, false]) {
      test(
        'payload ${refusal ? 'refusal' : 'failure'} is retried without completion',
        () async {
          const legacyKey = 'session_composer_draft::unmapped';
          final fixture = MigrationFixture(
            preferences: {legacyKey: '{"text":"recover me","shellMode":true}'},
          );
          final original = fixture.preferences.snapshot;
          final destination = V1DataImporter.recoveredDraftKey(legacyKey);
          final id = V1DataImporter.itemId(MigrationCategory.drafts, legacyKey);
          if (refusal) {
            fixture.payloads.refusedKeys.add(destination);
          } else {
            fixture.payloads.failedKeys.add(destination);
          }

          final failed = await fixture.importer().run();

          expect(fixture.payloads.values, isEmpty);
          expect(fixture.completed.containsKey(id), isFalse);
          expectMigrationPending(
            failed,
            MigrationCategory.drafts,
            legacyKey,
            refusal
                ? MigrationPendingReason.oversized
                : MigrationPendingReason.destinationFailed,
          );

          fixture.payloads.refusedKeys.clear();
          fixture.payloads.failedKeys.clear();
          await fixture.importer().run();

          expect(fixture.draft(legacyKey)['text'], 'recover me');
          expect(fixture.completed[id], 'imported');
          expect(fixture.payloads.writes, [destination]);
          expect(fixture.preferences.snapshot, original);
          expect(fixture.payloads.removals, isEmpty);
        },
      );
    }

    test(
      'durable checkpoint interruption resumes and preserves later user edits',
      () async {
        const legacyKey = 'session_composer_draft::resume';
        final fixture = MigrationFixture(
          preferences: {
            'experience_settings': '{"composerAutoApprovePermissions":false}',
            legacyKey: '{"text":"draft after checkpoint"}',
          },
        );
        final original = fixture.preferences.snapshot;
        final settingsId = V1DataImporter.itemId(
          MigrationCategory.settings,
          'composerAutoApprovePermissions',
        );
        final checkpointIds = <String>[];

        await expectLater(
          fixture
              .importer(
                afterCheckpoint: (id) async {
                  checkpointIds.add(id);
                  throw StateError('fixture interruption');
                },
              )
              .run(),
          throwsStateError,
        );

        expect(checkpointIds, [settingsId]);
        expect(fixture.completed, {settingsId: 'imported'});
        expect(
          fixture.backend.values.containsKey(V1DataImporter.reportKey),
          isFalse,
        );
        expect(fixture.payloads.values, isEmpty);
        await fixture.metadata.write(
          'cw2.settings.composerAutoApprovePermissions',
          true,
        );

        await fixture.importer().run();
        final writes = fixture.backend.writes.length;
        final payloadWrites = fixture.payloads.writes.length;
        await fixture.importer().run();

        expect(
          fixture.backend.values['cw2.settings.composerAutoApprovePermissions'],
          isTrue,
        );
        expect(fixture.draft(legacyKey)['text'], 'draft after checkpoint');
        expect(fixture.completed, hasLength(2));
        expect(fixture.backend.writes, hasLength(writes));
        expect(fixture.payloads.writes, hasLength(payloadWrites));
        expect(fixture.preferences.snapshot, original);
      },
    );

    test(
      'destination write before a failed journal is preserved on a new importer',
      () async {
        const legacyKey = 'session_composer_draft::checkpoint-crash';
        final fixture = MigrationFixture(
          preferences: {legacyKey: '{"text":"original draft"}'},
        );
        final destination = V1DataImporter.recoveredDraftKey(legacyKey);
        fixture.backend.failWrite = V1DataImporter.journalKey;

        await expectLater(
          fixture.importer().run(),
          migrationFailure(MigrationFailure.checkpointFailed),
        );

        expect(fixture.draft(legacyKey)['text'], 'original draft');
        expect(
          fixture.backend.values.containsKey(V1DataImporter.journalKey),
          isFalse,
        );
        final edited = jsonEncode({
          'text': 'later user draft',
          'reviewRequired': false,
        });
        await fixture.payloads.write(destination, edited);
        fixture.backend.failWrite = null;

        final resumed = await fixture.importer().run();

        expect(fixture.payloads.values[destination], edited);
        expect(
          fixture.completed[V1DataImporter.itemId(
            MigrationCategory.drafts,
            legacyKey,
          )],
          'existing',
        );
        expect(resumed.counts['existingPreserved'], 1);
        expect(fixture.payloads.writes, [destination, destination]);
      },
    );

    test(
      'failed report write does not lose durable checkpoints on retry',
      () async {
        final fixture = MigrationFixture(
          preferences: {'experience_settings': '{"useAmoledDark":true}'},
        );
        fixture.backend.failWrite = V1DataImporter.reportKey;

        await expectLater(
          fixture.importer().run(),
          migrationFailure(MigrationFailure.reportFailed),
        );

        expect(fixture.completed, hasLength(1));
        expect(fixture.backend.values['cw2.settings.useAmoledDark'], isTrue);
        fixture.backend.failWrite = null;
        await fixture.importer().run();
        expect(
          fixture.backend.writes.where(
            (key) => key == 'cw2.settings.useAmoledDark',
          ),
          hasLength(1),
        );
      },
    );

    for (final malformedJournal in <Object>[
      '{broken',
      jsonEncode({'version': 2, 'completed': {}}),
      jsonEncode({
        'version': 1,
        'completed': {'bad-id': 'imported'},
      }),
      jsonEncode({
        'version': 1,
        'completed': {'a' * 64: 'done'},
      }),
      42,
    ]) {
      test(
        'invalid journal is preserved and prevents destination writes ($malformedJournal)',
        () async {
          final fixture = MigrationFixture(
            preferences: {'experience_settings': '{"useAmoledDark":true}'},
          );
          fixture.backend.values.addAll({
            V2MetadataStore.schemaKey: 1,
            V1DataImporter.journalKey: malformedJournal,
            'cw2.keep': 'existing user data',
          });
          final before = jsonEncode(fixture.backend.values);
          final original = fixture.preferences.snapshot;

          await expectLater(
            fixture.importer().run(),
            migrationFailure(MigrationFailure.invalidJournal),
          );

          expect(jsonEncode(fixture.backend.values), before);
          expect(fixture.backend.writeAttempts, isEmpty);
          expect(fixture.payloads.writeAttempts, isEmpty);
          expect(fixture.credentialBackend.writes, isEmpty);
          expect(fixture.preferences.snapshot, original);
          expect(fixture.preferences.reads, isEmpty);
        },
      );
    }
  });

  group('recovered data and source preservation', () {
    test(
      'unmapped drafts retain shell and attachments without canonical history',
      () async {
        const legacyKey =
            'session_composer_draft::profile::/private/project::ses-v1';
        final attachment = {
          'mime': 'text/plain',
          'url': 'file:///private/project/notes.txt',
          'filename': 'notes.txt',
          'source': {
            'type': 'file',
            'path': '/private/project/notes.txt',
            'text': {'value': '@notes.txt', 'start': 0, 'end': 10},
          },
        };
        final fixture = MigrationFixture(
          preferences: {
            legacyKey: jsonEncode({
              'text': 'unfinished private command',
              'shellMode': true,
              'attachments': [attachment],
            }),
            'canned_answers::profile': jsonEncode([
              {
                'id': 'answer-1',
                'text': 'private reusable answer',
                'unused': 1,
              },
            ]),
            'chat_cache::profile': '{"sessions":["ses-v1"]}',
            'session_tabs::profile': '["ses-v1"]',
            'pinned_sessions::profile': '["ses-v1"]',
            'selected_session_id': 'ses-v1',
          },
        );
        final original = fixture.preferences.snapshot;

        final report = await fixture.importer().run();
        final recovered = fixture.draft(legacyKey);

        expect(recovered['text'], 'unfinished private command');
        expect(recovered['shellMode'], isTrue);
        expect(recovered['legacyScopeKey'], legacyKey);
        expect(recovered['mapping'], 'unmapped');
        expect(recovered['reviewRequired'], isTrue);
        expect(recovered.containsKey('sessionRef'), isFalse);
        expect(recovered['attachments'], [
          {...attachment, 'reviewRequired': true},
        ]);
        expectMigrationPending(
          report,
          MigrationCategory.drafts,
          legacyKey,
          MigrationPendingReason.unmappedDraft,
        );
        expectMigrationPending(
          report,
          MigrationCategory.drafts,
          legacyKey,
          MigrationPendingReason.attachmentReviewRequired,
        );
        final cannedKey =
            'cw2.cannedAnswers.${V1DataImporter.itemId(MigrationCategory.cannedAnswers, 'canned_answers::profile')}';
        final canned = jsonDecode(fixture.payloads.values[cannedKey]!) as Map;
        expect(canned['needsScopeReview'], isTrue);
        expect(canned['answers'], [
          {'id': 'answer-1', 'text': 'private reusable answer'},
        ]);
        expect(fixture.payloads.values.keys.toSet(), {
          V1DataImporter.recoveredDraftKey(legacyKey),
          cannedKey,
        });
        for (final key in [
          'chat_cache::profile',
          'session_tabs::profile',
          'pinned_sessions::profile',
          'selected_session_id',
        ]) {
          expect(fixture.preferences.reads[key], isNull);
        }
        expect(fixture.preferences.snapshot, original);
        expect(fixture.backend.removals, isEmpty);
        expect(fixture.payloads.removals, isEmpty);
      },
    );

    test(
      'known file-backed drafts recover and unknown files remain unresolved',
      () async {
        const legacyKey = 'session_composer_draft::file-backed';
        const orphan = '/private/cache/0123456789abcdef.json';
        final fixture = MigrationFixture(
          legacyPayloads: {legacyKey: '{"text":"file-backed text"}'},
          knownPayloadKeys: {legacyKey},
        );
        fixture.legacyPayloads.orphanFiles.add(orphan);
        final original = fixture.legacyPayloads.snapshot;

        final report = await fixture.importer().run();

        expect(fixture.draft(legacyKey)['text'], 'file-backed text');
        expect(fixture.legacyPayloads.lastClaimedKeys, {legacyKey});
        expectMigrationPending(
          report,
          MigrationCategory.orphanFiles,
          orphan,
          MigrationPendingReason.orphanPayload,
        );
        expect(fixture.legacyPayloads.snapshot, original);
        expect(fixture.legacyPayloads.orphanFiles, {orphan});
        expect(jsonEncode(report.toJson()), isNot(contains(orphan)));
      },
    );

    test(
      'unsafe attachment URLs recover opaque references without copying secrets',
      () async {
        const legacyKey = 'session_composer_draft::unsafe-attachments';
        final urls = [
          'https://user:private-attachment-password@files.invalid/notes.txt',
          'https://files.invalid/notes.txt?token=private-attachment-token',
          'https://files.invalid/notes.txt#private-attachment-fragment',
        ];
        final fixture = MigrationFixture(
          preferences: {
            legacyKey: jsonEncode({
              'text': 'preserved draft text',
              'attachments': [
                for (final url in urls)
                  {'mime': 'text/plain', 'url': url, 'filename': 'notes.txt'},
              ],
            }),
          },
        );
        final original = fixture.preferences.snapshot;

        final report = await fixture.importer().run();
        final recovered = fixture.draft(legacyKey);

        expect(recovered['text'], 'preserved draft text');
        final attachments = recovered['attachments'] as List;
        expect(attachments, hasLength(3));
        for (final attachment in attachments.cast<Map>()) {
          expect(attachment.containsKey('url'), isFalse);
          expect(attachment.containsKey('source'), isFalse);
          expect(
            attachment['legacyReferenceId'],
            matches(RegExp(r'^[a-f0-9]{64}$')),
          );
          expect(attachment['referenceUnavailable'], isTrue);
          expect(attachment['reviewRequired'], isTrue);
        }
        expectMigrationPending(
          report,
          MigrationCategory.drafts,
          legacyKey,
          MigrationPendingReason.unsupportedCredential,
        );
        for (final url in urls) {
          expect(jsonEncode(fixture.backend.values), isNot(contains(url)));
          expect(jsonEncode(fixture.payloads.values), isNot(contains(url)));
        }
        expect(fixture.preferences.snapshot, original);
      },
    );

    test(
      'corrupt and oversized source strings remain exactly unchanged',
      () async {
        const badDraft = 'session_composer_draft::malformed';
        const oversizedDraft = 'session_composer_draft::oversized-file';
        final fixture = MigrationFixture(
          preferences: {
            'experience_settings': 'x' * (V2PayloadLimits.maxPayloadChars + 1),
            badDraft: '{broken-json',
            'server_profiles': 'not-json',
          },
          legacyPayloads: {oversizedDraft: 'original oversized file bytes'},
          knownPayloadKeys: {oversizedDraft},
        );
        fixture.legacyPayloads.failures[oversizedDraft] =
            LegacyReadFailure.oversized;
        final originalPreferences = fixture.preferences.snapshot;
        final originalPayloads = fixture.legacyPayloads.snapshot;

        final report = await fixture.importer().run();

        expectMigrationPending(
          report,
          MigrationCategory.settings,
          'experience_settings',
          MigrationPendingReason.oversized,
        );
        expectMigrationPending(
          report,
          MigrationCategory.profiles,
          'server_profiles',
          MigrationPendingReason.malformed,
        );
        expectMigrationPending(
          report,
          MigrationCategory.drafts,
          badDraft,
          MigrationPendingReason.malformed,
        );
        expectMigrationPending(
          report,
          MigrationCategory.drafts,
          oversizedDraft,
          MigrationPendingReason.oversized,
        );
        expect(fixture.completed, isEmpty);
        expect(fixture.payloads.values, isEmpty);
        expect(fixture.preferences.snapshot, originalPreferences);
        expect(fixture.legacyPayloads.snapshot, originalPayloads);
        expect(fixture.backend.removals, isEmpty);
        expect(fixture.payloads.removals, isEmpty);
      },
    );

    test(
      'unavailable source can retry without destroying original values',
      () async {
        const legacyKey = 'session_composer_draft::temporarily-unavailable';
        final fixture = MigrationFixture(
          preferences: {legacyKey: '{"text":"retained text"}'},
        );
        fixture.preferences.failReads.add(legacyKey);
        final original = fixture.preferences.snapshot;

        final unavailable = await fixture.importer().run();

        expectMigrationPending(
          unavailable,
          MigrationCategory.drafts,
          legacyKey,
          MigrationPendingReason.sourceUnavailable,
        );
        expect(fixture.completed, isEmpty);
        expect(fixture.payloads.values, isEmpty);
        fixture.preferences.failReads.clear();
        await fixture.importer().run();
        expect(fixture.draft(legacyKey)['text'], 'retained text');
        expect(fixture.preferences.snapshot, original);
      },
    );

    test(
      'migration report exposes counts and opaque diagnostics only',
      () async {
        const privateUrl = 'http://private-host.invalid:4096/secret-project';
        const draftText = 'DO NOT DISCLOSE PRIVATE DRAFT CONTENT';
        const password = 'DO-NOT-DISCLOSE-ENDPOINT-SECRET';
        const voiceSecret = 'DO-NOT-DISCLOSE-VOICE-SECRET';
        const legacyKey =
            'session_composer_draft::/secret-project::private-native-session';
        const attachmentUrl = 'file:///secret-project/private-attachment.txt';
        final fixture = MigrationFixture(
          preferences: {
            'server_profiles': jsonEncode([
              migrationProfile(url: privateUrl, password: password),
            ]),
            legacyKey: jsonEncode({
              'text': draftText,
              'attachments': [
                {'mime': 'text/plain', 'url': attachmentUrl},
              ],
            }),
            'api_key::/secret-project': 'DO-NOT-DISCLOSE-API-SECRET',
          },
          secure: {'codewalk.secure::tts_api_key::elevenlabs': voiceSecret},
        );

        final report = await fixture.importer().run();
        final encoded = jsonEncode(report.toJson());

        for (final sensitive in [
          privateUrl,
          draftText,
          password,
          voiceSecret,
          legacyKey,
          attachmentUrl,
          'DO-NOT-DISCLOSE-API-SECRET',
          '/secret-project',
          'private-native-session',
        ]) {
          expect(encoded, isNot(contains(sensitive)));
        }
        expect(report.pending, isNotEmpty);
        for (final pending in report.pending) {
          expect(pending.id, matches(RegExp(r'^[a-f0-9]{64}$')));
          expect(pending.toJson().keys.toSet(), {'id', 'category', 'reason'});
        }
        expect(report.toJson()['status'], 'local-partial');
        expect(report.toJson()['allRequirementsAccepted'], isFalse);
        expect(
          report.toJson()['externalPrerequisites'],
          contains('real-v1.266-installed-upgrade'),
        );
        expect(fixture.backend.values[V1DataImporter.reportKey], encoded);
      },
    );
  });
}
