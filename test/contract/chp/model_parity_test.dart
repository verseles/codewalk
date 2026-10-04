@TestOn('vm')
library;

import 'dart:convert';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'model_projection_support.dart';
import 'schema_support.dart';

// Synthetic model/schema parity checks, not native harness or final G2/G5
// evidence. Only identity, ownership and stream use existing core codecs;
// the other JSON views are explicit test-only CHP edge projections.
const _host = HostId('host/%2F/ação ');
const _harnessId = HarnessInstanceId('profile: installation ');
const _harness = HarnessRef(_host, _harnessId);
const _ref = SessionRef(_host, _harnessId, 'native/%2F/会話 ');
const _owner = SessionOwner(_ref);
const _project = ProjectRef(
  _host,
  '/workspace/Case Sensitive/ação ',
  upstreamProjectId: 'annotation-only',
);
const _otherRef = SessionRef(_host, _harnessId, 'another native session');
const _otherHarness = HarnessRef(_host, HarnessInstanceId('another profile'));
final _now = DateTime.utc(2026, 10, 4, 8, 30);

void _expectDefinition(String name, Object? value) {
  final result = validateDefinition(name, value);
  expect(
    result.isValid,
    isTrue,
    reason: 'The real core value must fit the named $name projection: $result',
  );
}

StreamPosition _position(String seq) => StreamPosition(
  id: 'client observation stream ',
  epoch: 'stream epoch/%2F',
  seq: BigInt.parse(seq),
);

SourceProvenance _source({HarnessRef harness = _harness}) => SourceProvenance(
  harness: harness,
  version: 'synthetic-model-parity',
  nativeType: 'synthetic.observation',
  nativeCursor: 'opaque cursor/%2F\n',
  aggregateSeq: BigInt.parse('18446744073709551617'),
  durability: const OpenValue.known(Durability.watermarkOnly),
  extra: CanonicalValue({
    'observed': false,
    'missing': null,
    'ordered': [
      'β',
      0,
      {'future': 'value'},
    ],
  }),
);

SnapshotBoundary _boundary({
  SessionRef ref = _ref,
  String generation = 'hydration-generation',
  String seq = '10',
  int offsetMilliseconds = 0,
}) => SnapshotBoundary(
  owner: SessionOwner(ref),
  hydrationGeneration: generation,
  readStart: _position(seq),
  readStartedAt: _now.add(Duration(milliseconds: offsetMilliseconds)),
  readCompletedAt: _now.add(Duration(milliseconds: offsetMilliseconds + 5)),
  source: _source(harness: ref.harnessRef),
  authority: const OpenValue.known(SnapshotAuthority.authoritative),
);

ItemMeta _itemMeta(String id) => ItemMeta(
  id: ItemId(id),
  turnId: const TurnId('turn/%2F'),
  generation: 'attempt generation 1',
  status: const OpenValue.known(ItemStatus.completed),
  source: _source(),
  ordinal: 0,
);

SessionSnapshot _snapshot() {
  final timelineBoundary = _boundary();
  final pendingBoundary = _boundary(seq: '20', offsetMilliseconds: 2);
  return SessionSnapshot(
    ref: _ref,
    hydrationGeneration: 'hydration-generation',
    info: SnapshotValue(
      value: const SessionInfo(
        ref: _ref,
        title: 'Synthetic parity fixture',
        ownership: OwnershipInfo.unknown(reason: 'no native ownership capture'),
        project: _project,
        lineage: SessionLineage(
          parent: _otherRef,
          fork: ForkLineage(_otherRef, beforeItem: ItemId('fork boundary')),
        ),
      ),
      boundary: timelineBoundary,
    ),
    timeline: SnapshotCollection<TimelineItem>(
      boundary: timelineBoundary,
      complete: false,
      values: [
        AssistantText(
          meta: _itemMeta('assistant text block 0'),
          text: 'Exact visible text\n',
          complete: true,
        ),
        Reasoning(
          meta: _itemMeta('exposed reasoning block 0'),
          text: 'Synthetic exposed reasoning',
          complete: true,
        ),
      ],
    ),
    pending: SnapshotCollection(
      boundary: pendingBoundary,
      values: const [
        PendingInput(
          id: ItemId('pending input'),
          text: 'Queued exact intent\n',
          delivery: OpenValue.known(Delivery.queue),
          commandId: CommandId('pending command'),
        ),
      ],
    ),
    nextHistoryCursor: HistoryCursor('opaque page cursor/%2F'),
    hasMoreHistory: true,
  );
}

ApprovalChoice _choice({
  OpenValue<ApprovalScope> scope = const OpenValue.known(ApprovalScope.once),
  OpenValue<ResolutionScope> resolutionScope = const OpenValue.known(
    ResolutionScope.request,
  ),
}) => ApprovalChoice(
  id: 'native choice once/%2F',
  label: 'Offered allow choice',
  allows: true,
  scope: scope,
  resolutionScope: resolutionScope,
  scopePreview: CanonicalValue({
    'paths': ['opaque/path'],
    'persistent': false,
  }),
);

InteractionRequest _permission({
  ApprovalChoice? choice,
  FormSpec? form,
  DomainOwner owner = _owner,
}) => InteractionRequest(
  id: const InteractionId('permission/%2F'),
  owner: owner,
  kind: const OpenValue.known(InteractionKind.permission),
  title: 'Synthetic offered permission',
  choices: [choice ?? _choice()],
  form: form,
  autoApprovable: true,
);

FormSpec _form() => FormSpec(
  fields: [
    FormField(
      key: 'mode',
      kind: const OpenValue.known(FormFieldKind.multiSelect),
      required: true,
      options: const [
        FormOption(value: 'include,exact', label: 'Comma is native data'),
        FormOption(value: 'β', label: 'Unicode value'),
      ],
    ),
    FormField(
      key: 'details',
      kind: const OpenValue.known(FormFieldKind.string),
      required: true,
      condition: const IncludesCondition('mode', 'include,exact'),
    ),
  ],
);

final class _ReferenceOnlyHandle implements SessionHandle {
  _ReferenceOnlyHandle(this.ref);
  @override
  final SessionRef ref;

  // A create-result reference test never opens a stream or mutates a harness.
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Reference-only synthetic handle');
}

void main() {
  group('existing core codecs fit canonical schema definitions', () {
    test('full identity preserves opaque values and project annotations', () {
      _expectDefinition('CanonicalHarnessRef', _harness.toJson());
      _expectDefinition('CanonicalSessionRef', _ref.toJson());
      _expectDefinition('CanonicalProjectRef', _project.toJson());
      expect(HarnessRef.fromJson(_harness.toJson()), _harness);
      expect(SessionRef.fromJson(_ref.toJson()), _ref);
      final project = ProjectRef.fromJson(_project.toJson());
      expect(project, _project);
      expect(project.upstreamProjectId, 'annotation-only');
      expect(project.canonicalDirectory, '/workspace/Case Sensitive/ação ');
      expect(_ref.nativeId, 'native/%2F/会話 ');
      expect(_ref, isNot(_otherRef));
    });

    test('lineage codecs keep parent and fork independent', () {
      const lineage = SessionLineage(
        parent: _otherRef,
        fork: ForkLineage(_ref, beforeItem: ItemId('fork item')),
      );
      _expectDefinition('CanonicalSessionLineage', lineage.toJson());
      _expectDefinition('CanonicalForkLineage', lineage.fork!.toJson());
      final decoded = SessionLineage.fromJson(lineage.toJson());
      expect(decoded.parent, _otherRef);
      expect(decoded.fork!.source, _ref);
      expect(decoded.fork!.beforeItem, const ItemId('fork item'));
    });

    test('proof codec round trips while freshness stays a semantic check', () {
      final proof = OwnershipProof(
        source: 'synthetic direct observation',
        observedAt: _now,
        expiresAt: _now.add(const Duration(minutes: 1)),
        reference: 'opaque proof reference/%2F',
      );
      final ownership = OwnershipInfo.known(
        OwnershipKind.liveShared,
        proof: proof,
      );
      _expectDefinition('CanonicalOwnershipProof', proof.toJson());
      _expectDefinition('CanonicalOwnershipInfo', ownership.toJson());
      expect(OwnershipProof.fromJson(proof.toJson()), proof);
      expect(OwnershipInfo.fromJson(ownership.toJson()), ownership);
      expect(
        ownership.effectiveKindAt(_now, maxAge: const Duration(seconds: 30)),
        OwnershipKind.liveShared,
      );
      expect(
        ownership.effectiveKindAt(
          _now.add(const Duration(minutes: 1)),
          maxAge: const Duration(minutes: 5),
        ),
        OwnershipKind.unknown,
      );
    });

    test(
      'expanded positive and negative proof years retain exact codec forms',
      () {
        for (final year in [10000, -10000]) {
          final instant = DateTime.utc(year, 10, 4, 8, 30);
          final proof = OwnershipProof(
            source: 'synthetic expanded-year observation',
            observedAt: instant,
            expiresAt: instant.add(const Duration(minutes: 1)),
          );
          final json = proof.toJson();
          _expectDefinition('CanonicalOwnershipProof', json);
          expect(json['observedAt'], instant.toIso8601String());
          expect(OwnershipProof.fromJson(json), proof);
          expect(OwnershipProof.fromJson(json).observedAt.year, year);
        }
      },
    );

    test('unrecognized ownership normalizes to diagnostic unknown', () {
      final ownership = OwnershipInfo.fromJson({
        'version': 1,
        'kind': 'future topology kind',
      });
      _expectDefinition('CanonicalOwnershipInfo', ownership.toJson());
      expect(ownership.kind, OwnershipKind.unknown);
      expect(ownership.rawKind, 'future topology kind');
      expect(ownership.proof, isNull);
      expect(OwnershipInfo.fromJson(ownership.toJson()), ownership);
    });

    test('arbitrary BigInt sequences remain exact beyond JS and uint64', () {
      for (final sequence in [
        '0',
        '9007199254740993',
        '18446744073709551617',
        '999999999999999999999999999999999999999999999999999999',
      ]) {
        final position = _position(sequence);
        final json = position.toJson();
        _expectDefinition('CanonicalStreamPosition', json);
        expect(json['seq'], sequence);
        final decoded = StreamPosition.fromJson(jsonDecode(jsonEncode(json)));
        expect(decoded, position);
        expect(decoded.seq.toString(), sequence);
      }
    });

    test('sequence schema and codec reject noncanonical entire strings', () {
      final baseline = _position('1').toJson();
      for (final value in <Object?>[
        '01',
        '00',
        '+1',
        '-1',
        ' 1',
        '1 ',
        '1\n',
        '1\r',
        '1\r\n',
        '1.0',
        '',
        1,
      ]) {
        final invalid = {...baseline, 'seq': value};
        expect(
          isValidDefinition('CanonicalStreamPosition', invalid),
          isFalse,
          reason: 'Canonical decimal must reject ${jsonEncode(value)}',
        );
        expect(
          () => StreamPosition.fromJson(invalid),
          throwsFormatException,
          reason: 'Codec must reject ${jsonEncode(value)} independently',
        );
      }
    });
  });

  group('test-only projections retain canonical observations', () {
    test('all actual owner scopes preserve their own identity', () {
      final owners = <DomainOwner>[
        const SessionOwner(_ref, origin: _otherRef),
        ProjectOwner(_project, harness: _harness),
        ProjectOwner(_project),
        HostOwner(_host, harness: _harness),
        HostOwner(_host),
        const GlobalOwner(_harness),
        UnknownOwner(
          reason: 'future owner',
          raw: CanonicalValue({
            'future': ['scope', false, null],
          }),
        ),
      ];
      for (final owner in owners) {
        _expectDefinition('CanonicalDomainOwner', projectOwner(owner));
      }
      expect((owners.first as SessionOwner).session, _ref);
      expect((owners.first as SessionOwner).origin, _otherRef);
      expect(owners[2].isKnown, isFalse);
      expect(owners[4].isKnown, isFalse);
      expect(owners.last.isKnown, isFalse);
      expect(projectOwner(owners[5]).containsKey('session'), isFalse);
    });

    test('source watermark is separate from client observation sequence', () {
      final source = _source();
      final meta = EventMeta(
        owner: _owner,
        position: _position('17'),
        receivedAt: _now,
        source: source,
      );
      _expectDefinition('CanonicalSourceProvenance', projectSource(source));
      _expectDefinition('CanonicalEventMeta', projectEventMeta(meta));
      expect(meta.position.seq, BigInt.from(17));
      expect(source.aggregateSeq, BigInt.parse('18446744073709551617'));
      expect(source.durability.known, Durability.watermarkOnly);
      expect(projectSource(source)['aggregateSeq'], '18446744073709551617');
      expect(projectSource(source)['nativeCursor'], 'opaque cursor/%2F\n');
    });

    test(
      'unknown events and items retain nested data without inventing text',
      () {
        final raw = CanonicalValue({
          'future': [
            null,
            false,
            0,
            {'opaque': '会話/%2F\n'},
          ],
        });
        final owner = UnknownOwner(reason: 'unrecognized scope', raw: raw);
        final event = UnknownEvent(
          meta: EventMeta(
            owner: owner,
            position: _position('31'),
            receivedAt: _now,
            source: _source(),
          ),
          rawType: 'future.native.event',
          raw: raw,
        );
        final item = UnknownItem(
          meta: _itemMeta('future item identity'),
          rawType: 'future.native.item',
          raw: raw,
        );
        _expectDefinition('CanonicalSessionEvent', projectUnknownEvent(event));
        _expectDefinition('CanonicalTimelineItem', projectTimelineItem(item));
        expect(projectUnknownEvent(event)['raw'], raw.toJson());
        expect(projectTimelineItem(item)['raw'], raw.toJson());
        expect(projectTimelineItem(item).containsKey('text'), isFalse);
        expect(event.meta.owner.isKnown, isFalse);
        expect(item.fallbackText, isNull);
      },
    );

    test(
      'unknown and unavailable support remain valid unavailable observations',
      () {
        final capabilities = [
          Capability(
            support: OpenValue.unknown('futureSupport'),
            verified: true,
          ),
          Capability(
            support: const OpenValue.known(Support.unknown),
            verified: true,
          ),
          Capability(
            support: const OpenValue.known(Support.unavailable),
            verified: true,
          ),
          Capability(
            support: const OpenValue.known(Support.native),
            verified: false,
          ),
        ];
        for (final capability in capabilities) {
          _expectDefinition(
            'CanonicalCapability',
            projectCapability(capability),
          );
          expect(capability.isAvailable, isFalse);
        }
        expect(capabilities.first.support.toJson(), 'futureSupport');
        expect(capabilities.first.verified, isTrue);
        expect(
          projectCapability(capabilities.first).containsKey('isAvailable'),
          isFalse,
        );
      },
    );
  });

  group('snapshot shape and separately named constructor semantics', () {
    test('meaningful non-atomic reads preserve independent boundaries', () {
      final snapshot = _snapshot();
      _expectDefinition('CanonicalSessionSnapshot', projectSnapshot(snapshot));
      _expectDefinition(
        'CanonicalTimelineSnapshotCollection',
        projectTimelineCollection(snapshot.timeline!),
      );
      _expectDefinition(
        'CanonicalPendingSnapshotCollection',
        projectPendingCollection(snapshot.pending!),
      );
      _expectDefinition(
        'CanonicalSnapshotBoundary',
        projectBoundary(snapshot.timeline!.boundary),
      );
      expect(snapshot.timeline!.boundary.readStart.seq, BigInt.from(10));
      expect(snapshot.pending!.boundary.readStart.seq, BigInt.from(20));
      expect(
        snapshot.pending!.boundary.readStartedAt,
        snapshot.timeline!.boundary.readStartedAt.add(
          const Duration(milliseconds: 2),
        ),
      );
      expect(snapshot.timeline!.values, hasLength(2));
      expect(snapshot.timeline!.complete, isFalse);
      expect(snapshot.pending!.values.single.text, 'Queued exact intent\n');
      final first = snapshot.timeline!.values[0];
      final second = snapshot.timeline!.values[1];
      expect(first.meta.ordinal, 0);
      expect(second.meta.ordinal, 0);
      expect(first.id, isNot(second.id));
      expect(snapshot.nextHistoryCursor!.value, 'opaque page cursor/%2F');
    });

    test(
      'semantic owner mismatch is rejected despite a valid boundary shape',
      () {
        final wrong = _boundary(ref: _otherRef);
        _expectDefinition('CanonicalSnapshotBoundary', projectBoundary(wrong));
        _expectDefinition('CanonicalSessionSnapshot', {
          ...projectSnapshot(_snapshot()),
          'pending': {
            'values': <Object?>[],
            'boundary': projectBoundary(wrong),
            'complete': true,
          },
        });
        expect(
          () => SessionSnapshot(
            ref: _ref,
            hydrationGeneration: 'hydration-generation',
            pending: SnapshotCollection<PendingInput>(
              values: const [],
              boundary: wrong,
            ),
          ),
          throwsArgumentError,
        );
      },
    );

    test('semantic generation mismatch is rejected despite valid shape', () {
      final wrong = _boundary(generation: 'another hydration');
      _expectDefinition('CanonicalSnapshotBoundary', projectBoundary(wrong));
      _expectDefinition('CanonicalSessionSnapshot', {
        ...projectSnapshot(_snapshot()),
        'pending': {
          'values': <Object?>[],
          'boundary': projectBoundary(wrong),
          'complete': true,
        },
      });
      expect(
        () => SessionSnapshot(
          ref: _ref,
          hydrationGeneration: 'hydration-generation',
          pending: SnapshotCollection<PendingInput>(
            values: const [],
            boundary: wrong,
          ),
        ),
        throwsArgumentError,
      );
    });

    test('semantic source mismatch is rejected independently of shape', () {
      final source = _source(harness: _otherHarness);
      final json = {
        ...projectBoundary(_boundary()),
        'source': projectSource(source),
      };
      _expectDefinition('CanonicalSnapshotBoundary', json);
      expect(
        () => SnapshotBoundary(
          owner: _owner,
          hydrationGeneration: 'hydration-generation',
          readStart: _position('10'),
          readStartedAt: _now,
          source: source,
        ),
        throwsArgumentError,
      );
      final metaJson = {
        'owner': projectOwner(_owner),
        'position': _position('10').toJson(),
        'receivedAt': _now.toIso8601String(),
        'source': projectSource(source),
      };
      _expectDefinition('CanonicalEventMeta', metaJson);
      expect(
        () => EventMeta(
          owner: _owner,
          position: _position('10'),
          receivedAt: _now,
          source: source,
        ),
        throwsArgumentError,
      );
    });

    test(
      'semantic completion before start is rejected independently of shape',
      () {
        final earlier = _now.subtract(const Duration(milliseconds: 1));
        final json = {
          ...projectBoundary(_boundary()),
          'readCompletedAt': earlier.toIso8601String(),
        };
        _expectDefinition('CanonicalSnapshotBoundary', json);
        expect(
          () => SnapshotBoundary(
            owner: _owner,
            hydrationGeneration: 'hydration-generation',
            readStart: _position('10'),
            readStartedAt: _now,
            readCompletedAt: earlier,
          ),
          throwsArgumentError,
        );
      },
    );

    test(
      'semantic info identity mismatch is rejected independently of shape',
      () {
        const info = SessionInfo(
          ref: _otherRef,
          title: 'Wrong session identity',
          ownership: OwnershipInfo.unknown(reason: 'no proof'),
        );
        final json = {
          'value': projectInfo(info),
          'boundary': projectBoundary(_boundary()),
        };
        _expectDefinition('CanonicalInfoSnapshotValue', json);
        _expectDefinition('CanonicalSessionSnapshot', {
          ...projectSnapshot(_snapshot()),
          'info': json,
        });
        expect(
          () => SessionSnapshot(
            ref: _ref,
            hydrationGeneration: 'hydration-generation',
            info: SnapshotValue(value: info, boundary: _boundary()),
          ),
          throwsArgumentError,
        );
      },
    );
  });

  group('receipt shape never upgrades uncertain admission', () {
    test(
      'accepted, uncertain and both duplicates preserve model knowledge',
      () {
        const id = CommandId('mutation original intent');
        final accepted = CommandReceipt.accepted(
          id: id,
          owner: _owner,
          nativeRef: 'native admission ref',
        );
        final uncertain = CommandReceipt.uncertain(
          id: id,
          owner: _owner,
          reason: 'response lost after write',
        );
        final duplicateAccepted = CommandReceipt.duplicate(
          id: id,
          owner: _owner,
          original: accepted,
        );
        final duplicateUncertain = CommandReceipt.duplicate(
          id: id,
          owner: _owner,
          original: uncertain,
        );
        for (final receipt in [
          accepted,
          uncertain,
          duplicateAccepted,
          duplicateUncertain,
        ]) {
          _expectDefinition('CanonicalCommandReceipt', projectReceipt(receipt));
        }
        expect(duplicateAccepted.admissionKnown, isTrue);
        expect(duplicateAccepted.nativeRef, accepted.nativeRef);
        expect(duplicateUncertain.state.known, ReceiptState.duplicate);
        expect(duplicateUncertain.admissionKnown, isFalse);
        expect(duplicateUncertain.reason, uncertain.reason);
        expect(duplicateUncertain.nativeRef, isNull);
      },
    );

    test('rejected, unavailable and unknown receipts remain nonadmissions', () {
      const id = CommandId('command');
      final receipts = [
        CommandReceipt.rejected(
          id: id,
          owner: _owner,
          error: ErrorInfo(
            kind: const OpenValue.known(ErrorKind.permissionRejected),
            rawType: 'synthetic rejection',
            rawMessage: 'Original error text',
          ),
        ),
        CommandReceipt.unavailable(
          id: id,
          owner: _owner,
          unavailable: CapabilityUnavailable('undo', reason: 'not implemented'),
        ),
        CommandReceipt.unknown(
          id: id,
          owner: _owner,
          rawState: 'future receipt state',
          details: CanonicalValue({'future': false}),
        ),
      ];
      for (final receipt in receipts) {
        _expectDefinition('CanonicalCommandReceipt', projectReceipt(receipt));
        expect(receipt.admissionKnown, isFalse);
        expect(receipt.nativeRef, isNull);
      }
      expect(receipts.last.state.toJson(), 'future receipt state');
      expect(receipts.last.reason, 'unknownReceipt');
    });

    test(
      'rejected nullable error allows both omitted and explicit null views',
      () {
        final receipt = CommandReceipt.rejected(
          id: const CommandId('rejected without structured error'),
          owner: _owner,
          error: null,
        );
        final projection = projectReceipt(receipt);
        _expectDefinition('CanonicalCommandReceipt', projection);
        expect(receipt.state.known, ReceiptState.rejected);
        expect(receipt.admissionKnown, isFalse);
        expect(receipt.error, isNull);
        expect(projection.containsKey('error'), isFalse);
        _expectDefinition('CanonicalCommandReceipt', {
          ...projection,
          'error': null,
        });
      },
    );

    test(
      'uncertain and duplicate-uncertain create refuse fabricated handles',
      () {
        final uncertain = CommandReceipt.uncertain(
          id: const CommandId('create'),
          owner: ProjectOwner(_project, harness: _harness),
          reason: 'admission response unavailable',
        );
        final duplicate = CommandReceipt.duplicate(
          id: uncertain.id,
          owner: uncertain.owner,
          original: uncertain,
        );
        for (final receipt in [uncertain, duplicate]) {
          final result = CreateResult(receipt: receipt);
          _expectDefinition(
            'CanonicalCreateResult',
            projectCreateResult(result),
          );
          expect(result.handle, isNull);
          expect(projectCreateResult(result).containsKey('handleRef'), isFalse);
          expect(
            isValidDefinition('CanonicalCreateResult', {
              ...projectCreateResult(result),
              'handleRef': _ref.toJson(),
            }),
            isFalse,
          );
          expect(
            () => CreateResult(
              receipt: receipt,
              handle: _ReferenceOnlyHandle(_ref),
            ),
            throwsArgumentError,
          );
        }
      },
    );

    test(
      'accepted create handle must retain exact installation and native ID',
      () {
        final receipt = CommandReceipt.accepted(
          id: const CommandId('create'),
          owner: ProjectOwner(_project, harness: _harness),
          nativeRef: _ref.nativeId,
        );
        final result = CreateResult(
          receipt: receipt,
          handle: _ReferenceOnlyHandle(_ref),
        );
        _expectDefinition('CanonicalCreateResult', projectCreateResult(result));
        expect(result.handle!.ref, _ref);
        for (final wrong in [
          _otherRef,
          SessionRef(_host, _otherHarness.harness, _ref.nativeId),
        ]) {
          expect(
            () => CreateResult(
              receipt: receipt,
              handle: _ReferenceOnlyHandle(wrong),
            ),
            throwsArgumentError,
          );
        }
      },
    );
  });

  group(
    'schema-valid interaction observations still require domain policy',
    () {
      test(
        'only supplied once/request permission can be automatically eligible',
        () {
          final request = _permission();
          _expectDefinition(
            'CanonicalInteractionRequest',
            projectInteraction(request),
          );
          expect(request.automaticChoice, same(request.choices.single));
          expect(
            request.validateResponse(
              ApprovalResponse(request.choices.single.id),
            ),
            isEmpty,
          );
          expect(
            request.validateResponse(ApprovalResponse('invented allow choice')),
            [InteractionResponseIssue.choiceNotOffered],
          );
        },
      );

      test(
        'persistent, unknown scopes and forms are not automatic authorization',
        () {
          final unknown = _permission(
            choice: _choice(scope: OpenValue.unknown('futureApprovalScope')),
          );
          final requests = [
            _permission(
              choice: _choice(
                scope: const OpenValue.known(ApprovalScope.persistentProject),
              ),
            ),
            _permission(
              choice: _choice(
                resolutionScope: const OpenValue.known(ResolutionScope.session),
              ),
            ),
            unknown,
            _permission(form: _form()),
            _permission(owner: const GlobalOwner(_harness)),
          ];
          for (final request in requests) {
            _expectDefinition(
              'CanonicalInteractionRequest',
              projectInteraction(request),
            );
            expect(request.autoApprovable, isTrue);
            expect(request.automaticChoice, isNull);
          }
          expect(
            unknown.validateResponse(
              ApprovalResponse(unknown.choices.single.id),
            ),
            [InteractionResponseIssue.unknownChoiceScope],
          );
        },
      );

      test(
        'multi-select values remain exact and conditional answers are required',
        () {
          final form = _form();
          final answers = FormAnswers({
            'mode': MultiSelectAnswer(['include,exact', 'β']),
            'details': const StringAnswer('Original supplied content\n'),
          });
          _expectDefinition('CanonicalFormSpec', projectForm(form));
          _expectDefinition('CanonicalFormAnswers', answers.toJson());
          expect(answers.toJson()['mode'], ['include,exact', 'β']);
          expect(form.validate(answers), isEmpty);
          final missingDetails = FormAnswers({
            'mode': MultiSelectAnswer(['include,exact']),
          });
          _expectDefinition('CanonicalFormAnswers', missingDetails.toJson());
          final issues = form.validate(missingDetails);
          expect(issues, hasLength(1));
          expect(issues.single.key, 'details');
          expect(issues.single.kind, FormValidationKind.missingRequired);
        },
      );

      test(
        'unanswered conditions are false and missing references reject specs',
        () {
          final notEquals = NotEqualsCondition('mode', 'disabled');
          const includes = IncludesCondition('mode', 'include,exact');
          final empty = FormAnswers({});
          _expectDefinition(
            'CanonicalFormCondition',
            projectFormCondition(notEquals),
          );
          _expectDefinition(
            'CanonicalFormCondition',
            projectFormCondition(includes),
          );
          expect(notEquals.evaluate(empty), isFalse);
          expect(includes.evaluate(empty), isFalse);
          final field = FormField(
            key: 'details',
            kind: const OpenValue.known(FormFieldKind.string),
            condition: notEquals,
          );
          expect(
            () => FormSpec(fields: [field]),
            throwsArgumentError,
            reason:
                'Condition references must point to an earlier actual field',
          );
        },
      );

      test(
        'future fields and conditions remain observations but cannot submit',
        () {
          final unknownCondition = UnknownCondition(
            rawType: 'future condition',
            raw: CanonicalValue({'rule': false}),
          );
          final form = FormSpec(
            fields: [
              FormField(
                key: 'future field',
                kind: OpenValue.unknown('futureField'),
              ),
              FormField(
                key: 'conditional',
                kind: const OpenValue.known(FormFieldKind.string),
                condition: unknownCondition,
              ),
            ],
          );
          _expectDefinition('CanonicalFormSpec', projectForm(form));
          expect(unknownCondition.evaluate(FormAnswers({})), isFalse);
          final issues = form.validate(FormAnswers({}));
          expect(issues.map((issue) => issue.kind), [
            FormValidationKind.unknownField,
            FormValidationKind.unknownCondition,
          ]);
        },
      );
    },
  );
}
