import 'package:codewalk/app/composition_root.dart';
import 'package:codewalk/app/v2_bootstrap.dart';
import 'package:codewalk/features/sessions/session_actions_menu.dart';
import 'package:codewalk/features/sessions/sessions_controller.dart';
import 'package:codewalk/platform/sessions/session_action_source_io.dart';
import 'package:codewalk/shared/l10n/generated/v2_localizations.dart';
import 'package:codewalk/shared/sessions/session_actions.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../hosts/fakes.dart';
import 'fakes.dart';
import 'live_fakes.dart';

void main() {
  late FakeActionSource actions;

  Future<(CatalogSource source, V2Localizations l10n, SessionsController controller)>
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
    final dependencies = createAppDependencies(
      initialLink: Uri(path: '/sessions'),
      profileRepository: rig.repository,
      endpointProber: FakeProber(),
      sessionCatalogFactory: rig.create,
      sessionLiveDirectory: LiveDirectory.new,
      sessionActionFactory: (profile, credential) => actions,
    );
    await tester.pumpWidget(CodeWalkV2Bootstrap(dependencies: dependencies));
    await tester.pumpAndSettle();
    final dropdown = tester.widget<DropdownButton<String>>(
      find.byKey(const ValueKey('sessions-profile')),
    );
    dropdown.onChanged!('profile_a');
    await tester.pump();
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
      find.byKey(ValueKey('session-actions-${source.row('first').info.ref.storageKey}')),
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
      find.byKey(ValueKey('session-actions-${source.row('first').info.ref.storageKey}')),
    );
    await tester.pumpAndSettle();
    expect(find.text(l10n.sessionsActionMarkViewed), findsNothing);
  });

  testWidgets('the unread mark follows the endpoint epochs', (tester) async {
    final (source, l10n, _) = await open(
      tester,
      viewStates: {},
    );
    final key = source.row('first').info.ref.storageKey;
    // The endpoint's marker arrives with the row.
    actions.viewStates[key] = SessionViewState.unread;
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

  test('the action source observes the version with the profile probe', () async {
    final prober = FakeProber();
    final source = createSessionActionSource(
      profile('a'),
      EndpointCredential(
        kind: EndpointAuthKind.password,
        secret: 'secret',
      ),
      prober,
    );
    // The probe observed 2.0.22, so the endpoint's own commands are
    // available.
    expect((await source.support()).available, isTrue);
    source.close();
  });

  test('a transient probe failure is observed again', () async {
    final prober = FakeProber()
      ..assessment = const EndpointAssessment(
        EndpointStatus.unreachable,
      );
    final source = createSessionActionSource(
      profile('a'),
      EndpointCredential(
        kind: EndpointAuthKind.password,
        secret: 'secret',
      ),
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

  testWidgets('the create sends the chosen project directory', (tester) async {
    final (source, l10n, _) = await open(
      tester,
      rows: (source) => [
        source.row('first', title: 'First', directory: '/work/alpha'),
      ],
    );
    await tester.tap(find.byKey(const ValueKey('sessions-create')));
    await tester.pumpAndSettle();
    expect(find.text(l10n.sessionsCreateTitle), findsOneWidget);
    // The path is on the group's header and on the choice.
    expect(find.text('/work/alpha'), findsWidgets);
    await tester.tap(
      find.byKey(const ValueKey('sessions-create-project-/work/alpha')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.sessionsCreateConfirm));
    await tester.pumpAndSettle();
    expect(actions.calls, contains('create'));
    expect(actions.created, ['/work/alpha']);
  });

  testWidgets('the create sends a free-form directory', (tester) async {
    final (source, l10n, _) = await open(
      tester,
      rows: (source) => [
        source.row('first', title: 'First', directory: '/work/alpha'),
      ],
    );
    await tester.tap(find.byKey(const ValueKey('sessions-create')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('sessions-create-directory')),
      '/work/other',
    );
    await tester.pump();
    await tester.tap(find.text(l10n.sessionsCreateConfirm));
    await tester.pumpAndSettle();
    expect(actions.created, ['/work/other']);
  });

  testWidgets('a refused create says so', (tester) async {
    final (source, l10n, controller) = await open(
      tester,
      rows: (source) => [
        source.row('first', title: 'First', directory: '/work/alpha'),
      ],
    );
    actions.outcomes['create'] = SessionActionOutcome.rejected;
    await tester.tap(find.byKey(const ValueKey('sessions-create')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('sessions-create-project-/work/alpha')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.sessionsCreateConfirm));
    await tester.pumpAndSettle();
    // The refused create is reported by the list and by the dialog.
    expect(controller.actionFailure, SessionActionOutcome.rejected);
    expect(find.byKey(const ValueKey('sessions-create-failed')), findsOneWidget);
  });

  testWidgets('the create is disabled with its reason when it is not offered', (
    tester,
  ) async {
    final (_, l10n, _) = await open(
      tester,
      support: const SessionActionSupport(
        SessionActionReason.versionUnverified,
      ),
    );
    final button = tester.widget<IconButton>(
      find.byKey(const ValueKey('sessions-create')),
    );
    expect(button.onPressed, isNull);
    expect(find.text(l10n.sessionsActionUnavailableVersion), findsWidgets);
  });

  testWidgets('a relative path is refused before anything is sent', (
    tester,
  ) async {
    final (_, _, _) = await open(tester);
    await tester.tap(find.byKey(const ValueKey('sessions-create')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('sessions-create-directory')),
      'work/other',
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('sessions-create-invalid')), findsOneWidget);
    // The confirm stays disabled while the path is not usable.
    final confirm = tester.widget<FilledButton>(
      find.byKey(const ValueKey('sessions-create-confirm')),
    );
    expect(confirm.onPressed, isNull);
    expect(actions.calls, isNot(contains('create')));
  });

  testWidgets('a path over the bound is refused before anything is sent', (
    tester,
  ) async {
    final (_, _, _) = await open(tester);
    await tester.tap(find.byKey(const ValueKey('sessions-create')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('sessions-create-directory')),
      '/work/${'x' * 5000}',
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('sessions-create-invalid')), findsOneWidget);
    final confirm = tester.widget<FilledButton>(
      find.byKey(const ValueKey('sessions-create-confirm')),
    );
    expect(confirm.onPressed, isNull);
    expect(actions.calls, isNot(contains('create')));
  });

  testWidgets('the confirm is disabled while the create is in flight', (
    tester,
  ) async {
    final (source, l10n, _) = await open(tester);
    actions.createDelay = const Duration(milliseconds: 200);
    await tester.tap(find.byKey(const ValueKey('sessions-create')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('sessions-create-directory')),
      '/work/other',
    );
    await tester.pump();
    await tester.tap(find.text(l10n.sessionsCreateConfirm));
    await tester.pump();
    final confirm = tester.widget<FilledButton>(
      find.byKey(const ValueKey('sessions-create-confirm')),
    );
    expect(confirm.onPressed, isNull);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    // A second tap never sent a second create.
    expect(actions.created, ['/work/other']);
  });

  testWidgets('a create whose answer was lost says the list is working', (
    tester,
  ) async {
    final (source, l10n, _) = await open(tester);
    actions.outcomes['create'] = SessionActionOutcome.uncertain;
    await tester.tap(find.byKey(const ValueKey('sessions-create')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('sessions-create-directory')),
      '/work/other',
    );
    await tester.pump();
    await tester.tap(find.text(l10n.sessionsCreateConfirm));
    await tester.pumpAndSettle();
    // The dialog closes and the list waits for the authoritative read.
    expect(find.byKey(const ValueKey('sessions-create-confirm')), findsNothing);
    expect(find.text(l10n.sessionsActionPending), findsWidgets);
  });

  testWidgets('the created session arrives through the authoritative read', (
    tester,
  ) async {
    final (source, l10n, _) = await open(
      tester,
      rows: (source) => [
        source.row('first', title: 'First', directory: '/work/alpha'),
      ],
    );
    await tester.tap(find.byKey(const ValueKey('sessions-create')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('sessions-create-project-/work/alpha')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.sessionsCreateConfirm));
    await tester.pump();
    // The receipt never becomes a row.
    expect(find.text('Second'), findsNothing);
    // The endpoint's own record arrives with the next authoritative read.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(source.tasks.length, 2);
    source.respond([
      source.row('first', title: 'First', directory: '/work/alpha'),
      source.row('second', title: 'Second', directory: '/work/alpha'),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('Second'), findsOneWidget);
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
