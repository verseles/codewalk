import 'package:codewalk/app/composition_root.dart';
import 'package:codewalk/app/v2_bootstrap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../hosts/fakes.dart';
import 'fakes.dart';

void main() {
  for (final size in [const Size(390, 844), const Size(1280, 800)]) {
    testWidgets(
      'pair confirmation and save keep input private at ${size.width}',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final adapter = FakePairing();
        final repo = MemoryProfiles();
        final graph = createAppDependencies(
          initialLink: Uri(path: '/pair'),
          profileRepository: repo,
          endpointProber: FakeProber(),
          endpointPairing: adapter,
          qrInput: FakeQrInput(),
        );
        await tester.pumpWidget(CodeWalkV2Bootstrap(dependencies: graph));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('pairing-link')),
          'fake-test-link',
        );
        await tester.pumpAndSettle();
        expect(adapter.calls, 0);
        expect(find.text('http://127.0.0.1:4096/'), findsOneWidget);
        expect(find.text('fake-test-code'), findsNothing);
        await tester.tap(find.byKey(const ValueKey('confirm-pairing')));
        await tester.pumpAndSettle();
        expect(adapter.calls, 1);
        await tester.tap(find.byKey(const ValueKey('save-pairing')));
        await tester.pumpAndSettle();
        expect(repo.profiles, hasLength(1));
        expect(find.text('fake-test-paired'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
