import 'dart:async';
import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/entities/session_attention_overlay/session_attention_models.dart';
import 'session_attention_snapshot_file_store.dart';

class SessionAttentionSnapshotStoreException implements Exception {
  const SessionAttentionSnapshotStoreException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => cause == null
      ? 'SessionAttentionSnapshotStoreException: $message'
      : 'SessionAttentionSnapshotStoreException: $message ($cause)';
}

abstract class SessionAttentionSnapshotKeyStorage {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> delete();
}

class FlutterSecureSessionAttentionSnapshotKeyStorage
    implements SessionAttentionSnapshotKeyStorage {
  const FlutterSecureSessionAttentionSnapshotKeyStorage([this._secureStorage]);

  static const String storageKey = 'codewalk.session_attention.snapshot.key.v1';
  final FlutterSecureStorage? _secureStorage;

  FlutterSecureStorage get _storage =>
      _secureStorage ?? const FlutterSecureStorage();

  @override
  Future<String?> read() => _storage.read(key: storageKey);

  @override
  Future<void> write(String value) =>
      _storage.write(key: storageKey, value: value);

  @override
  Future<void> delete() => _storage.delete(key: storageKey);
}

class SessionAttentionSnapshotReadResult {
  const SessionAttentionSnapshotReadResult({
    required this.payload,
    this.recoveredFromCorruption = false,
  });

  final SessionAttentionSnapshotPayload payload;
  final bool recoveredFromCorruption;
}

class SessionAttentionSnapshotStore {
  SessionAttentionSnapshotStore({
    SessionAttentionSnapshotKeyStorage? keyStorage,
    SessionAttentionSnapshotFileStore? fileStore,
    Cipher? cipher,
  }) : _keyStorage =
           keyStorage ??
           const FlutterSecureSessionAttentionSnapshotKeyStorage(),
       _fileStore = fileStore ?? createSessionAttentionSnapshotFileStore(),
       _cipher = cipher ?? AesGcm.with256bits();

  static const int envelopeSchemaVersion = 1;
  static const int keyVersion = 1;
  static final StreamController<SessionAttentionSnapshotPayload>
  _changesController =
      StreamController<SessionAttentionSnapshotPayload>.broadcast();

  static Stream<SessionAttentionSnapshotPayload> get changes =>
      _changesController.stream;

  final SessionAttentionSnapshotKeyStorage _keyStorage;
  final SessionAttentionSnapshotFileStore _fileStore;
  final Cipher _cipher;
  Future<void> _pending = Future<void>.value();
  String? _cachedEncodedKey;

  Future<SessionAttentionSnapshotReadResult> read() {
    return _serialize(_readUnlocked);
  }

  Future<void> upsert(SessionAttentionItem item) {
    return _serialize(() async {
      final current = (await _readUnlocked()).payload;
      final normalized = item.identity.normalized();
      final normalizedItem = item.withIdentity(normalized);
      final messageId = item.assistantMessageId?.trim();
      final tombstone = _tombstoneKey(
        normalized,
        messageId?.isNotEmpty == true ? messageId : item.contentDigest,
      );
      if (tombstone != null &&
          current.dismissalTombstones.contains(tombstone)) {
        return;
      }
      SessionAttentionItem? existing;
      for (final candidate in current.items) {
        if (candidate.identity == normalized) {
          existing = candidate;
          break;
        }
      }
      if (existing != null &&
          (existing.revision > normalizedItem.revision ||
              (existing.revision == normalizedItem.revision &&
                  existing.assistantMessageId ==
                      normalizedItem.assistantMessageId &&
                  existing.contentDigest == normalizedItem.contentDigest))) {
        return;
      }
      final items =
          current.items
              .where((existing) => existing.identity != normalized)
              .toList()
            ..add(normalizedItem);
      await _writeUnlocked(
        SessionAttentionSnapshotPayload(
          revision: current.revision + 1,
          items: List<SessionAttentionItem>.unmodifiable(items),
          dismissalTombstones: current.dismissalTombstones,
        ),
      );
    });
  }

  Future<void> dismiss({
    required SessionAttentionIdentity identity,
    required String assistantMessageId,
  }) {
    return _serialize(() async {
      final current = (await _readUnlocked()).payload;
      final normalized = identity.normalized();
      final tombstone = _tombstoneKey(normalized, assistantMessageId);
      if (tombstone == null) {
        return;
      }
      final tombstones = Set<String>.from(current.dismissalTombstones)
        ..add(tombstone);
      final prefix = '${normalized.key}::';
      final matching = tombstones
          .where((key) => key.startsWith(prefix))
          .toList(growable: false);
      for (final expired in matching.take(
        (matching.length - 8).clamp(0, matching.length).toInt(),
      )) {
        tombstones.remove(expired);
      }
      await _writeUnlocked(
        SessionAttentionSnapshotPayload(
          revision: current.revision + 1,
          items: current.items
              .where(
                (item) =>
                    item.identity != normalized ||
                    _effectiveToken(item) != assistantMessageId.trim(),
              )
              .toList(growable: false),
          dismissalTombstones: tombstones,
        ),
      );
    });
  }

  Future<void> suppressLive(SessionAttentionItem item) {
    return suppressLiveIdentity(
      identity: item.identity,
      contentDigest: item.contentDigest,
    );
  }

  Future<void> suppressLiveIdentity({
    required SessionAttentionIdentity identity,
    required String contentDigest,
  }) {
    return _serialize(() async {
      final current = (await _readUnlocked()).payload;
      final normalized = identity.normalized();
      final tombstone = _tombstoneKey(normalized, contentDigest);
      if (tombstone == null) return;
      final tombstones = Set<String>.from(current.dismissalTombstones)
        ..add(tombstone);
      final prefix = '${normalized.key}::';
      final matching = tombstones
          .where((key) => key.startsWith(prefix))
          .toList(growable: false);
      for (final expired in matching.take(
        (matching.length - 8).clamp(0, matching.length).toInt(),
      )) {
        tombstones.remove(expired);
      }
      await _writeUnlocked(
        SessionAttentionSnapshotPayload(
          revision: current.revision + 1,
          items: current.items
              .where(
                (item) =>
                    item.identity != normalized ||
                    _effectiveToken(item) != contentDigest.trim(),
              )
              .toList(growable: false),
          dismissalTombstones: tombstones,
        ),
      );
    });
  }

  Future<void> removeIdentity(SessionAttentionIdentity identity) {
    return _serialize(() async {
      final current = (await _readUnlocked()).payload;
      final normalized = identity.normalized();
      final hasItem = current.items.any((item) => item.identity == normalized);
      final tombstonePrefix = '${normalized.key}::';
      final hasTombstone = current.dismissalTombstones.any(
        (key) => key.startsWith(tombstonePrefix),
      );
      if (!hasItem && !hasTombstone) return;
      await _writeUnlocked(
        SessionAttentionSnapshotPayload(
          revision: current.revision + 1,
          items: current.items
              .where((item) => item.identity != normalized)
              .toList(growable: false),
          dismissalTombstones: current.dismissalTombstones
              .where((key) => !key.startsWith(tombstonePrefix))
              .toSet(),
        ),
      );
    });
  }

  Future<void> consume(SessionAttentionItem selected) {
    return _serialize(() async {
      final current = (await _readUnlocked()).payload;
      final normalized = selected.identity.normalized();
      final selectedToken = _effectiveToken(selected);
      if (selectedToken.isEmpty ||
          !current.items.any(
            (item) =>
                item.identity == normalized &&
                _effectiveToken(item) == selectedToken,
          )) {
        return;
      }
      await _writeUnlocked(
        SessionAttentionSnapshotPayload(
          revision: current.revision + 1,
          items: current.items
              .where(
                (item) =>
                    item.identity != normalized ||
                    _effectiveToken(item) != selectedToken,
              )
              .toList(growable: false),
          dismissalTombstones: current.dismissalTombstones,
        ),
      );
    });
  }

  Future<void> removeServer(String serverId) {
    return _serialize(() async {
      final current = (await _readUnlocked()).payload;
      final normalized = serverId.trim();
      await _writeUnlocked(
        SessionAttentionSnapshotPayload(
          revision: current.revision + 1,
          items: current.items
              .where((item) => item.identity.serverId != normalized)
              .toList(growable: false),
          dismissalTombstones: current.dismissalTombstones
              .where((key) => !key.startsWith('$normalized::'))
              .toSet(),
        ),
      );
    });
  }

  Future<void> clear() {
    return _serialize(() async {
      await _fileStore.delete();
      await _keyStorage.delete();
      _cachedEncodedKey = null;
      _changesController.add(const SessionAttentionSnapshotPayload());
    });
  }

  Future<SessionAttentionSnapshotReadResult> _readUnlocked() async {
    late final String? raw;
    try {
      raw = await _fileStore.read();
    } catch (error) {
      throw SessionAttentionSnapshotStoreException(
        'Encrypted session snapshot storage is unavailable.',
        error,
      );
    }
    if (raw == null || raw.trim().isEmpty) {
      return const SessionAttentionSnapshotReadResult(
        payload: SessionAttentionSnapshotPayload(),
      );
    }
    late final Map<String, dynamic> envelope;
    try {
      envelope = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      if (envelope['schemaVersion'] != envelopeSchemaVersion ||
          envelope['keyVersion'] != keyVersion) {
        throw const FormatException('Unsupported snapshot envelope.');
      }
    } catch (_) {
      return _recoverFromCorruption();
    }
    late final String? encodedKey;
    if (_cachedEncodedKey != null && _cachedEncodedKey!.isNotEmpty) {
      encodedKey = _cachedEncodedKey;
    } else {
      try {
        encodedKey = await _keyStorage.read();
        if (encodedKey != null && encodedKey.isNotEmpty) {
          _cachedEncodedKey = encodedKey;
        }
      } catch (error) {
        throw SessionAttentionSnapshotStoreException(
          'Secure session snapshot key storage is unavailable.',
          error,
        );
      }
    }
    try {
      if (encodedKey == null || encodedKey.isEmpty) {
        throw const FormatException('Snapshot key is missing.');
      }
      final box = SecretBox(
        base64Decode(envelope['ciphertext'] as String),
        nonce: base64Decode(envelope['nonce'] as String),
        mac: Mac(base64Decode(envelope['mac'] as String)),
      );
      final clearBytes = await _cipher.decrypt(
        box,
        secretKey: SecretKey(base64Decode(encodedKey)),
      );
      final payload = SessionAttentionSnapshotPayload.fromJson(
        Map<String, dynamic>.from(jsonDecode(utf8.decode(clearBytes)) as Map),
      );
      return SessionAttentionSnapshotReadResult(payload: payload);
    } catch (_) {
      return _recoverFromCorruption();
    }
  }

  Future<SessionAttentionSnapshotReadResult> _recoverFromCorruption() async {
    await _fileStore.delete();
    _changesController.add(const SessionAttentionSnapshotPayload());
    return const SessionAttentionSnapshotReadResult(
      payload: SessionAttentionSnapshotPayload(),
      recoveredFromCorruption: true,
    );
  }

  Future<void> _writeUnlocked(SessionAttentionSnapshotPayload payload) async {
    try {
      var encodedKey = _cachedEncodedKey;
      if (encodedKey == null || encodedKey.isEmpty) {
        encodedKey = await _keyStorage.read();
        if (encodedKey != null && encodedKey.isNotEmpty) {
          _cachedEncodedKey = encodedKey;
        }
      }
      if (encodedKey == null || encodedKey.isEmpty) {
        final generated = await _cipher.newSecretKey();
        encodedKey = base64Encode(await generated.extractBytes());
        await _keyStorage.write(encodedKey);
        _cachedEncodedKey = encodedKey;
      }
      final box = await _cipher.encrypt(
        utf8.encode(jsonEncode(payload.toJson())),
        secretKey: SecretKey(base64Decode(encodedKey)),
      );
      final envelope = <String, dynamic>{
        'schemaVersion': envelopeSchemaVersion,
        'keyVersion': keyVersion,
        'nonce': base64Encode(box.nonce),
        'ciphertext': base64Encode(box.cipherText),
        'mac': base64Encode(box.mac.bytes),
        'updatedAtEpochMs': DateTime.now().millisecondsSinceEpoch,
      };
      await _fileStore.writeAtomically(jsonEncode(envelope));
      _changesController.add(payload);
    } catch (error) {
      throw SessionAttentionSnapshotStoreException(
        'Encrypted session snapshot storage is unavailable.',
        error,
      );
    }
  }

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final result = _pending.then((_) => _fileStore.synchronized(operation));
    _pending = result.then<void>((_) {}, onError: (_, _) {});
    return result;
  }

  String? _tombstoneKey(
    SessionAttentionIdentity identity,
    String? assistantMessageId,
  ) {
    final normalizedMessageId = assistantMessageId?.trim();
    if (normalizedMessageId == null || normalizedMessageId.isEmpty) {
      return null;
    }
    return '${identity.key}::$normalizedMessageId';
  }

  String _effectiveToken(SessionAttentionItem item) {
    final messageId = item.assistantMessageId?.trim();
    return messageId?.isNotEmpty == true
        ? messageId!
        : item.contentDigest.trim();
  }
}
