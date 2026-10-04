import 'package:codewalk_core/src/errors.dart';
import 'package:codewalk_core/src/identity.dart';
import 'package:codewalk_core/src/lifecycle.dart';
import 'package:codewalk_core/src/usage.dart';
import 'package:codewalk_core/src/values.dart';
import 'package:codewalk_core/src/work.dart';
import 'package:test/test.dart';

const _host = HostId('host');
const _harness = HarnessInstanceId('installation');
const _harnessRef = HarnessRef(_host, _harness);
const _parent = SessionRef(_host, _harness, 'parent');
const _child = SessionRef(_host, _harness, 'child');
const _sessionOwner = SessionOwner(_parent);
const _scope = OpenValue.known(UsageScope.session);
const _source = OpenValue.known(UsageSource.native);
final _observedAt = DateTime.utc(2026, 10, 4, 8);

UsageObservation _usage({
  String id = 'observation',
  DomainOwner owner = _sessionOwner,
  OpenValue<UsageScope> scope = _scope,
  OpenValue<UsageSource> source = _source,
  String? aggregationKey = 'native-series',
  SourceProvenance? provenance,
  bool cumulative = false,
  Cost? cost,
}) => UsageObservation(
  id: id,
  owner: owner,
  scope: scope,
  source: source,
  observedAt: _observedAt,
  aggregationKey: aggregationKey,
  provenance: provenance,
  cumulative: cumulative,
  cost: cost,
);

SourceProvenance _provenance({
  HarnessRef harness = _harnessRef,
  String version = '2.0.22',
}) => SourceProvenance(
  harness: harness,
  version: version,
  nativeType: 'usage.observed',
);

void main() {
  group('work and structured plans', () {
    test('parent notice, child execution and parent idle are independent', () {
      final notice = WorkItem(
        id: const WorkId('background-job'),
        owner: const SessionOwner(_parent),
        parent: _parent,
        child: _child,
        status: const OpenValue.known(WorkStatus.cancelled),
        completionScope: const OpenValue.known(CompletionScope.notice),
        source: SourceProvenance(
          harness: _harnessRef,
          version: '2.0.22',
          nativeType: 'session.message.enqueued',
          aggregateId: _parent.nativeId,
        ),
      );
      const childWork = WorkItem(
        id: WorkId('background-job'),
        owner: SessionOwner(_child),
        parent: _parent,
        child: _child,
        status: OpenValue.known(WorkStatus.running),
        completionScope: OpenValue.known(CompletionScope.work),
      );
      const parentExecution = ExecutionState(
        kind: OpenValue.known(ExecutionKind.idle),
      );
      const childExecution = ExecutionState(
        kind: OpenValue.known(ExecutionKind.interrupting),
      );

      expect(notice.owner.hasSameScope(childWork.owner), isFalse);
      expect(notice.completionScope.known, CompletionScope.notice);
      expect(childWork.status.known, WorkStatus.running);
      expect(childExecution.lastOutcome, isNull);
      expect(parentExecution.kind.known, ExecutionKind.idle);
      expect(notice.source!.aggregateId, _parent.nativeId);
    });

    test('unrecognized work and plan values retain their original meaning', () {
      final work = WorkItem(
        id: const WorkId('job'),
        owner: const SessionOwner(_child),
        status: OpenValue.parse('pausing-for-peer', WorkStatus.values),
        completionScope: OpenValue.parse(
          'remote-group',
          CompletionScope.values,
        ),
        error: ErrorInfo(
          kind: OpenValue.unknown('native-new-error'),
          rawType: 'PeerError',
          rawMessage: 'Waiting on a different owner',
        ),
      );
      final entry = PlanEntry(
        id: 'native-key',
        title: 'Native title',
        status: OpenValue.parse('blocked-on-review', PlanStatus.values),
      );

      expect(work.status.known, isNull);
      expect(work.status.value, 'pausing-for-peer');
      expect(work.completionScope.value, 'remote-group');
      expect(work.error!.kind.value, 'native-new-error');
      expect(entry.status.known, isNull);
      expect(entry.status.toJson(), 'blocked-on-review');
    });

    test('plan entries and structured metadata survive producer mutation', () {
      final metadata = <String, Object?>{
        'dependsOn': <Object?>['native-step-1'],
      };
      final entry = PlanEntry(
        id: 'native-step-2',
        title: 'Work after dependency',
        status: const OpenValue.known(PlanStatus.pending),
        metadata: CanonicalValue(metadata),
      );
      final entries = <PlanEntry>[entry];
      final snapshot = PlanSnapshot(owner: _sessionOwner, entries: entries);
      (metadata['dependsOn'] as List).add('later mutation');
      entries.clear();

      expect(snapshot.entries.single.id, 'native-step-2');
      final frozen = snapshot.entries.single.metadata!.value as Map;
      expect(frozen['dependsOn'], ['native-step-1']);
      expect(() => snapshot.entries.clear(), throwsUnsupportedError);
      expect(
        () => (frozen['dependsOn'] as List).clear(),
        throwsUnsupportedError,
      );
      expect(() => frozen['new'] = 'value', throwsUnsupportedError);
      expect(
        () => PlanEntry(
          id: '',
          title: 'Invalid native identity',
          status: const OpenValue.known(PlanStatus.pending),
        ),
        throwsArgumentError,
      );
    });
  });

  group('usage observations', () {
    test('missing measurements remain distinct from observed zero', () {
      final observation = UsageObservation(
        id: 'partial',
        owner: _sessionOwner,
        scope: _scope,
        source: OpenValue.unknown('future-usage-source'),
        observedAt: _observedAt,
        partial: true,
        tokens: TokenBreakdown(input: 0),
        cost: Cost(currency: 'USD', partial: true),
        context: ContextMeter(
          used: 0,
          measurement: OpenValue.unknown('native-unclassified'),
        ),
        quotas: [
          QuotaWindow(
            id: 'unknown-window',
            label: 'Native window',
            source: const OpenValue.known(UsageSource.unknown),
          ),
        ],
      );

      expect(observation.tokens!.input, 0);
      expect(observation.tokens!.output, isNull);
      expect(observation.tokens!.cacheRead, isNull);
      expect(observation.cost!.amount, isNull);
      expect(observation.cost!.partial, isTrue);
      expect(observation.context!.limit, isNull);
      expect(observation.context!.measurement.value, 'native-unclassified');
      expect(observation.quotas.single.usedPercent, isNull);
      expect(observation.quotas.single.resetsAt, isNull);
      expect(observation.partial, isTrue);
      expect(observation.source.value, 'future-usage-source');
      expect(observation.observationKey, isNull);
      expect(_usage().tokens, isNull);
      expect(_usage().cost, isNull);
      expect(_usage().context, isNull);
    });

    test('quota above 100 and sparse reset metadata remain unchanged', () {
      final quota = QuotaWindow(
        id: 'weekly',
        label: '7 day native window',
        usedPercent: 142.75,
        source: const OpenValue.known(UsageSource.hostConnector),
      );
      final quotas = <QuotaWindow>[quota];
      final observation = UsageObservation(
        id: 'quota',
        owner: const GlobalOwner(_harnessRef),
        scope: const OpenValue.known(UsageScope.account),
        source: const OpenValue.known(UsageSource.hostConnector),
        observedAt: _observedAt,
        quotas: quotas,
      );
      quotas.clear();

      expect(observation.quotas.single.usedPercent, 142.75);
      expect(observation.quotas.single.resetsAt, isNull);
      expect(observation.quotas.single.source.known, UsageSource.hostConnector);
      expect(() => observation.quotas.add(quota), throwsUnsupportedError);
    });

    test('invalid measurements fail without disabling runtime validation', () {
      for (final value in [
        -1,
        double.nan,
        double.infinity,
        double.negativeInfinity,
      ]) {
        expect(() => TokenBreakdown(input: value), throwsArgumentError);
        expect(() => TokenBreakdown(cacheWrite: value), throwsArgumentError);
        expect(() => Cost(amount: value), throwsArgumentError);
        expect(
          () => ContextMeter(
            limit: value,
            measurement: const OpenValue.known(ContextMeasurement.measured),
          ),
          throwsArgumentError,
        );
        expect(
          () => QuotaWindow(
            id: 'window',
            label: '',
            source: _source,
            usedPercent: value,
          ),
          throwsArgumentError,
        );
      }
      expect(() => _usage(id: ''), throwsArgumentError);
      expect(() => _usage(aggregationKey: ''), throwsArgumentError);
      expect(() => Cost(currency: ''), throwsArgumentError);
    });

    test(
      'cumulative readings share a series but have distinct observations',
      () {
        final first = _usage(
          id: 'reading-1',
          cumulative: true,
          cost: Cost(amount: 1.25, currency: 'USD', cumulative: true),
        );
        final next = _usage(
          id: 'reading-2',
          cumulative: true,
          cost: Cost(amount: 1.50, currency: 'USD', cumulative: true),
        );

        expect(first.aggregationIdentity, next.aggregationIdentity);
        expect(first.observationKey, isNot(next.observationKey));
        expect(first.cumulative, isTrue);
        expect(next.cost!.cumulative, isTrue);
        expect(next.cost!.amount, 1.50);
        expect(_usage(aggregationKey: null).aggregationIdentity, isNull);
      },
    );

    test(
      'identities isolate scope, source, host, installation and version',
      () {
        final observations = [
          _usage(provenance: _provenance()),
          _usage(
            scope: const OpenValue.known(UsageScope.turn),
            provenance: _provenance(),
          ),
          _usage(
            source: const OpenValue.known(UsageSource.estimate),
            provenance: _provenance(),
          ),
          _usage(
            owner: const SessionOwner(
              SessionRef(HostId('other-host'), _harness, 'parent'),
            ),
          ),
          _usage(
            owner: const SessionOwner(
              SessionRef(
                _host,
                HarnessInstanceId('other-installation'),
                'parent',
              ),
            ),
          ),
          _usage(provenance: _provenance(version: 'next-version')),
        ];

        expect(observations.map((o) => o.observationKey).toSet(), hasLength(6));
        expect(
          observations.map((o) => o.aggregationIdentity).toSet(),
          hasLength(6),
        );
        final displayedInParent = _usage(
          owner: const SessionOwner(_child, origin: _parent),
        );
        final displayedAlone = _usage(owner: const SessionOwner(_child));
        expect(displayedInParent.observationKey, displayedAlone.observationKey);
        expect(
          displayedInParent.observationKey!.hashCode,
          displayedAlone.observationKey!.hashCode,
        );
      },
    );

    test(
      'host and project observations require an installation-qualified owner',
      () {
        const project = ProjectRef(_host, '/project');
        const other = HarnessRef(
          _host,
          HarnessInstanceId('other-installation'),
        );
        for (final owner in [
          ProjectOwner(project),
          HostOwner(_host),
          UnknownOwner(reason: 'No verified owner'),
        ]) {
          final observation = _usage(owner: owner, provenance: _provenance());
          expect(observation.observationKey, isNull);
          expect(observation.aggregationIdentity, isNull);
        }
        final projectOne = _usage(
          owner: ProjectOwner(project, harness: _harnessRef),
        );
        final projectTwo = _usage(owner: ProjectOwner(project, harness: other));
        final hostOne = _usage(owner: HostOwner(_host, harness: _harnessRef));
        final hostTwo = _usage(owner: HostOwner(_host, harness: other));
        expect(projectOne.observationKey, isNot(projectTwo.observationKey));
        expect(hostOne.aggregationIdentity, isNot(hostTwo.aggregationIdentity));
        final mismatch = _usage(provenance: _provenance(harness: other));
        expect(mismatch.observationKey, isNull);
        expect(mismatch.aggregationIdentity, isNull);
        expect(mismatch.provenance!.harness, other);
        final unknownScope = _usage(
          scope: OpenValue.unknown('provider-budget'),
        );
        expect(unknownScope.scope.value, 'provider-budget');
        expect(unknownScope.aggregationIdentity, isNull);
      },
    );

    test('freshness uses observation time and an explicit caller policy', () {
      final observation = _usage();
      expect(observation.isFreshAt(_observedAt, maxAge: Duration.zero), isTrue);
      expect(
        observation.isFreshAt(
          _observedAt.add(const Duration(minutes: 5)),
          maxAge: const Duration(minutes: 5),
        ),
        isTrue,
      );
      expect(
        observation.isFreshAt(
          _observedAt.add(const Duration(minutes: 6)),
          maxAge: const Duration(minutes: 5),
        ),
        isFalse,
      );
      expect(
        observation.isFreshAt(
          _observedAt.subtract(const Duration(microseconds: 1)),
          maxAge: const Duration(days: 1),
        ),
        isFalse,
      );
      expect(
        () => observation.isFreshAt(
          _observedAt,
          maxAge: const Duration(seconds: -1),
        ),
        throwsArgumentError,
      );
    });
  });
}
