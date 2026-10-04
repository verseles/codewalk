import 'dart:convert';

// Constructor assertions catch programming errors, including invalid constants.
// Decoding checks remain active in release builds. Values are never normalized.
abstract class _OpaqueId {
  const _OpaqueId(this.value) : assert(value != '');

  final String value;

  String toJson() => value;

  @override
  bool operator ==(Object other) =>
      other is _OpaqueId &&
      runtimeType == other.runtimeType &&
      value == other.value;

  @override
  int get hashCode => Object.hash(runtimeType, value);

  @override
  String toString() => value;
}

/// App-assigned target identity. URLs and native IDs do not establish it.
final class HostId extends _OpaqueId {
  const HostId(super.value);
  HostId.fromJson(Object? value) : super(_string(value, 'HostId'));
}

/// An installation/profile on a host, not merely a harness product name.
final class HarnessInstanceId extends _OpaqueId {
  const HarnessInstanceId(super.value);
  HarnessInstanceId.fromJson(Object? value)
    : super(_string(value, 'HarnessInstanceId'));
}

final class ItemId extends _OpaqueId {
  const ItemId(super.value);
  ItemId.fromJson(Object? value) : super(_string(value, 'ItemId'));
}

final class TurnId extends _OpaqueId {
  const TurnId(super.value);
  TurnId.fromJson(Object? value) : super(_string(value, 'TurnId'));
}

/// Correlation identity; its existence does not guarantee mutation replay.
final class CommandId extends _OpaqueId {
  const CommandId(super.value);
  CommandId.fromJson(Object? value) : super(_string(value, 'CommandId'));
}

final class InteractionId extends _OpaqueId {
  const InteractionId(super.value);
  InteractionId.fromJson(Object? value)
    : super(_string(value, 'InteractionId'));
}

final class WorkId extends _OpaqueId {
  const WorkId(super.value);
  WorkId.fromJson(Object? value) : super(_string(value, 'WorkId'));
}

final class HarnessRef {
  const HarnessRef(this.host, this.harness);

  factory HarnessRef.fromJson(Object? value) {
    final json = _object(value, 'HarnessRef');
    return HarnessRef(
      HostId.fromJson(json['host']),
      HarnessInstanceId.fromJson(json['harness']),
    );
  }

  factory HarnessRef.fromStorageKey(String value) {
    final tuple = _key(value, 'harness', 4);
    return HarnessRef(
      HostId.fromJson(tuple[2]),
      HarnessInstanceId.fromJson(tuple[3]),
    );
  }

  final HostId host;
  final HarnessInstanceId harness;

  String get storageKey =>
      jsonEncode(['harness', 1, host.value, harness.value]);

  Map<String, Object?> toJson() => {
    'version': 1,
    'host': host.value,
    'harness': harness.value,
  };

  @override
  bool operator ==(Object other) =>
      other is HarnessRef && host == other.host && harness == other.harness;

  @override
  int get hashCode => Object.hash(host, harness);

  @override
  String toString() => storageKey;
}

/// The complete identity used by session caches, drafts, tabs and notifications.
/// Directory, title, endpoint aliases and lineage cannot change this identity.
final class SessionRef {
  const SessionRef(this.host, this.harness, this.nativeId)
    : assert(nativeId != '');

  factory SessionRef.fromJson(Object? value) {
    final json = _object(value, 'SessionRef');
    return SessionRef(
      HostId.fromJson(json['host']),
      HarnessInstanceId.fromJson(json['harness']),
      _string(json['nativeId'], 'nativeId'),
    );
  }

  factory SessionRef.fromStorageKey(String value) {
    final tuple = _key(value, 'session', 5);
    return SessionRef(
      HostId.fromJson(tuple[2]),
      HarnessInstanceId.fromJson(tuple[3]),
      _string(tuple[4], 'nativeId'),
    );
  }

  final HostId host;
  final HarnessInstanceId harness;
  final String nativeId;

  HarnessRef get harnessRef => HarnessRef(host, harness);

  String get storageKey =>
      jsonEncode(['session', 1, host.value, harness.value, nativeId]);

  Map<String, Object?> toJson() => {
    'version': 1,
    'host': host.value,
    'harness': harness.value,
    'nativeId': nativeId,
  };

  @override
  bool operator ==(Object other) =>
      other is SessionRef &&
      host == other.host &&
      harness == other.harness &&
      nativeId == other.nativeId;

  @override
  int get hashCode => Object.hash(host, harness, nativeId);

  @override
  String toString() => storageKey;
}

/// Directory identity supplied by the host's canonicalization boundary.
/// Core performs no case folding, separator conversion or physical resolution.
final class ProjectRef {
  const ProjectRef(this.host, this.canonicalDirectory, {this.upstreamProjectId})
    : assert(canonicalDirectory != ''),
      assert(upstreamProjectId == null || upstreamProjectId != '');

  factory ProjectRef.fromJson(Object? value) {
    final json = _object(value, 'ProjectRef');
    return ProjectRef(
      HostId.fromJson(json['host']),
      _string(json['canonicalDirectory'], 'canonicalDirectory'),
      upstreamProjectId: json['upstreamProjectId'] == null
          ? null
          : _string(json['upstreamProjectId'], 'upstreamProjectId'),
    );
  }

  /// Keys contain identity only; upstream annotations remain in [toJson].
  factory ProjectRef.fromStorageKey(String value) {
    final tuple = _key(value, 'project', 4);
    return ProjectRef(
      HostId.fromJson(tuple[2]),
      _string(tuple[3], 'canonicalDirectory'),
    );
  }

  final HostId host;
  final String canonicalDirectory;

  /// Annotation only: several directories can share an upstream project ID.
  final String? upstreamProjectId;

  String get storageKey =>
      jsonEncode(['project', 1, host.value, canonicalDirectory]);

  Map<String, Object?> toJson() => {
    'version': 1,
    'host': host.value,
    'canonicalDirectory': canonicalDirectory,
    if (upstreamProjectId != null) 'upstreamProjectId': upstreamProjectId,
  };

  @override
  bool operator ==(Object other) =>
      other is ProjectRef &&
      host == other.host &&
      canonicalDirectory == other.canonicalDirectory;

  @override
  int get hashCode => Object.hash(host, canonicalDirectory);

  @override
  String toString() => storageKey;
}

/// Fork provenance is distinct from task delegation's parent relationship.
final class ForkLineage {
  const ForkLineage(this.source, {this.beforeItem});

  factory ForkLineage.fromJson(Object? value) {
    final json = _object(value, 'ForkLineage');
    return ForkLineage(
      SessionRef.fromJson(json['source']),
      beforeItem: json['beforeItem'] == null
          ? null
          : ItemId.fromJson(json['beforeItem']),
    );
  }

  final SessionRef source;
  final ItemId? beforeItem;

  Map<String, Object?> toJson() => {
    'version': 1,
    'source': source.toJson(),
    if (beforeItem != null) 'beforeItem': beforeItem!.value,
  };

  @override
  bool operator ==(Object other) =>
      other is ForkLineage &&
      source == other.source &&
      beforeItem == other.beforeItem;

  @override
  int get hashCode => Object.hash(source, beforeItem);
}

final class SessionLineage {
  const SessionLineage({this.parent, this.fork});

  factory SessionLineage.fromJson(Object? value) {
    final json = _object(value, 'SessionLineage');
    return SessionLineage(
      parent: json['parent'] == null
          ? null
          : SessionRef.fromJson(json['parent']),
      fork: json['fork'] == null ? null : ForkLineage.fromJson(json['fork']),
    );
  }

  final SessionRef? parent;
  final ForkLineage? fork;

  Map<String, Object?> toJson() => {
    'version': 1,
    if (parent != null) 'parent': parent!.toJson(),
    if (fork != null) 'fork': fork!.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      other is SessionLineage && parent == other.parent && fork == other.fork;

  @override
  int get hashCode => Object.hash(parent, fork);
}

String _string(Object? value, String field) {
  if (value is! String || value.isEmpty) {
    throw FormatException('$field must be a nonempty string');
  }
  return value;
}

Map<String, Object?> _object(Object? value, String type) {
  if (value is! Map || value.keys.any((key) => key is! String)) {
    throw FormatException('$type must be an object');
  }
  final json = Map<String, Object?>.from(value);
  if (json['version'] is! int || json['version'] != 1) {
    throw FormatException('Unsupported $type version');
  }
  return json;
}

List<Object?> _key(String value, String kind, int length) {
  final json = jsonDecode(value);
  if (json is! List ||
      json.length != length ||
      json[0] != kind ||
      json[1] is! int ||
      json[1] != 1) {
    throw FormatException('Unsupported $kind identity key');
  }
  return List<Object?>.from(json);
}
