import 'dart:async';
import 'dart:convert';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../storage/metadata_store.dart';
import '../storage/payload_store.dart';
import '../storage/storage_support.dart';

/// The identity of a workspace draft before a session exists: the server, the
/// harness instance, and the canonical project directory.
@immutable
final class WorkspaceDraftKey {
  const WorkspaceDraftKey({
    required this.profileId,
    required this.harnessId,
    required this.canonicalDirectory,
  }) : assert(profileId != ''),
       assert(harnessId != ''),
       assert(canonicalDirectory != '');

  factory WorkspaceDraftKey.fromStorageKey(String value) {
    final list = jsonDecode(value);
    if (list is! List ||
        list.length != 5 ||
        list[0] != 'ws_draft' ||
        list[1] != 1 ||
        list.skip(2).any((part) => part is! String || part.isEmpty)) {
      throw FormatException('Invalid workspace draft storage key: $value');
    }
    return WorkspaceDraftKey(
      profileId: list[2] as String,
      harnessId: list[3] as String,
      canonicalDirectory: list[4] as String,
    );
  }

  final String profileId;
  final String harnessId;
  final String canonicalDirectory;

  String get storageKey =>
      jsonEncode(['ws_draft', 1, profileId, harnessId, canonicalDirectory]);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkspaceDraftKey &&
          other.profileId == profileId &&
          other.harnessId == harnessId &&
          other.canonicalDirectory == canonicalDirectory;

  @override
  int get hashCode => Object.hash(profileId, harnessId, canonicalDirectory);

  @override
  String toString() =>
      'WorkspaceDraftKey($profileId, $harnessId, $canonicalDirectory)';
}

/// The state of a workspace draft through creation and first-send bootstrapping.
enum WorkspaceDraftStatus {
  /// The user is editing the unsent draft.
  ready,

  /// An attempt fence is persisted and lazy creation is in flight.
  creating,

  /// The create was admitted or returned identity; the session is being
  /// read and bound.
  confirming,

  /// The create was refused; the draft text is kept for retry or edit.
  failed,

  /// The create outcome was uncertain (lost answer, timeout); no replay.
  uncertain,

  /// The created session was bound and the prompt handed off.
  bound,
}

/// One persisted workspace draft record.
@immutable
final class WorkspaceDraftEntry {
  const WorkspaceDraftEntry({
    required this.key,
    required this.text,
    this.status = WorkspaceDraftStatus.ready,
    this.fenceCommandId,
    this.createdSession,
  });

  final WorkspaceDraftKey key;
  final String text;
  final WorkspaceDraftStatus status;
  final String? fenceCommandId;
  final SessionRef? createdSession;

  WorkspaceDraftEntry copyWith({
    String? text,
    WorkspaceDraftStatus? status,
    String? fenceCommandId,
    SessionRef? createdSession,
  }) => WorkspaceDraftEntry(
    key: key,
    text: text ?? this.text,
    status: status ?? this.status,
    fenceCommandId: status == WorkspaceDraftStatus.ready
        ? null
        : fenceCommandId ?? this.fenceCommandId,
    createdSession: status == WorkspaceDraftStatus.ready
        ? null
        : createdSession ?? this.createdSession,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkspaceDraftEntry &&
          other.key == key &&
          other.text == text &&
          other.status == status &&
          other.fenceCommandId == fenceCommandId &&
          other.createdSession == createdSession;

  @override
  int get hashCode =>
      Object.hash(key, text, status, fenceCommandId, createdSession);
}

/// Persists New Chat draft state per project context, including an attempt
/// fence before sending create on first send.
final class WorkspaceDraftStore {
  WorkspaceDraftStore({
    required PayloadStore payloads,
    required V2MetadataStore index,
    this.delay = const Duration(milliseconds: 500),
  }) : _payloads = payloads,
       _index = index;

  static const indexKey = 'cw2.workspace.drafts';
  static const version = 1;
  static const maxDrafts = 32;
  static const maxDraftBytes = 128 * 1024;
  static String keyFor(WorkspaceDraftKey key) =>
      'cw2.ws_drafts.v1.${sha256.convert(utf8.encode(key.storageKey))}';

  final PayloadStore _payloads;
  final V2MetadataStore _index;
  final Duration delay;
  // One lane includes the index and payloads, so eviction cannot race a fence.
  final _executor = KeySerialExecutor();
  final _saved = <WorkspaceDraftKey, WorkspaceDraftEntry>{};
  final _loaded = <WorkspaceDraftKey>{};
  final _ownAttempts = <WorkspaceDraftKey, String>{};
  final _blocked = <WorkspaceDraftKey>{};
  final _pending = <WorkspaceDraftKey, String>{};
  final _owners = <WorkspaceDraftKey, void Function(String text)>{};
  Timer? _timer;

  bool isUnreadable(WorkspaceDraftKey key) => _blocked.contains(key);
  Future<WorkspaceDraftEntry?> read(WorkspaceDraftKey key) =>
      _executor.run(indexKey, () async {
        final stored = await _load(key);
        final pending = _pending[key];
        // Reopening a context must include edits still waiting for debounce
        // or retry, while its persisted attempt fence remains authoritative.
        return pending == null
            ? stored
            : (stored ?? WorkspaceDraftEntry(key: key, text: pending)).copyWith(
                text: pending,
              );
      });

  Future<WorkspaceDraftEntry?> _load(WorkspaceDraftKey key) async {
    final payloadKey = keyFor(key);
    try {
      if (await _payloads.contains(payloadKey)) {
        final raw = await _payloads.read(payloadKey);
        final entry = decode(raw, key);
        if (entry != null) {
          _blocked.remove(key);
          _loaded.add(key);
          final unsettled = const {
            WorkspaceDraftStatus.creating,
            WorkspaceDraftStatus.confirming,
            WorkspaceDraftStatus.bound,
          }.contains(entry.status);
          final current = unsettled && _ownAttempts[key] != entry.fenceCommandId
              ? entry.copyWith(status: WorkspaceDraftStatus.uncertain)
              : entry;
          _saved[key] = current;
          return current;
        }
        if (raw != null || await _payloads.contains(payloadKey)) {
          _blocked.add(key);
          return null;
        }
      }
      _loaded.add(key);
      _blocked.remove(key);
      _saved.remove(key);
    } on Object {
      _blocked.add(key);
    }
    return null;
  }

  Future<bool> _writable(WorkspaceDraftKey key) async {
    if (!_loaded.contains(key) || _blocked.contains(key)) await _load(key);
    return !_blocked.contains(key);
  }

  void attach(WorkspaceDraftKey key, void Function(String text) forgotten) =>
      _owners[key] = forgotten;
  void detach(WorkspaceDraftKey key, void Function(String text) forgotten) {
    if (_owners[key] == forgotten) _owners.remove(key);
  }

  void save(WorkspaceDraftKey key, String text) {
    _pending[key] = text;
    _timer ??= Timer(delay, () {
      _timer = null;
      unawaited(flush());
    });
  }

  void forget(WorkspaceDraftKey key, String text) {
    if (_pending[key] == text) _pending.remove(key);
    unawaited(
      _executor.run(indexKey, () async {
        if (!await _writable(key) || _saved[key]?.text != text) return;
        await _remove(key);
        _owners[key]?.call(text);
      }),
    );
  }

  Future<void> flush() async {
    _timer?.cancel();
    _timer = null;
    final batch = Map.of(_pending);
    await Future.wait([
      for (final MapEntry(:key, :value) in batch.entries)
        _executor.run(indexKey, () async {
          // Reads ahead of this write must still see the pending edit. A
          // newer edit made while the batch waited belongs to the next write.
          if (_pending[key] == value) _pending.remove(key);
          if (!await _writable(key)) {
            _pending.putIfAbsent(key, () => value);
            return;
          }
          final current = _saved[key];
          if (value.isEmpty &&
              (current == null ||
                  current.status == WorkspaceDraftStatus.ready)) {
            await _remove(key);
            return;
          }
          final entry = (current ?? WorkspaceDraftEntry(key: key, text: value))
              .copyWith(text: value);
          if (!await _reserve(key) || !await _persist(entry)) {
            _pending.putIfAbsent(key, () => value);
          }
        }),
    ]);
    await _executor.drain();
  }

  Future<bool> setAttemptFence(
    WorkspaceDraftKey key, {
    required String commandId,
    required String text,
  }) async {
    await flush();
    return _executor.run(indexKey, () async {
      if (!await _writable(key) ||
          commandId.isEmpty ||
          (_saved[key] != null &&
              _saved[key]!.status != WorkspaceDraftStatus.ready)) {
        return false;
      }
      if (!await _reserve(key)) return false;
      final written = await _persist(
        WorkspaceDraftEntry(
          key: key,
          text: text,
          status: WorkspaceDraftStatus.creating,
          fenceCommandId: commandId,
        ),
      );
      if (written) _ownAttempts[key] = commandId;
      return written;
    });
  }

  Future<bool> updateStatus(
    WorkspaceDraftKey key,
    WorkspaceDraftStatus status, {
    SessionRef? createdSession,
  }) => _executor.run(indexKey, () async {
    if (!await _writable(key)) return false;
    final current = _saved[key];
    if (current == null) return false;
    return _persist(
      current.copyWith(status: status, createdSession: createdSession),
    );
  });

  /// Only the original attempt may consume its draft after the outbox recorded
  /// the prompt. Edits made while that send settled remain a fresh draft.
  Future<void> finishAttempt(
    WorkspaceDraftKey key,
    String commandId,
    String text,
  ) => _executor.run(indexKey, () async {
    if (!await _writable(key)) return;
    final current = _saved[key];
    if (current == null || current.fenceCommandId != commandId) return;
    final edited = _pending[key] ?? current.text;
    if (edited == text) {
      _pending.remove(key);
      await _remove(key);
      _owners[key]?.call(text);
    } else {
      await _persist(
        current.copyWith(text: edited, status: WorkspaceDraftStatus.ready),
      );
    }
  });
  Future<void> clear(WorkspaceDraftKey key) {
    _pending.remove(key);
    return _executor.run(indexKey, () async {
      if (await _writable(key)) await _remove(key);
    });
  }

  Future<bool> _persist(WorkspaceDraftEntry entry) async {
    if (utf8.encode(entry.text).length > maxDraftBytes) return false;
    try {
      if (await _payloads.write(keyFor(entry.key), encode(entry)) ==
          PayloadWriteResult.refusedOversized) {
        return false;
      }
      _loaded.add(entry.key);
      _saved[entry.key] = entry;
      if (entry.status == WorkspaceDraftStatus.ready) {
        _ownAttempts.remove(entry.key);
      }
      return true;
    } on Object {
      return false;
    }
  }

  Future<void> _remove(WorkspaceDraftKey key) async {
    try {
      await _payloads.remove(keyFor(key));
      _saved.remove(key);
      _ownAttempts.remove(key);
      final keys = await _readIndex();
      if (keys != null && keys.contains(key.storageKey)) {
        await _writeIndex([...keys.where((id) => id != key.storageKey)]);
      }
    } on Object {
      /* Preserve an unreadable record or failed deletion. */
    }
  }

  Future<bool> _reserve(WorkspaceDraftKey key) async {
    final keys = await _readIndex();
    if (keys == null) return false;
    if (keys.contains(key.storageKey)) return true;
    final next = [...keys];
    WorkspaceDraftKey? evicted;
    if (next.length >= maxDrafts) {
      for (final id in keys) {
        final other = WorkspaceDraftKey.fromStorageKey(id);
        final entry = await _load(other);
        if (!_blocked.contains(other) &&
            (entry == null || entry.status == WorkspaceDraftStatus.ready)) {
          evicted = other;
          next.remove(id);
          break;
        }
      }
      // Losing an unresolved fence could permit a duplicate create.
      if (evicted == null) return false;
    }
    next.add(key.storageKey);
    if (!await _writeIndex(next)) return false;
    if (evicted != null) {
      try {
        await _payloads.remove(keyFor(evicted));
        _saved.remove(evicted);
      } on Object {
        /* A failed cleanup does not weaken any attempt fence. */
      }
    }
    return true;
  }

  Future<List<String>?> _readIndex() async {
    try {
      return decodeIndex(await _index.read(indexKey));
    } on Object {
      return null;
    }
  }

  Future<bool> _writeIndex(List<String> keys) async {
    try {
      await _index.write(
        indexKey,
        jsonEncode({'version': version, 'keys': keys}),
      );
      return true;
    } on Object {
      return false;
    }
  }

  @visibleForTesting
  static String encode(WorkspaceDraftEntry entry) => jsonEncode({
    'version': version,
    'profileId': entry.key.profileId,
    'harnessId': entry.key.harnessId,
    'canonicalDirectory': entry.key.canonicalDirectory,
    'text': entry.text,
    'status': entry.status.name,
    if (entry.fenceCommandId != null) 'fenceCommandId': entry.fenceCommandId,
    if (entry.createdSession != null)
      'createdSession': entry.createdSession!.storageKey,
  });
  @visibleForTesting
  static WorkspaceDraftEntry? decode(String? raw, WorkspaceDraftKey key) {
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic> ||
          json['version'] != version ||
          json['profileId'] != key.profileId ||
          json['harnessId'] != key.harnessId ||
          json['canonicalDirectory'] != key.canonicalDirectory ||
          json['text'] is! String) {
        return null;
      }
      final status = WorkspaceDraftStatus.values.byName(
        json['status'] as String,
      );
      final fence = json['fenceCommandId'] as String?;
      final ref = json['createdSession'] == null
          ? null
          : SessionRef.fromStorageKey(json['createdSession'] as String);
      if (status != WorkspaceDraftStatus.ready &&
          (fence == null || fence.isEmpty)) {
        return null;
      }
      if (ref != null &&
          (ref.host.value != key.profileId ||
              ref.harness.value != key.harnessId)) {
        return null;
      }
      if (const {
            WorkspaceDraftStatus.confirming,
            WorkspaceDraftStatus.bound,
          }.contains(status) &&
          ref == null) {
        return null;
      }
      return WorkspaceDraftEntry(
        key: key,
        text: json['text'] as String,
        status: status,
        fenceCommandId: fence,
        createdSession: ref,
      );
    } on Object {
      return null;
    }
  }

  @visibleForTesting
  static List<String>? decodeIndex(Object? raw) {
    if (raw == null) return [];
    if (raw is! String) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic> ||
          json['version'] != version ||
          json['keys'] is! List) {
        return null;
      }
      final keys = json['keys'] as List;
      if (keys.length > maxDrafts) return null;
      final result = <String>[];
      for (final id in keys) {
        if (id is! String || result.contains(id)) return null;
        WorkspaceDraftKey.fromStorageKey(id);
        result.add(id);
      }
      return result;
    } on Object {
      return null;
    }
  }
}
