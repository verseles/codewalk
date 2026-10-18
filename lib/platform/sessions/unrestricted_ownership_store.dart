import 'dart:convert';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:crypto/crypto.dart';
import 'package:harness_opencode/harness_opencode.dart';
import '../../shared/sessions/session_unrestricted.dart';
import '../storage/metadata_store.dart';
import '../storage/storage_support.dart';

/// Fingerprint of a recognized ruleset in native order.
String unrestrictedFingerprint(OpenCodeSessionRules rules) =>
    sha256.convert(utf8.encode(rules.canonical)).toString();

/// What a fresh read of the rules means for a session, given CodeWalk's
/// record. [record] is the record to keep afterwards (null drops it).
typedef UnrestrictedReading = ({
  SessionUnrestrictedPhase phase,
  UnrestrictedOwnership? record,
});

/// Pure classification of [rules] against CodeWalk's [record] (ADR-059 §7).
/// CodeWalk only claims a trailing allow-everything rule whose whole ruleset
/// matches the fingerprint it recorded; anything else is left alone.
UnrestrictedReading classifyUnrestricted(
  OpenCodeSessionRules rules,
  UnrestrictedOwnership? record,
) {
  if (!rules.recognized) {
    return (phase: SessionUnrestrictedPhase.unavailable, record: record);
  }
  final current = unrestrictedFingerprint(rules);
  if (record == null) {
    return (
      phase: rules.endsWithWildcardAllow
          ? SessionUnrestrictedPhase.elsewhere
          : SessionUnrestrictedPhase.off,
      record: null,
    );
  }
  switch (record.stage) {
    case UnrestrictedStage.owned:
      if (current == record.owned) {
        return (phase: SessionUnrestrictedPhase.on, record: record);
      }
      // Back to exactly the rules before the insertion: it was removed.
      if (current == record.base) {
        return (phase: SessionUnrestrictedPhase.off, record: null);
      }
      // CodeWalk's insertion is gone, whoever removed it.
      if (!rules.containsWildcardAllow) {
        return (phase: SessionUnrestrictedPhase.off, record: null);
      }
      return (phase: SessionUnrestrictedPhase.conflict, record: record);
    case UnrestrictedStage.applying:
      if (current == record.owned) {
        return (
          phase: SessionUnrestrictedPhase.on,
          record: record.at(UnrestrictedStage.owned),
        );
      }
      // Not applied (yet): kept, so a late application is still recognized.
      if (current == record.base) {
        return (phase: SessionUnrestrictedPhase.off, record: record);
      }
      if (!rules.containsWildcardAllow) {
        return (phase: SessionUnrestrictedPhase.off, record: null);
      }
      return (phase: SessionUnrestrictedPhase.conflict, record: record);
    case UnrestrictedStage.removing:
      if (current == record.base) {
        return (phase: SessionUnrestrictedPhase.off, record: null);
      }
      if (current == record.owned) {
        return (
          phase: SessionUnrestrictedPhase.on,
          record: record.at(UnrestrictedStage.owned),
        );
      }
      if (!rules.containsWildcardAllow) {
        return (phase: SessionUnrestrictedPhase.off, record: null);
      }
      return (phase: SessionUnrestrictedPhase.conflict, record: record);
  }
}

/// Persists the Unrestricted insertions CodeWalk owns, fail-closed like the
/// permission mode store: no write before the first read, an unreadable blob
/// is never overwritten, and a change is applied only after it is stored.
final class UnrestrictedOwnershipStore implements UnrestrictedOwnershipLedger {
  UnrestrictedOwnershipStore({required V2MetadataStore store}) : _store = store;

  /// JSON object of session storage keys to `{stage, base, owned}`.
  static const key = 'cw2.sessions.unrestrictedRules';

  /// Records come only from deliberate actions and are never evicted: a
  /// dropped record would leave a rule CodeWalk can no longer remove.
  static const maxRecords = 128;

  final V2MetadataStore _store;
  final _executor = KeySerialExecutor();
  final _records = <String, UnrestrictedOwnership>{};
  bool _loaded = false;
  bool _unreadable = false;

  @override
  bool get loaded => _loaded;

  @override
  bool get unreadable => _unreadable;

  Future<void> initialize() async {
    if (_loaded) return;
    try {
      requireV2Key(key);
      _apply(await _store.read(key));
    } on Object {
      _records.clear();
      _unreadable = true;
    }
    _loaded = true;
  }

  void _apply(Object? raw) {
    _records.clear();
    _unreadable = false;
    if (raw == null) return;
    if (raw is! String || raw.isEmpty) {
      _unreadable = true;
      return;
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      _unreadable = true;
      return;
    }
    if (decoded is! Map || decoded.length > maxRecords) {
      _unreadable = true;
      return;
    }
    final parsed = <String, UnrestrictedOwnership>{};
    for (final entry in decoded.entries) {
      final record = _decode(entry.value);
      if (entry.key is! String ||
          (entry.key as String).isEmpty ||
          record == null) {
        _unreadable = true;
        return;
      }
      parsed[entry.key as String] = record;
    }
    _records.addAll(parsed);
  }

  static UnrestrictedOwnership? _decode(Object? value) {
    if (value is! Map || value.length != 3) return null;
    final stage = switch (value['stage']) {
      'applying' => UnrestrictedStage.applying,
      'owned' => UnrestrictedStage.owned,
      'removing' => UnrestrictedStage.removing,
      _ => null,
    };
    final base = value['base'];
    final owned = value['owned'];
    if (stage == null || !_digest(base) || !_digest(owned)) return null;
    return UnrestrictedOwnership(
      stage: stage,
      base: base as String,
      owned: owned as String,
    );
  }

  static bool _digest(Object? value) =>
      value is String && RegExp(r'^[0-9a-f]{64}$').hasMatch(value);

  @override
  UnrestrictedOwnership? recordFor(SessionRef session) =>
      _loaded && !_unreadable ? _records[session.storageKey] : null;

  @override
  Future<bool> put(SessionRef session, UnrestrictedOwnership record) =>
      _executor.run(key, () async {
        if (!_loaded || _unreadable) return false;
        final id = session.storageKey;
        if (!_records.containsKey(id) && _records.length >= maxRecords) {
          return false;
        }
        final next = {..._records, id: record};
        if (!await _write(next)) return false;
        _records[id] = record;
        return true;
      });

  @override
  Future<bool> remove(SessionRef session) => _executor.run(key, () async {
    if (!_loaded || _unreadable) return false;
    final id = session.storageKey;
    if (!_records.containsKey(id)) return true;
    final next = Map.of(_records)..remove(id);
    if (!await _write(next)) return false;
    _records.remove(id);
    return true;
  });

  Future<bool> _write(Map<String, UnrestrictedOwnership> records) async {
    final value = jsonEncode({
      for (final entry in records.entries)
        entry.key: {
          'stage': entry.value.stage.name,
          'base': entry.value.base,
          'owned': entry.value.owned,
        },
    });
    try {
      requireV2Key(key);
      if (await _store.write(key, value)) return true;
      return await _store.read(key) == value;
    } on Object {
      return false;
    }
  }
}
