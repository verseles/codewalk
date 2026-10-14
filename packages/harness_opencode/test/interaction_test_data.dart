import 'dart:convert';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:harness_opencode/harness_opencode.dart';

import 'history_test_data.dart';
import 'text_reasoning_test_data.dart' show observedPosition;

// Source-shaped inputs, distinct from immutable observed C/D captures.
Map<String, Object?> interactionFrame(
  String type,
  Map<String, Object?> data, {
  String id = 'evt_interaction',
  Object? created = 1000,
}) => {
  'id': id,
  'created': created,
  'type': type,
  'location': {'directory': '/fake-private-location'},
  'data': data,
};

Map<String, Object?> askData({
  String id = 'per_a',
  String session = 'ses_a',
  List<String>? save = const ['read:*'],
  Map<String, Object?> fields = const {},
}) => {
  'id': id,
  'sessionID': session,
  'action': 'read',
  'resources': ['src/file.txt'],
  'save': ?save,
  'metadata': {'secret': 'fake-private-metadata'},
  'source': {'type': 'tool', 'messageID': 'msg_tool', 'id': 'call_1'},
  'message': 'fake-private-message',
  ...fields,
};

Map<String, Object?> formData({
  String id = 'frm_a',
  String session = 'ses_a',
  Object? fields,
}) => {
  'form': {
    'id': id,
    'sessionID': session,
    'title': 'Pick one',
    'metadata': {'secret': 'fake-private-metadata'},
    'fields':
        fields ??
        [
          {
            'key': 'choice',
            'required': true,
            'type': 'string',
            'options': [
              {'value': 'alpha', 'label': 'Alpha'},
              {'value': 'beta', 'label': 'Beta'},
            ],
          },
          {'key': 'count', 'type': 'integer', 'minimum': 1, 'maximum': 3},
          {'key': 'confirmed', 'type': 'boolean'},
        ],
  },
};

SessionEvent? projectInteraction(
  Object? frame, {
  SessionState? current,
  int seq = 1,
  String version = '2.0.22',
}) => projectOpenCodeInteractionEvent(
  frame,
  current ?? SessionState(historyRef),
  sourceVersion: version,
  position: observedPosition(seq),
  receivedAt: DateTime.utc(2026, 10, 14),
);

Map<String, Object?> choiceJson(ApprovalChoice c) => {
  'id': c.id,
  'label': c.label,
  'allows': c.allows,
  'scope': c.scope.value,
  'resolutionScope': c.resolutionScope.value,
  'acceptsNote': c.acceptsNote,
  'preview': c.scopePreview?.value,
};

Map<String, Object?> fieldJson(FormField f) => {
  'key': f.key,
  'kind': f.kind.value,
  'required': f.required,
  'hidden': f.hidden,
  'custom': f.acceptsCustom,
  'options': [for (final o in f.options) o.value],
  'default': f.defaultAnswer?.toJson(),
  'constraints': f.constraints?.value,
  'url': f.externalUrl,
};

String interactionManifest(SessionEvent event) => jsonEncode({
  'source': {
    'type': event.meta.source.nativeType,
    'event': event.meta.source.nativeEventId,
    'durability': event.meta.source.durability.value,
    'extra': event.meta.source.extra?.value,
  },
  ...switch (event) {
    InteractionOpened(:final request) => {
      'id': request.id.value,
      'owner': request.owner.scopeKey,
      'kind': request.kind.value,
      'title': request.title,
      'subject': request.subject?.value,
      'choices': request.choices.map(choiceJson).toList(),
      'fields': request.form?.fields.map(fieldJson).toList(),
    },
    InteractionResolved(:final resolution) => {
      'id': resolution.id.value,
      'owner': resolution.owner.scopeKey,
      'kind': resolution.kind.value,
      'choice': switch (resolution.response) {
        ApprovalResponse(:final choiceId) => choiceId,
        _ => null,
      },
      'at': resolution.resolvedAt?.toIso8601String(),
    },
    _ => throw StateError('Unexpected interaction producer event.'),
  },
});
