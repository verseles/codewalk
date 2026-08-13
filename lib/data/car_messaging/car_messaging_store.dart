import 'dart:async';
import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/entities/car_messaging.dart';
import '../../domain/entities/session_attention_overlay/session_attention_models.dart';
import 'car_messaging_file_store.dart';

abstract class CarMessagingKeyStorage {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> delete();
}

class FlutterSecureCarMessagingKeyStorage implements CarMessagingKeyStorage {
  const FlutterSecureCarMessagingKeyStorage([this._storage]);

  static const String storageKey = 'codewalk.car_messaging.key.v1';
  final FlutterSecureStorage? _storage;

  FlutterSecureStorage get _secure => _storage ?? const FlutterSecureStorage();

  @override
  Future<String?> read() => _secure.read(key: storageKey);

  @override
  Future<void> write(String value) =>
      _secure.write(key: storageKey, value: value);

  @override
  Future<void> delete() => _secure.delete(key: storageKey);
}

class CarMessagingStore {
  CarMessagingStore({
    CarMessagingKeyStorage? keyStorage,
    CarMessagingFileStore? fileStore,
    Cipher? cipher,
    DateTime Function()? now,
  }) : _keyStorage = keyStorage ?? const FlutterSecureCarMessagingKeyStorage(),
       _fileStore = fileStore ?? createCarMessagingFileStore(),
       _cipher = cipher ?? AesGcm.with256bits(),
       _now = now ?? DateTime.now;

  static const int envelopeSchemaVersion = 1;
  static const int keyVersion = 1;

  final CarMessagingKeyStorage _keyStorage;
  final CarMessagingFileStore _fileStore;
  final Cipher _cipher;
  final DateTime Function() _now;
  Future<void> _pending = Future<void>.value();

  Future<CarMessagingState> read() => _serialize(_readUnlocked);

  Future<void> upsertThread(CarMessagingThread thread) {
    return _serialize(() async {
      final current = await _readUnlocked();
      final normalized = _clampThread(thread);
      if (!normalized.identity.isValid) return;
      final threads =
          current.threads
              .where((candidate) => candidate.identity != normalized.identity)
              .toList()
            ..add(normalized);
      threads.sort(
        (left, right) =>
            right.updatedAtEpochMs.compareTo(left.updatedAtEpochMs),
      );
      await _writeUnlocked(
        CarMessagingState(
          threads: threads
              .take(kCarMessagingMaxThreads)
              .toList(growable: false),
          replies: current.replies,
        ),
      );
    });
  }

  Future<bool> enqueueReply(CarMessagingReply reply) {
    return _serialize(() async {
      final current = await _readUnlocked();
      final normalized = _clampReply(reply);
      if (normalized.id.isEmpty ||
          !normalized.identity.isValid ||
          normalized.text.isEmpty) {
        return false;
      }
      final withoutDuplicate = current.replies
          .where((candidate) => candidate.id != normalized.id)
          .toList(growable: false);
      if (withoutDuplicate.length != current.replies.length) {
        await _writeUnlocked(
          CarMessagingState(
            threads: current.threads,
            replies: withoutDuplicate..add(normalized),
          ),
        );
        return true;
      }
      final terminal = withoutDuplicate
          .where(
            (candidate) => candidate.state == CarMessagingReplyState.failed,
          )
          .toList(growable: false);
      final nonTerminalCount = withoutDuplicate.length - terminal.length;
      if (nonTerminalCount >= kCarMessagingMaxQueuedReplies) {
        return false;
      }
      final replies =
          [
            ...withoutDuplicate.where(
              (candidate) => candidate.state != CarMessagingReplyState.failed,
            ),
            normalized,
          ]..sort(
            (left, right) =>
                left.createdAtEpochMs.compareTo(right.createdAtEpochMs),
          );
      await _writeUnlocked(
        CarMessagingState(
          threads: current.threads,
          replies: replies
              .skip(
                (replies.length - kCarMessagingMaxQueuedReplies).clamp(
                  0,
                  replies.length,
                ),
              )
              .toList(growable: false),
        ),
      );
      return true;
    });
  }

  Future<CarMessagingReply?> claimReply({
    required String replyId,
    required CarMessagingReplyState from,
    required CarMessagingReplyState to,
    int attemptsDelta = 1,
  }) {
    return _serialize(() async {
      final current = await _readUnlocked();
      final index = current.replies.indexWhere(
        (candidate) => candidate.id == replyId,
      );
      if (index < 0 || current.replies[index].state != from) return null;
      final claimed = CarMessagingReply(
        id: current.replies[index].id,
        identity: current.replies[index].identity,
        text: current.replies[index].text,
        createdAtEpochMs: current.replies[index].createdAtEpochMs,
        state: to,
        attempts: current.replies[index].attempts + attemptsDelta,
        baselineAssistantMessageId:
            current.replies[index].baselineAssistantMessageId,
      );
      final replies = List<CarMessagingReply>.of(current.replies)
        ..[index] = claimed;
      await _writeUnlocked(
        CarMessagingState(threads: current.threads, replies: replies),
      );
      return claimed;
    });
  }

  Future<void> updateReply(CarMessagingReply reply) {
    return _serialize(() async {
      final current = await _readUnlocked();
      if (!current.replies.any((candidate) => candidate.id == reply.id)) {
        return;
      }
      await _writeUnlocked(
        CarMessagingState(
          threads: current.threads,
          replies: current.replies
              .map(
                (candidate) =>
                    candidate.id == reply.id ? _clampReply(reply) : candidate,
              )
              .toList(growable: false),
        ),
      );
    });
  }

  Future<void> removeReply(String replyId) {
    return _serialize(() async {
      final current = await _readUnlocked();
      final replies = current.replies
          .where((reply) => reply.id != replyId)
          .toList(growable: false);
      if (replies.length == current.replies.length) return;
      await _writeUnlocked(
        CarMessagingState(threads: current.threads, replies: replies),
      );
    });
  }

  Future<void> removeServer(String serverId) {
    return _serialize(() async {
      final current = await _readUnlocked();
      final normalized = serverId.trim();
      final threads = current.threads
          .where((thread) => thread.identity.serverId != normalized)
          .toList(growable: false);
      final replies = current.replies
          .where((reply) => reply.identity.serverId != normalized)
          .toList(growable: false);
      if (threads.length == current.threads.length &&
          replies.length == current.replies.length) {
        return;
      }
      await _writeUnlocked(
        CarMessagingState(threads: threads, replies: replies),
      );
    });
  }

  Future<void> removeIdentity(SessionAttentionIdentity identity) {
    return _serialize(() async {
      final current = await _readUnlocked();
      final normalized = _clampIdentity(identity);
      final threads = current.threads
          .where((thread) => thread.identity != normalized)
          .toList(growable: false);
      final replies = current.replies
          .where((reply) => reply.identity != normalized)
          .toList(growable: false);
      if (threads.length == current.threads.length &&
          replies.length == current.replies.length) {
        return;
      }
      await _writeUnlocked(
        CarMessagingState(threads: threads, replies: replies),
      );
    });
  }

  Future<void> markRead(SessionAttentionIdentity identity) {
    return _serialize(() async {
      final current = await _readUnlocked();
      final normalized = identity.normalized();
      final threads = current.threads
          .map(
            (thread) => thread.identity == normalized
                ? CarMessagingThread(
                    identity: thread.identity,
                    title: thread.title,
                    entries: thread.entries,
                    updatedAtEpochMs: thread.updatedAtEpochMs,
                  )
                : thread,
          )
          .toList(growable: false);
      await _writeUnlocked(
        CarMessagingState(threads: threads, replies: current.replies),
      );
    });
  }

  Future<void> clear() {
    return _serialize(() async {
      await _fileStore.delete();
      await _keyStorage.delete();
    });
  }

  Future<CarMessagingState> _readUnlocked() async {
    final raw = await _fileStore.read();
    if (raw == null || raw.trim().isEmpty) return const CarMessagingState();
    try {
      final envelope = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      if (envelope['schemaVersion'] != envelopeSchemaVersion ||
          envelope['keyVersion'] != keyVersion) {
        throw const FormatException('Unsupported car messaging envelope.');
      }
      final encodedKey = await _keyStorage.read();
      if (encodedKey == null || encodedKey.isEmpty) {
        throw const FormatException('Car messaging key is missing.');
      }
      final clear = await _cipher.decrypt(
        SecretBox(
          base64Decode(envelope['ciphertext'] as String),
          nonce: base64Decode(envelope['nonce'] as String),
          mac: Mac(base64Decode(envelope['mac'] as String)),
        ),
        secretKey: SecretKey(base64Decode(encodedKey)),
      );
      final decoded = CarMessagingState.fromJson(
        Map<String, dynamic>.from(jsonDecode(utf8.decode(clear)) as Map),
      );
      final pruned = _prune(decoded);
      if (_changed(decoded, pruned)) {
        if (pruned.threads.isEmpty && pruned.replies.isEmpty) {
          await _fileStore.delete();
        } else {
          await _writeEnvelope(pruned, encodedKey);
        }
      }
      return pruned;
    } on FormatException catch (_) {
      await _fileStore.delete();
      return const CarMessagingState();
    } on SecretBoxAuthenticationError catch (_) {
      await _fileStore.delete();
      return const CarMessagingState();
    } on TypeError catch (_) {
      await _fileStore.delete();
      return const CarMessagingState();
    } on ArgumentError catch (_) {
      await _fileStore.delete();
      return const CarMessagingState();
    }
  }

  bool _changed(CarMessagingState before, CarMessagingState after) {
    return before.threads.length != after.threads.length ||
        before.replies.length != after.replies.length ||
        before.threads.asMap().entries.any(
          (entry) => entry.value.identity != after.threads[entry.key].identity,
        ) ||
        before.replies.asMap().entries.any(
          (entry) => entry.value.id != after.replies[entry.key].id,
        );
  }

  CarMessagingState _prune(CarMessagingState state) {
    final nowMs = _now().millisecondsSinceEpoch;
    final threadCutoff = nowMs - kCarMessagingRetention.inMilliseconds;
    final replyCutoff = nowMs - kCarMessagingReplyRetention.inMilliseconds;
    return CarMessagingState(
      threads: state.threads
          .where((thread) => thread.updatedAtEpochMs >= threadCutoff)
          .take(kCarMessagingMaxThreads)
          .toList(growable: false),
      replies: state.replies
          .where(
            (reply) =>
                reply.state == CarMessagingReplyState.awaitingFinal ||
                reply.createdAtEpochMs >= replyCutoff,
          )
          .take(kCarMessagingMaxQueuedReplies)
          .toList(growable: false),
    );
  }

  Future<void> _writeUnlocked(CarMessagingState state) async {
    var encodedKey = await _keyStorage.read();
    if (encodedKey == null || encodedKey.isEmpty) {
      encodedKey = base64Encode(
        await (await _cipher.newSecretKey()).extractBytes(),
      );
      await _keyStorage.write(encodedKey);
    }
    await _writeEnvelope(_prune(state), encodedKey);
  }

  Future<void> _writeEnvelope(
    CarMessagingState state,
    String encodedKey,
  ) async {
    final box = await _cipher.encrypt(
      utf8.encode(jsonEncode(state.toJson())),
      secretKey: SecretKey(base64Decode(encodedKey)),
    );
    await _fileStore.writeAtomically(
      jsonEncode(<String, dynamic>{
        'schemaVersion': envelopeSchemaVersion,
        'keyVersion': keyVersion,
        'nonce': base64Encode(box.nonce),
        'ciphertext': base64Encode(box.cipherText),
        'mac': base64Encode(box.mac.bytes),
      }),
    );
  }

  CarMessagingThread _clampThread(CarMessagingThread thread) {
    final normalized = thread.normalized();
    return CarMessagingThread(
      identity: _clampIdentity(normalized.identity),
      title: normalized.title,
      entries: normalized.entries
          .map(
            (entry) => CarMessagingEntry(
              role: entry.role,
              text: entry.text,
              timestampEpochMs: entry.timestampEpochMs,
              messageId: _boundedOptional(entry.messageId),
            ),
          )
          .toList(growable: false),
      updatedAtEpochMs: normalized.updatedAtEpochMs,
      unread: normalized.unread,
    );
  }

  CarMessagingReply _clampReply(CarMessagingReply reply) {
    return CarMessagingReply(
      id: _bounded(reply.id.trim()),
      identity: _clampIdentity(reply.identity),
      text: String.fromCharCodes(
        reply.text.trim().runes.take(kCarMessagingMaxMessageScalars),
      ),
      createdAtEpochMs: reply.createdAtEpochMs,
      state: reply.state,
      attempts: reply.attempts.clamp(0, 3),
      baselineAssistantMessageId: _boundedOptional(
        reply.baselineAssistantMessageId,
      ),
    );
  }

  SessionAttentionIdentity _clampIdentity(SessionAttentionIdentity identity) {
    final normalized = identity.normalized();
    return SessionAttentionIdentity(
      serverId: _bounded(normalized.serverId),
      directory: _bounded(normalized.directory),
      rootSessionId: _bounded(normalized.rootSessionId),
    );
  }

  String _bounded(String value) =>
      String.fromCharCodes(value.runes.take(kCarMessagingMaxMessageScalars));

  String? _boundedOptional(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty
        ? null
        : _bounded(normalized);
  }

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final result = _pending.then((_) => _fileStore.synchronized(operation));
    _pending = result.then<void>((_) {}, onError: (_, _) {});
    return result;
  }
}
