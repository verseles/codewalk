import 'package:codewalk/platform/pairing/native_pairing_links.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('fake-test/private-pairing');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));
  test(
    'pending pull and uncertain ack deduplicate acceptance, not credentials',
    () async {
      var acknowledgments = 0;
      var drained = false;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'getPending') {
          return drained
              ? null
              : {'id': 1, 'uri': 'codewalk://pair?url=private-code'};
        }
        if (call.method == 'ack') {
          acknowledgments++;
          if (acknowledgments == 1) throw PlatformException(code: 'fake-test');
          drained = true;
        }
        return null;
      });
      final accepted = <Uri>[];
      final links = NativePairingLinks(
        accepted.add,
        channel: channel,
        enabled: true,
      );
      await links.start();
      expect(accepted, hasLength(1));
      await messenger.handlePlatformMessage(
        channel.name,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('pending'),
        ),
        (_) {},
      );
      expect(accepted, hasLength(1));
      expect(acknowledgments, 2);
      links.dispose();
    },
  );
}
