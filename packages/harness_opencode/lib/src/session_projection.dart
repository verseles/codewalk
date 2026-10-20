import 'dart:convert';

import 'package:codewalk_core/codewalk_core.dart';

/// The HTTP metadata subset is not an execution or hydration snapshot.
SessionSummary projectOpenCodeSession(Object? value, HarnessRef harness) {
  final data = _object(value);
  final id = openCodeSessionId(data['id']);
  final title = data['title'];
  if (title != null && title is! String) _malformed();
  final time = _object(data['time']);
  final updated = _instant(time['updated']);
  final parent = data['parentID'];
  final metadata = <String, Object?>{};
  // The upstream project id is an annotation: several directories can share
  // one, and an unborn Git directory resolves to the literal "global".
  String? upstreamProjectId;
  final project = data['projectID'];
  if (project != null) {
    upstreamProjectId = _text(project);
    metadata['nativeProjectId'] = upstreamProjectId;
  }
  // The canonical directory is the project identity (ADR-023: key projects by
  // host plus canonical directory).
  String? directory;
  final location = data['location'];
  if (location != null) {
    directory = _text(_object(location)['directory']);
    metadata['nativeDirectory'] = directory;
  }
  // The unread marker: the endpoint's idle and viewed epochs. They are
  // optional fields of the record, so an absent or unusable value leaves the
  // marker out instead of failing the page.
  SessionViewMarker? view;
  final idle = _optionalEpoch(time['idle']);
  if (idle != null) {
    final viewed = _optionalEpoch(time['viewed']);
    view = SessionViewMarker(idleAt: idle, viewedAt: viewed);
  }

  ForkLineage? fork;
  if (data['fork'] != null) {
    final native = _object(data['fork']);
    final source = openCodeSessionId(native['sessionID']);
    final boundary = _object(native['boundary']);
    final kind = _text(boundary['type']);
    final message = _text(boundary['messageID']);
    if (!message.startsWith('msg_')) _malformed();
    fork = ForkLineage(SessionRef(harness.host, harness.harness, source));
    // Native boundaries address a whole message, not a canonical timeline item.
    metadata['nativeForkBoundary'] = {'type': kind, 'messageId': message};
  }

  return SessionSummary(
    view: view,
    info: SessionInfo(
      ref: SessionRef(harness.host, harness.harness, id),
      title: title as String? ?? '',
      ownership: const OwnershipInfo.unknown(
        reason: 'nativeSessionMetadataHasNoOwnershipProof',
      ),
      project: directory == null
          ? null
          : ProjectRef(
              harness.host,
              directory,
              upstreamProjectId: upstreamProjectId,
            ),
      lineage: SessionLineage(
        parent: parent == null
            ? null
            : SessionRef(
                harness.host,
                harness.harness,
                openCodeSessionId(parent),
              ),
        fork: fork,
      ),
      metadata: metadata.isEmpty ? null : CanonicalValue(metadata),
    ),
    updatedAt: updated,
  );
}

String openCodeSessionId(Object? value) {
  final id = _text(value);
  if (!id.startsWith('ses')) _malformed();
  return id;
}

String _text(Object? value) {
  if (value is! String ||
      value.isEmpty ||
      utf8.encode(value).length > 4096 ||
      utf8.decode(utf8.encode(value)) != value) {
    _malformed();
  }
  return value;
}

Map<String, Object?> _object(Object? value) {
  if (value is! Map<String, Object?>) _malformed();
  return value;
}

DateTime _instant(Object? value) {
  if (value is! num || !value.isFinite || value.abs() > 8640000000000000) {
    _malformed();
  }
  return DateTime.fromMicrosecondsSinceEpoch(
    (value * 1000).round(),
    isUtc: true,
  );
}

/// An optional epoch in milliseconds, or null when the value is absent or not
/// a usable instant.
DateTime? _optionalEpoch(Object? value) {
  if (value is! num || !value.isFinite) return null;
  final millis = value.round();
  if (millis.abs() > 8640000000000000) return null;
  try {
    return DateTime.fromMicrosecondsSinceEpoch(millis * 1000, isUtc: true);
  } on ArgumentError {
    // The marker is optional: an unusable epoch leaves it out instead of
    // failing the read.
    return null;
  }
}

Never _malformed() =>
    throw const FormatException('Malformed OpenCode session metadata.');
