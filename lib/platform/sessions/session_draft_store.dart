import 'dart:async';
import 'dart:convert';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../storage/metadata_store.dart';
import '../storage/payload_store.dart';
import '../storage/storage_support.dart';

/// The unsent prompt of each session, kept on this device so it survives
/// leaving the session and the app being killed.
///
/// While the user types, the text is written at most once per [delay]; an
/// empty text removes the draft at once, and [flush] writes what is pending
/// when the app leaves the foreground. A draft that could not be read is
/// never written over or removed. The drafts of at most [maxDrafts] sessions
/// are kept: a new one evicts the draft written longest ago.
final class SessionDraftStore {
  SessionDraftStore({
    required PayloadStore payloads,
    required V2MetadataStore index,
    this.delay = const Duration(milliseconds: 500),
  }) : _payloads = payloads,
       _index = index;

  /// The record of the sessions that have a stored draft, oldest first.
  static const indexKey = 'cw2.sessions.drafts';
  static const version = 1;
  static const maxDrafts = 32;

  /// The largest draft written, in UTF-8 bytes. A longer text stays in the
  /// field but is not saved, and the last saved draft is kept.
  static const maxDraftBytes = 128 * 1024;

  /// The draft of [session]; hashed like the outbox, so any session id gives
  /// a bounded key.
  static String keyFor(SessionRef session) =>
      'cw2.drafts.v1.${sha256.convert(utf8.encode(session.storageKey))}';

  final PayloadStore _payloads;
  final V2MetadataStore _index;
  final Duration delay;
  final _executor = KeySerialExecutor();

  /// What each session's stored draft holds, as far as this store knows.
  final _saved = <SessionRef, String>{};

  /// Sessions whose stored draft could not be read: never written over
  /// until a later read finds it readable or gone.
  final _blocked = <SessionRef>{};
  final _pending = <SessionRef, String>{};

  /// Sessions written whose place in the index is still being recorded: an
  /// eviction chosen from the index before that leaves their draft alone.
  final _tracking = <SessionRef, int>{};

  /// Who shows each session's draft, told when a sent prompt is forgotten.
  final _owners = <SessionRef, void Function(String text)>{};
  Timer? _timer;

  /// The stored draft of [session], or null when it has none or it could not
  /// be read; in that case it is kept and never written over.
  Future<String?> read(SessionRef session) {
    final key = keyFor(session);
    return _executor.run(key, () => _load(session, key));
  }

  /// Reads [session]'s stored draft within its turn, blocking the session
  /// while a stored record cannot be read and unblocking it once it can.
  Future<String?> _load(SessionRef session, String key) async {
    try {
      if (await _payloads.contains(key)) {
        final raw = await _payloads.read(key);
        final text = decode(raw, session);
        if (text != null) {
          _blocked.remove(session);
          _saved[session] = text;
          return text;
        }
        // A record the payload store discarded as corrupt is gone, so
        // nothing is left to keep; any other one is kept.
        if (raw != null || await _payloads.contains(key)) {
          _blocked.add(session);
          return null;
        }
      }
      _blocked.remove(session);
      _saved.remove(session);
      return null;
    } on Object {
      _blocked.add(session);
      return null;
    }
  }

  /// Whether [session]'s stored draft may be changed: a record that could not
  /// be read is read again first, so a failure that passed does not keep it.
  Future<bool> _writable(SessionRef session, String key) async {
    if (_blocked.contains(session)) await _load(session, key);
    return !_blocked.contains(session);
  }

  /// [forgotten] is told when a prompt sent after its screen closed was
  /// removed as [session]'s draft, so a field that shows it again drops it.
  void attach(SessionRef session, void Function(String text) forgotten) =>
      _owners[session] = forgotten;

  void detach(SessionRef session, void Function(String text) forgotten) {
    if (_owners[session] == forgotten) _owners.remove(session);
  }

  /// Records the text of [session]'s draft. An empty text removes the stored
  /// draft at once; any other text is written within [delay].
  void save(SessionRef session, String text) {
    if (text.isEmpty) {
      _pending.remove(session);
      unawaited(_remove(session));
      return;
    }
    _pending[session] = text;
    // The wait is not restarted by every key, so a long burst of typing is
    // still saved every [delay].
    _timer ??= Timer(delay, () {
      _timer = null;
      unawaited(flush());
    });
  }

  /// Removes [session]'s draft while it still holds [text]: a prompt that
  /// was sent after the session's screen closed.
  void forget(SessionRef session, String text) {
    if (_pending[session] == text) _pending.remove(session);
    unawaited(_remove(session, only: text));
  }

  /// Writes every pending draft now.
  Future<void> flush() async {
    _timer?.cancel();
    _timer = null;
    if (_pending.isEmpty) return;
    final batch = Map.of(_pending);
    _pending.clear();
    await Future.wait([
      for (final MapEntry(:key, :value) in batch.entries) _write(key, value),
    ]);
  }

  Future<void> _write(SessionRef session, String text) async {
    final key = keyFor(session);
    final written = await _executor.run(key, () async {
      if (!await _writable(session, key)) {
        // Kept for the next flush, which reads the record again; a newer
        // text queued meanwhile wins.
        _pending.putIfAbsent(session, () => text);
        return false;
      }
      if (_saved[session] == text) return false;
      if (utf8.encode(text).length > maxDraftBytes) return false;
      try {
        final result = await _payloads.write(key, encode(session, text));
        if (result == PayloadWriteResult.refusedOversized) return false;
      } on Object {
        return false;
      }
      _saved[session] = text;
      _tracking[session] = (_tracking[session] ?? 0) + 1;
      return true;
    });
    if (!written) return;
    // The index is updated after the draft's own turn, so a draft never
    // waits for the index while the index waits for a draft it evicts.
    try {
      await _track(session);
    } finally {
      final left = _tracking[session]! - 1;
      if (left == 0) {
        _tracking.remove(session);
      } else {
        _tracking[session] = left;
      }
    }
  }

  Future<void> _remove(SessionRef session, {String? only}) async {
    final key = keyFor(session);
    final removed = await _executor.run(key, () async {
      if (!await _writable(session, key)) return false;
      final saved = _saved[session];
      if (saved == null || (only != null && saved != only)) return false;
      try {
        await _payloads.remove(key);
      } on Object {
        return false;
      }
      _saved.remove(session);
      return true;
    });
    if (!removed) return;
    if (only != null) _owners[session]?.call(only);
    await _untrack(session);
  }

  /// Moves [session] to the newest end of the index and evicts the drafts
  /// beyond [maxDrafts]. An index that could not be read is left as it is.
  Future<void> _track(SessionRef session) async {
    final evicted = await _executor.run(indexKey, () async {
      final sessions = await _readIndex();
      final id = session.storageKey;
      if (sessions == null || (sessions.isNotEmpty && sessions.last == id)) {
        return const <String>[];
      }
      final next = [...sessions.where((other) => other != id), id];
      final cut = next.length > maxDrafts ? next.length - maxDrafts : 0;
      if (!await _writeIndex(next.sublist(cut))) return const <String>[];
      return next.sublist(0, cut);
    });
    for (final id in evicted) {
      await _evict(SessionRef.fromStorageKey(id));
    }
  }

  Future<void> _untrack(SessionRef session) =>
      _executor.run(indexKey, () async {
        final sessions = await _readIndex();
        final id = session.storageKey;
        if (sessions == null || !sessions.contains(id)) return;
        await _writeIndex([...sessions.where((other) => other != id)]);
      });

  Future<void> _evict(SessionRef session) {
    final key = keyFor(session);
    return _executor.run(key, () async {
      if (_blocked.contains(session) || _tracking.containsKey(session)) return;
      try {
        await _payloads.remove(key);
        _saved.remove(session);
      } on Object {
        // The draft stays; the next eviction tries again.
      }
    });
  }

  Future<List<String>?> _readIndex() async {
    try {
      requireV2Key(indexKey);
      return decodeIndex(await _index.read(indexKey));
    } on Object {
      return null;
    }
  }

  Future<bool> _writeIndex(List<String> sessions) async {
    try {
      await _index.write(
        indexKey,
        jsonEncode({'version': version, 'sessions': sessions}),
      );
      return true;
    } on Object {
      return false;
    }
  }

  @visibleForTesting
  static String encode(SessionRef session, String text) => jsonEncode({
    'version': version,
    'session': session.storageKey,
    'text': text,
  });

  /// The text of a stored draft of [session], or null when it is not one
  /// this version reads or it belongs to another session.
  @visibleForTesting
  static String? decode(String? raw, SessionRef session) {
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, Object?> ||
          json['version'] != version ||
          json['session'] != session.storageKey) {
        return null;
      }
      final text = json['text'];
      return text is String && text.isNotEmpty ? text : null;
    } on FormatException {
      return null;
    }
  }

  /// The sessions of a stored index, or null when it is not one this version
  /// reads. A missing index is no drafts.
  @visibleForTesting
  static List<String>? decodeIndex(Object? raw) {
    if (raw == null) return const [];
    if (raw is! String) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, Object?> || json['version'] != version) {
        return null;
      }
      final sessions = json['sessions'];
      if (sessions is! List || sessions.length > maxDrafts) return null;
      final ids = <String>[];
      for (final id in sessions) {
        if (id is! String || ids.contains(id)) return null;
        SessionRef.fromStorageKey(id);
        ids.add(id);
      }
      return ids;
    } on Object {
      return null;
    }
  }
}
