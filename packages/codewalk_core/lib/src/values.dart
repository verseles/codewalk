import 'dart:convert';

import 'identity.dart';

/// A known canonical enum or an exact, unrecognized value from an adapter.
final class OpenValue<E extends Enum> {
  const OpenValue.known(E this.known) : _raw = null;

  OpenValue.unknown(String value) : known = null, _raw = requireText(value);

  factory OpenValue.parse(String value, Iterable<E> values) {
    requireText(value);
    for (final candidate in values) {
      if (candidate.name == value) return OpenValue.known(candidate);
    }
    return OpenValue.unknown(value);
  }

  final E? known;
  final String? _raw;
  String get value => known?.name ?? _raw!;
  bool get isKnown => known != null;
  String toJson() => value;

  @override
  bool operator ==(Object other) =>
      other is OpenValue<E> && known == other.known && value == other.value;
  @override
  int get hashCode => Object.hash(E, known, value);
}

/// Validated JSON-shaped data, copied recursively at the canonical boundary.
/// Diagnostic redaction is an adapter responsibility before constructing this.
final class CanonicalValue {
  CanonicalValue(Object? value) : value = _freeze(value, Set.identity());
  final Object? value;
  Object? toJson() => value;

  @override
  bool operator ==(Object other) =>
      other is CanonicalValue && _equal(value, other.value);
  @override
  int get hashCode => _hash(value);
}

List<T> immutableList<T>(Iterable<T> values) => List<T>.unmodifiable(values);
Map<K, V> immutableMap<K, V>(Map<K, V> values) =>
    Map<K, V>.unmodifiable(values);

/// Runtime validation is independent of debug constructor assertions.
String requireText(String value, [String field = 'value']) {
  if (value.isEmpty) {
    throw ArgumentError.value(value, field, 'Must not be empty');
  }
  return value;
}

Object? _freeze(Object? value, Set<Object> ancestors) {
  if (value == null || value is String || value is bool) return value;
  if (value is num) {
    if (!value.isFinite) {
      throw ArgumentError('Canonical numbers must be finite');
    }
    return value;
  }
  if (value is! List && value is! Map) {
    throw ArgumentError('Canonical data must be JSON-shaped');
  }
  if (!ancestors.add(value)) throw ArgumentError('Cyclic canonical data');
  try {
    if (value is List) {
      return List<Object?>.unmodifiable(
        value.map((v) => _freeze(v, ancestors)),
      );
    }
    final map = value as Map;
    if (map.keys.any((key) => key is! String)) {
      throw ArgumentError('Canonical object keys must be strings');
    }
    return Map<String, Object?>.unmodifiable({
      for (final entry in map.entries)
        entry.key as String: _freeze(entry.value, ancestors),
    });
  } finally {
    ancestors.remove(value);
  }
}

bool _equal(Object? a, Object? b) {
  if (a is List && b is List) {
    return a.length == b.length &&
        Iterable<int>.generate(a.length).every((i) => _equal(a[i], b[i]));
  }
  if (a is Map && b is Map) {
    return a.length == b.length &&
        a.keys.every((key) => b.containsKey(key) && _equal(a[key], b[key]));
  }
  return a == b;
}

int _hash(Object? value) {
  if (value is List) return Object.hashAll(value.map(_hash));
  if (value is Map<String, Object?>) {
    final keys = value.keys.toList()..sort();
    return Object.hashAll(
      keys.map((key) => Object.hash(key, _hash(value[key]))),
    );
  }
  return value.hashCode;
}

/// Actual owner and displayed origin are separate. No topology is inferred.
sealed class DomainOwner {
  const DomainOwner();
  bool get isKnown;
  HarnessRef? get harness;
  String get scopeKey;
  bool hasSameScope(DomainOwner other) =>
      isKnown && other.isKnown && scopeKey == other.scopeKey;
}

final class SessionOwner extends DomainOwner {
  const SessionOwner(this.session, {this.origin});
  final SessionRef session;
  final SessionRef? origin;
  @override
  HarnessRef get harness => session.harnessRef;
  @override
  bool get isKnown => true;
  @override
  String get scopeKey => jsonEncode(['session', session.storageKey]);
  @override
  bool operator ==(Object other) =>
      other is SessionOwner &&
      session == other.session &&
      origin == other.origin;
  @override
  int get hashCode => Object.hash(session, origin);
}

final class ProjectOwner extends DomainOwner {
  ProjectOwner(this.project, {this.harness}) {
    if (harness != null && harness!.host != project.host) {
      throw ArgumentError('Project owner harness belongs to another host');
    }
  }
  final ProjectRef project;
  @override
  final HarnessRef? harness;
  @override
  bool get isKnown => harness != null;
  @override
  String get scopeKey =>
      jsonEncode(['project', project.storageKey, harness?.storageKey]);
  @override
  bool operator ==(Object other) =>
      other is ProjectOwner &&
      project == other.project &&
      harness == other.harness;
  @override
  int get hashCode => Object.hash(ProjectOwner, project, harness);
}

final class HostOwner extends DomainOwner {
  HostOwner(this.host, {this.harness}) {
    if (harness != null && harness!.host != host) {
      throw ArgumentError('Host owner harness belongs to another host');
    }
  }
  final HostId host;
  @override
  final HarnessRef? harness;
  @override
  bool get isKnown => harness != null;
  @override
  String get scopeKey => jsonEncode(['host', host.value, harness?.storageKey]);
  @override
  bool operator ==(Object other) =>
      other is HostOwner && host == other.host && harness == other.harness;
  @override
  int get hashCode => Object.hash(HostOwner, host, harness);
}

/// Native global scope is still bounded by its host and harness instance.
final class GlobalOwner extends DomainOwner {
  const GlobalOwner(this.harness);
  @override
  final HarnessRef harness;
  @override
  bool get isKnown => true;
  @override
  String get scopeKey => jsonEncode(['global', harness.storageKey]);
  @override
  bool operator ==(Object other) =>
      other is GlobalOwner && harness == other.harness;
  @override
  int get hashCode => Object.hash(GlobalOwner, harness);
}

final class UnknownOwner extends DomainOwner {
  UnknownOwner({required String reason, this.raw})
    : reason = requireText(reason);
  final String reason;
  final CanonicalValue? raw;
  @override
  HarnessRef? get harness => null;
  @override
  bool get isKnown => false;
  @override
  String get scopeKey => jsonEncode(['unknown', reason, raw?.toJson()]);
  @override
  bool operator ==(Object other) =>
      other is UnknownOwner && reason == other.reason && raw == other.raw;
  @override
  int get hashCode => Object.hash(UnknownOwner, reason, raw);
}

enum Durability { ephemeral, durable, watermarkOnly, unknown }

final class SourceProvenance {
  SourceProvenance({
    required this.harness,
    required String version,
    required String nativeType,
    this.nativeEventId,
    this.nativeCursor,
    this.aggregateId,
    this.aggregateSeq,
    this.durability = const OpenValue.known(Durability.ephemeral),
    this.extra,
  }) : version = requireText(version, 'version'),
       nativeType = requireText(nativeType, 'nativeType') {
    if (aggregateSeq != null && aggregateSeq!.isNegative) {
      throw ArgumentError('Aggregate sequence must not be negative');
    }
  }
  final HarnessRef harness;
  final String version;
  final String nativeType;
  final String? nativeEventId;
  final String? nativeCursor;
  final String? aggregateId;
  final BigInt? aggregateSeq;
  final OpenValue<Durability> durability;
  final CanonicalValue? extra;
}

/// Optional pointer to an already-redacted, bounded diagnostic capture.
/// No model creates or enables a raw capture by default.
final class DiagnosticRef {
  DiagnosticRef({
    required String id,
    required this.byteLength,
    required bool redacted,
    int maxBytes = 65536,
  }) : id = requireText(id) {
    if (!redacted || byteLength < 0 || maxBytes < 0 || byteLength > maxBytes) {
      throw ArgumentError('Diagnostic capture must be redacted and bounded');
    }
  }
  final String id;
  final int byteLength;
}
