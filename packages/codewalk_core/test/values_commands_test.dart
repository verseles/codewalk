import 'package:codewalk_core/codewalk_core.dart';
import 'package:test/test.dart';

// Synthetic canonical domain cases, not native captures or a G1/G2 pass.
const host = HostId('host');
const harness = HarnessRef(host, HarnessInstanceId('installation'));
const session = SessionRef(
  host,
  HarnessInstanceId('installation'),
  'same-native-id',
);
const owner = SessionOwner(session);
final now = DateTime.utc(2026, 10, 4);

OriginalCommand command({
  DomainOwner scope = owner,
  HarnessRef ref = harness,
  String version = 'test-version',
  CommandId id = const CommandId('command'),
  OpenValue<MutationOperation> operation = const OpenValue.known(
    MutationOperation.prompt,
  ),
  Object? intent = const {'text': 'original'},
}) => OriginalCommand(
  id: id,
  harness: ref,
  owner: scope,
  operation: operation,
  connectedVersion: version,
  intent: CanonicalValue(intent),
);

OperationContract contract({
  HarnessRef ref = harness,
  String version = 'test-version',
  OpenValue<OperationPhase> phase = const OpenValue.known(
    OperationPhase.pending,
  ),
  ReplayPolicy policy = ReplayPolicy.verifiedUnresolvedAdmission,
  OpenValue<MutationOperation> operation = const OpenValue.known(
    MutationOperation.prompt,
  ),
}) => OperationContract(
  harness: ref,
  operation: operation,
  connectedVersion: version,
  phase: phase,
  replay: policy,
  evidence: policy == ReplayPolicy.reconcileOnly
      ? null
      : 'synthetic-operation-evidence',
);

ReplayDecision evaluate(
  OperationContract policy, {
  OriginalCommand? original,
  OriginalCommand? candidate,
  String persisted = 'exact original bytes',
  String payload = 'exact original bytes',
  AdmissionKnowledge admission = AdmissionKnowledge.unresolved,
  OpenValue<OperationPhase> phase = const OpenValue.known(
    OperationPhase.pending,
  ),
  OpenValue<CancellationFence> fence = const OpenValue.known(
    CancellationFence.none,
  ),
  bool reconciled = true,
}) => policy.evaluate(
  original: original ?? command(),
  candidate: candidate ?? command(),
  persistedOriginalPayload: persisted,
  candidatePayload: payload,
  admission: admission,
  currentPhase: phase,
  cancellation: fence,
  reconciled: reconciled,
);

CapabilityContext context({
  DomainOwner scope = owner,
  OwnershipInfo? ownership,
  bool? negotiated = true,
  bool? model = true,
  bool? policy = true,
  bool? platform = true,
  bool? state = true,
  OwnershipProof? authority,
}) => CapabilityContext(
  owner: scope,
  connectedVersion: 'test-version',
  evidence: ScopedCapabilityEvidence(
    owner: scope,
    connectedVersion: 'test-version',
    ownership:
        ownership ??
        OwnershipInfo.known(
          OwnershipKind.liveShared,
          proof: OwnershipProof(source: 'synthetic', observedAt: now),
        ),
    authorityProof: authority,
  ),
  now: now,
  maxProofAge: const Duration(minutes: 2),
  negotiated: negotiated,
  modelAllowed: model,
  policyAllowed: policy,
  platformAllowed: platform,
  stateAllowed: state,
);

void main() {
  group('canonical values and scope isolation', () {
    test('unknown enum strings remain exact and typed', () {
      final future = OpenValue.parse(' future/support ', Support.values);
      expect(future.known, isNull);
      expect(future.value, ' future/support ');
      expect(future.toJson(), ' future/support ');
      expect(OpenValue.parse(future.toJson(), Support.values), future);
      expect(() => OpenValue<Support>.unknown(''), throwsArgumentError);
    });
    test(
      'data is recursively copied and unmodifiable, with structural equality',
      () {
        final nested = <String, Object?>{
          'a': <Object?>[
            1,
            {'z': null},
          ],
        };
        final data = CanonicalValue(nested);
        (nested['a'] as List).add('changed');
        nested['new'] = true;
        expect(
          data,
          CanonicalValue({
            'a': [
              1,
              {'z': null},
            ],
          }),
        );
        expect(
          data.hashCode,
          CanonicalValue({
            'a': [
              1,
              {'z': null},
            ],
          }).hashCode,
        );
        final map = data.value as Map;
        expect(() => map['new'] = true, throwsUnsupportedError);
        expect(() => (map['a'] as List).add(false), throwsUnsupportedError);
        expect(CanonicalValue({'a': null}), isNot(CanonicalValue({})));
      },
    );
    test('cycles, nonfinite numbers and non-JSON values fail at runtime', () {
      final cycle = <Object?>[];
      cycle.add(cycle);
      expect(() => CanonicalValue(cycle), throwsArgumentError);
      expect(() => CanonicalValue(double.infinity), throwsArgumentError);
      expect(() => CanonicalValue({1: 'bad'}), throwsArgumentError);
      expect(() => CanonicalValue(DateTime.utc(2026)), throwsArgumentError);
      final shared = <Object?>['valid'];
      expect(CanonicalValue([shared, shared]).value, [
        ['valid'],
        ['valid'],
      ]);
    });
    test(
      'project identity remains stable while owner scope isolates harnesses',
      () {
        const project = ProjectRef(host, '/same');
        const other = HarnessRef(host, HarnessInstanceId('other'));
        final a = ProjectOwner(project, harness: harness);
        final b = ProjectOwner(project, harness: other);
        expect(a.hasSameScope(b), isFalse);
        expect(ProjectOwner(project).isKnown, isFalse);
        expect(HostOwner(host).isKnown, isFalse);
        expect(
          GlobalOwner(harness).hasSameScope(const GlobalOwner(other)),
          isFalse,
        );
        expect(
          () => ProjectOwner(
            project,
            harness: const HarnessRef(
              HostId('elsewhere'),
              HarnessInstanceId('installation'),
            ),
          ),
          throwsArgumentError,
        );
        expect(
          () => HostOwner(
            host,
            harness: const HarnessRef(
              HostId('elsewhere'),
              HarnessInstanceId('installation'),
            ),
          ),
          throwsArgumentError,
        );
        expect(
          const SessionOwner(
            session,
            origin: SessionRef(
              host,
              HarnessInstanceId('installation'),
              'child',
            ),
          ).hasSameScope(owner),
          isTrue,
        );
        expect(
          UnknownOwner(
            reason: 'unresolved',
          ).hasSameScope(UnknownOwner(reason: 'unresolved')),
          isFalse,
        );
      },
    );
    test(
      'diagnostic references require explicit redaction and bounded size',
      () {
        expect(
          DiagnosticRef(
            id: 'capture',
            byteLength: 4,
            redacted: true,
          ).byteLength,
          4,
        );
        expect(
          () => DiagnosticRef(id: 'capture', byteLength: 4, redacted: false),
          throwsArgumentError,
        );
        expect(
          () => DiagnosticRef(id: 'capture', byteLength: 65537, redacted: true),
          throwsArgumentError,
        );
      },
    );
  });

  group('operation-specific admission replay', () {
    test(
      'default reconciles, demonstrated exact unresolved admission can replay',
      () {
        expect(
          evaluate(contract(policy: ReplayPolicy.reconcileOnly)).allowed,
          isFalse,
        );
        expect(evaluate(contract()).allowed, isTrue);
        expect(evaluate(contract(), reconciled: false).allowed, isFalse);
        expect(
          () => OperationContract(
            harness: harness,
            operation: const OpenValue.known(MutationOperation.prompt),
            connectedVersion: 'test',
            phase: const OpenValue.known(OperationPhase.pending),
            replay: ReplayPolicy.verifiedUnresolvedAdmission,
          ),
          throwsArgumentError,
        );
      },
    );
    test(
      'original identity, scope, payload, operation, version and phase must match',
      () {
        final policy = contract();
        for (final candidate in [
          command(id: const CommandId('other')),
          command(
            scope: const SessionOwner(
              SessionRef(
                host,
                HarnessInstanceId('installation'),
                'other-session',
              ),
            ),
          ),
          command(intent: {'text': 'changed'}),
          command(version: 'later'),
          command(operation: const OpenValue.known(MutationOperation.create)),
        ]) {
          expect(evaluate(policy, candidate: candidate).allowed, isFalse);
        }
        expect(evaluate(policy, payload: 'changed bytes').allowed, isFalse);
        expect(evaluate(policy, persisted: '', payload: '').allowed, isFalse);
        expect(
          evaluate(
            policy,
            phase: const OpenValue.known(OperationPhase.promoted),
          ).allowed,
          isFalse,
        );
      },
    );
    test('proof for one installation cannot authorize another', () {
      const otherRef = HarnessRef(host, HarnessInstanceId('other'));
      const otherOwner = SessionOwner(
        SessionRef(host, HarnessInstanceId('other'), 'same-native-id'),
      );
      final otherCommand = command(ref: otherRef, scope: otherOwner);
      expect(
        evaluate(
          contract(),
          original: otherCommand,
          candidate: otherCommand,
        ).allowed,
        isFalse,
      );
      expect(() => command(scope: otherOwner), throwsArgumentError);
    });
    test('all known or unknown cancellation fences suspend original retry', () {
      for (final fence in CancellationFence.values.where(
        (v) => v != CancellationFence.none,
      )) {
        expect(
          evaluate(contract(), fence: OpenValue.known(fence)).allowed,
          isFalse,
        );
      }
      expect(
        evaluate(contract(), fence: OpenValue.unknown('future-fence')).allowed,
        isFalse,
      );
    });
    test(
      'admitted execution uncertainty, cancellation and settlement never resend',
      () {
        for (final admission in AdmissionKnowledge.values.where(
          (v) => v != AdmissionKnowledge.unresolved,
        )) {
          expect(evaluate(contract(), admission: admission).allowed, isFalse);
        }
      for (final phase in [
        OperationPhase.promoted,
        OperationPhase.cancelled,
          OperationPhase.settled,
          OperationPhase.unknown,
        ]) {
          expect(
            evaluate(
              contract(phase: OpenValue.known(phase)),
              phase: OpenValue.known(phase),
            ).allowed,
            isFalse,
          );
        }
        expect(
          evaluate(
            contract(operation: OpenValue.unknown('future-op')),
            original: command(operation: OpenValue.unknown('future-op')),
            candidate: command(operation: OpenValue.unknown('future-op')),
          ).allowed,
          isFalse,
        );
      },
    );
    test('a retryable error confers no replay permission', () {
      final error = ErrorInfo(
        kind: const OpenValue.known(ErrorKind.network),
        rawType: 'network',
        rawMessage: 'lost response',
        retryable: true,
      );
      final receipt = CommandReceipt.uncertain(
        id: const CommandId('command'),
        owner: owner,
        reason: 'lost',
        error: error,
      );
      expect(receipt.admissionKnown, isFalse);
      expect(error.retryable, isTrue);
      expect(
        evaluate(contract(policy: ReplayPolicy.reconcileOnly)).allowed,
        isFalse,
      );
    });
    test(
      'original intent and receipts remain scoped; duplicate does not resolve uncertainty',
      () {
        final intent = <String, Object?>{'text': 'original'};
        final original = command(intent: intent);
        intent['text'] = 'edited';
        expect(original.intent.value, {'text': 'original'});
        final uncertain = CommandReceipt.uncertain(
          id: original.id,
          owner: owner,
          reason: 'lost',
        );
        expect(
          CommandReceipt.duplicate(
            id: original.id,
            owner: owner,
            original: uncertain,
          ).admissionKnown,
          isFalse,
        );
        expect(
          () => CommandReceipt.duplicate(
            id: const CommandId('other'),
            owner: owner,
            original: uncertain,
          ),
          throwsArgumentError,
        );
        expect(
          CommandReceipt.unknown(
            id: original.id,
            owner: owner,
            rawState: 'new-state',
          ).state.value,
          'new-state',
        );
      },
    );
  });

  group('capability denial precedes invocation', () {
    final capabilities = CapabilitySet(
      {
        'input.queue': Capability(
          support: const OpenValue.known(Support.native),
          verified: true,
        ),
      },
      harness: harness,
      connectedVersion: 'test-version',
    );
    test(
      'all required restrictions must be known and authority fresh',
      () async {
        var calls = 0;
        Future<int> mutate() async => ++calls;
        for (final denied in [
          context(scope: UnknownOwner(reason: 'unknown')),
          context(negotiated: null),
          context(model: null),
          context(policy: false),
          context(platform: null),
          context(state: false),
          context(ownership: const OwnershipInfo.unknown(reason: 'unknown')),
          context(
            ownership: OwnershipInfo.known(
              OwnershipKind.liveShared,
              proof: OwnershipProof(
                source: 'stale',
                observedAt: now.subtract(const Duration(hours: 1)),
              ),
            ),
          ),
        ]) {
          expect(
            () => capabilities.invoke(
              'input.queue',
              context: denied,
              mutation: mutate,
            ),
            throwsA(isA<CapabilityUnavailable>()),
          );
        }
        expect(calls, 0);
        expect(
          await capabilities.invoke(
            'input.queue',
            context: context(),
            mutation: mutate,
          ),
          1,
        );
        expect(calls, 1);
      },
    );
    test(
      'missing/unknown/unverified support cannot invoke native mutation',
      () {
        var calls = 0;
        for (final capability in [
          Capability(support: OpenValue.unknown('future'), verified: true),
          Capability(support: const OpenValue.known(Support.native)),
          Capability(
            support: const OpenValue.known(Support.unavailable),
            verified: true,
          ),
        ]) {
          expect(
            () => CapabilitySet(
              {'op': capability},
              harness: harness,
              connectedVersion: 'test-version',
            ).invoke('op', context: context(), mutation: () async => ++calls),
            throwsA(isA<CapabilityUnavailable>()),
          );
        }
        expect(
          () => capabilities.invoke(
            'absent',
            context: context(),
            mutation: () async => ++calls,
          ),
          throwsA(isA<CapabilityUnavailable>()),
        );
        expect(calls, 0);
      },
    );
    test('non-session scope needs real harness and fresh authority proof', () {
      final project = ProjectOwner(
        const ProjectRef(host, '/same'),
        harness: harness,
      );
      expect(
        () => capabilities.requireAvailable(
          'input.queue',
          context: context(scope: project),
        ),
        throwsA(isA<CapabilityUnavailable>()),
      );
      capabilities.requireAvailable(
        'input.queue',
        context: context(
          scope: project,
          authority: OwnershipProof(source: 'authority', observedAt: now),
        ),
      );
    });
    test(
      'capabilities and evidence cannot move across owner, installation or version',
      () {
        const otherRef = HarnessRef(host, HarnessInstanceId('other'));
        const otherOwner = SessionOwner(
          SessionRef(host, HarnessInstanceId('other'), 'same-native-id'),
        );
        expect(
          () => capabilities.requireAvailable(
            'input.queue',
            context: context(scope: otherOwner),
          ),
          throwsA(isA<CapabilityUnavailable>()),
        );
        final evidence = ScopedCapabilityEvidence(
          owner: owner,
          connectedVersion: 'test-version',
          ownership: OwnershipInfo.known(
            OwnershipKind.liveShared,
            proof: OwnershipProof(source: 'proof', observedAt: now),
          ),
        );
        for (final scope in [
          const SessionOwner(
            SessionRef(
              host,
              HarnessInstanceId('installation'),
              'different-session',
            ),
          ),
          otherOwner,
        ]) {
          final moved = CapabilityContext(
            owner: scope,
            connectedVersion: 'test-version',
            evidence: evidence,
            now: now,
            maxProofAge: const Duration(minutes: 2),
            negotiated: true,
            modelAllowed: true,
            policyAllowed: true,
            platformAllowed: true,
            stateAllowed: true,
          );
          expect(
            () => capabilities.requireAvailable('input.queue', context: moved),
            throwsA(isA<CapabilityUnavailable>()),
          );
        }
        final changedVersion = CapabilityContext(
          owner: owner,
          connectedVersion: 'later',
          evidence: evidence,
          now: now,
          maxProofAge: const Duration(minutes: 2),
          negotiated: true,
          modelAllowed: true,
          policyAllowed: true,
          platformAllowed: true,
          stateAllowed: true,
        );
        expect(
          () => capabilities.requireAvailable(
            'input.queue',
            context: changedVersion,
          ),
          throwsA(isA<CapabilityUnavailable>()),
        );
        expect(otherRef, isNot(harness));
      },
    );
    test(
      'saved history can be read with verified scope, but not mutate via read context',
      () {
        final history = CapabilitySet(
          {
            'history.read': Capability(
              support: const OpenValue.known(Support.native),
              verified: true,
            ),
          },
          harness: harness,
          connectedVersion: 'test-version',
        );
        final evidence = ScopedCapabilityEvidence(
          owner: owner,
          connectedVersion: 'test-version',
          ownership: OwnershipInfo.known(
            OwnershipKind.savedHistory,
            proof: OwnershipProof(source: 'history', observedAt: now),
          ),
        );
        final read = CapabilityContext(
          owner: owner,
          connectedVersion: 'test-version',
          evidence: evidence,
          now: now,
          maxProofAge: const Duration(minutes: 2),
          mutating: false,
          negotiated: true,
          modelAllowed: true,
          policyAllowed: true,
          platformAllowed: true,
          stateAllowed: true,
        );
        history.requireAvailable('history.read', context: read);
        var calls = 0;
        expect(
          () => history.invoke(
            'history.read',
            context: read,
            mutation: () async => ++calls,
          ),
          throwsA(isA<CapabilityUnavailable>()),
        );
        expect(calls, 0);
      },
    );
    test('capability constraints are recursively immutable', () {
      final constraints = <String, Object?>{
        'mimes': <String>['image/png'],
      };
      final capability = Capability(
        support: const OpenValue.known(Support.native),
        constraints: constraints,
      );
      (constraints['mimes'] as List).add('application/pdf');
      expect(capability.constraints.value, {
        'mimes': ['image/png'],
      });
    });
  });
}
