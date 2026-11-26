import 'package:codewalk/features/sessions/session_live_scroll.dart';
import 'package:codewalk/features/sessions/session_live_timeline.dart';
import 'package:codewalk/features/sessions/session_timeline_projection.dart';
import 'package:codewalk/shared/l10n/generated/v2_localizations.dart';
import 'package:codewalk/shared/theme/chat_appearance.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _ref = SessionRef(HostId('h'), HarnessInstanceId('h'), 'ses_1');

ItemMeta _meta(String id, ItemStatus status) => ItemMeta(
  id: ItemId(id),
  generation: 'live',
  status: OpenValue.known(status),
  source: SourceProvenance(
    harness: _ref.harnessRef,
    version: '2.0.22',
    nativeType: 'live',
  ),
);

UserInput _prompt(String id, DeliveryState delivery, {String? text}) =>
    UserInput(
      meta: _meta(
        id,
        delivery == DeliveryState.delivered
            ? ItemStatus.completed
            : ItemStatus.pending,
      ),
      text: text ?? 'prompt $id',
      delivery: OpenValue.known(delivery),
      confirmed: delivery == DeliveryState.delivered,
    );

AssistantText _answer(String id, String text) => AssistantText(
  meta: _meta(id, ItemStatus.streaming),
  text: text,
  complete: false,
);

PendingInput _pending(String id, String text, Delivery delivery) =>
    PendingInput(
      id: ItemId(id),
      text: text,
      delivery: OpenValue.known(delivery),
    );

Widget _timeline(
  SessionLiveScroll scroll,
  List<TimelineItem> items,
  List<UserInput> waiting, {
  bool reducedMotion = false,
}) => MaterialApp(
  localizationsDelegates: V2Localizations.localizationsDelegates,
  supportedLocales: V2Localizations.supportedLocales,
  builder: (context, inner) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: reducedMotion),
    child: ChatAppearance(
      mathRendering: true,
      conversationTextScale: 1,
      child: inner!,
    ),
  ),
  home: Scaffold(
    body: SessionLiveTimeline(
      items: items,
      waiting: waiting,
      scroll: scroll,
      settled: false,
      headerBuilder: (_) => const SizedBox.shrink(),
    ),
  ),
);

/// The fill of the bubble that holds [text].
Color? _fill(WidgetTester tester, String text) => tester
    .widget<Card>(
      find
          .ancestor(
            of: find.textContaining(text, findRichText: true),
            matching: find.byType(Card),
          )
          .first,
    )
    .color;

void main() {
  group('waiting prompts (#502)', () {
    test('they leave their place and pin after the conversation', () {
      final steer = _prompt('steer', DeliveryState.accepted);
      final (:items, :waiting) = sessionWaitingPrompts(
        [
          _prompt('first', DeliveryState.delivered),
          _answer('a1', 'working'),
          steer,
          _answer('a2', 'still working'),
          _prompt('gone', DeliveryState.cancelled),
        ],
        [
          _pending('steer', 'prompt steer', Delivery.steer),
          _pending('queued', 'later', Delivery.queue),
          // A delivered prompt the pending list still names is settled.
          _pending('first', 'prompt first', Delivery.steer),
        ],
        harness: _ref.harnessRef,
      );
      expect([for (final item in items) item.id.value], ['first', 'a1', 'a2']);
      expect(
        [for (final input in waiting) input.id.value],
        ['steer', 'queued'],
      );
      expect(waiting.first, same(steer));
      final queued = waiting.last;
      expect(queued.text, 'later');
      expect(queued.delivery.known, DeliveryState.queued);
      expect(sessionPromptWaits(queued), isTrue);
      expect(queued.confirmed, isFalse);
    });

    test(
      'a waiting or cancelled prompt\'s message waits or leaves with it',
      () {
        final anchor = MessageAnchor(
          message: MessageRef('msg_s'),
          orderKey: 'msg_s',
        );
        ItemMeta anchored(String id, ItemStatus status) => ItemMeta(
          id: ItemId(id),
          generation: 'live',
          status: OpenValue.known(status),
          source: SourceProvenance(
            harness: _ref.harnessRef,
            version: '2.0.22',
            nativeType: 'live',
          ),
          anchor: anchor,
        );
        UserInput steer(DeliveryState delivery) => UserInput(
          meta: anchored('steer', ItemStatus.pending),
          text: 'steer',
          delivery: OpenValue.known(delivery),
        );
        final context = UnknownItem(
          meta: anchored('context', ItemStatus.completed),
          rawType: 'context',
          raw: CanonicalValue(<String, Object?>{}),
        );
        for (final delivery in [
          DeliveryState.accepted,
          DeliveryState.cancelled,
          DeliveryState.rejected,
        ]) {
          final (:items, :waiting) = sessionWaitingPrompts(
            [_answer('a1', 'x'), steer(delivery), context],
            const [],
            harness: _ref.harnessRef,
          );
          expect([for (final item in items) item.id.value], ['a1']);
          expect(
            waiting,
            hasLength(delivery == DeliveryState.accepted ? 1 : 0),
          );
        }
        // Delivered, a stale pending entry hides nothing.
        final delivered = [steer(DeliveryState.delivered), context];
        final (:items, :waiting) = sessionWaitingPrompts(delivered, [
          PendingInput(
            id: const ItemId('steer'),
            text: 'steer',
            delivery: const OpenValue.known(Delivery.steer),
            anchor: anchor,
          ),
        ], harness: _ref.harnessRef);
        expect(items, same(delivered));
        expect(waiting, isEmpty);
      },
    );

    test('a prompt sent here keeps its own text and attachments', () {
      final file = AttachmentRef(
        id: 'att-1',
        mimeType: 'text/plain',
        name: 'notes.txt',
        content: OutputRef(id: 'media:${'a' * 64}', sizeBytes: 12),
        kind: const OpenValue.known(AttachmentKind.file),
      );
      ({String text, List<AttachmentRef> attachments})? sentHere(ItemId id) =>
          id.value == 'mine' || id.value == 'done'
          ? (text: 'clean text', attachments: [file])
          : null;
      final timeline = [_prompt('done', DeliveryState.delivered)];
      final (:items, :waiting) = sessionWaitingPrompts(
        timeline,
        [
          _pending('mine', 'wire text', Delivery.queue),
          _pending('theirs', 'their text', Delivery.queue),
        ],
        harness: _ref.harnessRef,
        sentHere: sentHere,
      );
      expect(waiting.first.text, 'clean text');
      expect(waiting.first.attachments, [file]);
      expect(waiting.last.text, 'their text');
      expect(waiting.last.attachments, isEmpty);
      // Delivered without them, it keeps this device's attachments.
      expect((items.single as UserInput).attachments, [file]);
      expect((items.single as UserInput).text, 'prompt done');
      // Nothing waiting and nothing to add: the same list comes back.
      final plain = [_answer('a1', 'x')];
      expect(
        sessionWaitingPrompts(
          plain,
          const [],
          harness: _ref.harnessRef,
          sentHere: sentHere,
        ).items,
        same(plain),
      );
    });

    test('an admitted prompt the pending list lacks still waits', () {
      final (:items, :waiting) = sessionWaitingPrompts(
        [_prompt('steer', DeliveryState.accepted), _answer('a1', 'x')],
        const [],
        harness: _ref.harnessRef,
      );
      expect([for (final item in items) item.id.value], ['a1']);
      expect(waiting.single.id.value, 'steer');
    });

    testWidgets('they show after the reply in flight, fainter and breathing', (
      tester,
    ) async {
      final scroll = SessionLiveScroll();
      addTearDown(scroll.dispose);
      await tester.pumpWidget(
        _timeline(
          scroll,
          [_prompt('first', DeliveryState.delivered, text: 'Sent one')],
          [_prompt('queued', DeliveryState.queued, text: 'Waiting one')],
        ),
      );
      await tester.pump();
      final sent = tester.getRect(
        find.textContaining('Sent one', findRichText: true),
      );
      final waiting = tester.getRect(
        find.textContaining('Waiting one', findRichText: true),
      );
      expect(waiting.top, greaterThan(sent.bottom));
      final full = _fill(tester, 'Sent one')!.a;
      final faint = _fill(tester, 'Waiting one')!.a;
      expect(faint, lessThan(full));
      // It breathes while it waits.
      await tester.pump(const Duration(milliseconds: 800));
      expect(_fill(tester, 'Waiting one')!.a, isNot(closeTo(faint, 0.001)));
      // Screen readers hear that it waits.
      expect(find.bySemanticsLabel(RegExp('Queued')), findsOneWidget);
      // Delivered, it is an ordinary prompt.
      await tester.pumpWidget(
        _timeline(scroll, [
          _prompt('first', DeliveryState.delivered, text: 'Sent one'),
          _prompt('queued', DeliveryState.delivered, text: 'Waiting one'),
        ], const []),
      );
      await tester.pump();
      expect(_fill(tester, 'Waiting one')!.a, closeTo(full, 0.001));
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('with reduced motion the faint fill holds still', (
      tester,
    ) async {
      final scroll = SessionLiveScroll();
      addTearDown(scroll.dispose);
      await tester.pumpWidget(
        _timeline(scroll, const [], [
          _prompt('steer', DeliveryState.accepted, text: 'Steering one'),
        ], reducedMotion: true),
      );
      await tester.pump();
      final still = _fill(tester, 'Steering one')!.a;
      await tester.pump(const Duration(milliseconds: 800));
      expect(_fill(tester, 'Steering one')!.a, closeTo(still, 0.001));
      expect(tester.hasRunningAnimations, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
