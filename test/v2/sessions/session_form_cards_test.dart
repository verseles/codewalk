import 'package:codewalk/features/sessions/session_form_card.dart';
import 'package:codewalk/features/sessions/session_live_controller.dart';
import 'package:codewalk/shared/l10n/generated/v2_localizations.dart';
import 'package:codewalk/shared/l10n/generated/v2_localizations_en.dart';
import 'package:codewalk/shared/sessions/session_live_source.dart';
import 'package:codewalk/shared/sessions/session_permission_reply.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart' hide FormField;
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';
import 'live_fakes.dart';

InteractionRequest _formRequest(
  SessionRef ref,
  String id, {
  DomainOwner? owner,
  String? title,
  required FormSpec form,
}) => InteractionRequest(
  id: InteractionId(id),
  owner: owner ?? SessionOwner(ref),
  kind: const OpenValue.known(InteractionKind.form),
  title: title ?? 'Survey Form',
  form: form,
);

void main() {
  group('form notice copy mapping', () {
    final l10n = V2LocalizationsEn();

    test('maps every phase to finite localized copy', () {
      SessionPermissionReplyState at(SessionPermissionReplyPhase phase) =>
          SessionPermissionReplyState(phase: phase);
      expect(
        formNoticeText(l10n, at(SessionPermissionReplyPhase.ready)),
        isNull,
      );
      expect(
        formNoticeText(l10n, at(SessionPermissionReplyPhase.idle)),
        isNull,
      );
      expect(
        formNoticeText(l10n, at(SessionPermissionReplyPhase.requesting)),
        l10n.liveFormSending,
      );
      expect(
        formNoticeText(l10n, at(SessionPermissionReplyPhase.requested)),
        l10n.liveFormSent,
      );
      expect(
        formNoticeText(l10n, at(SessionPermissionReplyPhase.unconfirmed)),
        l10n.liveFormUnconfirmed,
      );
      expect(
        formNoticeText(l10n, at(SessionPermissionReplyPhase.refused)),
        l10n.liveFormRefused,
      );
    });

    test('refused maps known error types without raw text', () {
      CommandReceipt refused(String type) => CommandReceipt.rejected(
        id: const CommandId('cmd_form_notice'),
        owner: const SessionOwner(
          SessionRef(HostId('h'), HarnessInstanceId('i'), 'ses_notice'),
        ),
        error: ErrorInfo(
          kind: const OpenValue.known(ErrorKind.auth),
          rawType: type,
          rawMessage: 'never shown',
        ),
      );
      SessionPermissionReplyState refusedWith(String type) =>
          SessionPermissionReplyState(
            phase: SessionPermissionReplyPhase.refused,
            receipt: refused(type),
          );
      expect(
        formNoticeText(l10n, refusedWith('UnauthorizedError')),
        l10n.hostsAuthRequired,
      );
      expect(
        formNoticeText(l10n, refusedWith('RateLimited')),
        l10n.sessionsRateLimited,
      );
      expect(
        formNoticeText(l10n, refusedWith('NotFoundError')),
        l10n.livePermissionAnsweredElsewhere,
      );
      expect(
        formNoticeText(l10n, refusedWith('InvalidRequestError')),
        l10n.liveFormRefused,
      );
    });
  });

  group('controller form reply gating', () {
    late CatalogRig rig;
    late LiveDirectory directory;
    late SessionLiveController live;
    late SessionRef ref;
    late LiveHandle handle;
    var commands = 0;

    Future<void> open({SessionLiveView? view}) async {
      final opening = live.start();
      handle = directory.grant(ref);
      handle.replyAvailable = true;
      await opening;
      handle.emit(
        view ??
            SessionLiveView(
              session: ref,
              phase: SessionLivePhase.live,
              state: liveState(
                ref,
                interactions: [
                  _formRequest(
                    ref,
                    'form_1',
                    form: FormSpec(
                      fields: [
                        FormField(
                          key: 'name',
                          kind: const OpenValue.known(FormFieldKind.string),
                          title: 'Your name',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      );
      await pumpEventQueue();
    }

    setUp(() async {
      rig = CatalogRig();
      await rig.save('a');
      await rig.sessions.initialize();
      directory = LiveDirectory();
      final summary = CatalogSource(profile('a')).row('one');
      ref = summary.info.ref;
      commands = 0;
      live = SessionLiveController(
        hosts: rig.hosts,
        profile: profile('a'),
        summary: summary,
        directory: directory,
        commandIds: () => CommandId('cmd_${++commands}'),
      );
    });

    tearDown(() {
      live.dispose();
      rig.dispose();
    });

    test('canReplyForm requires live phase and resident interaction', () async {
      await open();
      final req = _formRequest(
        ref,
        'form_1',
        form: FormSpec(
          fields: [
            FormField(
              key: 'name',
              kind: const OpenValue.known(FormFieldKind.string),
            ),
          ],
        ),
      );
      expect(live.canReplyForm(req), isTrue);

      // Stale or wrong phase disables canReplyForm
      handle.emit(
        SessionLiveView(
          session: ref,
          phase: SessionLivePhase.live,
          stale: true,
          state: liveState(ref, interactions: [req]),
        ),
      );
      await pumpEventQueue();
      expect(live.canReplyForm(req), isFalse);
    });

    test('preserves form draft values across network failure', () async {
      await open();
      final req = _formRequest(
        ref,
        'form_1',
        form: FormSpec(
          fields: [
            FormField(
              key: 'name',
              kind: const OpenValue.known(FormFieldKind.string),
            ),
          ],
        ),
      );

      live.setFormFieldDraft(req.id, 'name', 'Alice');
      expect(live.formDraft(req.id)['name'], 'Alice');

      // Inject network refusal in handle
      handle.formAction = (request, response) async {
        return SessionPermissionReplyState(
          phase: SessionPermissionReplyPhase.refused,
          receipt: CommandReceipt.rejected(
            id: const CommandId('cmd_err'),
            owner: SessionOwner(ref),
            error: ErrorInfo(
              kind: const OpenValue.known(ErrorKind.auth),
              rawType: 'UnauthorizedError',
              rawMessage: 'Auth error',
            ),
          ),
        );
      };

      await live.replyToForm(
        request: req,
        answers: FormAnswers({'name': const StringAnswer('Alice')}),
      );

      // Draft value is preserved for user retry
      expect(live.formDraft(req.id)['name'], 'Alice');
      expect(
        live.replyState(req.id).phase,
        SessionPermissionReplyPhase.refused,
      );
    });

    test('prunes draft when interaction is resolved / leaves resident state', () async {
      await open();
      final req = _formRequest(
        ref,
        'form_1',
        form: FormSpec(
          fields: [
            FormField(
              key: 'name',
              kind: const OpenValue.known(FormFieldKind.string),
            ),
          ],
        ),
      );

      live.setFormFieldDraft(req.id, 'name', 'Bob');
      expect(live.formDraft(req.id)['name'], 'Bob');

      // Interaction resolved elsewhere: state arrives without form_1
      handle.emit(
        SessionLiveView(
          session: ref,
          phase: SessionLivePhase.live,
          state: liveState(ref, interactions: []),
        ),
      );
      await pumpEventQueue();

      expect(live.formDraft(req.id)['name'], isNull);
    });
  });

  group('SessionFormCard UI widgets', () {
    late CatalogRig rig;
    late LiveDirectory directory;
    late SessionLiveController live;
    late SessionRef ref;
    late LiveHandle handle;
    var commands = 0;

    setUp(() async {
      rig = CatalogRig();
      await rig.save('a');
      await rig.sessions.initialize();
      directory = LiveDirectory();
      final summary = CatalogSource(profile('a')).row('one');
      ref = summary.info.ref;
      commands = 0;
      live = SessionLiveController(
        hosts: rig.hosts,
        profile: profile('a'),
        summary: summary,
        directory: directory,
        commandIds: () => CommandId('cmd_${++commands}'),
      );
    });

    Future<void> open(
      List<InteractionRequest> interactions, {
      bool replyPort = true,
    }) async {
      final opening = live.start();
      handle = directory.grant(ref);
      handle.replyAvailable = replyPort;
      await opening;
      handle.emit(
        SessionLiveView(
          session: ref,
          phase: SessionLivePhase.live,
          state: liveState(ref, interactions: interactions),
        ),
      );
    }

    tearDown(() {
      live.dispose();
      rig.dispose();
    });

    Future<void> settleFrames(WidgetTester tester) async {
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> pump(WidgetTester tester, {double maxHeight = 1200}) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: V2Localizations.localizationsDelegates,
          supportedLocales: V2Localizations.supportedLocales,
          home: Scaffold(
            body: SessionFormCards(live: live, maxHeight: maxHeight),
          ),
        ),
      );
      await settleFrames(tester);
    }

    testWidgets('renders all 9 FormFieldKinds properly', (tester) async {
      final spec = FormSpec(
        fields: [
          FormField(
            key: 'str',
            kind: const OpenValue.known(FormFieldKind.string),
            title: 'String Field',
          ),
          FormField(
            key: 'num',
            kind: const OpenValue.known(FormFieldKind.number),
            title: 'Number Field',
          ),
          FormField(
            key: 'int',
            kind: const OpenValue.known(FormFieldKind.integer),
            title: 'Integer Field',
          ),
          FormField(
            key: 'bool',
            kind: const OpenValue.known(FormFieldKind.boolean),
            title: 'Boolean Field',
          ),
          FormField(
            key: 'single',
            kind: const OpenValue.known(FormFieldKind.singleSelect),
            title: 'Single Select Field',
            options: const [
              FormOption(value: 'opt1', label: 'Option 1'),
              FormOption(value: 'opt2', label: 'Option 2'),
            ],
          ),
          FormField(
            key: 'multi',
            kind: const OpenValue.known(FormFieldKind.multiSelect),
            title: 'Multi Select Field',
            options: const [
              FormOption(value: 'm1', label: 'Multi 1'),
              FormOption(value: 'm2', label: 'Multi 2'),
            ],
          ),
          FormField(
            key: 'custom',
            kind: const OpenValue.known(FormFieldKind.custom),
            title: 'Custom Field',
          ),
          FormField(
            key: 'secret',
            kind: const OpenValue.known(FormFieldKind.secret),
            title: 'Secret Field',
          ),
          FormField(
            key: 'link',
            kind: const OpenValue.known(FormFieldKind.externalLink),
            title: 'External Documentation',
            externalUrl: 'https://example.com/docs',
          ),
        ],
      );
      final request = _formRequest(ref, 'all_fields', form: spec);

      await open([request]);
      await pump(tester);

      expect(find.byKey(const ValueKey('live-form-all_fields')), findsOneWidget);
      expect(find.byKey(const ValueKey('form-field-str')), findsOneWidget);
      expect(find.byKey(const ValueKey('form-field-num')), findsOneWidget);
      expect(find.byKey(const ValueKey('form-field-int')), findsOneWidget);
      expect(find.byKey(const ValueKey('form-field-bool')), findsOneWidget);
      expect(find.byKey(const ValueKey('form-field-single')), findsOneWidget);
      expect(find.byKey(const ValueKey('form-field-multi')), findsOneWidget);
      expect(find.byKey(const ValueKey('form-field-custom')), findsOneWidget);
      expect(find.byKey(const ValueKey('form-field-secret')), findsOneWidget);
      expect(find.byKey(const ValueKey('form-field-link')), findsOneWidget);

      // Secret visibility toggle works
      final secretFieldFinder = find.byKey(const ValueKey('form-field-secret'));
      final editable = tester.widget<EditableText>(
        find.descendant(of: secretFieldFinder, matching: find.byType(EditableText)),
      );
      expect(editable.obscureText, isTrue);

      await tester.tap(find.byKey(const ValueKey('form-secret-toggle-secret')));
      await settleFrames(tester);

      final editableAfter = tester.widget<EditableText>(
        find.descendant(of: secretFieldFinder, matching: find.byType(EditableText)),
      );
      expect(editableAfter.obscureText, isFalse);
    });

    testWidgets('dynamic conditional visibility toggles dependent field', (tester) async {
      final spec = FormSpec(
        fields: [
          FormField(
            key: 'show_extra',
            kind: const OpenValue.known(FormFieldKind.boolean),
            title: 'Show extra details',
          ),
          FormField(
            key: 'extra_details',
            kind: const OpenValue.known(FormFieldKind.string),
            title: 'Extra Details',
            condition: EqualsCondition('show_extra', true),
          ),
        ],
      );
      final request = _formRequest(ref, 'cond_form', form: spec);

      await open([request]);
      await pump(tester);

      // Initially show_extra is false, so extra_details is not rendered
      expect(find.byKey(const ValueKey('form-field-show_extra')), findsOneWidget);
      expect(find.byKey(const ValueKey('form-field-extra_details')), findsNothing);

      // Toggle switch to true
      await tester.tap(find.byKey(const ValueKey('form-field-show_extra')));
      await settleFrames(tester);

      // Now extra_details appears
      expect(find.byKey(const ValueKey('form-field-extra_details')), findsOneWidget);
    });

    testWidgets('validation prevents submit and shows inline error for missing required', (tester) async {
      final spec = FormSpec(
        fields: [
          FormField(
            key: 'req_name',
            kind: const OpenValue.known(FormFieldKind.string),
            title: 'Required Name',
            required: true,
          ),
        ],
      );
      final request = _formRequest(ref, 'val_form', form: spec);

      await open([request]);
      await pump(tester);

      // Submit with empty field
      await tester.tap(find.byKey(const ValueKey('form-submit-val_form')));
      await settleFrames(tester);

      // Required field error is displayed and no reply dispatched
      expect(find.text(V2LocalizationsEn().liveFormRequiredField), findsOneWidget);
      expect(handle.formReplies, isEmpty);

      // Fill in field
      await tester.enterText(find.byKey(const ValueKey('form-field-req_name')), 'John');
      await settleFrames(tester);

      // Tap submit again
      await tester.tap(find.byKey(const ValueKey('form-submit-val_form')));
      await settleFrames(tester);

      expect(handle.formReplies, hasLength(1));
      expect(
        handle.formReplies.single.$2.answers['req_name']?.toJson(),
        'John',
      );
    });

    testWidgets('dismiss dispatches dismissForm (DELETE)', (tester) async {
      final spec = FormSpec(
        fields: [
          FormField(
            key: 'field_1',
            kind: const OpenValue.known(FormFieldKind.string),
          ),
        ],
      );
      final request = _formRequest(ref, 'dismiss_form', form: spec);

      await open([request]);
      await pump(tester);

      await tester.tap(find.byKey(const ValueKey('form-dismiss-dismiss_form')));
      await settleFrames(tester);

      expect(handle.formDismissals, hasLength(1));
      expect(handle.formDismissals.single.$1.value, 'dismiss_form');
    });

    testWidgets('sub-agent form displays child badge', (tester) async {
      final childRef = SessionRef(
        ref.host,
        ref.harness,
        'sub_ses_1',
      );
      final spec = FormSpec(
        fields: [
          FormField(
            key: 'f1',
            kind: const OpenValue.known(FormFieldKind.string),
          ),
        ],
      );
      final request = _formRequest(
        ref,
        'sub_form',
        owner: SessionOwner(childRef, origin: ref),
        form: spec,
      );

      await open([request]);
      await pump(tester);

      expect(find.text(V2LocalizationsEn().livePermissionChildBadge), findsOneWidget);
    });

    testWidgets('resolved-elsewhere automatically removes form card', (tester) async {
      final spec = FormSpec(
        fields: [
          FormField(
            key: 'f1',
            kind: const OpenValue.known(FormFieldKind.string),
          ),
        ],
      );
      final request = _formRequest(ref, 'res_form', form: spec);

      await open([request]);
      await pump(tester);

      expect(find.byKey(const ValueKey('live-form-res_form')), findsOneWidget);

      // Stream removes the interaction
      handle.emit(
        SessionLiveView(
          session: ref,
          phase: SessionLivePhase.live,
          state: liveState(ref, interactions: []),
        ),
      );
      await settleFrames(tester);

      expect(find.byKey(const ValueKey('live-form-res_form')), findsNothing);
    });

    testWidgets('renders choice chips for string field with options and custom field', (tester) async {
      final spec = FormSpec(
        fields: [
          FormField(
            key: 'q_str',
            kind: const OpenValue.known(FormFieldKind.string),
            title: 'Which language?',
            options: const [
              FormOption(value: 'dart', label: 'Dart'),
              FormOption(value: 'rust', label: 'Rust'),
            ],
            acceptsCustom: true,
          ),
        ],
      );
      final request = _formRequest(ref, 'form_options', form: spec);

      await open([request]);
      await pump(tester);

      expect(find.byKey(const ValueKey('form-option-q_str-dart')), findsOneWidget);
      expect(find.byKey(const ValueKey('form-option-q_str-rust')), findsOneWidget);
      expect(find.byKey(const ValueKey('form-field-q_str-custom')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('form-option-q_str-dart')));
      await settleFrames(tester);

      expect(live.formDraft(request.id)['q_str'], 'dart');
    });

    testWidgets('shows validation error for non-numeric input in number field', (tester) async {
      final spec = FormSpec(
        fields: [
          FormField(
            key: 'age',
            kind: const OpenValue.known(FormFieldKind.number),
            title: 'Age',
          ),
        ],
      );
      final request = _formRequest(ref, 'form_num_val', form: spec);

      await open([request]);
      await pump(tester);

      await tester.enterText(
        find.byKey(const ValueKey('form-field-age')),
        'not_a_number',
      );
      await settleFrames(tester);

      await tester.tap(find.byKey(const ValueKey('form-submit-form_num_val')));
      await settleFrames(tester);

      expect(find.text(V2LocalizationsEn().liveFormInvalidNumber), findsOneWidget);
    });
  });
}
