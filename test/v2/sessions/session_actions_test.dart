import 'package:codewalk/app/app_dependencies.dart';
import 'package:codewalk/app/composition_root.dart';
import 'package:codewalk/app/v2_bootstrap.dart';
import 'package:codewalk/features/sessions/session_actions_menu.dart';
import 'package:codewalk/features/sessions/sessions_controller.dart';
import 'package:codewalk/platform/sessions/session_action_source_io.dart';
import 'package:codewalk/platform/sessions/workspace_draft_store.dart';
import 'package:codewalk/platform/storage/metadata_store.dart';
import 'package:codewalk/platform/storage/payload_store.dart';
import 'package:codewalk/shared/l10n/generated/v2_localizations.dart';
import 'package:codewalk/shared/sessions/session_actions.dart';
import 'package:codewalk/shared/sessions/session_catalog_changes.dart';
import 'package:codewalk/shared/sessions/session_catalog_source.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../hosts/fakes.dart';
import '../storage/storage_fakes.dart';
import 'fakes.dart';
import 'live_fakes.dart';
import 'workspace_support.dart';

void main() {
  late FakeActionSource actions;
  late LiveDirectory live;
  late AppDependencies app;

  Future<
    (CatalogSource source, V2Localizations l10n, SessionsController controller)
  >
  open(
    WidgetTester tester, {
    List<SessionSummary> Function(CatalogSource source)? rows,
    SessionActionSupport support = const SessionActionSupport(
      SessionActionReason.none,
    ),
    Map<String, SessionViewState> viewStates = const {},
    int children = 0,
  }) async {
    actions = FakeActionSource(endpointSupport: support);
    final rig = CatalogRig();
    await rig.save('a');
    live = LiveDirectory();
    final metadata = V2MetadataStore(backend: FakeMetadataBackend());
    final dependencies = app = createAppDependencies(
      metadataStore: metadata,
      sessionClock: () => tester.binding.clock.now(),
      workspaceDraftStore: WorkspaceDraftStore(
        payloads: PreferencesPayloadStore(metadata),
        index: metadata,
      ),
      initialLink: Uri(path: '/sessions'),
      profileRepository: rig.repository,
      endpointProber: FakeProber(),
      sessionCatalogFactory: rig.create,
      sessionLiveDirectory: () => live,
      sessionActionFactory: (profile, credential) => actions,
    );
    await tester.pumpWidget(CodeWalkV2Bootstrap(dependencies: dependencies));
    await showSessionList(tester);
    final source = rig.sources.single;
    actions.viewStates.addAll(viewStates);
    actions.children = children;
    source.respond(rows?.call(source) ?? [source.row('first', title: 'First')]);
    await tester.pumpAndSettle();
    return (source, dependencies.localizations.current, dependencies.sessions!);
  }

  testWidgets('the row offers the filter and the actions', (tester) async {
    final (source, l10n, _) = await open(tester);
    expect(find.byKey(const ValueKey('sessions-filter')), findsOneWidget);
    expect(find.text('First'), findsOneWidget);
    await tester.tap(
      find.byKey(
        ValueKey('session-actions-${source.row('first').info.ref.storageKey}'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(l10n.sessionsActionRename), findsOneWidget);
    expect(find.text(l10n.sessionsActionFork), findsOneWidget);
    expect(find.text(l10n.sessionsActionDelete), findsOneWidget);
    expect(find.text(l10n.sessionsActionHide), findsOneWidget);
  });

  testWidgets('the mark as viewed entry needs an unread row', (tester) async {
    final (source, l10n, _) = await open(tester);
    await tester.tap(
      find.byKey(
        ValueKey('session-actions-${source.row('first').info.ref.storageKey}'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(l10n.sessionsActionMarkViewed), findsNothing);
  });

  testWidgets('the unread mark follows the endpoint epochs', (tester) async {
    final (source, l10n, _) = await open(tester, viewStates: {});
    final key = source.row('first').info.ref.storageKey;
    // The endpoint's marker arrives with the row: the catch-up read that
    // follows the feed's opening returns it.
    actions.viewStates[key] = SessionViewState.unread;
    await tester.pump(const Duration(milliseconds: 300));
    expect(source.tasks, hasLength(2));
    source.respond([source.row('first', title: 'First')]);
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('session-unread-$key')), findsOneWidget);
    await tester.tap(find.byKey(ValueKey('session-actions-$key')));
    await tester.pumpAndSettle();
    expect(find.text(l10n.sessionsActionMarkViewed), findsOneWidget);
    await tester.tap(find.text(l10n.sessionsActionMarkViewed));
    await tester.pumpAndSettle();
    expect(actions.calls, contains('markViewed'));
  });

  testWidgets('an unavailable action is disabled with its reason', (
    tester,
  ) async {
    final (source, l10n, _) = await open(
      tester,
      support: const SessionActionSupport(
        SessionActionReason.versionUnverified,
      ),
    );
    final key = source.row('first').info.ref.storageKey;
    await tester.tap(find.byKey(ValueKey('session-actions-$key')));
    await tester.pumpAndSettle();
    final item = tester.widget<PopupMenuItem<SessionRowAction>>(
      find.ancestor(
        of: find.text(l10n.sessionsActionRename),
        matching: find.byType(PopupMenuItem<SessionRowAction>),
      ),
    );
    expect(item.enabled, isFalse);
    // Every unavailable native entry carries the reason.
    expect(find.text(l10n.sessionsActionUnavailableVersion), findsWidgets);
  });

  testWidgets('a rename sends the new title', (tester) async {
    final (source, l10n, _) = await open(tester);
    final row = source.row('first', title: 'First');
    await tester.tap(
      find.byKey(ValueKey('session-actions-${row.info.ref.storageKey}')),
    );
    await tester.pumpAndSettle();
    expect(find.text(l10n.sessionsActionRename), findsOneWidget);
    await tester.tap(find.text(l10n.sessionsActionRename));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Renamed');
    await tester.tap(find.text(l10n.sessionsActionRenameSave));
    await tester.pumpAndSettle();
    expect(actions.calls, contains('rename'));
    expect(actions.titles, contains('Renamed'));
  });

  testWidgets('the delete warns about the child sessions', (tester) async {
    final (source, l10n, _) = await open(tester);
    final row = source.row('first', title: 'First');
    await tester.tap(
      find.byKey(ValueKey('session-actions-${row.info.ref.storageKey}')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.sessionsActionDelete));
    await tester.pumpAndSettle();
    expect(find.textContaining('First'), findsWidgets);
    // The dialog's own button: the menu entry carried the same word.
    await tester.tap(find.text(l10n.commonDelete).last);
    await tester.pumpAndSettle();
    expect(actions.calls, contains('delete'));
  });

  testWidgets('the long press opens the row menu', (tester) async {
    final (source, l10n, _) = await open(tester);
    // The long press is on the row, not on the overflow button.
    await tester.longPress(find.text('First'));
    await tester.pumpAndSettle();
    expect(find.text(l10n.sessionsActionRename), findsOneWidget);
  });

  test(
    'the action source observes the version with the profile probe',
    () async {
      final prober = FakeProber();
      final source = createSessionActionSource(
        profile('a'),
        EndpointCredential(kind: EndpointAuthKind.password, secret: 'secret'),
        prober,
      );
      // The probe observed 2.0.22, so the endpoint's own commands are
      // available.
      expect((await source.support()).available, isTrue);
      source.close();
    },
  );

  test('a transient probe failure is observed again', () async {
    final prober = FakeProber()
      ..assessment = const EndpointAssessment(EndpointStatus.unreachable);
    final source = createSessionActionSource(
      profile('a'),
      EndpointCredential(kind: EndpointAuthKind.password, secret: 'secret'),
      prober,
    );
    expect((await source.support()).available, isFalse);
    // The endpoint answers now, so the actions come back.
    prober.assessment = const EndpointAssessment(
      EndpointStatus.compatible,
      version: '2.0.22',
    );
    expect((await source.support()).available, isTrue);
    source.close();
  });

  testWidgets('an uncertain command waits for the re-read', (tester) async {
    final (source, l10n, _) = await open(tester);
    actions.outcomes['rename'] = SessionActionOutcome.uncertain;
    final row = source.row('first', title: 'First');
    await tester.tap(
      find.byKey(ValueKey('session-actions-${row.info.ref.storageKey}')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.sessionsActionRename));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Renamed');
    await tester.tap(find.text(l10n.sessionsActionRenameSave));
    await tester.pumpAndSettle();
    // The command's answer was lost: the list waits instead of calling it a
    // failure.
    expect(find.text(l10n.sessionsActionPending), findsOneWidget);
    expect(find.text(l10n.sessionsActionFailed), findsNothing);
  });

  testWidgets('the delete warning carries the child count', (tester) async {
    final (source, l10n, _) = await open(tester, children: 3);
    final row = source.row('first', title: 'First');
    await tester.tap(
      find.byKey(ValueKey('session-actions-${row.info.ref.storageKey}')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.sessionsActionDelete));
    await tester.pumpAndSettle();
    expect(find.textContaining('3'), findsWidgets);
  });

  Future<void> startDraft(
    WidgetTester tester,
    CatalogSource source, {
    String? directory,
  }) async {
    // The debounce can outlive pumpAndSettle when no frame is scheduled.
    await tester.pump(const Duration(milliseconds: 300));
    // Finish the feed's initial authoritative catch-up before a send intent.
    if (!source.tasks.last.completion.isCompleted) {
      source.respond(app.sessions!.sessions);
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byKey(const ValueKey('sessions-create')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('workspace-draft')), findsOneWidget);
    expect(actions.calls.where((call) => call == 'create'), isEmpty);
    if (directory != null) {
      await tester.enterText(
        find.byKey(const ValueKey('workspace-draft-directory')),
        directory,
      );
      await tester.tap(
        find.byKey(const ValueKey('workspace-draft-project-confirm')),
      );
      await tester.pumpAndSettle();
    }
    await tester.enterText(
      find.byKey(const ValueKey('workspace-draft-text')),
      'First prompt',
    );
    await tester.pump();
  }

  Future<void> sendDraft(WidgetTester tester) async {
    expect(
      tester
          .widget<IconButton>(
            find.byKey(const ValueKey('workspace-draft-send')),
          )
          .onPressed,
      isNotNull,
      reason:
          'loading=${app.workspaceDrafts!.loading} draft=${app.workspaceDrafts!.status} reason=${app.sessions!.createReason} pending=${app.sessions!.reconciling} quiet=${app.sessions!.quietRefreshing}',
    );
    await tester.tap(find.byKey(const ValueKey('workspace-draft-send')));
    await tester.pumpAndSettle();
  }

  testWidgets('first send creates in the chosen project directory', (
    tester,
  ) async {
    final (source, _, _) = await open(
      tester,
      rows: (source) => [
        source.row('first', title: 'First', directory: '/work/alpha'),
      ],
    );
    await startDraft(tester, source);
    await sendDraft(tester);
    expect(actions.created, ['/work/alpha']);
  });

  testWidgets('first send creates in an explicit free-form directory', (
    tester,
  ) async {
    final (source, _, _) = await open(tester);
    await startDraft(tester, source, directory: '/work/other');
    await sendDraft(tester);
    expect(actions.created, ['/work/other']);
  });

  testWidgets('a refused create keeps the draft and reports failure', (
    tester,
  ) async {
    final (source, _, controller) = await open(tester);
    actions.outcomes['create'] = SessionActionOutcome.rejected;
    await startDraft(tester, source, directory: '/work/other');
    await sendDraft(tester);
    expect(controller.actionFailure, SessionActionOutcome.rejected);
    expect(
      find.byKey(const ValueKey('workspace-draft-notice')),
      findsOneWidget,
    );
    expect(app.workspaceDrafts!.draft.text, 'First prompt');
    expect(app.workspaceDrafts!.status, WorkspaceDraftStatus.failed);
  });

  testWidgets('an unverified endpoint still permits a local draft', (
    tester,
  ) async {
    final (source, l10n, _) = await open(
      tester,
      support: const SessionActionSupport(
        SessionActionReason.versionUnverified,
      ),
    );
    expect(
      tester
          .widget<IconButton>(find.byKey(const ValueKey('sessions-create')))
          .onPressed,
      isNotNull,
    );
    await startDraft(tester, source, directory: '/work/other');
    expect(find.byKey(const ValueKey('workspace-draft')), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.byKey(const ValueKey('workspace-draft-send')),
          )
          .onPressed,
      isNull,
    );
    expect(find.text(l10n.sessionsActionUnavailableVersion), findsWidgets);
    expect(actions.calls.where((call) => call == 'create'), isEmpty);
  });

  for (final path in ['work/other', '/work/${'x' * 5000}']) {
    testWidgets('invalid directory is refused before sending: ${path.length}', (
      tester,
    ) async {
      final (source, _, _) = await open(tester);
      await startDraft(tester, source, directory: path);
      expect(app.workspaceDrafts!.needsDirectory, isTrue);
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('workspace-draft-directory')),
            )
            .decoration!
            .errorText,
        isNotNull,
      );
      expect(
        tester
            .widget<IconButton>(
              find.byKey(const ValueKey('workspace-draft-send')),
            )
            .onPressed,
        isNull,
      );
      expect(actions.calls, isNot(contains('create')));
    });
  }

  testWidgets('send stays disabled while create is in flight', (tester) async {
    final (source, _, _) = await open(tester);
    actions.createDelay = const Duration(seconds: 2);
    await startDraft(tester, source, directory: '/work/other');
    await tester.tap(find.byKey(const ValueKey('workspace-draft-send')));
    await tester.pump();
    expect(
      tester
          .widget<IconButton>(
            find.byKey(const ValueKey('workspace-draft-send')),
          )
          .onPressed,
      isNull,
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(actions.created, ['/work/other']);
  });

  testWidgets(
    'a lost create answer retains text and forbids automatic replay',
    (tester) async {
      final (source, _, _) = await open(tester);
      actions.outcomes['create'] = SessionActionOutcome.uncertain;
      await startDraft(tester, source, directory: '/work/other');
      await sendDraft(tester);
      expect(app.workspaceDrafts!.status, WorkspaceDraftStatus.uncertain);
      expect(app.workspaceDrafts!.draft.text, 'First prompt');
      expect(
        find.byKey(const ValueKey('workspace-draft-reset')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<IconButton>(
              find.byKey(const ValueKey('workspace-draft-send')),
            )
            .onPressed,
        isNull,
      );
      expect(actions.created, ['/work/other']);
    },
  );

  testWidgets('the receipt never becomes a catalog row', (tester) async {
    final (source, _, controller) = await open(
      tester,
      rows: (source) => [
        source.row('first', title: 'First', directory: '/work/alpha'),
      ],
    );
    await startDraft(tester, source);
    await sendDraft(tester);
    expect(controller.sessions.map((row) => row.info.title), ['First']);
    // The catalog changes only when the endpoint's authoritative read answers.
    await tester.pump(const Duration(milliseconds: 400));
    expect(source.tasks.last.completion.isCompleted, isFalse);
    source.respond([
      source.row('first', title: 'First', directory: '/work/alpha'),
      source.row('second', title: 'Second', directory: '/work/alpha'),
    ]);
    await tester.pumpAndSettle();
    expect(controller.sessions.map((row) => row.info.title), [
      'First',
      'Second',
    ]);
  });

  testWidgets('background rows never replace the chosen draft context', (
    tester,
  ) async {
    final (source, _, controller) = await open(
      tester,
      rows: (source) => [source.row('first', directory: '/work/alpha')],
    );
    await startDraft(tester, source);
    final refresh = controller.refresh();
    await tester.pump();
    source.respond([source.row('first')]);
    await refresh;
    await tester.pumpAndSettle();
    expect(app.workspaceDrafts!.currentKey!.canonicalDirectory, '/work/alpha');
    expect(app.workspaceDrafts!.draft.text, 'First prompt');
    expect(actions.calls, isNot(contains('create')));
  });

  testWidgets('a stale catalog blocks the draft send', (tester) async {
    final (source, _, controller) = await open(tester);
    await startDraft(tester, source, directory: '/work/other');
    final refresh = controller.refresh();
    await tester.pump();
    source.fail(SessionCatalogFailure.connection);
    await refresh;
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<IconButton>(
            find.byKey(const ValueKey('workspace-draft-send')),
          )
          .onPressed,
      isNull,
    );
    expect(actions.calls, isNot(contains('create')));
  });

  testWidgets('a pending authoritative re-read blocks draft send', (
    tester,
  ) async {
    final (source, _, _) = await open(tester);
    await startDraft(tester, source, directory: '/work/other');
    live.feeds.last.emit(const SessionCatalogChanged());
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(source.tasks.last.completion.isCompleted, isFalse);
    expect(
      tester
          .widget<IconButton>(
            find.byKey(const ValueKey('workspace-draft-send')),
          )
          .onPressed,
      isNull,
    );
    expect(actions.calls, isNot(contains('create')));
  });

  testWidgets('the local hide hides the row', (tester) async {
    final (source, l10n, _) = await open(tester);
    final row = source.row('first', title: 'First');
    await tester.tap(
      find.byKey(ValueKey('session-actions-${row.info.ref.storageKey}')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.sessionsActionHide));
    await tester.pumpAndSettle();
    expect(actions.calls, contains('hide'));
  });
}
