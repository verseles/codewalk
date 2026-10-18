import 'package:codewalk_core/codewalk_core.dart';

import 'execution_projection.dart';
import 'inbox_projection.dart';
import 'interaction_projection.dart';
import 'notice_projection.dart';
import 'revert_projection.dart';
import 'session_lifecycle_projection.dart';
import 'session_projection.dart';
import 'session_rules.dart';
import 'step_usage_projection.dart';
import 'text_reasoning_projection.dart';
import 'tool_projection.dart';
import 'version_policy.dart';

enum OpenCodeEventProjectionFailure {
  malformed,
  unsupportedVersion,
  limitExceeded,
}

/// Contains a finite category, never native content or identifiers.
final class OpenCodeEventProjectionException implements Exception {
  const OpenCodeEventProjectionException(this.failure);

  final OpenCodeEventProjectionFailure failure;

  @override
  String toString() => 'OpenCodeEventProjectionException(${failure.name})';
}

typedef _Producer =
    List<SessionEvent> Function(
      Object? value,
      SessionState current, {
      required String sourceVersion,
      required StreamPosition position,
      required DateTime receivedAt,
    });

const _typeLimit = 4096;

List<SessionEvent> _single(
  SessionEvent? Function(
    Object? value,
    SessionState current, {
    required String sourceVersion,
    required StreamPosition position,
    required DateTime receivedAt,
  })
  producer,
  Object? value,
  SessionState current,
  String sourceVersion,
  StreamPosition position,
  DateTime receivedAt,
) {
  final event = producer(
    value,
    current,
    sourceVersion: sourceVersion,
    position: position,
    receivedAt: receivedAt,
  );
  return event == null ? const [] : List.unmodifiable([event]);
}

List<SessionEvent> _text(
  Object? value,
  SessionState current, {
  required String sourceVersion,
  required StreamPosition position,
  required DateTime receivedAt,
}) => _single(
  projectOpenCodeTextReasoningEvent,
  value,
  current,
  sourceVersion,
  position,
  receivedAt,
);

List<SessionEvent> _tool(
  Object? value,
  SessionState current, {
  required String sourceVersion,
  required StreamPosition position,
  required DateTime receivedAt,
}) => _single(
  projectOpenCodeToolEvent,
  value,
  current,
  sourceVersion,
  position,
  receivedAt,
);

List<SessionEvent> _interaction(
  Object? value,
  SessionState current, {
  required String sourceVersion,
  required StreamPosition position,
  required DateTime receivedAt,
}) => _single(
  projectOpenCodeInteractionEvent,
  value,
  current,
  sourceVersion,
  position,
  receivedAt,
);

// Exact native types owned by each accepted producer; every one returns
// nothing for the types of the others.
final Map<String, _Producer> _routes = {
  for (final type in const [
    'session.text.started',
    'session.text.delta',
    'session.text.ended',
    'session.reasoning.started',
    'session.reasoning.delta',
    'session.reasoning.ended',
  ])
    type: _text,
  for (final type in const [
    'session.tool.input.started',
    'session.tool.input.delta',
    'session.tool.input.ended',
    'session.tool.called',
    'session.tool.progress',
    'session.tool.success',
    'session.tool.failed',
  ])
    type: _tool,
  for (final type in const [
    'session.execution.started',
    'session.execution.succeeded',
    'session.execution.failed',
    'session.execution.interrupted',
  ])
    type: projectOpenCodeExecutionEvent,
  for (final type in const [
    'session.inbox.enqueued',
    'session.inbox.delivered',
    'session.inbox.cancelled',
    'session.inbox.delivery.changed',
  ])
    type: projectOpenCodeInboxEvent,
  for (final type in const [
    'session.step.started',
    'session.step.streamed',
    'session.step.ended',
    'session.step.failed',
    'session.usage.updated',
  ])
    type: projectOpenCodeStepUsageEvent,
  for (final type in const [
    'permission.asked',
    'permission.replied',
    'form.created',
    'form.replied',
    'form.cancelled',
  ])
    type: _interaction,
  for (final type in const [
    'session.revert.staged',
    'session.revert.cleared',
    'session.revert.committed',
  ])
    type: projectOpenCodeRevertEvent,
  for (final type in const [
    'session.created',
    'session.renamed',
    'session.deleted',
  ])
    type: projectOpenCodeSessionLifecycleEvent,
  for (final type in const [
    'session.instructions.updated',
    'session.synthetic',
  ])
    type: projectOpenCodeNoticeEvent,
};

/// Official 2.0.22 session types that no producer projects yet; they stay
/// visible as observations instead of half-mapped state.
const _unprojected = {
  'session.agent.selected',
  'session.model.selected',
  'session.moved',
  'session.metadata.updated',
  'session.viewed',
  'session.forked',
  'session.skill.activated',
  'session.shell.started',
  'session.shell.ended',
  'session.retry.scheduled',
  'session.compaction.started',
  'session.compaction.ended',
  'session.compaction.failed',
  'session.usage.recorded',
  'session.message.content.updated',
  'session.status',
  'session.idle',
  'session.compacted',
};

/// The single projection entry point for one 2.0.22 stream frame against the
/// latest [current] state; it owns no stream or clock.
///
/// Each type owned by an accepted producer is routed to exactly that producer,
/// whose result and finite exception are returned unchanged. Any other frame
/// is a no-op unless its `data.sessionID` names this session: frames without a
/// session (such as `server.connected`), for other sessions, plugin `rpc.*`
/// and UI `tui.*` commands, and unprojected `*.delta` content streams (which
/// would flood the bounded diagnostics) return nothing. The rest become one
/// [UnknownEvent] whose raw value says only whether the type is known but
/// unprojected or unrecognized; no payload content is read or copied.
List<SessionEvent> projectOpenCodeEvent(
  Object? value,
  SessionState current, {
  required String sourceVersion,
  required StreamPosition position,
  required DateTime receivedAt,
}) {
  if (value is! Map<String, Object?>) {
    _fail(OpenCodeEventProjectionFailure.malformed);
  }
  final type = value['type'];
  if (type is! String || type.isEmpty) {
    _fail(OpenCodeEventProjectionFailure.malformed);
  }
  final route = _routes[type];
  if (route != null) {
    return route(
      value,
      current,
      sourceVersion: sourceVersion,
      position: position,
      receivedAt: receivedAt,
    );
  }
  if (type.length > _typeLimit) {
    _fail(OpenCodeEventProjectionFailure.limitExceeded);
  }
  final data = value['data'];
  if (data is! Map<String, Object?> ||
      data['sessionID'] != current.ref.nativeId ||
      type.startsWith('rpc.') ||
      type.startsWith('tui.') ||
      type.endsWith('.delta')) {
    return const [];
  }
  if (OpenCodeCompatibility.parse(sourceVersion)?.toString() != '2.0.22') {
    _fail(OpenCodeEventProjectionFailure.unsupportedVersion);
  }
  final id = value['id'];
  final nativeId =
      id is String && id.startsWith('evt_') && id.length <= _typeLimit
      ? id
      : null;
  return List.unmodifiable([
    UnknownEvent(
      meta: EventMeta(
        owner: SessionOwner(current.ref),
        position: position,
        receivedAt: receivedAt,
        source: SourceProvenance(
          harness: current.ref.harnessRef,
          version: sourceVersion,
          nativeType: type,
          nativeEventId: nativeId,
        ),
      ),
      rawType: type,
      raw: CanonicalValue({
        'disposition': _unprojected.contains(type)
            ? 'unprojected'
            : 'unrecognized',
      }),
    ),
  ]);
}

Never _fail(OpenCodeEventProjectionFailure failure) =>
    throw OpenCodeEventProjectionException(failure);

/// Projects one native `session.permissions` stream frame into
/// [OpenCodeSessionRules]. Throws [OpenCodeEventProjectionException] on malformed
/// payload, invalid session ID, or unsupported server version.
OpenCodeSessionRules projectOpenCodeSessionPermissions(
  Object? value,
  SessionRef session, {
  required String sourceVersion,
}) {
  if (value is! Map<String, Object?>) {
    _fail(OpenCodeEventProjectionFailure.malformed);
  }
  final type = value['type'];
  if (type != 'session.permissions') {
    _fail(OpenCodeEventProjectionFailure.malformed);
  }
  if (OpenCodeCompatibility.parse(sourceVersion)?.toString() != '2.0.22') {
    _fail(OpenCodeEventProjectionFailure.unsupportedVersion);
  }
  final data = value['data'];
  if (data is! Map<String, Object?>) {
    _fail(OpenCodeEventProjectionFailure.malformed);
  }
  final sessionId = data['sessionID'];
  if (sessionId is! String || sessionId.isEmpty) {
    _fail(OpenCodeEventProjectionFailure.malformed);
  }
  try {
    openCodeSessionId(sessionId);
  } on FormatException {
    _fail(OpenCodeEventProjectionFailure.malformed);
  }
  if (sessionId != session.nativeId) {
    _fail(OpenCodeEventProjectionFailure.malformed);
  }
  final permissions = data['permissions'];
  if (permissions != null && permissions is! List) {
    _fail(OpenCodeEventProjectionFailure.malformed);
  }
  return OpenCodeSessionRules.parse(permissions);
}
