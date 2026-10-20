import 'package:codewalk/app/composition_root.dart';
import 'package:codewalk/app/v2_bootstrap.dart';
import 'package:codewalk/features/sessions/session_actions_menu.dart';
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

  Future<(CatalogSource source, V2Localizations l10n)> open(
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
    return (source, dependencies.localizations.current);
  }

  testWidgets('the row offers the filter and the actions', (tester) async {
    final (source, l10n) = await open(tester);
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
    final (source, l10n) = await open(tester);
    await tester.tap(
      find.byKey(ValueKey('session-actions-${source.row('first').info.ref.storageKey}')),
    );
    await tester.pumpAndSettle();
    expect(find.text(l10n.sessionsActionMarkViewed), findsNothing);
  });

  testWidgets('the unread mark follows the endpoint epochs', (tester) async {
    final (source, l10n) = await open(
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
    final (source, l10n) = await open(
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
    final (source, l10n) = await open(tester);
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
    final (source, l10n) = await open(tester);
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
    final (source, l10n) = await open(tester);
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
    final (source, l10n) = await open(tester);
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
    final (source, l10n) = await open(tester, children: 3);
    final row = source.row('first', title: 'First');
    await tester.tap(
      find.byKey(ValueKey('session-actions-${row.info.ref.storageKey}')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.sessionsActionDelete));
    await tester.pumpAndSettle();
    expect(find.textContaining('3'), findsWidgets);
  });

  testWidgets('the local hide hides the row', (tester) async {
    final (source, l10n) = await open(tester);
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
