import 'package:codewalk/app/app_dependencies.dart';
import 'package:codewalk/app/composition_root.dart';
import 'package:codewalk/app/v2_bootstrap.dart';
import 'package:codewalk/platform/sessions/session_draft_store.dart';
import 'package:codewalk/platform/sessions/workspace_draft_store.dart';
import 'package:codewalk/platform/storage/metadata_store.dart';
import 'package:codewalk/platform/storage/payload_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../hosts/fakes.dart';
import '../storage/storage_fakes.dart';
import 'fakes.dart';
import 'live_fakes.dart';
import 'workspace_support.dart';

/// The two surface sizes of the v1 parity contract (#458): compact phone and
/// wide desktop, both in `en` at text scale 1.0.
const parityPhoneSize = Size(412, 915);
const parityDesktopSize = Size(1280, 800);

/// A mounted v2 workspace with the same fakes as the parity suite.
class ParitySurface {
  ParitySurface._(this.dependencies, this.directory, this.rig);

  final AppDependencies dependencies;
  final LiveDirectory directory;
  final CatalogRig rig;

  /// Pumps the v2 workspace at [size] in the requested brightness and settles
  /// its first frames. Tests own [tester] and the teardown of the view size.
  static Future<ParitySurface> pump(
    WidgetTester tester, {
    required Size size,
    bool dark = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final rig = CatalogRig();
    await rig.save('a');
    final directory = LiveDirectory();
    final metadata = V2MetadataStore(backend: FakeMetadataBackend());
    final payloads = PreferencesPayloadStore(metadata);
    final dependencies = createAppDependencies(
      initialLink: Uri(path: '/sessions'),
      metadataStore: metadata,
      profileRepository: rig.repository,
      endpointProber: FakeProber(),
      sessionCatalogFactory: rig.create,
      sessionLiveDirectory: () => directory,
      draftStore: SessionDraftStore(payloads: payloads, index: metadata),
      workspaceDraftStore: WorkspaceDraftStore(
        payloads: payloads,
        index: metadata,
      ),
    );
    addTearDown(dependencies.dispose);
    dependencies.preferences.setThemeMode(
      dark ? ThemeMode.dark : ThemeMode.light,
    );

    await tester.pumpWidget(
      CodeWalkV2Bootstrap(
        dependencies: dependencies,
        dynamicColors: (builder) => builder(null, null),
      ),
    );
    await showSessionList(tester);
    return ParitySurface._(dependencies, directory, rig);
  }
}

void main() {
  for (final entry in {
    'phone': parityPhoneSize,
    'desktop': parityDesktopSize,
  }.entries) {
    testWidgets('parity workspace mounts at ${entry.key} size', (tester) async {
      await ParitySurface.pump(tester, size: entry.value);

      expect(find.byType(CodeWalkV2Bootstrap), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
