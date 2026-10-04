import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../storage/endpoint_credentials.dart';
import '../storage/metadata_store.dart';
import '../storage/payload_store.dart';
import 'legacy_readers.dart';
import 'legacy_source.dart';
import 'migration_report.dart';
import 'migration_settings.dart';

/// Local partial importer; no networking, bootstrap, Kotlin or UI integration.
/// Run before consumers edit destinations. Later runs preserve every existing
/// destination, including writes completed before an interrupted checkpoint.
final class V1DataImporter {
  V1DataImporter({
    required this.source,
    required this.metadata,
    required this.payloads,
    this.credentials,
    this.credentialsAreDurable = false,
    this.exclusiveBeforeConsumers = false,
    this.afterCheckpoint,
  });

  static const journalKey = 'cw2.migration.v1';
  static const reportKey = 'cw2.migration.v1.report';
  static const maxItems = 2048;
  final LegacySource source;
  final V2MetadataStore metadata;
  final PayloadStore payloads;
  final EndpointCredentialVault? credentials;

  /// Must be false for Web's instance-local memory vault.
  final bool credentialsAreDurable;

  /// Caller attestation of an exclusive startup/offline window. This module
  /// supplies no cross-engine lease or atomic writeIfAbsent. App integration
  /// must establish exclusivity before invoking it; concurrent user writers
  /// between the read and write below are outside this partial delivery.
  final bool exclusiveBeforeConsumers;

  /// Lifecycle/fixture interruption boundary, after a durable checkpoint.
  final Future<void> Function(String opaqueItemId)? afterCheckpoint;
  Future<MigrationReport>? _running;

  Future<MigrationReport> run() {
    final existing = _running;
    if (existing != null) return existing;
    final future = _run();
    _running = future;
    future.then<void>(
      (_) => _running = null,
      onError: (Object _, StackTrace _) => _running = null,
    );
    return future;
  }

  static String itemId(MigrationCategory category, String sourceIdentity) =>
      sha256
          .convert(utf8.encode('${category.name}\u0000$sourceIdentity'))
          .toString();

  static String profileKey(String legacyId) =>
      'cw2.profiles.${itemId(MigrationCategory.profiles, legacyId)}';

  static String recoveredDraftKey(String legacyKey) =>
      'cw2.recoveredDrafts.${itemId(MigrationCategory.drafts, legacyKey)}';

  Future<MigrationReport> _run() async {
    if (!exclusiveBeforeConsumers) {
      throw const MigrationException(MigrationFailure.exclusivityRequired);
    }
    await metadata.ensureSchema();
    final saved = await metadata.read(journalKey);
    final completed = <String, String>{};
    if (saved != null) {
      try {
        final decoded = jsonDecode(saved as String);
        if (decoded is! Map ||
            decoded['version'] != 1 ||
            decoded['completed'] is! Map) {
          throw const FormatException();
        }
        for (final entry in (decoded['completed'] as Map).entries) {
          if (entry.key is! String ||
              !RegExp(r'^[a-f0-9]{64}$').hasMatch(entry.key as String) ||
              !{'imported', 'existing'}.contains(entry.value)) {
            throw const FormatException();
          }
          completed[entry.key as String] = entry.value as String;
        }
        if (completed.length > maxItems) throw const FormatException();
      } catch (_) {
        throw const MigrationException(MigrationFailure.invalidJournal);
      }
    }
    final run = _ImportRun(this, completed);
    await run.importSettings();
    await run.importProfiles();
    await run.importPayloads();
    await run.unsupportedSecrets();
    final report = run.report();
    try {
      await metadata.write(reportKey, jsonEncode(report.toJson()));
    } catch (_) {
      throw const MigrationException(MigrationFailure.reportFailed);
    }
    return report;
  }
}

final class _ImportRun {
  _ImportRun(this.importer, this.completed);
  final V1DataImporter importer;
  final Map<String, String> completed;
  final _pending = <String, MigrationPendingItem>{};
  final _seen = <String>{};
  final _counts = <String, int>{};
  final _profileIds = <String>{};
  final _profileUrls = <String, String>{};

  String id(MigrationCategory category, String identity) =>
      V1DataImporter.itemId(category, identity);

  void pending(
    MigrationCategory category,
    String identity,
    MigrationPendingReason reason,
  ) {
    final opaque = id(category, identity);
    final key = '$opaque:${reason.name}';
    if (!_pending.containsKey(key) &&
        _pending.length == V1DataImporter.maxItems) {
      throw const MigrationException(MigrationFailure.itemLimit);
    }
    _pending[key] = MigrationPendingItem(
      id: opaque,
      category: category,
      reason: reason,
    );
  }

  void seen(MigrationCategory category, String identity) {
    final opaque = id(category, identity);
    if (_seen.add(opaque)) {
      if (_seen.length > V1DataImporter.maxItems) {
        throw const MigrationException(MigrationFailure.itemLimit);
      }
      _counts[category.name] = (_counts[category.name] ?? 0) + 1;
    }
  }

  Future<void> checkpoint(String opaque, String status) async {
    final next = {...completed, opaque: status};
    if (next.length > V1DataImporter.maxItems) {
      throw const MigrationException(MigrationFailure.itemLimit);
    }
    try {
      await importer.metadata.write(
        V1DataImporter.journalKey,
        jsonEncode({'version': 1, 'completed': next}),
      );
    } catch (_) {
      throw const MigrationException(MigrationFailure.checkpointFailed);
    }
    completed[opaque] = status;
    await importer.afterCheckpoint?.call(opaque);
  }

  Future<_PreferenceRead> preference(
    String key,
    MigrationCategory category,
  ) async {
    try {
      final value = await importer.source.preferences.read(key);
      if (value is String && value.length > V2PayloadLimits.maxPayloadChars) {
        pending(category, key, MigrationPendingReason.oversized);
        return const _PreferenceRead.failed(_PreferenceStatus.oversized);
      }
      return value == null
          ? const _PreferenceRead.absent()
          : _PreferenceRead.present(value);
    } on LegacyReadException catch (error) {
      pending(
        category,
        key,
        error.failure == LegacyReadFailure.oversized
            ? MigrationPendingReason.oversized
            : error.failure == LegacyReadFailure.malformed
            ? MigrationPendingReason.malformed
            : MigrationPendingReason.sourceUnavailable,
      );
      return _PreferenceRead.failed(
        error.failure == LegacyReadFailure.oversized
            ? _PreferenceStatus.oversized
            : error.failure == LegacyReadFailure.malformed
            ? _PreferenceStatus.malformed
            : _PreferenceStatus.failed,
      );
    } catch (_) {
      pending(category, key, MigrationPendingReason.sourceUnavailable);
      return const _PreferenceRead.failed(_PreferenceStatus.failed);
    }
  }

  Future<String?> secure(String key, String identity) async {
    final reader = importer.source.secure;
    if (reader == null) {
      pending(
        MigrationCategory.credentials,
        'legacy-secure-reader',
        MigrationPendingReason.sourceUnavailable,
      );
      return null;
    }
    try {
      return await reader.read(key);
    } catch (_) {
      pending(
        MigrationCategory.credentials,
        identity,
        MigrationPendingReason.sourceUnavailable,
      );
      return null;
    }
  }

  Future<void> metadataItem(
    MigrationCategory category,
    String identity,
    String key,
    Object value,
  ) async {
    seen(category, identity);
    final opaque = id(category, identity);
    if (completed.containsKey(opaque)) return;
    if (value is String && value.length > V2MetadataStore.maxPreferenceChars) {
      pending(category, identity, MigrationPendingReason.oversized);
      return;
    }
    String status;
    try {
      if (await importer.metadata.read(key) != null) {
        status = 'existing';
      } else {
        await importer.metadata.write(key, value);
        status = 'imported';
      }
    } catch (_) {
      pending(category, identity, MigrationPendingReason.destinationFailed);
      return;
    }
    await checkpoint(opaque, status);
  }

  Future<void> payloadItem(
    MigrationCategory category,
    String identity,
    String key,
    Object value,
  ) async {
    seen(category, identity);
    final opaque = id(category, identity);
    if (completed.containsKey(opaque)) return;
    String status;
    try {
      if (await importer.payloads.contains(key)) {
        status = 'existing';
      } else {
        final result = await importer.payloads.write(key, jsonEncode(value));
        if (result == PayloadWriteResult.refusedOversized) {
          pending(category, identity, MigrationPendingReason.oversized);
          return;
        }
        status = 'imported';
      }
    } catch (_) {
      pending(category, identity, MigrationPendingReason.destinationFailed);
      return;
    }
    await checkpoint(opaque, status);
  }

  Object? decode(Object? raw, MigrationCategory category, String identity) {
    if (raw == null) return null;
    try {
      if (raw is! String) throw const FormatException();
      return jsonDecode(raw);
    } catch (_) {
      pending(category, identity, MigrationPendingReason.malformed);
      return null;
    }
  }

  Future<void> importSettings() async {
    final raw = await preference(
      'experience_settings',
      MigrationCategory.settings,
    );
    final decoded = decode(
      raw.value,
      MigrationCategory.settings,
      'experience_settings',
    );
    final values = <String, Object>{};
    if (decoded is Map<String, dynamic>) {
      values.addAll(selectedLegacySettings(decoded));
      for (final field in [
        'composerAutoApprovePermissions',
        'localeCode',
        'themeMode',
        'speechApiBaseUrl',
        'readAloudBaseUrl',
      ]) {
        if (decoded.containsKey(field) &&
            !values.containsKey(field) &&
            (decoded[field] != null ||
                field == 'composerAutoApprovePermissions')) {
          pending(
            MigrationCategory.settings,
            field,
            MigrationPendingReason.malformed,
          );
        }
      }
      for (final field in decoded.keys) {
        if (decoded[field] != null &&
            !values.containsKey(field) &&
            !{
              'composerAutoApprovePermissions',
              'localeCode',
              'themeMode',
              'speechApiBaseUrl',
              'readAloudBaseUrl',
            }.contains(field)) {
          pending(
            MigrationCategory.settings,
            field,
            MigrationPendingReason.unsupportedSettings,
          );
        }
      }
    } else if (decoded != null) {
      pending(
        MigrationCategory.settings,
        'experience_settings',
        MigrationPendingReason.malformed,
      );
    }
    // v1 SettingsProvider reads the experience document as a whole. Its
    // present/invalid document does not authorize old global setting values;
    // only a successful absent lookup enables those older source keys here.
    final allowGlobalFallback = raw.status == _PreferenceStatus.absent;
    if (allowGlobalFallback && !values.containsKey('themeMode')) {
      final theme = (await preference(
        'theme_mode',
        MigrationCategory.settings,
      )).value;
      if (theme is String && {'light', 'dark', 'system'}.contains(theme)) {
        values['themeMode'] = theme;
      }
    }
    if (allowGlobalFallback && !values.containsKey('localeCode')) {
      final locale = (await preference(
        'locale_code',
        MigrationCategory.settings,
      )).value;
      if (locale is String && locale.isNotEmpty && locale.length <= 128) {
        values['localeCode'] = locale;
      }
    }
    for (final entry in values.entries) {
      final value = entry.value is Map ? jsonEncode(entry.value) : entry.value;
      await metadataItem(
        MigrationCategory.settings,
        entry.key,
        'cw2.settings.${entry.key}',
        value,
      );
    }
  }

  Future<void> importProfiles() async {
    final raw = await preference('server_profiles', MigrationCategory.profiles);
    final decoded = decode(
      raw.value,
      MigrationCategory.profiles,
      'server_profiles',
    );
    if (decoded != null && decoded is! List) {
      pending(
        MigrationCategory.profiles,
        'server_profiles',
        MigrationPendingReason.malformed,
      );
      return;
    }
    var profileIndex = 0;
    for (final value in decoded is List ? decoded : const []) {
      final index = profileIndex++;
      if (value is! Map ||
          value['id'] is! String ||
          (value['id'] as String).trim().isEmpty ||
          value['url'] is! String) {
        seen(MigrationCategory.profiles, 'invalid:$index');
        pending(
          MigrationCategory.profiles,
          'invalid:$index',
          MigrationPendingReason.malformed,
        );
        continue;
      }
      final profile = Map<String, dynamic>.from(value);
      final legacyId = profile['id'] as String;
      final url = profile['url'] as String;
      if (!_profileIds.add(legacyId)) {
        pending(
          MigrationCategory.profiles,
          legacyId,
          MigrationPendingReason.malformed,
        );
        continue;
      }
      _profileUrls[legacyId] = url;
      final record = <String, Object?>{
        'id': 'legacy:${id(MigrationCategory.profiles, legacyId)}',
        'legacyId': legacyId,
        'url': url,
        'compatibility': 'needsOpenCode2Check',
        for (final field in [
          'label',
          'basicAuthEnabled',
          'oauthEnabled',
          'tailscaleEnabled',
          'aiGeneratedTitlesEnabled',
          'createdAt',
          'updatedAt',
        ])
          if (profile[field] is String ||
              profile[field] is bool ||
              (profile[field] is num && (profile[field] as num).isFinite))
            field: profile[field],
      };
      try {
        EndpointCredentialScope(
          endpoint: Uri.parse(url),
          profileId: record['id']! as String,
        );
      } catch (_) {
        pending(
          MigrationCategory.profiles,
          legacyId,
          MigrationPendingReason.malformed,
        );
        continue;
      }
      await metadataItem(
        MigrationCategory.profiles,
        legacyId,
        V1DataImporter.profileKey(legacyId),
        jsonEncode(record),
      );
      await profileCredential(profile, record);
      if (profile['oauthEnabled'] == true) {
        pending(
          MigrationCategory.credentials,
          'oauth:$legacyId',
          MigrationPendingReason.unsupportedCredential,
        );
      }
    }
    // Single-server legacy values remain unresolved instead of guessing profile identity.
    if (raw.status == _PreferenceStatus.absent) {
      final host = (await preference(
        'server_host',
        MigrationCategory.profiles,
      )).value;
      if (host != null) {
        pending(
          MigrationCategory.profiles,
          'server_host',
          MigrationPendingReason.malformed,
        );
      }
    }
  }

  Future<void> profileCredential(
    Map<String, dynamic> profile,
    Map<String, Object?> record,
  ) async {
    final legacyId = profile['id'] as String;
    final encoded = Uri.encodeComponent(legacyId.trim());
    const prefix = 'codewalk.secure::server_profile_basic_auth_';
    final secureReader = importer.source.secure;
    if (secureReader == null) {
      // Missing access to the old vault is not proof that its newer password
      // is absent. Do not promote an inline fallback into the durable vault.
      pending(
        MigrationCategory.credentials,
        'password:$legacyId',
        MigrationPendingReason.sourceUnavailable,
      );
      if (kIsWeb && profile['basicAuthPassword'] is String) {
        pending(
          MigrationCategory.credentials,
          'password:$legacyId',
          MigrationPendingReason.ephemeralCredential,
        );
      }
      return;
    }
    String? secureUser;
    String? securePassword;
    try {
      secureUser = await secureReader.read('${prefix}username::$encoded');
      securePassword = await secureReader.read('${prefix}password::$encoded');
    } catch (_) {
      pending(
        MigrationCategory.credentials,
        'password:$legacyId',
        MigrationPendingReason.sourceUnavailable,
      );
      return;
    }
    final username = (secureUser?.isNotEmpty ?? false)
        ? secureUser
        : (profile['basicAuthUsername'] is String
              ? profile['basicAuthUsername'] as String
              : null);
    final password = (securePassword?.isNotEmpty ?? false)
        ? securePassword
        : (profile['basicAuthPassword'] is String
              ? profile['basicAuthPassword'] as String
              : null);
    if (password == null || password.isEmpty) return;
    final identity = 'password:$legacyId';
    seen(MigrationCategory.credentials, identity);
    if (username != 'opencode' || profile['basicAuthEnabled'] != true) {
      pending(
        MigrationCategory.credentials,
        identity,
        MigrationPendingReason.unsupportedCredential,
      );
      return;
    }
    if (kIsWeb ||
        !importer.credentialsAreDurable ||
        importer.credentials == null) {
      pending(
        MigrationCategory.credentials,
        identity,
        MigrationPendingReason.ephemeralCredential,
      );
      return;
    }
    final opaque = id(MigrationCategory.credentials, identity);
    if (completed.containsKey(opaque)) return;
    String status;
    try {
      final saved = await importer.metadata.read(
        V1DataImporter.profileKey(legacyId),
      );
      if (saved is! String) throw const FormatException();
      final destination = jsonDecode(saved);
      if (destination is! Map ||
          destination['url'] is! String ||
          destination['id'] != record['id']) {
        throw const FormatException();
      }
      final original = EndpointCredentialScope(
        endpoint: Uri.parse(profile['url'] as String),
        profileId: record['id']! as String,
      );
      final target = EndpointCredentialScope(
        endpoint: Uri.parse(destination['url'] as String),
        profileId: record['id']! as String,
      );
      if (original.origin != target.origin) {
        pending(
          MigrationCategory.credentials,
          identity,
          MigrationPendingReason.credentialOriginMismatch,
        );
        return;
      }
      final vault = importer.credentials!;
      status =
          await vault.read(target, EndpointCredentialKind.endpointPassword) !=
              null
          ? 'existing'
          : 'imported';
      if (status == 'imported') {
        await vault.write(
          target,
          EndpointCredentialKind.endpointPassword,
          password,
        );
      }
    } catch (_) {
      pending(
        MigrationCategory.credentials,
        identity,
        MigrationPendingReason.destinationFailed,
      );
      return;
    }
    await checkpoint(opaque, status);
  }

  Future<void> importPayloads() async {
    Set<String> keys;
    try {
      keys = {
        ...await importer.source.preferences.keys(),
        ...importer.source.knownPayloadKeys,
      };
    } catch (_) {
      pending(
        MigrationCategory.source,
        'keys',
        MigrationPendingReason.sourceUnavailable,
      );
      keys = {...importer.source.knownPayloadKeys};
    }
    final known = <String>{};
    for (final key in keys.toList()..sort()) {
      if (!isLegacyImportKey(key)) continue;
      final draft =
          key == 'session_composer_draft' ||
          key.startsWith('session_composer_draft::');
      final canned =
          key == 'canned_answers' || key.startsWith('canned_answers::');
      if (!draft && !canned) continue;
      known.add(key);
      final category = draft
          ? MigrationCategory.drafts
          : MigrationCategory.cannedAnswers;
      final preferenceRead = await preference(key, category);
      var raw = preferenceRead.value;
      // Only a successful absent lookup permits the older file fallback.
      // Failed/oversized reads cannot establish which source is authoritative.
      if (preferenceRead.status == _PreferenceStatus.absent) {
        try {
          raw = await importer.source.payloads.read(key);
        } on LegacyReadException catch (error) {
          pending(
            category,
            key,
            error.failure == LegacyReadFailure.oversized
                ? MigrationPendingReason.oversized
                : error.failure == LegacyReadFailure.malformed
                ? MigrationPendingReason.malformed
                : MigrationPendingReason.sourceUnavailable,
          );
        } catch (_) {
          pending(category, key, MigrationPendingReason.sourceUnavailable);
        }
      }
      final value = decode(raw, category, key);
      if (value == null) continue;
      if (draft) {
        await recoverDraft(key, value);
      } else if (value is List &&
          value.every(
            (item) =>
                item is Map && item['id'] is String && item['text'] is String,
          )) {
        await payloadItem(
          category,
          key,
          'cw2.cannedAnswers.${id(category, key)}',
          {
            'legacyScopeKey': key,
            'needsScopeReview': true,
            'answers': [
              for (final item in value)
                {
                  'id': item['id'],
                  'text': item['text'],
                  for (final field in [
                    'label',
                    'insertMode',
                    'sendAutomatically',
                    'scopeMode',
                    'agentName',
                    'providerId',
                    'modelId',
                    'thinkingMode',
                    'thinkingVariantId',
                    'updatedAtEpochMs',
                  ])
                    if (item[field] is String ||
                        item[field] is bool ||
                        (item[field] is num && (item[field] as num).isFinite))
                      field: item[field],
                },
            ],
          },
        );
      } else {
        pending(category, key, MigrationPendingReason.malformed);
      }
    }
    try {
      final orphan = await importer.source.payloads.unclaimedFiles(known);
      for (final file in orphan) {
        seen(MigrationCategory.orphanFiles, file);
        pending(
          MigrationCategory.orphanFiles,
          file,
          MigrationPendingReason.orphanPayload,
        );
      }
    } on MigrationException {
      rethrow;
    } catch (_) {
      pending(
        MigrationCategory.orphanFiles,
        'listing',
        MigrationPendingReason.sourceUnavailable,
      );
    }
  }

  Future<void> recoverDraft(String key, Object value) async {
    if (value is! Map ||
        value['text'] is! String ||
        (value['shellMode'] != null && value['shellMode'] is! bool) ||
        (value['attachments'] != null && value['attachments'] is! List)) {
      pending(MigrationCategory.drafts, key, MigrationPendingReason.malformed);
      return;
    }
    final attachments = <Map<String, Object?>>[];
    for (final item
        in value['attachments'] is List
            ? value['attachments'] as List
            : const []) {
      if (item is! Map ||
          item['mime'] is! String ||
          item['url'] is! String ||
          (item['filename'] != null && item['filename'] is! String) ||
          (item['source'] != null && item['source'] is! Map)) {
        pending(
          MigrationCategory.drafts,
          key,
          MigrationPendingReason.malformed,
        );
        return;
      }
      Map<String, Object?>? originalSource;
      final attachmentSource = item['source'];
      if (attachmentSource is Map) {
        final text = attachmentSource['text'];
        if (attachmentSource['path'] is! String ||
            attachmentSource['type'] is! String ||
            text is! Map ||
            text['value'] is! String ||
            text['start'] is! num ||
            text['end'] is! num) {
          pending(
            MigrationCategory.drafts,
            key,
            MigrationPendingReason.malformed,
          );
          return;
        }
        originalSource = {
          'path': attachmentSource['path'],
          'type': attachmentSource['type'],
          'text': {
            'value': text['value'],
            'start': text['start'],
            'end': text['end'],
          },
        };
      }
      final url = Uri.tryParse(item['url'] as String);
      if (url == null ||
          url.userInfo.isNotEmpty ||
          ({'http', 'https'}.contains(url.scheme) &&
              (url.hasQuery || url.hasFragment))) {
        // Preserve the original only in the untouched legacy source, rather
        // than copying URL credentials into the Web preferences payload store.
        attachments.add({
          'mime': item['mime'],
          if (item['filename'] != null) 'filename': item['filename'],
          'legacyReferenceId': id(
            MigrationCategory.drafts,
            '$key:${item['url']}',
          ),
          'referenceUnavailable': true,
          'reviewRequired': true,
        });
        pending(
          MigrationCategory.drafts,
          key,
          MigrationPendingReason.unsupportedCredential,
        );
        continue;
      }
      attachments.add({
        'mime': item['mime'],
        'url': item['url'],
        if (item['filename'] != null) 'filename': item['filename'],
        'source': ?originalSource,
        'reviewRequired': true,
      });
    }
    final record = {
      'version': 1,
      'legacyScopeKey': key,
      'text': value['text'],
      'shellMode': value['shellMode'] ?? false,
      'attachments': attachments,
      'mapping': 'unmapped',
      'reviewRequired': true,
    };
    await payloadItem(
      MigrationCategory.drafts,
      key,
      V1DataImporter.recoveredDraftKey(key),
      record,
    );
    pending(
      MigrationCategory.drafts,
      key,
      MigrationPendingReason.unmappedDraft,
    );
    if (attachments.isNotEmpty) {
      pending(
        MigrationCategory.drafts,
        key,
        MigrationPendingReason.attachmentReviewRequired,
      );
    }
  }

  Future<void> unsupportedSecrets() async {
    Set<String> keys;
    try {
      keys = await importer.source.preferences.keys();
    } catch (_) {
      keys = {};
    }
    for (final key in keys.where(
      (key) =>
          key == 'api_key' ||
          key.startsWith('api_key::') ||
          key == 'basic_auth_password' ||
          key.startsWith('basic_auth_password::'),
    )) {
      if ((await preference(key, MigrationCategory.credentials)).value !=
          null) {
        pending(
          MigrationCategory.credentials,
          key,
          MigrationPendingReason.unsupportedCredential,
        );
      }
    }
    for (final key in [
      for (final base in ['api_key', 'basic_auth_password'])
        for (final server in ['', ..._profileIds])
          'codewalk.secure::$base${server.isEmpty ? '' : '::${Uri.encodeComponent(server.trim())}'}',
      for (final entry in _profileUrls.entries)
        'codewalk.secure::oauth::${Uri.encodeComponent(entry.key.trim())}::${Uri.encodeComponent(entry.value.trim())}',
      for (final provider in ['openai', 'groq', 'custom'])
        'codewalk.secure::stt_api_key::$provider',
      for (final provider in ['openai_compatible', 'elevenlabs', 'nim'])
        'codewalk.secure::tts_api_key::$provider',
    ]) {
      if ((await secure(key, key))?.isNotEmpty ?? false) {
        pending(
          MigrationCategory.credentials,
          key,
          MigrationPendingReason.unsupportedCredential,
        );
      }
    }
  }

  MigrationReport report() => MigrationReport(
    counts: {
      ..._counts,
      'durableCompleted': completed.length,
      'imported': completed.values.where((value) => value == 'imported').length,
      'existingPreserved': completed.values
          .where((value) => value == 'existing')
          .length,
      'unresolved': _pending.length,
    },
    pending: _pending.values.toList()
      ..sort(
        (a, b) =>
            '${a.id}:${a.reason.name}'.compareTo('${b.id}:${b.reason.name}'),
      ),
  );
}

enum _PreferenceStatus { absent, present, failed, oversized, malformed }

final class _PreferenceRead {
  const _PreferenceRead.absent()
    : status = _PreferenceStatus.absent,
      value = null;
  const _PreferenceRead.present(this.value)
    : status = _PreferenceStatus.present;
  const _PreferenceRead.failed(this.status) : value = null;

  final _PreferenceStatus status;
  final Object? value;
}
