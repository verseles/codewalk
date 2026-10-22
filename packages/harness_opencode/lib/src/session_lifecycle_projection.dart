import 'package:codewalk_core/codewalk_core.dart';

import 'version_policy.dart';

enum OpenCodeSessionLifecycleProjectionFailure {
  malformed,
  unsupportedVersion,
  limitExceeded,
}

/// Contains a finite category, never native content or identifiers.
final class OpenCodeSessionLifecycleProjectionException implements Exception {
  const OpenCodeSessionLifecycleProjectionException(this.failure);

  final OpenCodeSessionLifecycleProjectionFailure failure;

  @override
  String toString() =>
      'OpenCodeSessionLifecycleProjectionException(${failure.name})';
}

const _idLimit = 4096;
// Copied title text, like the siblings' selected-content budgets.
const _titleLimit = 256 * 1024;
const _safeInteger = 9007199254740991;
const _maxEpochMillis = 8640000000000000;
const _created = 'session.created';
const _renamed = 'session.renamed';
const _deleted = 'session.deleted';
const _agentSelected = 'session.agent.selected';
const _modelSelected = 'session.model.selected';
const _durableVersions = {
  _created: 1,
  _renamed: 1,
  _deleted: 2,
  _agentSelected: 1,
  _modelSelected: 1,
};

/// Projects the durable 2.0.22 session lifecycle and selection events without
/// owning a stream or clock.
///
/// Returns an unmodifiable list to reduce in order against the latest
/// [current] state, empty for unrelated types and other sessions — including a
/// child created under the current session, whose discovery belongs to the
/// stream owner.
///
/// `created` yields the [SessionInfo] the HTTP session record projects to:
/// title, parent lineage, native project and directory, unknown ownership.
/// Slug, server version, subpath, agent, model, host metadata, permissions
/// and workspace are validated and not copied. `renamed` replaces only the
/// title of resident info for this session; without it nothing is invented
/// and a [ResyncRequired] asks for a fresh read. `deleted` requests a resync
/// too: Core has no removal event, and the read that follows observes the
/// deleted session authoritatively. The frame location is never read.
///
/// `agent.selected` and `model.selected` change one half of the session's
/// selection, so each yields the resident selection with only that half
/// replaced: the agent id, or the whole model reference (a reference without
/// a variant clears the variant). `previous` is validated and not copied.
List<SessionEvent> projectOpenCodeSessionLifecycleEvent(
  Object? value,
  SessionState current, {
  required String sourceVersion,
  required StreamPosition position,
  required DateTime receivedAt,
}) {
  final frame = _object(value);
  final type = frame['type'];
  if (type is! String) {
    _fail(OpenCodeSessionLifecycleProjectionFailure.malformed);
  }
  final durableVersion = _durableVersions[type];
  if (durableVersion == null) return const [];
  final data = _object(frame['data']);
  final sessionId = _id(data['sessionID'], 'ses');
  final ref = current.ref;
  if (sessionId != ref.nativeId) return const [];
  if (OpenCodeCompatibility.parse(sourceVersion)?.toString() != '2.0.22') {
    _fail(OpenCodeSessionLifecycleProjectionFailure.unsupportedVersion);
  }
  for (final part in [
    ref.host.value,
    ref.harness.value,
    ref.nativeId,
    position.id,
    position.epoch,
  ]) {
    _text(part, nonempty: true);
  }
  final nativeId = _id(frame['id'], 'evt_');
  final created = frame['created'];
  if (created is! num ||
      !created.isFinite ||
      created < 0 ||
      created > _maxEpochMillis) {
    _fail(OpenCodeSessionLifecycleProjectionFailure.malformed);
  }
  final durable = _object(frame['durable']);
  if (_id(durable['aggregateID'], 'ses') != sessionId) {
    _fail(OpenCodeSessionLifecycleProjectionFailure.malformed);
  }
  if (_integer(durable['version']) != durableVersion) {
    _fail(OpenCodeSessionLifecycleProjectionFailure.unsupportedVersion);
  }
  final aggregateSeq = BigInt.from(_integer(durable['seq']));

  SessionInfo? info;
  Selection? selection;
  String? resync;
  final resident = current.selection;
  switch (type) {
    case _created:
      final projectId = _text(data['projectID'], nonempty: true);
      final location = _object(data['location']);
      final directory = _text(location['directory'], nonempty: true);
      if (location.containsKey('workspaceID')) {
        _text(location['workspaceID']);
      }
      _text(data['slug']);
      _text(data['version']);
      for (final key in ['subpath', 'agent']) {
        if (data.containsKey(key)) _text(data[key]);
      }
      if (data.containsKey('model')) {
        final model = _object(data['model']);
        _text(model['id'], nonempty: true);
        _text(model['providerID'], nonempty: true);
        if (model.containsKey('variant')) _text(model['variant']);
      }
      // Host annotations and permission rules are not part of session info;
      // only their declared container types are checked.
      if (data.containsKey('metadata')) _object(data['metadata']);
      if (data.containsKey('permissions') && data['permissions'] is! List) {
        _fail(OpenCodeSessionLifecycleProjectionFailure.malformed);
      }
      final parent = data.containsKey('parentID')
          ? _id(data['parentID'], 'ses')
          : null;
      info = SessionInfo(
        ref: ref,
        title: data.containsKey('title') ? _title(data['title']) : '',
        ownership: const OwnershipInfo.unknown(
          reason: 'nativeSessionMetadataHasNoOwnershipProof',
        ),
        // The canonical directory is the project identity; the upstream
        // project id stays an annotation.
        project: ProjectRef(ref.host, directory, upstreamProjectId: projectId),
        lineage: SessionLineage(
          parent: parent == null
              ? null
              : SessionRef(ref.host, ref.harness, parent),
        ),
        metadata: CanonicalValue({
          'nativeProjectId': projectId,
          'nativeDirectory': directory,
        }),
      );
    case _renamed:
      final title = _title(data['title']);
      final resident = current.info;
      if (resident == null || resident.ref != ref) {
        resync = 'sessionInfoUnproven';
      } else {
        info = SessionInfo(
          ref: resident.ref,
          title: title,
          ownership: resident.ownership,
          project: resident.project,
          lineage: resident.lineage,
          metadata: resident.metadata,
        );
      }
    case _deleted:
      resync = 'sessionDeleted';
    case _agentSelected:
      final agent = _text(data['agent'], nonempty: true);
      if (data['previous'] != null) _text(data['previous'], nonempty: true);
      selection = Selection(
        modelId: resident?.modelId,
        modelProviderId: resident?.modelProviderId,
        modelVariant: resident?.modelVariant,
        agentId: agent,
        effort: resident?.effort,
        permissionMode: resident?.permissionMode,
        metadata: resident?.metadata,
      );
    case _modelSelected:
      final model = _modelRef(data['model']);
      if (data['previous'] != null) _modelRef(data['previous']);
      selection = Selection(
        modelId: model.id,
        modelProviderId: model.providerId,
        modelVariant: model.variant,
        agentId: resident?.agentId,
        effort: resident?.effort,
        permissionMode: resident?.permissionMode,
        metadata: resident?.metadata,
      );
  }

  final meta = EventMeta(
    owner: SessionOwner(ref),
    position: position,
    receivedAt: receivedAt,
    source: SourceProvenance(
      harness: ref.harnessRef,
      version: sourceVersion,
      nativeType: type,
      nativeEventId: nativeId,
      aggregateId: sessionId,
      aggregateSeq: aggregateSeq,
      durability: const OpenValue.known(Durability.durable),
      extra: CanonicalValue({
        'nativeCreated': created,
        'nativeDurableVersion': durableVersion,
      }),
    ),
  );
  return List.unmodifiable([
    if (info != null) SessionInfoChanged(meta: meta, info: info),
    if (selection != null) SelectionChanged(meta: meta, selection: selection),
    if (resync != null) ResyncRequired(meta: meta, reason: resync),
  ]);
}

({String id, String providerId, String? variant}) _modelRef(Object? value) {
  final model = _object(value);
  return (
    id: _text(model['id'], nonempty: true),
    providerId: _text(model['providerID'], nonempty: true),
    variant: model['variant'] == null ? null : _text(model['variant']),
  );
}

String _title(Object? value) {
  if (value is! String) {
    _fail(OpenCodeSessionLifecycleProjectionFailure.malformed);
  }
  _bytes(value, _titleLimit);
  return value;
}

Map<String, Object?> _object(Object? value) {
  if (value is! Map<String, Object?>) {
    _fail(OpenCodeSessionLifecycleProjectionFailure.malformed);
  }
  return value;
}

int _integer(Object? value) {
  if (value is! num ||
      !value.isFinite ||
      value < 0 ||
      value > _safeInteger ||
      value != value.truncate()) {
    _fail(OpenCodeSessionLifecycleProjectionFailure.malformed);
  }
  return value.toInt();
}

String _id(Object? value, String prefix) {
  final result = _text(value, nonempty: true);
  if (!result.startsWith(prefix)) {
    _fail(OpenCodeSessionLifecycleProjectionFailure.malformed);
  }
  return result;
}

String _text(Object? value, {bool nonempty = false}) {
  if (value is! String || (nonempty && value.isEmpty)) {
    _fail(OpenCodeSessionLifecycleProjectionFailure.malformed);
  }
  _bytes(value, _idLimit);
  return value;
}

void _bytes(String value, int cap) {
  if (value.length > cap) {
    _fail(OpenCodeSessionLifecycleProjectionFailure.limitExceeded);
  }
  var bytes = 0;
  for (var i = 0; i < value.length; i++) {
    final unit = value.codeUnitAt(i);
    if (unit >= 0xd800 && unit <= 0xdbff) {
      if (++i >= value.length) {
        _fail(OpenCodeSessionLifecycleProjectionFailure.malformed);
      }
      final low = value.codeUnitAt(i);
      if (low < 0xdc00 || low > 0xdfff) {
        _fail(OpenCodeSessionLifecycleProjectionFailure.malformed);
      }
      bytes += 4;
    } else if (unit >= 0xdc00 && unit <= 0xdfff) {
      _fail(OpenCodeSessionLifecycleProjectionFailure.malformed);
    } else {
      bytes += unit < 0x80 ? 1 : (unit < 0x800 ? 2 : 3);
    }
    if (bytes > cap) {
      _fail(OpenCodeSessionLifecycleProjectionFailure.limitExceeded);
    }
  }
}

Never _fail(OpenCodeSessionLifecycleProjectionFailure failure) =>
    throw OpenCodeSessionLifecycleProjectionException(failure);
