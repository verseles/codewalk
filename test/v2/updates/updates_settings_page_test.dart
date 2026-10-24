import 'dart:convert';

import 'package:codewalk/app/composition_root.dart';
import 'package:codewalk/app/v2_bootstrap.dart';
import 'package:codewalk/features/settings/update_check_controller.dart';
import 'package:codewalk/features/settings/updates_settings_page.dart';
import 'package:codewalk/platform/releases/release_source_factory.dart';
import 'package:codewalk/platform/storage/metadata_store.dart';
import 'package:codewalk/shared/releases/release_source.dart';
import 'package:codewalk/shared/releases/update_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../storage/storage_fakes.dart';

class ImmediateSource implements ReleaseSource {
  ImmediateSource(this.body);
  String? body;
  int requests = 0;
  @override
  ReleaseSourceTask start() {
    requests++;
    return ImmediateTask(
      body == null
          ? const ReleaseSourceResult.failure(ReleaseSourceFailure.unavailable)
          : ReleaseSourceResult.success(body!),
    );
  }

  @override
  void close() {}
}

class ImmediateTask implements ReleaseSourceTask {
  ImmediateTask(this.value);
  final ReleaseSourceResult value;
  @override
  Future<ReleaseSourceResult> get result async => value;
  @override
  void cancel() {}
}

String listing(String tag) => jsonEncode([
  {
    'tag_name': tag,
    'draft': false,
    'prerelease': tag.contains('-'),
    'assets': [
      for (final target in UpdateTarget.values)
        {
          'name': target.assetName,
          'browser_download_url':
              'https://github.com/verseles/codewalk/releases/download/$tag/${target.assetName}',
        },
    ],
  },
]);

void main() {
  Future<UpdateCheckController> mount(
    WidgetTester tester, {
    required UpdateTarget? target,
    String? body,
    List<Uri>? opened,
  }) async {
    final updates = UpdateCheckController(
      source: ImmediateSource(body),
      store: V2MetadataStore(backend: FakeMetadataBackend()),
      installedVersion: () async => '2.0.0-beta.1',
      target: target,
    );
    addTearDown(updates.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<UpdateCheckController?>.value(
            value: updates,
            child: UpdatesSettingsPage(
              open: (uri) async {
                opened?.add(uri);
                return true;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return updates;
  }

  Future<void> optInAndCheck(WidgetTester tester) async {
    await tester.tap(find.text('Beta'));
    await tester.pumpAndSettle();
    expect(
      find.text('Beta versions are previews and may have problems.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('updates_check')));
    await tester.pumpAndSettle();
  }

  testWidgets('Android opens the exact APK and installs nothing itself', (
    tester,
  ) async {
    final opened = <Uri>[];
    await mount(
      tester,
      target: UpdateTarget.androidArm64,
      body: listing('v2.0.0-beta.2'),
      opened: opened,
    );
    await optInAndCheck(tester);
    expect(find.text('Update available: v2.0.0-beta.2'), findsOneWidget);
    expect(find.text('Installed version: 2.0.0-beta.1'), findsOneWidget);
    expect(find.byKey(const ValueKey('updates_linux_command')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('updates_download')));
    await tester.pump();
    expect(opened, [
      Uri.parse(
        'https://github.com/verseles/codewalk/releases/download/v2.0.0-beta.2/codewalk-android-arm64.apk',
      ),
    ]);
  });

  testWidgets('Linux shows and copies the exact-tag installer command', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await mount(
      tester,
      target: UpdateTarget.linuxArm64,
      body: listing('v2.0.0-beta.3'),
    );
    await optInAndCheck(tester);
    const command =
        'curl -fsSL https://install.cat/verseles/codewalk | '
        'CODEWALK_CHANNEL=beta CODEWALK_VERSION=v2.0.0-beta.3 sh';
    expect(find.text(command), findsOneWidget);
    expect(find.byKey(const ValueKey('updates_download')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('updates_copy_command')));
    await tester.pumpAndSettle();
    expect(copied, command);
    expect(find.text('Command copied'), findsOneWidget);
  });

  testWidgets('stable reports up to date and a failure is shown', (
    tester,
  ) async {
    final updates = await mount(
      tester,
      target: UpdateTarget.linuxX64,
      body: listing('v2.0.0-beta.9'),
    );
    await tester.tap(find.byKey(const ValueKey('updates_check')));
    await tester.pumpAndSettle();
    expect(updates.channel, UpdateChannel.stable);
    expect(find.byKey(const ValueKey('updates_up_to_date')), findsOneWidget);

    final failing = await mount(tester, target: UpdateTarget.linuxX64);
    await tester.tap(find.byKey(const ValueKey('updates_check')));
    await tester.pumpAndSettle();
    expect(failing.status, UpdateCheckStatus.failed);
    expect(find.byKey(const ValueKey('updates_failed')), findsOneWidget);
  });

  testWidgets('an unsupported platform offers no check', (tester) async {
    await mount(tester, target: null);
    expect(find.byKey(const ValueKey('updates_unsupported')), findsOneWidget);
    expect(find.byKey(const ValueKey('updates_check')), findsNothing);
  });

  testWidgets('Settings Help wires a manual native beta check', (tester) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    final source = ImmediateSource(listing('v2.0.0-beta.2'));
    final graph = createAppDependencies(
      initialLink: Uri(path: '/settings'),
      metadataStore: V2MetadataStore(backend: FakeMetadataBackend()),
      updateSource: source,
      installedVersion: () async => '2.0.0-beta.1',
    );
    await graph.preferences.initialize();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      graph.dispose();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      CodeWalkV2Bootstrap(
        dependencies: graph,
        dynamicColors: (builder) => builder(null, null),
      ),
    );
    await tester.pumpAndSettle();
    final row = find.byKey(const ValueKey('settings_destination_updates'));
    await tester.scrollUntilVisible(
      row,
      150,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('settings_destinations')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('settings_updates_page')), findsOneWidget);
    expect(source.requests, 0, reason: 'opening the page never checks');
    if (currentUpdateTarget() != null) {
      expect(find.byKey(const ValueKey('updates_check')), findsOneWidget);
      expect(find.byKey(const ValueKey('updates_unsupported')), findsNothing);
      await tester.tap(find.text('Beta'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('updates_check')));
      await tester.pumpAndSettle();
      expect(source.requests, 1);
      expect(find.byKey(const ValueKey('updates_available')), findsOneWidget);
    }
  });
}
