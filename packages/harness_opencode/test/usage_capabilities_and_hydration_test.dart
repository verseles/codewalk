import 'package:codewalk_core/codewalk_core.dart';
import 'package:harness_opencode/harness_opencode.dart';
import 'package:test/test.dart';

void main() {
  final host = HostId('h1');
  final harness = HarnessInstanceId('i1');
  final session = SessionRef(host, harness, 'ses_1');
  final t0 = DateTime.utc(2026, 11, 21, 12, 0, 0);

  group('openCodeUsageCapabilities', () {
    test('reports native tokens/cost/context and unavailable quota on v2', () {
      final caps = openCodeUsageCapabilities('2.0.22');
      expect(caps[UsageCapabilities.tokens]?.isAvailable, isTrue);
      expect(caps[UsageCapabilities.cost]?.isAvailable, isTrue);
      expect(caps[UsageCapabilities.context]?.isAvailable, isTrue);
      expect(caps[UsageCapabilities.quota]?.isAvailable, isFalse);
      expect(caps[UsageCapabilities.quota]?.reason, 'quotaNotExposed');
    });

    test('reports all unavailable for null or unsupported server versions', () {
      for (final version in [null, '1.18.34', 'bad']) {
        final caps = openCodeUsageCapabilities(version);
        for (final key in UsageCapabilities.keys) {
          expect(caps[key]?.isAvailable, isFalse);
          expect(caps[key]?.reason, 'unverifiedVersion');
        }
      }
    });
  });

  group('openCodeHydratedSessionTotal', () {
    ItemMeta itemMeta(String id, {MessageContext? message}) => ItemMeta(
      id: ItemId(id),
      anchor: openCodeMessageAnchor(id),
      generation: 'g1',
      status: const OpenValue.known(ItemStatus.completed),
      source: SourceProvenance(
        harness: session.harnessRef,
        version: '2.0.22',
        nativeType: 'session.message.list',
      ),
      message: message,
    );

    test('skips schema-default zeroes on untouched or in-flight sessions', () {
      final untouched = openCodeHydratedSessionTotal(
        record: {
          'cost': 0,
          'tokens': {
            'input': 0,
            'output': 0,
            'reasoning': 0,
            'cache': {'read': 0, 'write': 0},
          },
          'time': {'updated': t0.millisecondsSinceEpoch},
        },
        session: session,
        timeline: [
          // In-flight assistant message with no reported tokens/cost yet.
          AssistantText(
            meta: itemMeta(
              'msg_1',
              message: MessageContext(message: MessageRef('msg_1')),
            ),
            text: 'working...',
            complete: false,
          ),
        ],
        sourceVersion: '2.0.22',
        fallbackObservedAt: t0,
      );
      expect(untouched, isNull);
    });

    test('emits zero cost when a completed step actually reported usage', () {
      final freeStep = openCodeHydratedSessionTotal(
        record: {
          'cost': 0,
          'tokens': {
            'input': 100,
            'output': 50,
            'reasoning': 0,
            'cache': {'read': 0, 'write': 0},
          },
          'time': {'updated': t0.millisecondsSinceEpoch},
        },
        session: session,
        timeline: [
          AssistantText(
            meta: itemMeta(
              'msg_1',
              message: MessageContext(
                message: MessageRef('msg_1'),
                cost: Cost(amount: 0, currency: 'USD'),
                tokens: TokenBreakdown(
                  input: 100,
                  output: 50,
                  reasoning: 0,
                  cacheRead: 0,
                  cacheWrite: 0,
                ),
              ),
            ),
            text: 'done',
            complete: true,
          ),
        ],
        sourceVersion: '2.0.22',
        fallbackObservedAt: t0,
      );
      expect(freeStep, isNotNull);
      expect(freeStep!.cumulative, isTrue);
      expect(freeStep.aggregationKey, openCodeSessionTotalKey);
      expect(freeStep.cost?.amount, 0);
      expect(freeStep.cost?.currency, 'USD');
      expect(freeStep.tokens?.input, 100);
    });

    test('emits cumulative session-total from Session.Info cost/tokens', () {
      final obs = openCodeHydratedSessionTotal(
        record: {
          'cost': 0.42,
          'tokens': {
            'input': 1200,
            'output': 300,
            'reasoning': 100,
            'cache': {'read': 400, 'write': 50},
          },
          'time': {'updated': t0.millisecondsSinceEpoch},
        },
        session: session,
        timeline: const [],
        sourceVersion: '2.0.22',
        fallbackObservedAt: t0.add(const Duration(seconds: 10)),
      );
      expect(obs, isNotNull);
      expect(obs!.cost?.amount, closeTo(0.42, 1e-9));
      expect(obs.tokens?.cacheRead, 400);
      expect(obs.tokens?.cacheWrite, 50);
      expect(obs.observedAt, t0);
    });
  });
}
