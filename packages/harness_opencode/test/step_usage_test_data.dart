import 'dart:convert';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:harness_opencode/harness_opencode.dart';

import 'history_test_data.dart';
import 'text_reasoning_test_data.dart' show observedPosition;

const tokenJson = <String, Object?>{
  'input': 10,
  'output': 2,
  'reasoning': 1,
  'cache': {'read': 3, 'write': 0},
};

// Source-shaped inputs, distinct from immutable observed A–E captures.
Map<String, Object?> stepFrame(
  String phase, {
  String id = 'evt_step',
  String session = 'ses_a',
  String message = 'msg_step',
  Map<String, Object?> fields = const {},
  Object? seq = 0.0,
  Object? version = 1.0,
}) => {
  'id': id,
  'created': 1000,
  'type': 'session.step.$phase',
  'location': {'directory': '/fake-private-location'},
  'data': <String, Object?>{
    'sessionID': session,
    'assistantMessageID': message,
    ...switch (phase) {
      'started' => {
        'agent': 'build',
        'model': {'id': 'model', 'providerID': 'provider'},
        'snapshot': 'fake-private-snapshot',
        'started': 900,
      },
      'ended' => {
        'finish': 'stop',
        'rawFinish': 'fake-private-raw-finish',
        'providerState': {'secret': 'fake-private-state'},
        'cost': 0.25,
        'tokens': tokenJson,
        'snapshot': 'fake-private-snapshot',
        'files': ['fake/private/file.txt'],
      },
      'failed' => {
        'error': {
          'type': 'provider.auth',
          'message': 'fake-private-message',
          'status': 401,
          'response': {'body': 'fake-private-body'},
        },
      },
      _ => const <String, Object?>{},
    },
    ...fields,
  },
  'durable': <String, Object?>{
    'aggregateID': session,
    'seq': seq,
    'version': version,
  },
};

Map<String, Object?> usageFrame({
  String id = 'evt_usage',
  String session = 'ses_a',
  Object? cost = 1.5,
  Object? tokens = tokenJson,
}) => {
  'id': id,
  'created': 2000,
  'type': 'session.usage.updated',
  'data': <String, Object?>{
    'sessionID': session,
    'cost': cost,
    'tokens': tokens,
  },
};

List<SessionEvent> projectStepUsage(
  Object? frame, {
  SessionState? current,
  int seq = 1,
  String epoch = 'epoch-a',
  String version = '2.0.22',
}) => projectOpenCodeStepUsageEvent(
  frame,
  current ?? SessionState(historyRef),
  sourceVersion: version,
  position: observedPosition(seq, epoch: epoch),
  receivedAt: DateTime.utc(2026, 10, 14),
);

Map<String, Object?> usageJson(UsageObservation o) => {
  'id': o.id,
  'scope': o.scope.value,
  'source': o.source.value,
  'observedAt': o.observedAt.toIso8601String(),
  'tokens': [
    o.tokens?.input,
    o.tokens?.output,
    o.tokens?.reasoning,
    o.tokens?.cacheRead,
    o.tokens?.cacheWrite,
  ],
  'cost': {
    'amount': o.cost?.amount,
    'currency': o.cost?.currency,
    'partial': o.cost?.partial,
    'cumulative': o.cost?.cumulative,
  },
  'partial': o.partial,
  'cumulative': o.cumulative,
  'aggregationKey': o.aggregationKey,
};

String stepUsageManifest(SessionEvent event) => jsonEncode({
  'source': {
    'type': event.meta.source.nativeType,
    'event': event.meta.source.nativeEventId,
    'aggregate': event.meta.source.aggregateId,
    'seq': event.meta.source.aggregateSeq?.toString(),
    'durability': event.meta.source.durability.value,
    'extra': event.meta.source.extra?.value,
  },
  ...switch (event) {
    ItemUpserted(:final item) => {'item': semanticItem(item)},
    UsageObserved(:final observation) => {'usage': usageJson(observation)},
    StepChanged(:final step) => {
      'step': step == null
          ? null
          : {
              'message': step.message.value,
              'startedAt': step.startedAt?.toIso8601String(),
              'model': [step.modelId, step.modelProviderId, step.modelVariant],
              'agent': step.agentId,
            },
    },
    _ => throw StateError('Unexpected step/usage producer event.'),
  },
});
