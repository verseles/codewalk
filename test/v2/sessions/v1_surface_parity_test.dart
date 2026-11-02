import 'package:codewalk/app/app_dependencies.dart';
import 'package:codewalk/app/composition_root.dart';
import 'package:codewalk/app/v2_bootstrap.dart';
import 'package:codewalk/core/network/dio_client.dart';
import 'package:codewalk/domain/entities/experience_settings.dart';
import 'package:codewalk/platform/sessions/session_draft_store.dart';
import 'package:codewalk/platform/sessions/workspace_draft_store.dart';
import 'package:codewalk/platform/storage/metadata_store.dart';
import 'package:codewalk/platform/storage/payload_store.dart';
import 'package:codewalk/presentation/providers/settings_provider.dart';
import 'package:codewalk/presentation/services/sound_service.dart';
import 'package:codewalk/presentation/theme/app_theme.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';
import '../hosts/fakes.dart';
import '../storage/storage_fakes.dart';
import 'fakes.dart';
import 'live_fakes.dart';
import 'workspace_support.dart';

/// The two surface sizes of the v1 parity contract (#458): compact phone and
/// wide desktop, both in `en` at text scale 1.0.
const parityPhoneSize = Size(412, 915);
const parityDesktopSize = Size(1280, 800);

/// The reference endpoint profile of the parity fixtures, on both sides.
Future<void> saveReferenceProfile(CatalogRig rig) => rig.repository.save(
  EndpointProfile(
    id: 'profile_a',
    label: 'Test Server',
    endpoint: Uri.parse('http://127.0.0.1:4096/proxy/'),
  ),
  'fake-a',
);

/// The v2 app wired with the parity fakes and the fixed reference clock.
AppDependencies buildReferenceDependencies({
  required CatalogRig rig,
  required LiveDirectory directory,
  required bool dark,
}) {
  final metadata = V2MetadataStore(backend: FakeMetadataBackend());
  final payloads = PreferencesPayloadStore(metadata);
  final dependencies = createAppDependencies(
    initialLink: Uri(path: '/sessions'),
    sessionClock: () => DateTime.utc(2026, 11, 2, 12),
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
  return dependencies;
}

/// The v1 reference theme of the parity fixtures: refined style, Roboto text.
ThemeData v1ReferenceTheme({required bool dark}) {
  final raw = dark
      ? AppTheme.darkFrom(
          ColorScheme.fromSeed(
            seedColor: AppTheme.seedColor,
            brightness: Brightness.dark,
          ),
          visualStyle: VisualStyle.refined,
        )
      : AppTheme.lightFrom(
          ColorScheme.fromSeed(
            seedColor: AppTheme.seedColor,
            brightness: Brightness.light,
          ),
          visualStyle: VisualStyle.refined,
        );
  return raw.copyWith(textTheme: raw.textTheme.apply(fontFamily: 'Roboto'));
}

/// Decision 3 (#458): the v1 reference hides the Files and Utility desktop
/// panes; the conversation pane keeps its 300 dp default.
Future<SettingsProvider> v1ReferenceSettings(
  InMemoryAppLocalDataSource source,
) async {
  final settings = SettingsProvider(
    localDataSource: source,
    dioClient: DioClient(),
    soundService: SoundService(),
  );
  addTearDown(settings.dispose);
  await settings.setDesktopPaneVisible(DesktopPane.files, false);
  await settings.setDesktopPaneVisible(DesktopPane.utility, false);
  return settings;
}

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
    await saveReferenceProfile(rig);
    final directory = LiveDirectory();
    final dependencies = buildReferenceDependencies(
      rig: rig,
      directory: directory,
      dark: dark,
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
  // Each size shows its own session surface: the compact list drawer on a
  // phone, the persistent sidebar on desktop.
  final surfaces = {
    'phone': (size: parityPhoneSize, surface: 'workspace-drawer'),
    'desktop': (size: parityDesktopSize, surface: 'workspace-sidebar'),
  };
  for (final entry in surfaces.entries) {
    for (final dark in [false, true]) {
      testWidgets(
        'parity workspace mounts at ${entry.key} size, ${dark ? 'dark' : 'light'}',
        (tester) async {
          await ParitySurface.pump(tester, size: entry.value.size, dark: dark);

          expect(find.byType(CodeWalkV2Bootstrap), findsOneWidget);
          expect(find.byKey(ValueKey(entry.value.surface)), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
