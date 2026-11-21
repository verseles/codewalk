import 'package:codewalk_core/codewalk_core.dart';
import 'package:test/test.dart';

void main() {
  final host = HostId('h1');
  final harness = HarnessInstanceId('i1');
  final session = SessionRef(host, harness, 'ses_1');
  final owner = SessionOwner(session);
  final t0 = DateTime.utc(2026, 11, 21, 12, 0, 0);

  Map<String, Capability> nativeCaps({bool quota = false}) => {
    UsageCapabilities.tokens: Capability(
      support: const OpenValue.known(Support.native),
      verified: true,
    ),
    UsageCapabilities.cost: Capability(
      support: const OpenValue.known(Support.native),
      verified: true,
    ),
    UsageCapabilities.context: Capability(
      support: const OpenValue.known(Support.native),
      verified: true,
    ),
    UsageCapabilities.quota: Capability(
      support: OpenValue.known(quota ? Support.native : Support.unavailable),
      verified: quota,
      reason: quota ? null : 'quotaNotExposed',
    ),
  };

  group('resolveSessionUsage', () {
    test('unknown when empty and never returns zero', () {
      final view = resolveSessionUsage(
        usage: const [],
        capabilities: nativeCaps(),
        hasMoreHistory: false,
        fallbackContextLimit: 200000,
      );
      expect(view.supportsAny, isTrue);
      expect(view.supportsContext, isTrue);
      expect(view.supportsQuota, isFalse);
      expect(view.quotaUnavailableReason, 'quotaNotExposed');
      expect(view.contextUsed, isNull);
      expect(view.usagePercent, isNull);
      expect(view.contextLimit, 200000);
      expect(view.contextTokens, isNull);
      expect(view.cost, isNull);
      expect(view.quotas, isEmpty);
    });

    test('measured zero is distinct from unknown', () {
      final meterObs = UsageObservation(
        id: 'context-occupancy',
        owner: owner,
        scope: const OpenValue.known(UsageScope.session),
        source: const OpenValue.known(UsageSource.native),
        observedAt: t0,
        cumulative: true,
        aggregationKey: 'context-occupancy',
        tokens: TokenBreakdown(
          input: 0,
          output: 0,
          reasoning: 0,
          cacheRead: 0,
          cacheWrite: 0,
        ),
        context: ContextMeter(
          used: 0,
          measurement: const OpenValue.known(ContextMeasurement.measured),
          modelId: 'm1',
          modelProviderId: 'p1',
        ),
      );
      final view = resolveSessionUsage(
        usage: [meterObs],
        capabilities: nativeCaps(),
        hasMoreHistory: false,
        contextLimitForModel: (m, p) => m == 'm1' && p == 'p1' ? 100000 : null,
      );
      expect(view.contextUsed, 0);
      expect(view.contextLimit, 100000);
      expect(view.usagePercent, 0);
    });

    test('computes percent above 100 and keeps null when limit is unknown', () {
      final meterObs = UsageObservation(
        id: 'context-occupancy',
        owner: owner,
        scope: const OpenValue.known(UsageScope.session),
        source: const OpenValue.known(UsageSource.native),
        observedAt: t0,
        cumulative: true,
        aggregationKey: 'context-occupancy',
        context: ContextMeter(
          used: 150000,
          measurement: const OpenValue.known(ContextMeasurement.estimated),
          modelId: 'm1',
          modelProviderId: 'p1',
        ),
      );
      final over = resolveSessionUsage(
        usage: [meterObs],
        capabilities: nativeCaps(),
        hasMoreHistory: false,
        contextLimitForModel: (_, _) => 100000,
      );
      expect(over.usagePercent, 150);
      expect(over.contextEstimated, isTrue);

      final unknownLimit = resolveSessionUsage(
        usage: [meterObs],
        capabilities: nativeCaps(),
        hasMoreHistory: false,
        contextLimitForModel: (_, _) => null,
        fallbackContextLimit: 200000,
      );
      expect(unknownLimit.contextUsed, 150000);
      expect(unknownLimit.contextLimit, isNull);
      expect(unknownLimit.usagePercent, isNull);
    });

    test(
      'cumulative cost is not double-counted with earlier/equal steps, adds strictly later step once',
      () {
        final step1 = UsageObservation(
          id: 'step:msg_1',
          owner: owner,
          scope: const OpenValue.known(UsageScope.turn),
          source: const OpenValue.known(UsageSource.native),
          observedAt: t0,
          partial: true,
          aggregationKey: 'step:msg_1',
          cost: Cost(amount: 0.20, currency: 'USD', partial: true),
        );
        final total = UsageObservation(
          id: 'session-total',
          owner: owner,
          scope: const OpenValue.known(UsageScope.session),
          source: const OpenValue.known(UsageSource.native),
          observedAt: t0,
          cumulative: true,
          aggregationKey: 'session-total',
          cost: Cost(amount: 1.00, currency: 'USD', cumulative: true),
        );
        final step2a = UsageObservation(
          id: 'step:msg_2',
          owner: owner,
          scope: const OpenValue.known(UsageScope.turn),
          source: const OpenValue.known(UsageSource.native),
          observedAt: t0.add(const Duration(seconds: 2)),
          partial: true,
          aggregationKey: 'step:msg_2',
          cost: Cost(amount: 0.10, currency: 'USD', partial: true),
        );
        final step2b = UsageObservation(
          id: 'step:msg_2',
          owner: owner,
          scope: const OpenValue.known(UsageScope.turn),
          source: const OpenValue.known(UsageSource.native),
          observedAt: t0.add(const Duration(seconds: 3)),
          partial: true,
          aggregationKey: 'step:msg_2',
          cost: Cost(amount: 0.25, currency: 'USD', partial: true),
        );

        final atSameTime = resolveSessionUsage(
          usage: [step1, total],
          capabilities: nativeCaps(),
          hasMoreHistory: true,
        );
        expect(atSameTime.cost?.amount, closeTo(1.00, 1e-9));

        final withLaterStep = resolveSessionUsage(
          usage: [step1, total, step2a, step2b],
          capabilities: nativeCaps(),
          hasMoreHistory: true,
        );
        expect(withLaterStep.cost?.amount, closeTo(1.25, 1e-9));
        expect(withLaterStep.cost?.currency, 'USD');
      },
    );

    test(
      'without cumulative total, complete history sums steps once and incomplete history stays unknown',
      () {
        final step1 = UsageObservation(
          id: 'step:msg_1',
          owner: owner,
          scope: const OpenValue.known(UsageScope.turn),
          source: const OpenValue.known(UsageSource.native),
          observedAt: t0,
          partial: true,
          aggregationKey: 'step:msg_1',
          cost: Cost(amount: 0.15, currency: 'USD', partial: true),
        );
        final step2 = UsageObservation(
          id: 'step:msg_2',
          owner: owner,
          scope: const OpenValue.known(UsageScope.turn),
          source: const OpenValue.known(UsageSource.native),
          observedAt: t0.add(const Duration(seconds: 1)),
          partial: true,
          aggregationKey: 'step:msg_2',
          cost: Cost(amount: 0.35, currency: 'USD', partial: true),
        );

        final complete = resolveSessionUsage(
          usage: [step1, step2],
          capabilities: nativeCaps(),
          hasMoreHistory: false,
        );
        expect(complete.cost?.amount, closeTo(0.50, 1e-9));

        final incomplete = resolveSessionUsage(
          usage: [step1, step2],
          capabilities: nativeCaps(),
          hasMoreHistory: true,
        );
        expect(incomplete.cost, isNull);
      },
    );

    test(
      'capabilities gate every family and quota windows pass through when supported',
      () {
        final quotaObs = UsageObservation(
          id: 'quota-1',
          owner: owner,
          scope: const OpenValue.known(UsageScope.account),
          source: const OpenValue.known(UsageSource.native),
          observedAt: t0,
          quotas: [
            QuotaWindow(
              id: 'weekly',
              label: 'Weekly',
              source: const OpenValue.known(UsageSource.native),
              usedPercent: 120,
            ),
            QuotaWindow(
              id: 'unknown-window',
              label: 'Rolling',
              source: const OpenValue.known(UsageSource.native),
            ),
          ],
        );

        final disabled = resolveSessionUsage(
          usage: [quotaObs],
          capabilities: const {},
          hasMoreHistory: false,
        );
        expect(disabled.supportsAny, isFalse);
        expect(disabled.quotas, isEmpty);

        final enabled = resolveSessionUsage(
          usage: [quotaObs],
          capabilities: nativeCaps(quota: true),
          hasMoreHistory: false,
        );
        expect(enabled.supportsQuota, isTrue);
        expect(enabled.quotas.map((q) => q.id), ['weekly', 'unknown-window']);
        expect(enabled.quotas.first.usedPercent, 120);
        expect(enabled.quotas.last.usedPercent, isNull);
      },
    );

    test(
      'derives context from timeline after last completed compaction and before staged revert',
      () {
        ItemMeta itemMeta(
          String msgId,
          int ordinal, {
          MessageContext? message,
        }) => ItemMeta(
          id: ItemId('$msgId:$ordinal'),
          anchor: MessageAnchor(message: MessageRef(msgId), orderKey: msgId),
          generation: 'g1',
          status: const OpenValue.known(ItemStatus.completed),
          source: SourceProvenance(
            harness: session.harnessRef,
            version: '2.0.22',
            nativeType: 'session.message.list',
          ),
          message: message,
        );

        final msg1 = AssistantText(
          meta: itemMeta(
            'msg_1',
            0,
            message: MessageContext(
              message: MessageRef('msg_1'),
              modelId: 'm1',
              modelProviderId: 'p1',
              tokens: TokenBreakdown(
                input: 40000,
                output: 10000,
                reasoning: 0,
                cacheRead: 0,
                cacheWrite: 0,
              ),
              cost: Cost(amount: 0.12, currency: 'USD'),
            ),
          ),
          text: 'first',
          complete: true,
        );
        final msg1Part2 = AssistantText(
          meta: itemMeta(
            'msg_1',
            1,
            message: MessageContext(
              message: MessageRef('msg_1'),
              modelId: 'm1',
              modelProviderId: 'p1',
              tokens: TokenBreakdown(
                input: 40000,
                output: 10000,
                reasoning: 0,
                cacheRead: 0,
                cacheWrite: 0,
              ),
              cost: Cost(amount: 0.12, currency: 'USD'),
            ),
          ),
          text: 'first-part-2',
          complete: true,
        );
        final failedCompaction = Notice(
          meta: ItemMeta(
            id: ItemId('msg_2:0'),
            anchor: MessageAnchor(
              message: MessageRef('msg_2'),
              orderKey: 'msg_2',
            ),
            generation: 'g1',
            status: const OpenValue.known(ItemStatus.failed),
            source: SourceProvenance(
              harness: session.harnessRef,
              version: '2.0.22',
              nativeType: 'session.compaction.failed',
            ),
          ),
          kind: const OpenValue.known(NoticeKind.compaction),
          text: 'failed',
        );
        final completedCompaction = Notice(
          meta: ItemMeta(
            id: ItemId('msg_3:0'),
            anchor: MessageAnchor(
              message: MessageRef('msg_3'),
              orderKey: 'msg_3',
            ),
            generation: 'g1',
            status: const OpenValue.known(ItemStatus.completed),
            source: SourceProvenance(
              harness: session.harnessRef,
              version: '2.0.22',
              nativeType: 'session.compaction.ended',
            ),
          ),
          kind: const OpenValue.known(NoticeKind.compaction),
          text: 'compacted',
        );
        final msg4 = AssistantText(
          meta: itemMeta(
            'msg_4',
            0,
            message: MessageContext(
              message: MessageRef('msg_4'),
              modelId: 'm2',
              modelProviderId: 'p1',
              tokens: TokenBreakdown(
                input: 15000,
                output: 5000,
                reasoning: 0,
                cacheRead: 0,
                cacheWrite: 0,
              ),
              cost: Cost(amount: 0.08, currency: 'USD'),
            ),
          ),
          text: 'post-compaction',
          complete: true,
        );

        // Failed compaction preserves prior occupancy; multi-part msg_1 counts cost once.
        final afterFailedCompaction = resolveSessionUsage(
          usage: const [],
          timeline: [msg1, msg1Part2, failedCompaction],
          capabilities: nativeCaps(),
          hasMoreHistory: false,
          contextLimitForModel: (m, _) => m == 'm1' ? 100000 : 200000,
        );
        expect(afterFailedCompaction.contextUsed, 50000);
        expect(afterFailedCompaction.usagePercent, 50);
        expect(afterFailedCompaction.cost?.amount, closeTo(0.12, 1e-9));

        // Completed compaction with no later assistant clears context to unknown.
        final rightAfterCompaction = resolveSessionUsage(
          usage: const [],
          timeline: [msg1, completedCompaction],
          capabilities: nativeCaps(),
          hasMoreHistory: false,
          contextLimitForModel: (m, _) => 100000,
        );
        expect(rightAfterCompaction.contextUsed, isNull);
        expect(rightAfterCompaction.usagePercent, isNull);

        // Next assistant step after compaction restores occupancy using its model limit.
        final afterNextStep = resolveSessionUsage(
          usage: const [],
          timeline: [msg1, completedCompaction, msg4],
          capabilities: nativeCaps(),
          hasMoreHistory: false,
          contextLimitForModel: (m, _) => m == 'm1' ? 100000 : 200000,
        );
        expect(afterNextStep.contextUsed, 20000);
        expect(afterNextStep.contextLimit, 200000);
        expect(afterNextStep.usagePercent, 10);
        expect(afterNextStep.cost?.amount, closeTo(0.20, 1e-9));

        // Staged revert before msg_3 restores msg_1's occupancy.
        final reverted = resolveSessionUsage(
          usage: const [],
          timeline: [msg1, completedCompaction, msg4],
          revert: RevertState(
            kind: const OpenValue.known(RevertKind.staged),
            anchor: MessageAnchor(
              message: MessageRef('msg_3'),
              orderKey: 'msg_3',
            ),
          ),
          capabilities: nativeCaps(),
          hasMoreHistory: false,
          contextLimitForModel: (m, _) => m == 'm1' ? 100000 : 200000,
        );
        expect(reverted.contextUsed, 50000);
        expect(reverted.contextLimit, 100000);
        expect(reverted.usagePercent, 50);
      },
    );
  });

  group('SessionReducer limitUsage retention', () {
    test(
      'retains cumulative session-total and context-occupancy past maxObservations steps',
      () {
        var state = SessionState(
          session,
          limits: const ReducerLimits(maxObservations: 4),
        );
        final source = SourceProvenance(
          harness: session.harnessRef,
          version: '2.0.22',
          nativeType: 'session.usage.updated',
        );
        EventMeta meta(int seq) => EventMeta(
          owner: owner,
          position: StreamPosition(
            id: 'stream',
            epoch: 'e1',
            seq: BigInt.from(seq),
          ),
          receivedAt: t0.add(Duration(seconds: seq)),
          source: source,
        );

        state = reduce(
          state,
          UsageObserved(
            meta: meta(1),
            observation: UsageObservation(
              id: 'session-total',
              owner: owner,
              scope: const OpenValue.known(UsageScope.session),
              source: const OpenValue.known(UsageSource.native),
              observedAt: t0,
              cumulative: true,
              aggregationKey: 'session-total',
              cost: Cost(amount: 1.50, currency: 'USD', cumulative: true),
            ),
          ),
        ).state;
        state = reduce(
          state,
          UsageObserved(
            meta: meta(2),
            observation: UsageObservation(
              id: 'context-occupancy',
              owner: owner,
              scope: const OpenValue.known(UsageScope.session),
              source: const OpenValue.known(UsageSource.native),
              observedAt: t0.add(const Duration(seconds: 1)),
              cumulative: true,
              aggregationKey: 'context-occupancy',
              context: ContextMeter(
                used: 5000,
                measurement: const OpenValue.known(ContextMeasurement.measured),
                modelId: 'm1',
                modelProviderId: 'p1',
              ),
            ),
          ),
        ).state;

        for (var i = 3; i <= 10; i++) {
          state = reduce(
            state,
            UsageObserved(
              meta: meta(i),
              observation: UsageObservation(
                id: 'step:msg_$i',
                owner: owner,
                scope: const OpenValue.known(UsageScope.turn),
                source: const OpenValue.known(UsageSource.native),
                observedAt: t0.add(Duration(seconds: i)),
                partial: true,
                aggregationKey: 'step:msg_$i',
                cost: Cost(amount: 0.1, currency: 'USD', partial: true),
              ),
            ),
          ).state;
        }

        expect(state.usage.length, 4);
        expect(
          state.usage.any((o) => o.aggregationKey == 'session-total'),
          isTrue,
        );
        expect(
          state.usage.any((o) => o.aggregationKey == 'context-occupancy'),
          isTrue,
        );
        expect(state.usage.any((o) => o.id == 'step:msg_9'), isTrue);
        expect(state.usage.any((o) => o.id == 'step:msg_10'), isTrue);
        expect(state.usage.any((o) => o.id == 'step:msg_3'), isFalse);
      },
    );
  });
}
