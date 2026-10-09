import 'dart:async';
import 'dart:convert';

import 'package:codewalk_core/codewalk_core.dart';

import '../storage/endpoint_credentials.dart';
import '../storage/metadata_store.dart';

/// One serialized catalog, published only after metadata and secure credentials
/// succeed. Importer-owned cw2.profiles.* records remain untouched.
final class EndpointProfileStore implements EndpointProfileRepository {
  EndpointProfileStore({required this.metadata, required this.credentials});
  final V2MetadataStore metadata;
  final EndpointCredentialVault credentials;
  static const indexKey = 'cw2.endpointProfiles.index';
  static const removalKey = 'cw2.endpointProfiles.removing';
  static const creationKey = 'cw2.endpointProfiles.creating';
  static const maxProfiles = 100;
  Future<void> _tail = Future.value();

  static String itemKey(String id) => 'cw2.endpointProfiles.item.$id';

  Future<T> _run<T>(Future<T> Function() operation) {
    final next = _tail.then((_) => operation());
    _tail = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  Future<List<String>> _index() async {
    final value = await metadata.read(indexKey);
    if (value == null) return [];
    if (value is! List<String> ||
        value.length > maxProfiles ||
        value.toSet().length != value.length ||
        value.any((id) => !RegExp(r'^[A-Za-z0-9_-]{8,64}$').hasMatch(id))) {
      throw const FormatException(
        'Profile catalog is unreadable; data preserved.',
      );
    }
    return List.of(value);
  }

  Future<EndpointProfile> _read(String id) async {
    final raw = await metadata.read(itemKey(id));
    return _decodeProfile(raw, expectedId: id);
  }

  EndpointProfile _decodeProfile(Object? raw, {String? expectedId}) {
    if (raw is! String || raw.length > 8192) {
      throw const FormatException('Unreadable profile.');
    }
    final json = jsonDecode(raw);
    if (json is! Map ||
        json['id'] is! String ||
        (expectedId != null && json['id'] != expectedId) ||
        json['label'] is! String ||
        json['url'] is! String) {
      throw const FormatException('Unreadable profile.');
    }
    return EndpointProfile(
      id: json['id'] as String,
      label: json['label'] as String,
      endpoint: Uri.parse(json['url'] as String),
    );
  }

  @override
  Future<List<EndpointProfile>> load() => _run(() async {
    await _finishCreation();
    await _finishRemoval();
    final result = <EndpointProfile>[];
    for (final id in await _index()) {
      result.add(await _read(id));
    }
    return List.unmodifiable(result);
  });

  EndpointCredentialScope _scope(EndpointProfile profile) =>
      EndpointCredentialScope(
        endpoint: profile.endpoint,
        profileId: profile.id,
      );

  @override
  Future<String?> readSecret(EndpointProfile profile) async =>
      (await readCredential(profile))?.secret;

  @override
  Future<EndpointCredential?> readCredential(EndpointProfile profile) =>
      _run(() async {
        if (!(await _index()).contains(profile.id)) return null;
        final stored = await _read(profile.id);
        if (stored.endpoint != profile.endpoint) return null;
        return _readCredential(stored);
      });

  Future<EndpointCredential?> _readCredential(EndpointProfile profile) async {
    final active = await credentials.read(
      _scope(profile),
      EndpointCredentialKind.activeCredential,
    );
    if (active != null) return _decodeCredential(active);
    // Only absence authorizes reading the retained local password slot.
    final password = await credentials.read(
      _scope(profile),
      EndpointCredentialKind.endpointPassword,
    );
    return password == null
        ? null
        : EndpointCredential(kind: EndpointAuthKind.password, secret: password);
  }

  String _encodeCredential(EndpointCredential credential) => jsonEncode({
    'version': 1,
    'kind': credential.kind.name,
    'secret': credential.secret,
    'expiresAt': credential.expiresAt?.millisecondsSinceEpoch,
  });

  EndpointCredential _decodeCredential(String raw) {
    if (raw.length > 32768) {
      throw const FormatException('Unreadable credential; preserved.');
    }
    final data = jsonDecode(raw);
    if (data is! Map ||
        data['version'] != 1 ||
        data['secret'] is! String ||
        !{'password', 'paired'}.contains(data['kind']) ||
        data.keys.any(
          (key) => !{'version', 'kind', 'secret', 'expiresAt'}.contains(key),
        ) ||
        (data['expiresAt'] != null &&
            (data['expiresAt'] is! int ||
                (data['expiresAt'] as int).abs() > 8640000000000000))) {
      throw const FormatException('Unreadable credential; preserved.');
    }
    return EndpointCredential(
      kind: data['kind'] == 'paired'
          ? EndpointAuthKind.paired
          : EndpointAuthKind.password,
      secret: data['secret'] as String,
      expiresAt: data['expiresAt'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              data['expiresAt'] as int,
              isUtc: true,
            ),
    );
  }

  @override
  Future<void> save(EndpointProfile profile, String secret) => _save(
    profile,
    EndpointCredential(kind: EndpointAuthKind.password, secret: secret),
    legacy: true,
  );

  @override
  Future<void> saveCredential(
    EndpointProfile profile,
    EndpointCredential credential,
  ) => _save(profile, credential, legacy: false);

  Future<void> _save(
    EndpointProfile profile,
    EndpointCredential credential, {
    required bool legacy,
  }) => _run(() async {
    final secret = credential.secret;
    if (secret.isEmpty || secret.runes.any((c) => c < 32 || c == 127)) {
      throw const FormatException('Invalid endpoint credential.');
    }
    await metadata.ensureSchema();
    await _finishCreation();
    await _finishRemoval();
    final index = await _index();
    for (final id in index) {
      await _read(id);
    }
    if (index.length >= maxProfiles ||
        index.contains(profile.id) ||
        await metadata.read(itemKey(profile.id)) != null ||
        await _hasCredential(profile)) {
      throw const FormatException(
        'Profile identity exists or catalog is full.',
      );
    }
    // This non-secret intent owns the exact keys even if a backend commits a
    // write and then throws. Unknown outcomes remain recoverable after restart.
    await metadata.write(
      creationKey,
      jsonEncode({
        'id': profile.id,
        'label': profile.label,
        'url': profile.endpoint.toString(),
        'credentialFormat': legacy ? 'legacy' : 'active',
      }),
    );
    try {
      await metadata.write(
        itemKey(profile.id),
        jsonEncode({
          'id': profile.id,
          'label': profile.label,
          'url': profile.endpoint.toString(),
          'compatibility': 'needsOpenCode2Check',
        }),
      );
      await credentials.write(
        _scope(profile),
        legacy
            ? EndpointCredentialKind.endpointPassword
            : EndpointCredentialKind.activeCredential,
        legacy ? secret : _encodeCredential(credential),
      );
      await metadata.write(indexKey, [...index, profile.id]);
      await metadata.remove(creationKey);
    } on Object {
      if (await _finishCreation()) return;
      rethrow;
    }
  });

  Future<bool> _hasCredential(EndpointProfile profile) async {
    for (final kind in EndpointCredentialKind.values) {
      if (await credentials.read(_scope(profile), kind) != null) return true;
    }
    return false;
  }

  @override
  Future<void> replaceCredential(
    EndpointProfile profile,
    EndpointCredential credential, {
    required EndpointCredential? expected,
  }) => _run(() async {
    await metadata.ensureSchema();
    await _finishCreation();
    await _finishRemoval();
    if (!(await _index()).contains(profile.id) ||
        (await _read(profile.id)).endpoint != profile.endpoint) {
      throw const FormatException('Profile changed; credentials preserved.');
    }
    final current = await _readCredential(profile);
    if (!(current == null ? expected == null : current.matches(expected))) {
      throw const FormatException('Credential changed; preserved.');
    }
    final encoded = _encodeCredential(credential);
    try {
      await credentials.write(
        _scope(profile),
        EndpointCredentialKind.activeCredential,
        encoded,
      );
    } on Object {
      // A failed write can already be committed. Never overwrite or roll back
      // an unknown outcome; the one secure record is authoritative after restart.
      if (await credentials.read(
            _scope(profile),
            EndpointCredentialKind.activeCredential,
          ) ==
          encoded) {
        return;
      }
      throw StateError('Credential update unconfirmed; data preserved.');
    }
    if (await credentials.read(
          _scope(profile),
          EndpointCredentialKind.activeCredential,
        ) !=
        encoded) {
      throw StateError('Credential update unconfirmed; data preserved.');
    }
  });

  @override
  Future<void> remove(EndpointProfile profile) => _run(() async {
    await metadata.ensureSchema();
    await _finishCreation();
    await _finishRemoval();
    final index = await _index();
    if (!index.contains(profile.id)) return;
    final stored = await _read(profile.id);
    if (stored.endpoint != profile.endpoint) {
      throw const FormatException('Profile changed.');
    }
    // Persist explicit intent before hiding the row. A restart can retry only
    // this known identity and origin, without scanning or guessing vault keys.
    await metadata.write(
      removalKey,
      jsonEncode({
        'id': stored.id,
        'label': stored.label,
        'url': stored.endpoint.toString(),
      }),
    );
    await _finishRemoval();
  });

  Future<bool> _finishCreation() async {
    final raw = await metadata.read(creationKey);
    if (raw == null) return false;
    await metadata.ensureSchema();
    final pending = _decodeProfile(raw);
    final format = (jsonDecode(raw as String) as Map)['credentialFormat'];
    if (format != null && format != 'legacy' && format != 'active') {
      throw const FormatException('Unknown creation format; preserved.');
    }
    final kind = format == 'active'
        ? EndpointCredentialKind.activeCredential
        : EndpointCredentialKind.endpointPassword;
    final index = await _index();
    final item = await metadata.read(itemKey(pending.id));
    if (item != null &&
        _decodeProfile(item, expectedId: pending.id).endpoint !=
            pending.endpoint) {
      throw const FormatException('Profile changed; creation preserved.');
    }
    final committed = index.contains(pending.id);
    if (committed) {
      if (item == null ||
          await credentials.read(_scope(pending), kind) == null) {
        throw const FormatException('Incomplete published profile; preserved.');
      }
      if (kind == EndpointCredentialKind.activeCredential) {
        await _readCredential(pending);
      }
    } else {
      await credentials.remove(_scope(pending), kind);
      await metadata.remove(itemKey(pending.id));
    }
    await metadata.remove(creationKey);
    return committed;
  }

  Future<void> _finishRemoval() async {
    final raw = await metadata.read(removalKey);
    if (raw == null) return;
    await metadata.ensureSchema();
    final pending = _decodeProfile(raw);
    final index = await _index();
    if (await metadata.read(itemKey(pending.id)) != null) {
      final stored = await _read(pending.id);
      if (stored.endpoint != pending.endpoint) {
        throw const FormatException('Profile changed; removal preserved.');
      }
    }
    await metadata.write(
      indexKey,
      index.where((id) => id != pending.id).toList(),
    );
    for (final kind in EndpointCredentialKind.values) {
      await credentials.remove(_scope(pending), kind);
    }
    await metadata.remove(itemKey(pending.id));
    await metadata.remove(removalKey);
  }
}
