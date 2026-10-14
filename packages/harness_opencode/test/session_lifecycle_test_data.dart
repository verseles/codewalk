import 'dart:convert';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:harness_opencode/harness_opencode.dart';

import 'history_test_data.dart';
import 'text_reasoning_test_data.dart' show observedPosition;

// Source-shaped inputs, distinct from the immutable observed captures.
Map<String, Object?> lifecycleFrame(
  String phase, {
  String id = 'evt_lifecycle',
  String session = 'ses_a',
  Map<String, Object?>? data,
  Object? version,
  Object? seq = 0,
}) => {
  'id': id,
  'created': 1000,
  'type': 'session.$phase',
  'location': {'directory': '/fake-private-frame-location'},
  'metadata': {'secret': 'fake-private-frame-metadata'},
  'data': <String, Object?>{
    'sessionID': session,
    ...data ??
        switch (phase) {
          'created' => createdData(),
          'renamed' => {'title': 'Renamed title'},
          _ => const <String, Object?>{},
        },
  },
  'durable': <String, Object?>{
    'aggregateID': session,
    'seq': seq,
    'version': version ?? (phase == 'deleted' ? 2 : 1),
  },
};

Map<String, Object?> createdData({
  Map<String, Object?> fields = const {},
  bool withTitle = true,
}) => {
  'projectID': 'prj_a',
  'location': {
    'directory': '/workspace/project',
    'workspaceID': 'fake-private-workspace',
  },
  'subpath': 'fake-private-subpath',
  'slug': 'fake-private-slug',
  'version': '2.0.22',
  if (withTitle) 'title': 'First title',
  'agent': 'fake-private-agent',
  'model': {
    'id': 'fake-private-model',
    'providerID': 'fake-private-provider',
    'variant': 'low',
  },
  'metadata': {'secret': 'fake-private-metadata'},
  'permissions': [
    {'action': 'read', 'resource': 'fake-private-rule', 'effect': 'allow'},
  ],
  ...fields,
};

List<SessionEvent> projectLifecycle(
  Object? frame, {
  SessionState? current,
  int seq = 1,
  String version = '2.0.22',
}) => projectOpenCodeSessionLifecycleEvent(
  frame,
  current ?? SessionState(historyRef),
  sourceVersion: version,
  position: observedPosition(seq),
  receivedAt: DateTime.utc(2026, 10, 14),
);

Map<String, Object?> infoJson(SessionInfo info) => {
  'ref': info.ref.storageKey,
  'title': info.title,
  'ownership': info.ownership.kind.name,
  'ownershipReason': info.ownership.unknownReason,
  'project': info.project?.toString(),
  'parent': info.lineage.parent?.storageKey,
  'fork': info.lineage.fork?.source.storageKey,
  'metadata': info.metadata?.value,
};

String lifecycleManifest(SessionEvent event) => jsonEncode({
  'type': event.runtimeType.toString(),
  'source': {
    'type': event.meta.source.nativeType,
    'event': event.meta.source.nativeEventId,
    'aggregate': event.meta.source.aggregateId,
    'seq': event.meta.source.aggregateSeq?.toString(),
    'durability': event.meta.source.durability.value,
    'extra': event.meta.source.extra?.value,
  },
  ...switch (event) {
    SessionInfoChanged(:final info) => {'info': infoJson(info)},
    ResyncRequired(:final reason) => {'reason': reason},
    _ => throw StateError('Unexpected lifecycle producer event.'),
  },
});
