import 'package:codewalk/app/app_dependencies.dart';
import 'package:codewalk/app/composition_root.dart';
import 'package:codewalk/app/v2_bootstrap.dart';
import 'package:codewalk/platform/sessions/session_draft_store.dart';
import 'package:codewalk/platform/sessions/workspace_draft_store.dart';
import 'package:codewalk/platform/storage/metadata_store.dart';
import 'package:codewalk/platform/storage/payload_store.dart';
import 'package:codewalk/shared/l10n/generated/v2_localizations.dart';
import 'package:codewalk/shared/sessions/session_live_source.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../hosts/fakes.dart';
import '../storage/storage_fakes.dart';
import 'composer_fakes.dart';
import 'fakes.dart';
import 'live_fakes.dart';

/// The whole workspace over one saved server whose list holds session one.
typedef WorkspaceApp = ({
  AppDependencies dependencies,
  V2Localizations l10n,
  CatalogRig rig,
  LiveDirectory directory,
});

Future<void> settleWorkspace(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Launches the workspace at [link] in a [size] window, in [locale] and at
/// the [textScale] the platform asks for.
Future<WorkspaceApp> launchWorkspace(
  WidgetTester tester, {
  String link = '/s/profile_a/ses_one',
  Size size = const Size(1280, 800),
  Locale? locale,
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final rig = CatalogRig();
  addTearDown(rig.dispose);
  await rig.save('a');
  final directory = LiveDirectory();
  final metadata = V2MetadataStore(backend: FakeMetadataBackend());
  final payloads = PreferencesPayloadStore(metadata);
  final dependencies = createAppDependencies(
    initialLink: Uri.parse(link),
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
  if (locale != null) dependencies.preferences.setLocale(locale);
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData.fromView(
        tester.view,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: CodeWalkV2Bootstrap(dependencies: dependencies),
    ),
  );
  await settleWorkspace(tester);
  final source = rig.sources.single;
  source.respond([source.row('one', title: 'One', directory: '/w')]);
  await settleWorkspace(tester);
  return (
    dependencies: dependencies,
    l10n: dependencies.localizations.current,
    rig: rig,
    directory: directory,
  );
}

/// Opens the live view of session one.
Future<void> openLiveSession(WidgetTester tester, WorkspaceApp app) async {
  final source = app.rig.sources.single;
  final ref = source.row('one').info.ref;
  for (final (read, task) in source.reads.toList()) {
    if (read != ref || task.completion.isCompleted) continue;
    task.completion.complete(
      source.served.firstWhere((row) => row.info.ref == ref),
    );
    await settleWorkspace(tester);
  }
  final handle = app.directory.grant(ref, outbox: FakeOutbox());
  await tester.pump();
  handle.emit(
    SessionLiveView(
      session: ref,
      phase: SessionLivePhase.live,
      state: liveState(ref),
    ),
  );
  await settleWorkspace(tester);
}
