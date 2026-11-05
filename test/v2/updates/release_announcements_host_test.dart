import 'package:codewalk/features/settings/release_announcements_controller.dart';
import 'package:codewalk/features/settings/release_announcements_host.dart';
import 'package:codewalk/features/settings/update_check_controller.dart';
import 'package:codewalk/features/settings/update_discovery_host.dart';
import 'package:codewalk/platform/storage/metadata_store.dart';
import 'package:codewalk/shared/l10n/generated/v2_localizations.dart';
import 'package:codewalk/shared/releases/update_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../storage/storage_fakes.dart';
import 'release_announcements_controller_test.dart' show Source;

void main() {
  Future<ReleaseAnnouncementsController> mount(
    WidgetTester tester, {
    bool existing = true,
  }) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final store = V2MetadataStore(backend: FakeMetadataBackend());
    final checks = UpdateCheckController(
      source: Source(),
      store: store,
      installedVersion: () async => '2.0.0-beta.2',
      target: UpdateTarget.androidArm64,
    );
    final announcements = ReleaseAnnouncementsController(
      store: store,
      checks: checks,
      installedVersion: () async => '2.0.0-beta.2',
      existingInstallation: Future.value(existing),
    );
    await Future.wait([
      announcements.start(),
      checks.check(silent: true, force: false),
    ]);
    addTearDown(() {
      announcements.dispose();
      checks.dispose();
    });
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ReleaseAnnouncementsController>.value(
            value: announcements,
          ),
          ChangeNotifierProvider<UpdateCheckController>.value(value: checks),
        ],
        child: const MaterialApp(
          localizationsDelegates: V2Localizations.localizationsDelegates,
          supportedLocales: V2Localizations.supportedLocales,
          locale: Locale('en'),
          home: Scaffold(
            body: ReleaseAnnouncementsHost(
              enabled: true,
              child: UpdateDiscoveryHost(
                enabled: true,
                child: Text('Workspace'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return announcements;
  }

  testWidgets(
    'fresh install skips cumulative dialog but shows independent news toast',
    (tester) async {
      final controller = await mount(tester, existing: false);
      expect(controller.pendingKey, isNull);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(SnackBar), findsOneWidget);
    },
  );

  testWidgets('explicit Close with checked option acknowledges the interval', (
    tester,
  ) async {
    final controller = await mount(tester);
    expect(find.text('Beta 2'), findsOneWidget);
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
      isTrue,
    );
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(controller.pendingKey, isNull);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('unchecked Close retains pending interval without repeating it', (
    tester,
  ) async {
    final controller = await mount(tester);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(controller.pendingKey, isNotNull);
    expect(controller.pendingAnnouncements, isNull);
    expect(find.byType(AlertDialog), findsNothing);
  });
}
