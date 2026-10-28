import 'package:codewalk_core/codewalk_core.dart';
import 'package:test/test.dart';

void main() {
  test('message order is adapter supplied and independent of opaque IDs', () {
    final first = MessageAnchor(
      message: MessageRef('opaque-z'),
      orderKey: '001',
    );
    final later = MessageAnchor(
      message: MessageRef('opaque-a'),
      orderKey: '002',
    );
    expect(first.compareTo(later), lessThan(0));
    expect(later.compareTo(first), greaterThan(0));
    expect(
      first,
      MessageAnchor(message: MessageRef('opaque-z'), orderKey: '001'),
    );
    expect(
      () => MessageAnchor(message: MessageRef('x'), orderKey: ''),
      throwsArgumentError,
    );
  });

  test(
    'copying presentation metadata retains confirmation and typed anchor',
    () {
      final anchor = MessageAnchor(
        message: MessageRef('opaque'),
        orderKey: '001',
      );
      final meta = ItemMeta(
        id: const ItemId('item'),
        generation: 'generation',
        status: const OpenValue.known(ItemStatus.completed),
        source: SourceProvenance(
          version: 'test',
          nativeType: 'test',
          harness: const HarnessRef(
            HostId('host'),
            HarnessInstanceId('instance'),
          ),
        ),
        anchor: anchor,
      );
      final user = UserInput(
        meta: meta,
        text: 'hello',
        confirmed: true,
        delivery: const OpenValue.known(DeliveryState.delivered),
      );
      final copied =
          user.withMeta(
                meta.withMessage(MessageContext(message: anchor.message)),
              )
              as UserInput;
      expect(copied.confirmed, isTrue);
      expect(copied.meta.anchor, anchor);
      expect(
        UserInput(
          meta: meta,
          text: 'echo',
          delivery: const OpenValue.known(DeliveryState.accepted),
        ).confirmed,
        isFalse,
      );
      expect(
        () => meta.withMessage(MessageContext(message: MessageRef('other'))),
        throwsArgumentError,
      );
    },
  );

  test('revert anchor survives an absent resident boundary', () {
    final anchor = MessageAnchor(
      message: MessageRef('opaque'),
      orderKey: '001',
    );
    final revert = RevertState(
      kind: const OpenValue.known(RevertKind.staged),
      anchor: anchor,
    );
    expect(revert.boundary, isNull);
    expect(revert.anchor, anchor);
    expect(
      PendingInput(
        id: const ItemId('input'),
        text: 'later',
        delivery: const OpenValue.known(Delivery.queue),
        anchor: anchor,
      ).anchor,
      anchor,
    );
  });
}
