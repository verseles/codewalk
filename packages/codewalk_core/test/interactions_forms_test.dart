import 'package:codewalk_core/src/forms.dart';
import 'package:codewalk_core/src/identity.dart';
import 'package:codewalk_core/src/interactions.dart';
import 'package:codewalk_core/src/values.dart';
import 'package:test/test.dart';

const _host = HostId('host');
const _harness = HarnessInstanceId('profile');
const _session = SessionRef(_host, _harness, 'owner');
const _child = SessionRef(_host, _harness, 'child');
const _owner = SessionOwner(_session, origin: _child);

ApprovalChoice _choice({
  String id = 'once-native',
  bool allows = true,
  OpenValue<ApprovalScope> scope = const OpenValue.known(ApprovalScope.once),
  OpenValue<ResolutionScope> resolutionScope = const OpenValue.known(
    ResolutionScope.request,
  ),
  bool acceptsNote = false,
}) => ApprovalChoice(
  id: id,
  label: 'Native supplied label',
  allows: allows,
  scope: scope,
  resolutionScope: resolutionScope,
  acceptsNote: acceptsNote,
);

InteractionRequest _request({
  DomainOwner owner = _owner,
  OpenValue<InteractionKind> kind = const OpenValue.known(
    InteractionKind.permission,
  ),
  List<ApprovalChoice>? choices,
  FormSpec? form,
  bool requiresInput = false,
  bool autoApprovable = true,
}) => InteractionRequest(
  id: const InteractionId('same-native-request'),
  owner: owner,
  kind: kind,
  title: 'Supplied title',
  choices: choices ?? [_choice()],
  form: form,
  requiresInput: requiresInput,
  autoApprovable: autoApprovable,
);

FormField _field(String key, FormFieldKind kind, {bool required = false}) =>
    FormField(key: key, kind: OpenValue.known(kind), required: required);

void main() {
  test(
    'future form conditions retain raw content and block manual submission',
    () {
      final raw = <String, Object?>{
        'operator': 'future',
        'parts': <Object?>['retained'],
      };
      final condition = UnknownCondition(
        rawType: 'future-condition',
        raw: CanonicalValue(raw),
      );
      (raw['parts'] as List).clear();
      final form = FormSpec(
        fields: [
          FormField(
            key: 'required',
            kind: const OpenValue.known(FormFieldKind.string),
            required: true,
            condition: condition,
          ),
        ],
      );
      expect(condition.raw.value, {
        'operator': 'future',
        'parts': ['retained'],
      });
      expect(condition.evaluate(FormAnswers({})), isFalse);
      expect(
        form.validate(FormAnswers({})).single.kind,
        FormValidationKind.unknownCondition,
      );
      final request = _request(
        kind: const OpenValue.known(InteractionKind.form),
        form: form,
        choices: [],
      );
      expect(request.validateResponse(FormResponse(FormAnswers({}))), [
        InteractionResponseIssue.invalidFormAnswers,
      ]);
    },
  );
  test(
    'an unknown nested condition cannot be hidden by a true known branch',
    () {
      final condition = AnyConditions([
        EqualsCondition('control', 'enabled'),
        UnknownCondition(
          rawType: 'future',
          raw: CanonicalValue({'retain': true}),
        ),
      ]);
      final answers = FormAnswers({'control': const StringAnswer('enabled')});
      expect(condition.evaluate(answers), isTrue);
      expect(condition.isKnown, isFalse);
      final form = FormSpec(
        fields: [
          _field('control', FormFieldKind.string),
          FormField(
            key: 'detail',
            kind: const OpenValue.known(FormFieldKind.string),
            condition: condition,
          ),
        ],
      );
      expect(
        form.validate(answers).single.kind,
        FormValidationKind.unknownCondition,
      );
    },
  );
  group('synthetic interaction domain cases', () {
    test(
      'eligible once choice retains owner, child origin and native ordering',
      () {
        final choices = [
          _choice(id: 'reject-native', allows: false, acceptsNote: true),
          _choice(id: 'once-native'),
          _choice(
            id: 'project-native',
            scope: const OpenValue.known(ApprovalScope.persistentProject),
            resolutionScope: const OpenValue.known(ResolutionScope.project),
          ),
        ];
        final request = _request(choices: choices);
        choices.clear();
        expect(request.choices.map((choice) => choice.id), [
          'reject-native',
          'once-native',
          'project-native',
        ]);
        expect(request.automaticChoice?.id, 'once-native');
        expect((request.owner as SessionOwner).session, _session);
        expect((request.owner as SessionOwner).origin, _child);
        expect(() => request.choices.clear(), throwsUnsupportedError);
      },
    );

    test(
      'automatic permission rejects forms, input and nonpermission kinds',
      () {
        expect(_request(autoApprovable: false).automaticChoice, isNull);
        expect(_request(requiresInput: true).automaticChoice, isNull);
        expect(
          _request(
            form: FormSpec(
              fields: [_field('native-key', FormFieldKind.string)],
            ),
          ).automaticChoice,
          isNull,
        );
        for (final kind in InteractionKind.values) {
          if (kind == InteractionKind.permission) continue;
          expect(_request(kind: OpenValue.known(kind)).automaticChoice, isNull);
        }
        expect(
          _request(
            kind: OpenValue.unknown('future-permission'),
          ).automaticChoice,
          isNull,
        );
      },
    );

    test('unknown choice sets and all persistent scopes remain manual', () {
      for (final scope in ApprovalScope.values) {
        if (scope == ApprovalScope.once) continue;
        expect(
          _request(
            choices: [_choice(scope: OpenValue.known(scope))],
          ).automaticChoice,
          isNull,
        );
      }
      expect(
        _request(choices: [_choice(allows: false)]).automaticChoice,
        isNull,
      );
      final unknown = _choice(
        id: 'unknown-choice',
        scope: OpenValue.unknown('forever-on-other-host'),
      );
      final request = _request(choices: [_choice(), unknown]);
      expect(unknown.scope.value, 'forever-on-other-host');
      expect(request.automaticChoice, isNull);
      expect(request.validateResponse(ApprovalResponse('once-native')), [
        InteractionResponseIssue.unknownChoiceScope,
      ]);
      expect(
        _request(
          choices: [_choice(resolutionScope: OpenValue.unknown('all-tenants'))],
        ).automaticChoice,
        isNull,
      );
    });

    test('only session permission owners qualify automatically', () {
      final owners = <DomainOwner>[
        GlobalOwner(_session.harnessRef),
        HostOwner(_host, harness: _session.harnessRef),
        ProjectOwner(
          const ProjectRef(_host, '/canonical/path'),
          harness: _session.harnessRef,
        ),
        UnknownOwner(reason: 'unattributed'),
      ];
      for (final owner in owners) {
        expect(_request(owner: owner).automaticChoice, isNull);
      }
      expect(
        _request(
          owner: UnknownOwner(reason: 'unattributed'),
        ).validateResponse(ApprovalResponse('once-native')),
        [InteractionResponseIssue.unknownOwner],
      );
    });

    test(
      'identity separates owner scope without converting displayed origin',
      () {
        final parent = _request();
        final child = _request(owner: const SessionOwner(_child));
        final noOrigin = _request(owner: const SessionOwner(_session));
        expect(parent.identityKey, isNot(child.identityKey));
        expect(parent.identityKey, noOrigin.identityKey);
        final otherHarness = HarnessRef(
          _host,
          const HarnessInstanceId('other'),
        );
        expect(
          _request(owner: GlobalOwner(_session.harnessRef)).identityKey,
          isNot(_request(owner: GlobalOwner(otherHarness)).identityKey),
        );
        expect(
          _request(
            owner: HostOwner(_host),
          ).validateResponse(ApprovalResponse('once-native')),
          [InteractionResponseIssue.unknownOwner],
        );
      },
    );

    test('manual choices preserve note and same-session resolution scope', () {
      final request = _request(
        choices: [
          _choice(),
          _choice(
            id: 'reject-with-note',
            allows: false,
            acceptsNote: true,
            resolutionScope: const OpenValue.known(ResolutionScope.session),
          ),
        ],
      );
      expect(
        request.validateResponse(
          ApprovalResponse('reject-with-note', note: 'Continue without it'),
        ),
        isEmpty,
      );
      expect(
        request.choices.last.resolutionScope.known,
        ResolutionScope.session,
      );
      expect(
        request.validateResponse(
          ApprovalResponse('once-native', note: 'Unexpected'),
        ),
        [InteractionResponseIssue.noteNotAccepted],
      );
      expect(request.validateResponse(ApprovalResponse('invented')), [
        InteractionResponseIssue.choiceNotOffered,
      ]);
    });

    test(
      'unknown kind denies manual responses and resolution remains observable',
      () {
        final request = _request(kind: OpenValue.unknown('future-kind'));
        expect(request.validateResponse(ApprovalResponse('once-native')), [
          InteractionResponseIssue.unknownKind,
        ]);
        final resolution = InteractionResolution(
          id: request.id,
          owner: request.owner,
          kind: OpenValue.unknown('future-resolution'),
          source: CanonicalValue({'native-revision': 17}),
        );
        expect(resolution.kind.value, 'future-resolution');
        expect(resolution.identityKey, request.identityKey);
        expect(resolution.response, isNull);
      },
    );

    test('invalid runtime choice identifiers and duplicate offers fail', () {
      expect(() => _choice(id: ''), throwsArgumentError);
      expect(() => ApprovalResponse(''), throwsArgumentError);
      expect(
        () => _request(choices: [_choice(), _choice()]),
        throwsArgumentError,
      );
    });
  });

  group('synthetic typed form domain cases', () {
    test(
      'typed answers preserve arbitrary field keys and nested immutable data',
      () {
        final selected = ['alpha,beta', 'gamma'];
        final customSource = <String, Object?>{
          'nested': <Object?>['retained'],
        };
        final source = <String, FormAnswer>{
          'native.key/with punctuation': const StringAnswer('exact'),
          'num': NumberAnswer(1.25),
          'int': const IntegerAnswer(2),
          'flag': const BooleanAnswer(false),
          'single': const SingleSelectAnswer('alpha,beta'),
          'many': MultiSelectAnswer(selected),
          'custom': CustomAnswer(CanonicalValue(customSource)),
          'secret': const SecretAnswer('private'),
        };
        final answers = FormAnswers(source);
        source.clear();
        selected.clear();
        (customSource['nested'] as List).clear();
        expect(answers.toJson()['many'], ['alpha,beta', 'gamma']);
        expect(answers.toJson()['custom'], {
          'nested': ['retained'],
        });
        expect(answers.toJson()['native.key/with punctuation'], 'exact');
        expect(() => answers.values.clear(), throwsUnsupportedError);
        expect(
          () => (answers.toJson()['many'] as List).clear(),
          throwsUnsupportedError,
        );
        expect(
          () => (answers.toJson()['custom'] as Map).clear(),
          throwsUnsupportedError,
        );
      },
    );

    test(
      'missing references fail equality and inequality; multiselect uses membership',
      () {
        final missing = FormAnswers({});
        expect(EqualsCondition('key', 'a').evaluate(missing), isFalse);
        expect(NotEqualsCondition('key', 'a').evaluate(missing), isFalse);
        final answers = FormAnswers({
          'key': MultiSelectAnswer(['a,b', 'c']),
        });
        expect(EqualsCondition('key', 'a,b').evaluate(answers), isTrue);
        expect(EqualsCondition('key', 'a').evaluate(answers), isFalse);
        expect(NotEqualsCondition('key', 'a,b').evaluate(answers), isFalse);
        expect(NotEqualsCondition('key', 'a').evaluate(answers), isTrue);
        expect(IncludesCondition('key', 'a,b').evaluate(answers), isTrue);
        expect(IncludesCondition('key', 'a').evaluate(answers), isFalse);
        expect(NotEqualsCondition('key', true).evaluate(answers), isFalse);
      },
    );

    test('declarative all/any conditions snapshot their operands', () {
      final conditions = <FormCondition>[
        EqualsCondition('a', true),
        IncludesCondition('b', 'one'),
      ];
      final all = AllConditions(conditions);
      final any = AnyConditions(conditions);
      conditions.clear();
      final answers = FormAnswers({'a': const BooleanAnswer(true)});
      expect(all.evaluate(answers), isFalse);
      expect(any.evaluate(answers), isTrue);
      expect(() => all.conditions.clear(), throwsUnsupportedError);
      final unknown = FormAnswers({
        'a': UnknownAnswer(kind: 'future', value: CanonicalValue(true)),
      });
      expect(NotEqualsCondition('a', false).evaluate(unknown), isFalse);
      expect(EqualsCondition('a', true).evaluate(unknown), isFalse);
    });

    test(
      'field types and native option membership validate without coercion',
      () {
        final spec = FormSpec(
          fields: [
            _field('s', FormFieldKind.string, required: true),
            _field('n', FormFieldKind.number),
            _field('i', FormFieldKind.integer),
            _field('b', FormFieldKind.boolean),
            FormField(
              key: 'choice',
              kind: const OpenValue.known(FormFieldKind.singleSelect),
              options: [
                const FormOption(value: 'native,exact', label: 'Native'),
              ],
            ),
          ],
        );
        expect(
          spec.validate(
            FormAnswers({
              's': const StringAnswer(''),
              'n': const IntegerAnswer(3),
              'i': const IntegerAnswer(4),
              'b': const BooleanAnswer(false),
              'choice': const SingleSelectAnswer('native,exact'),
            }),
          ),
          isEmpty,
        );
        final issues = spec.validate(
          FormAnswers({
            'i': NumberAnswer(4.0),
            'b': const StringAnswer('false'),
            'choice': const SingleSelectAnswer('native'),
            'extra': const StringAnswer('x'),
          }),
        );
        expect(
          issues.map((issue) => (issue.key, issue.kind)),
          unorderedEquals([
            ('extra', FormValidationKind.unexpectedField),
            ('s', FormValidationKind.missingRequired),
            ('i', FormValidationKind.invalidAnswer),
            ('b', FormValidationKind.invalidAnswer),
            ('choice', FormValidationKind.invalidAnswer),
          ]),
        );
      },
    );

    test('inactive fields are not required or answerable', () {
      final spec = FormSpec(
        fields: [
          _field('toggle', FormFieldKind.boolean),
          FormField(
            key: 'dependent',
            kind: const OpenValue.known(FormFieldKind.string),
            required: true,
            condition: EqualsCondition('toggle', true),
          ),
        ],
      );
      expect(spec.validate(FormAnswers({})), isEmpty);
      expect(
        spec.validate(FormAnswers({'toggle': const BooleanAnswer(false)})),
        isEmpty,
      );
      expect(
        spec
            .validate(FormAnswers({'dependent': const StringAnswer('hidden')}))
            .single
            .kind,
        FormValidationKind.inactiveField,
      );
      expect(
        spec
            .validate(FormAnswers({'toggle': const BooleanAnswer(true)}))
            .single
            .kind,
        FormValidationKind.missingRequired,
      );
    });

    test('unknown fields are retained but never authorize form submission', () {
      final unknown = FormField(
        key: 'future-key',
        kind: OpenValue.unknown('future-widget'),
        metadata: CanonicalValue({
          'native-property': ['retained'],
        }),
        defaultAnswer: UnknownAnswer(
          kind: 'native-value',
          value: CanonicalValue({'a': 1}),
        ),
      );
      final spec = FormSpec(fields: [unknown]);
      expect(unknown.kind.value, 'future-widget');
      expect(
        spec.validate(FormAnswers({})).single.kind,
        FormValidationKind.unknownField,
      );
      expect(
        _request(
          form: spec,
          kind: const OpenValue.known(InteractionKind.form),
        ).validateResponse(FormResponse(FormAnswers({}))),
        [InteractionResponseIssue.invalidFormAnswers],
      );
    });

    test(
      'external links are retained as links and secrets remain explicitly typed',
      () {
        final spec = FormSpec(
          fields: [
            FormField(
              key: 'external',
              kind: const OpenValue.known(FormFieldKind.externalLink),
              externalUrl: 'https://example.test/confirm?native=a,b',
            ),
            _field('secret', FormFieldKind.secret, required: true),
            _field('custom', FormFieldKind.custom),
          ],
        );
        expect(
          spec.fields.first.externalUrl,
          'https://example.test/confirm?native=a,b',
        );
        expect(
          spec.validate(
            FormAnswers({
              'secret': const SecretAnswer('supplied'),
              'custom': CustomAnswer(CanonicalValue([1, false])),
            }),
          ),
          isEmpty,
        );
        expect(
          spec
              .validate(
                FormAnswers({
                  'secret': const StringAnswer('not-secret-typed'),
                  'external': const StringAnswer('cannot-answer-link'),
                }),
              )
              .map((issue) => issue.kind),
          [FormValidationKind.invalidAnswer, FormValidationKind.invalidAnswer],
        );
      },
    );

    test(
      'manual form replies must match the offered form and approval kind',
      () {
        final spec = FormSpec(
          fields: [_field('native-key', FormFieldKind.string, required: true)],
        );
        final request = _request(
          form: spec,
          kind: const OpenValue.known(InteractionKind.form),
        );
        expect(
          request.validateResponse(
            FormResponse(
              FormAnswers({'native-key': const StringAnswer('answer')}),
            ),
          ),
          isEmpty,
        );
        expect(request.validateResponse(ApprovalResponse('once-native')), [
          InteractionResponseIssue.wrongResponseKind,
        ]);
        expect(_request().validateResponse(FormResponse(FormAnswers({}))), [
          InteractionResponseIssue.wrongResponseKind,
        ]);
      },
    );

    test(
      'empty option sets cannot invent select choices; custom support is explicit',
      () {
        final select = FormSpec(
          fields: [_field('key', FormFieldKind.singleSelect)],
        );
        expect(
          select
              .validate(
                FormAnswers({'key': const SingleSelectAnswer('invented')}),
              )
              .single
              .kind,
          FormValidationKind.invalidAnswer,
        );
        final custom = FormSpec(
          fields: [
            FormField(
              key: 'key',
              kind: const OpenValue.known(FormFieldKind.singleSelect),
              acceptsCustom: true,
            ),
          ],
        );
        expect(
          custom.validate(
            FormAnswers({'key': const SingleSelectAnswer('custom')}),
          ),
          isEmpty,
        );
      },
    );

    test(
      'runtime invalid numbers, duplicate fields and forward conditions fail',
      () {
        expect(() => NumberAnswer(double.nan), throwsArgumentError);
        expect(() => NumberAnswer(double.infinity), throwsArgumentError);
        expect(() => EqualsCondition('key', []), throwsArgumentError);
        expect(
          () => FormSpec(
            fields: [
              _field('key', FormFieldKind.string),
              _field('key', FormFieldKind.boolean),
            ],
          ),
          throwsArgumentError,
        );
        expect(
          () => FormSpec(
            fields: [
              FormField(
                key: 'before',
                kind: const OpenValue.known(FormFieldKind.string),
                condition: EqualsCondition('later', true),
              ),
              _field('later', FormFieldKind.boolean),
            ],
          ),
          throwsArgumentError,
        );
        expect(
          () => FormField(
            key: 'link',
            kind: const OpenValue.known(FormFieldKind.externalLink),
          ),
          throwsArgumentError,
        );
        expect(
          () => FormField(
            key: 'choice',
            kind: const OpenValue.known(FormFieldKind.singleSelect),
            options: [
              const FormOption(value: 'duplicate', label: 'First'),
              const FormOption(value: 'duplicate', label: 'Second'),
            ],
          ),
          throwsArgumentError,
        );
        expect(
          () => FormField(
            key: 'integer',
            kind: const OpenValue.known(FormFieldKind.integer),
            defaultAnswer: NumberAnswer(1.5),
          ),
          throwsArgumentError,
        );
      },
    );
  });
}
