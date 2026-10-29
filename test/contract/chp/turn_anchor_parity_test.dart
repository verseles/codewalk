@TestOn('vm')
library;

import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'model_projection_support.dart';
import 'schema_support.dart';

const harness = HarnessRef(HostId('host'), HarnessInstanceId('instance'));
const session = SessionRef(
  HostId('host'),
  HarnessInstanceId('instance'),
  'opaque-session',
);

void valid(String definition, Object? value) => expect(
  validateDefinition(definition, value).isValid,
  isTrue,
  reason: '$definition must preserve the reviewed core value',
);

void main() {
  test(
    'message anchor preserves opaque identity independently of source order',
    () {
      final a = MessageAnchor(message: MessageRef('opaque-z'), orderKey: '001');
      final b = MessageAnchor(message: MessageRef('opaque-a'), orderKey: '002');
      valid('CanonicalMessageAnchor', projectMessageAnchor(a));
      final wire = projectMessageAnchor(b);
      final restored = MessageAnchor(
        message: MessageRef(wire['message']! as String),
        orderKey: wire['orderKey']! as String,
      );
      expect(restored, b);
      expect(a.compareTo(restored), lessThan(0));
      expect(
        isValidDefinition('CanonicalMessageAnchor', {
          'message': 'x',
          'orderKey': '',
        }),
        isFalse,
      );
      expect(
        isValidDefinition('CanonicalMessageAnchor', {'message': 'x'}),
        isFalse,
      );
    },
  );

  test(
    'confirmation is explicit and independent of delivery and execution',
    () {
      final anchor = MessageAnchor(
        message: MessageRef('opaque-user'),
        orderKey: '002',
      );
      final meta = ItemMeta(
        id: const ItemId('user-item'),
        generation: 'g',
        status: const OpenValue.known(ItemStatus.completed),
        source: SourceProvenance(
          harness: harness,
          version: 'synthetic',
          nativeType: 'synthetic',
        ),
        anchor: anchor,
      );
      for (final confirmed in [false, true]) {
        final input = UserInput(
          meta: meta,
          text: 'prompt',
          confirmed: confirmed,
          delivery: OpenValue.unknown('historical-delivery-unknown'),
        );
        final wire = projectTimelineItem(input);
        valid('CanonicalUserInput', wire);
        valid('CanonicalTimelineItem', wire);
        expect(wire['confirmed'], confirmed);
        expect((wire['meta'] as Map)['anchor'], projectMessageAnchor(anchor));
      }
      final omitted = projectTimelineItem(
        UserInput(
          meta: meta,
          text: 'local echo',
          delivery: const OpenValue.known(DeliveryState.accepted),
        ),
      )..remove('confirmed');
      valid('CanonicalUserInput', omitted);
      expect(
        UserInput(
          meta: meta,
          text: 'local echo',
          delivery: const OpenValue.known(DeliveryState.accepted),
        ).confirmed,
        isFalse,
      );
      omitted['confirmed'] = 'true';
      expect(isValidDefinition('CanonicalUserInput', omitted), isFalse);
    },
  );

  test(
    'nonresident staged cut and pending input preserve their typed anchors',
    () {
      final cut = MessageAnchor(
        message: MessageRef('boundary'),
        orderKey: '002',
      );
      final later = MessageAnchor(
        message: MessageRef('later'),
        orderKey: '003',
      );
      final staged = RevertState(
        kind: const OpenValue.known(RevertKind.staged),
        anchor: cut,
      );
      final wire = projectRevertState(staged);
      valid('CanonicalRevertState', wire);
      expect(wire['boundary'], isNull);
      expect(wire['anchor'], projectMessageAnchor(cut));
      final pending = PendingInput(
        id: const ItemId('pending'),
        text: 'later',
        delivery: const OpenValue.known(Delivery.queue),
        anchor: later,
      );
      valid('CanonicalPendingInput', projectPendingInput(pending));
      expect(cut.compareTo(pending.anchor!), lessThan(0));
      wire['anchor'] = {'message': 'boundary', 'orderKey': null};
      expect(isValidDefinition('CanonicalRevertState', wire), isFalse);
    },
  );

  test('compact intent and coalesced admission keep different references', () {
    final original = OriginalCommand(
      id: const CommandId('compact'),
      harness: harness,
      owner: const SessionOwner(session),
      operation: const OpenValue.known(MutationOperation.compact),
      connectedVersion: 'synthetic',
      intent: CanonicalValue({'input': 'proposed-input', 'delivery': 'steer'}),
    );
    final command = <String, Object?>{
      'id': original.id.toJson(),
      'harness': original.harness.toJson(),
      'owner': projectOwner(original.owner),
      'operation': original.operation.toJson(),
      'connectedVersion': original.connectedVersion,
      'intent': original.intent.toJson(),
    };
    valid('CanonicalOriginalCommand', command);
    valid('CanonicalCompactIntent', original.intent.toJson());
    final frame = loadExample('chp-command-compact')..['command'] = command;
    valid('ChpCommand', frame);
    valid('ChpFrame', frame);
    final receipt = CommandReceipt.accepted(
      id: original.id,
      owner: original.owner,
      nativeRef: 'coalesced-input',
    );
    valid('CanonicalCommandReceipt', projectReceipt(receipt));
    expect(receipt.nativeRef, isNot((original.intent.value as Map)['input']));
    for (final badIntent in [
      <String, Object?>{},
      {'input': 'proposed-input', 'delivery': 'queue'},
      {'input': 'proposed-input', 'delivery': 'steer', 'replay': true},
    ]) {
      final invalid = cloneObject(frame);
      (invalid['command'] as Map)['intent'] = badIntent;
      expect(isValidDefinition('ChpCommand', invalid), isFalse);
    }
    final wrongOwner = cloneObject(frame);
    (wrongOwner['command'] as Map)['owner'] = {
      'type': 'global',
      'harness': harness.toJson(),
    };
    expect(isValidDefinition('ChpCommand', wrongOwner), isFalse);
    frame['canonicalRevision'] = 'cw-canonical-1-provisional.5';
    expect(isValidDefinition('ChpCommand', frame), isFalse);
  });
}
