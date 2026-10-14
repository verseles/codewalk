import 'dart:convert';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:harness_opencode/harness_opencode.dart';
import 'package:test/test.dart';

import 'history_test_data.dart';
import 'interaction_test_data.dart';

Matcher failsWith(OpenCodeInteractionProjectionFailure failure) => throwsA(
  isA<OpenCodeInteractionProjectionException>()
      .having((e) => e.failure, 'failure', failure)
      .having(
        (e) => e.toString(),
        'toString',
        'OpenCodeInteractionProjectionException(${failure.name})',
      ),
);

InteractionRequest requestOf(SessionEvent? event) =>
    (event! as InteractionOpened).request;
InteractionResolution resolutionOf(SessionEvent? event) =>
    (event! as InteractionResolved).resolution;

Map<String, Object?> formWith(Object? fields) =>
    interactionFrame('form.created', formData(fields: fields));

void main() {
  final empty = SessionState(historyRef);

  test('a permission ask offers the native once, always and reject', () {
    final request = requestOf(
      projectInteraction(interactionFrame('permission.asked', askData())),
    );
    expect(request.id.value, 'per_a');
    expect(request.owner, SessionOwner(historyRef));
    expect(request.kind.known, InteractionKind.permission);
    expect(request.title, 'read');
    expect(request.subject?.value, {
      'action': 'read',
      'resources': ['src/file.txt'],
      'source': {'type': 'tool', 'messageID': 'msg_tool', 'id': 'call_1'},
    });
    expect(request.choices.map(choiceJson), [
      {
        'id': 'once',
        'label': 'once',
        'allows': true,
        'scope': 'once',
        'resolutionScope': 'request',
        'acceptsNote': false,
        'preview': null,
      },
      {
        'id': 'always',
        'label': 'always',
        'allows': true,
        'scope': 'persistentProject',
        'resolutionScope': 'project',
        'acceptsNote': false,
        'preview': {
          'patterns': ['read:*'],
        },
      },
      {
        'id': 'reject',
        'label': 'reject',
        'allows': false,
        'scope': 'once',
        'resolutionScope': 'session',
        'acceptsNote': true,
        'preview': null,
      },
    ]);
    expect(request.requiresInput, isFalse);
    expect(request.automaticChoice?.id, 'once');
  });

  test('always is offered only with save patterns', () {
    for (final save in [null, <String>[]]) {
      final request = requestOf(
        projectInteraction(
          interactionFrame('permission.asked', askData(save: save)),
        ),
      );
      expect(request.choices.map((c) => c.id), ['once', 'reject']);
    }
  });

  test('replies resolve with an unknown origin and the native choice', () {
    for (final reply in ['once', 'always', 'reject']) {
      final resolution = resolutionOf(
        projectInteraction(
          interactionFrame('permission.replied', {
            'sessionID': 'ses_a',
            'requestID': 'per_a',
            'reply': reply,
          }),
        ),
      );
      expect(resolution.id.value, 'per_a');
      expect(resolution.kind.known, isNull);
      expect(resolution.kind.value, 'replyOriginUnobserved');
      expect((resolution.response! as ApprovalResponse).choiceId, reply);
      expect(
        resolution.resolvedAt,
        DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true),
      );
    }
  });

  test('ask then reply opens and settles the interaction', () {
    var state = empty;
    for (final (i, frame) in [
      interactionFrame('permission.asked', askData()),
      interactionFrame('permission.asked', askData(), id: 'evt_dup'),
    ].indexed) {
      final event = projectInteraction(frame, current: state, seq: i + 1);
      if (i == 1) expect(event, isNull, reason: 'duplicate ask');
      if (event != null) state = reduce(state, event).state;
    }
    expect(state.interactions.single.id.value, 'per_a');
    state = reduce(
      state,
      projectInteraction(
        interactionFrame('permission.replied', {
          'sessionID': 'ses_a',
          'requestID': 'per_a',
          'reply': 'reject',
        }, id: 'evt_reply'),
        current: state,
        seq: 3,
      )!,
    ).state;
    expect(state.interactions, isEmpty);
  });

  test('a form maps fields, options, defaults and constraints', () {
    final request = requestOf(projectInteraction(formWith(null)));
    expect(request.kind.known, InteractionKind.form);
    expect(request.title, 'Pick one');
    expect(request.requiresInput, isTrue);
    expect(request.autoApprovable, isFalse);
    expect(request.choices, isEmpty);
    expect(request.form!.fields.map(fieldJson), [
      {
        'key': 'choice',
        'kind': 'string',
        'required': true,
        'hidden': false,
        'custom': false,
        'options': ['alpha', 'beta'],
        'default': null,
        'constraints': null,
        'url': null,
      },
      {
        'key': 'count',
        'kind': 'integer',
        'required': false,
        'hidden': false,
        'custom': false,
        'options': <String>[],
        'default': null,
        'constraints': {'minimum': 1, 'maximum': 3},
        'url': null,
      },
      {
        'key': 'confirmed',
        'kind': 'boolean',
        'required': false,
        'hidden': false,
        'custom': false,
        'options': <String>[],
        'default': null,
        'constraints': null,
        'url': null,
      },
    ]);
    final answers = FormAnswers({
      'choice': const StringAnswer('alpha'),
      'count': const IntegerAnswer(2),
      'confirmed': const BooleanAnswer(true),
    });
    expect(request.validateResponse(FormResponse(answers)), isEmpty);
  });

  test('every native field type and condition maps to Core', () {
    final fields = requestOf(
      projectInteraction(
        formWith([
          {
            'key': 'mode',
            'type': 'multiselect',
            'options': [
              {'value': 'a', 'label': 'A'},
              {'value': 'b', 'label': 'B'},
            ],
            'minItems': 1,
            'custom': true,
            'default': ['a'],
          },
          {
            'key': 'email',
            'type': 'string',
            'format': 'email',
            'maxLength': 40,
            'placeholder': 'you@example.com',
            'default': 'x@y.z',
            'hidden': true,
            'when': [
              {'key': 'mode', 'op': 'eq', 'value': 'a'},
            ],
          },
          {
            'key': 'ratio',
            'type': 'number',
            'default': 0.5,
            'when': [
              {'key': 'mode', 'op': 'neq', 'value': 'b'},
              {'key': 'email', 'op': 'eq', 'value': 'x@y.z'},
            ],
          },
          {'key': 'n', 'type': 'integer', 'default': 2},
          {'key': 'ok', 'type': 'boolean', 'default': false},
          {'key': 'docs', 'type': 'external', 'url': 'https://example.com'},
        ]),
      ),
    ).form!.fields;
    expect(fields.map((f) => f.kind.value), [
      'multiSelect',
      'string',
      'number',
      'integer',
      'boolean',
      'externalLink',
    ]);
    expect(fields[0].acceptsCustom, isTrue);
    expect(fields[0].defaultAnswer?.toJson(), ['a']);
    expect(fields[0].constraints?.value, {'minItems': 1});
    expect(fields[1].hidden, isTrue);
    expect(fields[1].constraints?.value, {
      'format': 'email',
      'maxLength': 40,
      'placeholder': 'you@example.com',
    });
    expect(fields[1].condition, isA<EqualsCondition>());
    expect(fields[2].condition, isA<AllConditions>());
    expect(fields[3].defaultAnswer, isA<IntegerAnswer>());
    expect(fields[5].externalUrl, 'https://example.com');
    // Multiselect membership: `eq a` holds when the selection includes `a`.
    final selected = FormAnswers({
      'mode': MultiSelectAnswer(['a']),
    });
    expect(fields[1].isActive(selected), isTrue);
    expect(fields[1].isActive(FormAnswers(const {})), isFalse);
  });

  test('a future field type stays explicit and unanswerable', () {
    final field = requestOf(
      projectInteraction(
        formWith([
          {'key': 'x', 'type': 'color', 'palette': 'fake-private-palette'},
        ]),
      ),
    ).form!.fields.single;
    expect(field.kind.known, isNull);
    expect(field.kind.value, 'color');
    expect(field.constraints, isNull);
  });

  test('global forms belong to the harness, not a session', () {
    final request = requestOf(
      projectInteraction(
        interactionFrame('form.created', formData(session: 'global')),
      ),
    );
    expect(request.owner, GlobalOwner(historyRef.harnessRef));
    final state = reduce(
      empty,
      projectInteraction(
        interactionFrame('form.created', formData(session: 'global')),
      )!,
    ).state;
    expect(state.interactions.single.owner, isA<GlobalOwner>());
    final cancelled = resolutionOf(
      projectInteraction(
        interactionFrame('form.cancelled', {
          'id': 'frm_a',
          'sessionID': 'global',
        }),
        current: state,
        seq: 2,
      ),
    );
    expect(cancelled.owner, GlobalOwner(historyRef.harnessRef));
    expect(
      () => projectInteraction(
        interactionFrame('permission.asked', askData(session: 'global')),
      ),
      failsWith(OpenCodeInteractionProjectionFailure.malformed),
    );
  });

  test('form replies keep no answers; cancellation is cancelled', () {
    final replied = projectInteraction(
      interactionFrame('form.replied', {
        'id': 'frm_a',
        'sessionID': 'ses_a',
        'answer': {
          'choice': 'fake-private-answer',
          'count': 2,
          'tags': ['fake-private-tag'],
        },
      }),
    );
    expect(resolutionOf(replied).response, isNull);
    expect(resolutionOf(replied).kind.value, 'replyOriginUnobserved');
    expect(
      replied!.meta.source.extra?.value,
      containsPair('answerNotProjected', true),
    );
    expect(interactionManifest(replied), isNot(contains('fake-private')));
    final cancelled = resolutionOf(
      projectInteraction(
        interactionFrame('form.cancelled', {
          'id': 'frm_a',
          'sessionID': 'ses_a',
        }),
      ),
    );
    expect(cancelled.kind.known, InteractionResolutionKind.cancelled);
  });

  test('private fields are never copied', () {
    final manifests = [
      projectInteraction(interactionFrame('permission.asked', askData())),
      projectInteraction(formWith(null)),
    ].map((e) => interactionManifest(e!)).join();
    for (final secret in [
      'fake-private-metadata',
      'fake-private-message',
      'fake-private-location',
    ]) {
      expect(manifests, isNot(contains(secret)), reason: secret);
    }
    final source = projectInteraction(
      interactionFrame('permission.asked', askData()),
    )!.meta.source;
    expect(source.durability.known, Durability.ephemeral);
    expect(source.aggregateId, isNull);
    expect(source.extra?.value, {
      'nativeCreated': 1000,
      'metadataNotProjected': true,
      'messageNotProjected': true,
    });
  });

  test('unrelated types and foreign sessions are ignored', () {
    expect(projectInteraction({'type': 'session.text.delta'}), isNull);
    expect(
      projectInteraction(
        interactionFrame('permission.asked', askData(session: 'ses_b')),
      ),
      isNull,
    );
    expect(
      projectInteraction(
        interactionFrame('form.created', formData(session: 'ses_b')),
      ),
      isNull,
    );
  });

  test('malformed and unsupported frames fail atomically by category', () {
    Map<String, Object?> ask(Map<String, Object?> fields) =>
        interactionFrame('permission.asked', askData(fields: fields));
    for (final (frame, failure) in [
      (null, OpenCodeInteractionProjectionFailure.malformed),
      ({'type': 1}, OpenCodeInteractionProjectionFailure.malformed),
      (
        {
          ...ask(const {}),
          'durable': {'version': 1},
        },
        OpenCodeInteractionProjectionFailure.malformed,
      ),
      (
        {...ask(const {}), 'id': 'x'},
        OpenCodeInteractionProjectionFailure.malformed,
      ),
      (
        {...ask(const {}), 'created': -1},
        OpenCodeInteractionProjectionFailure.malformed,
      ),
      (ask({'id': 'x_a'}), OpenCodeInteractionProjectionFailure.malformed),
      (ask({'resources': 'x'}), OpenCodeInteractionProjectionFailure.malformed),
      (
        ask({'resources': List.filled(4097, 'r')}),
        OpenCodeInteractionProjectionFailure.limitExceeded,
      ),
      (
        ask({
          'source': {'type': 'mcp', 'messageID': 'm', 'id': 'i'},
        }),
        OpenCodeInteractionProjectionFailure.unsupportedValue,
      ),
      (
        ask({'resources': List.filled(40, 'r' * 4000)}),
        OpenCodeInteractionProjectionFailure.limitExceeded,
      ),
      (
        interactionFrame('permission.replied', {
          'sessionID': 'ses_a',
          'requestID': 'per_a',
          'reply': 'later',
        }),
        OpenCodeInteractionProjectionFailure.unsupportedValue,
      ),
      (formWith(<Object?>[]), OpenCodeInteractionProjectionFailure.malformed),
      (
        formWith([
          for (var i = 0; i < 80; i++)
            {'key': 'f$i', 'type': 'string', 'description': 'd' * 4000},
        ]),
        OpenCodeInteractionProjectionFailure.limitExceeded,
      ),
      (
        formWith([
          {'key': 'a', 'type': 'string'},
          {'key': 'a', 'type': 'string'},
        ]),
        OpenCodeInteractionProjectionFailure.malformed,
      ),
      (
        formWith([
          {
            'key': 'a',
            'type': 'string',
            'when': [
              {'key': 'later', 'op': 'eq', 'value': 'x'},
            ],
          },
          {'key': 'later', 'type': 'string'},
        ]),
        OpenCodeInteractionProjectionFailure.malformed,
      ),
      (
        formWith([
          {
            'key': 'a',
            'type': 'string',
            'when': [
              {'key': 'a', 'op': 'gt', 'value': 1},
            ],
          },
        ]),
        OpenCodeInteractionProjectionFailure.unsupportedValue,
      ),
      (
        formWith([
          {'key': 'n', 'type': 'integer', 'default': 1.5},
        ]),
        OpenCodeInteractionProjectionFailure.malformed,
      ),
      (
        formWith([
          {
            'key': 's',
            'type': 'string',
            'options': [
              {'value': 'a', 'label': 'A'},
            ],
            'default': 'b',
          },
        ]),
        OpenCodeInteractionProjectionFailure.malformed,
      ),
      (
        formWith([
          {'key': 's', 'type': 'string', 'format': 'phone'},
        ]),
        OpenCodeInteractionProjectionFailure.unsupportedValue,
      ),
      (
        formWith([
          {'key': 'e', 'type': 'external'},
        ]),
        OpenCodeInteractionProjectionFailure.malformed,
      ),
      (
        interactionFrame('form.replied', {
          'id': 'frm_a',
          'sessionID': 'ses_a',
          'answer': {
            'x': {'nested': true},
          },
        }),
        OpenCodeInteractionProjectionFailure.malformed,
      ),
    ]) {
      expect(() => projectInteraction(frame), failsWith(failure));
    }
    for (final version in ['2.0.21', '2.0.22-rc.1', 'x']) {
      expect(
        () => projectInteraction(
          interactionFrame('permission.asked', askData()),
          version: version,
        ),
        failsWith(OpenCodeInteractionProjectionFailure.unsupportedVersion),
      );
    }
  });

  test('permission and form IDs never collide under one owner', () {
    final state = reduce(
      empty,
      projectInteraction(
        interactionFrame('form.created', formData(id: 'frm_x')),
      )!,
    ).state;
    final clash =
        jsonDecode(jsonEncode(askData(id: 'per_x'))) as Map<String, Object?>;
    expect(
      projectInteraction(
        interactionFrame('permission.asked', clash),
        current: state,
        seq: 2,
      ),
      isA<InteractionOpened>(),
      reason: 'distinct native prefixes never collide',
    );
  });
}
